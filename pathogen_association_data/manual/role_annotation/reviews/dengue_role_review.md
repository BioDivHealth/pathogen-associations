# Dengue Role Review

Phase: `Phase V`
Started: `2026-05-08`
Last updated: `2026-06-25`

## Disease Scope And Local Candidate Counts

- Disease name: Dengue
- Source pathogen or analysis unit: Orthoflavivirus denguei
- Host candidate rows: 53
- Vector candidate rows: 16
- Competence-linked vector rows: 15
- Local candidate snapshot: `species_host_vector_roster.csv`, `host_role_candidates.csv`, `disease_vector_links_taxonomy_cleaned_competence_annotated.csv`, `diseases/dengue/dengue_vector_extractions.md`, and `diseases/dengue/dengue_vector_competence_extractions.md`.

## Current Host Candidate Highlights

- Local host candidates include humans, several non-human primates, bats, rodents, marsupials, carnivores, and tree shrews.
- Official-source evidence added in this pass supports humans as the amplifying host in the human-mosquito-human dengue transmission cycle.
- Non-human primate or other mammal candidates remain deferred because the current official row does not establish a global reservoir assignment.

## Current Vector Candidate Highlights

- Local vector candidates include confirmed `Aedes aegypti`, `Aedes albopictus`, several sylvatic `Aedes` species, and weaker `Culex quinquefasciatus` evidence.
- WHO source language supports `Aedes aegypti` as the primary vector and `Aedes albopictus` as a secondary-context vector.
- `Aedes albopictus` is recorded as `secondary_vector` with manual review so it maps to a secondary/epidemic-style modelling bucket rather than the primary/main bucket.
- `Aedes furcifer`, `Aedes luteocephalus`, and `Aedes taylori` are recorded as review-needed African sylvatic-vector rows; these are not global urban-vector claims.
- `Aedes polynesiensis` is recorded as a review-needed regional epidemic-vector row for Polynesia-context evidence.
- `Aedes vittatus` is recorded as `competent_vector_only` with manual review because current evidence supports dengue vectorial competence but not a primary dengue-vector role.

## Sources Searched

| Source | Type | URL or local path | Used for rows? | Notes |
|---|---|---|---|---|
| WHO Dengue and severe dengue fact sheet | Official public health factsheet | https://www.who.int/en/news-room/fact-sheets/detail/dengue-and-severe-dengue | Yes | Supports human-to-mosquito transmission and primary/secondary Aedes vector wording. |
| CDC How Dengue Spreads | Official public health guidance | https://www.cdc.gov/dengue/transmission/index.html | Background only | Confirms spread by infected `Aedes` mosquitoes including `Ae. aegypti` and `Ae. albopictus`. |
| CDC Yellow Book: Dengue | Official travel medicine guidance | https://www.cdc.gov/yellow-book/hcp/travel-associated-infections-diseases/dengue.html | Background only | Supports `Aedes aegypti` and `Aedes albopictus` vector context and human viremia cautions. |
| Dengue vectors in Africa: A review | Review | https://pubmed.ncbi.nlm.nih.gov/35620619/ | Yes | Supports African sylvatic-vector context for `Aedes furcifer`, `Aedes luteocephalus`, and `Aedes taylori`. |
| The transmission of dengue by Aedes polynesiensis Marks | Primary study | https://pubmed.ncbi.nlm.nih.gov/13197723/ | Yes | Supports regional experimental and epidemiological context for `Aedes polynesiensis`. |
| A new vector emerges? Aedes vittatus (Diptera: Culicidae) | Review | https://www.scielo.sa.cr/scielo.php?pid=S0034-77442024000100027&script=sci_arttext | Yes | Supports `Aedes vittatus` dengue vectorial competence but not a primary dengue-vector role. |
| Local dengue vector extraction markdown | Local curated extraction | `diseases/dengue/dengue_vector_extractions.md` | Background only | Used to identify candidate complexity and defer secondary or regional species. |
| Local dengue competence extraction markdown | Local curated extraction | `diseases/dengue/dengue_vector_competence_extractions.md` | Background only | Used to avoid assigning competence-only or field-prevalence-only species as final roles. |

## Source-Backed Host Role Findings

| Host or group | Role claim | Evidence direction | Confidence | Manual review? | Evidence note |
|---|---|---|---|---|---|
| Homo sapiens | amplifying_host | supports | high | no | WHO supports human-to-mosquito transmission during viremia. |

## Source-Backed Vector Role Findings

| Vector or group | Role claim | Evidence direction | Confidence | Manual review? | Evidence note |
|---|---|---|---|---|---|
| Aedes aegypti | primary_vector | supports | high | no | WHO describes this as the primary dengue vector. |
| Aedes albopictus | secondary_vector | supports | medium | yes | WHO says it can act as a vector but is normally secondary to `Ae. aegypti`. |
| Aedes furcifer | sylvatic_vector | supports | medium | yes | Review-based African sylvatic-vector row; not a global urban-vector claim. |
| Aedes luteocephalus | sylvatic_vector | supports | medium | yes | Review-based African sylvatic-vector row; not a global urban-vector claim. |
| Aedes polynesiensis | epidemic_vector | supports | medium | yes | Old but direct experimental and epidemiological evidence; Polynesia context. |
| Aedes taylori | sylvatic_vector | supports | medium | yes | Review-based African sylvatic-vector row; not a global urban-vector claim. |
| Aedes vittatus | competent_vector_only | supports | medium | yes | Review supports dengue vectorial competence but not primary-vector status. |

## Rows Added To Evidence CSVs

- Host evidence rows: 1 row added for human `amplifying_host`.
- Vector evidence rows: 7 source-backed rows represented for `Aedes aegypti`, `Aedes albopictus`, `Aedes furcifer`, `Aedes luteocephalus`, `Aedes polynesiensis`, `Aedes taylori`, and `Aedes vittatus`.

## Draft Assignments Added

- Host assignments: 1 row added for human `amplifying_host`.
- Vector assignments: 1 source-backed `primary_vector` row for `Aedes aegypti`, 1 `secondary_vector` row for `Aedes albopictus`, 3 African `sylvatic_vector` rows, 1 Polynesia-context `epidemic_vector` row, and 1 `competent_vector_only` row for `Aedes vittatus`. All non-primary rows retain manual-review caveats.

## Deferred Candidates And Why

- Non-human primates: deferred because no source-backed dengue reservoir assignment was added in this pass.
- Bat, rodent, marsupial, carnivore, and tree-shrew candidates: deferred because local host presence is not role evidence.
- `Aedes hensilli`: deferred because the primary dengue source was not locally checked; current local support is secondary and weaker.
- `Culex quinquefasciatus`: deferred as negative or weak field-detection evidence, not a role assignment.
- `Aedes mediovittatus`, `Aedes malayensis`, and related regional vectors: deferred for later source-specific review rather than global assignment.

## Open Questions For Collaborator Review

- Whether `Aedes albopictus` should eventually use a dedicated secondary-vector bucket; for now `secondary_vector` maps to the bridge/epidemic modelling bucket with a manual-review flag.
- Whether additional regional or sylvatic dengue vectors should be promoted from the source-hint queue. The current accepted rows are deliberately review-needed and do not imply global main-vector status.
