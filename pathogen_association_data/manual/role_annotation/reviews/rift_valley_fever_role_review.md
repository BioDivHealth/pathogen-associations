# Rift Valley Fever Role Review

Phase: `Phase V`
Started: `2026-05-08`
Last updated: `2026-06-25`

## Disease Scope And Local Candidate Counts

- Disease name: Rift Valley fever
- Source pathogen or analysis unit: Phlebovirus riftense
- Host candidate rows: 41
- Vector candidate rows: 78
- Competence-linked vector rows: 72
- Local candidate snapshot: `species_host_vector_roster.csv`, `host_role_candidates.csv`, `disease_vector_links_taxonomy_cleaned_competence_annotated.csv`, `diseases/rvf/rvf_vector_extractions.md`, and `diseases/rvf/rvf_vector_competence_extractions.md`.

## Current Host Candidate Highlights

- Local host candidates include humans, cattle, sheep, goats, camels, buffalo, antelope, bats, and a rodent row.
- WHO source language supports group-level livestock disease/amplification and human spillover/incidental infection.
- Species-level livestock assignments are limited to sheep, goats, cattle, camel, and domestic buffalo where source support is explicit enough for modelling; wild ruminants and other vertebrates remain presence-only candidates.

## Current Vector Candidate Highlights

- The local vector roster is broad, with many mosquito species and a few weak tick rows.
- WHO source language supports vertical maintenance in `Aedes` mosquitoes and ruminant amplification via local competent mosquitoes including `Culex`, `Mansonia`, and `Anopheles`.
- `Aedes mcintoshi` and `Culex poicilipes` have source-backed species rows, but both remain review-needed because their role claims are review-derived and geographically/ecologically bounded.
- Genus-level vector rows remain caveated. `Mansonia spp.` is intentionally unmatched to species-level roster rows; do not automatically propagate it to all `Mansonia` species.

## Sources Searched

| Source | Type | URL or local path | Used for rows? | Notes |
|---|---|---|---|---|
| WHO Rift Valley fever fact sheet | Official public health factsheet | https://www.who.int/en/news-room/fact-sheets/detail/rift-valley-fever | Yes | Supports livestock amplification, human spillover, `Aedes` vertical maintenance, and `Culex`/`Mansonia`/`Anopheles` mechanical-vector wording. |
| CDC About Rift Valley Fever | Official public health guidance | https://www.cdc.gov/rift-valley-fever/about/index.html | Background only | Confirms mosquito and infected animal tissue exposure pathways. |
| FAO Rift Valley fever page | Official veterinary source | https://www.fao.org/animal-health/animal-diseases/rift-valley-fever/en | Background only | Confirms livestock risk and mosquito vector genera. |
| WOAH Rift Valley fever page | Official animal health guidance | https://www.woah.org/en/disease/rift-valley-fever/ | Yes | Supports susceptible domestic-buffalo wording without upgrading buffalo to an amplifying host. |
| Rift Valley Fever - a Growing Threat To Humans and Animals | Peer-reviewed review | https://pmc.ncbi.nlm.nih.gov/articles/PMC8009587/ | Yes | Supports review-derived species rows for `Aedes mcintoshi` and `Culex poicilipes`. |
| Local RVF vector extraction markdown | Local curated extraction | `diseases/rvf/rvf_vector_extractions.md` | Background only | Used to identify candidate vector breadth and defer species promotion. |
| Local RVF competence extraction markdown | Local curated extraction | `diseases/rvf/rvf_vector_competence_extractions.md` | Background only | Used to avoid treating competence-only rows as final role assignments. |

## Source-Backed Host Role Findings

| Host or group | Role claim | Evidence direction | Confidence | Manual review? | Evidence note |
|---|---|---|---|---|---|
| ruminant livestock | amplifying_host | supports | high | yes | WHO supports amplification in naive ruminants. |
| Homo sapiens | incidental_host | supports | high | no | WHO supports human infection through animal tissues or mosquito bites; not maintenance. |
| Camelus dromedarius | amplifying_host | supports | medium | yes | WHO and review sources support camel as part of the RVF livestock host set, but source wording is less specific than for sheep/goats. |
| Bubalus bubalis | susceptible_host_only | supports | medium | yes | CDC/WOAH support domestic buffalo susceptibility; not promoted to amplifier. |

## Source-Backed Vector Role Findings

| Vector or group | Role claim | Evidence direction | Confidence | Manual review? | Evidence note |
|---|---|---|---|---|---|
| Aedes spp. | enzootic_maintenance_vector | supports | high | yes | WHO supports vertical maintenance in `Aedes` mosquitoes. |
| Aedes mcintoshi | enzootic_maintenance_vector | supports | medium | yes | Review-based species row; maintenance wording is ecological synthesis rather than a global primary-vector claim. |
| Culex poicilipes | epidemic_vector | supports | medium | yes | Review-based regional epidemic-vector row; not promoted to primary/main vector. |
| Culex spp. | mechanical_vector | supports | medium | yes | WHO lists `Culex` among local competent mosquitoes acting as mechanical vectors. |
| Mansonia spp. | mechanical_vector | supports | medium | yes | WHO lists `Mansonia` among local competent mosquitoes acting as mechanical vectors. |
| Anopheles spp. | mechanical_vector | supports | medium | yes | WHO lists `Anopheles` among local competent mosquitoes acting as mechanical vectors. |

## Rows Added To Evidence CSVs

- Host evidence rows: initial 2 rows added for ruminant livestock and humans; completion pass added camel and domestic buffalo species rows.
- Vector evidence rows: 6 rows represented for `Aedes spp.`, `Aedes mcintoshi`, `Culex poicilipes`, `Culex spp.`, `Mansonia spp.`, and `Anopheles spp.`.

## Draft Assignments Added

- Host assignments: initial 2 rows added; completion pass added camel and domestic buffalo species rows.
- Vector assignments: 6 rows represented. Five match generated vector feature rows; `Mansonia spp.` remains an intentionally unmatched genus-level caveat.

## Deferred Candidates And Why

- Wild ruminants and other vertebrate candidates: retained as presence-only unless source-backed species role evidence is added later.
- Wildlife and bat candidates: deferred because the official-source pass did not support source-backed role rows.
- Individual mosquito species such as `Aedes vexans`, `Culex pipiens`, and many other competence-supported rows: deferred unless source-backed species role review justifies promotion.
- Tick rows: deferred because current evidence is weak and not part of the official-source vector role row.

## Open Questions For Collaborator Review

- Whether RVF should distinguish `enzootic_maintenance_vector` from `transovarial_maintenance_vector` in the vocabulary.
- Whether additional species-level RVF vector assignments should be promoted from the source-hint queue in a separate, species-focused pass. Current source-hint rows remain competence-supported fallback unless reviewed assignments promote them.
