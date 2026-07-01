# Tick-Borne Encephalitis Role Review

Phase: `Phase V`
Started: `2026-05-08`
Last updated: `2026-06-24`

## Disease Scope And Local Candidate Counts

- Disease name: Tick-borne encephalitis
- Source pathogen or analysis unit: Orthoflavivirus encephalitidis
- Host candidate rows: 92 in current generated roster
- Vector candidate rows: 11
- Competence-linked vector rows: 13
- Local candidate snapshot: role roster, vector competence annotated table, and `diseases/tbe/*_extractions.md`.

## Current Host Candidate Highlights

- The current generated role surface now has host and vector rows for TBE.
- CDC/ECDC support small rodents as the core amplifying/reservoir host context; exact source-backed rows are kept for `Apodemus flavicollis` and `Myodes glareolus`, while a review-visible Muridae/Cricetidae proxy handles broader small-rodent roster rows.
- CDC source-backed rows now also cover human incidental infection and domestic cattle/goat/sheep foodborne susceptible-host context, without upgrading livestock to reservoir or amplifier roles.

## Current Vector Candidate Highlights

- Local vector candidates include `Ixodes ricinus`, `Ixodes persulcatus`, and several other tick species.
- CDC Yellow Book supports `Ixodes ricinus` and `Ixodes persulcatus` as primary subtype-associated vectors.
- CDC transmission guidance supports group-level `Ixodes` environmental maintenance with small rodents.

## Sources Searched

| Source | Type | URL or local path | Used for rows? | Notes |
|---|---|---|---|---|
| CDC Yellow Book TBE | Official travel medicine guidance | https://www.cdc.gov/yellow-book/hcp/travel-associated-infections-diseases/tick-borne-encephalitis.html | Yes | Supports small rodents and primary `Ixodes` vectors. |
| CDC Transmission of TBE | Official transmission guidance | https://www.cdc.gov/tick-borne-encephalitis/php/transmission/index.html | Yes | Supports maintenance between `Ixodes` ticks and small rodents. |
| ECDC TBE factsheet | Official public health factsheet | https://www.ecdc.europa.eu/en/tick-borne-encephalitis/facts/factsheet | Proxy/background | Confirms small rodent reservoir/amplifier, broader indicator hosts, and human incidental/dead-end framing. |
| Local TBE extraction markdowns | Local curated extraction | `diseases/tbe/` | Background only | Used to identify deferred vector candidates. |

## Source-Backed Host Role Findings

| Host or group | Role claim | Evidence direction | Confidence | Manual review? | Evidence note |
|---|---|---|---|---|---|
| small rodents | amplifying_host | supports | high | yes | Group-level row; no local host candidate rows currently exist. |
| Homo sapiens | incidental_host | supports | high | yes | Human spillover row added despite no local host candidate row. |
| Bos taurus | susceptible_host_only | supports | medium | yes | Foodborne infected-dairy context only; not reservoir or amplifier evidence. |
| Capra hircus | susceptible_host_only | supports | medium | yes | Foodborne infected-dairy context only; goat-associated transmission is commonly reported. |
| Ovis aries | susceptible_host_only | supports | medium | yes | Foodborne infected-dairy context only; not reservoir or amplifier evidence. |

## Source-Backed Vector Role Findings

| Vector or group | Role claim | Evidence direction | Confidence | Manual review? | Evidence note |
|---|---|---|---|---|---|
| Ixodes ricinus | main_vector | supports | high | no | Primary vector for European subtype. |
| Ixodes persulcatus | main_vector | supports | high | no | Primary vector for Far Eastern and Siberian subtypes. |
| Haemaphysalis concinna | main_vector | supports | medium | yes | Regional Asia major-vector row; review-visible and not treated as a global core-vector claim. |
| Ixodes spp. | enzootic_maintenance_vector | supports | high | yes | Group-level maintenance evidence. |

## Rows Added To Evidence CSVs

- Host evidence rows: 7.
- Vector evidence rows: 3.
- Host proxy rules: 2 narrow small-rodent family rules for Muridae and Cricetidae.

## Draft Assignments Added

- Host assignments: 7 rows: group-level small rodents, human incidental infection, domestic cattle/goat/sheep susceptible-host context, and two source-checked small-rodent reservoir rows.
- Vector assignments: 3 rows.

## Deferred Candidates And Why

- Other tick species: deferred unless source-backed role evidence supports more than detection or competence.
- Other vertebrate hosts: birds, cervids, sciurids, and broader mammals remain presence-only unless source-backed role evidence supports more than detection, serology, tick support, or foodborne exposure.

## Open Questions For Collaborator Review

- Broad small-rodent proxy remains review-visible and should not be interpreted as species-level reservoir proof for every matched rodent row.
