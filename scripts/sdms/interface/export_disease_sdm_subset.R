#!/usr/bin/env Rscript
################################################################################
# export_disease_sdm_subset.R
################################################################################
# Purpose: Copy disease-filtered ready SDM files from the consolidated bundle
#          into a small reproducible subset folder.
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

parse_cli_args <- function(args) {
  out <- list()
  if (length(args) == 0) {
    return(out)
  }

  idx <- 1
  while (idx <= length(args)) {
    key <- args[[idx]]
    if (!startsWith(key, "--")) {
      stop("Unexpected argument: ", key, call. = FALSE)
    }

    key <- sub("^--", "", key)
    next_idx <- idx + 1
    if (next_idx > length(args) || startsWith(args[[next_idx]], "--")) {
      out[[key]] <- TRUE
      idx <- idx + 1
    } else {
      out[[key]] <- args[[next_idx]]
      idx <- idx + 2
    }
  }

  out
}

arg_value <- function(args, key, default = NULL) {
  if (!is.null(args[[key]])) {
    return(args[[key]])
  }
  default
}

arg_flag <- function(args, key, default = FALSE) {
  x <- arg_value(args, key, default)
  if (is.logical(x)) {
    return(isTRUE(x))
  }
  tolower(trimws(as.character(x))) %in% c("true", "t", "yes", "y", "1")
}

split_cli_arg <- function(x) {
  if (is.null(x) || isTRUE(is.na(x))) {
    return(NULL)
  }
  x <- unlist(strsplit(as.character(x), ",|;", perl = TRUE), use.names = FALSE)
  x <- trimws(x)
  x <- x[nzchar(x)]
  if (length(x) == 0) {
    return(NULL)
  }
  unique(x)
}

copy_one_file <- function(source_path, target_path, overwrite = FALSE, dry_run = FALSE) {
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

file_specs_for_row <- function(row, bundle_root, include_files) {
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

make_subset_output_dir <- function(output_root, analysis_unit_ids) {
  id_token <- if (length(analysis_unit_ids) == 1) {
    analysis_unit_ids[[1]]
  } else {
    paste0("multi_", length(analysis_unit_ids))
  }

  dir_name <- paste(timestamp_file(), safe_path_token(id_token), "sdm_subset", sep = "_")
  output_dir <- file.path(output_root, dir_name)
  suffix <- 1
  while (dir.exists(output_dir)) {
    output_dir <- file.path(output_root, paste0(dir_name, "_", suffix))
    suffix <- suffix + 1
  }
  ensure_dir(output_dir)
}

args <- parse_cli_args(commandArgs(trailingOnly = TRUE))

bundle_root <- normalizePath(
  arg_value(args, "bundle-root", default_ready_sdm_bundle_root()),
  winslash = "/",
  mustWork = TRUE
)
analysis_unit_ids <- split_cli_arg(arg_value(args, "analysis-unit-ids"))
if (is.null(analysis_unit_ids)) {
  stop("Use `--analysis-unit-ids` with one or more disease IDs, for example `master_4`.", call. = FALSE)
}

species_roles <- split_cli_arg(arg_value(args, "species-roles", "host,vector"))
host_role_buckets <- split_cli_arg(arg_value(args, "host-role-buckets"))
host_detection_methods <- split_cli_arg(arg_value(args, "host-detection-methods"))
vector_role_buckets <- split_cli_arg(arg_value(args, "vector-role-buckets"))
evidence_tiers <- split_cli_arg(arg_value(args, "evidence-tiers"))
include_files <- split_cli_arg(arg_value(args, "include-files", "model,continuous,tss,summary"))
output_root <- arg_value(args, "output-root", file.path(bundle_root, "disease_sdm_subsets"))
overwrite <- arg_flag(args, "overwrite", FALSE)
dry_run <- arg_flag(args, "dry-run", FALSE)

valid_files <- c("model", "continuous", "tss", "summary")
bad_files <- setdiff(include_files, valid_files)
if (length(bad_files) > 0) {
  stop("Unsupported `--include-files` values: ", paste(bad_files, collapse = ", "), call. = FALSE)
}

selection <- preview_sdm_selection(
  bundle_root = bundle_root,
  analysis_unit_ids = analysis_unit_ids,
  species_roles = species_roles,
  host_role_buckets = host_role_buckets,
  host_detection_methods = host_detection_methods,
  vector_role_buckets = vector_role_buckets,
  evidence_tiers = evidence_tiers
)

selected <- selection$selected
excluded <- selection$excluded
if (nrow(selected) == 0) {
  stop("No SDM-backed species selected after applying filters.", call. = FALSE)
}

output_dir <- make_subset_output_dir(output_root, analysis_unit_ids)
selected_path <- file.path(output_dir, "selected_species.csv")
excluded_path <- file.path(output_dir, "excluded_species.csv")
copy_manifest_path <- file.path(output_dir, "copy_manifest.csv")
run_manifest_path <- file.path(output_dir, "run_manifest.csv")

copy_rows <- list()
for (idx in seq_len(nrow(selected))) {
  row <- selected[idx, , drop = FALSE]
  species_dir <- safe_path_token(row$species_name)
  role_dir <- paste0(row$species_role, "s")
  target_dir <- file.path(output_dir, role_dir, species_dir)
  specs <- file_specs_for_row(row, bundle_root, include_files)

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
      copy_one_file(
        specs$source_path[[file_idx]],
        file.path(target_dir, specs$file_name[[file_idx]]),
        overwrite = overwrite,
        dry_run = dry_run
      )
    )
  }
}

copy_manifest <- dplyr::bind_rows(copy_rows)
readr::write_csv(selected, selected_path, na = "")
readr::write_csv(excluded, excluded_path, na = "")
readr::write_csv(copy_manifest, copy_manifest_path, na = "")

run_manifest <- tibble::tibble(
  generated_at_utc = timestamp_utc(),
  bundle_root = bundle_root,
  output_dir = output_dir,
  dry_run = dry_run,
  overwrite = overwrite,
  analysis_unit_ids = collapse_unique(analysis_unit_ids),
  species_roles = collapse_unique(species_roles),
  host_role_buckets = collapse_unique(host_role_buckets),
  host_detection_methods = collapse_unique(host_detection_methods),
  vector_role_buckets = collapse_unique(vector_role_buckets),
  evidence_tiers = collapse_unique(evidence_tiers),
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
message("Copy manifest: ", copy_manifest_path)
