#!/usr/bin/env Rscript
################################################################################
# 05_prepare_global_ready_sdm_delivery_bundle.R
################################################################################
# Purpose: Copy the refreshed modelling-readiness package beside the consolidated
#          ready SDMs and build lightweight lookup tables for disease/species
#          selection and raster loading.
#
# Output : /Volumes/LaCie/new_global_maxent/sdms/consolidated_ready_sdms_20260630/
#            readiness/
#              disease_modelling_*.csv
#              disease_modelling_pilot_package/
#              evidence_tiers/
#              sdm_catalog/
#              interface_inputs/
################################################################################

suppressPackageStartupMessages({
  if (!requireNamespace("here", quietly = TRUE)) {
    stop("Package `here` is required.", call. = FALSE)
  }
  if (!requireNamespace("pacman", quietly = TRUE)) {
    stop("Package `pacman` is required.", call. = FALSE)
  }
})

pacman::p_load(dplyr, readr, stringr, tibble)

# ------------------------------------------------------------------------------
#      Configuration ------------------------------------------------------------
# ------------------------------------------------------------------------------
repo_root <- normalizePath(here::here(), winslash = "/", mustWork = TRUE)
bundle_root <- Sys.getenv(
  "READY_SDM_BUNDLE_ROOT",
  unset = "/Volumes/LaCie/new_global_maxent/sdms/consolidated_ready_sdms_20260630"
)
bundle_root <- normalizePath(bundle_root, winslash = "/", mustWork = TRUE)

readiness_source_dir <- file.path(repo_root, "pathogen_association_data", "readiness")
readiness_target_dir <- file.path(bundle_root, "readiness")
catalog_target_dir <- file.path(readiness_target_dir, "sdm_catalog")
interface_target_dir <- file.path(readiness_target_dir, "interface_inputs")

paths <- list(
  consolidated_manifest = file.path(
    bundle_root,
    "manifests",
    "consolidated_ready_sdms_manifest.csv"
  ),
  accessible_sdm_species = file.path(
    repo_root,
    "sdms",
    "outputs",
    "catalog",
    "accessible_sdm_species.csv"
  ),
  readiness_full = file.path(readiness_source_dir, "disease_modelling_readiness_full.csv"),
  readiness_slim = file.path(readiness_source_dir, "disease_modelling_readiness.csv"),
  species_roster = file.path(
    repo_root,
    "pathogen_association_data",
    "evidence",
    "role_annotation",
    "species_host_vector_roster.csv"
  ),
  role_features = file.path(
    repo_root,
    "pathogen_association_data",
    "evidence",
    "role_annotation",
    "role_modelling_features.csv"
  ),
  vector_features = file.path(
    repo_root,
    "pathogen_association_data",
    "evidence",
    "role_annotation",
    "vector_modelling_features.csv"
  ),
  pilot_role_ready = file.path(
    readiness_source_dir,
    "disease_modelling_pilot_package",
    "pilot_sdm_species_role_ready.csv"
  )
)

required_paths <- unlist(paths, use.names = TRUE)
missing_paths <- required_paths[!file.exists(required_paths)]
if (length(missing_paths) > 0) {
  stop(
    "Required inputs are missing: ",
    paste(names(missing_paths), missing_paths, sep = "=", collapse = "; "),
    call. = FALSE
  )
}

dir.create(readiness_target_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(catalog_target_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(interface_target_dir, recursive = TRUE, showWarnings = FALSE)

# ------------------------------------------------------------------------------
#      Helpers ------------------------------------------------------------------
# ------------------------------------------------------------------------------
clean_key <- function(x) {
  x <- tolower(trimws(as.character(x)))
  stringr::str_squish(gsub("[^a-z0-9]+", " ", x))
}

tax_key <- function(x) {
  x <- trimws(as.character(x))
  x[is.na(x)] <- ""
  x
}

escape_regex <- function(x) {
  gsub("([][{}()+*^$|\\\\?.])", "\\\\\\1", x)
}

relative_to_bundle <- function(path) {
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  sub(paste0("^", escape_regex(bundle_root), "/?"), "", path)
}

is_auxiliary_file <- function(path) {
  name <- basename(path)
  name %in% c(".DS_Store") | startsWith(name, "._")
}

copy_one_file <- function(source_path, target_path) {
  dir.create(dirname(target_path), recursive = TRUE, showWarnings = FALSE)
  ok <- file.copy(source_path, target_path, overwrite = TRUE, copy.mode = FALSE)
  if (!ok) {
    stop("Failed to copy ", source_path, " to ", target_path, call. = FALSE)
  }
  target_path
}

copy_dir_contents <- function(source_dir, target_dir) {
  files <- list.files(
    source_dir,
    recursive = TRUE,
    full.names = TRUE,
    all.files = TRUE,
    no.. = TRUE
  )
  files <- files[file.info(files)$isdir %in% FALSE]
  files <- files[!is_auxiliary_file(files)]
  relative <- sub(paste0("^", escape_regex(normalizePath(source_dir, winslash = "/", mustWork = TRUE)), "/?"), "", files)
  targets <- file.path(target_dir, relative)
  invisible(Map(copy_one_file, files, targets))
  tibble(source_path = files, target_path = targets)
}

read_csv_chr <- function(path) {
  readr::read_csv(
    path,
    col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE
  )
}

first_existing <- function(data, cols) {
  cols <- intersect(cols, names(data))
  if (length(cols) == 0) {
    return(rep(NA_character_, nrow(data)))
  }

  out <- rep(NA_character_, nrow(data))
  for (col in cols) {
    val <- as.character(data[[col]])
    val[!nzchar(val)] <- NA_character_
    out <- dplyr::coalesce(out, val)
  }
  out
}

# ------------------------------------------------------------------------------
#      Copy Readiness Package ---------------------------------------------------
# ------------------------------------------------------------------------------
top_level_files <- list.files(readiness_source_dir, full.names = TRUE, all.files = TRUE, no.. = TRUE)
top_level_files <- top_level_files[file.info(top_level_files)$isdir %in% FALSE]
top_level_files <- top_level_files[!is_auxiliary_file(top_level_files)]

copied_top_level <- tibble(
  source_path = top_level_files,
  target_path = file.path(readiness_target_dir, basename(top_level_files))
)
invisible(Map(copy_one_file, copied_top_level$source_path, copied_top_level$target_path))

copied_package <- copy_dir_contents(
  file.path(readiness_source_dir, "disease_modelling_pilot_package"),
  file.path(readiness_target_dir, "disease_modelling_pilot_package")
)
copied_tiers <- copy_dir_contents(
  file.path(readiness_source_dir, "evidence_tiers"),
  file.path(readiness_target_dir, "evidence_tiers")
)

# ------------------------------------------------------------------------------
#      SDM Catalog Copies -------------------------------------------------------
# ------------------------------------------------------------------------------
consolidated_manifest <- read_csv_chr(paths$consolidated_manifest)
accessible_sdm_species <- read_csv_chr(paths$accessible_sdm_species)

required_manifest_cols <- c(
  "role",
  "species",
  "species_safe",
  "source_label",
  "prediction_status",
  "dest_model_path",
  "dest_ensemble_mean_path",
  "dest_ensemble_tss_clipped_path",
  "dest_prediction_summary_path"
)
missing_manifest_cols <- setdiff(required_manifest_cols, names(consolidated_manifest))
if (length(missing_manifest_cols) > 0) {
  stop(
    "Consolidated manifest is missing columns: ",
    paste(missing_manifest_cols, collapse = ", "),
    call. = FALSE
  )
}

sdm_paths <- consolidated_manifest %>%
  transmute(
    species_role = role,
    species_name = species,
    species_key = clean_key(species),
    species_role_key = clean_key(role),
    species_safe,
    sdm_source_label = source_label,
    sdm_prediction_status = prediction_status,
    sdm_species_dir = dirname(relative_to_bundle(dest_model_path)),
    sdm_model_rds = relative_to_bundle(dest_model_path),
    sdm_ensemble_mean_tif = relative_to_bundle(dest_ensemble_mean_path),
    sdm_ensemble_tss_clipped_tif = relative_to_bundle(dest_ensemble_tss_clipped_path),
    sdm_prediction_summary = relative_to_bundle(dest_prediction_summary_path),
    sdm_available = file.exists(dest_model_path) &
      file.exists(dest_ensemble_mean_path) &
      file.exists(dest_ensemble_tss_clipped_path) &
      file.exists(dest_prediction_summary_path)
  ) %>%
  arrange(species_role, species_name)

readr::write_csv(
  accessible_sdm_species,
  file.path(catalog_target_dir, "accessible_sdm_species.csv"),
  na = ""
)
readr::write_csv(
  consolidated_manifest,
  file.path(catalog_target_dir, "consolidated_sdm_manifest.csv"),
  na = ""
)
readr::write_csv(
  sdm_paths,
  file.path(catalog_target_dir, "available_species_sdm_paths.csv"),
  na = ""
)

# ------------------------------------------------------------------------------
#      Disease/Species Interface Tables ----------------------------------------
# ------------------------------------------------------------------------------
readiness_full <- read_csv_chr(paths$readiness_full)
readiness_slim <- read_csv_chr(paths$readiness_slim)
roster <- read_csv_chr(paths$species_roster)
role_features <- read_csv_chr(paths$role_features)
vector_features <- read_csv_chr(paths$vector_features)
pilot_role_ready <- read_csv_chr(paths$pilot_role_ready)

disease_context <- readiness_full %>%
  transmute(
    disease_key = clean_key(readiness_disease_name),
    analysis_unit_id,
    readiness_disease_name,
    pathogen_species_name,
    pathogen_taxid,
    family,
    in_master_who,
    priority_prototype_status,
    master_tier,
    modelling_scope_status,
    recommended_next_action,
    readiness_blocker,
    vectored_status,
    guild,
    host_sdm_needed,
    vector_sdm_needed,
    sdm_availability_status,
    host_sdm_species_available,
    vector_sdm_species_available
  ) %>%
  distinct(disease_key, .keep_all = TRUE)

host_feature_lookup <- role_features %>%
  transmute(
    disease_key = clean_key(disease_name),
    species_key = clean_key(species_name),
    tax_id_key = tax_key(tax_id),
    species_role_key = "host",
    taxonomy_ok,
    biological_evidence_tier,
    profile_broad,
    profile_supported,
    profile_strong,
    profile_strict,
    host_role_bucket,
    host_role_evidence_basis,
    host_role_weight,
    modelling_role_proxy,
    modelling_role_proxy_basis,
    modelling_role_proxy_confidence,
    role_evidence_missingness_reason = host_evidence_missingness_reason
  )

vector_feature_lookup <- vector_features %>%
  transmute(
    disease_key = clean_key(disease_name),
    species_key = clean_key(species_name),
    tax_id_key = tax_key(tax_id),
    species_role_key = "vector",
    taxonomy_ok,
    biological_evidence_tier,
    profile_broad,
    profile_supported,
    profile_strong,
    profile_strict,
    vector_role_bucket,
    vector_role_bucket_basis,
    vector_role_bucket_needs_review,
    bites_humans_known,
    bites_humans_true,
    role_evidence_missingness_reason = vector_evidence_missingness_reason
  )

feature_lookup <- bind_rows(host_feature_lookup, vector_feature_lookup) %>%
  distinct(disease_key, species_key, tax_id_key, species_role_key, .keep_all = TRUE)

all_disease_species_sdm_lookup <- roster %>%
  mutate(
    disease_key = clean_key(disease_name),
    species_key = clean_key(species_name),
    tax_id_key = tax_key(tax_id),
    species_role_key = clean_key(species_role)
  ) %>%
  left_join(disease_context, by = "disease_key") %>%
  left_join(
    feature_lookup,
    by = c("disease_key", "species_key", "tax_id_key", "species_role_key")
  ) %>%
  left_join(
    sdm_paths %>%
      select(
        species_key,
        species_role_key,
        sdm_source_label,
        sdm_prediction_status,
        sdm_species_dir,
        sdm_model_rds,
        sdm_ensemble_mean_tif,
        sdm_ensemble_tss_clipped_tif,
        sdm_prediction_summary,
        sdm_available
      ),
    by = c("species_key", "species_role_key")
  ) %>%
  mutate(
    sdm_available = dplyr::coalesce(sdm_available, FALSE),
    map_layer_default = sdm_ensemble_mean_tif,
    map_layer_thresholded = sdm_ensemble_tss_clipped_tif
  ) %>%
  select(
    analysis_unit_id,
    readiness_disease_name,
    disease_name,
    pathogen_species_name,
    pathogen_taxid,
    family,
    modelling_scope_status,
    recommended_next_action,
    readiness_blocker,
    vectored_status,
    guild,
    host_sdm_needed,
    vector_sdm_needed,
    sdm_availability_status,
    host_sdm_species_available,
    vector_sdm_species_available,
    species_role,
    species_name,
    tax_id,
    disease_has_vector_rows,
    in_current_role_review_scope,
    in_gibb_etal,
    in_empres_i,
    taxonomy_ok,
    biological_evidence_tier,
    profile_broad,
    profile_supported,
    profile_strong,
    profile_strict,
    host_role_assignment,
    host_role_confidence,
    host_role_needs_manual_review,
    host_role_assignment_status,
    host_role_bucket,
    host_role_evidence_basis,
    host_role_weight,
    modelling_role_proxy,
    modelling_role_proxy_basis,
    modelling_role_proxy_confidence,
    vector_group,
    vector_taxon_rank,
    vector_role_assignment,
    vector_role_confidence,
    vector_role_needs_manual_review,
    vector_role_assignment_status,
    vector_role_bucket,
    vector_role_bucket_basis,
    vector_role_bucket_needs_review,
    bites_humans,
    bites_humans_known,
    bites_humans_true,
    vector_competence_status,
    transmission_demonstrated,
    natural_infection_reported,
    role_evidence_missingness_reason,
    sdm_available,
    sdm_source_label,
    sdm_prediction_status,
    sdm_species_dir,
    sdm_model_rds,
    sdm_ensemble_mean_tif,
    sdm_ensemble_tss_clipped_tif,
    sdm_prediction_summary,
    map_layer_default,
    map_layer_thresholded
  ) %>%
  arrange(readiness_disease_name, disease_name, species_role, species_name)

pilot_disease_species_sdm_lookup <- pilot_role_ready %>%
  mutate(
    species_key = clean_key(species_name),
    species_role_key = clean_key(species_role)
  ) %>%
  left_join(
    sdm_paths %>%
      select(
        species_key,
        species_role_key,
        sdm_source_label,
        sdm_prediction_status,
        sdm_species_dir,
        sdm_model_rds,
        sdm_ensemble_mean_tif,
        sdm_ensemble_tss_clipped_tif,
        sdm_prediction_summary
      ),
    by = c("species_key", "species_role_key")
  ) %>%
  mutate(
    map_layer_default = sdm_ensemble_mean_tif,
    map_layer_thresholded = sdm_ensemble_tss_clipped_tif
  ) %>%
  select(-species_key, -species_role_key)

disease_summary <- readiness_slim %>%
  arrange(readiness_disease_name) %>%
  select(
    analysis_unit_id,
    readiness_disease_name,
    pathogen_species_name,
    pathogen_taxid,
    family,
    in_master_who,
    priority_prototype_status,
    master_tier,
    modelling_scope_status,
    recommended_next_action,
    readiness_blocker,
    vectored_status,
    guild,
    host_sdm_needed,
    vector_sdm_needed,
    direct_vector_evidence_status,
    country_evidence_status,
    sdm_availability_status,
    role_assignment_status,
    host_sdm_species_available,
    vector_sdm_species_available
  )

readr::write_csv(
  all_disease_species_sdm_lookup,
  file.path(interface_target_dir, "all_disease_species_sdm_lookup.csv"),
  na = ""
)
readr::write_csv(
  pilot_disease_species_sdm_lookup,
  file.path(interface_target_dir, "pilot_disease_species_sdm_lookup.csv"),
  na = ""
)
readr::write_csv(
  disease_summary,
  file.path(interface_target_dir, "disease_summary.csv"),
  na = ""
)

# ------------------------------------------------------------------------------
#      Bundle Manifest and README ----------------------------------------------
# ------------------------------------------------------------------------------
copied_files <- bind_rows(
  copied_top_level,
  copied_package,
  copied_tiers
) %>%
  mutate(
    relative_path = sub(
      paste0("^", escape_regex(readiness_target_dir), "/?"),
      "",
      normalizePath(target_path, winslash = "/", mustWork = FALSE)
    ),
    size_bytes = file.info(target_path)$size
  ) %>%
  select(relative_path, size_bytes, source_path)

generated_outputs <- tibble(
  relative_path = c(
    "sdm_catalog/accessible_sdm_species.csv",
    "sdm_catalog/consolidated_sdm_manifest.csv",
    "sdm_catalog/available_species_sdm_paths.csv",
    "interface_inputs/all_disease_species_sdm_lookup.csv",
    "interface_inputs/pilot_disease_species_sdm_lookup.csv",
    "interface_inputs/disease_summary.csv"
  )
) %>%
  mutate(
    size_bytes = file.info(file.path(readiness_target_dir, relative_path))$size,
    source_path = "generated by 05_prepare_global_ready_sdm_delivery_bundle.R"
  )

bundle_manifest <- bind_rows(copied_files, generated_outputs) %>%
  arrange(relative_path)
readr::write_csv(bundle_manifest, file.path(readiness_target_dir, "bundle_manifest.csv"), na = "")

summary <- tibble(
  generated_at_utc = format(Sys.time(), "%Y-%m-%d %H:%M:%S UTC", tz = "UTC"),
  bundle_root = bundle_root,
  readiness_target_dir = readiness_target_dir,
  consolidated_manifest_rows = nrow(consolidated_manifest),
  available_species_rows = nrow(sdm_paths),
  all_disease_species_rows = nrow(all_disease_species_sdm_lookup),
  all_disease_species_sdm_available_rows = sum(all_disease_species_sdm_lookup$sdm_available, na.rm = TRUE),
  pilot_species_rows = nrow(pilot_disease_species_sdm_lookup),
  pilot_species_sdm_available_rows = sum(
    tolower(as.character(pilot_disease_species_sdm_lookup$sdm_available)) %in% c("true", "t", "1", "yes"),
    na.rm = TRUE
  )
)
readr::write_csv(summary, file.path(readiness_target_dir, "bundle_summary.csv"), na = "")

readme <- c(
  "# Consolidated Ready SDM Readiness Bundle",
  "",
  paste0("Generated: ", summary$generated_at_utc[[1]]),
  "",
  "This folder copies the current repository readiness handoff beside the",
  "consolidated ready SDMs. Raster/model paths in `sdm_catalog/` and",
  "`interface_inputs/` are relative to the parent consolidated SDM folder.",
  "",
  "## Parent SDM Layout",
  "",
  "- `../hosts/<Species_safe>/model.rds`",
  "- `../hosts/<Species_safe>/ensemble_mean.tif`",
  "- `../hosts/<Species_safe>/ensemble_tss_clipped.tif`",
  "- `../vectors/<Species_safe>/model.rds`",
  "- `../vectors/<Species_safe>/ensemble_mean.tif`",
  "- `../vectors/<Species_safe>/ensemble_tss_clipped.tif`",
  "",
  "## Key Files",
  "",
  "- `disease_modelling_readiness.csv`: disease-level planning table.",
  "- `disease_modelling_readiness_full.csv`: wider audit table.",
  "- `disease_modelling_pilot_package/`: refreshed pilot package CSVs.",
  "- `evidence_tiers/tiered_species.csv`: role/tier handoff with SDM flags.",
  "- `sdm_catalog/available_species_sdm_paths.csv`: one row per available SDM with relative model/raster paths.",
  "- `interface_inputs/all_disease_species_sdm_lookup.csv`: all roster disease/species rows joined to role features and SDM paths.",
  "- `interface_inputs/pilot_disease_species_sdm_lookup.csv`: pilot package species rows joined to SDM paths.",
  "- `interface_inputs/disease_summary.csv`: compact disease selector table.",
  "",
  "## Interface Notes",
  "",
  "A Shiny or script-based interface can use `interface_inputs/disease_summary.csv`",
  "for disease selection, then filter `all_disease_species_sdm_lookup.csv` or",
  "`pilot_disease_species_sdm_lookup.csv` to load `map_layer_default`",
  "(`ensemble_mean.tif`) or `map_layer_thresholded`",
  "(`ensemble_tss_clipped.tif`). Aggregation choices should be explicit in the",
  "interface because the correct operation depends on whether the output is a",
  "mean suitability surface, any-species binary richness, weighted richness, or",
  "role-filtered map.",
  "",
  "## Counts",
  "",
  paste0("- Available SDM rows: ", summary$available_species_rows[[1]]),
  paste0("- All disease/species rows: ", summary$all_disease_species_rows[[1]]),
  paste0("- All disease/species rows with SDMs: ", summary$all_disease_species_sdm_available_rows[[1]]),
  paste0("- Pilot disease/species rows: ", summary$pilot_species_rows[[1]]),
  paste0("- Pilot disease/species rows with SDMs: ", summary$pilot_species_sdm_available_rows[[1]])
)
writeLines(readme, file.path(readiness_target_dir, "README.md"))

message("Wrote readiness bundle to: ", readiness_target_dir)
message("Available SDM rows: ", nrow(sdm_paths))
message("All disease/species lookup rows: ", nrow(all_disease_species_sdm_lookup))
message("All disease/species rows with SDMs: ", sum(all_disease_species_sdm_lookup$sdm_available, na.rm = TRUE))
message("Pilot species lookup rows: ", nrow(pilot_disease_species_sdm_lookup))
