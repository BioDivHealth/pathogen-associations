# pathogen-associations

This repository is an R analysis workspace for pathogen-host-vector association
evidence and modelling-readiness handoffs. It is split out from the
`pathogen_associations` branch of `new_global_maxent` as a fresh repository
without the old Git history.

Run scripts from the repository root so `here::here()` resolves paths
consistently.

## Repository Boundary

This repository owns the evidence and curation layers that answer:

- which diseases and pathogens are in scope;
- which host and vector taxa are linked to those diseases or pathogens;
- what evidence supports host, vector, competence, and host-vector roles;
- which countries are linked by GenBank records or WHO Disease Outbreak News;
- which species are ready, partial, or blocked for downstream modelling; and
- which versioned handoff files should be consumed by SDM workflows.

The main output contract is a modelling-readiness handoff under
`pathogen_association_data/readiness/`, including files such as disease
modelling packages, evidence tiers, role assignments, country evidence, and
species lists for SDM planning.

## Future SDM Repository Boundary

SDM execution should live in a separate repository, likely named
`pathogen-sdms` or `disease-sdms`. That future repository should own occurrence
downloads, SDM fitting, AutoMaxent/model execution, prediction outputs, delivery
bundles, model catalogues, and SDM interface tooling.

For now, `scripts/sdms/` and `sdms/` remain in this repository as temporary
migration material. They preserve the current handoff and catalogue workflow
while the split is stabilized. Treat them as extraction candidates for the
future SDM-focused repository, not as the long-term ownership boundary of this
repository.

The intended contract is:

1. `pathogen-associations` produces readiness targets and evidence tiers.
2. The SDM repository consumes those targets and produces model outputs and
   availability catalogues.
3. `pathogen-associations` may optionally import SDM availability catalogues
   back into readiness summaries, but it should not own SDM execution.

## Active Workflow

The active pathogen association pipeline builds WHO-linked disease/pathogen
analysis units, attaches host, vector, competence, country, role-review, and
SDM-availability evidence layers, and writes modelling-readiness handoff files.

Start with these files:

- `DATA_DECISIONS.md`: evidence-interpretation boundaries for host, vector,
  competence, country, role, and readiness layers.
- `pathogen_association_data/README.md`: current data lifecycle layout.
- `scripts/associations/README.md`: association workflow overview.
- `scripts/associations/working_inputs.R`: shared path helpers for active
  scripts.

Conceptual workflow order:

1. `scripts/associations/network_building/` builds WHO disease/pathogen
   backbones and host-pathogen networks from WHO, CLOVER, and VIRION sources.
2. `scripts/associations/vector_screening/` curates disease/pathogen-vector
   evidence and vector-competence annotations.
3. `scripts/associations/host_vector_sources/` prepares VectorMap and MapVEu
   host-vector evidence.
4. `scripts/associations/host_vector_integration/` joins disease/pathogen,
   host, vector, competence, and host-vector evidence for WHO-scoped outputs.
5. `scripts/associations/genbank_simple/` builds GenBank disease-country
   evidence for readiness workflows.
6. `scripts/associations/who_don_v2/` builds WHO Disease Outbreak News
   disease-country evidence.
7. `scripts/associations/role_annotation/` builds role-review candidates,
   source-check surfaces, QA summaries, and modelling-readiness handoffs.

## Data Layout

Versioned pathogen association data lives under `pathogen_association_data/`.
The current layout is lifecycle-based:

- `source_data/`: raw or near-raw source/vendor files.
- `manual/`: hand-edited curation, review, crosswalk, and control files.
- `staged/`: generated intermediates, prompts, manifests, and candidate tables.
- `evidence/`: active analysis-ready evidence outputs and QA surfaces.
- `readiness/`: generated modelling-readiness handoff files.
- `archive/`: inactive snapshots and local historical comparison material.

New scripts should source `scripts/associations/working_inputs.R` and use helper
functions instead of hard-coding data paths.

## Validation Style

There is no `testthat` suite. Validate changes by running the smallest relevant
script or parse/smoke check and confirming outputs land in the current
`source_data/`, `manual/`, `staged/`, `evidence/`, or `readiness/` roots without
schema regressions.
