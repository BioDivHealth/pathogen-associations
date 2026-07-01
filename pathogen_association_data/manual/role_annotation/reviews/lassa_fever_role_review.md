# Lassa Fever Role Review

Phase: `Phase N`
Started: `2026-05-08`
Last updated: `2026-06-23`

## Disease Scope And Local Candidate Counts

- Disease name: Lassa fever
- Source pathogen or analysis unit: Mammarenavirus lassaense
- Host candidate rows: 21
- Vector candidate rows: 0
- Competence-linked vector rows: 0
- Local candidate snapshot: host-only disease in the current role review scope.

## Current Host Candidate Highlights

- `Mastomys natalensis` is present as a local host candidate and matches the official reservoir source at species level.
- `Homo sapiens` is present as a local host candidate; human-to-human transmission is documented but context-dependent.
- `Hylomyscus pamfi` and `Mastomys erythroleucus` have source-backed species-level reservoir assignments from the source-check import; both remain region-specific and less canonical than `Mastomys natalensis`.
- `Mus baoulei` has new 2026 species-level evidence for active LASV viremia in Benin and is treated as a caveated reservoir candidate for modelling.
- Other rodent candidates remain candidate-only unless source-backed role evidence supports species-level assignment.

## Current Vector Candidate Highlights

- `not_applicable_non_vectored_scope`: no current disease-vector rows are present for this Phase N disease.

## Sources Searched

| Source | Type | URL or local path | Used for rows? | Notes |
|---|---|---|---|---|
| WHO Lassa fever fact sheet | official public health factsheet | https://www.who.int/en/news-room/fact-sheets/detail/lassa-fever | yes | Used for Mastomys reservoir and context-dependent human transmission rows. |
| New Hosts of The Lassa Virus | primary study | https://pubmed.ncbi.nlm.nih.gov/27140942/ | yes | Source-check import supports `Hylomyscus pamfi` and `Mastomys erythroleucus` as additional reservoir species with regional caveats. |
| Systematics, Ecology, and Host Switching: Attributes Affecting Emergence of the Lassa Virus in Rodents across Western Africa | review | https://www.mdpi.com/1999-4915/12/3/312 | yes | Review synthesis used by source-check import for additional reservoir species. |
| Non-Mastomys rodents harbour ancient Lassa virus lineages within Benin and Nigeria's Guinea savanna belt | primary study | https://www.nature.com/articles/s41598-026-51525-8 | yes | Used for a caveated `Mus baoulei` reservoir assignment; early-access 2026 species-level viremia/lineage evidence from Benin. |
| Local host role candidates | local candidate table | `pathogen_association_data/evidence/role_annotation/host_role_candidates.csv` | yes | Used to verify local candidate presence and tax_id. |

## Source-Backed Host Role Findings

| Host or group | Role claim | Evidence direction | Confidence | Manual review? | Evidence note |
|---|---|---|---|---|---|
| `Mastomys natalensis` | `reservoir_host` | supports | high | no | WHO describes Mastomys rats as the main reservoir of Lassa virus. |
| `Homo sapiens` | `amplifying_host` | supports | medium | yes | WHO describes human-to-human transmission prevention in health-care settings; assignment remains context-dependent. |
| `Hylomyscus pamfi` | `reservoir_host` | supports | medium | yes | Source-check import supports a newer/additional reservoir species with regional caveat. |
| `Mastomys erythroleucus` | `reservoir_host` | supports | medium | yes | Source-check import supports an additional reservoir species with regional caveat. |
| `Mus baoulei` | `reservoir_host` | supports | medium | yes | 2026 early-access paper reports active LASV viremia and lineage VIII in Benin; treat as a caveated non-`Mastomys` reservoir candidate. |

## Source-Backed Vector Role Findings

| Vector or group | Role claim | Evidence direction | Confidence | Manual review? | Evidence note |
|---|---|---|---|---|---|
| not applicable | `not_applicable_non_vectored_scope` | not applicable | not applicable | no | Phase N host-only review; no vector rows added. |

## Rows Added To Evidence CSVs

- Host evidence rows: 5
- Vector evidence rows: 0

## Draft Assignments Added

- Host assignments: 5
- Vector assignments: 0

## Deferred Candidates And Why

- Other local rodent candidates: deferred because reviewed sources do not support broad species-level reservoir assignment to every rodent candidate.

## Open Questions For Collaborator Review

- Whether human Lassa fever should remain `amplifying_host` with manual review or use a more outbreak-context-specific final label.
- Whether the 2026 `Mus baoulei` row should remain `reservoir_host` with manual review or be downgraded if collaborators require stronger maintenance-host evidence than field viremia plus lineage/ecology context.
