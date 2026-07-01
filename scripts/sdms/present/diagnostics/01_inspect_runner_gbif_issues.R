#!/usr/bin/env Rscript
# -----------------------------------------------------------------------------|
# 01_inspect_runner_gbif_issues.R ----
# -----------------------------------------------------------------------------|
# Purpose: Summarise GBIF issue flags for host/vector SDM runner species.
#
# The inspection is scoped to the modelling-relevant GBIF records:
#   - basisOfRecord in HUMAN_OBSERVATION or PRESERVED_SPECIMEN by default
#   - year within 2000-2026 by default
#
# Outputs one row per species/individual issue, plus issue-combination and
# species-level summary tables. Issue strings that contain semicolon-separated
# values are split into individual flags.
# -----------------------------------------------------------------------------|

suppressPackageStartupMessages({
  if (!requireNamespace("data.table", quietly = TRUE)) {
    stop("Package `data.table` is required.", call. = FALSE)
  }
})

# -----------------------------------------------------------------------------|
# CLI/config ----
# -----------------------------------------------------------------------------|

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

runner_root <- get_arg("runner-root", "/Volumes/LaCie/host_vector_sdm_runner")
vector_raw_root <- get_arg(
  "vector-raw-root",
  "/Volumes/LaCie/new_global_maxent/sdms/runs_artur/vector_sdm_push/occurrences"
)
output_dir <- get_arg(
  "output-dir",
  file.path(runner_root, "outputs", "issue_inspection")
)

host_manifest_path <- get_arg(
  "host-manifest",
  file.path(runner_root, "sdms", "runs", "host_sdm_push", "host_species_sdm_targets_model_ready.csv")
)
vector_manifest_path <- get_arg(
  "vector-manifest",
  file.path(runner_root, "sdms", "runs", "vector_sdm_push", "vector_species_sdm_targets_combined_v2_ready.csv")
)
host_raw_root <- get_arg(
  "host-raw-root",
  file.path(runner_root, "data", "occurrences", "host")
)

start_year <- as.integer(get_arg("start-year", "2000"))
end_year <- as.integer(get_arg("end-year", "2026"))
allowed_basis <- toupper(gsub(
  "[[:space:]]+",
  "_",
  split_arg(get_arg("allowed-basis", "HUMAN_OBSERVATION,PRESERVED_SPECIMEN"))
))

if (is.na(start_year) || is.na(end_year) || start_year > end_year) {
  stop("Invalid year range: start-year must be <= end-year.", call. = FALSE)
}

if (length(allowed_basis) == 0) {
  stop("At least one allowed basisOfRecord value is required.", call. = FALSE)
}

for (path in c(host_manifest_path, vector_manifest_path)) {
  if (!file.exists(path)) {
    stop("Missing manifest: ", path, call. = FALSE)
  }
}

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# -----------------------------------------------------------------------------|
# Helpers ----
# -----------------------------------------------------------------------------|

safe_species_name <- function(x) {
  gsub("[^A-Za-z0-9]+", "_", trimws(x))
}

clean_issue_combo <- function(x) {
  x <- trimws(as.character(x))
  x[is.na(x) | !nzchar(x)] <- "<empty>"
  x
}

split_issue_combo <- function(x) {
  x <- clean_issue_combo(x)
  lapply(x, function(value) {
    if (identical(value, "<empty>")) {
      return("<empty>")
    }
    parts <- trimws(strsplit(value, ";", fixed = TRUE)[[1]])
    parts <- parts[nzchar(parts)]
    if (length(parts) == 0) {
      "<empty>"
    } else {
      unique(parts)
    }
  })
}

find_raw_file <- function(root, species) {
  raw_dir <- file.path(root, safe_species_name(species), "gbif-download", "raw")
  if (!dir.exists(raw_dir)) {
    return(NA_character_)
  }

  files <- list.files(raw_dir, pattern = "[.]csv$", full.names = TRUE)
  files <- files[!grepl("/[.]_", files)]
  files <- files[basename(files) != "raw_download_manifest.csv"]
  if (length(files) == 0) {
    return(NA_character_)
  }

  files[[1]]
}

read_gbif_issue_columns <- function(path) {
  header <- names(data.table::fread(path, nrows = 0, showProgress = FALSE))
  issue_col <- intersect(c("issue", "issues", "gbif_issue"), header)
  basis_col <- intersect(c("basisOfRecord", "basis_of_record"), header)
  year_col <- intersect("year", header)
  event_col <- intersect("eventDate", header)

  selected <- unique(c(issue_col[[1]], basis_col[[1]], year_col[[1]], event_col[[1]]))
  selected <- selected[!is.na(selected)]
  dat <- data.table::fread(path, select = selected, showProgress = FALSE)

  if (length(issue_col) == 0) {
    dat[, issue := NA_character_]
  } else {
    data.table::setnames(dat, issue_col[[1]], "issue")
  }

  if (length(basis_col) == 0) {
    dat[, basisOfRecord := NA_character_]
  } else {
    data.table::setnames(dat, basis_col[[1]], "basisOfRecord")
  }

  if (length(year_col) == 0) {
    dat[, year := NA_integer_]
  } else {
    data.table::setnames(dat, year_col[[1]], "year")
  }

  if (length(event_col) > 0 && event_col[[1]] != "eventDate") {
    data.table::setnames(dat, event_col[[1]], "eventDate")
  }
  if (!"eventDate" %in% names(dat)) {
    dat[, eventDate := NA_character_]
  }

  dat[, basisOfRecord := toupper(gsub("[[:space:]]+", "_", trimws(as.character(basisOfRecord))))]
  dat[, year := suppressWarnings(as.integer(year))]

  missing_year <- is.na(dat$year)
  if (any(missing_year)) {
    year_from_event <- suppressWarnings(as.integer(sub("^.*\\b((18|19|20)[0-9]{2})\\b.*$", "\\1", dat$eventDate)))
    usable_event_year <- !is.na(year_from_event) & grepl("\\b(18|19|20)[0-9]{2}\\b", dat$eventDate)
    dat$year[missing_year & usable_event_year] <- year_from_event[missing_year & usable_event_year]
  }

  dat[, issue_combo := clean_issue_combo(issue)]
  dat
}

year_range <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) == 0) {
    return(c(NA_integer_, NA_integer_))
  }
  c(min(x), max(x))
}

process_species <- function(role, species, raw_root) {
  raw_file <- find_raw_file(raw_root, species)

  if (is.na(raw_file) || !file.exists(raw_file)) {
    summary <- data.table::data.table(
      role = role,
      species_name = species,
      raw_file = raw_file,
      raw_file_found = FALSE,
      raw_records = 0L,
      allowed_basis_records = 0L,
      model_scope_records = 0L,
      model_scope_empty_issue_records = 0L,
      model_scope_nonempty_issue_records = 0L,
      model_scope_year_min = NA_integer_,
      model_scope_year_max = NA_integer_
    )
    return(list(summary = summary, issues = data.table::data.table(), combos = data.table::data.table()))
  }

  dat <- read_gbif_issue_columns(raw_file)
  allowed <- dat[basisOfRecord %in% allowed_basis]
  scoped <- allowed[!is.na(year) & year >= start_year & year <= end_year]
  empty_issue <- scoped$issue_combo == "<empty>"
  scoped_year <- year_range(scoped$year)

  summary <- data.table::data.table(
    role = role,
    species_name = species,
    raw_file = raw_file,
    raw_file_found = TRUE,
    raw_records = nrow(dat),
    allowed_basis_records = nrow(allowed),
    model_scope_records = nrow(scoped),
    model_scope_empty_issue_records = sum(empty_issue),
    model_scope_nonempty_issue_records = sum(!empty_issue),
    model_scope_year_min = scoped_year[[1]],
    model_scope_year_max = scoped_year[[2]]
  )

  if (nrow(scoped) == 0) {
    return(list(summary = summary, issues = data.table::data.table(), combos = data.table::data.table()))
  }

  issue_list <- split_issue_combo(scoped$issue_combo)
  issue_table <- data.table::data.table(
    record_id = seq_along(issue_list),
    issue = unlist(issue_list, use.names = FALSE)
  )
  issue_table <- issue_table[, .(record_count = data.table::uniqueN(record_id)), by = issue]
  issue_table[, `:=`(
    role = role,
    species_name = species,
    raw_file = raw_file
  )]
  data.table::setcolorder(issue_table, c("role", "species_name", "issue", "record_count", "raw_file"))
  data.table::setorder(issue_table, role, species_name, -record_count, issue)

  combo_table <- scoped[, .(record_count = .N), by = issue_combo]
  combo_table[, `:=`(
    role = role,
    species_name = species,
    raw_file = raw_file
  )]
  data.table::setcolorder(combo_table, c("role", "species_name", "issue_combo", "record_count", "raw_file"))
  data.table::setorder(combo_table, role, species_name, -record_count, issue_combo)

  list(summary = summary, issues = issue_table, combos = combo_table)
}

# -----------------------------------------------------------------------------|
# Build target list ----
# -----------------------------------------------------------------------------|

host_manifest <- data.table::fread(host_manifest_path, showProgress = FALSE)
vector_manifest <- data.table::fread(vector_manifest_path, showProgress = FALSE)

targets <- data.table::rbindlist(
  list(
    data.table::data.table(
      role = "host",
      species_name = unique(host_manifest$species_name),
      raw_root = host_raw_root
    ),
    data.table::data.table(
      role = "vector",
      species_name = unique(vector_manifest$species_name),
      raw_root = vector_raw_root
    )
  ),
  use.names = TRUE
)

targets <- targets[!is.na(species_name) & nzchar(species_name)]
data.table::setorder(targets, role, species_name)

# -----------------------------------------------------------------------------|
# Inspect issues ----
# -----------------------------------------------------------------------------|

results <- vector("list", nrow(targets))
for (idx in seq_len(nrow(targets))) {
  if (idx == 1 || idx %% 25 == 0 || idx == nrow(targets)) {
    message("Processing ", idx, " of ", nrow(targets))
  }
  results[[idx]] <- process_species(
    role = targets$role[[idx]],
    species = targets$species_name[[idx]],
    raw_root = targets$raw_root[[idx]]
  )
}

species_summary <- data.table::rbindlist(lapply(results, `[[`, "summary"), fill = TRUE)
issue_by_species <- data.table::rbindlist(lapply(results, `[[`, "issues"), fill = TRUE)
combo_by_species <- data.table::rbindlist(lapply(results, `[[`, "combos"), fill = TRUE)

overall_by_role <- issue_by_species[, .(
  species_count = data.table::uniqueN(paste(role, species_name)),
  record_count = sum(record_count)
), by = .(role, issue)]
data.table::setorder(overall_by_role, role, -record_count, issue)

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

has_any_issue <- function(combo, issues) {
  parts <- trimws(unlist(strsplit(combo, ";", fixed = TRUE)))
  any(parts %in% issues)
}

combo_by_species[, has_exclude_issue := vapply(
  issue_combo,
  has_any_issue,
  logical(1),
  issues = exclude_issues
)]
combo_by_species[, has_review_issue := vapply(
  issue_combo,
  has_any_issue,
  logical(1),
  issues = review_issues
)]
combo_by_species[, has_exclude_or_review_issue := has_exclude_issue | has_review_issue]

filter_sensitivity <- combo_by_species[, .(
  records_removed_exclude_only = sum(record_count[has_exclude_issue]),
  records_kept_exclude_only = sum(record_count[!has_exclude_issue]),
  records_removed_exclude_or_review = sum(record_count[has_exclude_or_review_issue]),
  records_kept_exclude_or_review = sum(record_count[!has_exclude_or_review_issue])
), by = .(role, species_name)]

filter_sensitivity <- merge(
  species_summary[, .(
    role,
    species_name,
    model_scope_records,
    model_scope_empty_issue_records,
    model_scope_nonempty_issue_records
  )],
  filter_sensitivity,
  by = c("role", "species_name"),
  all.x = TRUE
)

count_cols <- c(
  "records_removed_exclude_only",
  "records_kept_exclude_only",
  "records_removed_exclude_or_review",
  "records_kept_exclude_or_review"
)
for (col in count_cols) {
  filter_sensitivity[is.na(get(col)), (col) := 0L]
}

filter_sensitivity[, pct_kept_exclude_only := round(
  100 * records_kept_exclude_only / pmax(model_scope_records, 1),
  2
)]
filter_sensitivity[, pct_kept_exclude_or_review := round(
  100 * records_kept_exclude_or_review / pmax(model_scope_records, 1),
  2
)]
filter_sensitivity[, pass_20_exclude_only := records_kept_exclude_only >= 20]
filter_sensitivity[, pass_20_exclude_or_review := records_kept_exclude_or_review >= 20]
data.table::setorder(filter_sensitivity, role, species_name)

run_metadata <- data.table::data.table(
  prepared_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  runner_root = runner_root,
  host_manifest_path = host_manifest_path,
  vector_manifest_path = vector_manifest_path,
  host_raw_root = host_raw_root,
  vector_raw_root = vector_raw_root,
  start_year = start_year,
  end_year = end_year,
  allowed_basis = paste(allowed_basis, collapse = ";"),
  species_count = nrow(species_summary),
  missing_raw_file_count = sum(!species_summary$raw_file_found)
)

data.table::fwrite(species_summary, file.path(output_dir, "gbif_issue_species_summary.csv"), na = "")
data.table::fwrite(issue_by_species, file.path(output_dir, "gbif_issue_by_species.csv"), na = "")
data.table::fwrite(combo_by_species, file.path(output_dir, "gbif_issue_combinations_by_species.csv"), na = "")
data.table::fwrite(overall_by_role, file.path(output_dir, "gbif_issue_overall_by_role.csv"), na = "")
data.table::fwrite(filter_sensitivity, file.path(output_dir, "gbif_issue_filter_sensitivity_by_species.csv"), na = "")
data.table::fwrite(run_metadata, file.path(output_dir, "gbif_issue_run_metadata.csv"), na = "")

cat("Wrote GBIF issue inspection outputs to: ", output_dir, "\n", sep = "")
cat("Species inspected: ", nrow(species_summary), "\n", sep = "")
cat("Missing raw files: ", sum(!species_summary$raw_file_found), "\n", sep = "")
cat("Issue rows: ", nrow(issue_by_species), "\n", sep = "")
cat("Issue-combination rows: ", nrow(combo_by_species), "\n", sep = "")
cat("Filter sensitivity rows: ", nrow(filter_sensitivity), "\n", sep = "")
