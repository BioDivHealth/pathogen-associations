################################################################################
# aggregation_helpers.R
################################################################################
# Purpose: Shared helpers for filtering ready SDM species, loading rasters, and
#          writing disease-level aggregate maps from the consolidated SDM bundle.
################################################################################

suppressPackageStartupMessages({
  if (!requireNamespace("pacman", quietly = TRUE)) {
    stop("Package `pacman` is required.", call. = FALSE)
  }
})

pacman::p_load(dplyr, readr, stringr, terra, tibble)

current_script_path <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    return(normalizePath(sub("^--file=", "", file_arg[[1]]), winslash = "/", mustWork = FALSE))
  }

  for (frame in rev(sys.frames())) {
    if (!is.null(frame$ofile)) {
      return(normalizePath(frame$ofile, winslash = "/", mustWork = FALSE))
    }
  }

  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    path <- tryCatch(rstudioapi::getSourceEditorContext()$path, error = function(e) "")
    if (!is.null(path) && nzchar(path)) {
      return(normalizePath(path, winslash = "/", mustWork = FALSE))
    }
  }

  NA_character_
}

looks_like_ready_sdm_bundle <- function(path) {
  file.exists(file.path(path, "readiness", "interface_inputs", "all_disease_species_sdm_lookup.csv")) &&
    dir.exists(file.path(path, "hosts")) &&
    dir.exists(file.path(path, "vectors"))
}

default_ready_sdm_bundle_root <- function() {
  env_root <- Sys.getenv("READY_SDM_BUNDLE_ROOT", unset = "")
  if (nzchar(env_root)) {
    return(env_root)
  }

  script_path <- current_script_path()
  if (!is.na(script_path)) {
    script_bundle_root <- normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE)
    if (looks_like_ready_sdm_bundle(script_bundle_root)) {
      return(script_bundle_root)
    }
  }

  cwd <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  if (looks_like_ready_sdm_bundle(cwd)) {
    return(cwd)
  }
  if (looks_like_ready_sdm_bundle(file.path(cwd, "..", ".."))) {
    return(normalizePath(file.path(cwd, "..", ".."), winslash = "/", mustWork = FALSE))
  }

  sdm_external_root <- Sys.getenv("SDM_EXTERNAL_ROOT", unset = "/Volumes/LaCie/pathogen-sdms")
  file.path(sdm_external_root, "consolidated_ready_sdms_20260630")
}

timestamp_file <- function() {
  format(Sys.time(), "%Y%m%d_%H%M%S", tz = "UTC")
}

timestamp_utc <- function() {
  format(Sys.time(), "%Y-%m-%d %H:%M:%S UTC", tz = "UTC")
}

ensure_dir <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

clean_key <- function(x) {
  x <- tolower(trimws(as.character(x)))
  stringr::str_squish(gsub("[^a-z0-9]+", " ", x))
}

safe_path_token <- function(x) {
  x <- paste(x, collapse = "_")
  x <- gsub("[^A-Za-z0-9_-]+", "_", x)
  x <- gsub("^_+|_+$", "", x)
  if (!nzchar(x)) {
    return("sdm_run")
  }
  x
}

collapse_unique <- function(x) {
  x <- as.character(x)
  x <- x[!is.na(x) & nzchar(x)]
  if (length(x) == 0) {
    return(NA_character_)
  }
  paste(sort(unique(x)), collapse = "; ")
}

as_bool <- function(x) {
  if (is.logical(x)) {
    return(x)
  }
  tolower(trimws(as.character(x))) %in% c("true", "t", "yes", "y", "1")
}

normalize_filter <- function(x) {
  if (is.null(x)) {
    return(NULL)
  }
  x <- as.character(x)
  x <- x[!is.na(x) & nzchar(trimws(x))]
  x <- trimws(x)
  if (length(x) == 0 || any(tolower(x) == "all")) {
    return(NULL)
  }
  unique(x)
}

read_csv_layer <- function(path) {
  if (!file.exists(path)) {
    stop("Required CSV not found: ", path, call. = FALSE)
  }
  readr::read_csv(path, col_types = readr::cols(.default = readr::col_character()), show_col_types = FALSE)
}

interface_lookup_path <- function(bundle_root) {
  file.path(bundle_root, "readiness", "interface_inputs", "all_disease_species_sdm_lookup.csv")
}

disease_summary_path <- function(bundle_root) {
  file.path(bundle_root, "readiness", "interface_inputs", "disease_summary.csv")
}

evidence_tiers_path <- function(bundle_root) {
  file.path(bundle_root, "readiness", "evidence_tiers", "tiered_species.csv")
}

detection_category_levels <- function() {
  c("PCR/Sequencing", "Antibodies", "Isolation/Observation", "Not specified")
}

detection_categories_one <- function(x) {
  x <- ifelse(is.na(x), "", as.character(x))
  out <- character(0)
  if (grepl("PCR|Sequenc", x, ignore.case = TRUE)) out <- c(out, "PCR/Sequencing")
  if (grepl("Antibod", x, ignore.case = TRUE)) out <- c(out, "Antibodies")
  if (grepl("Isolation|Observation", x, ignore.case = TRUE)) out <- c(out, "Isolation/Observation")
  if (grepl("Not specified", x, ignore.case = TRUE) || length(out) == 0) out <- c(out, "Not specified")
  detection_category_levels()[detection_category_levels() %in% out]
}

detection_categories_chr <- function(x) {
  vapply(x, function(one) paste(detection_categories_one(one), collapse = "; "), character(1))
}

row_has_detection_category <- function(methods, selected_categories) {
  vapply(methods, function(method) {
    any(detection_categories_one(method) %in% selected_categories)
  }, logical(1))
}

add_join_keys <- function(dat) {
  dat %>%
    mutate(
      join_analysis_unit_id = as.character(analysis_unit_id),
      join_species_role = as.character(species_role),
      join_species_name = clean_key(species_name),
      join_tax_id = as.character(tax_id)
    )
}

enrich_lookup_with_host_detection <- function(lookup, bundle_root) {
  if ("host_detection_method" %in% names(lookup)) {
    return(lookup)
  }

  tier_path <- evidence_tiers_path(bundle_root)
  if (!file.exists(tier_path)) {
    return(lookup)
  }

  tiers <- read_csv_layer(tier_path)
  required_cols <- c("analysis_unit_id", "species_role", "species_name", "tax_id", "host_detection_method")
  if (!all(required_cols %in% names(tiers))) {
    return(lookup)
  }

  optional_cols <- intersect(c("host_detection_tier", "host_direct_detection_supported"), names(tiers))
  host_detection <- tiers %>%
    filter(species_role == "host") %>%
    add_join_keys() %>%
    group_by(join_analysis_unit_id, join_species_role, join_species_name, join_tax_id) %>%
    summarise(
      host_detection_method = collapse_unique(host_detection_method),
      across(all_of(optional_cols), collapse_unique),
      .groups = "drop"
    ) %>%
    mutate(host_detection_category = detection_categories_chr(host_detection_method))

  lookup %>%
    add_join_keys() %>%
    left_join(
      host_detection,
      by = c("join_analysis_unit_id", "join_species_role", "join_species_name", "join_tax_id")
    ) %>%
    select(-starts_with("join_"))
}

load_sdm_interface_lookup <- function(bundle_root = default_ready_sdm_bundle_root()) {
  bundle_root <- normalizePath(bundle_root, winslash = "/", mustWork = TRUE)
  lookup <- read_csv_layer(interface_lookup_path(bundle_root))

  required_cols <- c(
    "analysis_unit_id",
    "readiness_disease_name",
    "species_role",
    "species_name",
    "sdm_available",
    "map_layer_default",
    "map_layer_thresholded"
  )
  missing_cols <- setdiff(required_cols, names(lookup))
  if (length(missing_cols) > 0) {
    stop(
      "Interface lookup is missing required columns: ",
      paste(missing_cols, collapse = ", "),
      call. = FALSE
    )
  }

  lookup <- lookup %>%
    mutate(
      sdm_available = as_bool(sdm_available),
      analysis_unit_id = as.character(analysis_unit_id),
      species_role = as.character(species_role)
    )

  enrich_lookup_with_host_detection(lookup, bundle_root)
}

load_disease_summary <- function(bundle_root = default_ready_sdm_bundle_root()) {
  bundle_root <- normalizePath(bundle_root, winslash = "/", mustWork = TRUE)
  read_csv_layer(disease_summary_path(bundle_root))
}

append_reason <- function(reason, new_reason) {
  reason <- as.character(reason)
  reason[is.na(reason)] <- ""
  add <- !is.na(new_reason) & nzchar(new_reason)
  reason[add & nzchar(reason)] <- paste(reason[add & nzchar(reason)], new_reason[add & nzchar(reason)], sep = "; ")
  reason[add & !nzchar(reason)] <- new_reason[add & !nzchar(reason)]
  reason
}

preview_sdm_selection <- function(bundle_root = default_ready_sdm_bundle_root(),
                                  analysis_unit_ids,
                                  species_roles,
                                  host_role_buckets = NULL,
                                  host_detection_methods = NULL,
                                  vector_role_buckets = NULL,
                                  evidence_tiers = NULL,
                                  sdm_sources = NULL,
                                  lookup = NULL) {
  bundle_root <- normalizePath(bundle_root, winslash = "/", mustWork = TRUE)
  analysis_unit_ids <- normalize_filter(analysis_unit_ids)
  species_roles <- normalize_filter(species_roles)
  host_role_buckets <- normalize_filter(host_role_buckets)
  host_detection_methods <- normalize_filter(host_detection_methods)
  vector_role_buckets <- normalize_filter(vector_role_buckets)
  evidence_tiers <- normalize_filter(evidence_tiers)
  sdm_sources <- normalize_filter(sdm_sources)

  if (is.null(analysis_unit_ids)) {
    stop("At least one `analysis_unit_id` is required.", call. = FALSE)
  }
  if (is.null(species_roles)) {
    stop("At least one species role is required.", call. = FALSE)
  }

  if (is.null(lookup)) {
    lookup <- load_sdm_interface_lookup(bundle_root)
  }

  candidates <- lookup %>%
    filter(
      analysis_unit_id %in% analysis_unit_ids,
      species_role %in% species_roles
    ) %>%
    mutate(excluded_reason = "")

  if (nrow(candidates) == 0) {
    stop("No disease/species rows matched the requested disease and role filters.", call. = FALSE)
  }

  if (!is.null(host_role_buckets) && "host_role_bucket" %in% names(candidates)) {
    reason <- ifelse(
      candidates$species_role == "host" &
        !(as.character(candidates$host_role_bucket) %in% host_role_buckets),
      "host_role_bucket_filtered",
      NA_character_
    )
    candidates$excluded_reason <- append_reason(candidates$excluded_reason, reason)
  }

  if (!is.null(host_detection_methods)) {
    if (!"host_detection_method" %in% names(candidates)) {
      stop("Host detection filtering requires `host_detection_method` in the interface lookup.", call. = FALSE)
    }
    host_detection_match <- row_has_detection_category(candidates$host_detection_method, host_detection_methods)
    reason <- ifelse(
      candidates$species_role == "host" & !host_detection_match,
      "host_detection_method_filtered",
      NA_character_
    )
    candidates$excluded_reason <- append_reason(candidates$excluded_reason, reason)
  }

  if (!is.null(vector_role_buckets) && "vector_role_bucket" %in% names(candidates)) {
    reason <- ifelse(
      candidates$species_role == "vector" &
        !(as.character(candidates$vector_role_bucket) %in% vector_role_buckets),
      "vector_role_bucket_filtered",
      NA_character_
    )
    candidates$excluded_reason <- append_reason(candidates$excluded_reason, reason)
  }

  if (!is.null(evidence_tiers) && "biological_evidence_tier" %in% names(candidates)) {
    reason <- ifelse(
      !(as.character(candidates$biological_evidence_tier) %in% evidence_tiers),
      "evidence_tier_filtered",
      NA_character_
    )
    candidates$excluded_reason <- append_reason(candidates$excluded_reason, reason)
  }

  if (!is.null(sdm_sources) && "sdm_source_label" %in% names(candidates)) {
    reason <- ifelse(
      candidates$sdm_available & !(as.character(candidates$sdm_source_label) %in% sdm_sources),
      "sdm_source_filtered",
      NA_character_
    )
    candidates$excluded_reason <- append_reason(candidates$excluded_reason, reason)
  }

  candidates$excluded_reason <- append_reason(
    candidates$excluded_reason,
    ifelse(candidates$sdm_available, NA_character_, "missing_sdm")
  )

  selected <- candidates %>%
    filter(!nzchar(excluded_reason)) %>%
    arrange(readiness_disease_name, species_role, species_name)

  excluded <- candidates %>%
    filter(nzchar(excluded_reason)) %>%
    arrange(readiness_disease_name, species_role, species_name)

  list(
    selected = selected,
    excluded = excluded,
    candidates = candidates
  )
}

raster_modes <- function() {
  c("continuous", "tss_clipped", "manual_binary", "model_threshold_binary")
}

raster_column_for_mode <- function(raster_mode) {
  raster_mode <- match.arg(raster_mode, raster_modes())
  if (raster_mode == "tss_clipped") {
    return("map_layer_thresholded")
  }
  "map_layer_default"
}

validate_mode_combination <- function(raster_mode, aggregation_mode) {
  raster_mode <- match.arg(raster_mode, raster_modes())
  aggregation_mode <- match.arg(
    aggregation_mode,
    c("mean_continuous", "max_continuous", "binary_richness", "any_binary")
  )

  binary_modes <- c("binary_richness", "any_binary")
  if (aggregation_mode %in% binary_modes && raster_mode == "continuous") {
    stop(
      "Binary aggregation modes require `raster_mode` to be `tss_clipped`, `manual_binary`, or `model_threshold_binary`.",
      call. = FALSE
    )
  }
  if (raster_mode == "model_threshold_binary" && !aggregation_mode %in% binary_modes) {
    stop(
      "`model_threshold_binary` produces binary rasters and requires `binary_richness` or `any_binary`.",
      call. = FALSE
    )
  }

  invisible(TRUE)
}

resolve_raster_paths <- function(selected, bundle_root, raster_mode) {
  raster_col <- raster_column_for_mode(raster_mode)
  if (!raster_col %in% names(selected)) {
    stop("Selected species table is missing raster column: ", raster_col, call. = FALSE)
  }

  selected %>%
    mutate(
      raster_mode = raster_mode,
      raster_relative_path = .data[[raster_col]],
      raster_path = file.path(bundle_root, raster_relative_path),
      model_relative_path = if ("sdm_model_rds" %in% names(.)) sdm_model_rds else NA_character_,
      model_path = ifelse(
        !is.na(model_relative_path) & nzchar(model_relative_path),
        file.path(bundle_root, model_relative_path),
        NA_character_
      )
    )
}

threshold_methods <- function() {
  c("tss_test_mean", "tss_test_median", "tss_maxent_mean", "tss_maxent_median")
}

threshold_column_for_method <- function(model_threshold_method) {
  model_threshold_method <- match.arg(model_threshold_method, threshold_methods())
  if (grepl("^tss_test_", model_threshold_method)) {
    return("TSS.threshold.TEST")
  }
  "TSS.threshold.MAXENT"
}

threshold_summary_for_method <- function(values, model_threshold_method) {
  model_threshold_method <- match.arg(model_threshold_method, threshold_methods())
  if (grepl("_median$", model_threshold_method)) {
    return(stats::median(values, na.rm = TRUE))
  }
  mean(values, na.rm = TRUE)
}

read_model_threshold <- function(model_path, species_name, model_threshold_method) {
  if (is.na(model_path) || !nzchar(model_path) || !file.exists(model_path)) {
    stop("Model RDS not found for thresholding: ", species_name, " | ", model_path, call. = FALSE)
  }

  obj <- readRDS(model_path)
  params <- obj$params
  threshold_col <- threshold_column_for_method(model_threshold_method)
  if (!is.data.frame(params) || !threshold_col %in% names(params)) {
    stop(
      "Model parameters do not include `",
      threshold_col,
      "` for ",
      species_name,
      ".",
      call. = FALSE
    )
  }

  values <- suppressWarnings(as.numeric(params[[threshold_col]]))
  values <- values[is.finite(values)]
  if (length(values) == 0) {
    stop("No finite `", threshold_col, "` values for ", species_name, ".", call. = FALSE)
  }

  threshold_summary_for_method(values, model_threshold_method)
}

model_thresholds_for_selected <- function(selected, model_threshold_method) {
  model_threshold_method <- match.arg(model_threshold_method, threshold_methods())
  thresholds <- vapply(
    seq_len(nrow(selected)),
    function(idx) {
      read_model_threshold(selected$model_path[[idx]], selected$species_name[[idx]], model_threshold_method)
    },
    numeric(1)
  )

  stats::setNames(thresholds, selected$species_name)
}

same_resolution <- function(rasters) {
  base_res <- terra::res(rasters[[1]])
  vapply(rasters[-1], function(r) {
    isTRUE(all.equal(base_res, terra::res(r), tolerance = 1e-10))
  }, logical(1))
}

extend_rasters_to_union <- function(rasters, fill_value = 0) {
  same_crs <- vapply(rasters[-1], function(r) terra::same.crs(rasters[[1]], r), logical(1))
  same_res <- same_resolution(rasters)
  if (any(!same_crs) || any(!same_res)) {
    stop(
      "`extend_to_union` requires matching CRS and resolution. Use `strict` for QA or prepare aligned rasters first.",
      call. = FALSE
    )
  }

  union_extent <- Reduce(terra::union, lapply(rasters, terra::ext))
  template <- terra::rast(
    ext = union_extent,
    resolution = terra::res(rasters[[1]]),
    crs = terra::crs(rasters[[1]])
  )

  extended <- lapply(rasters, function(r) terra::extend(r, template, fill = fill_value))
  geom_ok <- vapply(extended[-1], function(r) {
    isTRUE(terra::compareGeom(
      extended[[1]],
      r,
      stopOnError = FALSE,
      crs = TRUE,
      ext = TRUE,
      rowcol = TRUE,
      res = TRUE
    ))
  }, logical(1))

  if (any(!geom_ok)) {
    stop("Union-extended rasters still do not share geometry.", call. = FALSE)
  }

  extended
}

load_checked_rasters <- function(selected,
                                 geometry_strategy = c("strict", "extend_to_union"),
                                 geometry_fill_value = 0,
                                 internal_na_fill_value = 0) {
  geometry_strategy <- match.arg(geometry_strategy)
  missing <- selected %>%
    filter(is.na(raster_path) | !nzchar(raster_path) | !file.exists(raster_path))

  if (nrow(missing) > 0) {
    preview <- missing %>%
      transmute(label = paste(species_role, species_name, raster_path, sep = " | ")) %>%
      pull(label) %>%
      head(20)
    stop(
      "Selected species include missing raster paths: ",
      paste(preview, collapse = "; "),
      call. = FALSE
    )
  }

  rasters <- lapply(selected$raster_path, terra::rast)
  layer_counts <- vapply(rasters, terra::nlyr, numeric(1))
  if (any(layer_counts != 1L)) {
    bad <- selected$species_name[layer_counts != 1L]
    stop(
      "All selected SDM rasters must be single-layer. Multi-layer rasters: ",
      paste(bad, collapse = "; "),
      call. = FALSE
    )
  }

  if (length(rasters) > 1 && geometry_strategy == "strict") {
    geom_ok <- vapply(rasters[-1], function(r) {
      isTRUE(terra::compareGeom(
        rasters[[1]],
        r,
        stopOnError = FALSE,
        crs = TRUE,
        ext = TRUE,
        rowcol = TRUE,
        res = TRUE
      ))
    }, logical(1))

    if (any(!geom_ok)) {
      bad <- selected$species_name[-1][!geom_ok]
      stop(
        "Selected rasters do not all share CRS, extent, resolution, and dimensions. ",
        "Mismatched species: ",
        paste(bad, collapse = "; "),
        call. = FALSE
      )
    }
  }

  if (length(rasters) > 1 && geometry_strategy == "extend_to_union") {
    rasters <- extend_rasters_to_union(rasters, fill_value = geometry_fill_value)
  }

  stack <- terra::rast(rasters)
  names(stack) <- make.names(selected$species_name, unique = TRUE)
  if (length(internal_na_fill_value) == 1 && !is.na(internal_na_fill_value)) {
    stack <- terra::ifel(is.na(stack), internal_na_fill_value, stack)
  }
  stack
}

binary_stack <- function(stack, raster_mode, manual_threshold, model_thresholds = NULL) {
  raster_mode <- match.arg(raster_mode, raster_modes())
  if (raster_mode == "manual_binary") {
    return(stack >= manual_threshold)
  }

  if (raster_mode == "model_threshold_binary") {
    if (is.null(model_thresholds) || length(model_thresholds) != terra::nlyr(stack)) {
      stop("Model-threshold binary mode requires one threshold per raster layer.", call. = FALSE)
    }
    out <- terra::rast(lapply(seq_len(terra::nlyr(stack)), function(idx) {
      stack[[idx]] >= model_thresholds[[idx]]
    }))
    names(out) <- names(stack)
    return(out)
  }

  if (raster_mode == "tss_clipped") {
    return(stack > 0.1)
  }

  stop("Binary stack requested for unsupported raster mode: ", raster_mode, call. = FALSE)
}

aggregate_stack <- function(stack, raster_mode, manual_threshold, aggregation_mode, model_thresholds = NULL) {
  aggregation_mode <- match.arg(
    aggregation_mode,
    c("mean_continuous", "max_continuous", "binary_richness", "any_binary")
  )

  if (aggregation_mode == "mean_continuous") {
    return(terra::app(stack, mean, na.rm = TRUE))
  }

  if (aggregation_mode == "max_continuous") {
    return(terra::app(stack, max, na.rm = TRUE))
  }

  binary <- binary_stack(stack, raster_mode, manual_threshold, model_thresholds)
  if (aggregation_mode == "binary_richness") {
    return(terra::app(binary, sum, na.rm = TRUE))
  }

  terra::app(binary, function(x) as.integer(sum(x, na.rm = TRUE) > 0))
}

preview_raster <- function(raster, max_cells = 250000, fun = c("mean", "max")) {
  fun <- match.arg(fun)
  cell_count <- terra::ncell(raster)
  if (cell_count <= max_cells) {
    return(raster)
  }

  fact <- ceiling(sqrt(cell_count / max_cells))
  aggregate_fun <- if (fun == "max") max else mean
  terra::aggregate(raster, fact = fact, fun = aggregate_fun, na.rm = TRUE)
}

write_preview_png <- function(raster, path, title = "Aggregated SDM", preview_fun = c("mean", "max")) {
  preview_fun <- match.arg(preview_fun)
  if (!requireNamespace("viridisLite", quietly = TRUE)) {
    stop("Package `viridisLite` is required for preview PNG output.", call. = FALSE)
  }

  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  png(filename = path, width = 1600, height = 1000, res = 150)
  on.exit(dev.off(), add = TRUE)
  cols <- viridisLite::viridis(100)
  terra::plot(preview_raster(raster, fun = preview_fun), col = cols, colNA = cols[[1]], main = title)
  invisible(path)
}

write_run_manifest <- function(path, values) {
  manifest <- tibble::as_tibble(values)
  readr::write_csv(manifest, path, na = "")
  manifest
}

make_output_dir <- function(output_root, analysis_unit_ids, aggregation_mode) {
  ids <- normalize_filter(analysis_unit_ids)
  id_token <- if (length(ids) == 1) ids[[1]] else paste0("multi_", length(ids))
  dir_name <- paste(timestamp_file(), safe_path_token(id_token), aggregation_mode, sep = "_")
  output_dir <- file.path(output_root, dir_name)

  suffix <- 1
  while (dir.exists(output_dir)) {
    output_dir <- file.path(output_root, paste0(dir_name, "_", suffix))
    suffix <- suffix + 1
  }

  ensure_dir(output_dir)
}

run_sdm_aggregation <- function(bundle_root = default_ready_sdm_bundle_root(),
                                analysis_unit_ids,
                                species_roles,
                                host_role_buckets = NULL,
                                host_detection_methods = NULL,
                                vector_role_buckets = NULL,
                                evidence_tiers = NULL,
                                sdm_sources = NULL,
                                raster_mode = raster_modes(),
                                manual_threshold = 0.5,
                                model_threshold_method = c("tss_test_mean", "tss_test_median", "tss_maxent_mean", "tss_maxent_median"),
                                aggregation_mode = c("mean_continuous", "max_continuous", "binary_richness", "any_binary"),
                                geometry_strategy = c("strict", "extend_to_union"),
                                geometry_fill_value = 0,
                                internal_na_fill_value = 0,
                                output_root = file.path(bundle_root, "map_outputs")) {
  bundle_root <- normalizePath(bundle_root, winslash = "/", mustWork = TRUE)
  raster_mode <- match.arg(raster_mode)
  model_threshold_method <- match.arg(model_threshold_method)
  aggregation_mode <- match.arg(aggregation_mode)
  geometry_strategy <- match.arg(geometry_strategy)
  manual_threshold <- as.numeric(manual_threshold)
  geometry_fill_value <- as.numeric(geometry_fill_value)
  internal_na_fill_value <- as.numeric(internal_na_fill_value)
  if (length(internal_na_fill_value) == 0) {
    internal_na_fill_value <- NA_real_
  }

  validate_mode_combination(raster_mode, aggregation_mode)

  if (length(manual_threshold) != 1 || is.na(manual_threshold) || manual_threshold < 0 || manual_threshold > 1) {
    stop("`manual_threshold` must be a number between 0 and 1.", call. = FALSE)
  }

  selection <- preview_sdm_selection(
    bundle_root = bundle_root,
    analysis_unit_ids = analysis_unit_ids,
    species_roles = species_roles,
    host_role_buckets = host_role_buckets,
    host_detection_methods = host_detection_methods,
    vector_role_buckets = vector_role_buckets,
    evidence_tiers = evidence_tiers,
    sdm_sources = sdm_sources
  )

  selected <- selection$selected
  excluded <- selection$excluded

  if (nrow(selected) == 0) {
    stop("No SDM-backed species selected after applying filters.", call. = FALSE)
  }

  selected <- resolve_raster_paths(selected, bundle_root, raster_mode)
  model_thresholds <- NULL
  if (raster_mode == "model_threshold_binary") {
    model_thresholds <- model_thresholds_for_selected(selected, model_threshold_method)
    selected$model_threshold_method <- model_threshold_method
    selected$model_threshold_value <- unname(model_thresholds)
  }
  if (length(geometry_fill_value) != 1 || is.na(geometry_fill_value) || !is.finite(geometry_fill_value)) {
    stop("`geometry_fill_value` must be one finite numeric value.", call. = FALSE)
  }
  if (length(internal_na_fill_value) != 1 || (!is.na(internal_na_fill_value) && !is.finite(internal_na_fill_value))) {
    stop("`internal_na_fill_value` must be one numeric value or NA.", call. = FALSE)
  }

  stack <- load_checked_rasters(
    selected,
    geometry_strategy = geometry_strategy,
    geometry_fill_value = geometry_fill_value,
    internal_na_fill_value = internal_na_fill_value
  )
  aggregate <- aggregate_stack(
    stack,
    raster_mode,
    manual_threshold,
    aggregation_mode,
    model_thresholds = model_thresholds
  )
  names(aggregate) <- "aggregate"

  output_dir <- make_output_dir(output_root, analysis_unit_ids, aggregation_mode)
  aggregate_path <- file.path(output_dir, "aggregate.tif")
  preview_path <- file.path(output_dir, "aggregate_preview.png")
  selected_path <- file.path(output_dir, "selected_species.csv")
  excluded_path <- file.path(output_dir, "excluded_species.csv")
  manifest_path <- file.path(output_dir, "run_manifest.csv")

  datatype <- if (aggregation_mode %in% c("binary_richness", "any_binary")) "INT2U" else "FLT4S"
  terra::writeRaster(
    aggregate,
    aggregate_path,
    overwrite = TRUE,
    datatype = datatype,
    gdal = c("COMPRESS=LZW")
  )
  preview_fun <- if (aggregation_mode %in% c("binary_richness", "any_binary")) "max" else "mean"
  write_preview_png(
    aggregate,
    preview_path,
    title = paste("SDM aggregate:", aggregation_mode),
    preview_fun = preview_fun
  )
  readr::write_csv(selected, selected_path, na = "")
  readr::write_csv(excluded, excluded_path, na = "")

  manifest <- write_run_manifest(
    manifest_path,
    list(
      generated_at_utc = timestamp_utc(),
      bundle_root = bundle_root,
      output_dir = output_dir,
      analysis_unit_ids = collapse_unique(analysis_unit_ids),
      readiness_disease_names = collapse_unique(selected$readiness_disease_name),
      species_roles = collapse_unique(species_roles),
      host_role_buckets = collapse_unique(host_role_buckets),
      host_detection_methods = collapse_unique(host_detection_methods),
      vector_role_buckets = collapse_unique(vector_role_buckets),
      evidence_tiers = collapse_unique(evidence_tiers),
      sdm_sources = collapse_unique(sdm_sources),
      raster_mode = raster_mode,
      manual_threshold = manual_threshold,
      model_threshold_method = ifelse(raster_mode == "model_threshold_binary", model_threshold_method, NA_character_),
      model_threshold_values = ifelse(
        raster_mode == "model_threshold_binary",
        paste(paste(names(model_thresholds), round(model_thresholds, 4), sep = "="), collapse = "; "),
        NA_character_
      ),
      aggregation_mode = aggregation_mode,
      geometry_strategy = geometry_strategy,
      geometry_fill_value = geometry_fill_value,
      internal_na_fill_value = internal_na_fill_value,
      selected_species_count = nrow(selected),
      excluded_species_count = nrow(excluded),
      raster_count = terra::nlyr(stack),
      raster_binary_rule = ifelse(
        aggregation_mode %in% c("binary_richness", "any_binary"),
        dplyr::case_when(
          raster_mode == "manual_binary" ~ "ensemble_mean >= manual_threshold",
          raster_mode == "model_threshold_binary" ~ "ensemble_mean >= species model threshold",
          TRUE ~ "ensemble_tss_clipped > 0.1"
        ),
        NA_character_
      ),
      aggregate_tif = aggregate_path,
      aggregate_preview_png = preview_path,
      selected_species_csv = selected_path,
      excluded_species_csv = excluded_path
    )
  )

  list(
    output_dir = output_dir,
    aggregate_path = aggregate_path,
    preview_path = preview_path,
    selected_species_path = selected_path,
    excluded_species_path = excluded_path,
    run_manifest_path = manifest_path,
    selected_species = selected,
    excluded_species = excluded,
    manifest = manifest,
    aggregate = aggregate
  )
}
