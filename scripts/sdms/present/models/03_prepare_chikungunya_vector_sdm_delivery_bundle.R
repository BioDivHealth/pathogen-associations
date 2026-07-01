#!/usr/bin/env Rscript
# -----------------------------------------------------------------------------|
# 03_prepare_chikungunya_vector_sdm_delivery_bundle.R ----
# -----------------------------------------------------------------------------|
# Purpose: Build a reviewed Chikungunya host + vector SDM delivery bundle.
# -----------------------------------------------------------------------------|

suppressPackageStartupMessages({
  if (!requireNamespace("dismo", quietly = TRUE)) stop("Package `dismo` is required.", call. = FALSE)
  if (!requireNamespace("here", quietly = TRUE)) stop("Package `here` is required.", call. = FALSE)
  if (!requireNamespace("raster", quietly = TRUE)) stop("Package `raster` is required.", call. = FALSE)
  if (!requireNamespace("writexl", quietly = TRUE)) stop("Package `writexl` is required.", call. = FALSE)
})

source(file.path(here::here(), "scripts", "sdms", "present", "utils.R"))

sdm_external_root <- Sys.getenv("SDM_EXTERNAL_ROOT", unset = "/Volumes/LaCie/pathogen-sdms")
external_vector_root <- file.path(sdm_external_root, "runs_artur", "vector_sdm_push")

default_config <- list(
  delivery_root = file.path(sdm_external_root, "delivery", "chikungunya_vector_sdm_delivery_20260609"),
  main_batch_summary = file.path(external_vector_root, "model_batch_runs", "20260608T123347Z_pid36613", "model_batch_summary.csv"),
  diagnostic_batch_summary = file.path(external_vector_root, "model_batch_runs", "20260609T110743Z_pid22794", "model_batch_summary.csv"),
  host_model_root = file.path(sdm_external_root, "models"),
  predictor_stack_path = file.path(here::here(), "sdms", "cache", "Resample_rast.tif"),
  readiness_root = file.path(here::here(), "pathogen_association_data", "readiness"),
  make_zip = TRUE,
  make_predictions = TRUE,
  overwrite = FALSE,
  resume = FALSE,
  dry_run = FALSE
)

cfg <- if (exists("delivery_config", inherits = FALSE)) {
  utils::modifyList(default_config, delivery_config)
} else {
  default_config
}

args <- parse_cli_args(commandArgs(trailingOnly = TRUE))
cfg$delivery_root <- get_arg(args, "delivery-root", cfg$delivery_root)
cfg$make_zip <- cfg$make_zip || has_flag(args, "make-zip")
cfg$make_predictions <- cfg$make_predictions && !has_flag(args, "skip-predictions")
cfg$overwrite <- cfg$overwrite || has_flag(args, "overwrite")
cfg$resume <- cfg$resume || has_flag(args, "resume")
cfg$dry_run <- cfg$dry_run || has_flag(args, "dry-run")

diagnostic_species <- c("Opifex fuscus", "Eretmapodites chrysogaster", "Aedes africanus")
production_group <- "production_13"
diagnostic_group <- "diagnostic_3"
host_group <- "host_21"
target_analysis_unit_id <- "master_4"
target_disease_name <- "Chikungunya fever"

row_bind_fill <- function(...) {
  dots <- list(...)
  dots <- dots[vapply(dots, nrow, integer(1)) > 0]
  all_names <- unique(unlist(lapply(dots, names), use.names = FALSE))
  dots <- lapply(dots, function(dat) {
    missing <- setdiff(all_names, names(dat))
    dat[missing] <- NA
    dat[, all_names, drop = FALSE]
  })
  do.call(rbind, dots)
}

copy_file <- function(from, to, overwrite = FALSE, reuse_existing = FALSE) {
  if (!file.exists(from)) stop("Missing source file: ", from, call. = FALSE)
  if (grepl("(^|/)\\._", from) || grepl("/maxent_work(/|$)", from)) {
    stop("Refusing to copy ignored/generated path: ", from, call. = FALSE)
  }
  if (file.exists(to) && reuse_existing) return(normalizePath(to, winslash = "/", mustWork = TRUE))
  if (file.exists(to) && !overwrite) stop("Destination exists: ", to, call. = FALSE)
  dir.create(dirname(to), recursive = TRUE, showWarnings = FALSE)
  ok <- file.copy(from, to, overwrite = overwrite, copy.date = TRUE)
  if (!ok) stop("Failed to copy: ", from, " -> ", to, call. = FALSE)
  normalizePath(to, winslash = "/", mustWork = TRUE)
}

model_sidecar_path <- function(model_path, suffix) {
  out <- sub("__model[.]rds$", paste0("__", suffix), model_path)
  if (identical(out, model_path)) stop("Unexpected model filename: ", model_path, call. = FALSE)
  out
}

safe_dir <- function(species) safe_species_name(species)

relative_to_root <- function(paths, root) {
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  vapply(paths, function(path) {
    if (is.na(path) || !nzchar(path)) return(NA_character_)
    path <- normalizePath(path, winslash = "/", mustWork = FALSE)
    prefix <- paste0(root, "/")
    if (startsWith(path, prefix)) return(sub(prefix, "", path, fixed = TRUE))
    path
  }, character(1))
}

delivery_table <- function(dat, delivery_root) {
  source_path_cols <- c("occurrence_path", "model_log", "model_path")
  bundle_path_cols <- c(
    "copied_model_path",
    "copied_run_summary_path",
    "copied_occurrences_path",
    "prediction_tif_path",
    "prediction_map_path",
    "prediction_occurrence_map_path"
  )

  out <- dat
  for (col in intersect(bundle_path_cols, names(out))) {
    out[[col]] <- relative_to_root(out[[col]], delivery_root)
  }

  out[, setdiff(names(out), source_path_cols), drop = FALSE]
}

read_model_metrics <- function(model_path) {
  obj <- readRDS(model_path)
  if (!"mods" %in% names(obj) || length(obj$mods) == 0) {
    stop("Selected model has no retained `mods`: ", model_path, call. = FALSE)
  }
  if (is.null(obj$variables) || length(obj$variables) == 0) {
    stop("Selected model has no predictor variables: ", model_path, call. = FALSE)
  }

  params <- if ("params" %in% names(obj) && is.data.frame(obj$params)) obj$params else data.frame()
  data.frame(
    retained_models = length(obj$mods),
    predictor_names = paste(obj$variables, collapse = "; "),
    min_boyce = if ("C.Boyce" %in% names(params)) min(params$C.Boyce, na.rm = TRUE) else NA_real_,
    max_boyce = if ("C.Boyce" %in% names(params)) max(params$C.Boyce, na.rm = TRUE) else NA_real_,
    min_test_auc = if ("test.AUC.MAXENT" %in% names(params)) min(params$test.AUC.MAXENT, na.rm = TRUE) else NA_real_,
    max_test_auc = if ("test.AUC.MAXENT" %in% names(params)) max(params$test.AUC.MAXENT, na.rm = TRUE) else NA_real_,
    min_max_tss = if ("TSS.max.TEST" %in% names(params)) min(params$TSS.max.TEST, na.rm = TRUE) else NA_real_,
    max_max_tss = if ("TSS.max.TEST" %in% names(params)) max(params$TSS.max.TEST, na.rm = TRUE) else NA_real_,
    stringsAsFactors = FALSE
  )
}

build_selected_manifest <- function(main_summary_path, diagnostic_summary_path) {
  main <- read.csv(main_summary_path, check.names = FALSE, stringsAsFactors = FALSE)
  diagnostic <- read.csv(diagnostic_summary_path, check.names = FALSE, stringsAsFactors = FALSE)

  production <- main[!main$species_name %in% diagnostic_species, , drop = FALSE]
  diagnostic <- diagnostic[diagnostic$species_name %in% diagnostic_species, , drop = FALSE]
  if (nrow(production) != 13) stop("Expected 13 production rows; found ", nrow(production), call. = FALSE)
  if (nrow(diagnostic) != 3) stop("Expected 3 diagnostic rows; found ", nrow(diagnostic), call. = FALSE)

  production$delivery_group <- production_group
  production$delivery_variant <- "standard_boyce0.5_select10"
  production$model_quality <- "production_candidate"
  production$species_role <- "vector"
  production$sdm_species <- production$species_name

  diagnostic$delivery_group <- diagnostic_group
  diagnostic$delivery_variant <- "relaxed_boyce-1_select25"
  diagnostic$model_quality <- "diagnostic_not_recommended_without_review"
  diagnostic$species_role <- "vector"
  diagnostic$sdm_species <- diagnostic$species_name

  selected <- rbind(production, diagnostic)
  selected <- selected[order(match(selected$species_name, c(main$species_name, diagnostic_species))), , drop = FALSE]
  selected
}

build_host_manifest <- function(readiness_root, host_model_root) {
  sdm_table_path <- file.path(readiness_root, "disease_modelling_pilot_package", "pilot_sdm_species.csv")
  if (!file.exists(sdm_table_path)) stop("Missing SDM species table: ", sdm_table_path, call. = FALSE)

  dat <- read.csv(sdm_table_path, check.names = FALSE, stringsAsFactors = FALSE)
  dat <- filter_target_disease(dat)
  dat <- dat[dat$species_role == "host" & as.logical(dat$sdm_available), , drop = FALSE]
  dat <- dat[nzchar(dat$sdm_species), , drop = FALSE]
  if (nrow(dat) != 21) stop("Expected 21 available Chikungunya host SDMs; found ", nrow(dat), call. = FALSE)

  model_path <- file.path(host_model_root, dat$sdm_species, paste0(dat$sdm_species, ".rds"))
  missing <- model_path[!file.exists(model_path)]
  if (length(missing) > 0) stop("Missing host model files: ", paste(missing, collapse = ", "), call. = FALSE)

  data.frame(
    species_name = dat$species_name,
    manifest_species_name = dat$species_name,
    species_role = "host",
    sdm_species = dat$sdm_species,
    model_path = model_path,
    delivery_group = host_group,
    delivery_variant = "existing_host_sdm",
    model_quality = "existing_host_model",
    model_status = "already_available",
    stringsAsFactors = FALSE
  )
}

relative_prediction_dir <- function(group, species) {
  file.path("predictions", group, safe_dir(species))
}

relative_model_dir <- function(group, species, variant = NULL) {
  parts <- c("models", group, safe_dir(species), variant)
  do.call(file.path, as.list(parts[!is.na(parts) & nzchar(parts)]))
}

copy_selected_model_files <- function(row, delivery_root, overwrite, reuse_existing = FALSE) {
  species <- row$species_name[[1]]
  group <- row$delivery_group[[1]]
  variant <- if (group == diagnostic_group) row$delivery_variant[[1]] else NULL
  dest_dir <- file.path(delivery_root, relative_model_dir(group, species, variant))
  model_src <- row$model_path[[1]]
  model_dest <- copy_file(model_src, file.path(dest_dir, "model.rds"), overwrite = overwrite, reuse_existing = reuse_existing)

  if (identical(row$species_role[[1]], "host")) {
    summary_dest <- file.path(dest_dir, "run_summary.csv")
    if (!file.exists(summary_dest) || overwrite || reuse_existing) {
      summary <- data.frame(
        species_name = species,
        species_role = row$species_role[[1]],
        delivery_group = group,
        delivery_variant = row$delivery_variant[[1]],
        model_quality = row$model_quality[[1]],
        source_model_path = model_src,
        retained_models = row$retained_models[[1]],
        predictor_names = row$predictor_names[[1]],
        min_boyce = row$min_boyce[[1]],
        max_boyce = row$max_boyce[[1]],
        min_test_auc = row$min_test_auc[[1]],
        max_test_auc = row$max_test_auc[[1]],
        min_max_tss = row$min_max_tss[[1]],
        max_max_tss = row$max_max_tss[[1]],
        note = "Generated for delivery from an existing host SDM object; original host occurrence sidecar was not available.",
        stringsAsFactors = FALSE
      )
      write.csv(summary, summary_dest, row.names = FALSE, na = "")
    }
    return(list(
      model = model_dest,
      run_summary = normalizePath(summary_dest, winslash = "/", mustWork = TRUE),
      occurrences = NA_character_
    ))
  }

  summary_src <- model_sidecar_path(model_src, "run_summary.csv")
  occ_src <- model_sidecar_path(model_src, "occurrences_used.csv")

  list(
    model = model_dest,
    run_summary = copy_file(summary_src, file.path(dest_dir, "run_summary.csv"), overwrite = overwrite, reuse_existing = reuse_existing),
    occurrences = copy_file(occ_src, file.path(dest_dir, "occurrences_used.csv"), overwrite = overwrite, reuse_existing = reuse_existing)
  )
}

copy_strict_reference_files <- function(main_summary, delivery_root, overwrite, reuse_existing = FALSE) {
  strict <- main_summary[main_summary$species_name %in% diagnostic_species, , drop = FALSE]
  for (idx in seq_len(nrow(strict))) {
    row <- strict[idx, , drop = FALSE]
    species <- row$species_name[[1]]
    dest_dir <- file.path(delivery_root, relative_model_dir(diagnostic_group, species, "strict_boyce0.5_select10"))
    model_src <- row$model_path[[1]]
    copy_file(model_src, file.path(dest_dir, "model.rds"), overwrite = overwrite, reuse_existing = reuse_existing)
    copy_file(model_sidecar_path(model_src, "run_summary.csv"), file.path(dest_dir, "run_summary.csv"), overwrite = overwrite, reuse_existing = reuse_existing)
    copy_file(model_sidecar_path(model_src, "occurrences_used.csv"), file.path(dest_dir, "occurrences_used.csv"), overwrite = overwrite, reuse_existing = reuse_existing)
  }
}

make_prediction_extent <- function(occ, buffer = 6) {
  xmin <- max(-180, min(occ$decimalLongitude, na.rm = TRUE) - buffer)
  xmax <- min(180, max(occ$decimalLongitude, na.rm = TRUE) + buffer)
  ymin <- max(-90, min(occ$decimalLatitude, na.rm = TRUE) - buffer)
  ymax <- min(90, max(occ$decimalLatitude, na.rm = TRUE) + buffer)
  if ((xmax - xmin) < 12) {
    mid <- mean(c(xmin, xmax))
    xmin <- max(-180, mid - 6)
    xmax <- min(180, mid + 6)
  }
  if ((ymax - ymin) < 12) {
    mid <- mean(c(ymin, ymax))
    ymin <- max(-90, mid - 6)
    ymax <- min(90, mid + 6)
  }
  raster::extent(xmin, xmax, ymin, ymax)
}

prediction_crop <- function(predictors, obj, occ) {
  fallback <- function() {
    if (is.null(occ)) return(predictors)
    raster::crop(predictors, make_prediction_extent(occ))
  }
  cropped <- tryCatch({
    if (is.null(obj$study.area)) return(fallback())
    out <- raster::crop(predictors, raster::extent(obj$study.area))
    if (is.null(out) || raster::ncell(out) == 0 || any(dim(out)[1:2] == 0)) fallback() else out
  }, error = function(e) fallback())
  cropped
}

write_prediction_map <- function(raster_layer, occ, png_path, title, subtitle, with_occurrences = TRUE) {
  dir.create(dirname(png_path), recursive = TRUE, showWarnings = FALSE)
  png(png_path, width = 1800, height = 1350, res = 180)
  on.exit(dev.off(), add = TRUE)
  par(mar = c(4, 4, 4.5, 5), bg = "white")
  raster::plot(raster_layer, col = hcl.colors(100, "YlGnBu"), main = title, xlab = "Longitude", ylab = "Latitude")
  if (requireNamespace("maps", quietly = TRUE)) maps::map("world", add = TRUE, col = "grey35", lwd = 0.6)
  if (with_occurrences && !is.null(occ)) {
    points(occ$decimalLongitude, occ$decimalLatitude, pch = 21, bg = "#ffcc33", col = "black", cex = 0.85, lwd = 0.55)
    legend("bottomleft", legend = paste0("Occurrences used: ", nrow(occ)), pch = 21, pt.bg = "#ffcc33", col = "black", bty = "n")
  }
  mtext(subtitle, side = 3, line = 0.3, cex = 0.68)
}

generate_prediction <- function(row, delivery_root, predictor_stack, overwrite, reuse_existing = FALSE) {
  species <- row$species_name[[1]]
  group <- row$delivery_group[[1]]
  model_path <- row$model_path[[1]]
  pred_dir <- file.path(delivery_root, relative_prediction_dir(group, species))
  out_tif <- file.path(pred_dir, "ensemble_mean.tif")
  out_png <- file.path(pred_dir, "ensemble_mean_map.png")
  has_occurrences <- !identical(row$species_role[[1]], "host")
  out_occ_png <- if (has_occurrences) file.path(pred_dir, "ensemble_mean_with_occurrences.png") else NA_character_

  dir.create(pred_dir, recursive = TRUE, showWarnings = FALSE)
  expected <- c(out_tif, out_png, out_occ_png[!is.na(out_occ_png)])
  if (reuse_existing && all(file.exists(expected))) {
    return(list(
      tif = normalizePath(out_tif, winslash = "/", mustWork = TRUE),
      map = normalizePath(out_png, winslash = "/", mustWork = TRUE),
      occurrence_map = if (is.na(out_occ_png)) NA_character_ else normalizePath(out_occ_png, winslash = "/", mustWork = TRUE)
    ))
  }
  if (reuse_existing) {
    unlink(expected[file.exists(expected)])
  }
  if (!overwrite && !reuse_existing && any(file.exists(expected))) {
    stop("Prediction output exists for ", species, "; use --overwrite.", call. = FALSE)
  }

  obj <- readRDS(model_path)
  occ <- if (has_occurrences) read.csv(model_sidecar_path(model_path, "occurrences_used.csv"), check.names = FALSE, stringsAsFactors = FALSE) else NULL
  predictors <- predictor_stack[[obj$variables]]
  predictors <- prediction_crop(predictors, obj, occ)

  pred_files <- character(length(obj$mods))
  on.exit(unlink(pred_files[file.exists(pred_files)]), add = TRUE)
  for (idx in seq_along(obj$mods)) {
    pred_files[[idx]] <- tempfile(pattern = paste0(safe_dir(species), "_pred_"), fileext = ".tif")
    raster::predict(obj$mods[[idx]], predictors, filename = pred_files[[idx]], overwrite = TRUE)
  }
  ensemble <- if (length(pred_files) == 1) {
    raster::writeRaster(raster::raster(pred_files[[1]]), filename = out_tif, overwrite = TRUE)
  } else {
    raster::calc(raster::stack(pred_files), mean, na.rm = TRUE, filename = out_tif, overwrite = TRUE)
  }
  names(ensemble) <- "suitability"
  params <- obj$params
  subtitle <- sprintf(
    "Ensemble mean | retained %d models | Boyce %.3f to %.3f | test AUC %.3f to %.3f | maxTSS %.3f to %.3f",
    length(obj$mods),
    min(params$C.Boyce, na.rm = TRUE),
    max(params$C.Boyce, na.rm = TRUE),
    min(params$test.AUC.MAXENT, na.rm = TRUE),
    max(params$test.AUC.MAXENT, na.rm = TRUE),
    min(params$TSS.max.TEST, na.rm = TRUE),
    max(params$TSS.max.TEST, na.rm = TRUE)
  )
  write_prediction_map(ensemble, occ, out_png, species, subtitle, with_occurrences = FALSE)
  if (!is.na(out_occ_png)) write_prediction_map(ensemble, occ, out_occ_png, species, subtitle, with_occurrences = TRUE)

  list(
    tif = normalizePath(out_tif, winslash = "/", mustWork = TRUE),
    map = normalizePath(out_png, winslash = "/", mustWork = TRUE),
    occurrence_map = if (is.na(out_occ_png)) NA_character_ else normalizePath(out_occ_png, winslash = "/", mustWork = TRUE)
  )
}

existing_prediction_files <- function(row, delivery_root) {
  species <- row$species_name[[1]]
  group <- row$delivery_group[[1]]
  pred_dir <- file.path(delivery_root, relative_prediction_dir(group, species))
  out_tif <- file.path(pred_dir, "ensemble_mean.tif")
  out_png <- file.path(pred_dir, "ensemble_mean_map.png")
  out_occ_png <- file.path(pred_dir, "ensemble_mean_with_occurrences.png")

  normalize_existing <- function(path) {
    if (file.exists(path)) normalizePath(path, winslash = "/", mustWork = TRUE) else NA_character_
  }

  list(
    tif = normalize_existing(out_tif),
    map = normalize_existing(out_png),
    occurrence_map = if (identical(row$species_role[[1]], "host")) NA_character_ else normalize_existing(out_occ_png)
  )
}

normalize_species_key <- function(x) {
  tolower(gsub("[[:space:]_]+", " ", trimws(x)))
}

format_scientific_name <- function(x) {
  vapply(x, function(value) {
    if (is.na(value) || !nzchar(trimws(value))) return(NA_character_)
    words <- strsplit(tolower(trimws(value)), "[[:space:]]+")[[1]]
    words[[1]] <- paste0(toupper(substr(words[[1]], 1, 1)), substr(words[[1]], 2, nchar(words[[1]])))
    paste(words, collapse = " ")
  }, character(1), USE.NAMES = FALSE)
}

first_non_empty_value <- function(x) {
  x <- trimws(as.character(x))
  x <- x[!is.na(x) & nzchar(x)]
  if (length(x) == 0) return(NA_character_)
  x[[1]]
}

host_taxonomy_lookup <- function() {
  path <- file.path(
    here::here(),
    "pathogen_association_data",
    "source_data",
    "virion",
    "raw",
    "virion_download",
    "19502921",
    "taxonomy_host.csv"
  )
  if (!file.exists(path)) return(data.frame())

  dat <- read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
  required <- c("HostTaxID", "HostClass", "HostOrder", "HostFamily")
  if (!all(required %in% names(dat))) return(data.frame())

  dat$HostTaxID <- trimws(as.character(dat$HostTaxID))
  dat <- dat[!is.na(dat$HostTaxID) & nzchar(dat$HostTaxID), required, drop = FALSE]
  if (nrow(dat) == 0) return(data.frame())

  rows <- lapply(split(dat, dat$HostTaxID), function(x) {
    data.frame(
      tax_id = x$HostTaxID[[1]],
      host_class_lookup = tolower(first_non_empty_value(x$HostClass)),
      host_order_lookup = tolower(first_non_empty_value(x$HostOrder)),
      host_family_lookup = tolower(first_non_empty_value(x$HostFamily)),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

standardize_readiness_taxonomy <- function(dat) {
  for (col in intersect(c("species_name", "sdm_species"), names(dat))) {
    fill <- !is.na(dat[[col]]) & nzchar(trimws(dat[[col]]))
    dat[[col]][fill] <- format_scientific_name(dat[[col]][fill])
  }

  if (!all(c("tax_id", "host_class", "host_order", "host_family") %in% names(dat))) {
    return(dat)
  }

  lookup <- host_taxonomy_lookup()
  if (nrow(lookup) == 0) return(dat)

  dat$tax_id <- trimws(as.character(dat$tax_id))
  matched <- match(dat$tax_id, lookup$tax_id)
  for (col in c("host_class", "host_order", "host_family")) {
    lookup_col <- paste0(col, "_lookup")
    empty <- is.na(dat[[col]]) | !nzchar(trimws(dat[[col]]))
    dat[[col]][empty] <- lookup[[lookup_col]][matched[empty]]
  }
  dat
}

target_disease_rows <- function(dat) {
  checks <- list()
  if ("analysis_unit_id" %in% names(dat)) checks[[length(checks) + 1]] <- dat$analysis_unit_id == target_analysis_unit_id
  if ("readiness_disease_name" %in% names(dat)) checks[[length(checks) + 1]] <- dat$readiness_disease_name == target_disease_name
  if ("disease_name" %in% names(dat)) checks[[length(checks) + 1]] <- dat$disease_name == target_disease_name

  if (length(checks) == 0) return(rep(TRUE, nrow(dat)))
  Reduce(`|`, checks)
}

filter_target_disease <- function(dat) {
  dat[target_disease_rows(dat), , drop = FALSE]
}

delivered_species_by_role <- function(delivered_manifest, role) {
  delivered_manifest$species_name[delivered_manifest$species_role == role]
}

mark_delivered_sdms <- function(dat, delivered_manifest) {
  if (!all(c("species_name", "sdm_available") %in% names(dat))) return(dat)

  delivered <- normalize_species_key(delivered_manifest$species_name)
  matched <- normalize_species_key(dat$species_name) %in% delivered
  dat$sdm_available[matched] <- TRUE
  if ("sdm_species" %in% names(dat)) {
    empty_sdm_species <- is.na(dat$sdm_species) | !nzchar(dat$sdm_species)
    dat$sdm_species[matched & empty_sdm_species] <- dat$species_name[matched & empty_sdm_species]
  }
  dat
}

update_delivery_sdm_summary <- function(dat, delivered_manifest) {
  host_n <- length(unique(delivered_species_by_role(delivered_manifest, "host")))
  vector_n <- length(unique(delivered_species_by_role(delivered_manifest, "vector")))
  if ("host_sdm_species_available" %in% names(dat)) dat$host_sdm_species_available <- host_n
  if ("vector_sdm_species_available" %in% names(dat)) dat$vector_sdm_species_available <- vector_n
  if ("sdm_availability_status" %in% names(dat)) dat$sdm_availability_status <- "delivered_host_and_vector_sdms_available_for_review"
  if ("recommended_next_action" %in% names(dat)) dat$recommended_next_action <- "review_delivered_chikungunya_sdm_bundle"
  dat
}

write_filtered_csv <- function(from, to, delivered_manifest) {
  dat <- read.csv(from, check.names = FALSE, stringsAsFactors = FALSE)
  dat <- filter_target_disease(dat)
  dat <- mark_delivered_sdms(dat, delivered_manifest)
  dat <- update_delivery_sdm_summary(dat, delivered_manifest)
  dat <- standardize_readiness_taxonomy(dat)
  dir.create(dirname(to), recursive = TRUE, showWarnings = FALSE)
  write.csv(dat, to, row.names = FALSE, na = "")
  invisible(dat)
}

write_delivery_batch_summary <- function(from, to, delivered_species) {
  dat <- read.csv(from, check.names = FALSE, stringsAsFactors = FALSE)
  delivered <- normalize_species_key(delivered_species)
  matched <- normalize_species_key(dat$species_name) %in% delivered

  if ("sdm_available" %in% names(dat) && !"source_manifest_sdm_available" %in% names(dat)) {
    dat$source_manifest_sdm_available <- dat$sdm_available
  }
  if ("sdm_available" %in% names(dat)) dat$sdm_available[matched] <- TRUE
  dat$delivery_sdm_available <- matched

  dir.create(dirname(to), recursive = TRUE, showWarnings = FALSE)
  write.csv(dat, to, row.names = FALSE, na = "")
  normalizePath(to, winslash = "/", mustWork = TRUE)
}

refresh_package_manifest <- function(package_dir) {
  manifest_path <- file.path(package_dir, "manifest.csv")
  if (!file.exists(manifest_path)) return(invisible(NULL))

  manifest <- read.csv(manifest_path, check.names = FALSE, stringsAsFactors = FALSE)
  for (idx in seq_len(nrow(manifest))) {
    table_path <- file.path(package_dir, manifest$file_name[[idx]])
    if (!file.exists(table_path)) next
    dat <- read.csv(table_path, check.names = FALSE, stringsAsFactors = FALSE)
    manifest$rows[[idx]] <- nrow(dat)
    manifest$columns[[idx]] <- ncol(dat)
  }
  manifest$generated_at_utc <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z", tz = "UTC")
  write.csv(manifest, manifest_path, row.names = FALSE, na = "")
}

write_filtered_workbook <- function(package_dir, workbook_path) {
  sheet_order <- c(
    "manifest",
    "disease_modelling_pilot",
    "pilot_hosts",
    "pilot_vectors",
    "pilot_countries",
    "pilot_sdm_species",
    "pilot_evidence_summary"
  )
  sheets <- list()
  for (sheet in sheet_order) {
    path <- file.path(package_dir, paste0(sheet, ".csv"))
    if (file.exists(path)) sheets[[sheet]] <- read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
  }
  writexl::write_xlsx(sheets, workbook_path)
}

copy_readiness <- function(delivery_root, readiness_root, delivered_manifest, overwrite, reuse_existing = FALSE) {
  dest <- file.path(delivery_root, "readiness")
  top_level_csvs <- c(
    file.path(readiness_root, "disease_modelling_readiness.csv"),
    file.path(readiness_root, "disease_modelling_readiness_full.csv")
  )
  for (path in top_level_csvs) {
    write_filtered_csv(path, file.path(dest, basename(path)), delivered_manifest)
  }

  package_dir <- file.path(readiness_root, "disease_modelling_pilot_package")
  if (!dir.exists(package_dir)) stop("Missing readiness package directory: ", package_dir, call. = FALSE)
  target_dir <- file.path(dest, "disease_modelling_pilot_package")
  if (dir.exists(target_dir) && !overwrite && !reuse_existing) stop("Destination exists: ", target_dir, call. = FALSE)
  dir.create(dirname(target_dir), recursive = TRUE, showWarnings = FALSE)
  if (dir.exists(target_dir)) unlink(target_dir, recursive = TRUE)
  dir.create(target_dir, recursive = TRUE, showWarnings = FALSE)

  package_files <- list.files(package_dir, full.names = TRUE, all.files = TRUE, no.. = TRUE)
  for (path in package_files) {
    to <- file.path(target_dir, basename(path))
    if (dir.exists(path)) {
      ok <- file.copy(path, target_dir, recursive = TRUE, copy.date = TRUE)
    } else if (grepl("[.]csv$", path)) {
      write_filtered_csv(path, to, delivered_manifest)
      ok <- TRUE
    } else {
      ok <- file.copy(path, to, overwrite = TRUE, copy.date = TRUE)
    }
    if (!ok) stop("Failed to copy readiness package file: ", path, call. = FALSE)
  }
  refresh_package_manifest(target_dir)
  write_filtered_workbook(target_dir, file.path(dest, "disease_modelling_pilot_package.xlsx"))
}

write_tables <- function(delivery_root, manifest, qc_rows, overwrite) {
  manifest_path <- file.path(delivery_root, "manifest.csv")
  qc_path <- file.path(delivery_root, "model_qc_summary.csv")
  if (!overwrite && (file.exists(manifest_path) || file.exists(qc_path))) {
    stop("Manifest/QC outputs exist; use --overwrite.", call. = FALSE)
  }
  write.csv(delivery_table(manifest, delivery_root), manifest_path, row.names = FALSE, na = "")
  write.csv(delivery_table(qc_rows, delivery_root), qc_path, row.names = FALSE, na = "")

  parameter_dir <- file.path(delivery_root, "parameter_tables")
  dir.create(parameter_dir, recursive = TRUE, showWarnings = FALSE)
  for (idx in seq_len(nrow(manifest))) {
    row <- manifest[idx, , drop = FALSE]
    obj <- readRDS(row$model_path[[1]])
    params_path <- file.path(parameter_dir, paste0(safe_dir(row$species_name[[1]]), "__", row$delivery_group[[1]], "__params.csv"))
    aicc_path <- file.path(parameter_dir, paste0(safe_dir(row$species_name[[1]]), "__", row$delivery_group[[1]], "__aicc.csv"))
    write.csv(obj$params, params_path, row.names = FALSE, na = "")
    write.csv(obj$AICc, aicc_path, row.names = FALSE, na = "")
  }
}

write_readme <- function(delivery_root, qc_rows, overwrite, make_predictions) {
  readme_path <- file.path(delivery_root, "README.md")
  if (file.exists(readme_path) && !overwrite) stop("README exists; use --overwrite.", call. = FALSE)
  production_n <- sum(qc_rows$delivery_group == production_group)
  diagnostic_n <- sum(qc_rows$delivery_group == diagnostic_group)
  host_n <- sum(qc_rows$delivery_group == host_group)
  lines <- c(
    "# Chikungunya Host + Vector SDM Delivery Bundle",
    "",
    "This bundle contains present-day Chikungunya SDMs for delivered host and vector species.",
    "Vector SDMs were fitted with AutoMaxent from combined GBIF + VectorMap + MapVEu occurrence records.",
    "Host SDMs are existing saved host model objects from the shared SDM model archive.",
    "",
    "## Scope",
    "",
    paste0("- Existing host SDMs: ", host_n),
    paste0("- Vector production candidate models: ", production_n),
    paste0("- Vector diagnostic/problem models: ", diagnostic_n),
    "- Vector occurrence records were filtered to 2000-2026 before model fitting.",
    "- Host model objects preserve selected model parameters and study areas, but the original host occurrence sidecar files are not available in this delivery bundle.",
    "- Vector IUCN ranges were unavailable, so vector models use complete predictor records without IUCN range filtering.",
    "",
    "## Vector Model Settings",
    "",
    "Production candidate settings:",
    "- `random_features = TRUE`",
    "- `n_models = 25`",
    "- `n_selected_models = 10`",
    "- `use_boyce = 0.5`",
    "- dynamic background with `BwData`",
    "",
    "Diagnostic settings for `Opifex fuscus`, `Eretmapodites chrysogaster`, and `Aedes africanus`:",
    "- `random_features = TRUE`",
    "- `n_models = 25`",
    "- `n_selected_models = 25`",
    "- `use_boyce = -1`",
    "- These diagnostic species are not recommended as clean production models without manual review.",
    "",
    "## Contents",
    "",
    "- `manifest.csv`: selected delivery models and bundle-relative copied output paths.",
    "- `model_qc_summary.csv`: retained model counts, AUC, Boyce, maxTSS, and record counts.",
    "- `models/`: copied `.rds` files, run summaries, and vector model-facing occurrence records where available.",
    if (make_predictions) {
      "- `predictions/`: present-day ensemble mean suitability rasters and maps."
    } else {
      "- `predictions/`: already-generated prediction assets only; this packaging run used `--skip-predictions`."
    },
    "- `parameter_tables/`: selected-model parameter and AICc tables extracted from the saved RDS objects.",
    "- `readiness/`: disease modelling readiness files and pilot package tables filtered to Chikungunya fever.",
    "- `batch_logs/`: source batch summaries for the main and diagnostic runs.",
    "- `explore_chikungunya_vector_sdm_bundle.R`: helper functions for reading readiness tables and accessing delivered models.",
    "- `explore_chikungunya_vector_sdm_bundle.Rmd`: Shiny-backed interactive notebook for summaries, filters, maps, and example raster access.",
    "- `chikungunya_sdm_bundle_summary.Rmd`: static summary report for sharing/review without Shiny controls.",
    "",
    "## Notes",
    "",
    if (make_predictions) {
      "The prediction rasters were recomputed from the retained MaxEnt models and the present predictor stack, rather than reusing saved `avr.preds` objects from RDS files."
    } else {
      "Prediction generation was skipped for this packaging run. Existing prediction paths are listed in `manifest.csv`; missing prediction paths can be filled by rerunning this script without `--skip-predictions`."
    },
    "Readiness tables in this bundle are delivery-scoped: the 21 existing host SDMs and 16 delivered vector SDMs are marked available, while low-data Chikungunya vectors without delivered models remain unavailable."
  )
  writeLines(lines, readme_path)
}

write_explorer_script <- function(delivery_root, overwrite) {
  script_path <- file.path(delivery_root, "explore_chikungunya_vector_sdm_bundle.R")
  notebook_path <- file.path(delivery_root, "explore_chikungunya_vector_sdm_bundle.Rmd")
  static_report_path <- file.path(delivery_root, "chikungunya_sdm_bundle_summary.Rmd")
  if (file.exists(script_path) && !overwrite) stop("Explorer script exists; use --overwrite.", call. = FALSE)
  if (file.exists(notebook_path) && !overwrite) stop("Explorer notebook exists; use --overwrite.", call. = FALSE)
  if (file.exists(static_report_path) && !overwrite) stop("Static report exists; use --overwrite.", call. = FALSE)

  template_path <- file.path(here::here(), "scripts", "sdms", "present", "models", "explore_chikungunya_vector_sdm_bundle.R")
  notebook_template_path <- file.path(here::here(), "scripts", "sdms", "present", "models", "explore_chikungunya_vector_sdm_bundle.Rmd")
  static_report_template_path <- file.path(here::here(), "scripts", "sdms", "present", "models", "chikungunya_sdm_bundle_summary.Rmd")
  if (!file.exists(template_path)) stop("Missing explorer template: ", template_path, call. = FALSE)
  if (!file.exists(notebook_template_path)) stop("Missing explorer notebook template: ", notebook_template_path, call. = FALSE)
  if (!file.exists(static_report_template_path)) stop("Missing static report template: ", static_report_template_path, call. = FALSE)

  ok <- file.copy(template_path, script_path, overwrite = overwrite, copy.date = FALSE)
  if (!ok) stop("Failed to write explorer script: ", script_path, call. = FALSE)
  ok <- file.copy(notebook_template_path, notebook_path, overwrite = overwrite, copy.date = FALSE)
  if (!ok) stop("Failed to write explorer notebook: ", notebook_path, call. = FALSE)
  ok <- file.copy(static_report_template_path, static_report_path, overwrite = overwrite, copy.date = FALSE)
  if (!ok) stop("Failed to write static report: ", static_report_path, call. = FALSE)
  normalizePath(script_path, winslash = "/", mustWork = TRUE)
}

create_zip <- function(delivery_root, overwrite) {
  zip_path <- paste0(delivery_root, ".zip")
  if (file.exists(zip_path)) {
    if (!overwrite) stop("ZIP exists: ", zip_path, call. = FALSE)
    unlink(zip_path)
  }
  old <- setwd(dirname(delivery_root))
  on.exit(setwd(old), add = TRUE)
  utils::zip(zipfile = zip_path, files = basename(delivery_root), flags = "-r -X")
  if (!file.exists(zip_path)) stop("Failed to create ZIP: ", zip_path, call. = FALSE)
  normalizePath(zip_path, winslash = "/", mustWork = TRUE)
}

clean_appledouble <- function(delivery_root) {
  junk <- list.files(delivery_root, pattern = "^\\._", recursive = TRUE, full.names = TRUE, all.files = TRUE, no.. = TRUE)
  if (length(junk) > 0) unlink(junk, recursive = TRUE, force = TRUE)
  length(junk)
}

clean_local_history <- function(delivery_root) {
  junk <- file.path(delivery_root, ".Rhistory")
  if (file.exists(junk)) unlink(junk, force = TRUE)
  !file.exists(junk)
}

clean_rendered_notebook_html <- function(delivery_root) {
  junk <- file.path(delivery_root, c(
    "explore_chikungunya_vector_sdm_bundle.html",
    "chikungunya_sdm_bundle_summary.html"
  ))
  existing <- junk[file.exists(junk)]
  if (length(existing) > 0) unlink(existing, force = TRUE)
  all(!file.exists(junk))
}

clean_empty_host_prediction_dirs <- function(delivery_root) {
  host_pred_root <- file.path(delivery_root, "predictions", host_group)
  if (!dir.exists(host_pred_root)) return(0L)

  removed <- 0L
  repeat {
    dirs <- rev(list.dirs(host_pred_root, recursive = TRUE, full.names = TRUE))
    empty <- dirs[vapply(dirs, function(path) {
      length(list.files(path, all.files = TRUE, no.. = TRUE)) == 0
    }, logical(1))]
    if (length(empty) == 0) break
    unlink(empty, recursive = TRUE, force = TRUE)
    removed_now <- sum(!dir.exists(empty))
    removed <- removed + removed_now
    if (removed_now == 0) break
    if (!dir.exists(host_pred_root)) break
  }
  removed
}

validate_bundle <- function(delivery_root, manifest, make_zip) {
  path_cols <- c(
    "copied_model_path",
    "copied_run_summary_path",
    "copied_occurrences_path",
    "prediction_tif_path",
    "prediction_map_path",
    "prediction_occurrence_map_path"
  )
  copied <- manifest[, intersect(path_cols, names(manifest)), drop = FALSE]
  copied_paths <- unlist(copied, use.names = FALSE)
  copied_paths <- copied_paths[!is.na(copied_paths) & nzchar(copied_paths)]
  missing <- copied_paths[!file.exists(copied_paths)]
  if (length(missing) > 0) stop("Bundle validation found missing files: ", paste(missing, collapse = ", "), call. = FALSE)
  bad <- copied_paths[grepl("(^|/)\\._", copied_paths) | grepl("/maxent_work(/|$)", copied_paths)]
  if (length(bad) > 0) stop("Bundle validation found ignored paths: ", paste(bad, collapse = ", "), call. = FALSE)
  all_files <- list.files(delivery_root, recursive = TRUE, full.names = TRUE, all.files = TRUE, no.. = TRUE)
  bad_all <- all_files[
    grepl("(^|/)\\._", all_files) |
    grepl("/maxent_work(/|$)", all_files) |
    grepl("(^|/)[.]Rhistory$", all_files) |
    grepl("(^|/)explore_chikungunya_vector_sdm_bundle[.]html$", all_files) |
    grepl("(^|/)chikungunya_sdm_bundle_summary[.]html$", all_files)
  ]
  if (length(bad_all) > 0) stop("Bundle validation found ignored files in bundle tree: ", paste(bad_all, collapse = ", "), call. = FALSE)
  if (!file.exists(file.path(delivery_root, "readiness", "disease_modelling_readiness.csv"))) {
    stop("Readiness files were not copied.", call. = FALSE)
  }
  if (!file.exists(file.path(delivery_root, "explore_chikungunya_vector_sdm_bundle.R"))) {
    stop("Explorer script was not written.", call. = FALSE)
  }
  if (!file.exists(file.path(delivery_root, "explore_chikungunya_vector_sdm_bundle.Rmd"))) {
    stop("Explorer notebook was not written.", call. = FALSE)
  }
  if (!file.exists(file.path(delivery_root, "chikungunya_sdm_bundle_summary.Rmd"))) {
    stop("Static report was not written.", call. = FALSE)
  }
  readiness_csvs <- list.files(file.path(delivery_root, "readiness"), pattern = "[.]csv$", recursive = TRUE, full.names = TRUE)
  for (path in readiness_csvs) {
    dat <- read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
    if (length(target_disease_rows(dat)) > 0 && !all(target_disease_rows(dat))) {
      stop("Readiness table is not filtered to Chikungunya: ", path, call. = FALSE)
    }
  }
  pilot_sdm_species <- file.path(delivery_root, "readiness", "disease_modelling_pilot_package", "pilot_sdm_species.csv")
  if (file.exists(pilot_sdm_species)) {
    dat <- read.csv(pilot_sdm_species, check.names = FALSE, stringsAsFactors = FALSE)
    delivered <- normalize_species_key(manifest$species_name)
    delivered_rows <- normalize_species_key(dat$species_name) %in% delivered
    if (any(delivered_rows & !as.logical(dat$sdm_available))) {
      stop("Delivered SDMs are not marked available in pilot_sdm_species.csv.", call. = FALSE)
    }
  }
  if (make_zip && !file.exists(paste0(delivery_root, ".zip"))) stop("ZIP was not created.", call. = FALSE)
  TRUE
}

vector_selected <- build_selected_manifest(cfg$main_batch_summary, cfg$diagnostic_batch_summary)
host_selected <- build_host_manifest(cfg$readiness_root, cfg$host_model_root)
selected <- row_bind_fill(vector_selected, host_selected)
metrics <- do.call(rbind, lapply(selected$model_path, read_model_metrics))
selected <- cbind(selected, metrics)

cat("Selected delivery models:", nrow(selected), "\n")
cat("Host rows:", sum(selected$delivery_group == host_group), "\n")
cat("Production rows:", sum(selected$delivery_group == production_group), "\n")
cat("Diagnostic rows:", sum(selected$delivery_group == diagnostic_group), "\n")
cat("Delivery root:", cfg$delivery_root, "\n")
cat("Make predictions:", cfg$make_predictions, "\n")
cat("Dry run:", cfg$dry_run, "\n")

if (cfg$dry_run) {
  print(selected[, c("species_name", "species_role", "delivery_group", "delivery_variant", "retained_models", "min_boyce", "max_boyce", "model_path")], row.names = FALSE)
  quit(save = "no")
}

if (cfg$overwrite && cfg$resume) stop("Use only one of --overwrite or --resume.", call. = FALSE)

if (dir.exists(cfg$delivery_root)) {
  if (!cfg$overwrite && !cfg$resume) stop("Delivery root exists; use --overwrite or --resume: ", cfg$delivery_root, call. = FALSE)
  if (cfg$overwrite) unlink(cfg$delivery_root, recursive = TRUE)
}
if (!dir.exists(cfg$delivery_root)) dir.create(cfg$delivery_root, recursive = TRUE, showWarnings = FALSE)
cfg$delivery_root <- normalizePath(cfg$delivery_root, winslash = "/", mustWork = TRUE)

main_summary <- read.csv(cfg$main_batch_summary, check.names = FALSE, stringsAsFactors = FALSE)
write_delivery_batch_summary(cfg$main_batch_summary, file.path(cfg$delivery_root, "batch_logs", "main_16_species_model_batch_summary.csv"), vector_selected$species_name)
write_delivery_batch_summary(cfg$diagnostic_batch_summary, file.path(cfg$delivery_root, "batch_logs", "diagnostic_3_species_model_batch_summary.csv"), vector_selected$species_name)

copied <- lapply(seq_len(nrow(selected)), function(idx) copy_selected_model_files(selected[idx, , drop = FALSE], cfg$delivery_root, cfg$overwrite, reuse_existing = cfg$resume))
copy_strict_reference_files(main_summary, cfg$delivery_root, cfg$overwrite, reuse_existing = cfg$resume)
copy_readiness(cfg$delivery_root, cfg$readiness_root, selected[, c("species_name", "species_role"), drop = FALSE], cfg$overwrite, reuse_existing = cfg$resume)

if (cfg$make_predictions) {
  predictor_stack <- raster::stack(cfg$predictor_stack_path)
  predictions <- lapply(seq_len(nrow(selected)), function(idx) {
    cat("[", idx, "/", nrow(selected), "] Predicting ", selected$species_name[[idx]], "\n", sep = "")
    generate_prediction(selected[idx, , drop = FALSE], cfg$delivery_root, predictor_stack, cfg$overwrite, reuse_existing = cfg$resume)
  })
} else {
  cat("Skipping prediction generation; preserving existing prediction paths where present.\n")
  predictions <- lapply(seq_len(nrow(selected)), function(idx) {
    existing_prediction_files(selected[idx, , drop = FALSE], cfg$delivery_root)
  })
}

selected$copied_model_path <- vapply(copied, function(x) x$model, character(1))
selected$copied_run_summary_path <- vapply(copied, function(x) x$run_summary, character(1))
selected$copied_occurrences_path <- vapply(copied, function(x) x$occurrences, character(1))
selected$prediction_tif_path <- vapply(predictions, function(x) x$tif, character(1))
selected$prediction_map_path <- vapply(predictions, function(x) x$map, character(1))
selected$prediction_occurrence_map_path <- vapply(predictions, function(x) x$occurrence_map, character(1))

write_tables(cfg$delivery_root, selected, selected, cfg$overwrite || cfg$resume)
write_readme(cfg$delivery_root, selected, cfg$overwrite || cfg$resume, cfg$make_predictions)
write_explorer_script(cfg$delivery_root, cfg$overwrite || cfg$resume)
cleaned_notebook_html <- clean_rendered_notebook_html(cfg$delivery_root)
cat("Removed rendered notebook HTML:", cleaned_notebook_html, "\n")
removed_appledouble <- clean_appledouble(cfg$delivery_root)
cat("Removed AppleDouble files:", removed_appledouble, "\n")
cleaned_history <- clean_local_history(cfg$delivery_root)
cat("Removed local R history:", cleaned_history, "\n")
if (!cfg$make_predictions) {
  removed_empty_host_prediction_dirs <- clean_empty_host_prediction_dirs(cfg$delivery_root)
  cat("Removed empty host prediction directories:", removed_empty_host_prediction_dirs, "\n")
}

zip_path <- NA_character_
if (cfg$make_zip) {
  zip_path <- create_zip(cfg$delivery_root, cfg$overwrite || cfg$resume)
  removed_appledouble_after_zip <- clean_appledouble(cfg$delivery_root)
  cat("Removed AppleDouble files after ZIP:", removed_appledouble_after_zip, "\n")
}

validate_bundle(cfg$delivery_root, selected, cfg$make_zip)

cat("Delivery bundle written:", cfg$delivery_root, "\n")
if (!is.na(zip_path)) cat("ZIP written:", zip_path, "\n")
