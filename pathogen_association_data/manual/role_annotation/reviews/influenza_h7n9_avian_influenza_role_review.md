# Influenza H7N9 Avian Influenza Role Review

Phase: `Phase N`
Started: `2026-06-22`
Last updated: `2026-06-22`

## Disease Scope And Local Candidate Counts

- Disease name: Influenza (H7N9 avian influenza)
- Source pathogen or analysis unit: Alphainfluenzavirus influenzae (H7N9)
- Host candidate rows: 559
- Vector candidate rows: 0
- Competence-linked vector rows: 0
- Local candidate snapshot: large host-only candidate set dominated by avian hosts, with poultry, human, mammal spillover, and broad wild-aquatic-bird proxy rows.

## Current Host Candidate Highlights

- `Gallus gallus` is present as a domestic poultry candidate and is supported as an H7N9 poultry-market source or amplifying host.
- `Coturnix japonica` is present as a poultry candidate and is supported as an H7N9 source or amplifying host in experimental and poultry-market evidence.
- `Homo sapiens` is present as a local candidate and is treated as an incidental zoonotic endpoint because sustained human-to-human transmission is not demonstrated.
- Wild aquatic birds remain broad avian-influenza group proxies unless a source-backed species-level H7N9 role row is added.

## Handoff Note

H7N9 has exact source-backed roles for `Gallus gallus`, `Coturnix japonica`,
and `Homo sapiens`. Wild aquatic bird rows in generated role features are broad
avian-influenza group proxies (`host_role_evidence_basis = disease_group_proxy`),
not species-level reviewed reservoir assignments. Exact source-backed rows
override proxy rows.

## Current Vector Candidate Highlights

- `not_applicable_non_vectored_scope`: no current disease-vector rows are present for this Phase N disease.

## Sources Searched

| Source | Type | URL or local path | Used for rows? | Notes |
|---|---|---|---|---|
| USDA ARS Role of poultry in the spread of novel H7N9 influenza virus in China | official research summary | https://www.ars.usda.gov/research/publications/publication/?seqNo115=293916 | yes | Used for `Gallus gallus` and `Coturnix japonica` poultry source and shedding rows. |
| PubMed Pantin-Jackwood et al. 2014 | peer-reviewed experimental study abstract | https://pubmed.ncbi.nlm.nih.gov/24574407/ | yes | Used for Japanese quail infection, shedding, and transmission support. |
| ECDC Factsheet on A(H7N9) | public-health factsheet | https://www.ecdc.europa.eu/en/zoonotic-influenza/facts/faq-H7N9 | yes | Used for live-bird-market amplification and chicken detection context. |
| WHO Avian influenza A(H7N9) virus outbreak | official public-health guidance | https://www.who.int/emergencies/situations/avian-influenza-a-%28h7n9%29-virus-outbreak | yes | Used for human exposure and spillover framing. |
| CDC Asian lineage H7N9 virus archive | official public-health archive | https://archive.cdc.gov/www_cdc_gov/flu/avianflu/h7n9-virus.htm | yes | Used for human infection and no sustained person-to-person transmission framing. |

## Source-Backed Host Role Findings

| Host or group | Role claim | Evidence direction | Confidence | Manual review? | Evidence note |
|---|---|---|---|---|---|
| `Gallus gallus` | `amplifying_host` | supports | medium | yes | Chickens are supported as H7N9 poultry source or amplification hosts in live-market ecology. |
| `Coturnix japonica` | `amplifying_host` | supports | medium | yes | Japanese quail are supported by experimental infection/shedding evidence and poultry-market source framing. |
| `Homo sapiens` | `incidental_host` | supports | high | no | Human infections are zoonotic endpoints linked mostly to poultry or contaminated environments; sustained human-to-human transmission is not demonstrated. |

## Source-Backed Vector Role Findings

| Vector or group | Role claim | Evidence direction | Confidence | Manual review? | Evidence note |
|---|---|---|---|---|---|
| not applicable | `not_applicable_non_vectored_scope` | not applicable | not applicable | no | Phase N host-only review; no vector rows added. |

## Rows Added To Evidence CSVs

- Host evidence rows: 3
- Vector evidence rows: 0

## Draft Assignments Added

- Host assignments: 3
- Vector assignments: 0

## Deferred Candidates And Why

- Wild aquatic bird species-level assignments: deferred because the reviewed support is broad avian-influenza ecology or group-proxy evidence, not exact H7N9 species-level reservoir assignment.
- Other galliforms and poultry species: deferred unless source-backed evidence supports exact H7N9 host role rows beyond broad poultry ecology.
- Mammalian host candidates other than humans: deferred unless source-backed evidence supports a role beyond infection, exposure, or host presence.

## Open Questions For Collaborator Review

- Whether future avian-influenza role vocabulary should distinguish live-poultry-market source or amplification hosts from natural reservoirs.
- Whether any exact wild-bird H7N9 rows should be promoted after a dedicated species-level review.
