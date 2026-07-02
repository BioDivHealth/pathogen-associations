# ------------------------------------------------------------------------------
# association_text_helpers.R
# ------------------------------------------------------------------------------
# Purpose: Shared text/key helpers for pathogen-association scripts where the
#          helper behavior is intentionally identical.
# ------------------------------------------------------------------------------

clean_text <- function(x) {
  x <- as.character(x)
  x[x %in% c("", "NA", "NaN", "No data", "null", "Null")] <- NA_character_
  x <- stringr::str_replace_all(x, "\u00A0", " ")
  x <- stringr::str_replace_all(x, "[\r\n\t]+", " ")
  x <- stringr::str_squish(x)
  x[x == ""] <- NA_character_
  x
}

normalize_name_for_match <- function(x) {
  x <- clean_text(x)
  x <- stringr::str_to_lower(x)
  x <- stringr::str_replace_all(x, "haemorrh", "hemorrh")
  x <- stringr::str_replace_all(x, "&", " and ")
  x <- stringr::str_replace_all(x, "[/]", " ")
  x <- stringr::str_replace_all(x, "[-–—]", " ")
  x <- stringr::str_replace_all(x, "[()\\[\\],.;:*'`\"]", " ")
  x <- stringr::str_replace_all(x, "\\bviruses\\b", "virus")
  x <- stringr::str_replace_all(x, "\\s+", " ")
  x <- stringr::str_trim(x)
  x[x == ""] <- NA_character_
  x
}

ascii_transliterate_text <- function(x) {
  x <- clean_text(x)

  if (requireNamespace("stringi", quietly = TRUE)) {
    return(stringi::stri_trans_general(x, "Latin-ASCII"))
  }

  transliterated <- suppressWarnings(iconv(x, from = "", to = "ASCII//TRANSLIT"))
  transliterated[is.na(transliterated)] <- x[is.na(transliterated)]
  transliterated
}

normalize_vector_key <- function(x) {
  # Join keys are deliberately punctuation-insensitive ASCII strings so vector
  # evidence, competence, and host-vector sources share one equality contract.
  x <- ascii_transliterate_text(x)
  x <- stringr::str_to_lower(x)
  x <- stringr::str_replace_all(x, "[/|_\\\\]+", " ")
  x <- stringr::str_replace_all(x, "[-–—]+", " ")
  x <- stringr::str_replace_all(x, "[^a-z0-9]+", " ")
  x <- stringr::str_squish(x)
  x[x == ""] <- NA_character_
  x
}

append_vector_cleanup_method <- function(current, new_method) {
  dplyr::case_when(
    is.na(current) | current == "" ~ new_method,
    TRUE ~ paste(current, new_method, sep = "; ")
  )
}

format_vector_cleanup_name <- function(x, name_case = c("lower", "sentence")) {
  name_case <- match.arg(name_case)

  if (name_case == "lower") {
    return(x)
  }

  dplyr::if_else(
    is.na(x),
    NA_character_,
    stringr::str_replace(x, "^([a-z])", ~ stringr::str_to_upper(.x))
  )
}

apply_vector_name_cleanup <- function(
  x,
  manual_map = NULL,
  unchanged_method = "normalized_name",
  name_case = c("lower", "sentence")
) {
  # Biological cleanup runs before display casing; manual maps run last so
  # curated taxonomy fixes override general subgenus/authorship rules.
  name_case <- match.arg(name_case)
  cleaned <- ascii_transliterate_text(x)
  cleaned <- stringr::str_replace_all(cleaned, "[/|_\\\\]+", " ")
  cleaned <- stringr::str_to_lower(cleaned)
  cleaned <- stringr::str_squish(cleaned)
  cleaned[cleaned %in% c("na", "nan", "no data", "null")] <- NA_character_
  cleaned[cleaned == ""] <- NA_character_

  method <- rep(NA_character_, length(cleaned))
  method[is.na(cleaned)] <- "missing"

  abbreviations <- c(
    "ae" = "aedes",
    "cx" = "culex",
    "oc" = "ochlerotatus",
    "an" = "anopheles"
  )

  for (token in names(abbreviations)) {
    matched <- !is.na(cleaned) &
      stringr::str_detect(cleaned, paste0("^", token, "\\.?\\s+"))
    cleaned[matched] <- stringr::str_replace(
      cleaned[matched],
      paste0("^", token, "\\.?\\s+"),
      paste0(abbreviations[[token]], " ")
    )
    method[matched] <- append_vector_cleanup_method(
      method[matched],
      "rule_expand_genus_abbreviation"
    )
  }

  parenthetical_subgenus <- !is.na(cleaned) &
    stringr::str_detect(cleaned, "^[a-z]+ \\([a-z]+\\)\\s+")
  cleaned[parenthetical_subgenus] <- stringr::str_replace(
    cleaned[parenthetical_subgenus],
    "^([a-z]+) \\([a-z]+\\)\\s+",
    "\\1 "
  )
  method[parenthetical_subgenus] <- append_vector_cleanup_method(
    method[parenthetical_subgenus],
    "rule_drop_parenthetical_subgenus"
  )

  repeated_genus <- !is.na(cleaned) &
    stringr::str_detect(cleaned, "^([a-z]+) \\1\\b")
  cleaned[repeated_genus] <- stringr::str_replace(
    cleaned[repeated_genus],
    "^([a-z]+) \\1\\s+",
    "\\1 "
  )
  method[repeated_genus] <- append_vector_cleanup_method(
    method[repeated_genus],
    "rule_repeated_genus"
  )

  subgenus_token_patterns <- c(
    "^aedes (ochlerotatus|neomelaniconion)\\s+" = "aedes ",
    "^culex (melanoconion|culex)\\s+" = "culex "
  )

  for (pattern in names(subgenus_token_patterns)) {
    matched <- !is.na(cleaned) & stringr::str_detect(cleaned, pattern)
    cleaned[matched] <- stringr::str_replace(
      cleaned[matched],
      pattern,
      subgenus_token_patterns[[pattern]]
    )
    method[matched] <- append_vector_cleanup_method(
      method[matched],
      "rule_drop_subgenus_token"
    )
  }

  authorship_suffix <- !is.na(cleaned) &
    (
      stringr::str_detect(cleaned, "^[a-z]+\\s+[a-z-]+\\s+\\(") |
        stringr::str_detect(cleaned, "^[a-z]+\\s+[a-z-]+\\s+.*\\b[12][0-9]{3}\\b")
    )
  cleaned[authorship_suffix] <- stringr::str_replace(
    cleaned[authorship_suffix],
    "^([a-z]+\\s+[a-z-]+)\\s+.*$",
    "\\1"
  )
  method[authorship_suffix] <- append_vector_cleanup_method(
    method[authorship_suffix],
    "rule_strip_authorship_suffix"
  )

  if (!is.null(manual_map) && nrow(manual_map) > 0) {
    required_cols <- c("source_name", "canonical_name")
    missing_cols <- setdiff(required_cols, names(manual_map))
    if (length(missing_cols) > 0) {
      stop(
        "manual_map is missing required columns: ",
        paste(missing_cols, collapse = ", "),
        call. = FALSE
      )
    }

    manual_lookup <- manual_map[!is.na(normalize_vector_key(manual_map$source_name)), ]
    manual_source <- normalize_vector_key(manual_lookup$source_name)
    manual_canonical <- ascii_transliterate_text(manual_lookup$canonical_name)
    manual_canonical <- stringr::str_to_lower(manual_canonical)
    manual_canonical <- stringr::str_squish(manual_canonical)
    manual_method <- rep("manual_map", length(manual_source))
    if ("cleanup_method" %in% names(manual_map)) {
      manual_method <- dplyr::coalesce(clean_text(manual_lookup$cleanup_method), manual_method)
    }

    matched_idx <- match(normalize_vector_key(cleaned), manual_source)
    has_manual_map <- !is.na(matched_idx) & !is.na(manual_canonical[matched_idx])

    cleaned[has_manual_map] <- manual_canonical[matched_idx[has_manual_map]]
    method[has_manual_map] <- manual_method[matched_idx[has_manual_map]]
  }

  method[is.na(method) & !is.na(cleaned)] <- unchanged_method

  tibble::tibble(
    vector_name_cleaned = format_vector_cleanup_name(cleaned, name_case),
    vector_join_key = normalize_vector_key(cleaned),
    vector_name_cleanup_method = method
  )
}

collapse_unique <- function(x) {
  x <- clean_text(x)
  x <- sort(unique(stats::na.omit(x)))

  if (length(x) == 0) {
    return(NA_character_)
  }

  paste(x, collapse = "; ")
}

first_non_missing <- function(x) {
  x <- clean_text(x)
  x <- x[!is.na(x)]

  if (length(x) == 0) {
    return(NA_character_)
  }

  x[[1]]
}
