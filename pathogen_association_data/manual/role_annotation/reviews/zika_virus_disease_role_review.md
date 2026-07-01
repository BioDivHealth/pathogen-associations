# Zika Virus Disease Role Review

Phase: `Phase V`
Started: `2026-05-08`
Last updated: `2026-06-25`

## Disease Scope And Local Candidate Counts

- Disease name: Zika virus disease
- Source pathogen or analysis unit: Orthoflavivirus zikaense
- Host candidate rows: 21
- Vector candidate rows: 56
- Competence-linked vector rows: 27
- Local candidate snapshot: `species_host_vector_roster.csv`, `role_modelling_features.csv`, `vector_modelling_features.csv`, `tiered_species.csv`, `diseases/zika/zika_vector_extractions.md`, and `diseases/zika/zika_vector_competence_extractions.md`.

## Current Host Candidate Highlights

- Humans are source-backed as urban-cycle amplifying hosts.
- Taxonomically resolved non-human primate rows use a conservative review-needed sylvatic reservoir/amplifying group proxy. This is a modelling fallback, not species-level reservoir proof.
- Bat, rodent, shrew, and other mammal rows remain `host_presence_only`.

## Current Vector Candidate Highlights

- Local vector candidates include primary `Aedes aegypti`, secondary `Aedes albopictus`, multiple sylvatic/candidate African `Aedes` species, temperature-dependent secondary Aedes species, plus weaker non-Aedes rows.
- `Aedes albopictus` is kept as a review-needed secondary vector rather than a co-main vector.
- `Culex quinquefasciatus` is explicitly reviewed as not an important vector so mixed competence rows do not overstate its modelling role.

## Sources Searched

| Source | Type | URL or local path | Used for rows? | Notes |
|---|---|---|---|---|
| WHO Zika virus fact sheet | Official public health factsheet | https://www.who.int/en/news-room/fact-sheets/detail/zika-virus | Yes | Supports `Aedes aegypti` as main vector. |
| CDC Transmission of Zika Virus | Official public health guidance | https://www.cdc.gov/zika/php/transmission/index.html | Yes | Supports urban transmission involving infected people, `Aedes aegypti`, `Aedes albopictus`, non-human primates, sylvatic Aedes, and `Aedes hensilli` caveat. |
| Diagne et al. 2015 Senegal Aedes competence study | Peer-reviewed article | https://link.springer.com/article/10.1186/s12879-015-1231-2 | Yes | Supports African sylvatic Aedes context and `Ae. luteocephalus`/`Ae. vittatus` saliva-positive competence evidence. |
| Bisia et al. 2023 systematic review | Peer-reviewed systematic review | https://journals.plos.org/plosntds/article?id=10.1371/journal.pntd.0011591 | Yes | Supports secondary Aedes rows and the `Cx. quinquefasciatus` not-important caveat. |
| Terzian et al. 2018 Scientific Reports | Peer-reviewed article | https://www.nature.com/articles/s41598-018-34423-6 | Background/proxy | Supports caveated non-human primate susceptibility/possible transmission-cycle context; not used for exact species assignments. |
| Local Zika vector extraction markdown | Local curated extraction | `diseases/zika/zika_vector_extractions.md` | Background only | Used to identify breadth of candidate vectors. |
| Local Zika competence extraction markdown | Local curated extraction | `diseases/zika/zika_vector_competence_extractions.md` | Background only | Used to keep negative and competence-only rows out of final role assignments. |

## Source-Backed Host Role Findings

| Host or group | Role claim | Evidence direction | Confidence | Manual review? | Evidence note |
|---|---|---|---|---|---|
| Homo sapiens | amplifying_host | supports | high | no | CDC supports infected people as sources for urban Aedes transmission. |
| Non-human primates | sylvatic reservoir/amplifying group context | supports | medium-low | yes | CDC supports the enzootic Aedes-NHP cycle; proxy is broad and review-needed. |

## Source-Backed Vector Role Findings

| Vector or group | Role claim | Evidence direction | Confidence | Manual review? | Evidence note |
|---|---|---|---|---|---|
| Aedes aegypti | primary_vector | supports | high | no | WHO identifies this as the main Zika vector. |
| Aedes albopictus | secondary_vector | supports | medium | yes | Review and official sources support urban vector status, with `Ae. aegypti` retained as main. |
| Aedes africanus | sylvatic_candidate_vector | supports | medium | yes | African field/surveillance evidence; not promoted to a global urban vector. |
| Aedes furcifer | sylvatic_candidate_vector | supports | medium | yes | African field/surveillance evidence; not promoted to a global urban vector. |
| Aedes hensilli | regional_epidemic_candidate_vector | supports | low | yes | Pacific Islands/Yap context only. |
| Aedes luteocephalus | sylvatic_vector | supports | medium | yes | Senegal field and saliva-positive competence support. |
| Aedes taylori | sylvatic_candidate_vector | supports | medium | yes | African field/surveillance evidence; not promoted to a global urban vector. |
| Aedes vittatus | sylvatic_vector | supports | medium | yes | Senegal field and saliva-positive competence support. |
| Aedes detritus | secondary_vector | supports | medium | yes | Temperature-dependent laboratory secondary-vector support. |
| Aedes japonicus | secondary_vector | supports | medium | yes | Temperature-dependent laboratory secondary-vector support. |
| Aedes vexans | secondary_vector | supports | medium | yes | Low-efficiency laboratory secondary-vector support. |
| Culex quinquefasciatus | not_important_vector | supports | medium | yes | Systematic review says the weight of evidence does not support importance for ZIKV transmission, while localized exceptions remain possible. |

## Rows Added To Evidence CSVs

- Existing host evidence row retained for human urban-cycle amplification.
- Host proxy rule added for review-needed non-human primate sylvatic context.
- Vector evidence rows now cover `Aedes aegypti`, `Aedes albopictus`, `Aedes africanus`, `Aedes detritus`, `Aedes furcifer`, `Aedes hensilli`, `Aedes japonicus`, `Aedes luteocephalus`, `Aedes taylori`, `Aedes vexans`, `Aedes vittatus`, and `Culex quinquefasciatus`.

## Draft Assignments Added

- Host assignment retained for human `amplifying_host`.
- Vector assignments now separate primary/main, secondary, sylvatic/candidate, regional epidemic candidate, and not-important vector rows.

## Deferred Candidates And Why

- Non-human primates: group proxy is review-needed and should not be read as exact species-level reservoir evidence.
- Bat, rodent, shrew, and other mammal candidates: retained as host presence only.
- Mixed local Aedes rows such as `Aedes camptorhynchus`, `Aedes notoscriptus`, and `Aedes polynesiensis` remain competence-supported caveats rather than exact role assignments.
- Weaker non-Aedes rows remain direct-association or unknown/caveat rows unless separately reviewed.

## Open Questions For Collaborator Review

- Remaining `needs_review` flags are modelling caveats: broad NHP proxy, regional sylvatic Aedes context, temperature-dependent secondary vectors, and localized Culex exceptions.
- Missing SDM assets are outside this species-role review and were not treated as blockers.

## 2026-06-25 Reviewed-Assignment Caveat Pass

- Reviewed the 12 Zika vector assignment rows against the live vector features and source-backed evidence rows.
- No vector assignment rows needed changing: `Aedes aegypti` remains the only non-review primary vector; secondary, sylvatic, and regional candidate Aedes rows remain review-visible because their support is geography-, outbreak-, laboratory-, or temperature-context dependent.
- `Culex quinquefasciatus` remains `not_important_vector`, which intentionally maps to `unknown_or_unreviewed_vector` so mixed competence evidence does not promote it into a positive vector bucket.
- Current Zika machine-readable status: 56 vector feature rows, 12 vector assignment rows, 13 vector rows needing review, no reviewed primary-vector rows needing review, and no unmatched Zika vector assignments.
