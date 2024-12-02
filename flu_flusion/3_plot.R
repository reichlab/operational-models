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
data_date <- ref_date - 3

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

target_data <- readr::read_csv(paste0("https://infectious-disease-data.s3.amazonaws.com/data-raw/influenza-nhsn/nhsn-", data_date, ".csv")) |>
  dplyr::select(c("Week Ending Date", "Geographic aggregation", "Total Influenza Admissions"))
colnames(target_data) <- c("date", "abbreviation", "value")
target_data <- target_data |>
  dplyr::mutate(
    abbreviation = ifelse(abbreviation == "USA", "US", abbreviation)
  ) |>
  dplyr::left_join(locations) |>
  dplyr::filter(!is.na(location_name))

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



data_start <- as.Date("2024-09-01")
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
  dplyr::filter(date >= "2022-09-01", date <= "2023-06-01")
p <- p +
  ggplot2::geom_line(
    data = data_2022_23 |> dplyr::mutate(date = date + 2 * 365),
    mapping = ggplot2::aes(x = date, y = value), color = 'grey'
  )

data_2023_24 <- target_data |>
  dplyr::filter(date >= "2023-09-01", date <= "2024-06-01")
p <- p +
  ggplot2::geom_line(
    data = data_2023_24 |> dplyr::mutate(date = date + 365),
    mapping = ggplot2::aes(x = date, y = value), color = 'grey'
  )

p <- p + ggplot2::theme_bw()

if (!dir.exists("output/plots")) {
  dir.create("output/plots", recursive = TRUE)
}
pdf(paste0("output/plots/", ref_date, "-UMass-flusion_with_past_seasons.pdf"), width = 12, height = 30)
print(p)
dev.off()



cat_names <- c("large_decrease", "decrease", "stable", "increase", "large_increase")
grDevices::pdf(file = paste0("output/plots/", ref_date, "-UMass-flusion-with-categorical.pdf"), paper = "a4r")
idforecastutils::plot_quantile_pmf_outputs_pdf(
  model_out_tbl = flusion,
  target_ts = target_data,
  location_meta = locations,
  reference_date = ref_date,
  cats_ordered = cat_names[5:1],
  quantile_title = "Inc Flu Hosp",
  pmf_title = "Flu Hosp Rate Change"
)
grDevices::dev.off()
