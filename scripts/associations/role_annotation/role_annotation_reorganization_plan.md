# Role Annotation Reorganization Plan

Date: 2026-06-16

## Purpose

This plan describes how to reorganize the role-annotation workflow so it is
grouped by scope rather than by the historical order in which scripts were
created.

The goal is to make role annotation the owner of biological interpretation and
role-derived modelling features, while readiness remains a downstream modelling
handoff layer.

## Current Problem

The current `scripts/associations/role_annotation/` folder mixes several
different concerns in one historical sequence:

- host/vector candidate roster construction;
- Deep Research and source-check curation staging;
- accepted evidence and assignment import;
- evidence-readiness QA;
- disease modelling readiness assembly;
- prototype modelling evidence tiers and host role buckets.

This has worked while the workflow evolved, but it makes ownership blurry. The
main problem is visible in the current `6_11` prototype: role-like modelling
features such as `host_role_bucket`, `modelling_role_proxy`,
`host_role_evidence_basis`, and `host_role_weight` are derived after the
readiness package exists. In the final pipeline, these should be role-annotation
features that readiness consumes.

## Design Principle

Role annotation owns biological interpretation.

Readiness owns modelling handoff assembly.

In practice:

- `manual/role_annotation/` contains human decisions, review notes, and
  source-check work.
- `staged/role_annotation/` contains generated queues, prompts, candidate
  review tables, and pre-review material.
- `evidence/role_annotation/` contains accepted/generated active
  role-annotation products.
- `readiness/` contains assembled modelling handoff surfaces that consume role
  annotation, country evidence, vector evidence, and SDM availability.

## Target Data Layout

```text
pathogen_association_data/source_data/role_annotation/
  papers/
  pdf_text/

pathogen_association_data/staged/role_annotation/
  curation_inputs/
  source_check_candidates/
  deep_research_inputs/

pathogen_association_data/manual/role_annotation/
  reviews/
  source_check/
  modelling_proxy_rules/

pathogen_association_data/evidence/role_annotation/
  host_role_candidates.csv
  host_role_candidates_summary.csv
  species_host_vector_roster.csv
  species_host_vector_roster_summary.csv
  species_host_vector_roster.xlsx
  host_role_evidence.csv
  host_role_assignments.csv
  vector_role_evidence.csv
  vector_role_assignments.csv
  vector_role_candidates_who.csv
  vector_role_candidates_who_summary.csv
  role_modelling_features.csv
  qa/

pathogen_association_data/readiness/
  disease_modelling_readiness.csv
  disease_modelling_readiness_full.csv
  disease_modelling_pilot.csv
  disease_modelling_pilot_package/
  evidence_tiers/
```

### Data Ownership

| Artifact type | Owner folder | Notes |
| --- | --- | --- |
| Raw PDFs and extracted text | `source_data/role_annotation/` | Source material only. |
| Generated review queues | `staged/role_annotation/` | Inputs to human/source-check work; not evidence. |
| Human review notes and decisions | `manual/role_annotation/` | Durable manual judgement. |
| Accepted role evidence and assignments | `evidence/role_annotation/` | Active role-annotation truth layer. |
| Derived role modelling features | `evidence/role_annotation/` once stable; `staged/role_annotation/` while experimental | Owned by role annotation, consumed by readiness. |
| Readiness handoff tables | `readiness/` | Joined modelling surfaces for admin/model-spec work. |

## Target Script Layout

The final script layout should be grouped by scope:

```text
scripts/associations/role_annotation/
  roster/
    01_build_host_role_candidates.R
    02_build_species_host_vector_roster.R

  curation_inputs/
    01_prepare_deep_research_batches.R
    02_reformat_deep_research_reports.R
    03_consolidate_deep_research_reports.R
    04_build_role_gap_source_check_candidates.R

  source_check/
    01_build_source_check_decision_ledger.R
    02_import_source_checked_role_rows.R

  features/
    01_build_role_modelling_features.R
    rules/
      host_proxy_rules.R
      vector_proxy_rules.R

  qa/
    01_build_role_evidence_readiness_qa.R

scripts/associations/readiness/
  01_build_disease_modelling_readiness.R
  02_build_modelling_evidence_tiers_handoff.R
  helpers/
    disease_modelling_readiness_helpers.R
```

This structure allows each numbered sequence to be local to its scope rather
than one long historical timeline across all role-annotation work.

## Deep Research Scripts Are On-Demand Curation Tooling

The Deep Research scripts should not be treated as part of the routine pipeline.
They are on-demand curation tooling used when we want to generate, normalize, or
consolidate external research batches for later source-check review.

In particular:

- `6_4_Prepare_Deep_Research_Batch_Inputs.R` is a batch prompt/attachment
  generator.
- `6_5_Reformat_Deep_Research_Reports.R` is a parser for returned reports and
  currently contains hardcoded downloaded report paths.
- `6_6_Consolidate_Deep_Research_Reports.R` consolidates returned reports into
  source-check staging queues.

These scripts are useful for regenerating provenance and backlog material, but
they should not be run automatically as part of normal readiness or role-feature
builds. The active routine path starts after curation outputs have been reviewed
or staged into the source-check workflow.

Long term, `6_5` and `6_6` should be consolidated into a parameterized
curation-input processor. The old hardcoded report parser should only be
archived after a replacement can reproduce the current consolidated staging
outputs.

## Current-To-Target Mapping

| Current file | Current role | Target location |
| --- | --- | --- |
| `6_1_Derive_Host_Role_Candidates.R` | Build host role candidates | `role_annotation/roster/01_build_host_role_candidates.R` |
| `6_2_Derive_Species_Host_Vector_Roster.R` | Build collaborator-facing species host/vector roster | `role_annotation/roster/02_build_species_host_vector_roster.R` |
| `6_3_Build_Evidence_Readiness_QA.R` | Build role/evidence readiness QA summaries | `role_annotation/qa/01_build_role_evidence_readiness_qa.R` |
| `6_4_Prepare_Deep_Research_Batch_Inputs.R` | Generate Deep Research batch inputs | `role_annotation/curation_inputs/01_prepare_deep_research_batches.R` |
| `6_5_Reformat_Deep_Research_Reports.R` | Normalize Deep Research outputs | `role_annotation/curation_inputs/02_reformat_deep_research_reports.R` |
| `6_6_Consolidate_Deep_Research_Reports.R` | Consolidate generated research outputs and queues | `role_annotation/curation_inputs/03_consolidate_deep_research_reports.R` |
| `6_7_Build_Source_Check_Decision_Ledger.R` | Build source-check decision ledger | `role_annotation/source_check/01_build_source_check_decision_ledger.R`; eventually ingest Deep Research, manual, and role-gap source-check candidates |
| `6_9_Import_Source_Checked_Role_Rows.R` | Import accepted source-checked rows | `role_annotation/source_check/02_import_source_checked_role_rows.R` |
| `6_10_Build_Disease_Modelling_Readiness.R` | Assemble disease modelling readiness | `scripts/associations/readiness/01_build_disease_modelling_readiness.R` |
| `6_11_Derive_Modelling_Evidence_Tiers.R` | Prototype role feature, role-gap queue, and readiness handoff derivation | Split into role features, role-gap source-check candidate generation, and readiness handoff scripts |

## How To Split `6_11`

The current `6_11_Derive_Modelling_Evidence_Tiers.R` does three things:

1. derives role proxy, bucket, evidence-basis, and weight fields;
2. writes a readiness handoff table;
3. writes a generated host-role review queue.

These should become three separate concerns. The durable design should not be:

```text
6_11 -> review_queue_host_roles.csv -> 6_7
```

That would make the source-check workflow depend on a downstream readiness/
handoff prototype. Instead, the role-gap candidate logic currently prototyped
inside `6_11` should move into curation/source-check candidate generation.

### Preferred Simplification

The preferred simplification is:

1. Retire `review_queue_host_roles.csv` as a permanent output.
2. Add a smaller curation candidate generator that emits only rows worth source
   checking, with stable candidate IDs and a proposed review task.
3. Make `6_7_Build_Source_Check_Decision_Ledger.R`, or its future replacement,
   ingest those role-gap candidates alongside Deep Research and manual
   candidates.
4. Keep `6_9_Import_Source_Checked_Role_Rows.R` as the only promotion/import
   script for accepted source-check decisions.
5. Replace `6_11_Derive_Modelling_Evidence_Tiers.R` later with two cleaner
   scripts:
   - `build_role_modelling_features.R`
   - `build_modelling_evidence_tiers_handoff.R`

In other words: merge the review-queue part into the source-check/curation
workflow, but do not merge the modelling feature or readiness handoff logic into
source-check.

The intended simplified flow is:

```text
roster/candidates
  -> curation/source-check ledger
  -> import accepted role evidence/assignments
  -> derive role modelling features
  -> build readiness handoff
```

This keeps the pipeline to one curation ledger, one import route, one
role-feature layer, and one readiness handoff.

### 1. Role Modelling Feature Builder

Target script:

```text
scripts/associations/role_annotation/features/01_build_role_modelling_features.R
```

Target stable output:

```text
pathogen_association_data/evidence/role_annotation/role_modelling_features.csv
pathogen_association_data/evidence/role_annotation/qa/role_modelling_feature_summary.csv
```

Experimental output, if we are not ready to promote it:

```text
pathogen_association_data/staged/role_annotation/modelling_features/role_modelling_features.csv
pathogen_association_data/staged/role_annotation/modelling_features/role_modelling_feature_summary.csv
```

This script should derive:

- `host_role_bucket`
- `modelling_role_proxy`
- `modelling_role_proxy_basis`
- `modelling_role_proxy_confidence`
- `modelling_role_proxy_rule_id`
- `modelling_role_proxy_needs_review`
- `host_role_evidence_basis`
- `host_role_weight`
- vector-equivalent fields later, if needed

Inputs should be role-annotation-owned tables, not the readiness package:

- `species_host_vector_roster.csv`
- `host_role_assignments.csv`
- `vector_role_assignments.csv`
- relevant source-backed evidence tables
- reviewed proxy policy tables, if added

### 2. Role-Gap Source-Check Candidate Generation

Target script:

```text
scripts/associations/role_annotation/curation_inputs/04_build_role_gap_source_check_candidates.R
```

Target output:

```text
pathogen_association_data/staged/role_annotation/source_check_candidates/role_gap_source_check_candidates.csv
```

This should be a small, source-check-shaped candidate table, not a broad
2,000-row review queue. It should identify rows where a missing or weak role is
worth source checking and provide stable candidate IDs, proposed review tasks,
entity metadata, and enough context for source-check review.

The future source-check ledger builder should merge this with:

- Deep Research consolidated candidates;
- durable manual source-check candidates;
- any other explicitly generated role-gap candidates.

The generated broad `review_queue_host_roles.csv` may be useful temporarily as
an exploratory bridge, but it should not become a stable upstream dependency of
`6_7_Build_Source_Check_Decision_Ledger.R`.

### 3. Readiness Evidence-Tier Handoff

Target script:

```text
scripts/associations/readiness/02_build_modelling_evidence_tiers_handoff.R
```

Target outputs:

```text
pathogen_association_data/readiness/evidence_tiers/tiered_species.csv
pathogen_association_data/readiness/evidence_tiers/host_role_bucket_counts.csv
pathogen_association_data/readiness/evidence_tiers/manifest.csv
pathogen_association_data/readiness/evidence_tiers/README.md
```

This script should consume the role modelling feature layer and join it to the
readiness package. It should not define disease-specific biological proxy logic
itself.

## Role Proxy Rule Ownership

Disease-specific proxy rules should be explicit, reviewed, and testable.

Short term, they can live in code:

```text
scripts/associations/role_annotation/features/rules/host_proxy_rules.R
```

Long term, reviewed policy choices may be better as small manual tables:

```text
pathogen_association_data/manual/role_annotation/modelling_proxy_rules/
```

Example policy decisions that should be explicit:

- H5N1/H7N9 wild aquatic bird reservoir group proxy.
- H5N1/H7N9 galliform/livestock/spillover treatment.
- West Nile broad Aves proxy.
- West Nile weighted bird proxies for Corvidae, Passeriformes, and
  Charadriiformes/Laridae.
- Diseases where broad group proxies should not be propagated.

The code should always preserve:

- exact source-backed assignments first;
- reviewed-but-needs-review assignments before broad proxies;
- proxy provenance through `rule_id` and evidence basis;
- review flags for group/taxonomic proxies.

## Migration Phases

### Phase 0: Freeze The Current Prototype Contract

Purpose: prevent accidental drift while reorganizing.

Actions:

1. Record current paths, row counts, and column counts for:
   - `readiness/evidence_tiers/tiered_species.csv`
   - `readiness/evidence_tiers/host_role_bucket_counts.csv`
   - `staged/role_annotation/modelling_evidence_tiers/review_queue_host_roles.csv`
2. Keep `6_11` runnable during migration.
3. Do not change accepted evidence or assignment tables.

Validation:

- current script parses;
- generated CSVs parse with zero problems;
- current row counts are reproducible.

### Phase 1: Add Architecture Documentation

Purpose: document the intended ownership before moving files.

Actions:

1. Add this plan.
2. Update `pathogen_association_data/evidence/role_annotation/README.md` to
   state that role modelling features are role-annotation products.
3. Update readiness README text to state that readiness consumes role features.

Validation:

- documentation reflects actual paths;
- no generated outputs change.

### Phase 2: Extract Role Feature Rules

Purpose: separate biological role-feature logic from readiness assembly.

Actions:

1. Create `scripts/associations/role_annotation/features/`.
2. Move H5N1/H7N9 and West Nile host proxy logic into a helper, initially
   without changing behavior.
3. Add a small rule contract in comments or README:
   - exact assignments win;
   - reviewed assignments win before proxies;
   - group proxies are review-needed unless explicitly accepted;
   - role weights are separate from SDM/model quality.

Validation:

- rerun current `6_11`;
- `tiered_species.csv` and `host_role_bucket_counts.csv` remain unchanged except
  for expected timestamp-free metadata, if any.

### Phase 3: Build A Role Modelling Feature Table

Purpose: make role annotation produce the role-derived modelling layer.

Actions:

1. Create `01_build_role_modelling_features.R`.
2. Use `species_host_vector_roster.csv` and role assignments as the primary
   inputs.
3. Write an experimental feature table under staged first:

   ```text
   pathogen_association_data/staged/role_annotation/modelling_features/role_modelling_features.csv
   ```

4. Compare feature fields against the current `tiered_species.csv` host fields.
5. Once stable, promote output to:

   ```text
   pathogen_association_data/evidence/role_annotation/role_modelling_features.csv
   ```

Validation:

- one row per disease/species/role-family key expected by the roster;
- no accepted evidence or assignment table changes;
- all exact role assignments appear in the feature layer;
- WNV/H5/H7 proxy counts match the prototype.

### Phase 4: Move Role-Gap Curation Into Source-Check Candidate Generation

Purpose: keep curation inputs out of readiness and avoid a durable
`6_11 -> 6_7` dependency.

Actions:

1. Create `curation_inputs/04_build_role_gap_source_check_candidates.R`.
2. Generate a small source-check-shaped candidate table from the role feature
   layer and roster.
3. Write to:

   ```text
   pathogen_association_data/staged/role_annotation/source_check_candidates/role_gap_source_check_candidates.csv
   ```

4. Extend or replace `6_7_Build_Source_Check_Decision_Ledger.R` so the unified
   source-check ledger can ingest:
   - Deep Research consolidated candidates;
   - manual source-check candidates;
   - generated role-gap source-check candidates.
5. Stop generating broad review queues from the readiness handoff script.

Validation:

- candidate row count is explainable and intentionally much smaller than the
  broad exploratory queue;
- candidate columns are compatible with the source-check ledger;
- no stable source-check path depends on `6_11`;
- no queue files under `readiness/`.

### Phase 5: Refactor Readiness To Consume Role Features

Purpose: make readiness a consumer, not the owner of role logic.

Actions:

1. Create `scripts/associations/readiness/`.
2. Move or wrap `6_10_Build_Disease_Modelling_Readiness.R` as:

   ```text
   scripts/associations/readiness/01_build_disease_modelling_readiness.R
   ```

3. Create:

   ```text
   scripts/associations/readiness/02_build_modelling_evidence_tiers_handoff.R
   ```

4. Join `role_modelling_features.csv` into the readiness package.
5. Write only handoff outputs under `readiness/evidence_tiers/`.

Validation:

- readiness row counts remain expected;
- role feature columns in readiness match the role feature layer;
- no disease-specific role proxy rules live in readiness scripts.

### Phase 6: Rename And Retire Historical Scripts

Purpose: make the codebase readable by scope.

Actions:

1. Keep thin compatibility wrappers temporarily, if needed:

   ```r
   source("scripts/associations/readiness/01_build_disease_modelling_readiness.R")
   ```

2. Move old historical scripts into scope folders.
3. Update READMEs, contracts, and any command references.
4. Remove wrappers after downstream references are updated.

Validation:

- documented commands run from repo root;
- no stale README references to old paths;
- `rg "6_10|6_11|6_1_"` returns only intentional archive/history mentions.

## Final Pipeline Shape

```text
1. Build role candidates and roster.
2. Generate curation/source-check candidates from Deep Research, manual inputs,
   and role-gap candidate builders.
3. Build one unified source-check decision ledger.
4. Review and import accepted evidence/assignments.
5. Derive role modelling features from accepted evidence and explicit proxy rules.
6. Build role QA summaries.
7. Build disease modelling readiness from disease/country/SDM/role-feature inputs.
8. Build admin or species-level modelling handoff tables.
```

This makes role annotation the place where biological interpretation is owned,
and readiness the place where those interpretations are assembled for modelling.

## Non-Goals

- Do not change biological role assignments during the reorganization.
- Do not collapse host and vector evidence into one opaque score.
- Do not move accepted manual decisions into staged outputs.
- Do not let readiness scripts silently create new biological role logic.
- Do not make the source-check ledger depend durably on `6_11` or readiness
  handoff outputs.
- Do not make many sidecar CSVs when a table can be regenerated from a main
  row-level output.

## Open Decisions

- Should `role_modelling_features.csv` go directly to
  `evidence/role_annotation/`, or spend one iteration under staged first?
- Should reviewed proxy policies live only in code, or in
  `manual/role_annotation/modelling_proxy_rules/`?
- Should vector role buckets use the same feature-layer table as host role
  buckets, or a separate vector feature table?
- Should `6_10` be moved now, or only after the role feature layer is stable?
- What exact primary key should `role_modelling_features.csv` expose for
  readiness joins?
- Should `6_7_Build_Source_Check_Decision_Ledger.R` be extended in place to
  ingest multiple candidate sources, or replaced by a new scoped source-check
  ledger builder with a compatibility wrapper?

## Suggested First Implementation Slice

The lowest-risk first slice is:

1. Keep current `6_11` outputs unchanged.
2. Extract host proxy rule helpers into
   `scripts/associations/role_annotation/features/rules/host_proxy_rules.R`.
3. Add a staged `role_modelling_features.csv` generated from the same current
   inputs as `6_11`.
4. Compare the feature columns against `tiered_species.csv`.
5. Only then refactor readiness to consume the new feature table.
