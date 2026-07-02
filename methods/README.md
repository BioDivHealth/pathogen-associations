# Methods

This folder contains concise, manuscript-facing descriptions of the main evidence-generation steps. It is intended as a paper methods draft.

## Disease Selection And Analysis Units

Diseases and pathogens were defined from WHO priority, prototype, and regional
pathogen source tables, then harmonized against a disease master list. Source
labels were standardized through explicit name-resolution tables, manual
transmission-rule review, and pathogen-matching logic. Broad disease or
pathogen labels were retained for provenance, but downstream inclusion was
controlled by reviewed modelling-scope fields rather than by taxonomic rank
alone.

The main disease registry links WHO-derived disease and pathogen names to the
project disease master, records reviewed scope decisions, and identifies the
disease or pathogen analysis units available for host, vector, country, role,
and modelling-prioritisation analyses. Rows outside the reviewed modelling
scope are preserved for audit and future review, but are not promoted into the
main modelling tables.

## Host-Pathogen Network Assembly

Host-pathogen evidence was assembled by routing WHO-linked analysis units to
VIRION when the reviewed pathogen-family label matched viral-family or
virus-name patterns, and to CLOVER otherwise. Host names were cleaned and
standardized, and source-specific network components were combined into a WHO
host-pathogen backbone. This backbone was then aligned to the reviewed disease
registry while preserving provenance from the earlier WHO-only zoonotic
network.

Host-network rows are interpreted as association evidence only. A host
association indicates that a host was linked to a pathogen or disease in an
upstream source and passed the relevant quality or inclusion filters. It does
not, by itself, assign reservoir, amplifier, incidental, dead-end, or other
host-role labels.

## Vector And Host-Vector Evidence

Disease-vector evidence was curated from an internal literature-review table
and EFSA appendix-derived pathogen-vector records. Disease and vector names
were standardized, unmatched disease labels were written to review tables, and
the combined evidence was collapsed to one row per disease-vector pair while
preserving source, location, evidence-basis, and row-count summaries. Vector
taxonomy cleanup used conservative rule-based normalization plus explicit
manual mapping for unresolved or ambiguous taxa.

Vector-competence evidence was collapsed to disease-vector grain and left
joined onto the canonical disease-vector and disease-host-vector outputs. These
competence fields annotate infection, transmission, mixed, negative, or
uncertain evidence, but they do not control row inclusion and do not create
final vector-role labels.

Observed host-vector evidence was built from VectorMap and MapVEu outputs.
Record-level host-vector observations were standardized, summarized, and
reduced to join-ready host-vector evidence while retaining source-platform,
dataset, interaction-type, country, and record-count provenance. WHO
disease-host rows were then joined to observed host-vector records and curated
disease-vector evidence to generate conservative and expanded tables of
potential disease-host-vector links. Expanded rows can represent either
evidence from both layers or host-vector-only candidate links within the
screened disease subset.

## GenBank Country Evidence

GenBank country evidence was generated with a manifest-driven NCBI nuccore
retrieval process. The retrieval manifest is derived from diseases not placed
on hold for modelling, expanded to reviewable species-level retrieval targets,
and constrained by manual query overrides and guardrails for broad or
high-volume targets.
Deferred examples include unresolved broad coronavirus labels, broad influenza
labels without reviewed subtype targets, Salmonella targets that are too broad
for the current modelling use case, and targets exceeding the configured record
limit.

Retrieved records are cached in per-target checkpoints, summarized to
pathogen-country and disease-country layers, quality checked, and standardized
to country names used by downstream modelling-prioritisation analyses. GenBank
country metadata are treated as evidence of record-associated geography, not as a
definitive endemic-occurrence layer, because records can reflect sampling,
sequencing, laboratory, model-organism, or publication context.

## WHO Disease Outbreak News Country Evidence

WHO Disease Outbreak News evidence was built by extracting and reviewing
country-disease associations from WHO Disease Outbreak News records. The
process assembles source records, extracts country and disease candidates,
compares them with accepted reference layers, applies explicit reviewed or
policy-controlled adoption decisions, builds association evidence, classifies
scope, and exports a modelling-ready country-disease table.

This process separates candidate extraction, adoption decisions, association
evidence, scope classification, and final export. Country or disease candidates
are not accepted simply because they are detected; they must be covered by
deterministic policy or recorded review decisions. The resulting
country-evidence table is used as one modelling-prioritisation layer and is not
merged with GenBank or other country evidence into a single truth set.

## Role Annotation And Modelling Prioritisation

Role annotation is an interpretation layer downstream of the association,
vector, competence, host-vector, GenBank, and WHO Disease Outbreak News evidence
layers. Generated host-role and vector-role candidate tables are used for
triage. Final host or vector role labels are assigned only after source-backed
evidence rows are entered into the corresponding role-evidence tables and
reviewed or draft assignments are recorded in the assignment tables.

The species roster combines host rows from the reviewed host-pathogen network
with vector rows from the curated vector table, plus host-vector observation
and competence flags where available. Role modelling features derive compact
host and vector role buckets, evidence bases, confidence fields,
manual-review flags, and biological evidence tiers from the
reviewed assignments and explicit proxy-rule files. Disease-specific proxy
rules are stored as data, while the implementation applies the same generic
rule logic across diseases.

The final modelling-prioritisation tables combine the reviewed disease registry
with role-annotation review summaries, the species roster, country evidence
from GenBank and WHO Disease Outbreak News, and an imported SDM availability
catalogue. Required disease-registry inputs stop the build if missing; optional
evidence layers are treated as empty rather than as implicit negative evidence.
The outputs provide all-disease planning tables, a WHO-focused subset, species,
country, and evidence companion tables, and evidence-tier summaries for
downstream SDM planning.

## Validation And Interpretation Boundaries

Process changes are validated with the smallest useful checks: parse checks,
targeted script reruns, review summaries, row/column comparisons, and
`git --no-pager diff --check`. Generated outputs are not edited by hand when a
scripted regeneration path exists.

Throughout the analysis, host association, vector evidence, vector competence,
observed host-vector links, GenBank country metadata, WHO Disease Outbreak News
country evidence, role review, and SDM availability remain distinct evidence
layers unless a documented analysis step explicitly combines them. This
prevents candidate evidence from being overstated as final biological role
assignment or confirmed geographic occurrence.