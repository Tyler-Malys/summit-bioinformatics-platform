# Delcath Pipeline Architecture Decisions — 2026-03-17

## Confirmed canonical hardening bases
- bulk RNA-seq: delcath_crc_bulk_rnaseq_2026-02
- scRNA-seq: delcath_scrnaseq_dev_2026-03

## Legacy / reference-only area
- delcath_bulk_rnaseq is reference-only and not the canonical hardening target

## Core repo standard
Both pipeline repos should converge on:
- config/
- docs/
- scripts/
- README.md
- .gitignore

Optional later additions:
- tests/
- examples/

## scripts/ standard
Canonical scripts/ structure should center on:
- wrappers/
- utils/
- qc/
- preprocessing/
- alignment/
- quantification/
- downstream/
- legacy/

## Key cross-repo standardization decision
- Use bulk RNA-seq as the stronger config model
- Use scRNA-seq as the stronger script-organization model

## Repo-local content that is transitional, not canonical
The following should be externalized over time:
- logs/
- results/
- runs/
- raw/
- ref/
- large datasets
- temporary working files
- output artifacts
- repo-local pilot validation assets

## Specific folder decisions

### Bulk RNA-seq
- analysis/ is confirmed reusable downstream code content
- notes/ is empty and should not remain a canonical top-level folder
- star_pilot/ is a non-canonical pilot artifact area and should not define repo architecture

### scRNA-seq
- analysis/ is mixed code + outputs and should be split over time
- metadata/ is useful run/input metadata and should be normalized, not discarded
- qc/ is empty and should not remain a canonical top-level folder in current form
- validation/ is empty and should not remain a canonical top-level folder in current form

## Architectural principle going forward
There should be one canonical development source per pipeline, and shared/client-facing distributions should be intentional release artifacts derived from the hardened canonical source.
