library(hubData)
library(hubVis)
library(fs)
library(readr)
library(lubridate)

args <- commandArgs(trailingOnly = TRUE)

ref_date <- as.Date(args[1])
data_date <- ref_date - 3

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

data_start <- as.Date("2025-09-01")
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

data_2022_23 <- target_data |>
  dplyr::filter(date >= "2022-09-01", date <= "2023-06-01")
p <- p +
  ggplot2::geom_line(
    data = data_2022_23 |> dplyr::mutate(date = date + 3 * 365),
    mapping = ggplot2::aes(x = date, y = value, linetype = "2022-23"), color = 'lightgrey'
  )

data_2023_24 <- target_data |>
  dplyr::filter(date >= "2023-09-01", date <= "2024-06-01")
p <- p +
  ggplot2::geom_line(
    data = data_2023_24 |> dplyr::mutate(date = date + 2 * 365),
    mapping = ggplot2::aes(x = date, y = value, linetype = "2023-24"), color = 'grey'
  )

data_2024_25 <- target_data |>
  dplyr::filter(date >= "2024-09-01", date <= "2025-06-01")
p <- p +
  ggplot2::geom_line(
    data = data_2024_25 |> dplyr::mutate(date = date + 365),
    mapping = ggplot2::aes(x = date, y = value, linetype = "2024-25"), color = 'darkgrey'
  )

p <- p +
  ggplot2::scale_linetype_manual(
    name = "Past Season",
    values = c(
      "2022-23" = "solid",
      "2023-24" = "solid",
      "2024-25" = "solid")
  )

p <- p + ggplot2::theme_bw()

if (!dir.exists("output/plots")) {
  dir.create("output/plots", recursive = TRUE)
}

pdf(paste0("output/plots/", ref_date, "-UMass-AR2_with_past_seasons.pdf"), width = 12, height = 30)
print(p)
dev.off()