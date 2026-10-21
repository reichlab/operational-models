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
data_date <- ref_date - 3

locations <- read.csv(
  "https://raw.githubusercontent.com/reichlab/flu-metrocast/refs/heads/main/auxiliary-data/locations.csv"
)
outputs_path <- "output/model-output"
forecasts <- arrow::read_parquet(paste0(
  outputs_path,
  "/UMass-SAR/",
  ref_date,
  "-UMass-SAR.parquet"
)) |>
  dplyr::mutate(
    model_id = "UMass-SAR",
    # the hub output has no horizon column, so recover it from the target end date
    horizon = as.integer(target_end_date - ref_date) / 7
  ) |>
  dplyr::left_join(locations, by = "location") |>
  dplyr::arrange(state_abb)

# the forecasts are samples only. hubVis summarizes them as quantiles when intervals are given (used for the
# near-term horizons 0-3) and plots each sample trajectory when intervals = NULL (used for all horizons 0-31)
forecasts_near_term <- forecasts |> dplyr::filter(horizon >= 0, horizon <= 3)
forecasts_trajectories <- forecasts |> dplyr::filter(horizon >= 0, horizon <= 31)

target_data <- readr::read_csv(
  "https://raw.githubusercontent.com/reichlab/flu-metrocast/refs/heads/main/target-data/latest-data.csv"
) |>
  dplyr::left_join(locations, by = "location") |>
  dplyr::filter(location %in% unique(forecasts$location))

data_start <- ref_date - 12 * 7
data_end <- ref_date + 6 * 7

p <- plot_step_ahead_model_output(
  forecasts_near_term,
  target_data |>
    dplyr::filter(
      target_end_date >= data_start,
      target_end_date <= data_end,
      !is.na(location_name)
    ),
  x_col_name = "target_end_date",
  x_target_col_name = "target_end_date",
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
pdf(
  paste0("output/plots/", ref_date, "-UMass-SAR.pdf"),
  width = 12,
  height = 30
)
print(p)
dev.off()


data_start <- as.Date("2026-09-01")
data_end <- ref_date + 32 * 7 # through horizon 31

p <- plot_step_ahead_model_output(
  forecasts_trajectories,
  target_data |>
    dplyr::filter(
      target_end_date >= data_start,
      target_end_date <= data_end,
      !is.na(location_name)
    ),
  x_col_name = "target_end_date",
  x_target_col_name = "target_end_date",
  intervals = NULL, # plot each sample trajectory
  group = "location", # hubVis draws one line per group + output_type_id (i.e. per trajectory)
  facet = "location_name",
  facet_scales = "free_y",
  facet_nrow = 14,
  use_median_as_point = FALSE, # the median is drawn below, in a color that stands out from the trajectories
  interactive = FALSE,
  show_plot = FALSE
)

data_2022_23 <- target_data |>
  dplyr::filter(
    target_end_date >= "2022-09-01",
    target_end_date <= "2023-06-01",
    !is.na(location_name)
  )
p <- p +
  ggplot2::geom_line(
    data = data_2022_23 |>
      dplyr::mutate(target_end_date = target_end_date + 4 * 365),
    mapping = ggplot2::aes(
      x = target_end_date,
      y = observation,
      linetype = "2022-23"
    ),
    color = 'lightgrey'
  )

data_2023_24 <- target_data |>
  dplyr::filter(
    target_end_date >= "2023-09-01",
    target_end_date <= "2024-06-01",
    !is.na(location_name)
  )
p <- p +
  ggplot2::geom_line(
    data = data_2023_24 |>
      dplyr::mutate(target_end_date = target_end_date + 3 * 365),
    mapping = ggplot2::aes(
      x = target_end_date,
      y = observation,
      linetype = "2023-24"
    ),
    color = 'grey'
  )


data_2024_25 <- target_data |>
  dplyr::filter(
    target_end_date >= "2024-09-01",
    target_end_date <= "2025-06-01",
    !is.na(location_name)
  )
p <- p +
  ggplot2::geom_line(
    data = data_2024_25 |>
      dplyr::mutate(target_end_date = target_end_date + 2 * 365),
    mapping = ggplot2::aes(
      x = target_end_date,
      y = observation,
      linetype = "2024-25"
    ),
    color = 'darkgrey'
  )


data_2025_26 <- target_data |>
  dplyr::filter(
    target_end_date >= "2025-09-01",
    target_end_date <= "2026-06-01",
    !is.na(location_name)
  )
p <- p +
  ggplot2::geom_line(
    data = data_2025_26 |>
      dplyr::mutate(target_end_date = target_end_date + 365),
    mapping = ggplot2::aes(
      x = target_end_date,
      y = observation,
      linetype = "2025-26"
    ),
    color = 'darkgrey'
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

# median across trajectories, added last so it's drawn on top of the trajectories and past seasons
median_trajectory <- forecasts_trajectories |>
  dplyr::group_by(location_name, target_end_date) |>
  dplyr::summarize(value = stats::median(value), .groups = "drop")
p <- p +
  ggplot2::geom_line(
    data = median_trajectory,
    mapping = ggplot2::aes(x = target_end_date, y = value),
    color = "#0d469d",
    linewidth = 1,
    inherit.aes = FALSE
  )

p <- p + ggplot2::theme_bw()

if (!dir.exists("output/plots")) {
  dir.create("output/plots", recursive = TRUE)
}
pdf(
  paste0("output/plots/", ref_date, "-UMass-SAR_with_past_seasons.pdf"),
  width = 12,
  height = 30
)
print(p)
dev.off()
