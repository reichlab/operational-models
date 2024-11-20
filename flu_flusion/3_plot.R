# You can use this script to verify that the data objects used as expected
# outcomes for integration tests are reasonable.
# This script expects to be run from the repository root.

library(hubData)
library(hubVis)
library(fs)
library(readr)
library(lubridate)

args <- commandArgs(trailingOnly = TRUE)

ref_date <- as.Date(args[1])

locations <- read.csv("https://raw.githubusercontent.com/cdcepi/FluSight-forecast-hub/refs/heads/main/auxiliary-data/locations.csv")


hub_con <- hubData::connect_model_output("intermediate-output/model-output")
components <- hub_con |>
  dplyr::filter(reference_date == ref_date) |>
  dplyr::collect()

hub_con <- hubData::connect_model_output("output/model-output")
flusion <- hub_con |>
  dplyr::filter(reference_date == ref_date) |>
  dplyr::collect()

forecasts <- dplyr::bind_rows(components |> dplyr::mutate(output_type_id = as.character(output_type_id)), flusion) |>
  dplyr::left_join(locations)

#target_data <- readr::read_csv("https://raw.githubusercontent.com/cdcepi/FluSight-forecast-hub/main/target-data/target-hospital-admissions.csv")
target_data <- readr::read_csv("https://raw.githubusercontent.com/cdcepi/FluSight-forecast-hub/refs/heads/main/auxiliary-data/target-data-archive/target-hospital-admissions_2024-02-10.csv")

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
pdf(paste0("output/plots/", ref_date, "-UMass-flusion.pdf"), width = 12, height = 30)
print(p)
dev.off()
