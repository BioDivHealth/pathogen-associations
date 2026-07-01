# Ebola Virus Disease Role Review

Phase: `Phase N`
Started: `2026-05-08`
Last updated: `2026-06-23`

## Disease Scope And Local Candidate Counts

- Disease name: Ebola virus disease
- Source pathogen or analysis unit: Orthoebolavirus zairense
- Host candidate rows: 19
- Vector candidate rows: 0
- Local candidate snapshot: `host_role_candidates.csv` and `species_host_vector_roster.csv`.

## Current Host Candidate Highlights

- Local candidates include humans, fruit bats, non-human primates, rodents, and other mammals.
- CDC source language supports African fruit bats as likely involved in orthoebolavirus ecology.
- Bounded species-level source check supports only three current bat rows as possible reservoirs; other bat rows remain presence-only.
- WHO source language supports non-human primates as infected source animals and humans as outbreak amplifying hosts.

## Current Vector Candidate Highlights

- `not_applicable_non_vectored_scope`: no vector rows are present in the current role-review surface and no arthropod vector role was identified in this pass.

## Sources Searched

| Source | Type | URL or local path | Used for rows? | Notes |
|---|---|---|---|---|
| CDC How Ebola Disease Spreads | Official guidance | https://www.cdc.gov/ebola/causes/index.html | Yes | Supports likely African fruit bat source/reservoir group. |
| WHO Ebola disease fact sheet | Official factsheet | https://www.who.int/news-room/fact-sheets/detail/ebola-disease | Yes | Supports Pteropodidae natural-host framing, animal spillover examples, and human-to-human transmission. |
| Leroy et al. 2005 / Pourrut et al. 2007 / Biek et al. 2006 | Peer-reviewed bat reservoir evidence and synthesis | https://doi.org/10.1038/438575a; https://doi.org/10.1086/520541; https://journals.plos.org/plospathogens/article?id=10.1371/journal.ppat.0020090 | Yes | Supports caveated species-level possible-reservoir assignments for `Epomops franqueti`, `Hypsignathus monstrosus`, and `Myonycteris torquata`; does not justify a broad Pteropodidae proxy. |

## Source-Backed Host Role Findings

| Host or group | Role claim | Evidence direction | Confidence | Manual review? | Evidence note |
|---|---|---|---|---|---|
| African fruit bats | reservoir_host_group | supports | medium | yes | Likely reservoir/source group. |
| `Epomops franqueti` | reservoir_host | supports | medium | yes | Possible species-level reservoir support from natural infection / antibody evidence; caveated. |
| `Hypsignathus monstrosus` | reservoir_host | supports | medium | yes | Possible species-level reservoir support from natural infection / antibody evidence; caveated. |
| `Myonycteris torquata` | reservoir_host | supports | medium | yes | Possible species-level reservoir support from natural infection / antibody evidence; caveated. |
| non-human primates | spillover_host | supports | medium | yes | Source animals but not treated as natural reservoir. |
| Homo sapiens | amplifying_host | supports | high | no | Human-to-human outbreak transmission. |

## Source-Backed Vector Role Findings

No vector role evidence added; vector role evidence is not applicable in the current non-vectored scope.

## Rows Added To Evidence CSVs

- Host evidence rows: 8.
- Vector evidence rows: 0.

## Draft Assignments Added

- Host assignments: 7 rows for African fruit bats, three possible reservoir bat species, great-ape spillover/source hosts, and humans.
- Vector assignments: 0.

## Deferred Candidates And Why

- Other individual bat species: source support is currently group-level, serology-only, or too indirect for exact reservoir assignment.
- Individual non-human primate species: spillover/source role only and needs species-specific review.
- Rodents and other mammals: local host presence is not role evidence.

## Open Questions For Collaborator Review

- Broader Pteropodidae proxy remains deliberately omitted unless collaborators want a sensitivity-only broad bat fallback.
