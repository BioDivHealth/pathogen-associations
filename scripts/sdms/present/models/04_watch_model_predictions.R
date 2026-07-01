#!/usr/bin/env Rscript
# -----------------------------------------------------------------------------|
# 04_watch_model_predictions.R ----
# -----------------------------------------------------------------------------|
# Purpose: Watch a model-output folder and write present-day prediction rasters
#          as soon as completed SDM model RDS files appear.
# -----------------------------------------------------------------------------|

suppressPackageStartupMessages({
  if (!requireNamespace("here", quietly = TRUE)) {
    stop("Package `here` is required.", call. = FALSE)
  }
})

source(file.path(here::here(), "scripts", "sdms", "present", "utils.R"))

defaults <- list(
  model_output_root = file.path(here::here(), "outputs", "models", "vector_sdm_push"),
  prediction_root = file.path(here::here(), "outputs", "predictions", "vector_sdm_push"),
  predictor_stack_path = file.path(here::here(), "sdms", "cache", "Resample_rast.tif"),
  outputs = "ensemble_mean,tss_clipped",
  species_filter = character(),
  max_species = Inf,
  poll_seconds = 300,
  max_hours = 72,
  stable_seconds = 120,
  overwrite_predictions = FALSE,
  make_maps = TRUE,
  occurrence_maps = TRUE,
  once = FALSE
)

if (!exists("batch_config", inherits = FALSE)) {
  batch_config <- list()
}

cfg <- utils::modifyList(defaults, batch_config)
args <- parse_cli_args(commandArgs(trailingOnly = TRUE))
get_cfg <- function(key, field = gsub("-", "_", key)) get_arg(args, key, cfg[[field]])

cfg$model_output_root <- get_cfg("model-output-root")
cfg$prediction_root <- get_cfg("prediction-root")
cfg$predictor_stack_path <- get_cfg("predictor-stack-path")
cfg$outputs <- split_arg(get_cfg("outputs"))
cfg$species_filter <- safe_species_name(split_arg(get_cfg("species-filter")))
cfg$max_species <- as.numeric(get_cfg("max-species"))
cfg$poll_seconds <- as.numeric(get_cfg("poll-seconds"))
cfg$max_hours <- as.numeric(get_cfg("max-hours"))
cfg$stable_seconds <- as.numeric(get_cfg("stable-seconds"))
cfg$overwrite_predictions <- as_logical_arg(get_cfg("overwrite-predictions"))
cfg$make_maps <- as_logical_arg(get_cfg("make-maps"))
cfg$occurrence_maps <- as_logical_arg(get_cfg("occurrence-maps"))
cfg$once <- as_logical_arg(get_cfg("once")) || has_flag(args, "once")

valid_outputs <- c("ensemble_mean", "tss_clipped", "top_model")
if (length(cfg$outputs) == 0) {
  cfg$outputs <- "ensemble_mean"
}
bad_outputs <- setdiff(cfg$outputs, valid_outputs)
if (length(bad_outputs) > 0) {
  stop("Unsupported outputs: ", paste(bad_outputs, collapse = ", "), call. = FALSE)
}

if (!dir.exists(cfg$model_output_root)) {
  stop("Missing model output root: ", cfg$model_output_root, call. = FALSE)
}
if (!file.exists(cfg$predictor_stack_path)) {
  stop("Missing predictor stack: ", cfg$predictor_stack_path, call. = FALSE)
}
if (!requireNamespace("raster", quietly = TRUE)) {
  stop("Package `raster` is required.", call. = FALSE)
}
if (!requireNamespace("dismo", quietly = TRUE)) {
  stop("Package `dismo` is required.", call. = FALSE)
}
library(dismo)

cfg$model_output_root <- normalizePath(cfg$model_output_root, winslash = "/", mustWork = TRUE)
cfg$prediction_root <- ensure_dir(cfg$prediction_root)
cfg$predictor_stack_path <- normalizePath(cfg$predictor_stack_path, winslash = "/", mustWork = TRUE)

model_sidecar_path <- function(model_path, suffix) {
  sub("__model[.]rds$", paste0("__", suffix), model_path)
}

model_species_safe <- function(model_path) {
  basename(dirname(model_path))
}

model_species_name <- function(model_path, obj = NULL) {
  if (!is.null(obj) && !is.null(obj$Species) && length(obj$Species) > 0 && !is.na(obj$Species[[1]])) {
    return(as.character(obj$Species[[1]]))
  }

  summary_path <- model_sidecar_path(model_path, "run_summary.csv")
  if (file.exists(summary_path)) {
    summary <- tryCatch(read.csv(summary_path, check.names = FALSE, stringsAsFactors = FALSE), error = function(e) NULL)
    if (!is.null(summary) && "species_name" %in% names(summary) && nrow(summary) > 0) {
      return(as.character(summary$species_name[[1]]))
    }
  }

  gsub("_", " ", model_species_safe(model_path), fixed = TRUE)
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
    if (is.null(occ) || nrow(occ) == 0) {
      return(predictors)
    }
    raster::crop(predictors, make_prediction_extent(occ))
  }

  tryCatch({
    if (is.null(obj$study.area)) {
      return(fallback())
    }
    out <- raster::crop(predictors, raster::extent(obj$study.area))
    if (is.null(out) || raster::ncell(out) == 0 || any(dim(out)[1:2] == 0)) fallback() else out
  }, error = function(e) fallback())
}

read_occurrences <- function(model_path) {
  occ_path <- model_sidecar_path(model_path, "occurrences_used.csv")
  if (!file.exists(occ_path)) {
    return(NULL)
  }

  occ <- read.csv(occ_path, check.names = FALSE, stringsAsFactors = FALSE)
  needed <- c("decimalLongitude", "decimalLatitude")
  if (!all(needed %in% names(occ))) {
    return(NULL)
  }

  occ
}

predict_maxent <- function(model, predictors, filename, ...) {
  methods::selectMethod("predict", "MaxEnt")(model, predictors, filename = filename, ...)
}

pick_top_model_id <- function(obj) {
  ids <- names(obj$mods)
  if (is.null(ids) || length(ids) == 0) {
    return(1L)
  }

  aicc <- obj$AICc
  if (is.data.frame(aicc) && nrow(aicc) > 0) {
    id_col <- intersect(c("mod", "model.id", "model_id"), names(aicc))
    if (length(id_col) > 0) {
      if ("AICc" %in% names(aicc)) {
        aicc <- aicc[order(aicc$AICc), , drop = FALSE]
      }
      top_id <- as.character(aicc[[id_col[[1]]]][[1]])
      if (top_id %in% ids) {
        return(top_id)
      }
    }
  }

  ids[[1]]
}

model_tss_thresholds <- function(obj, species) {
  params <- obj$params
  if (!is.data.frame(params) || !"TSS.threshold.TEST" %in% names(params)) {
    stop("Model parameters do not include TSS.threshold.TEST for ", species, call. = FALSE)
  }

  model_ids <- names(obj$mods)
  if (is.null(model_ids) || any(!nzchar(model_ids))) {
    if ("model.id" %in% names(params) && nrow(params) >= length(obj$mods)) {
      model_ids <- params$model.id[seq_along(obj$mods)]
    } else {
      stop("Cannot match retained models to TSS thresholds for ", species, call. = FALSE)
    }
  }

  if ("model.id" %in% names(params)) {
    matched <- match(model_ids, params$model.id)
    thresholds <- suppressWarnings(as.numeric(params$TSS.threshold.TEST[matched]))
  } else {
    thresholds <- suppressWarnings(as.numeric(params$TSS.threshold.TEST[seq_along(obj$mods)]))
  }

  if (length(thresholds) != length(obj$mods) || any(!is.finite(thresholds))) {
    stop("Missing finite TSS.threshold.TEST values for retained models in ", species, call. = FALSE)
  }

  stats::setNames(thresholds, model_ids)
}

write_tss_clipped_ensemble <- function(pred_files, thresholds, out_tif, species_safe) {
  clipped_files <- character(length(pred_files))
  on.exit(unlink(clipped_files[file.exists(clipped_files)], force = TRUE), add = TRUE)

  for (idx in seq_along(pred_files)) {
    clipped_files[[idx]] <- tempfile(pattern = paste0(species_safe, "_tss_clipped_"), fileext = ".tif")
    threshold <- thresholds[[idx]]
    raster::calc(
      raster::raster(pred_files[[idx]]),
      fun = function(x) ifelse(is.na(x), NA, ifelse(x <= threshold, 0.1, x)),
      filename = clipped_files[[idx]],
      overwrite = TRUE
    )
  }

  out <- if (length(clipped_files) == 1) {
    raster::writeRaster(raster::raster(clipped_files[[1]]), filename = out_tif, overwrite = TRUE)
  } else {
    raster::calc(raster::stack(clipped_files), mean, na.rm = TRUE, filename = out_tif, overwrite = TRUE)
  }
  names(out) <- "tss_clipped_suitability"
  out
}

write_prediction_map <- function(raster_layer, occ, png_path, title, subtitle, with_occurrences = TRUE) {
  dir.create(dirname(png_path), recursive = TRUE, showWarnings = FALSE)
  png(png_path, width = 1800, height = 1350, res = 180)
  on.exit(dev.off(), add = TRUE)

  par(mar = c(4, 4, 4.5, 5), bg = "white")
  raster::plot(
    raster_layer,
    col = hcl.colors(100, "YlGnBu"),
    main = title,
    xlab = "Longitude",
    ylab = "Latitude"
  )

  if (requireNamespace("maps", quietly = TRUE)) {
    maps::map("world", add = TRUE, col = "grey35", lwd = 0.6)
  }

  if (with_occurrences && !is.null(occ)) {
    points(
      occ$decimalLongitude,
      occ$decimalLatitude,
      pch = 21,
      bg = "#ffcc33",
      col = "black",
      cex = 0.85,
      lwd = 0.55
    )
    legend(
      "bottomleft",
      legend = paste0("Occurrences used: ", nrow(occ)),
      pch = 21,
      pt.bg = "#ffcc33",
      col = "black",
      bty = "n"
    )
  }

  mtext(subtitle, side = 3, line = 0.3, cex = 0.68)
}

expected_prediction_files <- function(pred_dir, outputs, make_maps, occurrence_maps) {
  files <- character()
  if ("ensemble_mean" %in% outputs) {
    files <- c(files, file.path(pred_dir, "ensemble_mean.tif"))
    if (make_maps) {
      files <- c(files, file.path(pred_dir, "ensemble_mean_map.png"))
      if (occurrence_maps) files <- c(files, file.path(pred_dir, "ensemble_mean_with_occurrences.png"))
    }
  }
  if ("tss_clipped" %in% outputs) {
    files <- c(files, file.path(pred_dir, "ensemble_tss_clipped.tif"))
    if (make_maps) {
      files <- c(files, file.path(pred_dir, "ensemble_tss_clipped_map.png"))
      if (occurrence_maps) files <- c(files, file.path(pred_dir, "ensemble_tss_clipped_with_occurrences.png"))
    }
  }
  if ("top_model" %in% outputs) {
    files <- c(files, file.path(pred_dir, "top_model.tif"))
    if (make_maps) {
      files <- c(files, file.path(pred_dir, "top_model_map.png"))
      if (occurrence_maps) files <- c(files, file.path(pred_dir, "top_model_with_occurrences.png"))
    }
  }

  files
}

predict_model_file <- function(model_path, predictor_stack) {
  species_safe <- model_species_safe(model_path)
  pred_dir <- ensure_dir(file.path(cfg$prediction_root, species_safe))
  inventory_log <- file.path(pred_dir, "prediction_run_summary.csv")
  lock_path <- file.path(pred_dir, ".predicting.lock")
  expected <- expected_prediction_files(pred_dir, cfg$outputs, cfg$make_maps, cfg$occurrence_maps)

  if (!cfg$overwrite_predictions && length(expected) > 0 && all(file.exists(expected))) {
    return(data.frame(
      species_name = gsub("_", " ", species_safe, fixed = TRUE),
      species_safe = species_safe,
      model_path = model_path,
      prediction_dir = pred_dir,
      status = "skipped_existing_prediction",
      error_message = NA_character_,
      outputs = paste(cfg$outputs, collapse = "; "),
      retained_models = NA_integer_,
      variables = NA_integer_,
      top_model_id = NA_character_,
      ensemble_mean_tif = file.path(pred_dir, "ensemble_mean.tif"),
      tss_clipped_tif = file.path(pred_dir, "ensemble_tss_clipped.tif"),
      top_model_tif = file.path(pred_dir, "top_model.tif"),
      size_mb = round(sum(file.info(expected)$size, na.rm = TRUE) / 1024^2, 2),
      elapsed_minutes = 0,
      predicted_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      stringsAsFactors = FALSE
    ))
  }

  if (file.exists(lock_path)) {
    lock_age <- as.numeric(difftime(Sys.time(), file.info(lock_path)$mtime, units = "hours"))
    if (!is.na(lock_age) && lock_age < 24) {
      return(data.frame(
        species_name = gsub("_", " ", species_safe, fixed = TRUE),
        species_safe = species_safe,
        model_path = model_path,
        prediction_dir = pred_dir,
        status = "skipped_active_lock",
        error_message = NA_character_,
        outputs = paste(cfg$outputs, collapse = "; "),
        retained_models = NA_integer_,
        variables = NA_integer_,
        top_model_id = NA_character_,
        ensemble_mean_tif = file.path(pred_dir, "ensemble_mean.tif"),
        tss_clipped_tif = file.path(pred_dir, "ensemble_tss_clipped.tif"),
        top_model_tif = file.path(pred_dir, "top_model.tif"),
        size_mb = NA_real_,
        elapsed_minutes = 0,
        predicted_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
        stringsAsFactors = FALSE
      ))
    }
    unlink(lock_path, force = TRUE)
  }

  if (!cfg$overwrite_predictions && any(file.exists(expected))) {
    unlink(expected[file.exists(expected)], force = TRUE)
  }
  writeLines(as.character(Sys.getpid()), lock_path)
  on.exit(unlink(lock_path, force = TRUE), add = TRUE)

  started <- Sys.time()
  status <- "completed"
  error_message <- NA_character_
  retained_models <- NA_integer_
  variables <- NA_integer_
  top_model_id <- NA_character_
  temp_files <- character()

  result <- tryCatch({
    obj <- readRDS(model_path)
    species_name <- model_species_name(model_path, obj)
    retained_models <- length(obj$mods)
    variables <- length(obj$variables)
    top_model_id <- as.character(pick_top_model_id(obj))

    if (retained_models == 0 || is.null(obj$mods)) {
      stop("Model object has no retained MaxEnt models.")
    }

    missing_vars <- setdiff(obj$variables, names(predictor_stack))
    if (length(missing_vars) > 0) {
      stop("Predictor stack missing variables: ", paste(missing_vars, collapse = ", "))
    }

    occ <- read_occurrences(model_path)
    predictors <- predictor_stack[[obj$variables]]
    predictors <- prediction_crop(predictors, obj, occ)
    pred_files <- character()
    if (any(c("ensemble_mean", "tss_clipped") %in% cfg$outputs)) {
      pred_files <- character(length(obj$mods))
      for (idx in seq_along(obj$mods)) {
        pred_files[[idx]] <- tempfile(pattern = paste0(species_safe, "_pred_"), fileext = ".tif")
        predict_maxent(obj$mods[[idx]], predictors, filename = pred_files[[idx]], overwrite = TRUE)
      }
      temp_files <- c(temp_files, pred_files)
    }

    params <- obj$params
    metric_summary <- sprintf(
      "retained %d models | Boyce %.3f to %.3f | test AUC %.3f to %.3f | maxTSS %.3f to %.3f",
      length(obj$mods),
      suppressWarnings(min(params$C.Boyce, na.rm = TRUE)),
      suppressWarnings(max(params$C.Boyce, na.rm = TRUE)),
      suppressWarnings(min(params$test.AUC.MAXENT, na.rm = TRUE)),
      suppressWarnings(max(params$test.AUC.MAXENT, na.rm = TRUE)),
      suppressWarnings(min(params$TSS.max.TEST, na.rm = TRUE)),
      suppressWarnings(max(params$TSS.max.TEST, na.rm = TRUE))
    )

    if ("top_model" %in% cfg$outputs) {
      top_tif <- file.path(pred_dir, "top_model.tif")
      top_model_ref <- top_model_id
      if (!top_model_ref %in% names(obj$mods)) {
        top_model_ref <- suppressWarnings(as.integer(top_model_ref))
      }
      top_pred <- predict_maxent(obj$mods[[top_model_ref]], predictors, filename = top_tif, overwrite = TRUE)
      names(top_pred) <- "suitability"
      if (cfg$make_maps) {
        write_prediction_map(
          top_pred,
          occ,
          file.path(pred_dir, "top_model_map.png"),
          species_name,
          paste0("Top AICc model: ", top_model_id, " | ", metric_summary),
          with_occurrences = FALSE
        )
        if (cfg$occurrence_maps) {
          write_prediction_map(
            top_pred,
            occ,
            file.path(pred_dir, "top_model_with_occurrences.png"),
            species_name,
            paste0("Top AICc model: ", top_model_id, " | ", metric_summary),
            with_occurrences = TRUE
          )
        }
      }
    }

    if ("ensemble_mean" %in% cfg$outputs) {
      ensemble_tif <- file.path(pred_dir, "ensemble_mean.tif")
      ensemble <- if (length(pred_files) == 1) {
        raster::writeRaster(raster::raster(pred_files[[1]]), filename = ensemble_tif, overwrite = TRUE)
      } else {
        raster::calc(raster::stack(pred_files), mean, na.rm = TRUE, filename = ensemble_tif, overwrite = TRUE)
      }
      names(ensemble) <- "suitability"

      if (cfg$make_maps) {
        write_prediction_map(
          ensemble,
          occ,
          file.path(pred_dir, "ensemble_mean_map.png"),
          species_name,
          paste0("Ensemble mean | ", metric_summary),
          with_occurrences = FALSE
        )
        if (cfg$occurrence_maps) {
          write_prediction_map(
            ensemble,
            occ,
            file.path(pred_dir, "ensemble_mean_with_occurrences.png"),
            species_name,
            paste0("Ensemble mean | ", metric_summary),
            with_occurrences = TRUE
          )
        }
      }
    }

    if ("tss_clipped" %in% cfg$outputs) {
      thresholds <- model_tss_thresholds(obj, species_name)
      clipped_tif <- file.path(pred_dir, "ensemble_tss_clipped.tif")
      clipped <- write_tss_clipped_ensemble(pred_files, thresholds, clipped_tif, species_safe)
      clipped_summary <- sprintf(
        "TSS-clipped ensemble | below each model threshold set to 0.1 | threshold %.3f to %.3f",
        min(thresholds),
        max(thresholds)
      )

      if (cfg$make_maps) {
        write_prediction_map(
          clipped,
          occ,
          file.path(pred_dir, "ensemble_tss_clipped_map.png"),
          species_name,
          clipped_summary,
          with_occurrences = FALSE
        )
        if (cfg$occurrence_maps) {
          write_prediction_map(
            clipped,
            occ,
            file.path(pred_dir, "ensemble_tss_clipped_with_occurrences.png"),
            species_name,
            clipped_summary,
            with_occurrences = TRUE
          )
        }
      }
    }

    species_name
  }, error = function(e) {
    status <<- "failed"
    error_message <<- conditionMessage(e)
    gsub("_", " ", species_safe, fixed = TRUE)
  })

  unlink(temp_files[file.exists(temp_files)], force = TRUE)
  finished <- Sys.time()
  existing_expected <- expected[file.exists(expected)]

  row_out <- data.frame(
    species_name = as.character(result),
    species_safe = species_safe,
    model_path = model_path,
    prediction_dir = pred_dir,
    status = status,
    error_message = error_message,
    outputs = paste(cfg$outputs, collapse = "; "),
    retained_models = retained_models,
    variables = variables,
    top_model_id = top_model_id,
    ensemble_mean_tif = file.path(pred_dir, "ensemble_mean.tif"),
    tss_clipped_tif = file.path(pred_dir, "ensemble_tss_clipped.tif"),
    top_model_tif = file.path(pred_dir, "top_model.tif"),
    size_mb = if (length(existing_expected) > 0) round(sum(file.info(existing_expected)$size, na.rm = TRUE) / 1024^2, 2) else NA_real_,
    elapsed_minutes = round(as.numeric(difftime(finished, started, units = "mins")), 2),
    predicted_at = format(finished, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    stringsAsFactors = FALSE
  )

  write.csv(row_out, inventory_log, row.names = FALSE, na = "")
  row_out
}

discover_models <- function() {
  model_paths <- list.files(
    cfg$model_output_root,
    pattern = "__model[.]rds$",
    recursive = TRUE,
    full.names = TRUE
  )
  model_paths <- model_paths[file.exists(model_paths)]
  if (length(model_paths) == 0) {
    return(data.frame())
  }

  info <- file.info(model_paths)
  dat <- data.frame(
    model_path = normalizePath(model_paths, winslash = "/", mustWork = TRUE),
    species_safe = vapply(model_paths, model_species_safe, character(1)),
    size = info$size,
    mtime = info$mtime,
    age_seconds = as.numeric(difftime(Sys.time(), info$mtime, units = "secs")),
    stringsAsFactors = FALSE
  )
  dat <- dat[!is.na(dat$size) & dat$size > 0 & dat$age_seconds >= cfg$stable_seconds, , drop = FALSE]

  if (length(cfg$species_filter) > 0) {
    dat <- dat[dat$species_safe %in% cfg$species_filter, , drop = FALSE]
  }

  if (nrow(dat) == 0) {
    return(dat)
  }

  dat <- dat[order(dat$species_safe, -as.numeric(dat$mtime)), , drop = FALSE]
  dat <- dat[!duplicated(dat$species_safe), , drop = FALSE]
  dat <- dat[order(dat$mtime, dat$species_safe), , drop = FALSE]

  if (is.finite(cfg$max_species)) {
    dat <- head(dat, cfg$max_species)
  }

  dat
}

write_inventory <- function(rows) {
  if (length(rows) == 0) {
    return(invisible(NULL))
  }
  inventory <- do.call(rbind, rows)
  inventory_path <- file.path(cfg$prediction_root, "prediction_inventory.csv")
  write.csv(inventory, inventory_path, row.names = FALSE, na = "")
  invisible(inventory_path)
}

cat("Model output root:", cfg$model_output_root, "\n")
cat("Prediction root:", cfg$prediction_root, "\n")
cat("Outputs:", paste(cfg$outputs, collapse = ", "), "\n")
cat("Poll seconds:", cfg$poll_seconds, "\n")
cat("Max hours:", cfg$max_hours, "\n")
cat("Once:", cfg$once, "\n")

predictor_stack <- raster::stack(cfg$predictor_stack_path)
all_rows <- list()
deadline <- if (is.finite(cfg$max_hours) && cfg$max_hours > 0) Sys.time() + cfg$max_hours * 3600 else as.POSIXct(Inf, origin = "1970-01-01")

repeat {
  models <- discover_models()
  cat("[", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), "] eligible models: ", nrow(models), "\n", sep = "")

  if (nrow(models) > 0) {
    for (idx in seq_len(nrow(models))) {
      cat("[", idx, "/", nrow(models), "] predicting ", models$species_safe[[idx]], "\n", sep = "")
      row <- predict_model_file(models$model_path[[idx]], predictor_stack)
      all_rows[[length(all_rows) + 1L]] <- row
      write_inventory(all_rows)
      cat("  ", row$status[[1]], " | ", row$size_mb[[1]], " MB | ", row$elapsed_minutes[[1]], " min\n", sep = "")
    }
  }

  if (cfg$once || Sys.time() >= deadline) {
    break
  }

  Sys.sleep(cfg$poll_seconds)
}

write_inventory(all_rows)
cat("Prediction watcher finished:", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), "\n")
