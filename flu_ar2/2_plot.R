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
# use the newest S3 target data snapshot released in the week ending on ref_date. This is usually Wednesday's
# (ref_date - 3), but a holiday can delay the release. Like iddata, but stops if there is no snapshot that week rather
# than silently using last week's
snapshot_exists <- function(dataset, date) {
  tryCatch({
    close(url(paste0("https://infectious-disease-data.s3.amazonaws.com/data-raw/", dataset, "-", date, ".csv"), open = "rb"))
    TRUE
  }, error = function(e) FALSE, warning = function(w) FALSE)
}
data_date <- Find(function(d) snapshot_exists("influenza-nhsn/nhsn", d), as.character(ref_date - 0:6))
if (is.null(data_date)) stop("no NHSN snapshot found from ", ref_date - 6, " to ", ref_date, " (or S3 is unreachable)")

locations <- read.csv("https://raw.githubusercontent.com/cdcepi/FluSight-forecast-hub/refs/heads/main/auxiliary-data/locations.csv")

selected_model <- "UMass-nhsn"

hub_con <- hubData::connect_model_output("intermediate-output/model-output")
forecasts <- hub_con |>
  dplyr::filter(reference_date == ref_date, model_id == selected_model) |>
  dplyr::collect() |>
  dplyr::left_join(locations)

target_data <- readr::read_csv(paste0("https://infectious-disease-data.s3.amazonaws.com/data-raw/influenza-nhsn/nhsn-", data_date, ".csv")) |>
  dplyr::select(c("Week Ending Date", "Geographic aggregation", "Total Influenza Admissions"))
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
pdf(paste0("output/plots/", ref_date, "-", selected_model, ".pdf"), width = 12, height = 30)
print(p)
dev.off()



data_start <- as.Date("2026-09-01")
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
  dplyr::filter(date >= "2022-09-01", date <= "2023-08-31", !is.na(location))
p <- p +
  ggplot2::geom_line(
    data = data_2022_23 |> dplyr::mutate(date = date + 4 * 365),
    mapping = ggplot2::aes(x = date, y = value, linetype = "2022-23"), color = 'lightgrey'
  )

data_2023_24 <- target_data |>
  dplyr::filter(date >= "2023-09-01", date <= "2024-08-31", !is.na(location))
p <- p +
  ggplot2::geom_line(
    data = data_2023_24 |> dplyr::mutate(date = date + 3 * 365),
    mapping = ggplot2::aes(x = date, y = value, linetype = "2023-24"), color = 'grey'
  )

data_2024_25 <- target_data |>
  dplyr::filter(date >= "2024-09-01", date <= "2025-08-31", !is.na(location))
p <- p +
  ggplot2::geom_line(
    data = data_2024_25 |> dplyr::mutate(date = date + 2 * 365),
    mapping = ggplot2::aes(x = date, y = value, linetype = "2024-25"), color = 'darkgrey'
  )

data_2025_26 <- target_data |>
  dplyr::filter(date >= "2025-09-01", date <= "2026-08-31", !is.na(location))
p <- p +
  ggplot2::geom_line(
    data = data_2025_26 |> dplyr::mutate(date = date + 1 * 365),
    mapping = ggplot2::aes(x = date, y = value, linetype = "2025-26"), color = '#676767'
  )

p <- p +
  ggplot2::scale_linetype_manual(
    name = "Past Season",
    values = c(
      "2022-23" = "solid",
      "2023-24" = "solid",
      "2024-25" = "solid",
      "2025-26" = "solid")
  )

p <- p + ggplot2::theme_bw()

if (!dir.exists("output/plots")) {
  dir.create("output/plots", recursive = TRUE)
}
pdf(paste0("output/plots/", ref_date, "-", selected_model, "_with_past_seasons.pdf"), width = 12, height = 30)
print(p)
dev.off()



# NSSP


locations <- read.csv("https://raw.githubusercontent.com/cdcepi/FluSight-forecast-hub/refs/heads/main/auxiliary-data/locations.csv")

selected_model <- "UMass-nssp"

hub_con <- hubData::connect_model_output("intermediate-output/model-output")
forecasts <- hub_con |>
  dplyr::filter(reference_date == ref_date, model_id == selected_model) |>
  dplyr::collect() |>
  dplyr::left_join(locations)

nssp_date <- Find(function(d) snapshot_exists("nssp/nssp", d), as.character(ref_date - 0:6))
if (is.null(nssp_date)) stop("no NSSP snapshot found from ", ref_date - 6, " to ", ref_date, " (or S3 is unreachable)")

target_data <- readr::read_csv(paste0("https://infectious-disease-data.s3.amazonaws.com/data-raw/nssp/nssp-", nssp_date, ".csv")) |>
  dplyr::filter(county == "All") |>
  dplyr::select(c("week_end", "geography", "percent_visits_influenza"))
colnames(target_data) <- c("date", "location_name", "value")
target_data <- target_data |>
  dplyr::mutate(
    location_name = ifelse(location_name == "United States", "US", location_name),
    value = value / 100
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
pdf(paste0("output/plots/", ref_date, "-", selected_model, ".pdf"), width = 12, height = 30)
print(p)
dev.off()



data_start <- as.Date("2026-09-01")
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
  dplyr::filter(date >= "2022-09-01", date <= "2023-08-31", !is.na(location))
p <- p +
  ggplot2::geom_line(
    data = data_2022_23 |> dplyr::mutate(date = date + 4 * 365),
    mapping = ggplot2::aes(x = date, y = value, linetype = "2022-23"), color = 'lightgrey'
  )

data_2023_24 <- target_data |>
  dplyr::filter(date >= "2023-09-01", date <= "2024-08-31", !is.na(location))
p <- p +
  ggplot2::geom_line(
    data = data_2023_24 |> dplyr::mutate(date = date + 3 * 365),
    mapping = ggplot2::aes(x = date, y = value, linetype = "2023-24"), color = 'grey'
  )

data_2024_25 <- target_data |>
  dplyr::filter(date >= "2024-09-01", date <= "2025-08-31", !is.na(location))
p <- p +
  ggplot2::geom_line(
    data = data_2024_25 |> dplyr::mutate(date = date + 2 * 365),
    mapping = ggplot2::aes(x = date, y = value, linetype = "2024-25"), color = 'darkgrey'
  )

data_2025_26 <- target_data |>
  dplyr::filter(date >= "2025-09-01", date <= "2026-08-31", !is.na(location))
p <- p +
  ggplot2::geom_line(
    data = data_2025_26 |> dplyr::mutate(date = date + 1 * 365),
    mapping = ggplot2::aes(x = date, y = value, linetype = "2025-26"), color = '#676767'
  )

p <- p +
  ggplot2::scale_linetype_manual(
    name = "Past Season",
    values = c(
      "2022-23" = "solid",
      "2023-24" = "solid",
      "2024-25" = "solid",
      "2025-26" = "solid")
  )

p <- p + ggplot2::theme_bw()

if (!dir.exists("output/plots")) {
  dir.create("output/plots", recursive = TRUE)
}
pdf(paste0("output/plots/", ref_date, "-", selected_model, "_with_past_seasons.pdf"), width = 12, height = 30)
print(p)
dev.off()