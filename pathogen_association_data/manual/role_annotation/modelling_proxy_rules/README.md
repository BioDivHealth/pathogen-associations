# Host Modelling Proxy Rules

This folder contains manual modelling-proxy policy used by the role-annotation
feature builder. These rules are for broad modelling sensitivity and review
triage. They are not source-backed species-level role assignments.

## Main File

- `host_proxy_rules.csv` stores disease and taxonomic fallback rules consumed by
  `scripts/associations/role_annotation/features/01_build_role_modelling_features.R`.

The rule table uses one row per match rule. Blank taxonomic fields are
wildcards, and the first active matching row by lowest `priority` is applied.
Reviewed or source-backed rows from `host_role_assignments.csv` take precedence
over these proxy rules.

## Columns

- `rule_id`: stable identifier written to `modelling_role_proxy_rule_id`.
- `rule_active`: `TRUE` or `FALSE`.
- `disease_name`: readiness disease name to match.
- `priority`: lower numbers win when multiple rows match.
- `host_class`, `host_order`, `host_family`, `species_name`, `tax_id`: optional
  match fields. Leave blank to match any value.
- `modelling_role_proxy`, `modelling_role_proxy_basis`,
  `host_role_bucket`, `host_role_evidence_basis`,
  `modelling_role_proxy_confidence`, `modelling_role_proxy_needs_review`:
  values propagated into generated role modelling features.
- `rule_notes`: short curator-facing rationale or caveat.

## Editing Rule

Add future disease-specific fallback policy here first. Only change the R rule
engine when the matching language itself needs a new generic capability.

## When To Add A Rule

Add a host proxy rule when a disease has a well-supported broad host ecology,
exact species-level assignments are sparse, and the taxonomic grouping is useful
for modelling or sensitivity analysis. Exact reviewed host assignments override
proxy rules.

Do not add a proxy rule for a source-backed species-level role claim. Add that
claim to `host_role_evidence.csv` and `host_role_assignments.csv` instead.
Also avoid proxy rules for isolated detection, serology, or incidental exposure
unless the rule is explicitly meant to remain `host_presence_only`.

Use narrow rules first and broad fallbacks later. Lower `priority` values win.
Match on `disease_name` plus the narrowest reliable taxonomic fields, and leave
fields blank only when they should be wildcards. Broad group rules should usually
set `modelling_role_proxy_needs_review` to `TRUE`.
