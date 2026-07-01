# SDM Scripts

This folder separates scripts for fitting present-day SDMs from scripts that
project existing SDMs into future climate scenarios.

## Folders

- `present/`: present-day SDM fitting workflows. This is where new AutoMaxent
  wrappers and calibration scripts should go.
- `present_future/`: existing workflow for cataloguing saved SDM objects and
  projecting them into future climate scenarios.

Refresh the readiness-facing SDM availability catalogue before rebuilding
readiness outputs:

```sh
Rscript scripts/sdms/present_future/01_catalog_models.R
```

By default, the catalogue uses the consolidated ready-SDM folder on LaCie when
it is present:
`/Volumes/LaCie/new_global_maxent/sdms/consolidated_ready_sdms_20260630`.
