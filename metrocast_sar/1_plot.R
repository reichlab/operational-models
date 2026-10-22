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
# near-term horizons 0-3) and plots each sample trajectory when intervals = NULL (used for all horizons 0-33)
forecasts_near_term <- forecasts |> dplyr::filter(horizon >= 0, horizon <= 3)
forecasts_trajectories <- forecasts |>
  dplyr::filter(horizon >= 0, horizon <= 33)

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
  facet_ncol = 5,
  use_median_as_point = TRUE,
  interactive = FALSE,
  show_plot = FALSE
)
p <- p + ggplot2::theme(legend.position = "top")

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
data_end <- ref_date + 34 * 7 # through horizon 33

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
  facet_ncol = 5,
  use_median_as_point = FALSE, # the median is drawn below, in a color that stands out from the trajectories
  plot_target = FALSE, # the observed data is drawn below, so it can be in the legend
  interactive = FALSE,
  show_plot = FALSE
)

# past seasons, shifted onto the current season's dates. Darker grays for more recent seasons
past_seasons <- list(
  "2022-23" = list(
    start = "2022-09-01",
    end = "2023-06-01",
    years_back = 4,
    color = "#8c8c8c"
  ),
  "2023-24" = list(
    start = "2023-09-01",
    end = "2024-06-01",
    years_back = 3,
    color = "#6e6e6e"
  ),
  "2024-25" = list(
    start = "2024-09-01",
    end = "2025-06-01",
    years_back = 2,
    color = "#505050"
  ),
  "2025-26" = list(
    start = "2025-09-01",
    end = "2026-06-01",
    years_back = 1,
    color = "#303030"
  )
)
for (season in names(past_seasons)) {
  s <- past_seasons[[season]]
  p <- p +
    ggplot2::geom_line(
      data = target_data |>
        dplyr::filter(
          target_end_date >= s$start,
          target_end_date <= s$end,
          !is.na(location_name)
        ) |>
        dplyr::mutate(
          target_end_date = target_end_date + s$years_back * 365,
          legend = season
        ),
      mapping = ggplot2::aes(
        x = target_end_date,
        y = observation,
        color = legend
      ),
      alpha = 0.8,
      linewidth = 0.6,
      inherit.aes = FALSE
    )
}

# this season's observed data
observed_color <- "#000000"
observed <- target_data |>
  dplyr::filter(
    target_end_date >= data_start,
    target_end_date <= data_end,
    !is.na(location_name)
  ) |>
  dplyr::mutate(legend = "Observed")
p <- p +
  ggplot2::geom_line(
    data = observed,
    mapping = ggplot2::aes(
      x = target_end_date,
      y = observation,
      color = legend
    ),
    inherit.aes = FALSE
  ) +
  ggplot2::geom_point(
    data = observed,
    mapping = ggplot2::aes(
      x = target_end_date,
      y = observation,
      color = legend
    ),
    size = 0.8,
    inherit.aes = FALSE
  )

# highlight the trajectories at the 10th/50th/90th percentiles of each location's season total (the sum of its
# weekly values over the plotted horizons). Weeks before the forecast are the same for every trajectory, so this
# ranks them the same as a season-to-date total would. A sum of weekly percentages is only a proxy for cumulative
# incidence, but it's fine for ranking trajectories within a location
highlights <- list(
  "10th pct. season total" = list(quantile = 0.1, color = "#44a585"),
  "50th pct. season total" = list(quantile = 0.5, color = "#1f7d60"),
  "90th pct. season total" = list(quantile = 0.9, color = "#0e5541")
)
trajectory_ranks <- forecasts_trajectories |>
  dplyr::group_by(location_name, output_type_id) |>
  dplyr::summarize(total = sum(value), .groups = "drop_last") |>
  dplyr::arrange(total, .by_group = TRUE) |>
  dplyr::mutate(rank = dplyr::row_number(), n = dplyr::n()) |>
  dplyr::ungroup()
for (label in names(highlights)) {
  # with 100 trajectories, the 10th percentile is the trajectory ranked 10th, etc.
  picked <- trajectory_ranks |>
    dplyr::filter(rank == pmax(1, ceiling(highlights[[label]]$quantile * n))) |>
    dplyr::select(location_name, output_type_id)
  p <- p +
    ggplot2::geom_line(
      data = forecasts_trajectories |>
        dplyr::semi_join(picked, by = c("location_name", "output_type_id")) |>
        dplyr::mutate(legend = label),
      mapping = ggplot2::aes(
        x = target_end_date,
        y = value,
        group = output_type_id,
        color = legend
      ),
      inherit.aes = FALSE
    )
}

# median across trajectories, added last so it's drawn on top of the trajectories and past seasons
median_trajectory <- forecasts_trajectories |>
  dplyr::group_by(location_name, target_end_date) |>
  dplyr::summarize(value = stats::median(value), .groups = "drop") |>
  dplyr::mutate(legend = "Median")
median_color <- "#4a86d4"
p <- p +
  ggplot2::geom_line(
    data = median_trajectory,
    mapping = ggplot2::aes(x = target_end_date, y = value, color = legend),
    linewidth = 0.6,
    alpha = 0.8,
    inherit.aes = FALSE
  )

# one color legend for everything: this replaces hubVis' color scale, so it repeats hubVis' color for the model's
# trajectories (the first color of its default "Set2" palette)
legend_colors <- c(
  "Observed" = observed_color,
  "UMass-SAR" = RColorBrewer::brewer.pal(3, "Set2")[1],
  "Median" = median_color,
  vapply(highlights, \(h) h$color, character(1)),
  vapply(past_seasons, \(s) s$color, character(1))
)
p <- p +
  ggplot2::scale_color_manual(
    name = "Legend",
    values = legend_colors,
    breaks = names(legend_colors)
  )

p <- p + ggplot2::theme_bw() + ggplot2::theme(legend.position = "top")

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
