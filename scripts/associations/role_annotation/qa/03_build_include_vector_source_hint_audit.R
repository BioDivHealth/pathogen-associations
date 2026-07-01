#!/usr/bin/env Rscript
################################################################################
# 03_build_include_vector_source_hint_audit.R
################################################################################
# Purpose: Build a row-level audit of include-scope vector modelling rows where
#          `vector_role_hint` would have changed the bucket under the old policy.
#
# Output : pathogen_association_data/evidence/role_annotation/qa/
#            include_vector_source_hint_audit.csv
#
# Notes  : This is a QA/navigation table only. It does not assign vector roles
#          or edit generated modelling surfaces.
################################################################################

suppressPackageStartupMessages({
  if (!requireNamespace("here", quietly = TRUE)) {
    stop("Package `here` is required.", call. = FALSE)
  }
  if (!requireNamespace("pacman", quietly = TRUE)) {
    stop("Package `pacman` is required.", call. = FALSE)
  }
})

pacman::p_load(dplyr, purrr, readr, stringr, tibble, tidyr)

source(here::here("scripts", "associations", "working_inputs.R"))

# ------------------------------------------------------------------------------|
#      Helpers -----------------------------------------------------------------|
# ------------------------------------------------------------------------------|
clean_text <- function(x) {
  x <- as.character(x)
  x[x %in% c("", "NA", "NaN", "No data", "null", "Null")] <- NA_character_
  x <- stringr::str_replace_all(x, "\u00A0", " ")
  x <- stringr::str_replace_all(x, "[\r\n\t]+", " ")
  x <- stringr::str_squish(x)
  x[x == ""] <- NA_character_
  x
}

clean_key <- function(x) {
  x %>%
    clean_text() %>%
    stringr::str_to_lower() %>%
    stringr::str_replace_all("&", " and ") %>%
    stringr::str_replace_all("[^a-z0-9]+", " ") %>%
    stringr::str_squish()
}

is_true <- function(x) {
  x %in% c(TRUE, "TRUE", "true", "True", 1, "1", "yes", "Yes", "YES")
}

read_csv_layer <- function(path) {
  if (!file.exists(path)) {
    stop("Missing required source-hint audit input: ", path, call. = FALSE)
  }

  readr::read_csv(path, show_col_types = FALSE, na = c("", "NA")) %>%
    mutate(across(where(is.character), clean_text))
}

entity_key <- function(disease_name, vector_join_key, species_name) {
  paste(clean_key(disease_name), clean_key(vector_join_key), clean_key(species_name), sep = "|")
}

classify_vector_role_text <- function(role_text) {
  role_text <- coalesce(clean_text(role_text), "")

  case_when(
    str_detect(
      role_text,
      regex("not_competent|not_important|non.?vector|refractory|unsupported", ignore_case = TRUE)
    ) ~ "unknown_or_unreviewed_vector",
    str_detect(role_text, regex("mechanical", ignore_case = TRUE)) ~
      "mechanical_vector",
    str_detect(role_text, regex("competent|competence", ignore_case = TRUE)) ~
      "competence_supported_vector",
    # Match role tokens across underscores/pipes without catching `maintenance`.
    str_detect(role_text, regex("(^|[^a-z])(main|primary|principal)([^a-z]|$)", ignore_case = TRUE)) ~
      "primary_or_main_vector",
    str_detect(role_text, regex("bridge|epidemic|epizootic|secondary", ignore_case = TRUE)) ~
      "bridge_or_epidemic_vector",
    str_detect(role_text, regex("enzootic|sylvatic|maintenance", ignore_case = TRUE)) ~
      "enzootic_or_sylvatic_vector",
    TRUE ~ NA_character_
  )
}

# ------------------------------------------------------------------------------|
#      Inputs ------------------------------------------------------------------|
# ------------------------------------------------------------------------------|
paths <- list(
  tracker = file.path(role_manual_dir, "disease_role_review_status.csv"),
  roster = file.path(role_roster_dir, "species_host_vector_roster.csv"),
  vector_features = vector_modelling_features_path(),
  vector_evidence = file.path(role_evidence_dir, "vector_role_evidence.csv"),
  vector_assignments = file.path(role_evidence_dir, "vector_role_assignments.csv"),
  readiness_full = file.path(readiness_dir, "disease_modelling_readiness_full.csv")
)

tracker <- read_csv_layer(paths$tracker)
roster <- read_csv_layer(paths$roster)
vector_features <- read_csv_layer(paths$vector_features)
vector_evidence <- read_csv_layer(paths$vector_evidence)
vector_assignments <- read_csv_layer(paths$vector_assignments)
readiness_full <- read_csv_layer(paths$readiness_full)

include_tracker <- tracker %>%
  filter(scope == "include") %>%
  transmute(
    disease_name,
    tracker_done = is_true(done),
    tracker_review = review,
    tracker_vectors = vectors,
    tracker_last_reviewed = last_reviewed,
    tracker_next_step = next_step
  )

include_diseases <- include_tracker$disease_name

# ------------------------------------------------------------------------------|
#      Source-Hint Rows --------------------------------------------------------|
# ------------------------------------------------------------------------------|
roster_context <- roster %>%
  filter(
    disease_name %in% include_diseases,
    species_role == "vector"
  ) %>%
  transmute(
    .vector_key = entity_key(disease_name, vector_join_key, species_name),
    vector_record_sources,
    uncertainty_reason
  ) %>%
  distinct(.vector_key, .keep_all = TRUE)

manual_vector_evidence_counts <- vector_evidence %>%
  filter(disease_name %in% include_diseases) %>%
  mutate(.vector_key = entity_key(disease_name, vector_join_key, vector_species)) %>%
  count(.vector_key, name = "manual_vector_evidence_rows")

manual_vector_assignment_counts <- vector_assignments %>%
  filter(disease_name %in% include_diseases) %>%
  mutate(.vector_key = entity_key(disease_name, vector_join_key, vector_species)) %>%
  count(.vector_key, name = "manual_vector_assignment_rows")

readiness_context <- readiness_full %>%
  filter(source_disease_name %in% include_diseases) %>%
  transmute(
    disease_name = source_disease_name,
    readiness_blocker,
    recommended_next_action,
    vector_sdm_needed,
    vector_sdm_species_available
  ) %>%
  distinct(disease_name, .keep_all = TRUE)

source_hint_rows <- vector_features %>%
  filter(
    disease_name %in% include_diseases,
    vector_role_bucket_basis != "reviewed_vector_assignment",
    !is.na(vector_role_hint)
  ) %>%
  mutate(
    .vector_key = entity_key(disease_name, vector_join_key, species_name),
    taxonomy_ok = is_true(taxonomy_ok),
    has_disease_vector_evidence = is_true(has_disease_vector_evidence),
    has_host_vector_evidence = is_true(has_host_vector_evidence),
    has_competence_evidence = is_true(has_competence_evidence),
    bites_humans_true = is_true(bites_humans_true),
    profile_broad = is_true(profile_broad),
    profile_supported = is_true(profile_supported),
    profile_strong = is_true(profile_strong),
    profile_strict = is_true(profile_strict),
    competence_or_transmission_supported =
      vector_competence_status %in% c("competent", "mixed") |
        transmission_demonstrated %in% c("yes", "mixed"),
    hint_classification_bucket = classify_vector_role_text(vector_role_hint),
    bucket_without_source_hint = vector_role_bucket,
    bucket_with_source_hint = case_when(
      !taxonomy_ok ~ "unknown_or_unreviewed_vector",
      !has_disease_vector_evidence ~ "unknown_or_unreviewed_vector",
      !is.na(hint_classification_bucket) ~ hint_classification_bucket,
      competence_or_transmission_supported ~ "competence_supported_vector",
      has_disease_vector_evidence ~ "direct_association_only_vector",
      TRUE ~ "unknown_or_unreviewed_vector"
    ),
    bucket_change_if_hints_enabled = bucket_with_source_hint != bucket_without_source_hint,
    source_hint_bucket_strength = case_when(
      bucket_with_source_hint == "primary_or_main_vector" ~ 3L,
      bucket_with_source_hint %in% c(
        "bridge_or_epidemic_vector",
        "enzootic_or_sylvatic_vector",
        "mechanical_vector"
      ) ~ 2L,
      TRUE ~ 1L
    ),
    fallback_evidence_strength = case_when(
      bucket_without_source_hint == "competence_supported_vector" ~ 2L,
      bucket_without_source_hint == "direct_association_only_vector" ~ 1L,
      TRUE ~ 0L
    ),
    source_hint_review_score =
      source_hint_bucket_strength * 100 +
      fallback_evidence_strength * 10 +
      if_else(profile_strict, 6L, 0L) +
      if_else(profile_strong, 4L, 0L) +
      if_else(profile_supported, 2L, 0L),
    policy_review_focus = case_when(
      bucket_with_source_hint == "primary_or_main_vector" &
        bucket_without_source_hint == "competence_supported_vector" ~
        "primary_hint_with_competence_support",
      bucket_with_source_hint == "primary_or_main_vector" ~
        "primary_hint_only",
      bucket_with_source_hint %in% c("bridge_or_epidemic_vector", "enzootic_or_sylvatic_vector") &
        bucket_without_source_hint == "competence_supported_vector" ~
        "ecological_hint_with_competence_support",
      bucket_with_source_hint %in% c("bridge_or_epidemic_vector", "enzootic_or_sylvatic_vector") ~
        "ecological_hint_only",
      bucket_with_source_hint == "mechanical_vector" ~
        "mechanical_hint_review",
      TRUE ~ "other_source_hint_review"
    ),
    review_recommendation = case_when(
      bucket_with_source_hint == "primary_or_main_vector" ~
        "review_before_allowing_hint_primary_bucket",
      bucket_with_source_hint %in% c(
        "bridge_or_epidemic_vector",
        "enzootic_or_sylvatic_vector",
        "mechanical_vector"
      ) ~ "review_if_hint_ecology_should_set_bucket",
      TRUE ~ "low_priority_source_hint_row"
    )
  ) %>%
  filter(
    !is.na(hint_classification_bucket),
    bucket_change_if_hints_enabled
  ) %>%
  left_join(roster_context, by = ".vector_key") %>%
  left_join(manual_vector_evidence_counts, by = ".vector_key") %>%
  left_join(manual_vector_assignment_counts, by = ".vector_key") %>%
  left_join(include_tracker, by = "disease_name") %>%
  left_join(readiness_context, by = "disease_name") %>%
  mutate(
    manual_vector_evidence_rows = coalesce(manual_vector_evidence_rows, 0L),
    manual_vector_assignment_rows = coalesce(manual_vector_assignment_rows, 0L)
  )

disease_hint_summary <- source_hint_rows %>%
  group_by(disease_name) %>%
  summarise(
    source_hint_rows_by_disease = n(),
    source_hint_primary_rows_by_disease = sum(
      bucket_with_source_hint == "primary_or_main_vector",
      na.rm = TRUE
    ),
    source_hint_bridge_rows_by_disease = sum(
      bucket_with_source_hint == "bridge_or_epidemic_vector",
      na.rm = TRUE
    ),
    source_hint_sylvatic_rows_by_disease = sum(
      bucket_with_source_hint == "enzootic_or_sylvatic_vector",
      na.rm = TRUE
    ),
    source_hint_competence_fallback_rows_by_disease = sum(
      bucket_without_source_hint == "competence_supported_vector",
      na.rm = TRUE
    ),
    source_hint_direct_fallback_rows_by_disease = sum(
      bucket_without_source_hint == "direct_association_only_vector",
      na.rm = TRUE
    ),
    .groups = "drop"
  )

source_hint_audit <- source_hint_rows %>%
  left_join(disease_hint_summary, by = "disease_name") %>%
  arrange(desc(source_hint_review_score), disease_name, species_name, vector_join_key) %>%
  mutate(source_hint_review_rank = row_number()) %>%
  select(
    disease_name,
    source_hint_review_rank,
    source_hint_review_score,
    policy_review_focus,
    review_recommendation,
    species_name,
    tax_id,
    vector_group,
    vector_taxon_rank,
    vector_join_key,
    vector_role_hint,
    vector_role_bucket,
    vector_role_bucket_basis,
    bucket_with_source_hint,
    bucket_without_source_hint,
    bucket_change_if_hints_enabled,
    best_evidence_level,
    best_evidence_basis,
    biological_evidence_tier,
    has_disease_vector_evidence,
    has_host_vector_evidence,
    has_competence_evidence,
    bites_humans,
    bites_humans_true,
    vector_competence_status,
    transmission_demonstrated,
    natural_infection_reported,
    vector_record_sources,
    uncertainty_reason,
    vector_evidence_missingness_reason,
    vector_role_assignment,
    vector_role_assignment_status,
    manual_vector_evidence_rows,
    manual_vector_assignment_rows,
    source_hint_rows_by_disease,
    source_hint_primary_rows_by_disease,
    source_hint_bridge_rows_by_disease,
    source_hint_sylvatic_rows_by_disease,
    source_hint_competence_fallback_rows_by_disease,
    source_hint_direct_fallback_rows_by_disease,
    readiness_blocker,
    recommended_next_action,
    vector_sdm_needed,
    vector_sdm_species_available,
    tracker_done,
    tracker_review,
    tracker_vectors,
    tracker_last_reviewed,
    tracker_next_step
  )

stopifnot(all(source_hint_audit$disease_name %in% include_diseases))
stopifnot(!any(source_hint_audit$vector_role_bucket_basis == "source_role_hint"))
stopifnot(all(source_hint_audit$bucket_change_if_hints_enabled))
stopifnot(!anyDuplicated(source_hint_audit$source_hint_review_rank))

output_path <- file.path(role_qa_dir, "include_vector_source_hint_audit.csv")
dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
write_csv(source_hint_audit, output_path, na = "")

message("Wrote include vector source-hint audit: ", output_path)
message("Rows in include_vector_source_hint_audit.csv: ", nrow(source_hint_audit))
