#!/usr/bin/env Rscript
################################################################################
# consolidate_ready_sdms.R
################################################################################
# Purpose: Copy complete host/vector SDM deliverables into one LaCie folder,
#          keeping one preferred model per species and recording provenance.
#
# Usage from repo root:
#   batch_config <- list(dry_run = FALSE)
#   source("scripts/sdms/consolidate_ready_sdms.R")
#
# By default this is a dry run. It writes only when `dry_run = FALSE`.
################################################################################

# ------------------------------------------------------------------------------
#      Configuration ------------------------------------------------------------
# ------------------------------------------------------------------------------
default_config <- list(
  target_root = "/Volumes/LaCie/new_global_maxent/sdms/consolidated_ready_sdms_20260630",
  gonzalo_model_root = "/Volumes/LaCie/new_global_maxent/sdms/models",
  gonzalo_prediction_root = "/Volumes/LaCie/gonzalo_host_prediction_outputs_20260629/hosts_gonzalo_predictions",
  server_result_root = "/Volumes/LaCie/host_vector_sdm_results_20260624",
  dry_run = TRUE,
  overwrite = FALSE
)

if (!exists("batch_config", inherits = FALSE)) {
  batch_config <- list()
}

cfg <- modifyList(default_config, batch_config)

# ------------------------------------------------------------------------------
#      Helpers -----------------------------------------------------------------
# ------------------------------------------------------------------------------
safe_species_name <- function(x) {
  x <- trimws(as.character(x))
  x <- gsub("[^A-Za-z0-9]+", "_", x)
  gsub("^_+|_+$", "", x)
}

ensure_dir <- function(path) {
  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE, showWarnings = FALSE)
  }
  path
}

relative_path <- function(path, root) {
  sub(paste0("^", gsub("([][{}()+*^$|\\\\?.])", "\\\\\\1", root), "/?"), "", path)
}

read_prediction_status <- function(path) {
  if (!file.exists(path)) {
    return(NA_character_)
  }

  summary <- tryCatch(
    utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE),
    error = function(e) NULL
  )

  if (is.null(summary) || !"status" %in% names(summary) || nrow(summary) == 0) {
    return(NA_character_)
  }

  as.character(summary$status[[1]])
}

list_real_files <- function(root, pattern = NULL) {
  files <- list.files(root, pattern = pattern, recursive = TRUE, full.names = TRUE)
  files[!startsWith(basename(files), "._")]
}

as_csv <- function(data, path) {
  utils::write.csv(data, path, row.names = FALSE, na = "")
}

failure_reasons <- function(has_model, has_mean, has_tss, status) {
  reasons <- character()
  if (!has_model) {
    reasons <- c(reasons, "missing_model")
  }
  if (!has_mean) {
    reasons <- c(reasons, "missing_ensemble_mean")
  }
  if (!has_tss) {
    reasons <- c(reasons, "missing_tss_clipped")
  }
  if (is.na(status) || !identical(status, "completed")) {
    reasons <- c(reasons, paste0("status_", ifelse(is.na(status), "missing", status)))
  }
  paste(reasons, collapse = "; ")
}

copy_one <- function(from, to, overwrite = FALSE, dry_run = TRUE) {
  if (is.na(from) || !nzchar(from) || !file.exists(from)) {
    return(FALSE)
  }

  if (dry_run) {
    return(TRUE)
  }

  ensure_dir(dirname(to))
  file.copy(from, to, overwrite = overwrite, copy.mode = TRUE, copy.date = TRUE)
}

copy_id_for <- function(source_label, species_safe, existing_ids) {
  base <- source_label
  if (!base %in% existing_ids) {
    return(base)
  }

  idx <- 2L
  candidate <- paste0(base, "_", idx)
  while (candidate %in% existing_ids) {
    idx <- idx + 1L
    candidate <- paste0(base, "_", idx)
  }
  candidate
}

# ------------------------------------------------------------------------------
#      Discover Source Records --------------------------------------------------
# ------------------------------------------------------------------------------
required_roots <- c(
  cfg$gonzalo_model_root,
  cfg$gonzalo_prediction_root,
  file.path(cfg$server_result_root, "models"),
  file.path(cfg$server_result_root, "predictions")
)

missing_roots <- required_roots[!dir.exists(required_roots)]
if (length(missing_roots) > 0) {
  stop("Missing required source roots: ", paste(missing_roots, collapse = "; "), call. = FALSE)
}

gonzalo_model_files <- list_real_files(cfg$gonzalo_model_root, "[.]rds$")
gonzalo_model_species <- safe_species_name(basename(dirname(gonzalo_model_files)))
gonzalo_model_lookup <- split(gonzalo_model_files, gonzalo_model_species)

gonzalo_pred_dirs <- list.dirs(cfg$gonzalo_prediction_root, recursive = FALSE, full.names = TRUE)
gonzalo_records <- do.call(rbind, lapply(gonzalo_pred_dirs, function(pred_dir) {
  species_safe <- basename(pred_dir)
  model_paths <- gonzalo_model_lookup[[species_safe]]
  model_path <- if (length(model_paths) > 0) model_paths[[1]] else NA_character_
  summary_path <- file.path(pred_dir, "prediction_run_summary.csv")
  mean_path <- file.path(pred_dir, "ensemble_mean.tif")
  tss_path <- file.path(pred_dir, "ensemble_tss_clipped.tif")

  data.frame(
    role = "host",
    species_safe = species_safe,
    species = gsub("_", " ", species_safe),
    source_label = "gonzalo_reference",
    model_path = model_path,
    ensemble_mean_path = mean_path,
    ensemble_tss_clipped_path = tss_path,
    prediction_summary_path = summary_path,
    prediction_status = read_prediction_status(summary_path),
    has_model = !is.na(model_path) && file.exists(model_path),
    has_ensemble_mean = file.exists(mean_path),
    has_tss_clipped = file.exists(tss_path),
    stringsAsFactors = FALSE
  )
}))

server_model_root <- file.path(cfg$server_result_root, "models")
server_prediction_root <- file.path(cfg$server_result_root, "predictions")
server_model_files <- list_real_files(server_model_root, "[.]rds$")

server_records <- do.call(rbind, lapply(server_model_files, function(model_path) {
  rel <- relative_path(model_path, server_model_root)
  parts <- strsplit(rel, "/", fixed = TRUE)[[1]]
  context <- parts[[1]]
  species_safe <- parts[[2]]
  role <- if (identical(context, "vector_sdm_push")) "vector" else "host"
  pred_dir <- file.path(server_prediction_root, context, species_safe)
  summary_path <- file.path(pred_dir, "prediction_run_summary.csv")
  mean_path <- file.path(pred_dir, "ensemble_mean.tif")
  tss_path <- file.path(pred_dir, "ensemble_tss_clipped.tif")

  data.frame(
    role = role,
    species_safe = species_safe,
    species = gsub("_", " ", species_safe),
    source_label = "host_vector_server_rerun",
    model_path = model_path,
    ensemble_mean_path = mean_path,
    ensemble_tss_clipped_path = tss_path,
    prediction_summary_path = summary_path,
    prediction_status = read_prediction_status(summary_path),
    has_model = file.exists(model_path),
    has_ensemble_mean = file.exists(mean_path),
    has_tss_clipped = file.exists(tss_path),
    stringsAsFactors = FALSE
  )
}))

records <- rbind(gonzalo_records, server_records)
records$is_complete <- with(
  records,
  has_model & has_ensemble_mean & has_tss_clipped & prediction_status == "completed"
)

records$reason <- mapply(
  function(is_complete, has_model, has_mean, has_tss, status) {
    if (is_complete) {
      return("complete")
    }
    failure_reasons(has_model, has_mean, has_tss, status)
  },
  records$is_complete,
  records$has_model,
  records$has_ensemble_mean,
  records$has_tss_clipped,
  records$prediction_status,
  USE.NAMES = FALSE
)

complete <- records[records$is_complete, , drop = FALSE]
incomplete <- records[!records$is_complete, , drop = FALSE]

# ------------------------------------------------------------------------------
#      Select Preferred Source And Build Destination Plan -----------------------
# ------------------------------------------------------------------------------
complete$source_priority <- ifelse(complete$source_label == "host_vector_server_rerun", 1L, 2L)
complete$key <- paste(complete$role, complete$species_safe, sep = "::")
complete <- complete[order(complete$key, complete$source_priority), , drop = FALSE]

selected <- complete[!duplicated(complete$key), , drop = FALSE]
duplicate_complete <- complete[duplicated(complete$key), , drop = FALSE]

selected$role_dir <- ifelse(selected$role == "vector", "vectors", "hosts")
selected$species_dir <- file.path(cfg$target_root, selected$role_dir, selected$species_safe)
selected$copy_id <- selected$source_label
selected$dest_model_path <- file.path(selected$species_dir, "model.rds")
selected$dest_ensemble_mean_path <- file.path(selected$species_dir, "ensemble_mean.tif")
selected$dest_ensemble_tss_clipped_path <- file.path(selected$species_dir, "ensemble_tss_clipped.tif")
selected$dest_prediction_summary_path <- file.path(selected$species_dir, "prediction_run_summary.csv")

manifest_cols <- c(
  "role", "species", "species_safe", "source_label", "copy_id",
  "species_dir",
  "prediction_status", "model_path", "ensemble_mean_path",
  "ensemble_tss_clipped_path", "prediction_summary_path",
  "dest_model_path", "dest_ensemble_mean_path",
  "dest_ensemble_tss_clipped_path", "dest_prediction_summary_path"
)

summary <- data.frame(
  metric = c(
    "total_source_records",
    "complete_source_records",
    "selected_records",
    "incomplete_records",
    "duplicate_complete_records",
    "selected_hosts",
    "selected_vectors",
    "selected_gonzalo_hosts",
    "selected_server_hosts",
    "selected_server_vectors"
  ),
  value = c(
    nrow(records),
    nrow(complete),
    nrow(selected),
    nrow(incomplete),
    nrow(duplicate_complete),
    sum(selected$role == "host"),
    sum(selected$role == "vector"),
    sum(selected$source_label == "gonzalo_reference" & selected$role == "host"),
    sum(selected$source_label == "host_vector_server_rerun" & selected$role == "host"),
    sum(selected$source_label == "host_vector_server_rerun" & selected$role == "vector")
  ),
  stringsAsFactors = FALSE
)

cat("Target root:", cfg$target_root, "\n")
cat("Dry run:", cfg$dry_run, "\n")
print(summary, row.names = FALSE)

if (cfg$dry_run) {
  cat("Dry run only; no files were copied.\n")
  quit(save = "no", status = 0)
}

if (dir.exists(cfg$target_root) && length(list.files(cfg$target_root, all.files = TRUE, no.. = TRUE)) > 0 && !cfg$overwrite) {
  stop("Target root already exists and is not empty: ", cfg$target_root, call. = FALSE)
}

# ------------------------------------------------------------------------------
#      Copy Files And Write Manifests ------------------------------------------
# ------------------------------------------------------------------------------
ensure_dir(file.path(cfg$target_root, "hosts"))
ensure_dir(file.path(cfg$target_root, "vectors"))
ensure_dir(file.path(cfg$target_root, "manifests"))

copy_results <- data.frame(
  source_path = character(),
  dest_path = character(),
  copied = logical(),
  stringsAsFactors = FALSE
)

for (idx in seq_len(nrow(selected))) {
  row <- selected[idx, , drop = FALSE]
  pairs <- data.frame(
    source_path = c(
      row$model_path,
      row$ensemble_mean_path,
      row$ensemble_tss_clipped_path,
      row$prediction_summary_path
    ),
    dest_path = c(
      row$dest_model_path,
      row$dest_ensemble_mean_path,
      row$dest_ensemble_tss_clipped_path,
      row$dest_prediction_summary_path
    ),
    stringsAsFactors = FALSE
  )

  for (file_idx in seq_len(nrow(pairs))) {
    ok <- copy_one(
      pairs$source_path[[file_idx]],
      pairs$dest_path[[file_idx]],
      overwrite = cfg$overwrite,
      dry_run = FALSE
    )

    copy_results <- rbind(
      copy_results,
      data.frame(
        source_path = pairs$source_path[[file_idx]],
        dest_path = pairs$dest_path[[file_idx]],
        copied = ok,
        stringsAsFactors = FALSE
      )
    )
  }
}

manifest <- selected[, manifest_cols, drop = FALSE]
manifest$all_files_copied <- vapply(seq_len(nrow(manifest)), function(idx) {
  dests <- unname(unlist(manifest[idx, c(
    "dest_model_path",
    "dest_ensemble_mean_path",
    "dest_ensemble_tss_clipped_path",
    "dest_prediction_summary_path"
  )]))
  all(file.exists(dests))
}, logical(1))

as_csv(manifest, file.path(cfg$target_root, "manifests", "consolidated_ready_sdms_manifest.csv"))
as_csv(incomplete, file.path(cfg$target_root, "manifests", "incomplete_or_failed_sdms.csv"))
as_csv(duplicate_complete, file.path(cfg$target_root, "manifests", "duplicate_complete_sdms_not_copied.csv"))
as_csv(copy_results, file.path(cfg$target_root, "manifests", "copy_results.csv"))
as_csv(summary, file.path(cfg$target_root, "manifests", "copy_summary.csv"))

for (species_dir in unique(manifest$species_dir)) {
  species_manifest <- manifest[manifest$species_dir == species_dir, , drop = FALSE]
  as_csv(species_manifest, file.path(species_dir, "source_manifest.csv"))
}

readme <- c(
  "# Consolidated Ready SDMs",
  "",
  paste("Generated:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  "",
  "This folder copies complete host/vector SDM deliverables from the current LaCie source roots.",
  "A complete SDM has a model RDS, ensemble_mean.tif, ensemble_tss_clipped.tif, and a prediction_run_summary.csv with status completed.",
  "",
  "Source roots:",
  paste("- Gonzalo models:", cfg$gonzalo_model_root),
  paste("- Gonzalo predictions:", cfg$gonzalo_prediction_root),
  paste("- Host/vector server results:", cfg$server_result_root),
  "",
  "Layout:",
  "- hosts/<Species_safe>/",
  "- vectors/<Species_safe>/",
  "- manifests/",
  "",
  "Files inside species folders use plain names:",
  "- model.rds",
  "- ensemble_mean.tif",
  "- ensemble_tss_clipped.tif",
  "- prediction_run_summary.csv",
  "",
  "When a host species had both Gonzalo and server rerun versions, the server rerun version was kept.",
  "See manifests/consolidated_ready_sdms_manifest.csv for included files, manifests/incomplete_or_failed_sdms.csv for skipped failed/incomplete outputs, and manifests/duplicate_complete_sdms_not_copied.csv for complete duplicate inputs that were not copied."
)
writeLines(readme, file.path(cfg$target_root, "README.md"))

cat("Copy complete.\n")
cat("Manifest:", file.path(cfg$target_root, "manifests", "consolidated_ready_sdms_manifest.csv"), "\n")
