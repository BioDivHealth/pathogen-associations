# Plague Role Review

Phase: `Phase V`
Started: `2026-05-08`
Last updated: `2026-06-23`

## Disease Scope And Local Candidate Counts

- Disease name: Plague
- Source pathogen or analysis unit: Yersinia pestis
- Host candidate rows: 52
- Vector candidate rows: 47
- Competence-linked vector rows: 47
- Local candidate snapshot: `species_host_vector_roster.csv`, `host_role_candidates.csv`, `disease_vector_links_taxonomy_cleaned_competence_annotated.csv`, `diseases/plague/plague_vector_extractions.md`, and `diseases/plague/plague_vector_competence_extractions.md`.

## Current Host Candidate Highlights

- Local host candidates include humans, many rodents, carnivores, lagomorphs, and some livestock-like or wild ungulate rows.
- Official-source evidence supports a group-level wild rodent-flea maintenance cycle.
- Human evidence supports an incidental/spillover role, with a separate pneumonic human-to-human transmission context that was not converted into a reservoir assignment.

## Current Vector Candidate Highlights

- Local vector candidates are flea-heavy, with 47 flea rows and many species-level competence/extraction rows.
- Official-source rows were added for fleas as a group and `Xenopsylla cheopis` as the named Oriental rat flea vector.
- The local extraction files contain many additional species-level flea rows, but most require source-specific geographic and efficiency caveats before assignment.

## Sources Searched

| Source | Type | URL or local path | Used for rows? | Notes |
|---|---|---|---|---|
| CDC How Plague Spreads | Official public health guidance | https://www.cdc.gov/plague/causes/index.html | Yes | Supports natural wild rodent-flea cycle and human infection routes. |
| CDC MMWR plague treatment guidelines | Official public health guidance | https://www.cdc.gov/mmwr/volumes/70/rr/rr7003a1.htm | Yes | Supports incidental host language and `Xenopsylla cheopis` vector evidence. |
| WHO Plague fact sheet | Official public health factsheet | https://www.who.int/news-room/fact-sheets/detail/plague | Background only | Supports broad flea, animal reservoir, and control context but less specific than CDC rows used here. |
| Merck Veterinary Manual plague in animals | Veterinary reference | https://www.merckvetmanual.com/infectious-diseases/plague/plague-in-animals | Proxy background only | Supports conservative non-rodent mammal susceptible/spillover proxy framing. |
| Local plague vector extraction markdown | Local curated extraction | `diseases/plague/plague_vector_extractions.md` | Background only | Used to identify species-level vector candidates and source caveats. |
| Local plague competence extraction markdown | Local curated extraction | `diseases/plague/plague_vector_competence_extractions.md` | Background only | Used to avoid treating all experimentally competent fleas as equivalent role assignments. |

## Source-Backed Host Role Findings

| Host or group | Role claim | Evidence direction | Confidence | Manual review? | Evidence note |
|---|---|---|---|---|---|
| Rodentia | maintenance_host | supports | high | yes | CDC supports a natural maintenance cycle involving wild rodents and fleas. |
| Homo sapiens | incidental_host | supports | high | no | CDC supports spillover to incidental hosts including humans. |
| Cynomys ludovicianus | amplifying_host | supports | medium | yes | Source-check row supports a North American prairie-dog epizootic amplifying-host role. |

## Source-Backed Vector Role Findings

| Vector or group | Role claim | Evidence direction | Confidence | Manual review? | Evidence note |
|---|---|---|---|---|---|
| fleas | main_vector | supports | high | yes | CDC supports fleas in the natural maintenance and transmission cycle. |
| Xenopsylla cheopis | primary_vector | supports | high | no | CDC MMWR explicitly names the Oriental rat flea as a plague vector. |
| Oropsylla montana | primary_vector | supports | high | yes | Source-check row supports a regional North American primary-vector role. |
| Oropsylla hirsuta | candidate_vector | supports | medium | yes | Source-check row supports a prairie-dog epizootic candidate-vector role. |

## Rows Added To Evidence CSVs

- Current host evidence rows: 3 rows for rodent group maintenance, human incidental/spillover role, and `Cynomys ludovicianus` amplifying-host context.
- Current vector evidence rows: 4 rows for fleas as a group, `Xenopsylla cheopis`, `Oropsylla montana`, and `Oropsylla hirsuta`.

## Draft Assignments Added

- Current host assignments: 3 rows for group-level `Rodentia` maintenance, human `incidental_host`, and `Cynomys ludovicianus` amplifying-host context.
- Current vector assignments: 4 rows for group-level fleas, species-level `Xenopsylla cheopis`, regional `Oropsylla montana`, and candidate `Oropsylla hirsuta`.

## 2026-06-23 Completion Pass

- Added Plague-only host proxy rules in `host_proxy_rules.csv` for Rodentia maintenance/reservoir fallback and non-rodent mammal susceptible/spillover fallback. These are review-visible modelling proxies, not species-level source-backed role claims.
- Added tax-ID rescue proxy rows for current Plague roster hosts with missing generated taxonomy so known rodent and non-rodent mammal rows do not remain `host_presence_only` solely because `host_class` or `host_order` is blank.
- Regenerated `role_modelling_features.csv`, `vector_modelling_features.csv`, and `tiered_species.csv`.
- Generated host buckets are now 26 `reservoir_or_amplifying_host`, 25 `susceptible_or_spillover_host`, and 1 `dead_end_or_incidental_host`.
- Generated vector buckets remain conservative: species-level reviewed primary/main rows are limited to `Xenopsylla cheopis` and regionally caveated `Oropsylla montana`; `Oropsylla hirsuta` remains a reviewed candidate/competence-supported row; other flea rows stay competence, direct-association, source-hint, or taxonomy-caution buckets.
- Remaining review flags are caveats for broad proxy use, source geography, taxonomy, or group-level evidence. The group-level `fleas` assignment is intentionally non-propagating context; species-level flea handoff rows carry the modelling buckets.

## Deferred Candidates And Why

- Individual rodent species: deferred because official-source evidence is group-level and plague host role varies by region and epizootic context.
- Carnivores, lagomorphs, ungulates, and other mammal candidates: deferred unless source-backed role evidence distinguishes susceptible, incidental, amplifying, or surveillance roles.
- Most flea species: deferred because competence or historical vector evidence needs geography, efficiency, host association, and source wording reviewed species by species.
- Mechanical-vector rows such as `Pulex irritans`: deferred until the vector-role assignment policy decides whether to assign `mechanical_vector` when biological-vector evidence is poor.

## Future Refinements

- The `Rodentia` maintenance-host row is accepted as group-level context for the current modelling handoff; species-level reservoir rules can be refined later if regional reservoir-host policy is needed.
- Additional flea species can be promoted later through species-specific vector subreview, but current generated buckets remain conservative.
