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


# save
reference_date <- model_out_tbl$reference_date[1]

output_dir <- "output/model-output/UMass-flusion"
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

utils::write.csv(
  model_out_tbl |>
    dplyr::mutate(output_type_id = as.character(output_type_id))
    |> dplyr::select(-model_id),
  file = file.path(
    output_dir,
    paste0(reference_date, "-UMass-flusion.csv")
  ),
  row.names = FALSE
)
