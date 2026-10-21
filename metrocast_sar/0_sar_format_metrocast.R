library(dplyr)
library(hubData)

args <- commandArgs(trailingOnly = TRUE)
ref_date <- as.Date(args[1])

locations <- read.csv(
  "https://raw.githubusercontent.com/reichlab/flu-metrocast/refs/heads/main/auxiliary-data/locations.csv"
)
fips_mappings <- readr::read_csv(
  "https://infectious-disease-data.s3.amazonaws.com/data-raw/fips-mappings/fips_mappings.csv"
) |>
  dplyr::rename(fips_code = "location", state_name = "location_name")
locations_meta <- locations |>
  dplyr::left_join(
    fips_mappings,
    by = c("state_abb" = "abbreviation", "state" = "state_name")
  ) |>
  dplyr::mutate(
    agg_level = ifelse(original_location_code == "All", "state", "hsa"),
    loc_code = ifelse(agg_level == "state", fips_code, original_location_code)
  ) |>
  # sub-state locations also include non-HSA regions (e.g. Utah and North Carolina regions) whose codes overlap
  # HSA codes (Utah region "9" vs. Maine HSA "9"), so only match model HSAs to HSA locations
  dplyr::filter(agg_level == "state" | location_type == "hsa_nci_id")

# load components and rename locations
outputs_path <- "intermediate-output/model-output"
model_outputs <- read.csv(paste0(
  outputs_path,
  "/UMass-SAR/",
  ref_date,
  "-UMass-SAR.csv"
)) |>
  dplyr::mutate(
    location = ifelse(agg_level == "state", sprintf("%02g", location), location)
  ) |>
  dplyr::rename(loc_code = location) |>
  dplyr::filter(reference_date == ref_date, horizon >= 0) |>
  dplyr::left_join(locations_meta, by = c("loc_code", "agg_level"))

unmatched <- model_outputs |>
  dplyr::filter(is.na(location)) |>
  dplyr::distinct(agg_level, loc_code)
if (nrow(unmatched) > 0) {
  stop("No flu-metrocast location for: ", paste(unmatched$agg_level, unmatched$loc_code, collapse = ", "))
}

model_outputs <- model_outputs |>
  dplyr::mutate(
    target = "Flu ED visits pct",
    value = value * 100, # prop -> pct
    # sample ids must be unique across locations: idmodels numbers each location's draws 1-100, so prefix them
    # with the location name (e.g. "denver1"), which never ends in a digit
    output_type_id = paste0(location, as.integer(output_type_id)),
    # parquet keeps column types, so match the hub schema's date columns
    reference_date = as.Date(reference_date),
    target_end_date = as.Date(target_end_date)
  ) |>
  dplyr::arrange(state_abb) |>
  dplyr::select( # horizon isn't a task id in the hub, so it's dropped
    "reference_date",
    "location",
    "target",
    "target_end_date",
    "output_type",
    "output_type_id",
    "value"
  )

# save
reference_date <- model_outputs$reference_date[1]

output_dir <- "output/model-output/UMass-SAR"
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

# the hub only accepts parquet submissions
arrow::write_parquet(
  model_outputs,
  file.path(
    output_dir,
    paste0(reference_date, "-UMass-SAR.parquet")
  )
)
