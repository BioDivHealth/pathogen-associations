# Hepatitis E Role Review

## Scope

- Disease tracker label: `Hepatitis E`
- Source pathogen: `Paslahepevirus balayani genotype 3`
- Modelling frame: non-vectored host SDM. Main modelling distinction is between
  source-backed swine/rabbit reservoir rows, cervid susceptible or spillover
  rows, human incidental zoonotic endpoint, and remaining host-presence rows.
- Last updated: `2026-06-22`

## Local Candidate Snapshot

- Host candidate rows: `74`
- Vector candidate rows: `0`
- Source-backed host evidence rows added: `11`
- Draft source-backed host assignments added: `11`
- Host feature bucket counts after regeneration:
  - `reservoir_or_amplifying_host`: `5`
  - `susceptible_or_spillover_host`: `5`
  - `dead_end_or_incidental_host`: `1`
  - `host_presence_only`: `63`

Review rows in this note are breadcrumbs. The authoritative role evidence and
assignment rows are in `host_role_evidence.csv` and
`host_role_assignments.csv`; generated modelling buckets are in
`role_modelling_features.csv` and `tiered_species.csv`.

## Source-Backed Host Roles

- `Sus scrofa` (`9823`): reservoir host. WHO frames HEV genotypes 3 and 4 as
  mainly non-human mammal viruses with occasional zoonotic human disease, and
  BfR / EID sources support domestic pigs and wild boars as genotype 3 animal
  reservoirs and foodborne sources.
- `Sus scrofa` (`9825`): reservoir host. Domestic pig row kept high-confidence
  and not review-needed because the source support is direct.
- `Sus scrofa` (`375578`) and `Sus scrofa` (`1611880`): reservoir host,
  review-visible. These are local wild-boar/subspecies-style duplicate rows
  mapped from general `Sus scrofa` / wild boar source support, not a broad
  Suidae proxy.
- `Cervus nippon` (`9863`, `92867`, `223998`): spillover host,
  review-visible. Deer meat has direct foodborne zoonotic evidence, but the
  row is kept non-reservoir because the checked sources caution that deer are
  not established major reservoirs.
- `Capreolus capreolus` (`9858`): susceptible host only, review-visible. Roe
  deer HEV genotype 3 detection and foodborne-risk evidence supports a
  caveated susceptible/spillover-facing bucket, not a reservoir role.
- `Cervus elaphus` (`9860`): susceptible host only, review-visible. Red deer
  detection and foodborne-risk evidence is handled like roe deer: useful for a
  susceptible/spillover-facing bucket, not a reservoir role.
- `Oryctolagus cuniculus` (`9986`): reservoir host, review-visible. Rabbit
  HEV-3ra evidence supports a source-backed reservoir row for this species, but
  the row stays review-needed because it is subtype and geography sensitive and
  is not generalized to lagomorphs.
- `Homo sapiens` (`9606`): incidental host, review-visible. Humans are treated
  as the genotype 3 or 4 zoonotic disease endpoint for this roster, not a
  reservoir row. Human-only genotype 1 or 2 transmission is outside the
  genotype-3-heavy local roster.

## Proxy Decision

No broad host proxy rule was added. The modelling-relevant roles were covered
by exact source-backed rows, and a broad Suidae, Cervidae, or Mammalia fallback
would overstate species-level reservoir evidence.

## Web Sources

- WHO Hepatitis E fact sheet: `https://www.who.int/news-room/fact-sheets/detail/hepatitis-e`
- BfR domestic pigs and wild boars Q&A: `https://www.bfr.bund.de/en/service/frequently-asked-questions/topic/hepatitis-e-virus-avoiding-transmission-via-domestic-pigs-and-wild-boars-and-food-derived-from-them/`
- Anheyer-Behmenburg et al. 2017 Emerging Infectious Diseases: `https://wwwnc.cdc.gov/eid/article/23/1/16-1169_article`
- Li et al. 2005 Emerging Infectious Diseases: `https://wwwnc.cdc.gov/eid/article/11/12/05-1041_article`
- Tei et al. 2003 Lancet PubMed record: `https://pubmed.ncbi.nlm.nih.gov/12907011/`
- Rabbit HEV-3ra 2025 Emerging Infectious Diseases: `https://wwwnc.cdc.gov/eid/article/31/4/25-0074_article`

## Open Questions

- None blocking for modelling readiness. Review flags are retained
  for mapped subspecies rows, cervid non-reservoir caveats, rabbit HEV-3ra
  subtype/geography sensitivity, and the human incidental-host framing.
