library(hubData)
library(hubVis)
library(fs)
library(readr)
library(lubridate)

args <- commandArgs(trailingOnly = TRUE)

ref_date <- as.Date(args[1])

locations <- read.csv("https://raw.githubusercontent.com/cdcepi/FluSight-forecast-hub/refs/heads/main/auxiliary-data/locations.csv")

forecast_files <- Sys.glob("output/model-output/*/*.csv")
if (length(forecast_files) > 1) {
  stop("Expected to see a single forecast file.")
}
path_parts <- fs::path_split(forecast_files)[[1]]
model_id <- path_parts[length(path_parts) - 1]

forecasts <- dplyr::bind_rows(
  read.csv(forecast_files) |>
    dplyr::mutate(model_id = model_id)
) |>
  dplyr::left_join(locations)

target_data <- readr::read_csv("https://raw.githubusercontent.com/cdcepi/FluSight-forecast-hub/main/target-data/target-hospital-admissions.csv")

data_start <- ref_date - 12 * 7
data_end <- ref_date + 6 * 7

p <- plot_step_ahead_model_output(
  forecasts,
  target_data |>
    dplyr::filter(date >= data_start, date <= data_end) |>
    dplyr::mutate(observation = value),
  x_col_name = "target_end_date",
  x_target_col_name = "date",
  intervals = 0.95,
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
pdf(paste0("output/plots/", ref_date, "-UMass-AR2.pdf"), width = 12, height = 30)
print(p)
dev.off()
