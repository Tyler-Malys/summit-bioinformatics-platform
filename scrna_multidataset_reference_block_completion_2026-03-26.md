# scRNA-seq Multi-Dataset & Reference Genome Management Completion
Date: 2026-03-26

## Scope completed
Completed the scRNA-seq portion of the Phase 3 task block:

- Implement dataset-specific configuration support for multiple pipeline runs
- Implement organism selection and reference genome selection via configuration
- Define standardized reference genome directory layout
- Implement validation checks for required reference assets
- Develop helper scripts to register and load new reference genomes
- Test reference switching behavior

## Authoritative wrapper decision
Confirmed the canonical scRNA-seq wrapper is:

- `pipelines/scrnaseq/scripts/run_scrnaseq_wrapper.sh`

Confirmed `run_scrnaseq_wrapper_v3.sh` is not the production wrapper and was not used as the implementation target.

## Wrapper updates completed
Updated `pipelines/scrnaseq/scripts/run_scrnaseq_wrapper.sh` to support bulk-style canonical reference resolution using:

- `REF_ROOT`
- `ORGANISM`
- `GENOME_BUILD`
- `ANNOTATION_VERSION`

When explicit overrides are not provided, the wrapper now derives:

- `STAR_INDEX=${REF_ROOT}/${ORGANISM}/${GENOME_BUILD}/${ANNOTATION_VERSION}/star_index`
- `CELLRANGER_REF=${REF_ROOT}/${ORGANISM}/${GENOME_BUILD}/${ANNOTATION_VERSION}/cellranger_ref`

This was implemented with backward compatibility preserved for configs that still set `STAR_INDEX` and/or `CELLRANGER_REF` directly.

## Canonical scRNA reference layout established
Canonical layout for scRNA references is now:

`/home/summitadmin/refs/<organism>/<genome_build>/<annotation_version>/`

For the validated GRCh38/Gencode v49 reference set, registered:

- `/home/summitadmin/refs/human/grch38/gencode_v49/star_index`
- `/home/summitadmin/refs/human/grch38/gencode_v49/cellranger_ref`

These were registered as symlinks to the validated existing scRNA reference assets under the pipeline development area.

## Reference asset validation
Validated that the wrapper fails fast when canonical reference selection points to missing assets.

Tested with an intentionally invalid annotation version and confirmed clean failure on:

- missing `star_index`

Also confirmed canonical-resolution execution succeeds for the updated example `starsolo` configuration.

## Helper script added
Created:

- `pipelines/scrnaseq/scripts/utils/register_reference.sh`

This provides a minimal scRNA companion to the bulk registration helper and registers:

- `star_index`
- `cellranger_ref`

under the canonical reference layout using symlinks.

## Config updates completed
Updated:

- `pipelines/scrnaseq/config/template_scrnaseq.env`
- `pipelines/scrnaseq/config/examples/scrna_pbmc1k_starsolo.env`

Template/example configs now use:

- `REF_ROOT`
- `ORGANISM`
- `GENOME_BUILD`
- `ANNOTATION_VERSION`

with:

- `STAR_INDEX=""`
- `CELLRANGER_REF=""`

to allow canonical wrapper resolution by default while preserving override capability.

## Additional wrapper cleanup
Fixed an unrelated but production-relevant bug in the wrapper where `CELLRANGER_BIN` was referenced unconditionally during `starsolo` runs, causing an unbound-variable warning under `set -u`.

`starsolo` startup is now clean.

## Verification completed
Confirmed:

- `bash -n scripts/run_scrnaseq_wrapper.sh` → OK
- `bash -n scripts/utils/register_reference.sh` → OK
- canonical `starsolo` example startup → OK
- bad canonical annotation selection → clean fail-fast

## Status
scRNA-seq Multi-Dataset & Reference Genome Management block completed on 2026-03-26.
