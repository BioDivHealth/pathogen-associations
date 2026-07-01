# Nipah Virus Disease Role Review

Phase: `Phase N`
Started: `2026-05-08`
Last updated: `2026-06-23`

## Disease Scope And Local Candidate Counts

- Disease name: Nipah virus disease
- Source pathogen or analysis unit: Henipavirus nipahense
- Host candidate rows: 34
- Vector candidate rows: 0
- Local candidate snapshot: `host_role_candidates.csv` and `species_host_vector_roster.csv`.

## Current Host Candidate Highlights

- Local candidates include humans, multiple `Pteropus` fruit bat species or groups, pigs, cattle, goats, dogs, cats, and a rodent.
- WHO supports Pteropodidae fruit bats as natural hosts; CDC frames Nipah as carried by fruit bats in genus `Pteropus`.
- WHO also supports infection from pigs and related pig-farm control measures; this was mapped to local domestic pig as an amplifying/intermediate host.
- Human-to-human transmission is recognized but context-dependent.
- Source-checked species-level `Pteropus` rows now cover `Pteropus hypomelanus`, `Pteropus vampyrus`, `Pteropus lylei`, and `Pteropus medius`; other bat rows remain host-presence-only unless exact source-backed role evidence is checked.

## Current Vector Candidate Highlights

- `not_applicable_non_vectored_scope`: no vector rows are present and no vector role was identified.

## Sources Searched

| Source | Type | URL or local path | Used for rows? | Notes |
|---|---|---|---|---|
| WHO Nipah virus fact sheet | Official factsheet | https://www.who.int/news-room/fact-sheets/detail/nipah-virus | Yes | Supports Pteropodidae natural host, pig/human transmission, and human-to-human control concerns. |
| CDC About Nipah Virus | Official guidance | https://www.cdc.gov/nipah-virus/about/index.html | Background only | Confirms fruit bat reservoir and animal contact routes. |
| Pteropid bats reservoir study | Peer-reviewed article | https://pmc.ncbi.nlm.nih.gov/articles/PMC3205647/ | Background only | Supports genus-level Pteropus reservoir framing and existing species-level row context. |
| CDC EID Pteropus lylei article | Peer-reviewed article | https://wwwnc.cdc.gov/eid/article/8/9/01-0515_article | Background only | Supports cautious treatment of Pteropus lylei evidence as regional/species-level and review-needed. |
| Madagascar pteropodid bat serology | Peer-reviewed article | https://pasteur.hal.science/pasteur-01835678/ | No | Serology/cross-reactivity for `Pteropus rufus` and other Malagasy bats is not enough to promote exact reservoir assignment. |

## Source-Backed Host Role Findings

| Host or group | Role claim | Evidence direction | Confidence | Manual review? | Evidence note |
|---|---|---|---|---|---|
| Pteropus spp. | reservoir_host_group | supports | high | yes | Group-level fruit bat natural host evidence. |
| Sus scrofa | amplifying_host | supports | high | no | Pig-farm outbreak and animal transmission evidence. |
| Homo sapiens | amplifying_host | supports | medium | yes | Human-to-human transmission is context-dependent. |
| Pteropus hypomelanus | reservoir_host | supports | high | yes | Direct species-level natural-host support from source-checked local PDF text; Malaysia/Island flying fox context. |
| Pteropus vampyrus | reservoir_host | supports | high | yes | Direct species-level natural infection/recrudescence support from source-checked local PDF text; Malaysia context. |
| Pteropus lylei | reservoir_host | supports | medium | yes | Regional species-level evidence from Cambodia/Thailand sources; keep geography caveat visible. |
| Pteropus medius | reservoir_host | supports | medium | yes | Regional species-level evidence from Kerala/India sources; keep geography caveat visible. |

## Source-Backed Vector Role Findings

No vector role evidence added; vector role evidence is not applicable in the current non-vectored scope.

## Rows Added To Evidence CSVs

- Host evidence rows: 7.
- Vector evidence rows: 0.

## Draft Assignments Added

- Host assignments: 7.
- Vector assignments: 0.

## Deferred Candidates And Why

- Remaining bat candidates, including other pteropodids and unchecked `Pteropus` rows: detection, serology, or group-level evidence only; no broad proxy rule added.
- Cattle, goats, dogs, cats, horses, and rodent candidates: local host presence is not enough to assign role.

## Open Questions For Collaborator Review

- The unmatched `Pteropus spp.` assignment is intentionally group-level context and does not propagate to species rows.
- Remaining `needs_review` flags are geography/source caveats for usable role rows, not blockers for the modelling handoff.
