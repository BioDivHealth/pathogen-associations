# Crimean-Congo Hemorrhagic Fever Role Review

Phase: `Phase V`
Started: `2026-05-08`
Last updated: `2026-06-25`

## Disease Scope And Local Candidate Counts

- Disease name: Crimean-Congo hemorrhagic fever
- Source pathogen or analysis unit: Orthonairovirus haemorrhagiae
- Host candidate rows: 13
- Vector candidate rows: 49
- Competence-linked vector rows: 30
- Local candidate snapshot: role roster, host candidates, vector competence annotated table, and `diseases/cchf/*_extractions.md`.

## Current Host Candidate Highlights

- Local host candidates include humans, livestock-like ruminants, rodents, a hedgehog, hare, tortoise, and broad goat/sheep entries.
- Source-backed rows added here support livestock as group-level amplifying hosts and humans as spillover/incidental hosts.
- Species-level livestock assignments were deferred.

## Current Vector Candidate Highlights

- Local vector candidates are dominated by `Hyalomma` ticks, with additional `Rhipicephalus`, `Dermacentor`, `Haemaphysalis`, `Amblyomma`, `Ixodes`, and `Ornithodoros` candidates.
- WHO supports `Hyalomma` as the principal vector genus.
- Non-`Hyalomma` and individual `Hyalomma` species remain deferred until source-specific review.

## Sources Searched

| Source | Type | URL or local path | Used for rows? | Notes |
|---|---|---|---|---|
| WHO CCHF fact sheet | Official factsheet | https://www.who.int/en/news-room/fact-sheets/detail/crimean-congo-haemorrhagic-fever | Yes | Supports human spillover routes and `Hyalomma` principal-vector genus. |
| CDC EID CCHF Virus in Cattle and Ticks Israel | Peer-reviewed article | https://wwwnc.cdc.gov/eid/article/31/11/25-0622_article | Yes | Supports livestock amplifying-host language. |
| Local CCHF extraction markdowns | Local curated extraction | `diseases/cchf/` | Background only | Used to identify deferred vector-species candidates. |

## Source-Backed Host Role Findings

| Host or group | Role claim | Evidence direction | Confidence | Manual review? | Evidence note |
|---|---|---|---|---|---|
| livestock | amplifying_host | supports | high | yes | Group-level livestock amplification. |
| Homo sapiens | incidental_host | supports | high | no | Human spillover from ticks or infected animal tissues. |

## Source-Backed Vector Role Findings

| Vector or group | Role claim | Evidence direction | Confidence | Manual review? | Evidence note |
|---|---|---|---|---|---|
| Hyalomma spp. | principal_vector_genus | supports | high | yes | Principal-vector genus, not automatic species assignment. |

## Rows Added To Evidence CSVs

- Host evidence rows: 2.
- Vector evidence rows: 1.

## Draft Assignments Added

- Host assignments: 2.
- Vector assignments: 1 group-level row.

## Deferred Candidates And Why

- Individual livestock species: group-level source only.
- Individual tick species: deferred to species-level CCHF vector review.
- Non-livestock animal candidates: host presence is not role evidence.

## Open Questions For Collaborator Review

- Whether to add a distinct vocabulary value for tick-as-reservoir versus vector.

## 2026-06-24 Species-Role Closeout

- Added source-backed host rows for `Struthio camelus` as a susceptible host and a broad `wild ungulates` susceptible-host breadcrumb.
- Added conservative host proxy rules: livestock species map to `reservoir_or_amplifying_host`; wild ungulates map to `susceptible_or_spillover_host`; remaining vertebrates stay `host_presence_only` unless source-backed rows exist.
- Added `Hyalomma asiaticum` as `competent_vector_only`, keeping it separate from main-vector `Hyalomma` rows.
- Regenerated roster, role features, role QA, readiness, and tiered-species handoff surfaces.
- Validated CCHF rows: 58 hosts, 49 vectors, 4 host evidence/assignment rows, 6 vector evidence/assignment rows, no CCHF unmatched vector assignments, no duplicate feature IDs, and tiered-species rows from `repo_pilot` only.
- Remaining `needs_review` flags are caveats for broad proxy, regional vector, taxonomy, or SDM availability context; missing SDM assets are not species-role blockers.

## 2026-06-25 Reviewed-Assignment Caveat Pass

- Fixed the vector role classifier so `enzootic_maintenance_vector` maps to `enzootic_or_sylvatic_vector` rather than matching `main` inside `maintenance`.
- This moved `Hyalomma lusitanicum` out of the CCHF primary-vector bucket and into the enzootic/sylvatic bucket.
- Remaining CCHF primary-vector rows are `Hyalomma anatolicum`, `Hyalomma marginatum`, `Hyalomma rufipes`, and `Hyalomma spp.`. They remain source-backed but review-visible because the strongest species-level source is regional or species-nuanced, while WHO supports `Hyalomma` at genus level.
