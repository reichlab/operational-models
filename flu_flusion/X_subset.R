library(dplyr)
library(hubData)
library(hubEnsembles)


# ref_date <- as.Date(args[1])
ref_date <- "2024-11-30"

abbreviations_to_drop <- c("OH")
locations <- read.csv("https://raw.githubusercontent.com/cdcepi/FluSight-forecast-hub/refs/heads/main/auxiliary-data/locations.csv")
locations_to_drop <- locations |>
  dplyr::filter(abbreviation %in% abbreviations_to_drop) |>
  dplyr::pull(location)

selected_model <- "UMass-flusion"
input_dir <- "output/model-output/UMass-flusion"

forecasts <- readr::read_csv(file.path(input_dir, paste0(ref_date, "-", selected_model, ".csv"))) |>
  dplyr::filter(!location %in% locations_to_drop)

# save
output_dir <- paste0("final-output/model-output/UMass-", selected_model)
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
