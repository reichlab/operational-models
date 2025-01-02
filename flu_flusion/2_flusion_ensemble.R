library(dplyr)
library(hubData)
library(hubEnsembles)


args <- commandArgs(trailingOnly = TRUE)
ref_date <- as.Date(args[1])

hub_con <- hubData::connect_model_output("intermediate-output/model-output")

# load components and create ensembles
model_out_tbl <- dplyr::collect(hub_con) |>
  dplyr::filter(reference_date == ref_date, horizon >= 0) |>
  hubEnsembles::simple_ensemble(model_id = "UMass-flusion")

# add categorical target predictions
target_ts <- readr::read_csv("https://raw.githubusercontent.com/cdcepi/FluSight-forecast-hub/main/target-data/target-hospital-admissions.csv")
location_meta <- readr::read_csv("https://raw.githubusercontent.com/cdcepi/FluSight-forecast-hub/refs/heads/main/auxiliary-data/locations.csv")
bin_endpoints <- idforecastutils::get_flusight_bin_endpoints(
  target_ts = target_ts,
  location_meta = location_meta,
  season = "2024/25"
)
categorical_outputs <- idforecastutils::transform_quantile_to_pmf(
  model_out_tbl = model_out_tbl,
  bin_endpoints = bin_endpoints
) |>
  dplyr::mutate(target = "wk flu hosp rate change") |>
  ungroup()

model_out_tbl <- dplyr::bind_rows(
  model_out_tbl |> dplyr::mutate(output_type_id = as.character(output_type_id)),
  categorical_outputs
)

# save
reference_date <- model_out_tbl$reference_date[1]

output_dir <- "output/model-output/UMass-flusion"
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

utils::write.csv(
  model_out_tbl |> dplyr::select(-model_id),
  file = file.path(
    output_dir,
    paste0(reference_date, "-UMass-flusion.csv")
  ),
  row.names = FALSE
)
