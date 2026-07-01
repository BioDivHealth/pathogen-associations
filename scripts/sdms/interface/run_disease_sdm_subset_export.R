################################################################################
# run_disease_sdm_subset_export.R
################################################################################
# Purpose: RStudio-friendly disease SDM subset export.
#
# Open this file, edit the config block below, then click Source.
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

# Edit this block --------------------------------------------------------------

disease_sdm_subset_config <- list(
  bundle_root = default_ready_sdm_bundle_root(),

  # Use IDs from readiness/interface_inputs/disease_summary.csv.
  # Examples:
  #   Chikungunya fever = "master_4"
  #   Yellow fever = "master_5"
  analysis_unit_ids = c("master_4"),

  # Use "host", "vector", or both.
  species_roles = c("vector"),

  # Leave NULL to include all matching buckets.
  host_role_buckets = NULL,
  host_detection_methods = NULL,
  vector_role_buckets = c("primary_or_main_vector", "competence_supported_vector"),
  evidence_tiers = NULL,

  # Files to copy. Options: "model", "continuous", "tss", "summary".
  include_files = c("model", "continuous", "tss", "summary"),

  # Output folder. A timestamped subfolder is created inside this.
  output_root = file.path(default_ready_sdm_bundle_root(), "disease_sdm_subsets"),

  # Set dry_run = TRUE to only write manifests without copying SDM files.
  dry_run = FALSE,
  overwrite = FALSE
)

# Export helpers ---------------------------------------------------------------

copy_subset_file <- function(source_path, target_path, overwrite = FALSE, dry_run = FALSE) {
  exists <- !is.na(source_path) && nzchar(source_path) && file.exists(source_path)
  if (!exists) {
    return(data.frame(
      source_path = source_path,
      target_path = target_path,
      copied = FALSE,
      status = "missing_source",
      stringsAsFactors = FALSE
    ))
  }

  if (file.exists(target_path) && !overwrite) {
    return(data.frame(
      source_path = source_path,
      target_path = target_path,
      copied = FALSE,
      status = "exists_not_overwritten",
      stringsAsFactors = FALSE
    ))
  }

  if (dry_run) {
    return(data.frame(
      source_path = source_path,
      target_path = target_path,
      copied = FALSE,
      status = "dry_run",
      stringsAsFactors = FALSE
    ))
  }

  dir.create(dirname(target_path), recursive = TRUE, showWarnings = FALSE)
  ok <- file.copy(source_path, target_path, overwrite = overwrite, copy.date = TRUE)
  data.frame(
    source_path = source_path,
    target_path = target_path,
    copied = isTRUE(ok),
    status = if (isTRUE(ok)) "copied" else "copy_failed",
    stringsAsFactors = FALSE
  )
}

subset_file_specs <- function(row, bundle_root, include_files) {
  specs <- list()

  if ("model" %in% include_files && "sdm_model_rds" %in% names(row)) {
    specs$model.rds <- row$sdm_model_rds
  }
  if ("continuous" %in% include_files && "map_layer_default" %in% names(row)) {
    specs$ensemble_mean.tif <- row$map_layer_default
  }
  if ("tss" %in% include_files && "map_layer_thresholded" %in% names(row)) {
    specs$ensemble_tss_clipped.tif <- row$map_layer_thresholded
  }
  if ("summary" %in% include_files && "sdm_prediction_summary" %in% names(row)) {
    specs$prediction_run_summary.csv <- row$sdm_prediction_summary
  }

  data.frame(
    file_name = names(specs),
    source_path = file.path(bundle_root, unlist(specs, use.names = FALSE)),
    stringsAsFactors = FALSE
  )
}

make_subset_export_dir <- function(output_root, analysis_unit_ids) {
  id_token <- if (length(analysis_unit_ids) == 1) {
    analysis_unit_ids[[1]]
  } else {
    paste0("multi_", length(analysis_unit_ids))
  }

  output_dir <- file.path(
    output_root,
    paste(timestamp_file(), safe_path_token(id_token), "sdm_subset", sep = "_")
  )

  suffix <- 1
  while (dir.exists(output_dir)) {
    output_dir <- file.path(
      output_root,
      paste0(basename(output_dir), "_", suffix)
    )
    suffix <- suffix + 1
  }

  ensure_dir(output_dir)
}

run_disease_sdm_subset_export <- function(config = disease_sdm_subset_config) {
  bundle_root <- normalizePath(config$bundle_root, winslash = "/", mustWork = TRUE)
  include_files <- normalize_filter(config$include_files)
  valid_files <- c("model", "continuous", "tss", "summary")
  bad_files <- setdiff(include_files, valid_files)
  if (length(bad_files) > 0) {
    stop("Unsupported include_files values: ", paste(bad_files, collapse = ", "), call. = FALSE)
  }

  selection <- preview_sdm_selection(
    bundle_root = bundle_root,
    analysis_unit_ids = config$analysis_unit_ids,
    species_roles = config$species_roles,
    host_role_buckets = config$host_role_buckets,
    host_detection_methods = config$host_detection_methods,
    vector_role_buckets = config$vector_role_buckets,
    evidence_tiers = config$evidence_tiers
  )

  selected <- selection$selected
  excluded <- selection$excluded
  if (nrow(selected) == 0) {
    stop("No SDM-backed species selected after applying filters.", call. = FALSE)
  }

  output_dir <- make_subset_export_dir(config$output_root, config$analysis_unit_ids)
  copy_rows <- list()

  for (idx in seq_len(nrow(selected))) {
    row <- selected[idx, , drop = FALSE]
    target_dir <- file.path(
      output_dir,
      paste0(row$species_role, "s"),
      safe_path_token(row$species_name)
    )
    specs <- subset_file_specs(row, bundle_root, include_files)

    for (file_idx in seq_len(nrow(specs))) {
      copy_rows[[length(copy_rows) + 1]] <- cbind(
        data.frame(
          analysis_unit_id = row$analysis_unit_id,
          readiness_disease_name = row$readiness_disease_name,
          species_role = row$species_role,
          species_name = row$species_name,
          file_name = specs$file_name[[file_idx]],
          stringsAsFactors = FALSE
        ),
        copy_subset_file(
          specs$source_path[[file_idx]],
          file.path(target_dir, specs$file_name[[file_idx]]),
          overwrite = isTRUE(config$overwrite),
          dry_run = isTRUE(config$dry_run)
        )
      )
    }
  }

  copy_manifest <- dplyr::bind_rows(copy_rows)
  selected_path <- file.path(output_dir, "selected_species.csv")
  excluded_path <- file.path(output_dir, "excluded_species.csv")
  copy_manifest_path <- file.path(output_dir, "copy_manifest.csv")
  run_manifest_path <- file.path(output_dir, "run_manifest.csv")

  readr::write_csv(selected, selected_path, na = "")
  readr::write_csv(excluded, excluded_path, na = "")
  readr::write_csv(copy_manifest, copy_manifest_path, na = "")

  run_manifest <- tibble::tibble(
    generated_at_utc = timestamp_utc(),
    bundle_root = bundle_root,
    output_dir = output_dir,
    dry_run = isTRUE(config$dry_run),
    overwrite = isTRUE(config$overwrite),
    analysis_unit_ids = collapse_unique(config$analysis_unit_ids),
    species_roles = collapse_unique(config$species_roles),
    host_role_buckets = collapse_unique(config$host_role_buckets),
    host_detection_methods = collapse_unique(config$host_detection_methods),
    vector_role_buckets = collapse_unique(config$vector_role_buckets),
    evidence_tiers = collapse_unique(config$evidence_tiers),
    include_files = collapse_unique(include_files),
    selected_species_count = nrow(selected),
    excluded_species_count = nrow(excluded),
    copied_file_count = sum(copy_manifest$copied, na.rm = TRUE),
    missing_source_count = sum(copy_manifest$status == "missing_source", na.rm = TRUE),
    selected_species_csv = selected_path,
    excluded_species_csv = excluded_path,
    copy_manifest_csv = copy_manifest_path
  )
  readr::write_csv(run_manifest, run_manifest_path, na = "")

  message("Disease SDM subset export complete")
  message("Output directory: ", output_dir)
  message("Selected species: ", nrow(selected))
  message("Excluded species: ", nrow(excluded))
  message("Copied files: ", sum(copy_manifest$copied, na.rm = TRUE))

  invisible(list(
    output_dir = output_dir,
    selected_species = selected,
    excluded_species = excluded,
    copy_manifest = copy_manifest,
    run_manifest = run_manifest
  ))
}

# Run export -------------------------------------------------------------------

if (isTRUE(getOption("ready_sdm_subset_export.run", TRUE))) {
  export_result <- run_disease_sdm_subset_export(disease_sdm_subset_config)
}
