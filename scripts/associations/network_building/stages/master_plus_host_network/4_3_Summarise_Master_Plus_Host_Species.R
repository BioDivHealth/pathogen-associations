# ------------------------------------------------------------------------------
# 4_3_Summarise_Master_Plus_Host_Species.R
# ------------------------------------------------------------------------------
# Purpose: Collapse the active master-plus WHO host network to one compact row
#          per unique host species name with higher taxonomy.
#
# Inputs : WHO host-pathogen network helper path for
#          master_plus_who_host_network.csv, plus optional taxonomy reference
#          Species_Taxonomy2025-12-16.csv and VIRION NCBI-resolved host
#          taxonomy fallbacks.
#
# Output: WHO host-pathogen network helper path for
#         master_plus_who_host_species.csv
# ------------------------------------------------------------------------------

library(tidyverse)
library(here)

source(here("scripts", "associations", "working_inputs.R"))
source(here(
  "scripts",
  "associations",
  "network_building",
  "helpers",
  "master_plus_host_network_helpers.R"
))

input_path <- who_network_host_pathogen_path("master_plus_who_host_network.csv")
taxonomy_reference_path <- who_network_host_pathogen_path("Species_Taxonomy2025-12-16.csv")
virion_taxonomy_path <- file.path(virion_source_version_dir, "virion.csv.gz")
pilot_path <- file.path(readiness_dir, "disease_modelling_pilot.csv")
analysis_units_path <- who_master_plus_analysis_units_path()
output_path <- who_network_host_pathogen_path("master_plus_who_host_species.csv")

if (!file.exists(input_path)) {
  stop("Missing required input file: ", input_path)
}

host_network_sentence_case_species <- function(x) {
  x <- stringr::str_to_lower(host_network_clean_text(x))
  has_value <- !is.na(x)
  x[has_value] <- paste0(
    stringr::str_to_upper(stringr::str_sub(x[has_value], 1, 1)),
    stringr::str_sub(x[has_value], 2)
  )
  x
}

host_network_sentence_case_taxon <- function(x) {
  x <- host_network_clean_text(x)
  has_value <- !is.na(x)
  x[has_value] <- stringr::str_to_sentence(stringr::str_to_lower(x[has_value]))
  x
}

host_network_disease_key <- function(x) {
  key <- host_network_clean_text(x)
  key <- stringr::str_to_lower(key)
  key <- stringr::str_replace_all(key, "&", " and ")
  key <- stringr::str_replace_all(key, "[^a-z0-9]+", " ")
  stringr::str_squish(key)
}

host_network_one_unique <- function(x) {
  x <- host_network_clean_text(x)
  x <- sort(unique(stats::na.omit(x)))
  x <- x[x != "" & x != "Not assigned"]

  if (length(x) == 1) {
    x[[1]]
  } else {
    NA_character_
  }
}

host_network_infer_phylum_from_class <- function(x) {
  class_key <- stringr::str_to_lower(host_network_clean_text(x))
  dplyr::case_when(
    class_key %in% c(
      "actinopterygii",
      "amphibia",
      "aves",
      "chondrichthyes",
      "mammalia",
      "reptilia"
    ) ~ "Chordata",
    TRUE ~ NA_character_
  )
}

host_network_extract_reference_names <- function(...) {
  values <- host_network_clean_text(c(...))
  values <- values[!is.na(values)]
  if (length(values) == 0) {
    return(character(0))
  }

  explicit_names <- values %>%
    stringr::str_split(";") %>%
    unlist(use.names = FALSE)

  embedded_binomials <- values %>%
    stringr::str_extract_all("\\b[A-Z][a-z]+\\s+[a-z][a-z.-]+\\b") %>%
    unlist(use.names = FALSE)

  c(explicit_names, embedded_binomials) %>%
    host_network_sentence_case_species() %>%
    stats::na.omit() %>%
    unique()
}

host_network_optional_taxonomy_lookup <- function(path) {
  if (!file.exists(path)) {
    return(tibble(
      host_species = character(),
      reference_phylum = character(),
      reference_class = character(),
      reference_order = character(),
      reference_family = character()
    ))
  }

  read_csv(path, col_types = cols(.default = col_character()), na = c("", "NA")) %>%
    mutate(across(where(is.character), host_network_clean_text)) %>%
    mutate(
      reference_phylum = coalesce(IUCN_Phylum, ITIS_Phylum, GBIF_Phylum),
      reference_class = coalesce(IUCN_Class, ITIS_Class, GBIF_Class),
      reference_order = coalesce(IUCN_Order, ITIS_Order, GBIF_Order),
      reference_family = coalesce(IUCN_Family, ITIS_Family, GBIF_Family),
      reference_names = pmap(
        select(., Or_name, IUCN_name, IUCN_syn, ITIS_name, ITIS_syn, GBIF_name, GBIF_syn),
        host_network_extract_reference_names
      )
    ) %>%
    select(
      reference_names,
      reference_phylum,
      reference_class,
      reference_order,
      reference_family
    ) %>%
    unnest(reference_names) %>%
    transmute(
      host_species = reference_names,
      reference_phylum = host_network_sentence_case_taxon(reference_phylum),
      reference_class = host_network_sentence_case_taxon(reference_class),
      reference_order = host_network_sentence_case_taxon(reference_order),
      reference_family = host_network_sentence_case_taxon(reference_family)
    ) %>%
    filter(!is.na(host_species)) %>%
    group_by(host_species) %>%
    summarise(
      reference_phylum = host_network_collapse_unique(reference_phylum),
      reference_class = host_network_collapse_unique(reference_class),
      reference_order = host_network_collapse_unique(reference_order),
      reference_family = host_network_collapse_unique(reference_family),
      .groups = "drop"
    )
}

host_network_optional_virion_taxonomy_lookup <- function(path) {
  if (!file.exists(path)) {
    return(tibble(
      host_species = character(),
      virion_phylum = character(),
      virion_class = character(),
      virion_order = character(),
      virion_family = character()
    ))
  }

  virion_cols <- c(
    "Host",
    "HostOriginal",
    "HostClass",
    "HostOrder",
    "HostFamily",
    "HostNCBIResolved"
  )

  virion_raw <- if (requireNamespace("data.table", quietly = TRUE)) {
    data.table::fread(
      path,
      select = virion_cols,
      na.strings = c("", "NA"),
      showProgress = FALSE
    ) %>%
      as_tibble()
  } else {
    read_csv(
      path,
      col_types = cols(.default = col_character()),
      col_select = any_of(virion_cols),
      na = c("", "NA"),
      show_col_types = FALSE
    )
  }

  virion_raw %>%
    mutate(across(where(is.character), host_network_clean_text)) %>%
    filter(host_network_is_true(HostNCBIResolved)) %>%
    distinct(Host, HostOriginal, HostClass, HostOrder, HostFamily) %>%
    mutate(
      virion_class = host_network_sentence_case_taxon(HostClass),
      virion_order = host_network_sentence_case_taxon(HostOrder),
      virion_family = host_network_sentence_case_taxon(HostFamily),
      virion_phylum = host_network_infer_phylum_from_class(virion_class)
    ) %>%
    select(
      Host,
      HostOriginal,
      virion_phylum,
      virion_class,
      virion_order,
      virion_family
    ) %>%
    pivot_longer(
      cols = c(Host, HostOriginal),
      names_to = "virion_name_source",
      values_to = "host_species"
    ) %>%
    transmute(
      host_species = host_network_sentence_case_species(host_species),
      virion_phylum,
      virion_class,
      virion_order,
      virion_family
    ) %>%
    filter(
      !is.na(host_species),
      stringr::str_detect(host_species, "^[A-Z][a-z]+\\s+[a-z][a-z.-]+")
    ) %>%
    distinct() %>%
    group_by(host_species) %>%
    summarise(
      virion_phylum = host_network_one_unique(virion_phylum),
      virion_class = host_network_one_unique(virion_class),
      virion_order = host_network_one_unique(virion_order),
      virion_family = host_network_one_unique(virion_family),
      .groups = "drop"
    )
}

host_network_optional_analysis_unit_aliases <- function(path, analysis_unit_ids) {
  if (!file.exists(path) || length(analysis_unit_ids) == 0) {
    return(tibble(analysis_unit_id = character(), alias = character()))
  }

  alias_columns <- c(
    "source_disease_name",
    "disease_master_name",
    "analysis_unit_label",
    "analysis_unit"
  )

  read_csv(path, col_types = cols(.default = col_character()), na = c("", "NA")) %>%
    mutate(across(where(is.character), host_network_clean_text)) %>%
    filter(analysis_unit_id %in% analysis_unit_ids) %>%
    select(analysis_unit_id, any_of(alias_columns)) %>%
    pivot_longer(
      cols = any_of(alias_columns),
      names_to = "alias_source",
      values_to = "alias"
    ) %>%
    filter(!is.na(alias)) %>%
    distinct(analysis_unit_id, alias)
}

host_network_optional_pilot_lookups <- function(path, analysis_units_path) {
  empty <- list(
    by_analysis_unit = tibble(
      analysis_unit_id = character(),
      pilot_disease = character(),
      pilot_modelling_scope_status = character()
    ),
    by_alias = tibble(
      alias_key = character(),
      pilot_disease = character(),
      pilot_modelling_scope_status = character()
    )
  )

  if (!file.exists(path)) {
    return(empty)
  }

  pilot <- read_csv(path, col_types = cols(.default = col_character()), na = c("", "NA")) %>%
    mutate(across(where(is.character), host_network_clean_text))

  by_analysis_unit <- pilot %>%
    transmute(
      analysis_unit_id,
      pilot_disease = readiness_disease_name,
      pilot_modelling_scope_status = modelling_scope_status
    ) %>%
    filter(!is.na(analysis_unit_id)) %>%
    distinct()

  pilot_aliases <- pilot %>%
    select(analysis_unit_id, readiness_disease_name, analysis_unit_label) %>%
    pivot_longer(
      cols = c(readiness_disease_name, analysis_unit_label),
      names_to = "alias_source",
      values_to = "alias"
    ) %>%
    filter(!is.na(alias)) %>%
    distinct(analysis_unit_id, alias)

  analysis_unit_aliases <- host_network_optional_analysis_unit_aliases(
    analysis_units_path,
    unique(stats::na.omit(pilot$analysis_unit_id))
  )

  by_alias <- bind_rows(pilot_aliases, analysis_unit_aliases) %>%
    left_join(by_analysis_unit, by = "analysis_unit_id") %>%
    transmute(
      alias_key = host_network_disease_key(alias),
      pilot_disease,
      pilot_modelling_scope_status
    ) %>%
    filter(!is.na(alias_key), alias_key != "", !is.na(pilot_disease)) %>%
    distinct()

  list(by_analysis_unit = by_analysis_unit, by_alias = by_alias)
}

network <- read_csv(
  input_path,
  col_types = cols(.default = col_character()),
  na = c("", "NA")
) %>%
  mutate(across(where(is.character), host_network_clean_text))

species_rows <- network %>%
  mutate(
    host_species = host_network_sentence_case_species(Host),
    host_phylum = host_network_sentence_case_taxon(HostPhylum),
    host_class = host_network_sentence_case_taxon(HostClass),
    host_order = host_network_sentence_case_taxon(HostOrder),
    host_family = host_network_sentence_case_taxon(HostFamily),
    host_taxonomy_flag = host_network_clean_text(host_taxonomy_flag)
  ) %>%
  filter(!is.na(host_species), host_taxonomy_flag == "species_like")

taxonomy_reference <- host_network_optional_taxonomy_lookup(taxonomy_reference_path)
virion_taxonomy <- host_network_optional_virion_taxonomy_lookup(virion_taxonomy_path)
pilot_lookups <- host_network_optional_pilot_lookups(pilot_path, analysis_units_path)

taxonomy_direct <- species_rows %>%
  group_by(host_species) %>%
  summarise(
    host_phylum = host_network_collapse_unique(host_phylum),
    host_class = host_network_collapse_unique(host_class),
    host_order = host_network_collapse_unique(host_order),
    host_family = host_network_collapse_unique(host_family),
    .groups = "drop"
  ) %>%
  left_join(taxonomy_reference, by = "host_species") %>%
  left_join(virion_taxonomy, by = "host_species") %>%
  mutate(
    host_phylum = coalesce(host_phylum, reference_phylum, virion_phylum),
    host_class = coalesce(host_class, reference_class, virion_class),
    host_order = coalesce(host_order, reference_order, virion_order),
    host_family = coalesce(host_family, reference_family, virion_family),
    host_genus = stringr::word(host_species, 1)
  ) %>%
  select(host_species, host_genus, host_phylum, host_class, host_order, host_family)

genus_lookup <- taxonomy_direct %>%
  group_by(host_genus) %>%
  summarise(
    genus_phylum = host_network_one_unique(host_phylum),
    genus_class = host_network_one_unique(host_class),
    genus_order = host_network_one_unique(host_order),
    genus_family = host_network_one_unique(host_family),
    .groups = "drop"
  )

family_lookup <- taxonomy_direct %>%
  filter(!is.na(host_family), host_family != "Not assigned") %>%
  group_by(host_family) %>%
  summarise(
    family_phylum = host_network_one_unique(host_phylum),
    family_class = host_network_one_unique(host_class),
    family_order = host_network_one_unique(host_order),
    .groups = "drop"
  )

order_lookup <- taxonomy_direct %>%
  filter(!is.na(host_order), host_order != "Not assigned") %>%
  group_by(host_order) %>%
  summarise(
    order_phylum = host_network_one_unique(host_phylum),
    order_class = host_network_one_unique(host_class),
    .groups = "drop"
  )

class_lookup <- taxonomy_direct %>%
  filter(!is.na(host_class), host_class != "Not assigned") %>%
  group_by(host_class) %>%
  summarise(
    class_phylum = host_network_one_unique(host_phylum),
    .groups = "drop"
  )

taxonomy_enriched <- taxonomy_direct %>%
  left_join(genus_lookup, by = "host_genus") %>%
  mutate(
    host_phylum = coalesce(host_phylum, genus_phylum),
    host_class = coalesce(host_class, genus_class),
    host_order = coalesce(host_order, genus_order),
    host_family = coalesce(host_family, genus_family)
  ) %>%
  select(-starts_with("genus_")) %>%
  left_join(family_lookup, by = "host_family") %>%
  mutate(
    host_phylum = coalesce(host_phylum, family_phylum),
    host_class = coalesce(host_class, family_class),
    host_order = coalesce(host_order, family_order)
  ) %>%
  select(-starts_with("family_")) %>%
  left_join(order_lookup, by = "host_order") %>%
  mutate(
    host_phylum = coalesce(host_phylum, order_phylum),
    host_class = coalesce(host_class, order_class)
  ) %>%
  select(-starts_with("order_")) %>%
  left_join(class_lookup, by = "host_class") %>%
  mutate(host_phylum = coalesce(host_phylum, class_phylum)) %>%
  select(-host_genus, -starts_with("class_"))

gonzalo_species <- taxonomy_reference %>%
  distinct(host_species) %>%
  mutate(host_in_gonzalos_list = TRUE)

disease_detection_summary <- species_rows %>%
  group_by(host_species) %>%
  summarise(
    diseases = host_network_collapse_unique(Disease_name),
    Not_specified = sum(DetectionMethod == "Not specified", na.rm = TRUE),
    PCR_Sequencing = sum(DetectionMethod == "PCR/Sequencing", na.rm = TRUE),
    Isolation_Observation = sum(DetectionMethod == "Isolation/Observation", na.rm = TRUE),
    Antibodies = sum(DetectionMethod == "Antibodies", na.rm = TRUE),
    Any_PCR_Or_Observation = sum(
      DetectionMethod %in% c("PCR/Sequencing", "Isolation/Observation"),
      na.rm = TRUE
    ),
    .groups = "drop"
  )

species_disease_keys <- species_rows %>%
  distinct(host_species, Disease_name, disease_master_name, analysis_unit_id) %>%
  mutate(
    disease_key = host_network_disease_key(Disease_name),
    disease_master_key = host_network_disease_key(disease_master_name)
  )

pilot_matches_by_id <- species_disease_keys %>%
  filter(!is.na(analysis_unit_id)) %>%
  inner_join(pilot_lookups$by_analysis_unit, by = "analysis_unit_id")

pilot_matches_by_disease <- species_disease_keys %>%
  filter(!is.na(disease_key), disease_key != "") %>%
  inner_join(pilot_lookups$by_alias, by = c("disease_key" = "alias_key"))

pilot_matches_by_master_disease <- species_disease_keys %>%
  filter(!is.na(disease_master_key), disease_master_key != "") %>%
  inner_join(pilot_lookups$by_alias, by = c("disease_master_key" = "alias_key"))

pilot_summary <- bind_rows(
  pilot_matches_by_id,
  pilot_matches_by_disease,
  pilot_matches_by_master_disease
) %>%
  distinct(host_species, pilot_disease, pilot_modelling_scope_status) %>%
  group_by(host_species) %>%
  summarise(
    has_pilot_disease = TRUE,
    pilot_diseases = host_network_collapse_unique(pilot_disease),
    has_pilot_include_disease = any(pilot_modelling_scope_status == "include"),
    pilot_include_diseases = host_network_collapse_unique(
      pilot_disease[pilot_modelling_scope_status == "include"]
    ),
    .groups = "drop"
  )

host_species <- taxonomy_enriched %>%
  left_join(gonzalo_species, by = "host_species") %>%
  left_join(disease_detection_summary, by = "host_species") %>%
  left_join(pilot_summary, by = "host_species") %>%
  mutate(
    host_in_gonzalos_list = coalesce(host_in_gonzalos_list, FALSE),
    has_pilot_disease = coalesce(has_pilot_disease, FALSE),
    has_pilot_include_disease = coalesce(has_pilot_include_disease, FALSE)
  ) %>%
  select(
    host_species,
    host_phylum,
    host_class,
    host_order,
    host_family,
    host_in_gonzalos_list,
    diseases,
    has_pilot_disease,
    pilot_diseases,
    has_pilot_include_disease,
    pilot_include_diseases,
    Not_specified,
    PCR_Sequencing,
    Isolation_Observation,
    Antibodies,
    Any_PCR_Or_Observation
  ) %>%
  arrange(host_species)

stopifnot(nrow(host_species) == nrow(distinct(host_species, host_species)))

dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
write_csv(host_species, output_path, na = "")

cat("Network rows:", nrow(network), "\n")
cat("Unique host species names:", nrow(host_species), "\n")
cat("Host species with phylum:", sum(!is.na(host_species$host_phylum)), "\n")
cat("Host species with class:", sum(!is.na(host_species$host_class)), "\n")
cat("Host species with order:", sum(!is.na(host_species$host_order)), "\n")
cat("Host species with family:", sum(!is.na(host_species$host_family)), "\n")
cat("Host species with pilot disease:", sum(host_species$has_pilot_disease), "\n")
cat(
  "Host species with pilot include disease:",
  sum(host_species$has_pilot_include_disease),
  "\n"
)
cat("Wrote:", output_path, "\n")
