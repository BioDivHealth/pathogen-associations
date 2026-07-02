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

load_function_definitions <- function(path, function_names, env = new.env(parent = globalenv())) {
  expressions <- parse(path)

  for (expr in expressions) {
    if (
      is.call(expr) &&
        identical(expr[[1]], as.name("<-")) &&
        as.character(expr[[2]]) %in% function_names
    ) {
      eval(expr, envir = env)
    }
  }

  env
}

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

env_56c <- new.env(parent = globalenv())
env_56c$clean_text <- clean_text
env_56c <- load_function_definitions(
  here("scripts", "associations", "vector_screening", "5_6c_Join_Vector_Competence_Evidence.R"),
  c("normalize_vector_key", "apply_vector_name_cleanup"),
  env_56c
)

env_59 <- load_function_definitions(
  here("scripts", "associations", "host_vector_sources", "5_9_VectorMap_Vector_Name_Cleanup.R"),
  c("clean_text", "normalize_vector_key", "append_method", "apply_rule_cleanup")
)

current_56c <- env_56c$apply_vector_name_cleanup(fixtures$input, manual_map) %>%
  transmute(
    input = fixtures$input,
    current_56c_join_key = vector_join_key,
    current_56c_method = vector_competence_name_cleanup_method
  )

current_59 <- env_59$apply_rule_cleanup(fixtures$input) %>%
  mutate(current_59_join_key = env_59$normalize_vector_key(vector_name_rule_cleaned)) %>%
  transmute(
    input = fixtures$input,
    current_59_name = vector_name_rule_cleaned,
    current_59_join_key,
    current_59_method = vector_cleanup_method
  )

comparison <- actual %>%
  select(
    input,
    canonical_name = vector_name_cleaned,
    canonical_join_key = vector_join_key,
    canonical_method = vector_name_cleanup_method
  ) %>%
  left_join(current_56c, by = "input") %>%
  left_join(current_59, by = "input") %>%
  mutate(
    differs_from_56c = canonical_join_key != current_56c_join_key |
      canonical_method != current_56c_method,
    differs_from_59 = canonical_join_key != current_59_join_key |
      canonical_method != current_59_method
  ) %>%
  filter(differs_from_56c | differs_from_59)

cat("Canonical vector cleanup fixture rows:", nrow(fixtures), "\n")
cat("Fixture rows differing from current stage-local behavior:", nrow(comparison), "\n")

if (nrow(comparison) > 0) {
  print(comparison, n = Inf, width = Inf)
}
