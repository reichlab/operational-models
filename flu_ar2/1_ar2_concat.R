library(dplyr)
library(hubData)

args <- commandArgs(trailingOnly = TRUE)
ref_date <- as.Date(args[1])
data_date <- ref_date - 3

hub_con <- hubData::connect_model_output("intermediate-output/model-output")

# load components and concatenate
model_out_tbl <- dplyr::collect(hub_con) |>
    dplyr::filter(reference_date == ref_date, horizon >= 0) |>
    dplyr::mutate(model_id = "UMass-AR2", horizon = as.integer(horizon))

# save
reference_date <- model_out_tbl$reference_date[1]

output_dir <- "output/model-output/UMass-AR2"
if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
}

utils::write.csv(
    model_out_tbl |> dplyr::select(-model_id),
    file = file.path(
        output_dir,
        paste0(reference_date, "-UMass-AR2.csv")
    ),
    row.names = FALSE
)
