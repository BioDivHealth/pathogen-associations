# Include Species-Role Evidence Review

Date: 2026-06-25

Scope: first pass over the top-ranked include-scope diseases from
`include_species_role_evidence_audit.csv`.

## Bottom Line

No top-eight disease shows a new species-role blocker in the source-backed
evidence/assignment layer. Source-derived `vector_role_hint` values are now
audit context only: they remain visible in `vector_modelling_features.csv`, but
they no longer set `primary_or_main_vector`, `bridge_or_epidemic_vector`, or
`enzootic_or_sylvatic_vector` modelling buckets unless a reviewed vector
assignment row supports that bucket.

The high avian-influenza ranks are mostly volume, not evidence conflict. They
are broad host-proxy policies that are already separated from exact
source-backed assignments.

One cleanup was made during this pass: obsolete Plague tax-id rescue proxy rows
were removed because regenerated Plague host taxonomy is now complete and the
rules were no longer used by `role_modelling_features.csv`.

Follow-up source-hint audit output:
`include_vector_source_hint_audit.csv`. This row-level QA table has 43
include-scope vector rows across 6 diseases where `vector_role_hint` would have
changed the bucket under the old policy. Under the current policy, those rows
use fallback buckets instead: 34 `competence_supported_vector` rows and 9
`direct_association_only_vector` rows. The audit preserves the old hypothetical
hint bucket for review: 20 `primary_or_main_vector`, 16
`bridge_or_epidemic_vector`, and 7 `enzootic_or_sylvatic_vector`.

## Review Priority

1. Treat `include_vector_source_hint_audit.csv` as a candidate-promotion queue,
   not as a current modelling-bucket source. Review rows there only when a
   disease needs more reviewed vector assignments.
2. Treat reviewed-assignment and group-level vector caveats for West Nile,
   Yellow fever, CCHF, Zika, Dengue, and RVF as acceptable after follow-up
   passes. Remaining group-level vector assignments should be reviewed only if
   a collaborator wants species-level propagation or finer role vocabulary.
3. Treat H5N1/H7N9, Plague, and TBE as acceptable caveat surfaces unless a
   collaborator wants finer role vocabulary.

## Disease Notes

### Influenza (H7N9 avian influenza)

- Current audit focus: high-volume host proxy policy.
- Live surface: 559 host feature rows, 3 exact source-backed rows, 556 proxy
  rows, no vector rows, no readiness blocker.
- Interpretation: acceptable caveat. The proxy rows are broad avian-influenza
  group rules; exact source-backed rows remain separate and override proxies.
- Action: no species-role fix needed now.

### Influenza (H5N1 avian influenza)

- Current audit focus: high-volume host proxy policy.
- Live surface: 559 host feature rows, 4 exact source-backed rows, 555 proxy
  rows, no vector rows, no readiness blocker.
- Interpretation: acceptable caveat. This is the same broad avian-influenza
  policy surface as H7N9, with exact rows kept separate from proxies.
- Action: no species-role fix needed now.

### West Nile Fever

- Current audit focus: high-volume host proxy policy plus vector bucket review.
- Live surface: 274 host feature rows, 159 host proxy rows, 75 vector feature
  rows, 5 vector assignment rows, 6 vector rows needing review, and 4
  review-needed primary/main vector rows.
- Host proxy surface: broad avian reservoir/amplifier proxy policy remains
  review-visible. Exact human, horse, and `Turdus migratorius` rows stay
  separate from proxy-derived bird rows.
- Vector surface: reviewed `Culex pipiens`, `Culex modestus`,
  `Culex quinquefasciatus`, and `Culex tarsalis` main-vector rows retain
  regional caveats; `Culex salinarius` remains a regional epidemic-vector row.
- Evidence/assignment integrity caveat: one group-level `Aves` host evidence row
  and one group-level `Culex spp.` vector evidence row are intentionally not
  expanded into species-level assignments.
- Interpretation: acceptable caveat surface. The source-hint audit still shows
  11 rows that old logic would have promoted, but current buckets fall back to
  competence or direct-association evidence unless reviewed assignments exist.
- Action: no species-role row fix needed now. Missing vector SDM is an external
  handoff blocker, not a species-role blocker.

### Yellow Fever

- Current audit focus: group-level vector assignment caveat.
- Live surface: 73 host feature rows, 52 host proxy rows, 30 vector feature
  rows, 6 vector assignment rows, 3 reviewed vector feature rows, and no
  reviewed primary/main vector rows.
- Vector surface: `Aedes aegypti` is the only non-review urban/main vector.
  `Aedes africanus`, `Haemagogus janthinomys`, and `Haemagogus leucocelaenus`
  remain review-needed sylvatic/outbreak rows.
- Group-level vector caveat: `Haemagogus spp.` and `Sabethes spp.` assignments
  remain intentionally unmatched to species-level roster rows.
- Host proxy surface: broad primate rule plus 6 remaining tax-id rescues for
  unresolved primate genus/subfamily rows.
- Interpretation: acceptable caveat surface. The source-hint audit still shows
  18 vector rows that old logic would have promoted, but those now fall back to
  competence or direct-association buckets.
- Action: no species-role row fix needed now. Use the source-hint audit only if
  we decide to promote more species-level Yellow fever vectors with reviewed
  assignments.

### Crimean-Congo Hemorrhagic Fever

- Current review focus: host proxy policy plus reviewed primary-vector caveats.
- Live surface: 58 host feature rows, 28 host proxy rows, 49 vector feature
  rows, 8 vector rows needing review, 4 primary-vector rows needing review.
- Host proxy surface: livestock tax-id rules plus broad wild-ungulate taxonomy
  rules; no remaining host taxonomy blanks.
- Vector surface: `Hyalomma` rows are the main review pressure, with several
  primary-vector buckets still caveated by reviewed regional context. The
  classifier fix moved `Hyalomma lusitanicum` from `primary_or_main_vector` to
  `enzootic_or_sylvatic_vector`; four additional source-hint rows stay at
  competence-supported fallback.
- Interpretation: usable, with CCHF now the main remaining reviewed-assignment
  primary-vector caveat among the top-ranked diseases.
- Action: no immediate row fix. Missing vector SDM is external to species-role
  evidence.

### Plague

- Current audit focus: group-level vector assignment caveat.
- Live surface after cleanup: 52 host feature rows, 50 host proxy rows, 47 vector
  feature rows, 4 vector rows needing review, 1 unmatched group-level vector
  assignment (`fleas`), no readiness blocker.
- Host proxy surface after cleanup: 2 active broad rules only, Rodentia
  maintenance and non-rodent mammal susceptible/spillover.
- Interpretation: acceptable caveat. The group-level `fleas` assignment is
  deliberate context and is not automatically propagated to all flea species.
- Action: no further species-role fix needed now.

### Rift Valley Fever

- Current audit focus: group-level vector assignment caveat.
- Live surface: 41 host feature rows, no host proxy rows, 78 vector feature
  rows, 6 vector assignment rows, 5 reviewed vector feature rows, and no
  reviewed primary/main vector rows.
- Vector surface: `Aedes spp.` and `Aedes mcintoshi` are review-needed
  enzootic/maintenance rows; `Culex poicilipes` is a review-needed
  epidemic/bridge row; `Culex spp.` and `Anopheles spp.` are review-needed
  mechanical-vector rows.
- Group-level vector caveat: `Mansonia spp.` is intentionally unmatched to the
  species-level vector roster and should not be propagated to all `Mansonia`
  species without species-level review.
- Interpretation: acceptable caveat surface. Five old source-hint primary-vector
  promotions now remain competence-supported fallback rows unless reviewed
  assignments promote them.
- Action: no species-role row fix needed now. Missing vector SDM is external to
  species-role evidence.

### Tick-Borne Encephalitis

- Current audit focus: group-level vector assignment caveat.
- Live surface: 92 host feature rows, 19 small-rodent proxy rows, 11 vector
  feature rows, 1 vector row needing review, 1 unmatched group-level vector
  assignment (`Ixodes spp.`).
- Interpretation: acceptable caveat. Species-level `Ixodes ricinus` and
  `Ixodes persulcatus` are reviewed primary vectors; `Ixodes spp.` is retained
  as group-level maintenance context.
- Action: no species-role fix needed now. Missing vector SDM is external to
  species-role evidence.

### Zika Virus Disease

- Current audit focus: reviewed vector-bucket caveats.
- Live surface: 21 host feature rows, 7 broad NHP host proxy rows, 56 vector
  feature rows, 12 vector assignment rows, 13 vector rows needing review, and no
  unmatched vector assignments.
- Vector surface: `Aedes aegypti` is the only non-review primary vector.
  Secondary, sylvatic, and regional candidate Aedes rows remain review-visible
  because their support is geography-, outbreak-, laboratory-, or
  temperature-context dependent.
- `Culex quinquefasciatus` remains intentionally reviewed as
  `not_important_vector`, mapping to `unknown_or_unreviewed_vector` so mixed
  competence evidence does not promote it into a positive vector bucket.
- Interpretation: acceptable caveat surface. No evidence/assignment row fix was
  needed in the reviewed-assignment pass.
- Action: no species-role fix needed now. Missing vector SDM is external to
  species-role evidence.

### Dengue

- Current audit focus: reviewed ecological vector caveats.
- Live surface: 53 host feature rows, 16 vector feature rows, 7 vector
  assignment rows, 6 vector rows needing review, and no unmatched vector
  assignments.
- Vector surface: `Aedes aegypti` is the only non-review primary vector.
  `Aedes albopictus` stays as a review-needed secondary vector, `Aedes
  polynesiensis` as a review-needed Polynesia-context epidemic vector,
  `Aedes furcifer`, `Aedes luteocephalus`, and `Aedes taylori` as
  review-needed African sylvatic vectors, and `Aedes vittatus` as
  competence-only.
- `Aedes hensilli` remains deferred because the primary dengue source has not
  been checked locally and the available secondary support is weaker.
- Interpretation: acceptable caveat surface. The ecological rows are
  source-backed but intentionally prevented from becoming global primary/main
  vector claims.
- Action: no species-role row fix needed now. Missing vector SDM is external to
  species-role evidence.

## Must fix

- None identified in the include-scope species-role evidence layer after this
  pass.

## Policy decision

- Keep `include_vector_source_hint_audit.csv` as a candidate-promotion queue;
  source-derived hints are not current modelling-bucket inputs.
- Keep broad host proxy policy separate from exact source-backed assignments,
  with proxy-derived rows remaining review-visible.

## Acceptable caveat

- Chikungunya fever: group-level `non-human primates` host evidence remains
  evidence-only; it is not expanded into local species-level assignments.
- Ebola virus disease: group-level `non-human primates` spillover/source-animal
  evidence remains evidence-only; it is not treated as natural-reservoir
  evidence for individual primate rows.
- Existing group-level vector rows such as `Culex spp.`, `Haemagogus spp.`,
  `Sabethes spp.`, `fleas`, `Mansonia spp.`, and `Ixodes spp.` are documented
  caveats, not automatic species-level propagation rules.

## Handoff note

- All 20 include diseases have reviewed role assignments. Remaining
  `missing_required_vector_sdm` flags are external SDM asset gaps, not
  species-role evidence blockers.
