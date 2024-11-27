# You can use this script to verify that the data objects used as expected
# outcomes for integration tests are reasonable.
# This script expects to be run from the repository root.

library(hubData)
library(hubVis)
library(fs)
library(readr)
library(lubridate)
library(idforecastutils)

args <- commandArgs(trailingOnly = TRUE)

ref_date <- as.Date(args[1])
ref_date <- as.Date("2024-11-23")

locations <- read.csv("https://raw.githubusercontent.com/cdcepi/FluSight-forecast-hub/refs/heads/main/auxiliary-data/locations.csv")


hub_con <- hubData::connect_model_output("output/model-output")
forecasts <- hub_con |>
  dplyr::filter(reference_date == ref_date) |>
  dplyr::collect() |>
  dplyr::left_join(locations)

hub_con <- hubData::connect_model_output("intermediate-output/model-output")
forecasts <- hub_con |>
  dplyr::filter(reference_date == ref_date) |>
  dplyr::collect() |>
  dplyr::left_join(locations)

selected_model <- "UMass-ar6_pooled"
forecasts <- forecasts |>
  dplyr::filter(model_id == selected_model)

# target_data <- readr::read_csv("https://raw.githubusercontent.com/CDCgov/covid19-forecast-hub/refs/heads/main/target-data/covid-hospital-admissions.csv") |>
target_data <- readr::read_csv("https://infectious-disease-data.s3.amazonaws.com/data-raw/influenza-nhsn/nhsn-2024-11-20.csv") |>
  dplyr::select(c("Week Ending Date", "Geographic aggregation", "Total COVID-19 Admissions"))
colnames(target_data) <- c("date", "abbreviation", "value")
target_data <- target_data |>
  dplyr::mutate(
    abbreviation = ifelse(abbreviation == "USA", "US", abbreviation)
  ) |>
  dplyr::left_join(locations)

data_start <- ref_date - 12 * 7
data_end <- ref_date + 6 * 7

p <- plot_step_ahead_model_output(
  forecasts,
  target_data |>
    dplyr::filter(date >= data_start, date <= data_end, !is.na(location)) |>
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
pdf(paste0("output/plots/", ref_date, "-UMass-ar6_pooled.pdf"), width = 12, height = 30)
print(p)
dev.off()



data_start <- as.Date("2024-09-01")
data_end <- ref_date + 6 * 7

p <- plot_step_ahead_model_output(
  forecasts,
  target_data |>
    dplyr::filter(date >= data_start, date <= data_end, !is.na(location)) |>
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
  dplyr::filter(date >= "2022-09-01", date <= "2023-06-01", !is.na(location))
p <- p +
  ggplot2::geom_line(
    data = data_2022_23 |> dplyr::mutate(date = date + 2 * 365),
    mapping = ggplot2::aes(x = date, y = value), color = 'grey'
  )

data_2023_24 <- target_data |>
  dplyr::filter(date >= "2023-09-01", date <= "2024-06-01", !is.na(location))
p <- p +
  ggplot2::geom_line(
    data = data_2023_24 |> dplyr::mutate(date = date + 365),
    mapping = ggplot2::aes(x = date, y = value), color = 'grey'
  )

p <- p + ggplot2::theme_bw()

if (!dir.exists("output/plots")) {
  dir.create("output/plots", recursive = TRUE)
}
pdf(paste0("output/plots/", ref_date, "-", selected_model, "_with_past_seasons.pdf"), width = 12, height = 30)
print(p)
dev.off()
