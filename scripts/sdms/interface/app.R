################################################################################
# app.R
################################################################################
# Purpose: Shiny interface for filtering ready SDMs and running aggregate maps.
################################################################################

suppressPackageStartupMessages({
  if (!requireNamespace("shiny", quietly = TRUE)) {
    stop("Package `shiny` is required.", call. = FALSE)
  }
  if (!requireNamespace("DT", quietly = TRUE)) {
    stop("Package `DT` is required.", call. = FALSE)
  }
  if (!requireNamespace("leaflet", quietly = TRUE)) {
    stop("Package `leaflet` is required.", call. = FALSE)
  }
  if (!requireNamespace("raster", quietly = TRUE)) {
    stop("Package `raster` is required.", call. = FALSE)
  }
  if (!requireNamespace("viridisLite", quietly = TRUE)) {
    stop("Package `viridisLite` is required.", call. = FALSE)
  }
})

library(shiny)

source("aggregation_helpers.R")

bundle_root <- normalizePath(default_ready_sdm_bundle_root(), winslash = "/", mustWork = TRUE)
lookup <- load_sdm_interface_lookup(bundle_root)
disease_summary <- load_disease_summary(bundle_root)

sdm_disease_choices <- lookup %>%
  filter(sdm_available) %>%
  group_by(analysis_unit_id, readiness_disease_name) %>%
  summarise(sdm_backed_rows = n(), .groups = "drop")

disease_choices <- sdm_disease_choices %>%
  mutate(label = paste0(readiness_disease_name, " (", analysis_unit_id, "; ", sdm_backed_rows, " SDM rows)")) %>%
  arrange(readiness_disease_name) %>%
  select(label, analysis_unit_id)
disease_choices <- stats::setNames(disease_choices$analysis_unit_id, disease_choices$label)
default_disease <- if ("master_4" %in% unname(disease_choices)) "master_4" else unname(disease_choices)[[1]]

ui <- fluidPage(
  titlePanel("Ready SDM Mapping"),
  sidebarLayout(
    sidebarPanel(
      selectizeInput(
        "analysis_unit_ids",
        "Disease",
        choices = disease_choices,
        selected = default_disease,
        multiple = TRUE
      ),
      checkboxGroupInput(
        "species_roles",
        "Species roles",
        choices = c("host", "vector"),
        selected = "vector",
        inline = TRUE
      ),
      selectizeInput("host_role_buckets", "Host role buckets", choices = NULL, multiple = TRUE),
      selectizeInput("host_detection_methods", "Host detection methods", choices = NULL, multiple = TRUE),
      selectizeInput("vector_role_buckets", "Vector role buckets", choices = NULL, multiple = TRUE),
      selectizeInput("evidence_tiers", "Evidence tiers", choices = NULL, multiple = TRUE),
      selectInput(
        "raster_mode",
        "Raster mode",
        choices = c(
          "Continuous ensemble mean" = "continuous",
          "TSS-clipped layer" = "tss_clipped",
          "Manual binary threshold" = "manual_binary",
          "Model TSS binary threshold" = "model_threshold_binary"
        ),
        selected = "model_threshold_binary"
      ),
      conditionalPanel(
        condition = "input.raster_mode == 'manual_binary'",
        sliderInput("manual_threshold", "Manual threshold", min = 0, max = 1, value = 0.5, step = 0.01)
      ),
      conditionalPanel(
        condition = "input.raster_mode == 'model_threshold_binary'",
        selectInput(
          "model_threshold_method",
          "Model threshold",
          choices = c(
            "Mean TSS test threshold" = "tss_test_mean",
            "Median TSS test threshold" = "tss_test_median",
            "Mean TSS MaxEnt threshold" = "tss_maxent_mean",
            "Median TSS MaxEnt threshold" = "tss_maxent_median"
          ),
          selected = "tss_test_mean"
        )
      ),
      selectInput(
        "aggregation_mode",
        "Aggregation mode",
        choices = c(
          "Mean suitability" = "mean_continuous",
          "Max suitability" = "max_continuous",
          "Binary richness" = "binary_richness",
          "Any binary presence" = "any_binary"
        ),
        selected = "binary_richness"
      ),
      selectInput(
        "geometry_strategy",
        "Geometry",
        choices = c(
          "Extend to union grid" = "extend_to_union",
          "Strict match only" = "strict"
        ),
        selected = "extend_to_union"
      ),
      numericInput("geometry_fill_value", "Union fill value", value = 0, min = 0, step = 0.1),
      numericInput("internal_na_fill_value", "Internal NA fill value", value = 0, min = 0, step = 0.1),
      actionButton("run", "Run aggregation", class = "btn-primary")
    ),
    mainPanel(
      tabsetPanel(
        tabPanel("Disease", DT::DTOutput("disease_table")),
        tabPanel("Selected Species", DT::DTOutput("selected_table")),
        tabPanel("Excluded Species", DT::DTOutput("excluded_table")),
        tabPanel(
          "Map",
          verbatimTextOutput("run_status"),
          leaflet::leafletOutput("map", height = 620),
          tags$hr(),
          downloadButton("download_tif", "GeoTIFF"),
          downloadButton("download_png", "PNG"),
          downloadButton("download_selected", "Selected CSV"),
          downloadButton("download_manifest", "Manifest CSV")
        )
      )
    )
  )
)

server <- function(input, output, session) {
  selected_diseases <- reactive({
    ids <- normalize_filter(input$analysis_unit_ids)
    if (is.null(ids)) {
      return(character())
    }
    ids
  })

  disease_rows <- reactive({
    disease_summary %>%
      filter(analysis_unit_id %in% selected_diseases())
  })

  candidate_rows <- reactive({
    req(length(selected_diseases()) > 0)
    lookup %>%
      filter(analysis_unit_id %in% selected_diseases(), species_role %in% input$species_roles)
  })

  observe({
    rows <- candidate_rows()

    host_choices <- rows %>%
      filter(species_role == "host", !is.na(host_role_bucket), nzchar(host_role_bucket)) %>%
      pull(host_role_bucket) %>%
      unique() %>%
      sort()
    host_detection_choices <- rows %>%
      filter(species_role == "host", !is.na(host_detection_category), nzchar(host_detection_category)) %>%
      pull(host_detection_category) %>%
      strsplit(";\\s*") %>%
      unlist(use.names = FALSE) %>%
      unique() %>%
      {
        intersect(detection_category_levels(), .)
      }
    vector_choices <- rows %>%
      filter(species_role == "vector", !is.na(vector_role_bucket), nzchar(vector_role_bucket)) %>%
      pull(vector_role_bucket) %>%
      unique() %>%
      sort()
    tier_choices <- rows %>%
      filter(!is.na(biological_evidence_tier), nzchar(biological_evidence_tier)) %>%
      pull(biological_evidence_tier) %>%
      unique() %>%
      sort()

    vector_default <- if ("master_4" %in% selected_diseases()) {
      intersect(c("primary_or_main_vector", "competence_supported_vector"), vector_choices)
    } else {
      character()
    }

    updateSelectizeInput(
      session,
      "host_role_buckets",
      choices = host_choices,
      selected = intersect(isolate(input$host_role_buckets), host_choices),
      server = TRUE
    )
    updateSelectizeInput(
      session,
      "host_detection_methods",
      choices = host_detection_choices,
      selected = intersect(isolate(input$host_detection_methods), host_detection_choices),
      server = TRUE
    )
    updateSelectizeInput(
      session,
      "vector_role_buckets",
      choices = vector_choices,
      selected = if (length(isolate(input$vector_role_buckets)) == 0) {
        vector_default
      } else {
        intersect(isolate(input$vector_role_buckets), vector_choices)
      },
      server = TRUE
    )
    updateSelectizeInput(
      session,
      "evidence_tiers",
      choices = tier_choices,
      selected = intersect(isolate(input$evidence_tiers), tier_choices),
      server = TRUE
    )
  })

  selection_preview <- reactive({
    req(length(selected_diseases()) > 0)
    preview_sdm_selection(
      bundle_root = bundle_root,
      analysis_unit_ids = selected_diseases(),
      species_roles = input$species_roles,
      host_role_buckets = input$host_role_buckets,
      host_detection_methods = input$host_detection_methods,
      vector_role_buckets = input$vector_role_buckets,
      evidence_tiers = input$evidence_tiers,
      lookup = lookup
    )
  })

  aggregation_result <- eventReactive(input$run, {
    run_sdm_aggregation(
      bundle_root = bundle_root,
      analysis_unit_ids = selected_diseases(),
      species_roles = input$species_roles,
      host_role_buckets = input$host_role_buckets,
      host_detection_methods = input$host_detection_methods,
      vector_role_buckets = input$vector_role_buckets,
      evidence_tiers = input$evidence_tiers,
      raster_mode = input$raster_mode,
      manual_threshold = input$manual_threshold,
      model_threshold_method = input$model_threshold_method,
      aggregation_mode = input$aggregation_mode,
      geometry_strategy = input$geometry_strategy,
      geometry_fill_value = input$geometry_fill_value,
      internal_na_fill_value = input$internal_na_fill_value
    )
  })

  output$disease_table <- DT::renderDT({
    DT::datatable(
      disease_rows(),
      rownames = FALSE,
      options = list(pageLength = 10, scrollX = TRUE)
    )
  })

  output$selected_table <- DT::renderDT({
    rows <- selection_preview()$selected %>%
      select(any_of(c(
        "readiness_disease_name",
        "species_role",
        "species_name",
        "biological_evidence_tier",
        "host_detection_category",
        "host_detection_method",
        "host_detection_tier",
        "host_role_bucket",
        "vector_role_bucket",
        "sdm_source_label",
        "map_layer_default",
        "map_layer_thresholded"
      )))
    DT::datatable(rows, rownames = FALSE, options = list(pageLength = 15, scrollX = TRUE))
  })

  output$excluded_table <- DT::renderDT({
    rows <- selection_preview()$excluded %>%
      select(any_of(c(
        "readiness_disease_name",
        "species_role",
        "species_name",
        "biological_evidence_tier",
        "host_detection_category",
        "host_detection_method",
        "host_detection_tier",
        "host_role_bucket",
        "vector_role_bucket",
        "sdm_available",
        "excluded_reason"
      )))
    DT::datatable(rows, rownames = FALSE, options = list(pageLength = 15, scrollX = TRUE))
  })

  output$run_status <- renderText({
    result <- aggregation_result()
    paste(
      "Output directory:", result$output_dir,
      "Selected species:", nrow(result$selected_species),
      "Excluded species:", nrow(result$excluded_species),
      sep = "\n"
    )
  })

  output$map <- leaflet::renderLeaflet({
    result <- aggregation_result()
    raster <- terra::rast(result$aggregate_path)
    aggregation_mode <- result$manifest$aggregation_mode[[1]]
    preview_fun <- if (aggregation_mode %in% c("binary_richness", "any_binary")) "max" else "mean"
    raster_preview <- preview_raster(raster, fun = preview_fun)
    raster_layer <- raster::raster(raster_preview)
    values <- raster::values(raster_layer)
    values <- values[is.finite(values)]

    pal <- leaflet::colorNumeric(
      palette = viridisLite::viridis(100),
      domain = values,
      na.color = viridisLite::viridis(100)[[1]]
    )

    leaflet::leaflet() %>%
      leaflet::addProviderTiles(leaflet::providers$CartoDB.Positron) %>%
      leaflet::addRasterImage(raster_layer, colors = pal, opacity = 0.75, project = TRUE) %>%
      leaflet::addLegend(pal = pal, values = values, title = "Aggregate")
  })

  download_result_file <- function(path_getter, filename) {
    downloadHandler(
      filename = function() filename,
      content = function(file) {
        result <- aggregation_result()
        source_path <- path_getter(result)
        file.copy(source_path, file, overwrite = TRUE)
      }
    )
  }

  output$download_tif <- download_result_file(function(result) result$aggregate_path, "aggregate.tif")
  output$download_png <- download_result_file(function(result) result$preview_path, "aggregate_preview.png")
  output$download_selected <- download_result_file(function(result) result$selected_species_path, "selected_species.csv")
  output$download_manifest <- download_result_file(function(result) result$run_manifest_path, "run_manifest.csv")
}

shinyApp(ui, server)
