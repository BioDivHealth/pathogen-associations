#!/usr/bin/env Rscript
# -----------------------------------------------------------------------------|
# 02_build_host_sdm_target_manifests.R ----
# -----------------------------------------------------------------------------|
# Purpose: Build host SDM target manifests for species not covered by Gonzalo's
#          host SDMs, with conservative first-pass eligibility and review flags.
# -----------------------------------------------------------------------------|

suppressPackageStartupMessages({
  if (!requireNamespace("here", quietly = TRUE)) {
    stop("Package `here` is required.", call. = FALSE)
  }
})

source(file.path(here::here(), "scripts", "sdms", "present", "utils.R"))

# -----------------------------------------------------------------------------|
# RStudio config: edit this block before sourcing the script ----
# -----------------------------------------------------------------------------|

if (!exists("manifest_config", inherits = FALSE)) {
  manifest_config <- list(
    start_year = 2000,
    end_year = as.integer(format(Sys.Date(), "%Y")),
    overwrite = TRUE
  )
}

# -----------------------------------------------------------------------------|
# Internal defaults ----
# -----------------------------------------------------------------------------|

default_manifest_config <- list(
  host_source_path = file.path(
    repo_root(),
    "pathogen_association_data",
    "evidence",
    "who_networks",
    "host_pathogen",
    "master_plus_who_host_species.csv"
  ),
  taxonomy_override_path = file.path(
    repo_root(),
    "pathogen_association_data",
    "manual",
    "role_annotation",
    "host_sdm_taxonomy_overrides.csv"
  ),
  output_root = file.path(repo_root(), "sdms", "runs", "host_sdm_push"),
  existing_model_root = file.path(repo_root(), "sdms", "models"),
  occurrence_method = "gbif-download",
  gbif_occurrence_method = "gbif-download",
  start_year = 2000,
  end_year = as.integer(format(Sys.Date(), "%Y")),
  min_points = 20,
  default_run_status = "pending",
  sdm_needed_when_eligible = "yes",
  sdm_needed_when_ineligible = "no",
  require_pilot_include_disease = TRUE,
  require_detection_evidence = FALSE,
  target_class = "Mammalia",
  broad_excluded_class = "Aves",
  human_domestic_species = c(
    "Homo sapiens",
    "Bos grunniens",
    "Camelus bactrianus",
    "Lama glama",
    "Vicugna pacos"
  ),
  overwrite = TRUE
)

manifest_config <- utils::modifyList(default_manifest_config, manifest_config)
args <- parse_cli_args(commandArgs(trailingOnly = TRUE))

config_arg <- function(key, config_key = gsub("-", "_", key)) {
  get_arg(args, key, manifest_config[[config_key]])
}

# -----------------------------------------------------------------------------|
# Helpers ----
# -----------------------------------------------------------------------------|

require_columns <- function(data, cols, label) {
  missing <- setdiff(cols, names(data))
  if (length(missing) > 0) {
    stop(label, " is missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  }
}

first_non_missing <- function(x) {
  x <- as.character(x)
  x <- x[!is.na(x) & nzchar(x)]
  if (length(x) == 0) {
    return(NA_character_)
  }

  x[[1]]
}

missing_or_unknown <- function(x) {
  x <- trimws(as.character(x))
  is.na(x) | !nzchar(x) | tolower(x) %in% c("unknown", "na", "n/a", "none", "null")
}

normalise_taxonomy <- function(data) {
  taxonomy_cols <- c("host_phylum", "host_class", "host_order", "host_family")
  for (col in taxonomy_cols) {
    value <- trimws(as.character(data[[col]]))
    value[is.na(value) | !nzchar(value)] <- "Unknown"
    data[[col]] <- value
  }

  data
}

logical_value <- function(x) {
  value <- tolower(trimws(as.character(x)))
  value %in% c("true", "yes", "1")
}

numeric_value <- function(x) {
  suppressWarnings(as.numeric(x))
}

max_numeric_or_na <- function(x) {
  x <- numeric_value(x)
  x <- x[!is.na(x)]
  if (length(x) == 0) {
    return(NA_real_)
  }

  max(x)
}

split_values <- function(x) {
  x <- trimws(as.character(x))
  x <- x[!is.na(x) & nzchar(x)]
  if (length(x) == 0) {
    return(character())
  }

  values <- unlist(strsplit(x, ";", fixed = TRUE), use.names = FALSE)
  values <- trimws(values)
  values[!is.na(values) & nzchar(values)]
}

existing_model_path <- function(species) {
  file.path(existing_model_root, species, paste0(species, ".rds"))
}

apply_taxonomy_overrides <- function(hosts, override_path) {
  if (!file.exists(override_path)) {
    hosts$taxonomy_override_applied <- FALSE
    hosts$taxonomy_override_notes <- NA_character_
    return(hosts)
  }

  overrides <- read.csv(override_path, check.names = FALSE, stringsAsFactors = FALSE)
  require_columns(overrides, "host_species", basename(override_path))
  overrides$host_species_key <- canonical_species_name(overrides$host_species)
  hosts$host_species_key <- canonical_species_name(hosts$host_species)
  hosts$taxonomy_override_applied <- FALSE
  hosts$taxonomy_override_notes <- NA_character_

  taxonomy_cols <- c("host_phylum", "host_class", "host_order", "host_family")
  for (i in seq_len(nrow(overrides))) {
    idx <- hosts$host_species_key == overrides$host_species_key[[i]]
    if (!any(idx)) {
      next
    }

    for (col in intersect(taxonomy_cols, names(overrides))) {
      value <- trimws(as.character(overrides[[col]][[i]]))
      if (!is.na(value) && nzchar(value)) {
        hosts[[col]][idx] <- value
      }
    }

    hosts$taxonomy_override_applied[idx] <- TRUE
    if ("notes" %in% names(overrides)) {
      hosts$taxonomy_override_notes[idx] <- overrides$notes[[i]]
    }
  }

  hosts
}

review_reasons <- function(row) {
  reasons <- character()
  if (isTRUE(row$taxonomy_gap)) {
    reasons <- c(reasons, "taxonomy_gap")
  }
  if (isTRUE(row$known_non_target_class)) {
    reasons <- c(reasons, paste0("non_target_class:", row$host_class))
  }
  if (isTRUE(row$human_domestic_or_livestock)) {
    reasons <- c(reasons, "human_domestic_or_livestock")
  }
  if (isTRUE(row$not_pilot_include_disease)) {
    reasons <- c(reasons, "not_pilot_include_disease")
  }
  if (isTRUE(row$no_detection_evidence)) {
    reasons <- c(reasons, "no_pcr_or_observation_signal")
  }
  if (isTRUE(row$sdm_already_available)) {
    reasons <- c(reasons, "sdm_already_available")
  }
  if (length(reasons) == 0) {
    return(NA_character_)
  }

  paste(reasons, collapse = "; ")
}

eligibility_status <- function(row) {
  if (isTRUE(row$first_pass_eligible)) {
    return("first_pass_eligible")
  }
  if (isTRUE(row$taxonomy_gap)) {
    return("review_taxonomy_gap")
  }
  if (isTRUE(row$known_non_target_class)) {
    return("review_non_target_class")
  }
  if (isTRUE(row$human_domestic_or_livestock)) {
    return("review_exclude_human_domestic_or_livestock")
  }
  if (isTRUE(row$not_pilot_include_disease)) {
    return("review_not_pilot_include_disease")
  }
  if (isTRUE(row$no_detection_evidence)) {
    return("review_no_pcr_or_observation_signal")
  }
  if (isTRUE(row$sdm_already_available)) {
    return("already_available")
  }

  "review_other"
}

rank_species <- function(data) {
  status_rank <- match(
    data$eligibility_status,
    c(
      "first_pass_eligible",
      "review_taxonomy_gap",
      "review_no_pcr_or_observation_signal",
      "review_not_pilot_include_disease",
      "review_non_target_class",
      "review_exclude_human_domestic_or_livestock",
      "already_available",
      "review_other"
    )
  )
  status_rank[is.na(status_rank)] <- 99L
  detection_rank <- -numeric_value(data$Any_PCR_Or_Observation)
  detection_rank[is.na(detection_rank)] <- 0
  disease_rank <- -numeric_value(data$disease_count)
  disease_rank[is.na(disease_rank)] <- 0

  order(status_rank, detection_rank, disease_rank, data$host_order, data$host_family, data$species_name)
}

summary_count <- function(data, col) {
  out <- as.data.frame(table(data[[col]], useNA = "ifany"), stringsAsFactors = FALSE)
  names(out) <- c("value", "rows")
  out$summary_group <- col
  out <- out[, c("summary_group", "value", "rows"), drop = FALSE]
  out
}

expand_host_diseases <- function(data) {
  rows <- vector("list", nrow(data))
  for (i in seq_len(nrow(data))) {
    row <- data[i, , drop = FALSE]
    disease_names <- split_values(row$pilot_diseases)
    if (length(disease_names) == 0) {
      disease_names <- split_values(row$diseases)
    }
    if (length(disease_names) == 0) {
      disease_names <- NA_character_
    }

    include_names <- split_values(row$pilot_include_diseases)
    expanded <- row[rep(1L, length(disease_names)), , drop = FALSE]
    expanded$analysis_unit_id <- NA_character_
    expanded$readiness_disease_name <- disease_names
    expanded$disease_name <- disease_names
    expanded$disease_is_pilot_include <- if (length(include_names) == 0) {
      FALSE
    } else {
      disease_names %in% include_names
    }
    rows[[i]] <- expanded
  }

  do.call(rbind, rows)
}

# -----------------------------------------------------------------------------|
# Resolve paths and config ----
# -----------------------------------------------------------------------------|

host_source_path <- config_arg("host-source-path")
taxonomy_override_path <- config_arg("taxonomy-override-path")
output_root <- ensure_dir(config_arg("output-root"))
existing_model_root <- config_arg("existing-model-root")
occurrence_method <- config_arg("occurrence-method")
gbif_occurrence_method <- config_arg("gbif-occurrence-method")
start_year <- as.integer(config_arg("start-year"))
end_year <- as.integer(config_arg("end-year"))
min_points <- as.integer(config_arg("min-points"))
default_run_status <- config_arg("default-run-status")
sdm_needed_when_eligible <- config_arg("sdm-needed-when-eligible")
sdm_needed_when_ineligible <- config_arg("sdm-needed-when-ineligible")
require_pilot_include_disease <- as_logical_arg(config_arg("require-pilot-include-disease"))
require_detection_evidence <- as_logical_arg(config_arg("require-detection-evidence"))
target_class <- split_arg(config_arg("target-class"))
broad_excluded_class <- split_arg(config_arg("broad-excluded-class"))
human_domestic_species <- canonical_species_name(split_arg(config_arg("human-domestic-species")))
overwrite <- as_logical_arg(config_arg("overwrite")) || has_flag(args, "overwrite")

disease_targets_path <- file.path(output_root, "disease_host_sdm_targets.csv")
species_targets_path <- file.path(output_root, "host_species_sdm_targets.csv")
taxonomy_review_path <- file.path(output_root, "host_taxonomy_review_queue.csv")
summary_path <- file.path(output_root, "manifest_build_summary.csv")

if (!file.exists(host_source_path)) {
  stop("Missing host source file: ", host_source_path, call. = FALSE)
}

if (!overwrite && any(file.exists(c(disease_targets_path, species_targets_path, taxonomy_review_path, summary_path)))) {
  stop("Output manifests already exist. Set overwrite = TRUE to replace them.", call. = FALSE)
}

# -----------------------------------------------------------------------------|
# Load and flag host candidates ----
# -----------------------------------------------------------------------------|

hosts <- read.csv(host_source_path, check.names = FALSE, stringsAsFactors = FALSE)
require_columns(
  hosts,
  c(
    "host_species",
    "host_phylum",
    "host_class",
    "host_order",
    "host_family",
    "host_in_gonzalos_list",
    "diseases",
    "has_pilot_disease",
    "pilot_diseases",
    "has_pilot_include_disease",
    "pilot_include_diseases",
    "Not_specified",
    "PCR_Sequencing",
    "Isolation_Observation",
    "Antibodies",
    "Any_PCR_Or_Observation"
  ),
  basename(host_source_path)
)

hosts <- normalise_taxonomy(hosts)
hosts <- apply_taxonomy_overrides(hosts, taxonomy_override_path)
hosts <- normalise_taxonomy(hosts)

hosts$species_name <- canonical_species_name(hosts$host_species)
hosts$species_name_canonical <- hosts$species_name
hosts$species_key <- tolower(hosts$species_name_canonical)
hosts$host_in_gonzalos_list <- logical_value(hosts$host_in_gonzalos_list)
hosts$has_pilot_disease <- logical_value(hosts$has_pilot_disease)
hosts$has_pilot_include_disease <- logical_value(hosts$has_pilot_include_disease)
hosts$Any_PCR_Or_Observation <- numeric_value(hosts$Any_PCR_Or_Observation)
hosts$PCR_Sequencing <- numeric_value(hosts$PCR_Sequencing)
hosts$Isolation_Observation <- numeric_value(hosts$Isolation_Observation)
hosts$Antibodies <- numeric_value(hosts$Antibodies)
hosts$Not_specified <- numeric_value(hosts$Not_specified)

broad_targets <- hosts[
  !hosts$host_in_gonzalos_list &
    hosts$has_pilot_disease &
    !hosts$host_class %in% broad_excluded_class,
  ,
  drop = FALSE
]

broad_targets <- broad_targets[!duplicated(broad_targets$species_key), , drop = FALSE]

broad_targets$taxonomy_gap <- missing_or_unknown(broad_targets$host_phylum) |
  missing_or_unknown(broad_targets$host_class) |
  missing_or_unknown(broad_targets$host_order) |
  missing_or_unknown(broad_targets$host_family)
broad_targets$known_non_target_class <- !broad_targets$taxonomy_gap &
  !broad_targets$host_class %in% target_class
broad_targets$human_domestic_or_livestock <- canonical_species_name(broad_targets$species_name) %in% human_domestic_species
broad_targets$not_pilot_include_disease <- !broad_targets$has_pilot_include_disease
broad_targets$no_detection_evidence <- is.na(broad_targets$Any_PCR_Or_Observation) |
  broad_targets$Any_PCR_Or_Observation <= 0
broad_targets$existing_model_path <- vapply(broad_targets$species_name, existing_model_path, character(1))
broad_targets$sdm_available <- file.exists(broad_targets$existing_model_path)
broad_targets$sdm_already_available <- broad_targets$sdm_available
broad_targets$first_pass_eligible <- !broad_targets$taxonomy_gap &
  !broad_targets$known_non_target_class &
  !broad_targets$human_domestic_or_livestock &
  !broad_targets$sdm_already_available
if (require_pilot_include_disease) {
  broad_targets$first_pass_eligible <- broad_targets$first_pass_eligible &
    broad_targets$has_pilot_include_disease
}
if (require_detection_evidence) {
  broad_targets$first_pass_eligible <- broad_targets$first_pass_eligible &
    !broad_targets$no_detection_evidence
}

review_rows <- split(broad_targets, seq_len(nrow(broad_targets)))
broad_targets$eligibility_reasons <- vapply(review_rows, review_reasons, character(1))
broad_targets$eligibility_status <- vapply(review_rows, eligibility_status, character(1))
broad_targets$taxonomy_review_needed <- broad_targets$taxonomy_gap |
  broad_targets$known_non_target_class |
  broad_targets$human_domestic_or_livestock
broad_targets$taxonomy_review_reason <- ifelse(
  broad_targets$taxonomy_review_needed,
  broad_targets$eligibility_reasons,
  NA_character_
)

# -----------------------------------------------------------------------------|
# Build long disease-host targets ----
# -----------------------------------------------------------------------------|

disease_targets <- expand_host_diseases(broad_targets)
disease_targets$species_role <- "host"
disease_targets$sdm_needed_for_disease <- ifelse(
  disease_targets$first_pass_eligible,
  sdm_needed_when_eligible,
  sdm_needed_when_ineligible
)
disease_targets$sdm_species <- disease_targets$species_name
disease_targets$run_status <- ifelse(
  disease_targets$sdm_already_available,
  "already_available",
  ifelse(disease_targets$first_pass_eligible, default_run_status, "review_before_download")
)
disease_targets$run_priority <- seq_len(nrow(disease_targets))
disease_targets$occurrence_method <- occurrence_method
disease_targets$gbif_occurrence_method <- gbif_occurrence_method
disease_targets$start_year <- start_year
disease_targets$end_year <- end_year
disease_targets$min_points <- min_points
disease_targets$target_status <- ifelse(
  disease_targets$first_pass_eligible,
  "needs_host_sdm",
  disease_targets$eligibility_status
)
disease_targets$synonym_review_status <- "not_audited"
disease_targets$synonym_notes <- NA_character_

# -----------------------------------------------------------------------------|
# Collapse to one operational row per host species ----
# -----------------------------------------------------------------------------|

species_groups <- split(disease_targets, disease_targets$species_key)
species_rows <- lapply(species_groups, function(group) {
  data.frame(
    species_name = first_non_missing(group$species_name),
    species_name_canonical = first_non_missing(group$species_name_canonical),
    species_role = "host",
    sdm_needed_for_disease = if (any(group$first_pass_eligible, na.rm = TRUE)) {
      sdm_needed_when_eligible
    } else {
      sdm_needed_when_ineligible
    },
    sdm_available = any(group$sdm_available, na.rm = TRUE),
    sdm_species = first_non_missing(group$sdm_species),
    run_status = first_non_missing(group$run_status),
    run_priority = NA_integer_,
    occurrence_method = occurrence_method,
    gbif_occurrence_method = gbif_occurrence_method,
    start_year = start_year,
    end_year = end_year,
    min_points = min_points,
    disease_count = length(unique(group$readiness_disease_name[!is.na(group$readiness_disease_name) & nzchar(group$readiness_disease_name)])),
    disease_names = collapse_unique(group$readiness_disease_name),
    pilot_include_disease_names = collapse_unique(group$readiness_disease_name[group$disease_is_pilot_include]),
    analysis_unit_ids = collapse_unique(group$analysis_unit_id),
    host_phylum = first_non_missing(group$host_phylum),
    host_class = first_non_missing(group$host_class),
    host_order = first_non_missing(group$host_order),
    host_family = first_non_missing(group$host_family),
    host_in_gonzalos_list = any(group$host_in_gonzalos_list, na.rm = TRUE),
    has_pilot_disease = any(group$has_pilot_disease, na.rm = TRUE),
    has_pilot_include_disease = any(group$has_pilot_include_disease, na.rm = TRUE),
    Not_specified = max_numeric_or_na(group$Not_specified),
    PCR_Sequencing = max_numeric_or_na(group$PCR_Sequencing),
    Isolation_Observation = max_numeric_or_na(group$Isolation_Observation),
    Antibodies = max_numeric_or_na(group$Antibodies),
    Any_PCR_Or_Observation = max_numeric_or_na(group$Any_PCR_Or_Observation),
    first_pass_eligible = any(group$first_pass_eligible, na.rm = TRUE),
    eligibility_status = first_non_missing(group$eligibility_status),
    eligibility_reasons = collapse_unique(group$eligibility_reasons),
    taxonomy_review_needed = any(group$taxonomy_review_needed, na.rm = TRUE),
    taxonomy_review_reason = collapse_unique(group$taxonomy_review_reason),
    taxonomy_override_applied = any(group$taxonomy_override_applied, na.rm = TRUE),
    taxonomy_override_notes = collapse_unique(group$taxonomy_override_notes),
    existing_model_path = if (any(group$sdm_available, na.rm = TRUE)) first_non_missing(group$existing_model_path) else NA_character_,
    occurrence_status = "not_prepared",
    occurrence_rows_raw = NA_integer_,
    occurrence_rows_clean = NA_integer_,
    passes_min_points = NA,
    gbif_occurrence_path = NA_character_,
    local_occurrence_path = NA_character_,
    combined_occurrence_path = NA_character_,
    model_status = "not_run",
    model_output_path = NA_character_,
    synonym_review_status = "not_audited",
    synonym_notes = NA_character_,
    notes = NA_character_,
    stringsAsFactors = FALSE
  )
})

species_targets <- do.call(rbind, species_rows)
species_targets <- species_targets[rank_species(species_targets), , drop = FALSE]
species_targets$run_priority <- seq_len(nrow(species_targets))

taxonomy_review <- species_targets[
  species_targets$taxonomy_review_needed |
    species_targets$eligibility_status %in% c(
      "review_taxonomy_gap",
      "review_non_target_class",
      "review_exclude_human_domestic_or_livestock"
    ),
  ,
  drop = FALSE
]

summary_rows <- rbind(
  summary_count(species_targets, "eligibility_status"),
  summary_count(species_targets, "host_class"),
  summary_count(species_targets, "sdm_needed_for_disease")
)
summary_metadata <- data.frame(
  source_path = host_source_path,
  taxonomy_override_path = if (file.exists(taxonomy_override_path)) taxonomy_override_path else NA_character_,
  broad_candidate_species = nrow(species_targets),
  first_pass_eligible_species = sum(species_targets$first_pass_eligible, na.rm = TRUE),
  taxonomy_review_species = nrow(taxonomy_review),
  start_year = start_year,
  end_year = end_year,
  min_points = min_points,
  built_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  stringsAsFactors = FALSE
)
summary_metadata_path <- file.path(output_root, "manifest_build_metadata.csv")

# -----------------------------------------------------------------------------|
# Write outputs ----
# -----------------------------------------------------------------------------|

write.csv(disease_targets, disease_targets_path, row.names = FALSE, na = "")
write.csv(species_targets, species_targets_path, row.names = FALSE, na = "")
write.csv(taxonomy_review, taxonomy_review_path, row.names = FALSE, na = "")
write.csv(summary_rows, summary_path, row.names = FALSE, na = "")
write.csv(summary_metadata, summary_metadata_path, row.names = FALSE, na = "")

cat("Wrote disease-host manifest:", disease_targets_path, "\n")
cat("Wrote host species manifest:", species_targets_path, "\n")
cat("Wrote host taxonomy review queue:", taxonomy_review_path, "\n")
cat("Wrote manifest build summary:", summary_path, "\n")
cat("Wrote manifest build metadata:", summary_metadata_path, "\n")
cat("Broad host species:", nrow(species_targets), "\n")
cat("First-pass eligible host species:", sum(species_targets$first_pass_eligible, na.rm = TRUE), "\n")
cat("Taxonomy-review species:", nrow(taxonomy_review), "\n")
