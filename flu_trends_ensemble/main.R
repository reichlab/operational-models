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
