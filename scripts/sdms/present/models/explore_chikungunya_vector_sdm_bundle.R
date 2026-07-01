#!/usr/bin/env Rscript
# -----------------------------------------------------------------------------|
# explore_chikungunya_vector_sdm_bundle.R ----
# -----------------------------------------------------------------------------|
# Purpose: Define bundle-relative helpers for inspecting delivered Chikungunya
#          host/vector SDMs and opening present-day predictions.
# Outputs: No automatic output; source this file from the bundle root or use
#          explore_chikungunya_vector_sdm_bundle.Rmd for an interactive notebook.
# -----------------------------------------------------------------------------|

required_packages <- c("dplyr", "readr", "tibble")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages) > 0) {
  stop("Install required packages before using this helper: ", paste(missing_packages, collapse = ", "), call. = FALSE)
}

has_path <- function(x) {
  is.character(x) &&
    length(x) > 0 &&
    !is.na(x[[1]]) &&
    nzchar(x[[1]]) &&
    !identical(toupper(trimws(x[[1]])), "NA")
}

parent_dirs <- function(path) {
  if (!has_path(path)) return(character(0))
  path <- normalizePath(path[[1]], mustWork = FALSE)
  out <- character(0)
  repeat {
    out <- c(out, path)
    parent <- dirname(path)
    if (identical(parent, path)) break
    path <- parent
  }
  unique(out)
}

# -----------------------------------------------------------------------------|
# 1. Locate delivery bundle ----
# -----------------------------------------------------------------------------|

detect_bundle_root <- function() {
  candidates <- character(0)

  if (exists("bundle_root", inherits = TRUE)) {
    existing_root <- get("bundle_root", inherits = TRUE)
    if (has_path(existing_root)) {
      candidates <- c(candidates, normalizePath(existing_root[[1]], mustWork = FALSE))
    }
  }

  env_root <- Sys.getenv("CHIKUNGUNYA_SDM_BUNDLE_ROOT", unset = "")
  if (nzchar(env_root)) {
    candidates <- c(candidates, normalizePath(env_root, mustWork = FALSE))
  }

  ofile <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
  if (has_path(ofile)) {
    candidates <- c(candidates, dirname(normalizePath(ofile, mustWork = FALSE)))
  }

  if (requireNamespace("rstudioapi", quietly = TRUE)) {
    active <- tryCatch(rstudioapi::getActiveDocumentContext()$path, error = function(e) "")
    if (has_path(active)) candidates <- c(candidates, dirname(normalizePath(active, mustWork = FALSE)))
  }

  candidates <- c(candidates, getwd())

  sdm_external_root <- Sys.getenv("SDM_EXTERNAL_ROOT", unset = "/Volumes/LaCie/pathogen-sdms")
  default_delivery_root <- file.path(
    sdm_external_root,
    "delivery",
    "chikungunya_vector_sdm_delivery_20260609"
  )
  if (dir.exists(default_delivery_root)) {
    candidates <- c(candidates, default_delivery_root)
  }

  candidates <- unique(unlist(lapply(candidates, parent_dirs), use.names = FALSE))
  for (candidate in candidates) {
    if (file.exists(file.path(candidate, "manifest.csv"))) return(candidate)
  }

  stop("Could not find manifest.csv. Source this script from the bundle root, set `bundle_root`, or set CHIKUNGUNYA_SDM_BUNDLE_ROOT.", call. = FALSE)
}

bundle_root <- detect_bundle_root()

bundle_path <- function(...) file.path(bundle_root, ...)
read_bundle_csv <- function(...) readr::read_csv(bundle_path(...), show_col_types = FALSE, progress = FALSE)

species_key <- function(x) tolower(gsub("[[:space:]_]+", " ", trimws(x)))
safe_species_name <- function(x) {
  out <- gsub("[^A-Za-z0-9]+", "_", trimws(x))
  gsub("(^_+|_+$)", "", out)
}
clean_country_name <- function(x) {
  x <- trimws(as.character(x))
  x[x == ""] <- NA_character_
  x
}
country_join_key <- function(x) {
  x <- clean_country_name(x)
  x <- iconv(x, from = "UTF-8", to = "ASCII//TRANSLIT")
  x <- tolower(gsub("[^a-z0-9]+", " ", x))
  clean_country_name(x)
}

collapse_unique <- function(x, sep = "; ") {
  x <- unique(stats::na.omit(trimws(as.character(x))))
  x <- x[nzchar(x)]
  if (length(x) == 0) return(NA_character_)
  paste(sort(x), collapse = sep)
}

as_numeric_safe <- function(x) suppressWarnings(as.numeric(x))

# -----------------------------------------------------------------------------|
# 2. Read bundle tables ----
# -----------------------------------------------------------------------------|

manifest <- function() read_bundle_csv("manifest.csv")
model_qc <- function() read_bundle_csv("model_qc_summary.csv")

list_readiness_tables <- function() {
  files <- list.files(bundle_path("readiness"), pattern = "[.]csv$", recursive = TRUE, full.names = FALSE)
  tibble::tibble(table = sub("[.]csv$", "", basename(files)), file = files)
}

read_readiness <- function(table = "pilot_sdm_species") {
  files <- list_readiness_tables()
  hit <- files$table == table | files$file == table | basename(files$file) == paste0(table, ".csv")
  if (!any(hit)) stop("Unknown readiness table. Try list_readiness_tables().", call. = FALSE)
  read_bundle_csv("readiness", files$file[which(hit)[1]])
}

# -----------------------------------------------------------------------------|
# 3. Disease overview and country evidence ----
# -----------------------------------------------------------------------------|

disease_overview <- function(disease = NULL) {
  dat <- read_readiness("disease_modelling_pilot")
  dat <- filter_text(dat, "readiness_disease_name", disease, partial = FALSE)

  keep_cols <- c(
    "readiness_disease_name",
    "analysis_unit_label",
    "pathogen_species_name",
    "pathogen_taxid",
    "family",
    "priority_prototype_status",
    "pilot_next_step",
    "readiness_blocker",
    "vectored_status",
    "guild",
    "range_limiting_layer",
    "host_sdm_needed",
    "vector_sdm_needed",
    "direct_vector_evidence_status",
    "country_evidence_status",
    "sdm_availability_status",
    "host_sdm_species_available",
    "vector_sdm_species_available",
    "genbank_distinct_countries_or_territories",
    "who_don_distinct_countries"
  )

  dplyr::select(dat, dplyr::any_of(keep_cols))
}

country_name_overrides <- function() {
  tibble::tribble(
    ~country, ~map_country,
    "Brunei", "Brunei Darussalam",
    "Cape Verde", "Cabo Verde",
    "Cote d'Ivoire", "Cote d'Ivoire",
    "Curacao", "Curacao",
    "East Timor", "Timor-Leste",
    "Eswatini", "eSwatini",
    "Laos", "Lao PDR",
    "Micronesia", "Federated States of Micronesia",
    "Republic of the Congo", "Republic of the Congo",
    "Reunion", "Réunion",
    "Russia", "Russian Federation",
    "South Georgia and the South Sandwich Islands", "South Georgia and the Islands",
    "United States", "United States of America",
    "Virgin Islands", "United States Virgin Islands"
  )
}

missing_country_map_packages <- function() {
  packages <- c("ggplot2", "rnaturalearth", "sf")
  packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
}

world_country_lookup <- function() {
  missing <- missing_country_map_packages()
  if (length(missing) > 0) {
    stop("Install required map packages: ", paste(missing, collapse = ", "), call. = FALSE)
  }

  world <- rnaturalearth::ne_countries(scale = "medium", type = "map_units", returnclass = "sf")
  name_cols <- intersect(
    c("name_long", "admin", "sovereignt", "name", "brk_name", "formal_en"),
    names(world)
  )

  dplyr::bind_rows(lapply(name_cols, function(col) {
    world |>
      dplyr::transmute(
        map_join_name = clean_country_name(.data[[col]]),
        map_join_key = country_join_key(.data[[col]]),
        map_country = clean_country_name(.data$name_long),
        map_iso3 = dplyr::coalesce(.data$iso_a3, .data$adm0_a3),
        geometry
      )
  })) |>
    dplyr::filter(!is.na(.data$map_join_key)) |>
    dplyr::distinct(.data$map_join_key, .keep_all = TRUE)
}

pilot_country_source_rows <- function(disease = NULL, map_ready = FALSE) {
  dat <- read_readiness("pilot_countries") |>
    dplyr::mutate(
      readiness_disease_name = trimws(as.character(.data$readiness_disease_name)),
      country = clean_country_name(.data$country),
      country_source = trimws(as.character(.data$country_source)),
      country_source_label = dplyr::case_when(
        .data$country_source == "genbank" ~ "GenBank",
        .data$country_source == "who_don" ~ "WHO DON",
        TRUE ~ .data$country_source
      ),
      evidence_rows = as_numeric_safe(.data$evidence_rows),
      records_with_country = as_numeric_safe(.data$records_with_country)
    ) |>
    dplyr::filter(!is.na(.data$country))

  dat <- filter_text(dat, "readiness_disease_name", disease, partial = FALSE)

  dat <- dat |>
    dplyr::left_join(country_name_overrides(), by = "country") |>
    dplyr::mutate(
      map_country = dplyr::coalesce(.data$map_country, .data$country),
      map_join_key = country_join_key(.data$map_country)
    )

  if (!map_ready) {
    return(
      dat |>
        dplyr::mutate(
          map_iso3 = NA_character_,
          map_matched = NA
        )
    )
  }

  dat |>
    dplyr::left_join(world_country_lookup(), by = "map_join_key") |>
    dplyr::mutate(map_country = dplyr::coalesce(.data$map_country.y, .data$map_country.x)) |>
    dplyr::select(-dplyr::any_of(c("map_country.x", "map_country.y", "map_join_name"))) |>
    dplyr::mutate(map_matched = !is.na(.data$map_iso3)) |>
    sf::st_as_sf()
}

pilot_country_summary <- function(disease = NULL, map_ready = FALSE) {
  dat <- pilot_country_source_rows(disease = disease, map_ready = map_ready)

  grouped <- dat |>
    dplyr::group_by(
      .data$analysis_unit_id,
      .data$readiness_disease_name,
      .data$country,
      .data$map_country,
      .data$map_iso3,
      .data$map_matched
    )

  if (map_ready) grouped <- dplyr::group_by(grouped, geometry, .add = TRUE)

  out <- grouped |>
    dplyr::summarise(
      country_status = collapse_unique(.data$country_status),
      sources = collapse_unique(.data$country_source_label),
      source_group = dplyr::case_when(
        all(c("GenBank", "WHO DON") %in% unique(.data$country_source_label)) ~ "GenBank + WHO DON",
        "GenBank" %in% unique(.data$country_source_label) ~ "GenBank only",
        "WHO DON" %in% unique(.data$country_source_label) ~ "WHO DON only",
        TRUE ~ collapse_unique(.data$country_source_label)
      ),
      genbank_records = sum(
        dplyr::if_else(.data$country_source == "genbank", .data$records_with_country, 0),
        na.rm = TRUE
      ),
      who_don_evidence_rows = sum(
        dplyr::if_else(.data$country_source == "who_don", .data$evidence_rows, 0),
        na.rm = TRUE
      ),
      source_methods = collapse_unique(.data$source_methods),
      claim_types = collapse_unique(.data$claim_types),
      latest_who_don_publication = suppressWarnings(max(.data$latest_publication_datetime_utc, na.rm = TRUE)),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      latest_who_don_publication = dplyr::if_else(
        is.infinite(.data$latest_who_don_publication),
        as.Date(NA),
        as.Date(.data$latest_who_don_publication)
      )
    )

  dplyr::arrange(out, .data$readiness_disease_name, .data$country)
}

pilot_country_metrics <- function(disease = NULL) {
  pilot_country_summary(disease = disease, map_ready = FALSE) |>
    dplyr::group_by(.data$readiness_disease_name) |>
    dplyr::summarise(
      countries_or_territories = dplyr::n_distinct(.data$country),
      genbank_supported = sum(.data$genbank_records > 0, na.rm = TRUE),
      who_don_supported = sum(.data$who_don_evidence_rows > 0, na.rm = TRUE),
      supported_by_both = sum(.data$source_group == "GenBank + WHO DON", na.rm = TRUE),
      .groups = "drop"
    )
}

pilot_country_map_plot <- function(disease = NULL) {
  missing <- missing_country_map_packages()
  if (length(missing) > 0) {
    stop("Install required map packages: ", paste(missing, collapse = ", "), call. = FALSE)
  }

  disease_countries <- pilot_country_summary(disease = disease, map_ready = TRUE) |>
    dplyr::filter(.data$map_matched) |>
    dplyr::mutate(
      genbank_records_for_fill = dplyr::if_else(
        .data$genbank_records > 0,
        .data$genbank_records,
        NA_real_
      )
    )

  if (nrow(disease_countries) == 0) return(NULL)

  who_don_points <- disease_countries |>
    dplyr::filter(.data$who_don_evidence_rows > 0)

  if (nrow(who_don_points) > 0) {
    who_don_points <- suppressWarnings(sf::st_point_on_surface(who_don_points))
  }

  world_base <- rnaturalearth::ne_countries(scale = "medium", type = "map_units", returnclass = "sf")
  disease_name <- collapse_unique(disease_countries$readiness_disease_name)
  subtitle <- paste0(
    nrow(disease_countries),
    " mapped countries/territories; fill is log10 GenBank records; points mark WHO DON evidence"
  )

  plot <- ggplot2::ggplot() +
    ggplot2::geom_sf(data = world_base, fill = "grey94", color = "white", linewidth = 0.12) +
    ggplot2::geom_sf(
      data = disease_countries,
      ggplot2::aes(fill = .data$genbank_records_for_fill),
      color = "grey25",
      linewidth = 0.08
    ) +
    ggplot2::scale_fill_viridis_c(
      trans = "log10",
      option = "magma",
      direction = -1,
      na.value = "grey94",
      name = "GenBank records"
    ) +
    ggplot2::coord_sf(crs = "+proj=robin", datum = NA) +
    ggplot2::labs(
      title = disease_name,
      subtitle = subtitle,
      caption = "Sources: readiness pilot_countries.csv; mapped with Natural Earth country geometries"
    ) +
    ggplot2::theme_void(base_size = 11) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold", size = 15, hjust = 0.5),
      plot.subtitle = ggplot2::element_text(size = 9, hjust = 0.5, color = "grey30"),
      plot.caption = ggplot2::element_text(size = 7, color = "grey45"),
      legend.position = "bottom",
      legend.key.width = grid::unit(1.2, "cm")
    )

  if (nrow(who_don_points) > 0) {
    plot <- plot +
      ggplot2::geom_sf(
        data = who_don_points,
        shape = 21,
        fill = "#2b8cbe",
        color = "white",
        stroke = 0.55,
        size = 2.3,
        inherit.aes = FALSE
      )
  }

  plot
}

# -----------------------------------------------------------------------------|
# 4. Filtering helpers ----
# -----------------------------------------------------------------------------|

as_filter_bool <- function(x) {
  if (is.null(x)) return(NULL)
  if (is.logical(x)) return(x)
  x <- tolower(trimws(as.character(x)))
  if (x %in% c("true", "t", "yes", "y", "1")) return(TRUE)
  if (x %in% c("false", "f", "no", "n", "0")) return(FALSE)
  stop("Boolean filters should be TRUE/FALSE, yes/no, or 1/0.", call. = FALSE)
}

filter_text <- function(dat, column, values, partial = TRUE) {
  if (is.null(values)) return(dat)
  if (!column %in% names(dat)) stop("Column not found: ", column, call. = FALSE)

  values <- tolower(trimws(as.character(values)))
  field <- tolower(trimws(as.character(dat[[column]])))

  keep <- rep(FALSE, nrow(dat))
  for (value in values) {
    keep <- keep | if (partial) grepl(value, field, fixed = TRUE) else field == value
  }
  dat[keep & !is.na(keep), , drop = FALSE]
}

filter_bool <- function(dat, column, value) {
  value <- as_filter_bool(value)
  if (is.null(value)) return(dat)
  if (!column %in% names(dat)) stop("Column not found: ", column, call. = FALSE)

  field <- as_filter_bool_vec(dat[[column]])
  dat[!is.na(field) & field == value, , drop = FALSE]
}

as_filter_bool_vec <- function(x) {
  if (is.logical(x)) return(x)
  x <- tolower(trimws(as.character(x)))
  dplyr::case_when(
    x %in% c("true", "t", "yes", "y", "1") ~ TRUE,
    x %in% c("false", "f", "no", "n", "0") ~ FALSE,
    TRUE ~ NA
  )
}

selected_values <- function(x) {
  if (is.null(x) || length(x) == 0) return(character(0))
  x <- as.character(x)
  x[!is.na(x) & nzchar(x)]
}

sdm_availability_to_bool <- function(sdm_availability = "available") {
  if (is.null(sdm_availability)) return(NULL)
  if (is.logical(sdm_availability)) return(sdm_availability[[1]])

  value <- tolower(trimws(as.character(sdm_availability[[1]])))
  if (value %in% c("available", "available only", "true", "yes", "1")) return(TRUE)
  if (value %in% c("unavailable", "unavailable only", "false", "no", "0")) return(FALSE)
  if (value %in% c("all", "any", "")) return(NULL)

  stop("sdm_availability should be one of: available, unavailable, all.", call. = FALSE)
}

detection_category_levels <- c("PCR/Sequencing", "Antibodies", "Isolation/Observation", "Not specified")

detection_categories_one <- function(x) {
  x <- ifelse(is.na(x), "", as.character(x))
  out <- character(0)
  if (grepl("PCR|Sequenc", x, ignore.case = TRUE)) out <- c(out, "PCR/Sequencing")
  if (grepl("Antibod", x, ignore.case = TRUE)) out <- c(out, "Antibodies")
  if (grepl("Isolation|Observation", x, ignore.case = TRUE)) out <- c(out, "Isolation/Observation")
  if (grepl("Not specified", x, ignore.case = TRUE) || length(out) == 0) out <- c(out, "Not specified")
  detection_category_levels[detection_category_levels %in% out]
}

detection_categories_chr <- function(x) {
  vapply(x, function(one) paste(detection_categories_one(one), collapse = "; "), character(1))
}

add_detection_categories <- function(dat) {
  if (!"host_detection_method" %in% names(dat)) return(dat)
  dplyr::mutate(dat, host_detection_category = detection_categories_chr(.data$host_detection_method))
}

filter_in_selected <- function(dat, column, selected) {
  selected <- selected_values(selected)
  if (length(selected) == 0) return(dat)
  if (!column %in% names(dat)) stop("Column not found: ", column, call. = FALSE)
  dplyr::filter(dat, .data[[column]] %in% selected)
}

filter_detection_categories <- function(dat, selected) {
  selected <- selected_values(selected)
  if (length(selected) == 0) return(dat)

  detection_source <- if ("host_detection_method" %in% names(dat)) {
    dat$host_detection_method
  } else if ("host_detection_category" %in% names(dat)) {
    dat$host_detection_category
  } else {
    rep("", nrow(dat))
  }

  keep <- vapply(detection_source, function(method) {
    any(detection_categories_one(method) %in% selected)
  }, logical(1))
  dplyr::filter(dat, .env$keep)
}

bool_filter_values <- function(x) {
  selected <- selected_values(x)
  if (length(selected) == 0) return(NULL)

  out <- as_filter_bool_vec(selected)
  if (any(is.na(out))) stop("Boolean filters should be TRUE/FALSE, yes/no, or 1/0.", call. = FALSE)
  out
}

# -----------------------------------------------------------------------------|
# 5. SDM index and file paths ----
# -----------------------------------------------------------------------------|

find_species <- function(species) {
  dat <- manifest()
  hit <- dplyr::filter(dat, species_key(.data$species_name) == species_key(species))
  if (nrow(hit) == 0) stop("Species not found in manifest: ", species, call. = FALSE)
  dplyr::slice(hit, 1)
}

model_folder <- function(species) {
  row <- find_species(species)
  species_dir <- safe_species_name(row$species_name[[1]])

  if (row$delivery_group[[1]] == "diagnostic_3") {
    bundle_path("models", row$delivery_group[[1]], species_dir, row$delivery_variant[[1]])
  } else {
    bundle_path("models", row$delivery_group[[1]], species_dir)
  }
}

prediction_folder <- function(species) {
  row <- find_species(species)
  bundle_path("predictions", row$delivery_group[[1]], safe_species_name(row$species_name[[1]]))
}

model_path <- function(species) file.path(model_folder(species), "model.rds")
prediction_path <- function(species) file.path(prediction_folder(species), "ensemble_mean.tif")
map_path <- function(species, with_occurrences = TRUE) {
  file.path(prediction_folder(species), if (with_occurrences) "ensemble_mean_with_occurrences.png" else "ensemble_mean_map.png")
}

sdms <- function(role = NULL, group = NULL, quality = NULL, available_only = TRUE) {
  dat <- manifest()
  dat <- filter_text(dat, "species_role", role, partial = FALSE)
  dat <- filter_text(dat, "delivery_group", group, partial = FALSE)
  dat <- filter_text(dat, "model_quality", quality, partial = TRUE)

  dat$local_model_path <- vapply(dat$species_name, model_path, character(1))
  dat$local_prediction_tif <- vapply(dat$species_name, prediction_path, character(1))
  dat$local_map_png <- vapply(dat$species_name, map_path, character(1), with_occurrences = FALSE)
  dat$has_model <- file.exists(dat$local_model_path)
  dat$has_prediction <- file.exists(dat$local_prediction_tif)
  dat$has_map <- file.exists(dat$local_map_png)

  if (available_only) {
    dat <- dplyr::filter(dat, .data$has_model, .data$has_prediction, .data$has_map)
  }

  dplyr::select(
    dat,
    species_name,
    species_role,
    delivery_group,
    model_quality,
    retained_models,
    min_boyce,
    max_boyce,
    max_test_auc,
    max_max_tss,
    has_model,
    has_prediction,
    has_map,
    local_prediction_tif,
    local_map_png,
    local_model_path
  )
}

sdm_summary <- function() {
  dat <- sdms(available_only = FALSE)
  dat |>
    dplyr::count(
      species_role,
      delivery_group,
      model_quality,
      has_model,
      has_prediction,
      has_map,
      name = "n"
    ) |>
    dplyr::arrange(species_role, delivery_group, model_quality)
}

available_sdms <- function(role = NULL) sdms(role = role, available_only = TRUE)
diagnostic_sdms <- function() sdms(group = "diagnostic_3", available_only = FALSE)

# -----------------------------------------------------------------------------|
# 6. Host and vector evidence indexes ----
# -----------------------------------------------------------------------------|

add_delivered_sdm_fields <- function(dat, role) {
  delivered <- sdms(role = role, available_only = FALSE) |>
    dplyr::transmute(
      species_key_join = species_key(.data$species_name),
      delivered_species_name = .data$species_name,
      delivery_group,
      model_quality,
      retained_models,
      max_test_auc,
      max_max_tss,
      local_prediction_tif,
      local_map_png,
      local_model_path
    )

  dat <- dplyr::mutate(dat, species_key_join = species_key(.data$species_name))
  dat <- dplyr::left_join(dat, delivered, by = "species_key_join")
  dat$species_name <- ifelse(!is.na(dat$delivered_species_name), dat$delivered_species_name, dat$species_name)
  dplyr::select(dat, -species_key_join, -delivered_species_name)
}

hosts <- function(
  detection_method = NULL,
  role = NULL,
  confidence = NULL,
  manual_review = NULL,
  in_gibb_etal = NULL,
  in_empres_i = NULL,
  sdm_available = NULL
) {
  dat <- read_readiness("pilot_hosts") |>
    add_delivered_sdm_fields(role = "host")

  dat <- filter_text(dat, "host_detection_method", detection_method)
  dat <- filter_text(dat, "host_role_assignment", role)
  dat <- filter_text(dat, "host_role_confidence", confidence, partial = FALSE)
  dat <- filter_bool(dat, "host_role_needs_manual_review", manual_review)
  dat <- filter_bool(dat, "in_gibb_etal", in_gibb_etal)
  dat <- filter_bool(dat, "in_empres_i", in_empres_i)

  dat$sdm_available <- !is.na(dat$local_prediction_tif) & file.exists(dat$local_prediction_tif)
  dat <- filter_bool(dat, "sdm_available", sdm_available)

  dplyr::select(
    dat,
    species_name,
    host_class,
    host_order,
    host_family,
    host_detection_method,
    host_role_assignment,
    host_role_confidence,
    host_role_needs_manual_review,
    in_gibb_etal,
    in_empres_i,
    sdm_available,
    model_quality,
    local_prediction_tif,
    local_map_png,
    local_model_path
  )
}

vectors <- function(
  evidence_level = NULL,
  evidence_basis = NULL,
  competence_status = NULL,
  bites_humans = NULL,
  disease_vector_evidence = NULL,
  host_vector_evidence = NULL,
  competence_evidence = NULL,
  transmission_demonstrated = NULL,
  natural_infection_reported = NULL,
  taxonomy_caution = NULL,
  sdm_available = NULL
) {
  dat <- read_readiness("pilot_vectors") |>
    add_delivered_sdm_fields(role = "vector")

  dat <- filter_text(dat, "best_evidence_level", evidence_level)
  dat <- filter_text(dat, "best_evidence_basis", evidence_basis)
  dat <- filter_text(dat, "vector_competence_status", competence_status)
  dat <- filter_bool(dat, "bites_humans", bites_humans)
  dat <- filter_bool(dat, "has_disease_vector_evidence", disease_vector_evidence)
  dat <- filter_bool(dat, "has_host_vector_evidence", host_vector_evidence)
  dat <- filter_bool(dat, "has_competence_evidence", competence_evidence)
  dat <- filter_bool(dat, "transmission_demonstrated", transmission_demonstrated)
  dat <- filter_bool(dat, "natural_infection_reported", natural_infection_reported)
  dat <- filter_bool(dat, "taxonomy_caution", taxonomy_caution)

  dat$sdm_available <- !is.na(dat$local_prediction_tif) & file.exists(dat$local_prediction_tif)
  dat <- filter_bool(dat, "sdm_available", sdm_available)

  dplyr::select(
    dat,
    species_name,
    vector_group,
    best_evidence_level,
    best_evidence_basis,
    vector_record_sources,
    has_disease_vector_evidence,
    has_host_vector_evidence,
    has_competence_evidence,
    vector_competence_status,
    transmission_demonstrated,
    natural_infection_reported,
    bites_humans,
    taxonomy_caution,
    sdm_available,
    delivery_group,
    model_quality,
    local_prediction_tif,
    local_map_png,
    local_model_path
  )
}

filter_hosts_for_bundle <- function(
  sdm_availability = "available",
  detection_categories = NULL,
  roles = NULL,
  confidence = NULL
) {
  hosts(sdm_available = sdm_availability_to_bool(sdm_availability)) |>
    add_detection_categories() |>
    filter_detection_categories(detection_categories) |>
    filter_in_selected("host_role_assignment", roles) |>
    filter_in_selected("host_role_confidence", confidence) |>
    dplyr::select(
      species_name,
      host_class,
      host_detection_category,
      host_role_assignment,
      host_role_confidence,
      sdm_available,
      local_model_path,
      local_prediction_tif
    )
}

filter_vectors_for_bundle <- function(
  sdm_availability = "available",
  evidence_levels = NULL,
  competence_statuses = NULL,
  bites_humans = NULL
) {
  bites_filter <- bool_filter_values(bites_humans)

  dat <- vectors(sdm_available = sdm_availability_to_bool(sdm_availability)) |>
    dplyr::select(
      species_name,
      best_evidence_level,
      best_evidence_basis,
      vector_competence_status,
      bites_humans,
      sdm_available,
      delivery_group,
      local_model_path,
      local_prediction_tif
    ) |>
    filter_in_selected("best_evidence_level", evidence_levels) |>
    filter_in_selected("vector_competence_status", competence_statuses)

  if (!is.null(bites_filter)) {
    dat <- dplyr::filter(dat, as_filter_bool_vec(.data$bites_humans) %in% bites_filter)
  }

  dat
}

# -----------------------------------------------------------------------------|
# 7. Open maps and load predictions ----
# -----------------------------------------------------------------------------|

open_map <- function(species, with_occurrences = TRUE) {
  path <- map_path(species, with_occurrences = with_occurrences)
  if (!file.exists(path) && with_occurrences) path <- map_path(species, with_occurrences = FALSE)
  if (!file.exists(path)) stop("Saved map not found: ", path, call. = FALSE)

  utils::browseURL(path)
  invisible(path)
}

load_prediction <- function(species) {
  if (!requireNamespace("raster", quietly = TRUE)) {
    stop("Install the `raster` package to load GeoTIFF predictions.", call. = FALSE)
  }
  raster::raster(prediction_path(species))
}

plot_prediction <- function(species, with_occurrences = TRUE) {
  if (!requireNamespace("raster", quietly = TRUE)) {
    stop("Install the `raster` package to plot GeoTIFF predictions.", call. = FALSE)
  }

  r <- load_prediction(species)
  raster::plot(r, col = hcl.colors(100, "YlGnBu"), main = species, xlab = "Longitude", ylab = "Latitude")
  if (requireNamespace("maps", quietly = TRUE)) maps::map("world", add = TRUE, col = "grey35", lwd = 0.6)

  occ_path <- file.path(model_folder(species), "occurrences_used.csv")
  if (with_occurrences && file.exists(occ_path)) {
    occ <- readr::read_csv(occ_path, show_col_types = FALSE, progress = FALSE)
    points(occ$decimalLongitude, occ$decimalLatitude, pch = 21, bg = "#ffcc33", col = "black", cex = 0.75, lwd = 0.5)
  }

  invisible(r)
}

show_species <- function(species) {
  role <- find_species(species)$species_role[[1]]
  evidence <- if (role == "host") {
    hosts() |> dplyr::filter(species_key(.data$species_name) == species_key(species))
  } else {
    vectors() |> dplyr::filter(species_key(.data$species_name) == species_key(species))
  }

  list(
    sdm = sdms(available_only = FALSE) |> dplyr::filter(species_key(.data$species_name) == species_key(species)),
    evidence = evidence,
    model_path = model_path(species),
    prediction_path = prediction_path(species),
    map_path = map_path(species, with_occurrences = FALSE)
  )
}

# -----------------------------------------------------------------------------|
# 8. Advanced model details ----
# -----------------------------------------------------------------------------|

read_model <- function(species) readRDS(model_path(species))
read_run_summary <- function(species) readr::read_csv(file.path(model_folder(species), "run_summary.csv"), show_col_types = FALSE, progress = FALSE)

read_occurrences <- function(species) {
  path <- file.path(model_folder(species), "occurrences_used.csv")
  if (!file.exists(path)) stop("No occurrence sidecar is available for this species in the bundle: ", species, call. = FALSE)
  readr::read_csv(path, show_col_types = FALSE, progress = FALSE)
}

read_params <- function(species) {
  row <- find_species(species)
  path <- bundle_path("parameter_tables", paste0(safe_species_name(row$species_name[[1]]), "__", row$delivery_group[[1]], "__params.csv"))
  readr::read_csv(path, show_col_types = FALSE, progress = FALSE)
}

read_aicc <- function(species) {
  row <- find_species(species)
  path <- bundle_path("parameter_tables", paste0(safe_species_name(row$species_name[[1]]), "__", row$delivery_group[[1]], "__aicc.csv"))
  readr::read_csv(path, show_col_types = FALSE, progress = FALSE)
}
