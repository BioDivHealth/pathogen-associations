# ------------------------------------------------------------------------------
# validate_vector_key_cleanup_contract.R
# ------------------------------------------------------------------------------
# Purpose: Fixture checks for the shared vector key/name cleanup contract.
#          This script is read-only: it validates helper behavior and reports
#          where current stage-local cleanup functions differ from the contract.
# ------------------------------------------------------------------------------

library(pacman)
p_load(dplyr, here, stringr, tibble)

source(here("scripts", "associations", "association_text_helpers.R"))

assert_identical_columns <- function(actual, expected, label) {
  actual <- actual[, names(expected)]

  if (!identical(actual, expected)) {
    comparison <- bind_cols(
      expected %>% rename_with(~ paste0("expected_", .x)),
      actual %>% rename_with(~ paste0("actual_", .x))
    )

    print(comparison, n = Inf, width = Inf)
    stop(label, " did not match expected fixture output", call. = FALSE)
  }
}

fixtures <- tibble(
  input = c(
    "Aedes (Ochlerotatus) vexans",
    "Aedes ochlerotatus vexans",
    "Culex (Culex) pipiens",
    "Culex melanoconion spissipes",
    "Culex culex pipiens",
    "Ae. albopictus",
    "Cx annulirostris",
    "Aedes aegypti (Linnaeus, 1762)",
    "Haemagogus spegazzinni",
    "Culicidae/unknown",
    "Aëdes aegypti"
  ),
  expected_input_key = c(
    "aedes ochlerotatus vexans",
    "aedes ochlerotatus vexans",
    "culex culex pipiens",
    "culex melanoconion spissipes",
    "culex culex pipiens",
    "ae albopictus",
    "cx annulirostris",
    "aedes aegypti linnaeus 1762",
    "haemagogus spegazzinni",
    "culicidae unknown",
    "aedes aegypti"
  ),
  expected_vector_name_cleaned = c(
    "aedes vexans",
    "aedes vexans",
    "culex pipiens",
    "culex spissipes",
    "culex pipiens",
    "aedes albopictus",
    "culex annulirostris",
    "aedes aegypti",
    "haemagogus spegazzinii",
    "culicidae unknown",
    "aedes aegypti"
  ),
  expected_vector_join_key = c(
    "aedes vexans",
    "aedes vexans",
    "culex pipiens",
    "culex spissipes",
    "culex pipiens",
    "aedes albopictus",
    "culex annulirostris",
    "aedes aegypti",
    "haemagogus spegazzinii",
    "culicidae unknown",
    "aedes aegypti"
  ),
  expected_vector_name_cleanup_method = c(
    "rule_drop_parenthetical_subgenus",
    "rule_drop_subgenus_token",
    "rule_drop_parenthetical_subgenus",
    "rule_drop_subgenus_token",
    "rule_repeated_genus",
    "rule_expand_genus_abbreviation",
    "rule_expand_genus_abbreviation",
    "rule_strip_authorship_suffix",
    "manual_map",
    "normalized_name",
    "normalized_name"
  )
)

sentence_expected <- fixtures %>%
  transmute(
    input,
    input_key = expected_input_key,
    vector_name_cleaned = c(
      "Aedes vexans",
      "Aedes vexans",
      "Culex pipiens",
      "Culex spissipes",
      "Culex pipiens",
      "Aedes albopictus",
      "Culex annulirostris",
      "Aedes aegypti",
      "Haemagogus spegazzinii",
      "Culicidae unknown",
      "Aedes aegypti"
    ),
    vector_join_key = expected_vector_join_key,
    vector_name_cleanup_method = c(
      "rule_drop_parenthetical_subgenus",
      "rule_drop_subgenus_token",
      "rule_drop_parenthetical_subgenus",
      "rule_drop_subgenus_token",
      "rule_repeated_genus",
      "rule_expand_genus_abbreviation",
      "rule_expand_genus_abbreviation",
      "rule_strip_authorship_suffix",
      "manual_map",
      "no_change",
      "no_change"
    )
  )

manual_map <- tibble(
  source_name = "haemagogus spegazzinni",
  canonical_name = "haemagogus spegazzinii",
  cleanup_method = "manual_map"
)

actual <- bind_cols(
  fixtures %>% transmute(input, input_key = normalize_vector_key(input)),
  apply_vector_name_cleanup(fixtures$input, manual_map)
)

expected <- fixtures %>%
  transmute(
    input,
    input_key = expected_input_key,
    vector_name_cleaned = expected_vector_name_cleaned,
    vector_join_key = expected_vector_join_key,
    vector_name_cleanup_method = expected_vector_name_cleanup_method
  )

assert_identical_columns(actual, expected, "Canonical vector cleanup contract")

sentence_actual <- bind_cols(
  fixtures %>% transmute(input, input_key = normalize_vector_key(input)),
  apply_vector_name_cleanup(
    fixtures$input,
    manual_map,
    unchanged_method = "no_change",
    name_case = "sentence"
  )
)

cat("Canonical vector cleanup fixture rows:", nrow(fixtures), "\n")
assert_identical_columns(
  sentence_actual,
  sentence_expected,
  "Canonical VectorMap-style vector cleanup contract"
)
cat("Canonical VectorMap-style fixture rows:", nrow(fixtures), "\n")
