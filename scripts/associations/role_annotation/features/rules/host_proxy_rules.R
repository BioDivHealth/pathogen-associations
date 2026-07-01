################################################################################
# host_proxy_rules.R
################################################################################
# Purpose: Derive modelling-facing host-role proxy fields from reviewed role
#          assignments and manual disease/taxonomic proxy-rule tables.
#
# Rule contract:
# - exact source-backed assignments win;
# - reviewed assignments win before broad proxies;
# - group proxies stay review-needed unless explicitly accepted upstream;
# - role weights are separate from SDM or model-quality weights.
################################################################################

host_proxy_rule_columns <- c(
  "rule_id",
  "rule_active",
  "disease_name",
  "priority",
  "host_class",
  "host_order",
  "host_family",
  "species_name",
  "tax_id",
  "modelling_role_proxy",
  "modelling_role_proxy_basis",
  "host_role_bucket",
  "host_role_evidence_basis",
  "modelling_role_proxy_confidence",
  "modelling_role_proxy_needs_review",
  "rule_notes"
)

parse_host_proxy_logical <- function(x, column_name) {
  values <- clean_text(x)
  true_values <- c("TRUE", "true", "True", "1", "yes", "Yes", "YES")
  false_values <- c("FALSE", "false", "False", "0", "no", "No", "NO")
  valid_values <- c(true_values, false_values)
  invalid <- !is.na(values) & !values %in% valid_values

  if (any(invalid)) {
    stop(
      "Invalid logical value in host proxy rule column `",
      column_name,
      "`: ",
      paste(unique(values[invalid]), collapse = ", "),
      call. = FALSE
    )
  }

  dplyr::case_when(
    values %in% true_values ~ TRUE,
    values %in% false_values ~ FALSE,
    TRUE ~ NA
  )
}

validate_host_proxy_rules <- function(rules) {
  missing_columns <- setdiff(host_proxy_rule_columns, names(rules))
  if (length(missing_columns) > 0) {
    stop(
      "Host proxy rule table is missing required columns: ",
      paste(missing_columns, collapse = ", "),
      call. = FALSE
    )
  }

  active_rules <- rules %>%
    dplyr::filter(rule_active)

  if (nrow(active_rules) == 0) {
    stop("Host proxy rule table has no active rules.", call. = FALSE)
  }

  required_active_columns <- c(
    "rule_id",
    "disease_name",
    "priority",
    "modelling_role_proxy",
    "modelling_role_proxy_basis",
    "host_role_bucket",
    "host_role_evidence_basis",
    "modelling_role_proxy_confidence",
    "modelling_role_proxy_needs_review"
  )

  missing_required_values <- purrr::keep(
    required_active_columns,
    ~ any(is.na(active_rules[[.x]]))
  )

  if (length(missing_required_values) > 0) {
    stop(
      "Active host proxy rules have missing required values in: ",
      paste(missing_required_values, collapse = ", "),
      call. = FALSE
    )
  }

  invisible(rules)
}

read_host_proxy_rules <- function(path) {
  if (!file.exists(path)) {
    stop("Host proxy rule table is missing: ", path, call. = FALSE)
  }

  rules <- readr::read_csv(
    path,
    show_col_types = FALSE,
    na = c("", "NA"),
    col_types = readr::cols(
      .default = readr::col_character(),
      priority = readr::col_double()
    )
  )

  missing_columns <- setdiff(host_proxy_rule_columns, names(rules))
  if (length(missing_columns) > 0) {
    stop(
      "Host proxy rule table is missing required columns: ",
      paste(missing_columns, collapse = ", "),
      call. = FALSE
    )
  }

  rules <- rules %>%
    dplyr::select(dplyr::all_of(host_proxy_rule_columns)) %>%
    dplyr::mutate(
      dplyr::across(where(is.character), clean_text),
      rule_active = dplyr::coalesce(
        parse_host_proxy_logical(rule_active, "rule_active"),
        FALSE
      ),
      modelling_role_proxy_needs_review = parse_host_proxy_logical(
        modelling_role_proxy_needs_review,
        "modelling_role_proxy_needs_review"
      )
    )

  validate_host_proxy_rules(rules)
}

host_role_confidence_weight <- function(confidence, bucket) {
  dplyr::case_when(
    bucket == "unknown_or_unreviewed" ~ 0,
    bucket == "host_presence_only" & confidence == "low" ~ 0.1,
    confidence == "high" ~ 1,
    confidence == "medium" ~ 0.75,
    confidence == "medium_low" ~ 0.5,
    confidence == "low" ~ 0.25,
    TRUE ~ 0.1
  )
}

classify_host_role_bucket <- function(modelling_role_proxy) {
  dplyr::case_when(
    stringr::str_detect(
      modelling_role_proxy,
      stringr::regex("reservoir|amplifying|competence", ignore_case = TRUE)
    ) ~ "reservoir_or_amplifying_host",
    stringr::str_detect(
      modelling_role_proxy,
      stringr::regex("dead_end|incidental", ignore_case = TRUE)
    ) ~ "dead_end_or_incidental_host",
    modelling_role_proxy == "galliform_avian_host_group_proxy" ~
      "susceptible_or_spillover_host",
    stringr::str_detect(
      modelling_role_proxy,
      stringr::regex("susceptible|spillover", ignore_case = TRUE)
    ) ~ "susceptible_or_spillover_host",
    modelling_role_proxy == "host_presence_only" |
      stringr::str_detect(
        modelling_role_proxy,
        stringr::regex("host_presence", ignore_case = TRUE)
      ) ~ "host_presence_only",
    TRUE ~ "unknown_or_unreviewed"
  )
}

classify_host_role_evidence_basis <- function(modelling_role_proxy_basis) {
  dplyr::case_when(
    modelling_role_proxy_basis == "source_backed_role_assignment" ~
      "exact_source_backed",
    modelling_role_proxy_basis == "reviewed_role_assignment_needs_review" ~
      "exact_reviewed_needs_review",
    stringr::str_detect(
      modelling_role_proxy_basis,
      stringr::regex("weighted_rule", ignore_case = TRUE)
    ) ~ "weighted_taxonomic_proxy",
    stringr::str_detect(
      modelling_role_proxy_basis,
      stringr::regex("_group_rule_", ignore_case = TRUE)
    ) ~ "disease_group_proxy",
    modelling_role_proxy_basis == "candidate_role_assignment" ~ "candidate_only",
    TRUE ~ "candidate_only"
  )
}

prepare_host_proxy_rule_matches <- function(proxy_rules) {
  validate_host_proxy_rules(proxy_rules)

  proxy_rules %>%
    dplyr::filter(rule_active) %>%
    dplyr::mutate(
      .rule_order = dplyr::row_number(),
      .disease_key = clean_key(disease_name),
      .rule_host_class_key = clean_key(host_class),
      .rule_host_order_key = clean_key(host_order),
      .rule_host_family_key = clean_key(host_family),
      .rule_species_key = clean_key(species_name),
      .rule_tax_id_key = clean_text(tax_id)
    )
}

host_proxy_rule_field_matches <- function(rule_key, host_key) {
  is.na(rule_key) | (!is.na(host_key) & rule_key == host_key)
}

empty_host_proxy_rule_matches <- function(data) {
  data %>%
    dplyr::mutate(
      .proxy_rule_id = NA_character_,
      .proxy_modelling_role_proxy = NA_character_,
      .proxy_modelling_role_proxy_basis = NA_character_,
      .proxy_host_role_bucket = NA_character_,
      .proxy_host_role_evidence_basis = NA_character_,
      .proxy_modelling_role_proxy_confidence = NA_character_,
      .proxy_modelling_role_proxy_needs_review = NA
    )
}

match_host_proxy_rules <- function(data, proxy_rules) {
  rules <- prepare_host_proxy_rule_matches(proxy_rules)
  if (nrow(rules) == 0) {
    return(empty_host_proxy_rule_matches(data))
  }

  candidates <- data %>%
    dplyr::mutate(
      .host_proxy_row_id = dplyr::row_number(),
      .disease_key = clean_key(readiness_disease_name),
      .host_class_key = clean_key(host_class),
      .host_order_key = clean_key(host_order),
      .host_family_key = clean_key(host_family),
      .species_key = clean_key(species_name),
      .tax_id_key = clean_text(tax_id)
    ) %>%
    dplyr::select(
      .host_proxy_row_id,
      .disease_key,
      .host_class_key,
      .host_order_key,
      .host_family_key,
      .species_key,
      .tax_id_key
    )

  matches <- candidates %>%
    dplyr::inner_join(rules, by = ".disease_key", relationship = "many-to-many") %>%
    dplyr::filter(
      host_proxy_rule_field_matches(.rule_host_class_key, .host_class_key),
      host_proxy_rule_field_matches(.rule_host_order_key, .host_order_key),
      host_proxy_rule_field_matches(.rule_host_family_key, .host_family_key),
      host_proxy_rule_field_matches(.rule_species_key, .species_key),
      host_proxy_rule_field_matches(.rule_tax_id_key, .tax_id_key)
    ) %>%
    dplyr::arrange(.host_proxy_row_id, priority, .rule_order) %>%
    dplyr::distinct(.host_proxy_row_id, .keep_all = TRUE) %>%
    dplyr::transmute(
      .host_proxy_row_id,
      .proxy_rule_id = rule_id,
      .proxy_modelling_role_proxy = modelling_role_proxy,
      .proxy_modelling_role_proxy_basis = modelling_role_proxy_basis,
      .proxy_host_role_bucket = host_role_bucket,
      .proxy_host_role_evidence_basis = host_role_evidence_basis,
      .proxy_modelling_role_proxy_confidence = modelling_role_proxy_confidence,
      .proxy_modelling_role_proxy_needs_review = modelling_role_proxy_needs_review
    )

  data %>%
    dplyr::mutate(.host_proxy_row_id = dplyr::row_number()) %>%
    dplyr::left_join(matches, by = ".host_proxy_row_id") %>%
    dplyr::select(-.host_proxy_row_id)
}

resolve_host_proxy_rules <- function(proxy_rules) {
  if (is.null(proxy_rules)) {
    if (!exists("role_host_proxy_rules_path", mode = "function")) {
      stop(
        "`proxy_rules` must be supplied when `role_host_proxy_rules_path()` is not available.",
        call. = FALSE
      )
    }
    return(read_host_proxy_rules(role_host_proxy_rules_path()))
  }

  if (is.character(proxy_rules) && length(proxy_rules) == 1) {
    return(read_host_proxy_rules(proxy_rules))
  }

  validate_host_proxy_rules(proxy_rules)
}

add_host_modelling_proxy <- function(data, proxy_rules = NULL) {
  proxy_rules <- resolve_host_proxy_rules(proxy_rules)

  data %>%
    dplyr::mutate(
      .source_backed_specific_role = host_role_source_backed & host_role_specific,
      .reviewed_specific_role = host_role_specific &
        host_role_assignment_status %in% c("draft_source_backed", "draft_needs_review")
    ) %>%
    match_host_proxy_rules(proxy_rules) %>%
    dplyr::mutate(
      modelling_role_proxy = dplyr::case_when(
        .reviewed_specific_role ~ host_role_assignment,
        !is.na(.proxy_modelling_role_proxy) ~ .proxy_modelling_role_proxy,
        TRUE ~ host_role_assignment
      ),
      modelling_role_proxy_basis = dplyr::case_when(
        .source_backed_specific_role ~ "source_backed_role_assignment",
        .reviewed_specific_role ~ "reviewed_role_assignment_needs_review",
        !is.na(.proxy_modelling_role_proxy_basis) ~ .proxy_modelling_role_proxy_basis,
        TRUE ~ "candidate_role_assignment"
      ),
      modelling_role_proxy_confidence = dplyr::case_when(
        .reviewed_specific_role ~ host_role_confidence,
        !is.na(.proxy_modelling_role_proxy_confidence) ~
          .proxy_modelling_role_proxy_confidence,
        TRUE ~ host_role_confidence
      ),
      modelling_role_proxy_rule_id = dplyr::case_when(
        .source_backed_specific_role ~ "source_backed_role_v0_1",
        .reviewed_specific_role ~ "reviewed_role_needs_review_v0_1",
        !is.na(.proxy_rule_id) ~ .proxy_rule_id,
        TRUE ~ "candidate_role_v0_1"
      ),
      modelling_role_proxy_needs_review = dplyr::case_when(
        .reviewed_specific_role ~ missing_as_false(host_role_needs_manual_review),
        !is.na(.proxy_rule_id) ~ .proxy_modelling_role_proxy_needs_review,
        TRUE ~ missing_as_false(host_role_needs_manual_review)
      ),
      host_role_bucket = dplyr::case_when(
        !.reviewed_specific_role & !is.na(.proxy_host_role_bucket) ~
          .proxy_host_role_bucket,
        TRUE ~ classify_host_role_bucket(modelling_role_proxy)
      ),
      host_role_evidence_basis = dplyr::case_when(
        .source_backed_specific_role ~ "exact_source_backed",
        .reviewed_specific_role ~ "exact_reviewed_needs_review",
        !is.na(.proxy_host_role_evidence_basis) ~ .proxy_host_role_evidence_basis,
        TRUE ~ classify_host_role_evidence_basis(modelling_role_proxy_basis)
      ),
      host_role_weight = host_role_confidence_weight(
        modelling_role_proxy_confidence,
        host_role_bucket
      ),
      role_proxy_applied = !is.na(modelling_role_proxy) &
        modelling_role_proxy != "host_presence_only",
      group_proxy_applied = !is.na(.proxy_rule_id) & !.reviewed_specific_role,
      profile_group_proxy = group_proxy_applied & taxonomy_ok
    ) %>%
    dplyr::select(-dplyr::starts_with("."))
}
