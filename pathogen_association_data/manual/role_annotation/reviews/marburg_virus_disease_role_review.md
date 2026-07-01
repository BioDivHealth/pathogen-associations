# Marburg Virus Disease Role Review

Phase: `Phase N`
Started: `2026-05-08`
Last updated: `2026-06-22`

## Disease Scope And Local Candidate Counts

- Disease name: Marburg virus disease
- Source pathogen or analysis unit: Orthomarburgvirus marburgense
- Host candidate rows: 12
- Vector candidate rows: 0
- Local candidate snapshot: `host_role_candidates.csv` and `species_host_vector_roster.csv`.

## Current Host Candidate Highlights

- Local candidates include humans, `Rousettus aegyptiacus`, other bats, `Chlorocebus aethiops`, `Pongo pygmaeus`, and rodents.
- WHO and CDC support `Rousettus aegyptiacus` as the natural reservoir host, with human infection followed by human-to-human transmission.
- Human-to-human transmission supports human outbreak amplification.
- `Chlorocebus aethiops` is retained as a historical laboratory-associated source-animal/incidental row, not reservoir evidence.

## Current Vector Candidate Highlights

- `not_applicable_non_vectored_scope`: no vector rows are present and no vector role was identified.

## Sources Searched

| Source | Type | URL or local path | Used for rows? | Notes |
|---|---|---|---|---|
| WHO Marburg virus disease fact sheet | Official factsheet | https://www.who.int/docs/default-source/documents/guidelines/marburg-fact-sheet-en-20-oct-2017.pdf?sfvrsn=1681fd69_2 | Yes | Supports `Rousettus aegyptiacus` natural host. |
| WHO Marburg virus disease fact sheet | Official factsheet | https://www.who.int/news-room/fact-sheets/detail/marburg-virus-disease | Background | Confirms `Rousettus aegyptiacus` natural host, human-to-human transmission, and African green monkey source-animal history. |
| CDC About Marburg | Official factsheet | https://www.cdc.gov/marburg/about/index.html | Background | Confirms Egyptian rousette bat spillover to people and person-to-person spread. |
| CDC History of Marburg Outbreaks | Official outbreak history | https://www.cdc.gov/marburg/outbreaks/index.html | Background | Confirms 1967 laboratory-worker outbreak linked to African green monkeys imported from Uganda. |
| Isolation of Genetically Diverse Marburg Viruses from Egyptian Fruit Bats | Peer-reviewed article | https://journals.plos.org/plospathogens/article?id=10.1371/journal.ppat.1000536 | Background | Primary evidence supporting `Rousettus aegyptiacus` as a major natural reservoir/source. |
| Systematic review on Marburg virus prevalence and persistence in bats | Peer-reviewed review | https://pmc.ncbi.nlm.nih.gov/articles/PMC12913193/ | Background | Supports keeping non-`Rousettus aegyptiacus` bat detections/serology as caveated host-presence rows unless stronger role evidence is reviewed. |
| Marburg Virus Disease - StatPearls | Peer-reviewed clinical review | https://www.ncbi.nlm.nih.gov/books/NBK578176/ | Yes | Supports human-to-human transmission through bodily fluids. |
| CDC EID Egyptian rousette bat spillover paper | Peer-reviewed article | https://wwwnc.cdc.gov/eid/article/29/11/23-0362_article | Background only | Confirms repeated detection/isolation in Egyptian rousette bats. |

## Source-Backed Host Role Findings

| Host or group | Role claim | Evidence direction | Confidence | Manual review? | Evidence note |
|---|---|---|---|---|---|
| Rousettus aegyptiacus | reservoir_host | supports | high | no | Species-level natural host evidence. |
| Homo sapiens | amplifying_host | supports | high | no | Human-to-human outbreak transmission. |
| Chlorocebus aethiops | incidental_host | supports | medium | yes | Historical/laboratory-associated source-animal role; not reservoir evidence. |

## Source-Backed Vector Role Findings

No vector role evidence added; vector role evidence is not applicable in the current non-vectored scope.

## Rows Added To Evidence CSVs

- Host evidence rows: 3.
- Vector evidence rows: 0.

## Draft Assignments Added

- Host assignments: 3.
- Vector assignments: 0.

## Deferred Candidates And Why

- Other bat species: deferred because source-backed reservoir evidence is strongest for `Rousettus aegyptiacus`; RNA/serology in other exact roster bats remains host-presence evidence, not reservoir assignment.
- Rodent candidates: local host presence or laboratory/model-organism evidence is not field role evidence.
- `Pongo pygmaeus`: retained as host-presence only; no source-backed Marburg reservoir, amplifying, or source-animal role was identified in this pass.

## Open Questions For Collaborator Review

- No broad `Rousettus` or Pteropodidae proxy rule was added. The species-level `Rousettus aegyptiacus` reservoir assignment is sufficient for the current roster and avoids upgrading antibody-only or occasional-detection bat rows.
- Remaining `needs_review` rows are modelling caveats for candidate-only host-presence rows or the historical `Chlorocebus aethiops` source-animal row, not blockers for role use.

## Completion Audit 2026-06-22

- Generated roster: 12 host rows and 0 vector rows.
- Host features: 2 exact source-backed reservoir/amplifying rows, 1 exact source-backed incidental row, and 9 candidate-only host-presence rows.
- Vector features: no rows; this matches the non-vectored readiness scope.
- Tiered species handoff: 12 `repo_pilot` host rows, with the same host buckets as `role_modelling_features.csv`.
- Source-backed evidence and assignments: all 3 Marburg host evidence rows have matching same-role assignments; no vector evidence or assignments are expected.
- Proxy policy: no Marburg host proxy rule needed.
- Tracker decision: role-done for the current modelling handoff, with caveats retained in generated `needs_review` fields.
