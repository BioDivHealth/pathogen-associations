# Source References

This file records public citation anchors for the methods draft. Local source
tables, manual review files, and generated outputs remain the reproducibility
record for the analysis; these links identify the upstream public sources that
should be cited or described in manuscript text.

## Disease Selection

- World Health Organization. `Pathogens prioritization: A scientific framework
  for epidemic and pandemic research preparedness`. June 2024.
  https://cdn.who.int/media/docs/default-source/consultation-rdb/prioritization-pathogens-v6final.pdf

  Used as the main WHO priority/prototype pathogen and pathogen-family source
  document for disease selection and analysis-unit construction.

## Host-Pathogen Networks

- Gibb R, Albery GF, Becker DJ, Brierley L, Connor R, Dallas TA, et al.
  `Data proliferation, reconciliation, and synthesis in viral ecology`.
  BioScience. 2021;71(11):1148-1156. doi: 10.1093/biosci/biab080.
  https://doi.org/10.1093/biosci/biab080

  Public manuscript citation for the CLOVER data-synthesis work. The live
  workflow reads local `clover_1.0_allpathogens` flat files and uses CLOVER as
  a host-pathogen source for WHO-linked analysis units routed away from VIRION.

- Gibb R, Carlson CJ, Farrell MJ. `viralemergence/clover: Preprint + Zenodo`.
  Zenodo. Version v0.1.1. doi: 10.5281/zenodo.4435128.
  https://zenodo.org/records/4435128

  Repository/data-release anchor for CLOVER. If a manuscript cites a different
  local CLOVER release, update this entry to the exact archived version used.

- Carlson CJ, Gibb RJ, Albery GF, Brierley L, Connor R, Dallas T, et al.
  `The Global Virome in One Network (VIRION): an Atlas of Vertebrate-Virus
  Associations`. mBio. 2022;13(2):e02985-21. doi: 10.1128/mbio.02985-21.
  https://doi.org/10.1128/mbio.02985-21

  Used as the public citation anchor for VIRION host-virus associations.

## Vector And Host-Vector Evidence

- Massoels B, Bottu T, Vanslembrouck A, Kramer I, Van Bortel W.
  `Systematic literature review on the vector status of potential vector species
  of 36 vector-borne pathogens`. EFSA Supporting Publications. Approved
  29 November 2023. doi: 10.2903/sp.efsa.2023.EN-8484.
  https://efsa.onlinelibrary.wiley.com/doi/10.2903/sp.efsa.2023.EN-8484

  Used as the EFSA source report for vector-status and vector-competence
  evidence covering mosquitoes, ticks, sand flies, and biting midges.

- Walter Reed Biosystematics Unit. VectorMap Data Portal.
  http://vectormap.si.edu/

  Used as the public source anchor for VectorMap host-vector and arthropod
  collection records. The final manuscript citation should include the exact
  data-access date from the download or analysis log.

- Amos B, Aurrecoechea C, Barba M, Barreto A, Basenko EY, et al.
  `VEuPathDB: the eukaryotic pathogen, vector and host bioinformatics resource
  center`. Nucleic Acids Research. 2022;50(D1):D898-D911.
  doi: 10.1093/nar/gkab929.
  https://doi.org/10.1093/nar/gkab929

  Used as the public citation anchor for MapVEu, the VEuPathDB spatial data
  exploration and download tool used for vector blood-meal records.

- Internal curated literature-review vector table: `diseases/vector_table.xlsx`.

  This is a local curation input, not a single public upstream source. Row-level
  `source` and `notes` fields remain the provenance record for these
  literature-review vector rows.

## Country Evidence

- World Health Organization. Disease Outbreak News.
  https://www.who.int/emergencies/disease-outbreak-news

  Used as the public source for WHO Disease Outbreak News country-disease
  evidence.

- National Center for Biotechnology Information. GenBank.
  https://www.ncbi.nlm.nih.gov/genbank/

  Used as the public source for GenBank sequence-record metadata summarized into
  disease-country evidence.
