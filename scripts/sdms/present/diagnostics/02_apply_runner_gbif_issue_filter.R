#!/usr/bin/env Rscript
# -----------------------------------------------------------------------------|
# 02_apply_runner_gbif_issue_filter.R ----
# -----------------------------------------------------------------------------|
# Purpose: Apply the agreed GBIF issue policy to the portable host/vector SDM
#          runner occurrence inputs.
#
# Policy:
#   - keep GBIF records with basisOfRecord in HUMAN_OBSERVATION or
#     PRESERVED_SPECIMEN
#   - keep years in 2000-2026
#   - drop rows with any issue in the hard exclude or review issue lists
#   - do not apply GBIF issue rules to VectorMap/MapVEu local records
#
# Hosts are filtered in their existing `gbif-download/cleaned` files.
# Vectors are recombined from GBIF + VectorMap + MapVEu sources so local source
# records can fill coordinates after GBIF filtering.
# -----------------------------------------------------------------------------|

suppressPackageStartupMessages({
  if (!requireNamespace("data.table", quietly = TRUE)) {
    stop("Package `data.table` is required.", call. = FALSE)
  }
})

args <- commandArgs(trailingOnly = TRUE)

get_arg <- function(key, default = NULL) {
  prefix <- paste0("--", key, "=")
  hit <- grep(paste0("^", prefix), args, value = TRUE)
  if (length(hit) == 0) {
    return(default)
  }
  sub(prefix, "", hit[[length(hit)]])
}

split_arg <- function(x) {
  if (is.null(x) || length(x) == 0 || is.na(x) || !nzchar(trimws(x))) {
    return(character())
  }
  trimws(unlist(strsplit(x, ",", fixed = TRUE)))
}

safe_species_name <- function(x) {
  gsub("[^A-Za-z0-9]+", "_", trimws(x))
}

normalise_basis <- function(x) {
  toupper(gsub("[[:space:]]+", "_", trimws(as.character(x))))
}

split_issue_combo <- function(x) {
  value <- toupper(trimws(as.character(x)))
  value[is.na(value) | !nzchar(value)] <- NA_character_
  lapply(value, function(item) {
    if (is.na(item)) {
      return(character())
    }
    parts <- trimws(strsplit(item, ";", fixed = TRUE)[[1]])
    unique(parts[nzchar(parts)])
  })
}

has_disallowed_issue <- function(x, disallowed_issues) {
  issue_values <- split_issue_combo(x)
  vapply(issue_values, function(parts) any(parts %in% disallowed_issues), logical(1))
}

copy_with_dirs <- function(from, to) {
  dir.create(dirname(to), recursive = TRUE, showWarnings = FALSE)
  file.copy(from, to, overwrite = TRUE, copy.mode = TRUE, copy.date = TRUE)
}

update_if_present <- function(data, idx, col, value) {
  if (col %in% names(data)) {
    data[[col]][idx] <- value
  }
  data
}

repo_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
runner_root <- get_arg("runner-root", "/Volumes/LaCie/host_vector_sdm_runner")
vector_source_root <- get_arg(
  "vector-source-root",
  "/Volumes/LaCie/new_global_maxent/sdms/runs_artur/vector_sdm_push/occurrences"
)
vector_local_manifest <- get_arg(
  "vector-local-source-manifest",
  "/Volumes/LaCie/new_global_maxent/sdms/runs_artur/vector_sdm_push/local_vector_occurrence_sources_manifest.csv"
)

start_year <- as.integer(get_arg("start-year", "2000"))
end_year <- as.integer(get_arg("end-year", "2026"))
min_points <- as.integer(get_arg("min-points", "20"))
allowed_basis <- normalise_basis(split_arg(get_arg("allowed-basis", "HUMAN_OBSERVATION,PRESERVED_SPECIMEN")))

exclude_issues <- c(
  "TAXON_MATCH_HIGHERRANK",
  "TAXON_MATCH_FUZZY",
  "TAXON_MATCH_NAME_AND_ID_AMBIGUOUS",
  "SCIENTIFIC_NAME_AND_ID_INCONSISTENT",
  "COORDINATE_REPROJECTION_FAILED",
  "COORDINATE_REPROJECTION_SUSPICIOUS",
  "INDIVIDUAL_COUNT_CONFLICTS_WITH_OCCURRENCE_STATUS",
  "OCCURRENCE_STATUS_UNPARSABLE"
)

review_issues <- c(
  "COUNTRY_MISMATCH",
  "COUNTRY_INVALID",
  "CONTINENT_INVALID",
  "CONTINENT_COORDINATE_MISMATCH",
  "CONTINENT_COUNTRY_MISMATCH",
  "GEODETIC_DATUM_INVALID",
  "RECORDED_DATE_INVALID",
  "RECORDED_DATE_MISMATCH",
  "IDENTIFIED_DATE_INVALID",
  "IDENTIFIED_DATE_UNLIKELY",
  "INDIVIDUAL_COUNT_INVALID",
  "FOOTPRINT_WKT_INVALID",
  "FOOTPRINT_WKT_MISMATCH",
  "FOOTPRINT_SRS_INVALID",
  "SUSPECTED_TYPE"
)

disallowed_issues <- unique(c(exclude_issues, review_issues))

host_manifest_path <- file.path(runner_root, "sdms", "runs", "host_sdm_push", "host_species_sdm_targets_model_ready.csv")
vector_manifest_path <- file.path(runner_root, "sdms", "runs", "vector_sdm_push", "vector_species_sdm_targets_combined_v2_ready.csv")
host_occurrence_root <- file.path(runner_root, "data", "occurrences", "host")
vector_occurrence_root <- file.path(runner_root, "data", "occurrences", "vector")
run_root <- file.path(runner_root, "outputs", "issue_filtered_occurrences")
run_dir <- file.path(run_root, paste0(format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC"), "_pid", Sys.getpid()))
backup_root <- file.path(run_dir, "backups")
vector_combine_run_root <- file.path(run_dir, "vector_combine_runs")

for (path in c(host_manifest_path, vector_manifest_path, vector_local_manifest)) {
  if (!file.exists(path)) {
    stop("Missing required file: ", path, call. = FALSE)
  }
}

dir.create(run_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(backup_root, recursive = TRUE, showWarnings = FALSE)

# -----------------------------------------------------------------------------|
# Host GBIF cleaned occurrence filtering ----
# -----------------------------------------------------------------------------|

host_manifest <- data.table::fread(host_manifest_path, showProgress = FALSE)
host_manifest_backup <- file.path(backup_root, "host_species_sdm_targets_model_ready.csv")
copy_with_dirs(host_manifest_path, host_manifest_backup)

host_rows <- vector("list", nrow(host_manifest))
host_manifest_occurrence_paths <- character(nrow(host_manifest))
for (idx in seq_len(nrow(host_manifest))) {
  species <- host_manifest$species_name[[idx]]
  species_safe <- safe_species_name(species)
  occurrence_path <- file.path(
    host_occurrence_root,
    species_safe,
    "gbif-download",
    "cleaned",
    paste0(species_safe, "_cleaned.csv")
  )
  host_manifest_occurrence_paths[[idx]] <- occurrence_path

  if (!file.exists(occurrence_path)) {
    host_rows[[idx]] <- data.table::data.table(
      species_name = species,
      occurrence_path = occurrence_path,
      status = "missing_occurrence_file",
      rows_before = 0L,
      rows_after = 0L,
      removed_rows = 0L,
      passes_min_points = FALSE
    )
    next
  }

  backup_path <- file.path(backup_root, "host", species_safe, "gbif-download", "cleaned", basename(occurrence_path))
  copy_with_dirs(occurrence_path, backup_path)

  dat <- data.table::fread(occurrence_path, showProgress = FALSE)
  rows_before <- nrow(dat)
  basis <- if ("basisOfRecord" %in% names(dat)) normalise_basis(dat$basisOfRecord) else rep(NA_character_, rows_before)
  year <- if ("year" %in% names(dat)) suppressWarnings(as.integer(dat$year)) else rep(NA_integer_, rows_before)
  issue <- if ("issue" %in% names(dat)) dat$issue else rep(NA_character_, rows_before)

  keep <- basis %in% allowed_basis &
    !is.na(year) &
    year >= start_year &
    year <= end_year &
    !has_disallowed_issue(issue, disallowed_issues)

  filtered <- dat[keep]
  rows_after <- nrow(filtered)
  unique_coords <- if (rows_after > 0 && all(c("decimalLongitude", "decimalLatitude") %in% names(filtered))) {
    nrow(unique(filtered[, .(decimalLongitude, decimalLatitude)]))
  } else {
    rows_after
  }
  passes <- unique_coords >= min_points

  data.table::fwrite(filtered, occurrence_path, na = "")

  host_manifest <- update_if_present(host_manifest, idx, "occurrence_rows_clean", rows_after)
  host_manifest <- update_if_present(host_manifest, idx, "passes_min_points", passes)
  host_manifest <- update_if_present(host_manifest, idx, "run_status", if (passes) "occurrences_ready" else "cleaned_below_min_points")

  host_rows[[idx]] <- data.table::data.table(
    species_name = species,
    occurrence_path = occurrence_path,
    status = "filtered",
    rows_before = rows_before,
    rows_after = rows_after,
    removed_rows = rows_before - rows_after,
    unique_coordinate_rows = unique_coords,
    passes_min_points = passes,
    backup_path = backup_path
  )
}

all_host_occurrence_files <- list.files(
  host_occurrence_root,
  pattern = "_cleaned[.]csv$",
  recursive = TRUE,
  full.names = TRUE
)
all_host_occurrence_files <- all_host_occurrence_files[grepl("/gbif-download/cleaned/", all_host_occurrence_files)]
extra_host_files <- setdiff(
  normalizePath(all_host_occurrence_files, winslash = "/", mustWork = TRUE),
  normalizePath(host_manifest_occurrence_paths[file.exists(host_manifest_occurrence_paths)], winslash = "/", mustWork = TRUE)
)

extra_host_rows <- vector("list", length(extra_host_files))
for (idx in seq_along(extra_host_files)) {
  occurrence_path <- extra_host_files[[idx]]
  relative_path <- substring(
    occurrence_path,
    nchar(normalizePath(host_occurrence_root, winslash = "/", mustWork = TRUE)) + 2L
  )
  species_safe <- sub("/gbif-download/.*$", "", relative_path)
  species <- gsub("_", " ", species_safe)

  backup_path <- file.path(backup_root, "host_extra_not_in_ready_manifest", relative_path)
  copy_with_dirs(occurrence_path, backup_path)

  dat <- data.table::fread(occurrence_path, showProgress = FALSE)
  rows_before <- nrow(dat)
  basis <- if ("basisOfRecord" %in% names(dat)) normalise_basis(dat$basisOfRecord) else rep(NA_character_, rows_before)
  year <- if ("year" %in% names(dat)) suppressWarnings(as.integer(dat$year)) else rep(NA_integer_, rows_before)
  issue <- if ("issue" %in% names(dat)) dat$issue else rep(NA_character_, rows_before)

  keep <- basis %in% allowed_basis &
    !is.na(year) &
    year >= start_year &
    year <= end_year &
    !has_disallowed_issue(issue, disallowed_issues)

  filtered <- dat[keep]
  rows_after <- nrow(filtered)
  unique_coords <- if (rows_after > 0 && all(c("decimalLongitude", "decimalLatitude") %in% names(filtered))) {
    nrow(unique(filtered[, .(decimalLongitude, decimalLatitude)]))
  } else {
    rows_after
  }

  data.table::fwrite(filtered, occurrence_path, na = "")

  extra_host_rows[[idx]] <- data.table::data.table(
    species_name = species,
    occurrence_path = occurrence_path,
    status = "filtered_extra_not_in_ready_manifest",
    rows_before = rows_before,
    rows_after = rows_after,
    removed_rows = rows_before - rows_after,
    unique_coordinate_rows = unique_coords,
    passes_min_points = unique_coords >= min_points,
    backup_path = backup_path
  )
}

host_filter_summary <- data.table::rbindlist(c(host_rows, extra_host_rows), fill = TRUE)
data.table::fwrite(host_filter_summary, file.path(run_dir, "host_gbif_issue_filter_summary.csv"), na = "")

host_manifest_filtered <- host_manifest[passes_min_points == TRUE]
data.table::fwrite(host_manifest_filtered, host_manifest_path, na = "")
data.table::fwrite(host_manifest, file.path(run_dir, "host_species_sdm_targets_after_issue_filter_all_rows.csv"), na = "")

# -----------------------------------------------------------------------------|
# Vector recombination with GBIF issue filtering ----
# -----------------------------------------------------------------------------|

vector_manifest_backup <- file.path(backup_root, "vector_species_sdm_targets_combined_v2_ready.csv")
copy_with_dirs(vector_manifest_path, vector_manifest_backup)

existing_vector_files <- list.files(
  vector_occurrence_root,
  pattern = "_cleaned[.]csv$",
  recursive = TRUE,
  full.names = TRUE
)
existing_vector_files <- existing_vector_files[grepl("/combined_v2/cleaned/", existing_vector_files)]
for (path in existing_vector_files) {
  relative_path <- substring(
    normalizePath(path, winslash = "/", mustWork = TRUE),
    nchar(normalizePath(vector_occurrence_root, winslash = "/", mustWork = TRUE)) + 2L
  )
  copy_with_dirs(path, file.path(backup_root, "vector", relative_path))
}

combine_script <- file.path(repo_root, "scripts", "sdms", "present", "occurrences", "06_combine_vector_occurrences.R")
combine_args <- c(
  combine_script,
  "--target-manifest-path", vector_manifest_path,
  "--local-source-manifest-path", vector_local_manifest,
  "--occurrence-root", vector_source_root,
  "--output-occurrence-root", vector_occurrence_root,
  "--combined-run-root", vector_combine_run_root,
  "--roles", "vector",
  "--occurrence-method", "combined_v2",
  "--start-year", as.character(start_year),
  "--end-year", as.character(end_year),
  "--min-points", as.character(min_points),
  "--allowed-gbif-basis-of-record", paste(allowed_basis, collapse = ","),
  "--disallowed-gbif-issues", paste(disallowed_issues, collapse = ","),
  "--require-empty-gbif-issue", "false",
  "--update-target-manifest", "true"
)

combine_status <- system2(file.path(R.home("bin"), "Rscript"), combine_args)
if (!identical(combine_status, 0L)) {
  stop("Vector recombination failed with status: ", combine_status, call. = FALSE)
}

vector_manifest <- data.table::fread(vector_manifest_path, showProgress = FALSE)
vector_manifest_all_rows <- file.path(run_dir, "vector_species_sdm_targets_after_issue_filter_all_rows.csv")
data.table::fwrite(vector_manifest, vector_manifest_all_rows, na = "")

if ("passes_min_points" %in% names(vector_manifest)) {
  vector_manifest <- vector_manifest[passes_min_points == TRUE]
}
data.table::fwrite(vector_manifest, vector_manifest_path, na = "")

# -----------------------------------------------------------------------------|
# Run metadata ----
# -----------------------------------------------------------------------------|

metadata <- data.table::data.table(
  prepared_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  runner_root = runner_root,
  start_year = start_year,
  end_year = end_year,
  allowed_basis = paste(allowed_basis, collapse = ";"),
  disallowed_issues = paste(disallowed_issues, collapse = ";"),
  host_rows_before = sum(host_filter_summary$rows_before),
  host_rows_after = sum(host_filter_summary$rows_after),
  host_species_before = nrow(host_manifest),
  host_species_after_manifest_filter = nrow(host_manifest_filtered),
  vector_species_after_manifest_filter = nrow(vector_manifest),
  backup_root = backup_root,
  vector_combine_run_root = vector_combine_run_root
)
data.table::fwrite(metadata, file.path(run_dir, "issue_filter_run_metadata.csv"), na = "")

cat("Wrote filtered runner occurrence inputs.\n")
cat("Run directory: ", run_dir, "\n", sep = "")
cat("Backup directory: ", backup_root, "\n", sep = "")
cat("Host species retained in ready manifest: ", nrow(host_manifest_filtered), "\n", sep = "")
cat("Vector species retained in ready manifest: ", nrow(vector_manifest), "\n", sep = "")
