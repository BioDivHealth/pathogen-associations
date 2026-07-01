# Global Ready SDM Mapping Interface

This folder contains a small scriptable/Shiny interface for aggregating present-day
ready SDM rasters from the consolidated SDM bundle.

Default bundle root:

```text
/Volumes/LaCie/new_global_maxent/sdms/consolidated_ready_sdms_20260630
```

When this `scripts/interface/` folder is copied inside a consolidated SDM bundle,
the helper scripts auto-detect the bundle root from their own location. You can
also override the root with `READY_SDM_BUNDLE_ROOT`.

The main input table is:

```text
readiness/interface_inputs/all_disease_species_sdm_lookup.csv
```

That lookup table provides disease/species rows, modelling role fields, SDM
availability flags, and relative raster paths.

## Files

- `aggregation_helpers.R`: reusable filtering, raster loading, aggregation, and
  export functions.
- `run_chikungunya_aggregation_example.R`: non-interactive smoke run for
  Chikungunya vectors.
- `run_disease_sdm_subset_export.R`: RStudio-friendly exporter with an editable
  config block at the top.
- `export_disease_sdm_subset.R`: command-line exporter for copying the SDMs
  relevant to selected diseases and filters.
- `app.R`: Shiny interface for selecting diseases/species and writing aggregate
  maps.

## Run The Chikungunya Smoke Example

Run from the repository root:

```sh
Rscript scripts/sdms/interface/run_chikungunya_aggregation_example.R
```

The example uses:

- `analysis_unit_id == "master_4"`
- vectors only
- `primary_or_main_vector` and `competence_supported_vector`
- `ensemble_mean.tif` thresholded with the mean retained-model
  `TSS.threshold.TEST` value
- binary richness aggregation
- `extend_to_union` geometry handling with a fill value of `0`
- remaining raster `NA` cells filled with `0` before aggregation

Outputs are written under:

```text
<bundle_root>/map_outputs/
```

Each run folder contains:

- `aggregate.tif`
- `aggregate_preview.png`
- `selected_species.csv`
- `excluded_species.csv`
- `run_manifest.csv`

## Export Disease-Specific SDM Files

Use `run_disease_sdm_subset_export.R` when you want a reproducible folder of SDM
files for chosen diseases/species without making a map. This is the easiest
RStudio workflow:

1. Open `scripts/sdms/interface/run_disease_sdm_subset_export.R`.
2. Edit the `disease_sdm_subset_config` block at the top.
3. Click Source.

The default config exports Chikungunya vector SDMs:

```r
disease_sdm_subset_config <- list(
  bundle_root = default_ready_sdm_bundle_root(),
  analysis_unit_ids = c("master_4"),
  species_roles = c("vector"),
  host_role_buckets = NULL,
  host_detection_methods = NULL,
  vector_role_buckets = c("primary_or_main_vector", "competence_supported_vector"),
  evidence_tiers = NULL,
  include_files = c("model", "continuous", "tss", "summary"),
  output_root = file.path(default_ready_sdm_bundle_root(), "disease_sdm_subsets"),
  dry_run = FALSE,
  overwrite = FALSE
)
```

Example Yellow fever host config, limited to PCR/sequencing-backed host rows:

```r
disease_sdm_subset_config$analysis_unit_ids <- c("master_5")
disease_sdm_subset_config$species_roles <- c("host")
disease_sdm_subset_config$vector_role_buckets <- NULL
disease_sdm_subset_config$host_detection_methods <- c("PCR/Sequencing")
```

There is also a command-line equivalent for automated runs.

Example Chikungunya vector export:

```sh
Rscript scripts/sdms/interface/export_disease_sdm_subset.R \
  --analysis-unit-ids master_4 \
  --species-roles vector \
  --vector-role-buckets primary_or_main_vector,competence_supported_vector
```

Example Yellow fever host export, limited to PCR/sequencing-backed host rows:

```sh
Rscript scripts/sdms/interface/export_disease_sdm_subset.R \
  --analysis-unit-ids master_5 \
  --species-roles host \
  --host-detection-methods PCR/Sequencing
```

By default, exports are written under:

```text
<bundle_root>/disease_sdm_subsets/
```

Each export folder contains:

- `hosts/` and/or `vectors/` species folders with copied SDM files.
- `selected_species.csv`
- `excluded_species.csv`
- `copy_manifest.csv`
- `run_manifest.csv`

Useful options:

- `--species-roles host,vector`
- `--host-role-buckets reservoir_or_amplifying_host`
- `--host-detection-methods PCR/Sequencing,Isolation/Observation`
- `--vector-role-buckets primary_or_main_vector,competence_supported_vector`
- `--evidence-tiers strict,strong,supported`
- `--include-files model,continuous,tss,summary`
- `--output-root /path/to/output`
- `--dry-run true`
- `--overwrite true`

## Launch The Shiny App

From the repository root:

```sh
Rscript -e "shiny::runApp('scripts/sdms/interface')"
```

The app defaults to Chikungunya fever (`master_4`), vector rows, and the two
first-pass vector buckets:

- `primary_or_main_vector`
- `competence_supported_vector`

The app also exposes a host-only detection-method filter when host rows are in
scope. The filter is derived from `readiness/evidence_tiers/tiered_species.csv`
and uses these broad categories:

- `PCR/Sequencing`
- `Antibodies`
- `Isolation/Observation`
- `Not specified`

## Aggregation Semantics

Supported raster modes:

- `continuous`: load `map_layer_default` / `ensemble_mean.tif`.
- `tss_clipped`: load `map_layer_thresholded` / `ensemble_tss_clipped.tif`.
- `manual_binary`: load `ensemble_mean.tif` and apply `manual_threshold`.
- `model_threshold_binary`: load `ensemble_mean.tif`, read the species
  `model.rds`, and apply a species-specific threshold from the model parameter
  table. The default is the mean retained-model `TSS.threshold.TEST` value.

Supported aggregation modes:

- `mean_continuous`: mean of selected raster values.
- `max_continuous`: maximum selected raster value.
- `binary_richness`: count of selected species present.
- `any_binary`: at least one selected species present.

Role buckets, evidence tiers, and host detection methods are filters only. They
do not currently weight species differently after selection.

Binary aggregations require `tss_clipped`, `manual_binary`, or
`model_threshold_binary`. For `tss_clipped`,
presence is interpreted as `ensemble_tss_clipped > 0.1`, matching the current
clipped-output convention where below-threshold cells are set to `0.1`.
The TSS-clipped rasters are produced from each retained model's
`TSS.threshold.TEST` value.
For binary richness maps, prefer `model_threshold_binary` over `tss_clipped`;
the clipped ensemble is a continuous display product, while
`model_threshold_binary` creates true 0/1 species layers from the model
thresholds.

The helper checks raster CRS, extent, resolution, and dimensions before
aggregation.

Geometry modes:

- `strict`: require identical CRS, extent, resolution, and dimensions.
- `extend_to_union`: require matching CRS and resolution, then pad rasters onto
  a shared union extent using `geometry_fill_value` for newly added cells.

The current Chikungunya vector rasters are species-cropped to different extents,
so the example and Shiny default use `extend_to_union` with `geometry_fill_value
= 0`. This pads rasters without interpolating values.

After geometry handling, remaining raster `NA` cells are filled with
`internal_na_fill_value` before aggregation. The default is `0`, treating masked
or internal no-data cells as absence/background for aggregate maps. The same
zero-color is used for any leftover `NA` cells in static and Shiny previews.

## Override The Bundle Root

Set `READY_SDM_BUNDLE_ROOT` before running either script:

```sh
READY_SDM_BUNDLE_ROOT=/path/to/consolidated_ready_sdms Rscript scripts/sdms/interface/run_chikungunya_aggregation_example.R
```
