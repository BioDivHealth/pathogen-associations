#!/usr/bin/env Rscript
################################################################################
# 02_build_include_species_role_evidence_audit.R
################################################################################
# Purpose: Build one disease-level audit row for each include-scope species-role
#          disease so review can focus on flagged policy/evidence surfaces.
#
# Output : pathogen_association_data/evidence/role_annotation/qa/
#            include_species_role_evidence_audit.csv
#
# Notes  : This is a QA/navigation table only. It does not assign biological
#          host/vector roles or edit generated modelling surfaces.
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
source(here::here("scripts", "associations", "association_data_helpers.R"))

# ------------------------------------------------------------------------------|
#      Helpers -----------------------------------------------------------------|
# ------------------------------------------------------------------------------|
entity_key <- function(name, id = NA_character_) {
  paste(clean_key(name), clean_text(id), sep = "|")
}

sum_true <- function(x) {
  sum(x %in% TRUE, na.rm = TRUE)
}

count_bucket <- function(x, value) {
  sum(x == value, na.rm = TRUE)
}

collapse_non_missing <- function(x) {
  x <- sort(unique(stats::na.omit(clean_text(x))))
  if (length(x) == 0) {
    return(NA_character_)
  }
  paste(x, collapse = "; ")
}

combine_flags <- function(...) {
  values <- c(...)
  values <- values[!is.na(values) & values != ""]
  if (length(values) == 0) {
    return("no_role_review_flags")
  }
  paste(values, collapse = "; ")
}

zero_count_columns <- function(data, cols) {
  for (col in cols) {
    if (!col %in% names(data)) {
      data[[col]] <- 0L
    }
    data[[col]][is.na(data[[col]])] <- 0L
  }
  data
}

make_review_file_summary <- function(diseases) {
  if (!dir.exists(role_reviews_dir)) {
    return(tibble(
      disease_name = diseases,
      review_note_present = FALSE,
      review_note_files = NA_character_
    ))
  }

  review_files <- list.files(
    role_reviews_dir,
    pattern = "\\.md$",
    full.names = TRUE
  )

  if (length(review_files) == 0) {
    return(tibble(
      disease_name = diseases,
      review_note_present = FALSE,
      review_note_files = NA_character_
    ))
  }

  review_lookup <- tibble(
    review_file = review_files,
    review_basename = basename(review_files),
    review_text = purrr::map_chr(
      review_files,
      ~ paste(readLines(.x, warn = FALSE), collapse = " ")
    )
  ) %>%
    mutate(review_key = clean_key(paste(review_basename, review_text)))

  tibble(disease_name = diseases) %>%
    rowwise() %>%
    mutate(
      .disease_key = clean_key(disease_name),
      review_note_files = {
        matches <- review_lookup$review_basename[
          stringr::str_detect(review_lookup$review_key, stringr::fixed(.disease_key))
        ]
        if (length(matches) == 0) NA_character_ else paste(matches, collapse = "; ")
      },
      review_note_present = !is.na(review_note_files)
    ) %>%
    ungroup() %>%
    select(-.disease_key)
}

# ------------------------------------------------------------------------------|
#      Inputs ------------------------------------------------------------------|
# ------------------------------------------------------------------------------|
paths <- list(
  tracker = file.path(role_manual_dir, "disease_role_review_status.csv"),
  roster = file.path(role_roster_dir, "species_host_vector_roster.csv"),
  host_features = role_modelling_features_path(),
  vector_features = vector_modelling_features_path(),
  tiered_species = file.path(readiness_dir, "evidence_tiers", "tiered_species.csv"),
  host_evidence = file.path(role_evidence_dir, "host_role_evidence.csv"),
  host_assignments = file.path(role_evidence_dir, "host_role_assignments.csv"),
  vector_evidence = file.path(role_evidence_dir, "vector_role_evidence.csv"),
  vector_assignments = file.path(role_evidence_dir, "vector_role_assignments.csv"),
  proxy_rules = role_host_proxy_rules_path(),
  vector_unmatched = file.path(role_qa_dir, "vector_role_assignments_unmatched_to_roster.csv"),
  readiness_full = file.path(readiness_dir, "disease_modelling_readiness_full.csv")
)

tracker <- read_csv_layer(paths$tracker, required = TRUE)
roster <- read_csv_layer(paths$roster, required = TRUE)
host_features <- read_csv_layer(paths$host_features, required = TRUE)
vector_features <- read_csv_layer(paths$vector_features, required = TRUE)
tiered_species <- read_csv_layer(paths$tiered_species, required = TRUE)
host_evidence <- read_csv_layer(paths$host_evidence, required = TRUE)
host_assignments <- read_csv_layer(paths$host_assignments, required = TRUE)
vector_evidence <- read_csv_layer(paths$vector_evidence, required = TRUE)
vector_assignments <- read_csv_layer(paths$vector_assignments, required = TRUE)
proxy_rules <- read_csv_layer(paths$proxy_rules, required = TRUE)
vector_unmatched <- read_csv_layer(paths$vector_unmatched, required = TRUE)
readiness_full <- read_csv_layer(paths$readiness_full, required = TRUE)

include_tracker <- tracker %>%
  filter(scope == "include") %>%
  arrange(disease_name)

include_diseases <- include_tracker$disease_name

# ------------------------------------------------------------------------------|
#      Layer Summaries ---------------------------------------------------------|
# ------------------------------------------------------------------------------|
review_summary <- make_review_file_summary(include_diseases)

roster_summary <- roster %>%
  filter(disease_name %in% include_diseases) %>%
  group_by(disease_name) %>%
  summarise(
    roster_rows = n(),
    roster_host_rows = sum(species_role == "host", na.rm = TRUE),
    roster_vector_rows = sum(species_role == "vector", na.rm = TRUE),
    roster_host_taxonomy_blank_rows = sum(
      species_role == "host" &
        (is.na(host_class) | is.na(host_order) | is.na(host_family)),
      na.rm = TRUE
    ),
    roster_vector_taxonomy_caution_rows = sum_true(taxonomy_caution),
    roster_vectors_with_disease_vector_evidence = sum_true(has_disease_vector_evidence),
    roster_vectors_with_host_vector_evidence = sum_true(has_host_vector_evidence),
    roster_vectors_with_competence_evidence = sum_true(has_competence_evidence),
    .groups = "drop"
  )

host_feature_summary <- host_features %>%
  filter(disease_name %in% include_diseases) %>%
  group_by(disease_name) %>%
  summarise(
    host_feature_rows = n(),
    host_bucket_reservoir_or_amplifying_rows = count_bucket(
      host_role_bucket,
      "reservoir_or_amplifying_host"
    ),
    host_bucket_susceptible_or_spillover_rows = count_bucket(
      host_role_bucket,
      "susceptible_or_spillover_host"
    ),
    host_bucket_dead_end_or_incidental_rows = count_bucket(
      host_role_bucket,
      "dead_end_or_incidental_host"
    ),
    host_bucket_presence_only_rows = count_bucket(host_role_bucket, "host_presence_only"),
    host_bucket_unknown_rows = count_bucket(host_role_bucket, "unknown_or_unreviewed"),
    host_exact_source_backed_rows = count_bucket(
      host_role_evidence_basis,
      "exact_source_backed"
    ),
    host_exact_reviewed_needs_review_rows = count_bucket(
      host_role_evidence_basis,
      "exact_reviewed_needs_review"
    ),
    host_disease_group_proxy_rows = count_bucket(
      host_role_evidence_basis,
      "disease_group_proxy"
    ),
    host_weighted_taxonomic_proxy_rows = count_bucket(
      host_role_evidence_basis,
      "weighted_taxonomic_proxy"
    ),
    host_proxy_rows = sum_true(group_proxy_applied),
    host_profile_group_proxy_rows = sum_true(profile_group_proxy),
    host_proxy_needs_review_rows = sum_true(modelling_role_proxy_needs_review),
    host_role_needs_manual_review_rows = sum_true(host_role_needs_manual_review),
    host_taxonomy_blank_rows = sum(
      is.na(host_class) | is.na(host_order) | is.na(host_family),
      na.rm = TRUE
    ),
    host_proxy_rule_ids = collapse_non_missing(
      modelling_role_proxy_rule_id[
        !modelling_role_proxy_rule_id %in% c(
          "candidate_role_v0_1",
          "source_backed_role_v0_1",
          "reviewed_role_needs_review_v0_1"
        )
      ]
    ),
    .groups = "drop"
  )

vector_feature_summary <- vector_features %>%
  filter(disease_name %in% include_diseases) %>%
  group_by(disease_name) %>%
  summarise(
    vector_feature_rows = n(),
    vector_bucket_primary_rows = count_bucket(
      vector_role_bucket,
      "primary_or_main_vector"
    ),
    vector_bucket_bridge_rows = count_bucket(
      vector_role_bucket,
      "bridge_or_epidemic_vector"
    ),
    vector_bucket_enzootic_or_sylvatic_rows = count_bucket(
      vector_role_bucket,
      "enzootic_or_sylvatic_vector"
    ),
    vector_bucket_competence_supported_rows = count_bucket(
      vector_role_bucket,
      "competence_supported_vector"
    ),
    vector_bucket_direct_association_rows = count_bucket(
      vector_role_bucket,
      "direct_association_only_vector"
    ),
    vector_bucket_unknown_rows = count_bucket(
      vector_role_bucket,
      "unknown_or_unreviewed_vector"
    ),
    vector_role_needs_review_rows = sum_true(vector_role_bucket_needs_review),
    vector_primary_needs_review_rows = sum(
      vector_role_bucket == "primary_or_main_vector" &
        vector_role_bucket_needs_review %in% TRUE,
      na.rm = TRUE
    ),
    vector_bridge_needs_review_rows = sum(
      vector_role_bucket == "bridge_or_epidemic_vector" &
        vector_role_bucket_needs_review %in% TRUE,
      na.rm = TRUE
    ),
    vector_sylvatic_needs_review_rows = sum(
      vector_role_bucket == "enzootic_or_sylvatic_vector" &
        vector_role_bucket_needs_review %in% TRUE,
      na.rm = TRUE
    ),
    vector_source_role_hint_rows = count_bucket(
      vector_role_bucket_basis,
      "source_role_hint"
    ),
    vector_reviewed_assignment_rows = count_bucket(
      vector_role_bucket_basis,
      "reviewed_vector_assignment"
    ),
    vector_taxonomy_caution_rows = count_bucket(
      vector_role_bucket_basis,
      "taxonomy_caution"
    ),
    vector_competence_or_transmission_supported_rows = count_bucket(
      vector_role_bucket_basis,
      "competence_or_transmission_supported"
    ),
    .groups = "drop"
  )

tiered_summary <- tiered_species %>%
  filter(disease_name %in% include_diseases) %>%
  group_by(disease_name) %>%
  summarise(
    tiered_species_rows = n(),
    tiered_repo_host_rows = sum(source_dataset == "repo_pilot" & species_role == "host"),
    tiered_repo_vector_rows = sum(source_dataset == "repo_pilot" & species_role == "vector"),
    tiered_delivery_host_rows = sum(
      source_dataset == "chikungunya_delivery" & species_role == "host"
    ),
    tiered_delivery_vector_rows = sum(
      source_dataset == "chikungunya_delivery" & species_role == "vector"
    ),
    tiered_no_spatial_layer_rows = sum_true(no_spatial_layer),
    tiered_host_taxonomy_blank_rows = sum(
      species_role == "host" &
        (is.na(host_class) | is.na(host_order) | is.na(host_family)),
      na.rm = TRUE
    ),
    .groups = "drop"
  )

proxy_rule_summary <- proxy_rules %>%
  filter(disease_name %in% include_diseases, is_true(rule_active)) %>%
  group_by(disease_name) %>%
  summarise(
    active_host_proxy_rule_rows = n(),
    active_host_proxy_taxid_rule_rows = sum(!is.na(tax_id)),
    active_host_proxy_broad_taxonomy_rule_rows = sum(
      is.na(tax_id) &
        (!is.na(host_class) | !is.na(host_order) | !is.na(host_family) | !is.na(species_name))
    ),
    active_host_proxy_rule_ids = collapse_non_missing(rule_id),
    .groups = "drop"
  )

host_evidence_keys <- host_evidence %>%
  filter(disease_name %in% include_diseases) %>%
  transmute(
    disease_name,
    .host_key = entity_key(host, host_tax_id),
    needs_manual_review = is_true(needs_manual_review)
  )

host_assignment_keys <- host_assignments %>%
  filter(disease_name %in% include_diseases) %>%
  transmute(
    disease_name,
    .host_key = entity_key(host, host_tax_id),
    needs_manual_review = is_true(needs_manual_review)
  )

host_evidence_summary <- host_evidence_keys %>%
  group_by(disease_name) %>%
  summarise(
    host_role_evidence_rows = n(),
    host_role_evidence_needs_review_rows = sum_true(needs_manual_review),
    .groups = "drop"
  )

host_assignment_summary <- host_assignment_keys %>%
  group_by(disease_name) %>%
  summarise(
    host_role_assignment_rows = n(),
    host_role_assignment_needs_review_rows = sum_true(needs_manual_review),
    .groups = "drop"
  )

host_evidence_assignment_summary <- bind_rows(
  host_evidence_keys %>%
    anti_join(
      host_assignment_keys %>% distinct(disease_name, .host_key),
      by = c("disease_name", ".host_key")
    ) %>%
    count(disease_name, name = "host_evidence_without_assignment_rows"),
  tibble(disease_name = character(), host_evidence_without_assignment_rows = integer())
) %>%
  group_by(disease_name) %>%
  summarise(
    host_evidence_without_assignment_rows = sum(host_evidence_without_assignment_rows),
    .groups = "drop"
  ) %>%
  full_join(
    host_assignment_keys %>%
      anti_join(
        host_evidence_keys %>% distinct(disease_name, .host_key),
        by = c("disease_name", ".host_key")
      ) %>%
      count(disease_name, name = "host_assignment_without_evidence_rows"),
    by = "disease_name"
  )

vector_evidence_keys <- vector_evidence %>%
  filter(disease_name %in% include_diseases) %>%
  transmute(
    disease_name,
    .vector_key = entity_key(vector_species, vector_join_key),
    needs_manual_review = is_true(needs_manual_review)
  )

vector_assignment_keys <- vector_assignments %>%
  filter(disease_name %in% include_diseases) %>%
  transmute(
    disease_name,
    .vector_key = entity_key(vector_species, vector_join_key),
    needs_manual_review = is_true(needs_manual_review)
  )

vector_evidence_summary <- vector_evidence_keys %>%
  group_by(disease_name) %>%
  summarise(
    vector_role_evidence_rows = n(),
    vector_role_evidence_needs_review_rows = sum_true(needs_manual_review),
    .groups = "drop"
  )

vector_assignment_summary <- vector_assignment_keys %>%
  group_by(disease_name) %>%
  summarise(
    vector_role_assignment_rows = n(),
    vector_role_assignment_needs_review_rows = sum_true(needs_manual_review),
    .groups = "drop"
  )

vector_evidence_assignment_summary <- bind_rows(
  vector_evidence_keys %>%
    anti_join(
      vector_assignment_keys %>% distinct(disease_name, .vector_key),
      by = c("disease_name", ".vector_key")
    ) %>%
    count(disease_name, name = "vector_evidence_without_assignment_rows"),
  tibble(disease_name = character(), vector_evidence_without_assignment_rows = integer())
) %>%
  group_by(disease_name) %>%
  summarise(
    vector_evidence_without_assignment_rows = sum(vector_evidence_without_assignment_rows),
    .groups = "drop"
  ) %>%
  full_join(
    vector_assignment_keys %>%
      anti_join(
        vector_evidence_keys %>% distinct(disease_name, .vector_key),
        by = c("disease_name", ".vector_key")
      ) %>%
      count(disease_name, name = "vector_assignment_without_evidence_rows"),
    by = "disease_name"
  )

vector_unmatched_summary <- vector_unmatched %>%
  filter(disease_name %in% include_diseases) %>%
  group_by(disease_name) %>%
  summarise(
    unmatched_vector_assignment_rows = n(),
    unmatched_vector_assignment_labels = collapse_non_missing(vector_species),
    .groups = "drop"
  )

readiness_summary <- readiness_full %>%
  filter(source_disease_name %in% include_diseases) %>%
  transmute(
    disease_name = source_disease_name,
    role_assignment_status,
    sdm_availability_status,
    readiness_blocker,
    recommended_next_action,
    host_sdm_needed,
    vector_sdm_needed,
    host_sdm_species_available,
    vector_sdm_species_available,
    host_candidate_rows,
    direct_vector_species_or_taxa,
    direct_vector_taxonomy_review_needed_rows
  ) %>%
  distinct(disease_name, .keep_all = TRUE)

# ------------------------------------------------------------------------------|
#      Audit Table -------------------------------------------------------------|
# ------------------------------------------------------------------------------|
count_cols <- c(
  "roster_rows",
  "roster_host_rows",
  "roster_vector_rows",
  "roster_host_taxonomy_blank_rows",
  "roster_vector_taxonomy_caution_rows",
  "roster_vectors_with_disease_vector_evidence",
  "roster_vectors_with_host_vector_evidence",
  "roster_vectors_with_competence_evidence",
  "host_feature_rows",
  "host_bucket_reservoir_or_amplifying_rows",
  "host_bucket_susceptible_or_spillover_rows",
  "host_bucket_dead_end_or_incidental_rows",
  "host_bucket_presence_only_rows",
  "host_bucket_unknown_rows",
  "host_exact_source_backed_rows",
  "host_exact_reviewed_needs_review_rows",
  "host_disease_group_proxy_rows",
  "host_weighted_taxonomic_proxy_rows",
  "host_proxy_rows",
  "host_profile_group_proxy_rows",
  "host_proxy_needs_review_rows",
  "host_role_needs_manual_review_rows",
  "host_taxonomy_blank_rows",
  "vector_feature_rows",
  "vector_bucket_primary_rows",
  "vector_bucket_bridge_rows",
  "vector_bucket_enzootic_or_sylvatic_rows",
  "vector_bucket_competence_supported_rows",
  "vector_bucket_direct_association_rows",
  "vector_bucket_unknown_rows",
  "vector_role_needs_review_rows",
  "vector_primary_needs_review_rows",
  "vector_bridge_needs_review_rows",
  "vector_sylvatic_needs_review_rows",
  "vector_source_role_hint_rows",
  "vector_reviewed_assignment_rows",
  "vector_taxonomy_caution_rows",
  "vector_competence_or_transmission_supported_rows",
  "tiered_species_rows",
  "tiered_repo_host_rows",
  "tiered_repo_vector_rows",
  "tiered_delivery_host_rows",
  "tiered_delivery_vector_rows",
  "tiered_no_spatial_layer_rows",
  "tiered_host_taxonomy_blank_rows",
  "active_host_proxy_rule_rows",
  "active_host_proxy_taxid_rule_rows",
  "active_host_proxy_broad_taxonomy_rule_rows",
  "host_role_evidence_rows",
  "host_role_evidence_needs_review_rows",
  "host_role_assignment_rows",
  "host_role_assignment_needs_review_rows",
  "host_evidence_without_assignment_rows",
  "host_assignment_without_evidence_rows",
  "vector_role_evidence_rows",
  "vector_role_evidence_needs_review_rows",
  "vector_role_assignment_rows",
  "vector_role_assignment_needs_review_rows",
  "vector_evidence_without_assignment_rows",
  "vector_assignment_without_evidence_rows",
  "unmatched_vector_assignment_rows",
  "direct_vector_taxonomy_review_needed_rows"
)

audit <- include_tracker %>%
  select(
    disease_name,
    tracker_done = done,
    tracker_scope = scope,
    tracker_review = review,
    tracker_hosts = hosts,
    tracker_vectors = vectors,
    tracker_proxy = proxy,
    tracker_source_check = source_check,
    tracker_features = features,
    tracker_last_reviewed = last_reviewed,
    tracker_next_step = next_step
  ) %>%
  left_join(review_summary, by = "disease_name") %>%
  left_join(roster_summary, by = "disease_name") %>%
  left_join(host_feature_summary, by = "disease_name") %>%
  left_join(vector_feature_summary, by = "disease_name") %>%
  left_join(tiered_summary, by = "disease_name") %>%
  left_join(proxy_rule_summary, by = "disease_name") %>%
  left_join(host_evidence_summary, by = "disease_name") %>%
  left_join(host_assignment_summary, by = "disease_name") %>%
  left_join(host_evidence_assignment_summary, by = "disease_name") %>%
  left_join(vector_evidence_summary, by = "disease_name") %>%
  left_join(vector_assignment_summary, by = "disease_name") %>%
  left_join(vector_evidence_assignment_summary, by = "disease_name") %>%
  left_join(vector_unmatched_summary, by = "disease_name") %>%
  left_join(readiness_summary, by = "disease_name") %>%
  zero_count_columns(count_cols) %>%
  mutate(
    review_note_present = coalesce(review_note_present, FALSE),
    role_assignment_status = coalesce(role_assignment_status, "missing_readiness_row"),
    sdm_availability_status = coalesce(sdm_availability_status, "missing_readiness_row"),
    readiness_blocker = coalesce(readiness_blocker, "missing_readiness_row"),
    recommended_next_action = coalesce(recommended_next_action, "missing_readiness_row"),
    host_high_volume_proxy_flag = host_proxy_rows >= 100,
    host_proxy_policy_flag = host_proxy_rows > 0,
    vector_primary_review_flag = vector_primary_needs_review_rows >= 5,
    vector_review_flag = vector_role_needs_review_rows >= 10,
    evidence_assignment_integrity_flag =
      host_evidence_without_assignment_rows > 0 |
      host_assignment_without_evidence_rows > 0 |
      vector_evidence_without_assignment_rows > 0 |
      vector_assignment_without_evidence_rows > 0,
    group_level_vector_assignment_flag = unmatched_vector_assignment_rows > 0,
    sdm_handoff_blocker_flag = readiness_blocker != "none",
    review_priority_score =
      host_proxy_rows * 2 +
      host_bucket_reservoir_or_amplifying_rows +
      vector_primary_needs_review_rows * 12 +
      vector_role_needs_review_rows * 4 +
      unmatched_vector_assignment_rows * 10 +
      (host_evidence_without_assignment_rows + vector_evidence_without_assignment_rows) * 25 +
      if_else(sdm_handoff_blocker_flag, 5, 0),
    review_focus = case_when(
      host_high_volume_proxy_flag ~ "host_proxy_policy_high_volume",
      vector_primary_review_flag ~ "primary_vector_bucket_review",
      vector_review_flag ~ "vector_bucket_review",
      evidence_assignment_integrity_flag ~ "evidence_assignment_integrity",
      group_level_vector_assignment_flag ~ "group_level_vector_assignment_caveat",
      host_proxy_policy_flag ~ "host_proxy_policy",
      sdm_handoff_blocker_flag ~ "sdm_handoff_blocker",
      TRUE ~ "low_signal_accept_caveats"
    ),
    audit_flags = pmap_chr(
      list(
        if_else(host_high_volume_proxy_flag, "high_volume_host_proxy", NA_character_),
        if_else(host_proxy_policy_flag, "host_proxy_policy", NA_character_),
        if_else(vector_primary_review_flag, "primary_vector_needs_review", NA_character_),
        if_else(vector_review_flag, "vector_bucket_needs_review", NA_character_),
        if_else(evidence_assignment_integrity_flag, "evidence_assignment_mismatch", NA_character_),
        if_else(group_level_vector_assignment_flag, "group_level_vector_assignment", NA_character_),
        if_else(sdm_handoff_blocker_flag, "sdm_handoff_blocker", NA_character_)
      ),
      combine_flags
    )
  ) %>%
  arrange(desc(review_priority_score), disease_name) %>%
  mutate(review_priority_rank = row_number()) %>%
  select(
    disease_name,
    review_priority_rank,
    review_priority_score,
    review_focus,
    audit_flags,
    tracker_done,
    tracker_scope,
    tracker_review,
    tracker_hosts,
    tracker_vectors,
    tracker_proxy,
    tracker_source_check,
    tracker_features,
    tracker_last_reviewed,
    tracker_next_step,
    review_note_present,
    review_note_files,
    role_assignment_status,
    sdm_availability_status,
    readiness_blocker,
    recommended_next_action,
    host_sdm_needed,
    vector_sdm_needed,
    host_sdm_species_available,
    vector_sdm_species_available,
    roster_rows,
    roster_host_rows,
    roster_vector_rows,
    roster_host_taxonomy_blank_rows,
    roster_vector_taxonomy_caution_rows,
    roster_vectors_with_disease_vector_evidence,
    roster_vectors_with_host_vector_evidence,
    roster_vectors_with_competence_evidence,
    host_feature_rows,
    host_bucket_reservoir_or_amplifying_rows,
    host_bucket_susceptible_or_spillover_rows,
    host_bucket_dead_end_or_incidental_rows,
    host_bucket_presence_only_rows,
    host_bucket_unknown_rows,
    host_exact_source_backed_rows,
    host_exact_reviewed_needs_review_rows,
    host_disease_group_proxy_rows,
    host_weighted_taxonomic_proxy_rows,
    host_proxy_rows,
    host_profile_group_proxy_rows,
    host_proxy_needs_review_rows,
    host_role_needs_manual_review_rows,
    host_taxonomy_blank_rows,
    host_proxy_rule_ids,
    active_host_proxy_rule_rows,
    active_host_proxy_taxid_rule_rows,
    active_host_proxy_broad_taxonomy_rule_rows,
    active_host_proxy_rule_ids,
    vector_feature_rows,
    vector_bucket_primary_rows,
    vector_bucket_bridge_rows,
    vector_bucket_enzootic_or_sylvatic_rows,
    vector_bucket_competence_supported_rows,
    vector_bucket_direct_association_rows,
    vector_bucket_unknown_rows,
    vector_role_needs_review_rows,
    vector_primary_needs_review_rows,
    vector_bridge_needs_review_rows,
    vector_sylvatic_needs_review_rows,
    vector_source_role_hint_rows,
    vector_reviewed_assignment_rows,
    vector_taxonomy_caution_rows,
    vector_competence_or_transmission_supported_rows,
    tiered_species_rows,
    tiered_repo_host_rows,
    tiered_repo_vector_rows,
    tiered_delivery_host_rows,
    tiered_delivery_vector_rows,
    tiered_no_spatial_layer_rows,
    tiered_host_taxonomy_blank_rows,
    host_role_evidence_rows,
    host_role_assignment_rows,
    host_role_evidence_needs_review_rows,
    host_role_assignment_needs_review_rows,
    host_evidence_without_assignment_rows,
    host_assignment_without_evidence_rows,
    vector_role_evidence_rows,
    vector_role_assignment_rows,
    vector_role_evidence_needs_review_rows,
    vector_role_assignment_needs_review_rows,
    vector_evidence_without_assignment_rows,
    vector_assignment_without_evidence_rows,
    unmatched_vector_assignment_rows,
    unmatched_vector_assignment_labels,
    host_candidate_rows,
    direct_vector_species_or_taxa,
    direct_vector_taxonomy_review_needed_rows
  )

stopifnot(nrow(audit) == nrow(include_tracker))
stopifnot(!anyDuplicated(audit$disease_name))

output_path <- file.path(role_qa_dir, "include_species_role_evidence_audit.csv")
dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
write_csv(audit, output_path, na = "")

message("Wrote include species-role evidence audit: ", output_path)
message("Rows in include_species_role_evidence_audit.csv: ", nrow(audit))
