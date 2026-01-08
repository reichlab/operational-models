library(dplyr)
library(hubData)


# ref_date <- as.Date(args[1])
ref_date <- "2025-11-29"

counties_to_drop <- c("NYC")
ref_date <- as.Date(args[1])
data_date <- ref_date - 3

locations <- read.csv("https://raw.githubusercontent.com/reichlab/flu-metrocast/refs/heads/main/auxiliary-data/locations.csv")
locations_to_drop <- locations |>
  dplyr::filter(location_name %in% counties_to_drop) |>
  dplyr::pull(location)

selected_model <- "UMass-SAR"
input_dir <- "output/model-output/UMass-SAR"

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
