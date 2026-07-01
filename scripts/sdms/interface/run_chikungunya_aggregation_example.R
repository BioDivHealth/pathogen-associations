#!/usr/bin/env Rscript
################################################################################
# run_chikungunya_aggregation_example.R
################################################################################
# Purpose: Non-interactive smoke run for the global ready-SDM aggregation helper.
################################################################################

suppressPackageStartupMessages({
})

script_path <- {
  args_all <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args_all, value = TRUE)
  if (length(file_arg) > 0) {
    normalizePath(sub("^--file=", "", file_arg[[1]]), winslash = "/", mustWork = FALSE)
  } else {
    frame_paths <- vapply(sys.frames(), function(frame) {
      if (is.null(frame$ofile)) "" else frame$ofile
    }, character(1))
    frame_paths <- frame_paths[nzchar(frame_paths)]
    if (length(frame_paths) > 0) normalizePath(tail(frame_paths, 1), winslash = "/", mustWork = FALSE) else NA_character_
  }
}
local_helper_path <- if (!is.na(script_path)) file.path(dirname(script_path), "aggregation_helpers.R") else "aggregation_helpers.R"
if (file.exists(local_helper_path)) {
  source(local_helper_path)
} else {
  if (!requireNamespace("here", quietly = TRUE)) {
    stop("Package `here` is required when running from the repository checkout.", call. = FALSE)
  }
  source(here::here("scripts", "sdms", "interface", "aggregation_helpers.R"))
}

bundle_root <- default_ready_sdm_bundle_root()

result <- run_sdm_aggregation(
  bundle_root = bundle_root,
  analysis_unit_ids = "master_4",
  species_roles = "vector",
  vector_role_buckets = c("primary_or_main_vector", "competence_supported_vector"),
  raster_mode = "model_threshold_binary",
  model_threshold_method = "tss_test_mean",
  aggregation_mode = "binary_richness",
  geometry_strategy = "extend_to_union",
  geometry_fill_value = 0,
  internal_na_fill_value = 0
)

message("Chikungunya aggregation complete")
message("Output directory: ", result$output_dir)
message("Selected species: ", nrow(result$selected_species))
message("Excluded species: ", nrow(result$excluded_species))
message("Aggregate GeoTIFF: ", result$aggregate_path)
message("Preview PNG: ", result$preview_path)
