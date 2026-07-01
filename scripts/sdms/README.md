# SDM Scripts

This folder contains temporary SDM migration material for present-day SDM target
manifests, occurrence workflows, model execution, delivery bundles, and
interface tooling.

## Folders

- `present/`: present-day SDM fitting workflows, including target manifests,
  occurrence preparation, model runners, calibration checks, diagnostics, and
  bundle preparation.
- `interface/`: helper functions, export scripts, and a Shiny app for using a
  consolidated ready-SDM bundle.

Before rebuilding association readiness outputs, refresh or import the compact
SDM availability catalogue at:

```text
pathogen_association_data/readiness/sdm_catalog/accessible_sdm_species.csv
```

During migration, readiness falls back to
`sdms/outputs/catalog/accessible_sdm_species.csv` if the preferred readiness
catalogue is absent. Long term, the future SDM repository should own catalogue
generation and publish only compact availability imports back to this repo.
