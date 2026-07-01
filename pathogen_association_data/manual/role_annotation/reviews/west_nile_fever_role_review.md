# West Nile Fever Role Review

Phase: `Phase V`
Started: `2026-05-08`
Last updated: `2026-06-25`

## Disease Scope And Local Candidate Counts

- Disease name: West Nile fever
- Source pathogen or analysis unit: Orthoflavivirus nilense
- Host candidate rows: 274
- Vector candidate rows: 75
- Competence-linked vector rows: 39
- Local candidate snapshot: `species_host_vector_roster.csv`, `role_modelling_features.csv`, `vector_modelling_features.csv`, `tiered_species.csv`, and QA outputs reviewed on 2026-06-25.

## Current Host Candidate Highlights

- The local host roster is bird-heavy: 144 bird candidate rows, including many passeriform, accipitriform, anseriform, strigiform, and charadriiform rows.
- The local roster also includes human, horse/domestic equid, livestock-like mammal, rodent, bat, primate, reptile, and amphibian candidate rows.
- Group-level bird reservoir evidence is valid for `Aves`; broad bird rows are kept as review-visible proxy rows rather than source-backed species claims.
- Human and domestic horse/dead-end evidence is sufficiently explicit for draft source-backed assignments.
- `Turdus migratorius` has a source-backed amplifying-host assignment from the CDC guideline, with an OCR/name-mapping caveat retained.

## Current Vector Candidate Highlights

- The local vector roster has 75 mosquito rows, including confirmed `Culex pipiens`, `Culex modestus`, `Culex tarsalis`, `Culex perexiguus`, `Culex annulirostris`, `Aedes albopictus`, and broader `Culex spp.` entries.
- Existing pilot rows support genus-level `Culex spp.` as `principal_vector_genus`; `Culex pipiens`, `Culex modestus`, `Culex quinquefasciatus`, and `Culex tarsalis` as `main_vector`; and `Culex salinarius` as `epidemic_vector`, all with regional caveats where appropriate.
- The genus-level `Culex spp.` row is kept as role evidence only; it is not an assignment row and is not propagated to every `Culex` species.
- Many additional vector rows are candidate/probable or competence-layer rows only; these remain deferred unless a role source explicitly supports them.

## Sources Searched

| Source | Type | URL or local path | Used for rows? | Notes |
|---|---|---|---|---|
| WHO West Nile virus fact sheet | Official public health factsheet | https://www.who.int/en/news-room/fact-sheets/detail/west-nile-virus | Yes | Supports bird reservoir group, Culex principal-vector genus, and horse dead-end role. |
| CDC West Nile Virus Key Messages | Official public health guidance | https://www.cdc.gov/west-nile-virus/php/outbreak-communication/key-messages.html | Yes | Supports human, horse, and other mammal dead-end host language. |
| ECDC factsheet about West Nile virus infection | Official public health factsheet | https://www.ecdc.europa.eu/en/west-nile-fever/facts | Yes | Supports Europe-focused `Culex pipiens` and `Culex modestus` main vector rows. |
| ECDC Culex pipiens factsheet for experts | Official vector factsheet | https://www.ecdc.europa.eu/en/infectious-disease-topics/related-public-health-topics/disease-vectors/facts/mosquito-factsheets/culex-pipiens | Yes | Supports `Culex pipiens` as a major WNV vector; regional caveat retained. |
| CDC West Nile Virus Surveillance and Control Guidelines | Official public health guidance | https://www.cdc.gov/west-nile-virus/php/surveillance-and-control-guidelines/index.html | Yes | Supports `Turdus migratorius` amplifying-host evidence, US `Culex quinquefasciatus` and `Culex tarsalis` main-vector rows, and a regional `Culex salinarius` epidemic-vector row. |

## Source-Backed Host Role Findings

| Host or group | Role claim | Evidence direction | Confidence | Manual review? | Evidence note |
|---|---|---|---|---|---|
| Aves | reservoir_host_group | supports | high | yes | WHO supports birds as reservoir hosts, but the claim is group-level. |
| Homo sapiens | dead_end_incidental_host | supports | high | no | CDC explicitly describes humans as dead-end hosts in WNV transmission logic. |
| Equus caballus | dead_end_host | supports | high | no | WHO supports horses as dead-end hosts; mapped to domestic horse candidate. |
| Turdus migratorius | amplifying_host | supports | medium | yes | CDC guideline names American robin as an amplifier host example; row retains OCR/name-mapping caveat. |

## Source-Backed Vector Role Findings

| Vector or group | Role claim | Evidence direction | Confidence | Manual review? | Evidence note |
|---|---|---|---|---|---|
| Culex spp. | principal_vector_genus | supports | high | yes | WHO supports genus-level principal vector language. |
| Culex pipiens | main_vector | supports | high | yes | ECDC supports a major/main vector role, with European geographic caveat. |
| Culex modestus | main_vector | supports | high | yes | ECDC supports a main vector role in Europe. |
| Culex quinquefasciatus | main_vector | supports | high | yes | CDC guideline supports a southern-US primary/main-vector role. |
| Culex tarsalis | main_vector | supports | high | yes | CDC guideline supports a western-US primary/main-vector role. |
| Culex salinarius | epidemic_vector | supports | medium | yes | CDC guideline supports an important northeastern-US enzootic/epidemic vector role. |

## Rows Added To Evidence CSVs

- Host evidence rows currently include one group-level `Aves` row, source-backed human and domestic-horse dead-end rows, and a source-checked `Turdus migratorius` amplifying-host row.
- Vector evidence rows currently include genus-level `Culex spp.`, reviewed `Culex pipiens` and `Culex modestus`, and source-checked `Culex quinquefasciatus`, `Culex tarsalis`, and `Culex salinarius` rows.

## Draft Assignments Added

- Host assignments retain exact source-backed rows for human and domestic horse, plus source-checked `Turdus migratorius`.
- Vector assignments retain exact source-backed rows for `Culex pipiens`, `Culex modestus`, `Culex quinquefasciatus`, `Culex tarsalis`, and `Culex salinarius`.

## Deferred Candidates And Why

- Bird species-level assignments remain deferred except for `Turdus migratorius`; all broader avian reservoir/amplifying rows are proxy-derived and review-visible.
- Additional `Culex` species and non-`Culex` mosquitoes: deferred unless source-backed role evidence distinguishes main, bridge, enzootic, epidemic, or candidate roles.
- Mammal, reptile, amphibian, and broad livestock candidate rows: deferred unless sources support role-specific claims beyond infection or host presence.

## Completion Check

- Broad `Aves` evidence remains evidence-only; broad bird modelling behavior is handled by `host_proxy_rules.csv`, with `modelling_role_proxy_needs_review = TRUE`.
- Human and horse rows are exact source-backed dead-end/incidental host assignments.
- `Turdus migratorius` is the only exact source-backed bird species row in the current handoff.
- `Culex spp.` is intentionally evidence-only, while reviewed species-level Culex assignment rows carry the modelling buckets.
- Main/epidemic Culex assignments are source-backed where available; competence-only or source-hint vector rows stay caveated and are not promoted to unrestricted main-vector claims.
- Species-role surfaces are modelling-usable. The remaining readiness blocker is missing vector SDM assets, not a species-role curation blocker.
