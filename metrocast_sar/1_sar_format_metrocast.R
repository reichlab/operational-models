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
  )

# load components and rename locations
# outputs_path <- "intermediate-output/model-output"
outputs_path <- "output/model-output/"
model_outputs <- read.csv(paste0(
  outputs_path,
  #  "/UMass-SAR/",
  ref_date,
  "-UMass-SAR.csv"
)) |>
  dplyr::mutate(
    model_id = model_name,
    location = ifelse(agg_level == "state", sprintf("%02g", location), location)
  ) |>
  dplyr::rename(loc_code = location) |>
  dplyr::filter(reference_date == ref_date, horizon >= 0) |>
  dplyr::left_join(locations_meta, by = c("loc_code", "agg_level")) |>
  dplyr::mutate(target = "Flu ED visits pct", value = value * 100) |> # prop -> pct
  dplyr::arrange(state_abb) |>
  dplyr::select(
    "reference_date",
    "location",
    "horizon",
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

utils::write.csv(
  model_outputs,
  file = file.path(
    output_dir,
    paste0(reference_date, "-UMass-SAR.csv")
  ),
  row.names = FALSE
)
