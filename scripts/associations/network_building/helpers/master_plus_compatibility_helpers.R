# ------------------------------------------------------------------------------
# master_plus_compatibility_helpers.R
# ------------------------------------------------------------------------------
# Purpose: Expose a legacy-shaped compatibility view of the master-plus WHO
#          host-pathogen network for downstream consumers that still expect the
#          old canonical zoonotic network contract.
#
# Inputs : master_plus_who_host_network.csv
#          combined_who_network_canonical_zoonotic.csv (contract/order check)
#
# Output : in-memory 22-column compatibility view at legacy association grain
# ------------------------------------------------------------------------------

requireNamespace("dplyr", quietly = TRUE)
requireNamespace("readr", quietly = TRUE)
requireNamespace("stringr", quietly = TRUE)

`%>%` <- dplyr::`%>%`

legacy_compatibility_expected_flagged_rows <- 3514L
legacy_compatibility_expected_association_rows <- 3072L

legacy_compatibility_columns <- c(
  "Pathogen",
  "Pathogen_raw_examples",
  "PathogenTaxID",
  "PHEIC risk",
  "Disease_name",
  "Disease_name_raw_examples",
  "HostTaxID",
  "Host",
  "PathogenClass",
  "PathogenOrder",
  "PathogenFamily",
  "PathogenGenus",
  "HostPhylum",
  "HostClass",
  "HostFamily",
  "HostOrder",
  "DetectionMethod",
  "MainSource",
  "PathogenType",
  "is_zoonotic",
  "zoonotic_status",
  "canonicalization_status"
)

legacy_compatibility_required_master_columns <- c(
  "Disease_name",
  "Pathogen",
  "PathogenTaxID",
  "Host",
  "HostTaxID",
  "in_legacy_canonical_zoonotic_pathogen_host",
  legacy_compatibility_columns
)

legacy_compatibility_clean_text <- function(x) {
  x <- as.character(x)
  x[x %in% c("", "NA", "NaN", "null", "Null")] <- NA_character_
  x <- stringr::str_replace_all(x, "\u00A0", " ")
  x <- stringr::str_replace_all(x, "[\r\n\t]+", " ")
  x <- stringr::str_squish(x)
  x[x == ""] <- NA_character_
  x
}

legacy_compatibility_scope_key <- function(x) {
  x %>%
    legacy_compatibility_clean_text() %>%
    stringr::str_to_lower() %>%
    stringr::str_replace_all("&", " and ") %>%
    stringr::str_replace_all("[^a-z0-9]+", " ") %>%
    stringr::str_squish()
}

legacy_compatibility_association_key <- function(data) {
  paste(
    legacy_compatibility_scope_key(data$Disease_name),
    legacy_compatibility_clean_text(data$PathogenTaxID),
    legacy_compatibility_scope_key(data$Pathogen),
    legacy_compatibility_clean_text(data$HostTaxID),
    legacy_compatibility_scope_key(data$Host),
    sep = "|||"
  )
}

legacy_compatibility_is_true <- function(x) {
  x %in% c(TRUE, "TRUE", "true", "True", 1, "1")
}

legacy_compatibility_first_non_missing <- function(x) {
  x <- legacy_compatibility_clean_text(x)
  x <- x[!is.na(x)]

  if (length(x) == 0) {
    return(NA_character_)
  }

  x[[1]]
}

legacy_compatibility_collapse_unique <- function(x) {
  x <- legacy_compatibility_clean_text(x)
  x <- unique(x[!is.na(x)])

  if (length(x) == 0) {
    return(NA_character_)
  }

  paste(x, collapse = "; ")
}

legacy_compatibility_pathogen_label <- function(raw_examples, fallback) {
  label <- legacy_compatibility_first_non_missing(raw_examples)

  if (is.na(label)) {
    label <- legacy_compatibility_first_non_missing(fallback)
  }

  binomial_lower <- !is.na(label) &&
    stringr::str_detect(label, "^[a-z][a-z-]+ [a-z][a-z-]+$")

  if (binomial_lower) {
    substring(label, 1, 1) <- toupper(substring(label, 1, 1))
  }

  label
}

legacy_compatibility_check_columns <- function(data, columns, label) {
  missing <- setdiff(columns, names(data))

  if (length(missing) > 0) {
    stop(
      label,
      " is missing required columns: ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
}

read_legacy_compatible_master_plus_network <- function(
  master_plus_path = who_network_host_pathogen_path("master_plus_who_host_network.csv"),
  legacy_contract_path = who_canonical_zoonotic_network_path(),
  validate_counts = TRUE
) {
  if (!exists("who_network_host_pathogen_path", mode = "function") ||
      !exists("who_canonical_zoonotic_network_path", mode = "function")) {
    stop(
      "Source scripts/associations/working_inputs.R before sourcing ",
      "master_plus_compatibility_helpers.R.",
      call. = FALSE
    )
  }

  missing_paths <- c(master_plus_path, legacy_contract_path)[
    !file.exists(c(master_plus_path, legacy_contract_path))
  ]

  if (length(missing_paths) > 0) {
    stop(
      "Missing required WHO network compatibility input(s): ",
      paste(missing_paths, collapse = "; "),
      call. = FALSE
    )
  }

  master_plus <- readr::read_csv(
    master_plus_path,
    show_col_types = FALSE,
    progress = FALSE,
    na = c("", "NA")
  )

  legacy_contract <- readr::read_csv(
    legacy_contract_path,
    show_col_types = FALSE,
    progress = FALSE,
    na = c("", "NA")
  )

  legacy_compatibility_check_columns(
    master_plus,
    legacy_compatibility_required_master_columns,
    "master_plus_who_host_network.csv"
  )
  legacy_compatibility_check_columns(
    legacy_contract,
    legacy_compatibility_columns,
    "combined_who_network_canonical_zoonotic.csv"
  )

  if (any(is.na(master_plus$in_legacy_canonical_zoonotic_pathogen_host))) {
    stop(
      "master_plus_who_host_network.csv has missing ",
      "in_legacy_canonical_zoonotic_pathogen_host values.",
      call. = FALSE
    )
  }

  flagged <- master_plus[
    legacy_compatibility_is_true(
      master_plus$in_legacy_canonical_zoonotic_pathogen_host
    ),
  ]
  flagged$.legacy_compatibility_key <-
    legacy_compatibility_association_key(flagged)

  legacy_contract <- legacy_contract[, legacy_compatibility_columns]
  legacy_contract$.legacy_compatibility_key <-
    legacy_compatibility_association_key(legacy_contract)

  duplicate_legacy_keys <- legacy_contract$.legacy_compatibility_key[
    duplicated(legacy_contract$.legacy_compatibility_key)
  ]

  if (length(duplicate_legacy_keys) > 0) {
    stop(
      "Legacy canonical zoonotic network has duplicated association keys.",
      call. = FALSE
    )
  }

  missing_legacy_keys <- setdiff(
    legacy_contract$.legacy_compatibility_key,
    unique(flagged$.legacy_compatibility_key)
  )
  extra_flagged_keys <- setdiff(
    unique(flagged$.legacy_compatibility_key),
    legacy_contract$.legacy_compatibility_key
  )

  if (length(missing_legacy_keys) > 0) {
    stop(
      "Master-plus compatibility flag is missing ",
      length(missing_legacy_keys),
      " legacy association key(s).",
      call. = FALSE
    )
  }

  if (length(extra_flagged_keys) > 0) {
    stop(
      "Master-plus compatibility flag contains ",
      length(extra_flagged_keys),
      " association key(s) outside the legacy contract.",
      call. = FALSE
    )
  }

  reconstructed <- flagged %>%
    dplyr::group_by(.legacy_compatibility_key) %>%
    dplyr::summarise(
      Pathogen = legacy_compatibility_pathogen_label(
        Pathogen_raw_examples,
        Pathogen
      ),
      Pathogen_raw_examples = legacy_compatibility_collapse_unique(
        Pathogen_raw_examples
      ),
      PathogenTaxID = legacy_compatibility_first_non_missing(PathogenTaxID),
      `PHEIC risk` = legacy_compatibility_first_non_missing(`PHEIC risk`),
      Disease_name = legacy_compatibility_first_non_missing(
        Disease_name_raw_examples
      ),
      Disease_name_raw_examples = legacy_compatibility_collapse_unique(
        Disease_name_raw_examples
      ),
      HostTaxID = legacy_compatibility_first_non_missing(HostTaxID),
      Host = legacy_compatibility_first_non_missing(Host),
      PathogenClass = legacy_compatibility_first_non_missing(PathogenClass),
      PathogenOrder = legacy_compatibility_first_non_missing(PathogenOrder),
      PathogenFamily = legacy_compatibility_first_non_missing(PathogenFamily),
      PathogenGenus = legacy_compatibility_first_non_missing(PathogenGenus),
      HostPhylum = legacy_compatibility_first_non_missing(HostPhylum),
      HostClass = legacy_compatibility_first_non_missing(HostClass),
      HostFamily = legacy_compatibility_first_non_missing(HostFamily),
      HostOrder = legacy_compatibility_first_non_missing(HostOrder),
      DetectionMethod = legacy_compatibility_collapse_unique(DetectionMethod),
      MainSource = legacy_compatibility_collapse_unique(MainSource),
      PathogenType = legacy_compatibility_first_non_missing(PathogenType),
      is_zoonotic = dplyr::first(is_zoonotic),
      zoonotic_status = legacy_compatibility_first_non_missing(zoonotic_status),
      canonicalization_status = legacy_compatibility_collapse_unique(
        canonicalization_status
      ),
      .groups = "drop"
    )

  if (validate_counts) {
    if (nrow(flagged) != legacy_compatibility_expected_flagged_rows) {
      stop(
        "Expected ",
        legacy_compatibility_expected_flagged_rows,
        " flagged master-plus rows, found ",
        nrow(flagged),
        ".",
        call. = FALSE
      )
    }

    if (nrow(reconstructed) != legacy_compatibility_expected_association_rows) {
      stop(
        "Expected ",
        legacy_compatibility_expected_association_rows,
        " legacy-compatible association rows, found ",
        nrow(reconstructed),
        ".",
        call. = FALSE
      )
    }
  }

  reconstructed <- reconstructed[
    match(
      legacy_contract$.legacy_compatibility_key,
      reconstructed$.legacy_compatibility_key
    ),
  ]

  reconstructed[, legacy_compatibility_columns]
}

read_manual_role_review_status <- function(
  status_path = file.path(role_manual_dir, "disease_role_review_status.csv"),
  include_scopes = c("include", "review")
) {
  if (!exists("role_manual_dir", mode = "character") || !file.exists(status_path)) {
    return(dplyr::tibble(disease_name = character(), scope = character()))
  }

  readr::read_csv(
    status_path,
    show_col_types = FALSE,
    progress = FALSE,
    na = c("", "NA")
  ) %>%
    dplyr::mutate(dplyr::across(where(is.character), legacy_compatibility_clean_text)) %>%
    dplyr::filter(scope %in% include_scopes, !is.na(disease_name)) %>%
    dplyr::mutate(.role_review_disease_key = legacy_compatibility_scope_key(disease_name)) %>%
    dplyr::distinct(.role_review_disease_key, .keep_all = TRUE)
}

read_role_review_scope_rows <- function(
  zoonotic_path = who_pathogens_diseases_zoonotic_path(),
  master_units_path = who_master_plus_analysis_units_path(),
  status_path = file.path(role_manual_dir, "disease_role_review_status.csv"),
  include_scopes = c("include", "review")
) {
  active_scope <- readr::read_csv(
    zoonotic_path,
    show_col_types = FALSE,
    progress = FALSE,
    na = c("", "NA")
  ) %>%
    dplyr::mutate(dplyr::across(where(is.character), legacy_compatibility_clean_text)) %>%
    dplyr::filter(
      legacy_compatibility_is_true(in_gibb_etal) |
        legacy_compatibility_is_true(in_empres_i),
      Pathogens != "Genus Vesiculovirus"
    ) %>%
    dplyr::transmute(
      disease_name = Disease_name,
      active_source_pathogen = Pathogens,
      in_gibb_etal = legacy_compatibility_is_true(in_gibb_etal),
      in_empres_i = legacy_compatibility_is_true(in_empres_i),
      priority_prototype_status,
      active_scope_reason = paste0(
        "in_gibb_etal=", in_gibb_etal,
        "; in_empres_i=", in_empres_i,
        "; deferred_broad_vesiculovirus=FALSE"
      )
    )

  manual_status <- read_manual_role_review_status(
    status_path = status_path,
    include_scopes = include_scopes
  )

  if (nrow(manual_status) == 0 || !file.exists(master_units_path)) {
    return(active_scope)
  }

  active_keys <- unique(legacy_compatibility_scope_key(active_scope$disease_name))

  manual_status <- manual_status %>%
    dplyr::filter(!.role_review_disease_key %in% active_keys)

  if (nrow(manual_status) == 0) {
    return(active_scope)
  }

  master_units <- readr::read_csv(
    master_units_path,
    show_col_types = FALSE,
    progress = FALSE,
    na = c("", "NA")
  ) %>%
    dplyr::mutate(dplyr::across(where(is.character), legacy_compatibility_clean_text))

  master_keys <- master_units %>%
    dplyr::mutate(
      .role_review_disease_key = legacy_compatibility_scope_key(disease_master_name)
    ) %>%
    dplyr::select(
      .role_review_disease_key,
      dplyr::any_of(c(
        "analysis_unit_id",
        "matched_pathogen_names",
        "source_pathogen",
        "priority_prototype_status"
      ))
    ) %>%
    dplyr::distinct(.role_review_disease_key, .keep_all = TRUE)

  manual_scope <- manual_status %>%
    dplyr::left_join(master_keys, by = ".role_review_disease_key") %>%
    dplyr::transmute(
      disease_name,
      active_source_pathogen = dplyr::coalesce(matched_pathogen_names, source_pathogen),
      in_gibb_etal = FALSE,
      in_empres_i = FALSE,
      priority_prototype_status,
      active_scope_reason = paste0(
        "manual_role_review_status_scope=", scope,
        "; analysis_unit_id=", analysis_unit_id
      )
    )

  dplyr::bind_rows(active_scope, manual_scope)
}

read_role_review_master_plus_network <- function(
  master_plus_path = who_network_host_pathogen_path("master_plus_who_host_network.csv"),
  legacy_contract_path = who_canonical_zoonotic_network_path(),
  status_path = file.path(role_manual_dir, "disease_role_review_status.csv"),
  include_scopes = c("include", "review"),
  validate_legacy_counts = TRUE
) {
  legacy <- read_legacy_compatible_master_plus_network(
    master_plus_path = master_plus_path,
    legacy_contract_path = legacy_contract_path,
    validate_counts = validate_legacy_counts
  ) %>%
    dplyr::mutate(dplyr::across(dplyr::all_of(legacy_compatibility_columns), as.character))

  manual_status <- read_manual_role_review_status(
    status_path = status_path,
    include_scopes = include_scopes
  )

  legacy_disease_keys <- unique(legacy_compatibility_scope_key(legacy$Disease_name))
  manual_status <- manual_status %>%
    dplyr::filter(!.role_review_disease_key %in% legacy_disease_keys)

  if (nrow(manual_status) == 0) {
    return(legacy)
  }

  master_plus <- readr::read_csv(
    master_plus_path,
    show_col_types = FALSE,
    progress = FALSE,
    na = c("", "NA")
  ) %>%
    dplyr::mutate(dplyr::across(where(is.character), legacy_compatibility_clean_text))

  legacy_compatibility_check_columns(
    master_plus,
    c(legacy_compatibility_columns, "disease_master_name", "modelling_scope_status"),
    "master_plus_who_host_network.csv"
  )

  manual_rows <- master_plus %>%
    dplyr::mutate(
      .role_review_disease_key = legacy_compatibility_scope_key(disease_master_name)
    ) %>%
    dplyr::inner_join(
      manual_status %>% dplyr::select(.role_review_disease_key, disease_name),
      by = ".role_review_disease_key"
    ) %>%
    dplyr::filter(modelling_scope_status %in% include_scopes) %>%
    dplyr::mutate(Disease_name = disease_name) %>%
    dplyr::group_by(Disease_name, PathogenTaxID, Pathogen, HostTaxID, Host) %>%
    dplyr::summarise(
      Pathogen_raw_examples = legacy_compatibility_collapse_unique(Pathogen_raw_examples),
      `PHEIC risk` = legacy_compatibility_first_non_missing(`PHEIC risk`),
      Disease_name_raw_examples = legacy_compatibility_collapse_unique(Disease_name_raw_examples),
      PathogenClass = legacy_compatibility_first_non_missing(PathogenClass),
      PathogenOrder = legacy_compatibility_first_non_missing(PathogenOrder),
      PathogenFamily = legacy_compatibility_first_non_missing(PathogenFamily),
      PathogenGenus = legacy_compatibility_first_non_missing(PathogenGenus),
      HostPhylum = legacy_compatibility_first_non_missing(HostPhylum),
      HostClass = legacy_compatibility_first_non_missing(HostClass),
      HostFamily = legacy_compatibility_first_non_missing(HostFamily),
      HostOrder = legacy_compatibility_first_non_missing(HostOrder),
      DetectionMethod = legacy_compatibility_collapse_unique(DetectionMethod),
      MainSource = legacy_compatibility_collapse_unique(MainSource),
      PathogenType = legacy_compatibility_first_non_missing(PathogenType),
      is_zoonotic = TRUE,
      zoonotic_status = legacy_compatibility_first_non_missing(zoonotic_status),
      canonicalization_status = legacy_compatibility_collapse_unique(canonicalization_status),
      .groups = "drop"
    ) %>%
    dplyr::select(dplyr::all_of(legacy_compatibility_columns)) %>%
    dplyr::mutate(dplyr::across(dplyr::all_of(legacy_compatibility_columns), as.character))

  dplyr::bind_rows(legacy, manual_rows)
}
