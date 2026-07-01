# Yellow Fever Role Review

Phase: `Phase V`
Started: `2026-05-08`
Last updated: `2026-06-25`

## Disease Scope And Local Candidate Counts

- Disease name: Yellow fever
- Source pathogen or analysis unit: Yellow fever virus
- Host candidate rows: 73
- Vector candidate rows: 30
- Competence-linked vector rows: 30
- Local candidate snapshot: `species_host_vector_roster.csv`, `host_role_candidates.csv`, `disease_vector_links_taxonomy_cleaned_competence_annotated.csv`, `diseases/yf/yellow_fever_vector_extractions.md`, and `diseases/yf/yellow_fever_vector_competence_extractions.md`.

## Current Host Candidate Highlights

- Local host candidates are dominated by primates: `Homo sapiens`, multiple `Alouatta`, `Callithrix`, `Sapajus`, and other non-human primate rows.
- Official-source role evidence supports non-human primates only at group level for sylvatic maintenance/reservoir logic.
- Human role evidence is urban-cycle specific: humans participate in human-mosquito-human transmission with `Aedes aegypti`, but this does not make humans a sylvatic reservoir.

## Current Vector Candidate Highlights

- Local vector candidates include confirmed `Aedes aegypti`, multiple African sylvatic `Aedes` species, `Haemagogus janthinomys`, `Haemagogus leucocelaenus`, and `Sabethes` species.
- Official-source rows were added only for the strongest cycle-level claims: `Aedes aegypti` as urban `main_vector`, `Aedes africanus` as `sylvatic_vector`, and group-level `Haemagogus spp.` plus `Sabethes spp.` as `sylvatic_vector`.
- Source-checked outbreak evidence also supports `Haemagogus janthinomys` and `Haemagogus leucocelaenus` as review-needed sylvatic/outbreak vector rows.
- Species-heavy vector extraction rows remain useful supporting context, but most should not become role assignments without source-specific review of geography, cycle, and wording.

## Sources Searched

| Source | Type | URL or local path | Used for rows? | Notes |
|---|---|---|---|---|
| CDC Transmission of Yellow Fever Virus | Official public health guidance | https://www.cdc.gov/yellow-fever/php/transmission/index.html | Yes | Supports non-human primate sylvatic cycle, human urban cycle, and `Aedes aegypti` urban-vector role. |
| CDC Yellow Book: Yellow Fever | Official travel medicine guidance | https://www.cdc.gov/yellow-book/hcp/travel-associated-infections-diseases/yellow-fever.html | Yes | Supports `Aedes africanus`, `Haemagogus spp.`, and `Sabethes spp.` in sylvatic cycle context. |
| WHO Yellow fever fact sheet | Official public health factsheet | https://www.who.int/news-room/fact-sheets/detail/yellow-fever | Yes | Supports broad `Aedes`, `Haemagogus`, and `Sabethes` vector evidence. |
| PAHO Yellow Fever topic page | Official regional public health source | https://www.paho.org/en/topics/yellow-fever | Background only | Useful Americas-focused wording, but no additional CSV row was needed after CDC/WHO rows. |
| Haemagogus leucocelaenus and Haemagogus janthinomys are the primary vectors in the major yellow fever outbreak in Brazil, 2016-2018 | Primary outbreak study | https://pubmed.ncbi.nlm.nih.gov/30866775/ | Yes | Supports species-level `Haemagogus janthinomys` and `Haemagogus leucocelaenus` sylvatic/outbreak vector rows with Brazil Atlantic Forest caveat. |
| Local yellow fever vector extraction markdown | Local curated extraction | `diseases/yf/yellow_fever_vector_extractions.md` | Background only | Used to understand candidate vector complexity and deferred species-level role claims. |
| Local yellow fever competence extraction markdown | Local curated extraction | `diseases/yf/yellow_fever_vector_competence_extractions.md` | Background only | Used to avoid treating competence-only rows as final role assignments. |

## Source-Backed Host Role Findings

| Host or group | Role claim | Evidence direction | Confidence | Manual review? | Evidence note |
|---|---|---|---|---|---|
| non-human primates | reservoir_host_group | supports | high | yes | CDC supports sylvatic cycling between non-human primates and forest mosquitoes. |
| Homo sapiens | amplifying_host | supports | medium | no | CDC supports humans in the urban human-mosquito-human cycle; assignment is cycle-specific. |

## Source-Backed Vector Role Findings

| Vector or group | Role claim | Evidence direction | Confidence | Manual review? | Evidence note |
|---|---|---|---|---|---|
| Aedes aegypti | main_vector | supports | high | no | CDC supports `Aedes aegypti` as the primary urban mosquito vector. |
| Aedes africanus | sylvatic_vector | supports | high | yes | CDC Yellow Book places this species in the sylvatic forest-canopy context. |
| Haemagogus janthinomys | sylvatic_vector | supports | high | yes | Brazil outbreak evidence supports species-level sylvatic/outbreak vector role; geography-specific caveat retained. |
| Haemagogus leucocelaenus | sylvatic_vector | supports | high | yes | Brazil outbreak evidence supports species-level sylvatic/outbreak vector role; geography-specific caveat retained. |
| Haemagogus spp. | sylvatic_vector | supports | high | yes | WHO and CDC support genus-level sylvatic vector evidence; keep group-level. |
| Sabethes spp. | sylvatic_vector | supports | high | yes | WHO and CDC support genus-level sylvatic vector evidence; keep group-level. |

## Rows Added To Evidence CSVs

- Host evidence rows: 2 rows added for non-human primates and humans.
- Vector evidence rows: 6 rows represented for `Aedes aegypti`, `Aedes africanus`, `Haemagogus janthinomys`, `Haemagogus leucocelaenus`, `Haemagogus spp.`, and `Sabethes spp.`.

## Draft Assignments Added

- Host assignments: 2 rows added for human urban-cycle `amplifying_host` and group-level non-human-primate `reservoir_host_group`.
- Vector assignments: 6 rows represented. Species-level `Haemagogus janthinomys` and `Haemagogus leucocelaenus` match generated feature rows; group-level `Haemagogus spp.` and `Sabethes spp.` remain intentionally unmatched context rows.

## 2026-06-25 Completion Pass

- Added a broad Yellow fever non-human-primate proxy rule for rows with generated `host_order = Primates`.
- Added tax-id rescue proxy rows for current non-human-primate roster rows whose generated taxonomy is blank.
- Kept `Homo sapiens` on the exact urban-cycle `amplifying_host` assignment; the primate proxy remains broad, review-visible, and does not turn each primate row into a species-level source-backed claim.
- Left bats, sloths, rodents, ungulates, and other vertebrate rows as `host_presence_only`.
- Current vector buckets already keep `Aedes aegypti` as the reviewed urban/main vector, `Aedes africanus` and source-checked `Haemagogus` species as sylvatic vectors, and weaker or mixed mosquito rows as source-hint or direct-association caveats.

## Deferred Candidates And Why

- Individual non-human primate species: deferred because official-source evidence is group-level.
- Additional African `Aedes` species: deferred until species-specific role wording is reviewed from local review papers or primary sources.
- `Aedes albopictus`: deferred because local evidence is mixed or potential bridge-vector evidence, not a stable official role assignment.
- Additional individual `Haemagogus` and `Sabethes` species beyond source-checked `Haemagogus janthinomys` and `Haemagogus leucocelaenus`: deferred unless local source rows are promoted after checking geography and wording.
- `Anopheles funestus` and other positive-only taxa: deferred because field detection or review positivity alone is not role evidence.

## Open Questions For Collaborator Review

- Whether `Aedes albopictus` should remain `candidate_vector`, `bridge_vector`, or evidence-only after a closer review of the yellow fever competence and bridge-vector papers.
