library(dplyr)
library(hubData)
library(hubEnsembles)


ref_date <- "2024-11-23"

abbreviations_to_drop <- c("DC", "ME", "MA", "MI", "PA", "US", "WY", "NM", "SD", "WI")
locations <- read.csv("https://raw.githubusercontent.com/cdcepi/FluSight-forecast-hub/refs/heads/main/auxiliary-data/locations.csv")
locations_to_drop <- locations |>
  dplyr::filter(abbreviation %in% abbreviations_to_drop) |>
  dplyr::pull(location)


selected_model <- "UMass-gbqr"
input_dir <- "output/model-output/UMass-gbqr"

forecasts <- readr::read_csv(file.path(input_dir, paste0(ref_date, "-", selected_model, ".csv"))) |>
  dplyr::filter(!location %in% locations_to_drop)

output_dir <- paste0("final-output/model-output/", selected_model)
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

utils::write.csv(
  forecasts,
  file = file.path(
    output_dir,
    paste0(ref_date, "-", selected_model, ".csv")
  ),
  row.names = FALSE
)
