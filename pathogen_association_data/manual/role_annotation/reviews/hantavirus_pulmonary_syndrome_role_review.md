# Hantavirus Pulmonary Syndrome Role Review

Last updated: `2026-06-22`

## Scope

- Disease tracker label: `Hantavirus pulmonary syndrome`
- Source pathogen: `Orthohantavirus sinnombreense`
- Analysis unit label: `Sinnombre virus`
- Modelling frame: non-vectored, host SDM needed, reservoir rodents primary; humans are terminal/incidental cases.
- Local roster at review: 28 host rows, 0 vector rows.

This note is a breadcrumb for the bounded role pass. The machine-readable truth
lives in `host_role_evidence.csv`, `host_role_assignments.csv`, generated
`role_modelling_features.csv`, and `tiered_species.csv`.

## Source-Backed Host Roles

- `Homo sapiens` (`9606`): dead-end/incidental host. Canada PSDS explicitly
  treats humans as dead-end hosts for Sin Nombre virus; CDC guidance frames
  non-Andes HPS exposure as rodent-to-human rather than person-to-person.
- `Peromyscus maniculatus` (`10042`): primary reservoir host. CDC identifies
  the deer mouse as spreading the most common US HPS hantavirus; Canada PSDS
  identifies `P. maniculatus` as the primary reservoir host. This is the
  strict, available-SDM reservoir anchor in the current handoff.
- `Peromyscus sonoriensis` (`2746888`): primary reservoir host, review-visible.
  Goodfellow et al. 2025 use current western deer mouse taxonomy and note it
  was previously named `P. maniculatus`; keep the taxonomy/SDM caveat visible.
- `Peromyscus leucopus` (`10041`), `Peromyscus boylii` (`56316`),
  `Peromyscus truei` (`89101`), `Mus musculus` (`10090`), and
  `Sigmodon hispidus` (`42415`): alternate reservoir/shedding hosts,
  review-visible. Goodfellow et al. 2025 provide live-virus carriage or
  shedding evidence in the New Mexico study, but these remain caveated because
  they are not the canonical primary deer-mouse reservoir.
- `Peromyscus eremicus` (`42410`): possible focal reservoir host,
  review-visible. Burns et al. 2018 support a Death Valley cactus mouse focus
  with high seroprevalence and viral RNA sequence evidence.
- `Tamias minimus` (`45468`): alternate reservoir/shedding host,
  review-visible. Canada PSDS lists the species among SNV reservoirs; recent
  source language uses `Neotamias`, so the taxonomy caveat stays visible.

## Deferred Or Presence-Only Rows

Remaining rodent rows stay `host_presence_only` or candidate-only unless a
direct species-level source supports reservoir, shedding, amplification, or
another modelling role. Serology or detection alone was not promoted to a
strong role assignment.

## Proxy Decision

No broad `Rodentia`, `Cricetidae`, or deer-mouse-group host proxy rule was
added. The current species-level evidence is strong enough for the main
modelling rows, and a broad proxy would overstate weak or serology-only roster
rows.

## Modelling Outcome

After regeneration, HPS was marked done in
`disease_role_review_status.csv`. The current generated surfaces show
`reviewed_assignment_present`, `ready_for_model_spec_review`, and
`readiness_blocker = none`.

Remaining review flags are non-blocking caveats for alternate reservoirs,
taxonomy, region-specific evidence, or missing SDM overlays. They should stay
visible for sensitivity or species-selection discussion.

## Web Sources

- CDC Clinician Brief: Hantavirus Pulmonary Syndrome (HPS): `https://www.cdc.gov/hantavirus/hcp/clinical-overview/hps.html`
- Canada Sin Nombre virus Pathogen Safety Data Sheet: `https://www.canada.ca/en/public-health/services/laboratory-biosafety-biosecurity/pathogen-safety-data-sheets-risk-assessment/sin-nombre-virus.html`
- Goodfellow et al. 2025 PLOS Pathogens: `https://journals.plos.org/plospathogens/article?id=10.1371%2Fjournal.ppat.1012849`
- Burns et al. 2018 Emerging Infectious Diseases: `https://wwwnc.cdc.gov/eid/article/24/6/18-0089_article`
