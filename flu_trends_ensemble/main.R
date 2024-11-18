library(trendsEnsemble)
library(idforecastutils)
library(hubData)
library(hubVis)
library(fs)
library(readr)
library(lubridate)

args <- commandArgs(trailingOnly = TRUE)

reference_date <- as.Date(args[1])
reference_date <- lubridate::ymd(reference_date)

locations <- read.csv("https://raw.githubusercontent.com/cdcepi/FluSight-forecast-hub/refs/heads/main/auxiliary-data/locations.csv")
required_quantiles <- c(0.01, 0.025, seq(0.05, 0.95, by = 0.05), 0.975, 0.99)

# load target data
target_data <- readr::read_csv("https://raw.githubusercontent.com/cdcepi/FluSight-forecast-hub/main/target-data/target-hospital-admissions.csv")
target_ts <- target_data |>
  dplyr::select("date", "location", "value") |>
  dplyr::rename(time_index = date, observation = value)

# set up variations of baseline to fit
component_variations <- tidyr::expand_grid(
  transformation = c("none", "sqrt"),
  symmetrize = c(TRUE, FALSE),
  window_size = c(3, 4),
  temporal_resolution = "weekly"
)

# Generate ensemble
outputs_list <- component_variations |>
  create_trends_ensemble(target_ts,
                         reference_date,
                         horizons = 0:3,
                         target = "wk inc flu hosp",
                         quantile_levels = required_quantiles,
                         n_samples = 13,
                         return_baseline_predictions = TRUE)
component_outputs <- outputs_list[["baselines"]] |>
  dplyr::mutate(output_type_id = ifelse(.data[["output_type"]] == "sample",
                                        paste0(.data[["location"]], sprintf("%02g", .data[["output_type_id"]])),
                                        as.character(.data[["output_type_id"]])))
model_names <- unique(component_outputs$model_id)

# save and plot individual baseline model forecasts
save_model_out_tbl(component_outputs, path = "output/model-output", extension = "parquet")


data_start <- reference_date - 12 * 7
data_end <- reference_date + 6 * 7

model_names |>
  purrr::walk(.f = function(current_model) {
    p <- hubVis::plot_step_ahead_model_output(
      component_outputs |>
        dplyr::left_join(locations, by = "location") |>
        dplyr::filter(model_id == current_model, output_type == "quantile") |>
        dplyr::mutate(output_type_id = as.numeric(output_type_id)) |>
        hubUtils::as_model_out_tbl(),
      target_data |>
        dplyr::filter(date >= data_start, date <= data_end) |>
        dplyr::mutate(observation = value),
      x_col_name = "target_end_date",
      x_target_col_name = "date",
      intervals = c(0.5, 0.95),
      facet = "location_name",
      facet_scales = "free_y",
      facet_nrow = 14,
      use_median_as_point = TRUE,
      interactive = FALSE,
      show_plot = FALSE,
      group = "reference_date"
    )

    plot_folder <- file.path("output/plots/", current_model)
    if (!file.exists(plot_folder)) dir.create(plot_folder, recursive = TRUE)

    results_path <- file.path(plot_folder, paste0(reference_date, "-", current_model, ".pdf"))
    grDevices::pdf(results_path, width = 12, height = 30)
    print(p)
    grDevices::dev.off()
  })


# pmf forecasts
trends_ensemble_raw <- outputs_list[["ensemble"]] |>
  dplyr::mutate(output_type_id = ifelse(.data[["output_type"]] == "sample",
                                        paste0(.data[["location"]], sprintf("%02g", .data[["output_type_id"]])),
                                        as.character(.data[["output_type_id"]])))

multipliers <- expand.grid(
  horizon = 0:4,
  output_type_id = cat_names,
  lower = NA,
  upper = NA,
  stringsAsFactors = FALSE
)

cat_names <- c("large_decrease", "decrease", "stable", "increase", "large_increase")
multipliers$lower[multipliers$horizon == 0] <- c(-Inf, -1.7, -0.3, 0.3, 1.7)
multipliers$lower[multipliers$horizon == 1] <- c(-Inf, -3, -0.5, 0.5, 3)
multipliers$lower[multipliers$horizon == 2] <- c(-Inf, -4, -0.7, 0.7, 4)
multipliers$lower[multipliers$horizon == 3] <-
  multipliers$lower[multipliers$horizon == 4] <- c(-Inf, -5, -1, 1, 5)
multipliers$upper[multipliers$horizon == 0] <- c(-1.7, -0.3, 0.3, 1.7, Inf)
multipliers$upper[multipliers$horizon == 1] <- c(-3, -0.5, 0.5, 3, Inf)
multipliers$upper[multipliers$horizon == 2] <- c(-4, -0.7, 0.7, 4, Inf)
multipliers$upper[multipliers$horizon == 3] <-
  multipliers$upper[multipliers$horizon == 4] <- c(-5, -1, 1, 5, Inf)

state_pops <- setNames(locations$population, locations$location)
bin_endpoints <- expand.grid(
  location = locations$location,
  horizon = 0:4,
  output_type_id = cat_names,
  stringsAsFactors = FALSE
) |>
  dplyr::left_join(multipliers, by = c("horizon", "output_type_id")) |>
  mutate(
    lower = .data[["lower"]] * state_pops[location] / 100000,
    upper = .data[["upper"]] * state_pops[location] / 100000
  )



trends_ensemble_pmf <- trends_ensemble_raw |>
  dplyr::filter(output_type == "quantile") |>
  idforecastutils::transform_quantile_to_pmf(bin_endpoints = bin_endpoints) |>
  dplyr::mutate(target = "wk flu hosp rate change") |>
  ungroup()
trends_ensemble_outputs <- trends_ensemble_raw |>
  dplyr::mutate(output_type_id = as.character(.data[["output_type_id"]])) |>
  dplyr::bind_rows(trends_ensemble_pmf)
save_model_out_tbl(trends_ensemble_outputs, path = "output/model-output", extension = "parquet")

# # open PDF
# model_id <- "UMass-trends_ensemble"
# model_folder <- file.path("output/plots", model_id)
# if (!file.exists(model_folder)) dir.create(model_folder, recursive = TRUE)
# grDevices::pdf(file = paste0(model_folder, "/", reference_date, "-", model_id, ".pdf"), paper = "a4r")
# plot_combined_outputs_pdf(
#   trends_ensemble_outputs,
#   target_data, locations,
#   reference_date, cats_ordered = cat_names[5:1],
#   quantile_title = "Inc Flu Hosp", pmf_title = "Flu Hosp Rate Change"
# )
# grDevices::dev.off()
