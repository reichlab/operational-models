library(trendsEnsemble)
library(idforecastutils)
library(hubData)
library(hubVis)
library(fs)
library(readr)
library(lubridate)

args <- commandArgs(trailingOnly = TRUE)

ref_date <- as.Date(args[1])
ref_date <- lubridate::ymd(ref_date)
data_date <- ref_date - 3

locations <- read.csv("https://raw.githubusercontent.com/cdcepi/FluSight-forecast-hub/refs/heads/main/auxiliary-data/locations.csv")
required_quantiles <- c(0.01, 0.025, seq(0.05, 0.95, by = 0.05), 0.975, 0.99)

# load target data
target_data <- readr::read_csv(paste0("https://infectious-disease-data.s3.amazonaws.com/data-raw/influenza-nhsn/nhsn-", data_date, ".csv")) |>
  dplyr::select(c("Week Ending Date", "Geographic aggregation", "Total Influenza Admissions"))
colnames(target_data) <- c("date", "abbreviation", "value")
target_data <- target_data |>
  dplyr::mutate(
    abbreviation = ifelse(abbreviation == "USA", "US", abbreviation)
  ) |>
  dplyr::left_join(locations) |>
  dplyr::filter(!is.na(location_name))
target_ts <- target_data |>
  dplyr::select("date", "location", "value") |>
  dplyr::arrange(dplyr::desc(date)) |>
  dplyr::rename(time_index = date, observation = value)

# set up variations of baseline to fit
component_variations <- tidyr::expand_grid(
  transformation = c("none", "sqrt"),
  symmetrize = c(TRUE, FALSE),
  window_size = c(3, 4),
  temporal_resolution = "weekly"
)

# Generate ensemble
outputs_list <- create_trends_ensemble(
  component_variations,
  target_ts,
  ref_date,
  horizons = 0:3,
  target = "wk inc flu hosp",
  quantile_levels = required_quantiles,
  n_samples = 100,
  round_predictions = TRUE,
  return_baseline_predictions = TRUE
)
component_outputs <- outputs_list[["baselines"]] |>
  dplyr::mutate(
    output_type_id = ifelse(
      .data[["output_type"]] == "sample",
      paste0(.data[["location"]], sprintf("%02g", .data[["output_type_id"]])),
      as.character(.data[["output_type_id"]])
    )
  )
model_names <- unique(component_outputs$model_id)

# save forecasts
trends_ensemble_outputs <- outputs_list[["ensemble"]] |>
  dplyr::mutate(
    output_type_id = ifelse(
      .data[["output_type"]] == "sample",
      paste0(.data[["location"]], sprintf("%02g", .data[["output_type_id"]])),
      as.character(.data[["output_type_id"]])
    )
  )
trendsEnsemble::save_model_out_tbl(trends_ensemble_outputs, path = "output/model-output", extension = "parquet")

# plot forecasts
forecasts <- trends_ensemble_outputs |>
  dplyr::filter(output_type == "quantile") |>
  dplyr::mutate(output_type_id = as.numeric(output_type_id)) |>
  dplyr::left_join(locations)

data_start <- ref_date - 12 * 7
data_end <- ref_date + 6 * 7

p <- plot_step_ahead_model_output(
  forecasts,
  target_data |>
    dplyr::filter(date >= data_start, date <= data_end) |>
    dplyr::mutate(observation = value),
  x_col_name = "target_end_date",
  x_target_col_name = "date",
  intervals = c(0.5, 0.8, 0.95),
  facet = "location_name",
  facet_scales = "free_y",
  facet_nrow = 14,
  use_median_as_point = TRUE,
  interactive = FALSE,
  show_plot = FALSE
)

if (!dir.exists("output/plots")) {
  dir.create("output/plots", recursive = TRUE)
}
pdf(paste0("output/plots/", ref_date, "-UMass-trends_ensemble.pdf"), width = 12, height = 30)
print(p)
dev.off()



data_start <- as.Date("2026-09-01")
data_end <- ref_date + 6 * 7

p <- plot_step_ahead_model_output(
  forecasts,
  target_data |>
    dplyr::filter(date >= data_start, date <= data_end) |>
    dplyr::mutate(observation = value),
  x_col_name = "target_end_date",
  x_target_col_name = "date",
  intervals = c(0.5, 0.8, 0.95),
  facet = "location_name",
  facet_scales = "free_y",
  facet_nrow = 14,
  use_median_as_point = TRUE,
  interactive = FALSE,
  show_plot = FALSE
)

data_2022_23 <- target_data |>
  dplyr::filter(date >= "2022-09-01", date <= "2023-06-15")
p <- p +
  ggplot2::geom_line(
    data = data_2022_23 |> dplyr::mutate(date = date + 4 * 365),
    mapping = ggplot2::aes(x = date, y = value, linetype = "2022-23"), color = 'lightgrey'
  )

data_2023_24 <- target_data |>
  dplyr::filter(date >= "2023-09-01", date <= "2024-06-15")
p <- p +
  ggplot2::geom_line(
    data = data_2023_24 |> dplyr::mutate(date = date + 3 * 365),
    mapping = ggplot2::aes(x = date, y = value, linetype = "2023-24"), color = 'grey'
  )

data_2024_25 <- target_data |>
  dplyr::filter(date >= "2024-09-01", date <= "2025-06-15")
p <- p +
  ggplot2::geom_line(
    data = data_2024_25 |> dplyr::mutate(date = date + 2 * 365),
    mapping = ggplot2::aes(x = date, y = value, linetype = "2024-25"), color = 'darkgrey'
  )

data_2025_26 <- target_data |>
  dplyr::filter(date >= "2025-09-01", date <= "2026-08-31", !is.na(location))
p <- p +
  ggplot2::geom_line(
    data = data_2025_26 |> dplyr::mutate(date = date + 365),
    mapping = ggplot2::aes(x = date, y = value, linetype = "2025-26"), color = '#969696'
  )

p <- p +
  ggplot2::scale_linetype_manual(
    name = "Past Season",
    values = c(
      "2022-23" = "solid",
      "2023-24" = "solid",
      "2024-25" = "solid",
      "2025-26" = "solid"
    )
  )

p <- p + ggplot2::theme_bw()

if (!dir.exists("output/plots")) {
  dir.create("output/plots", recursive = TRUE)
}
pdf(paste0("output/plots/", ref_date, "-UMass-trends_ensemble_with_past_seasons.pdf"), width = 12, height = 30)
print(p)
dev.off()
