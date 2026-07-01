#!/usr/bin/env Rscript
# -----------------------------------------------------------------------------|
# gbif_chunked_download_template.R ----
# -----------------------------------------------------------------------------|
# Purpose: Small, resumable GBIF occurrence downloads. The script keeps a CSV
#          ledger, submits only a few async GBIF jobs at once, then fetches
#          completed downloads one at a time so local disk use stays controlled.
# -----------------------------------------------------------------------------|

suppressPackageStartupMessages({
  if (!requireNamespace("rgbif", quietly = TRUE)) {
    stop("Package `rgbif` is required: install.packages('rgbif')", call. = FALSE)
  }
})

# -----------------------------------------------------------------------------|
# 1. Config: edit here, or define `gbif_config` before source() ----
# -----------------------------------------------------------------------------|

default_config <- list(
  species = character(),                   # e.g. c("Aedes aegypti", "Aedes albopictus")
  species_csv = NA_character_,             # optional CSV with a species column
  species_column = "species_name",
  run_root = file.path("sdms", "runs", "gbif_chunked_downloads"),
  start_year = 1970,
  end_year = as.integer(format(Sys.Date(), "%Y")),

  max_active_downloads = 3,                # cap GBIF jobs occupying account slots
  max_new_submissions_per_run = 3,         # cap new requests per pass / poll cycle
  max_fetches_per_run = 1,                 # cap ZIP imports per pass / poll cycle
  poll = FALSE,                            # TRUE keeps checking until done / max cycles
  poll_interval_seconds = 60,
  max_poll_cycles = 120,
  stop_when_all_done = TRUE,               # done = fetched or terminal failure

  submit_new_downloads = TRUE,
  fetch_ready_downloads = TRUE,
  dry_run = FALSE,

  presence_only = TRUE,                    # FALSE keeps explicit ABSENT rows
  basis_of_record = c("HUMAN_OBSERVATION", "OBSERVATION", "PRESERVED_SPECIMEN"),
  drop_zero_individual_count = TRUE,
  deduplicate_by_gbif_key = TRUE,
  keep_zip = FALSE,                        # raw CSV is kept; ZIP is removed after import
  overwrite_downloads = FALSE
)

gbif_config <- if (exists("gbif_config", inherits = FALSE)) {
  utils::modifyList(default_config, gbif_config)
} else {
  default_config
}

# -----------------------------------------------------------------------------|
# 2. Helpers ----
# -----------------------------------------------------------------------------|

stamp <- function() {
  format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

first_value <- function(x, default = NA_character_) {
  if (is.null(x) || length(x) == 0 || is.na(x[[1]])) default else as.character(x[[1]])
}

safe_name <- function(x) {
  gsub("^_|_$", "", gsub("[^A-Za-z0-9]+", "_", trimws(as.character(x))))
}

species_key <- function(x) {
  gsub("[[:space:]]+", " ", trimws(tolower(as.character(x))))
}

ensure_dir <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  path
}

read_species <- function(config) {
  species <- as.character(config$species)
  if (!is.na(config$species_csv) && nzchar(config$species_csv)) {
    species_table <- read.csv(config$species_csv, check.names = FALSE, stringsAsFactors = FALSE)
    if (!config$species_column %in% names(species_table)) {
      stop("Species CSV is missing column: ", config$species_column, call. = FALSE)
    }
    species <- c(species, as.character(species_table[[config$species_column]]))
  }
  species <- trimws(species)
  unique(species[!is.na(species) & nzchar(species)])
}

ledger_cols <- c(
  "species", "species_key", "taxon_key", "matched_name", "start_year", "end_year",
  "download_key", "request_status", "gbif_status", "submitted_at", "checked_at",
  "fetch_status", "fetched_at", "download_link", "total_records", "size_bytes",
  "raw_csv", "filtered_csv", "raw_rows", "filtered_rows", "notes"
)

empty_ledger <- function() {
  as.data.frame(setNames(rep(list(character()), length(ledger_cols)), ledger_cols))
}

ensure_ledger <- function(x) {
  for (col in ledger_cols) {
    if (!col %in% names(x)) x[[col]] <- NA_character_
  }
  x[, ledger_cols, drop = FALSE]
}

read_ledger <- function(path) {
  if (file.exists(path)) {
    ensure_ledger(read.csv(path, check.names = FALSE, stringsAsFactors = FALSE))
  } else {
    empty_ledger()
  }
}

write_ledger <- function(ledger, path) {
  ensure_dir(dirname(path))
  write.csv(ensure_ledger(ledger), path, row.names = FALSE, na = "")
}

gbif_credentials <- function() {
  user <- Sys.getenv("GBIF_USER", unset = Sys.getenv("GBIF_USERNAME", unset = ""))
  password <- Sys.getenv("GBIF_PASSWORD", unset = Sys.getenv("GBIF_PWD", unset = ""))
  email <- Sys.getenv("GBIF_EMAIL", unset = "")
  if (!nzchar(email) && grepl("@", user, fixed = TRUE)) email <- user
  if (!nzchar(user) || !nzchar(password) || !nzchar(email)) {
    stop("Set GBIF_USER, GBIF_PASSWORD, and GBIF_EMAIL before submitting.", call. = FALSE)
  }
  list(user = user, password = password, email = email)
}

active_status <- function(status, fetch_status) {
  status <- toupper(trimws(as.character(status)))
  terminal <- c("SUCCEEDED", "FAILED", "KILLED", "CANCELLED", "CANCELED")
  missing_or_running <- is.na(status) | !nzchar(status) | !status %in% terminal
  not_fetched <- is.na(fetch_status) | !fetch_status %in% c("fetched", "no_records", "fetch_failed")
  missing_or_running & not_fetched
}

already_requested <- function(ledger, species, config) {
  if (nrow(ledger) == 0) return(FALSE)
  same_species <- ledger$species_key == species_key(species)
  same_window <- suppressWarnings(as.integer(ledger$start_year)) == config$start_year &
    suppressWarnings(as.integer(ledger$end_year)) == config$end_year
  has_key <- !is.na(ledger$download_key) & nzchar(ledger$download_key)
  any(same_species & same_window & has_key, na.rm = TRUE)
}

new_ledger_row <- function(species, config, request_status = "submitted", notes = NA_character_, ...) {
  values <- list(...)
  row <- as.list(setNames(rep(NA_character_, length(ledger_cols)), ledger_cols))
  row$species <- species
  row$species_key <- species_key(species)
  row$start_year <- as.character(config$start_year)
  row$end_year <- as.character(config$end_year)
  row$request_status <- request_status
  row$fetch_status <- "not_fetched"
  row$submitted_at <- stamp()
  row$notes <- notes
  for (name in names(values)) row[[name]] <- as.character(values[[name]])
  as.data.frame(row, stringsAsFactors = FALSE)
}

status_fields <- function(download_key) {
  meta <- rgbif::occ_download_meta(download_key)
  list(
    gbif_status = first_value(meta$status),
    checked_at = stamp(),
    download_link = first_value(meta$downloadLink),
    total_records = first_value(meta$totalRecords),
    size_bytes = first_value(meta$size)
  )
}

replace_fields <- function(ledger, row_idx, fields) {
  for (name in names(fields)) ledger[[name]][row_idx] <- as.character(fields[[name]])
  ledger
}

mark_zero_record_downloads <- function(ledger) {
  if (nrow(ledger) == 0) return(ledger)

  succeeded <- toupper(ledger$gbif_status) == "SUCCEEDED"
  total_records <- suppressWarnings(as.integer(ledger$total_records))
  fetch_open <- is.na(ledger$fetch_status) | !ledger$fetch_status %in% c("fetched", "no_records", "fetch_failed")
  zero_idx <- which(succeeded & !is.na(total_records) & total_records == 0 & fetch_open)

  for (row_idx in zero_idx) {
    ledger <- replace_fields(ledger, row_idx, list(
      fetch_status = "no_records",
      fetched_at = stamp(),
      raw_rows = 0,
      filtered_rows = 0,
      notes = "GBIF download succeeded with 0 records; no CSV fetch attempted."
    ))
  }

  ledger
}

submit_download <- function(species, config) {
  credentials <- gbif_credentials()
  backbone <- rgbif::name_backbone(name = species, rank = "species")
  taxon_key <- backbone$usageKey
  if (is.null(taxon_key) || is.na(taxon_key)) {
    stop("GBIF backbone lookup did not return a usageKey for ", species, call. = FALSE)
  }

  predicates <- list(
    rgbif::pred("taxonKey", taxon_key),
    rgbif::pred("hasCoordinate", TRUE),
    rgbif::pred("hasGeospatialIssue", FALSE),
    rgbif::pred_gte("year", config$start_year)
  )
  if (!is.na(config$end_year)) {
    predicates <- c(predicates, list(rgbif::pred_lte("year", config$end_year)))
  }
  if (length(config$basis_of_record) > 0) {
    predicates <- c(predicates, list(rgbif::pred_in("basisOfRecord", config$basis_of_record)))
  }
  if (isTRUE(config$presence_only)) {
    predicates <- c(predicates, list(rgbif::pred("occurrenceStatus", "PRESENT")))
  }

  download_key <- do.call(
    rgbif::occ_download,
    c(predicates, list(
      format = "SIMPLE_CSV",
      user = credentials$user,
      pwd = credentials$password,
      email = credentials$email
    ))
  )

  new_ledger_row(
    species,
    config,
    taxon_key = taxon_key,
    matched_name = first_value(backbone$canonicalName, species),
    download_key = as.character(download_key)
  )
}

zip_path_from <- function(download_result, download_key, download_dir) {
  candidates <- suppressWarnings(as.character(unlist(download_result, use.names = FALSE)))
  candidates <- candidates[grepl("[.]zip$", candidates) & file.exists(candidates)]
  if (length(candidates) > 0) return(normalizePath(candidates[[1]], mustWork = FALSE))

  expected <- file.path(download_dir, paste0(download_key, ".zip"))
  if (file.exists(expected)) normalizePath(expected, mustWork = FALSE) else NA_character_
}

filter_rows <- function(data, config) {
  keep <- rep(TRUE, nrow(data))

  if ("year" %in% names(data)) {
    years <- suppressWarnings(as.integer(data$year))
    keep <- keep & (is.na(years) | years >= config$start_year)
    if (!is.na(config$end_year)) keep <- keep & (is.na(years) | years <= config$end_year)
  }
  if (isTRUE(config$presence_only) && "occurrenceStatus" %in% names(data)) {
    status <- toupper(trimws(as.character(data$occurrenceStatus)))
    keep <- keep & (is.na(status) | !nzchar(status) | status == "PRESENT")
  }
  if (isTRUE(config$drop_zero_individual_count) && "individualCount" %in% names(data)) {
    count <- suppressWarnings(as.numeric(data$individualCount))
    keep <- keep & (is.na(count) | count != 0)
  }

  data <- data[keep, , drop = FALSE]
  if (isTRUE(config$deduplicate_by_gbif_key) && "key" %in% names(data)) {
    key <- as.character(data$key)
    data <- data[!(duplicated(key) & !is.na(key) & nzchar(key)), , drop = FALSE]
  }
  data
}

fetch_download <- function(ledger, row_idx, config) {
  species_safe <- safe_name(ledger$species[[row_idx]])
  download_key <- ledger$download_key[[row_idx]]
  base_dir <- ensure_dir(file.path(config$run_root, "occurrences", species_safe, "gbif-download"))
  raw_dir <- ensure_dir(file.path(base_dir, "raw"))
  filtered_dir <- ensure_dir(file.path(base_dir, "filtered"))

  download_result <- rgbif::occ_download_get(
    download_key,
    path = raw_dir,
    overwrite = isTRUE(config$overwrite_downloads)
  )
  zip_path <- zip_path_from(download_result, download_key, raw_dir)
  raw <- as.data.frame(rgbif::occ_download_import(download_result))
  filtered <- filter_rows(raw, config)

  raw_csv <- file.path(raw_dir, paste0(species_safe, "_raw.csv"))
  filtered_csv <- file.path(filtered_dir, paste0(species_safe, "_filtered.csv"))
  write.csv(raw, raw_csv, row.names = FALSE, na = "")
  write.csv(filtered, filtered_csv, row.names = FALSE, na = "")

  if (!isTRUE(config$keep_zip) && !is.na(zip_path) && file.exists(zip_path)) {
    unlink(zip_path)
  }

  replace_fields(ledger, row_idx, list(
    fetch_status = "fetched",
    fetched_at = stamp(),
    raw_csv = raw_csv,
    filtered_csv = filtered_csv,
    raw_rows = nrow(raw),
    filtered_rows = nrow(filtered)
  ))
}

all_species_done <- function(ledger, species, config) {
  if (length(species) == 0 || nrow(ledger) == 0) return(FALSE)

  done <- vapply(
    species,
    function(species_name) {
      same_species <- ledger$species_key == species_key(species_name)
      same_window <- suppressWarnings(as.integer(ledger$start_year)) == config$start_year &
        suppressWarnings(as.integer(ledger$end_year)) == config$end_year
      request_terminal <- tolower(ledger$request_status) == "failed"
      gbif_terminal <- toupper(ledger$gbif_status) %in% c("FAILED", "KILLED", "CANCELLED", "CANCELED")
      fetch_terminal <- ledger$fetch_status %in% c("fetched", "no_records", "fetch_failed")
      any(same_species & same_window & (fetch_terminal | request_terminal | gbif_terminal), na.rm = TRUE)
    },
    logical(1)
  )
  all(done)
}

# -----------------------------------------------------------------------------|
# 3. Submit/fetch pass ----
# -----------------------------------------------------------------------------|

ledger_path <- file.path(gbif_config$run_root, "gbif_download_requests.csv")
species <- read_species(gbif_config)
max_cycles <- if (isTRUE(gbif_config$poll)) gbif_config$max_poll_cycles else 1L

ensure_dir(gbif_config$run_root)
cat("Ledger:", ledger_path, "\n")
cat("Configured species:", length(species), "\n")

cycle <- 1L
repeat {
  cat("\nCycle:", cycle, "\n")
  ledger <- read_ledger(ledger_path)

  if (!isTRUE(gbif_config$dry_run) && nrow(ledger) > 0) {
    for (row_idx in which(!is.na(ledger$download_key) & nzchar(ledger$download_key))) {
      ledger <- tryCatch(
        replace_fields(ledger, row_idx, status_fields(ledger$download_key[[row_idx]])),
        error = function(err) replace_fields(
          ledger,
          row_idx,
          list(notes = paste("Status refresh failed:", conditionMessage(err)))
        )
      )
    }
    ledger <- mark_zero_record_downloads(ledger)
    write_ledger(ledger, ledger_path)
  }

  if (isTRUE(gbif_config$submit_new_downloads)) {
    active_count <- sum(active_status(ledger$gbif_status, ledger$fetch_status), na.rm = TRUE)
    slots <- min(
      max(0L, gbif_config$max_active_downloads - active_count),
      gbif_config$max_new_submissions_per_run
    )
    candidates <- species[!vapply(species, already_requested, logical(1), ledger = ledger, config = gbif_config)]
    to_submit <- head(candidates, slots)

    cat("Active downloads:", active_count, "\n")
    cat("New submissions this cycle:", length(to_submit), "\n")

    for (species_name in to_submit) {
      if (isTRUE(gbif_config$dry_run)) {
        cat("Dry run submit:", species_name, "\n")
        next
      }
      row <- tryCatch(
        submit_download(species_name, gbif_config),
        error = function(err) new_ledger_row(
          species_name,
          gbif_config,
          request_status = "failed",
          gbif_status = "FAILED",
          checked_at = stamp(),
          notes = conditionMessage(err)
        )
      )
      ledger <- rbind(ensure_ledger(ledger), ensure_ledger(row))
      write_ledger(ledger, ledger_path)
      cat("Submit:", species_name, "-", row$request_status[[1]], "\n")
    }
  }

  if (isTRUE(gbif_config$fetch_ready_downloads)) {
    ready <- ledger$gbif_status == "SUCCEEDED" &
      !(ledger$fetch_status %in% c("fetched", "no_records", "fetch_failed")) &
      !is.na(ledger$download_key) &
      nzchar(ledger$download_key)
    ready_idx <- head(which(ready), gbif_config$max_fetches_per_run)
    cat("Ready fetches this cycle:", length(ready_idx), "\n")

    for (row_idx in ready_idx) {
      if (isTRUE(gbif_config$dry_run)) {
        cat("Dry run fetch:", ledger$species[[row_idx]], "\n")
        next
      }
      ledger <- tryCatch(
        fetch_download(ledger, row_idx, gbif_config),
        error = function(err) replace_fields(
          ledger,
          row_idx,
          list(fetch_status = "fetch_failed", notes = paste("Fetch failed:", conditionMessage(err)))
        )
      )
      write_ledger(ledger, ledger_path)
      cat("Fetch:", ledger$species[[row_idx]], "-", ledger$fetch_status[[row_idx]], "\n")
    }
  }

  if (!isTRUE(gbif_config$dry_run)) {
    write_ledger(ledger, ledger_path)
  }

  if (!isTRUE(gbif_config$poll)) break
  if (isTRUE(gbif_config$dry_run)) break
  if (isTRUE(gbif_config$stop_when_all_done) && all_species_done(ledger, species, gbif_config)) {
    cat("All configured species are fetched or terminal.\n")
    break
  }
  if (!is.infinite(max_cycles) && cycle >= max_cycles) {
    cat("Reached max_poll_cycles:", max_cycles, "\n")
    break
  }

  cat("Sleeping", gbif_config$poll_interval_seconds, "seconds before next status check.\n")
  Sys.sleep(gbif_config$poll_interval_seconds)
  cycle <- cycle + 1L
}

cat("Done.\n")
