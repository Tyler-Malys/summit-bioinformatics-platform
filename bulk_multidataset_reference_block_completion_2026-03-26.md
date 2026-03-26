# Bulk RNA-seq — Multi-Dataset & Reference Genome Management Completion
Date: 2026-03-26

## Scope
Completed the Phase 3 task block:
**Multi-Dataset & Reference Genome Management** for the bulk RNA-seq pipeline.

---

## Summary of Changes

### 1. Dataset-Specific Configuration Support
- Introduced `DATASET_ID` into bulk config schema
- Created new test configs derived from template
- Verified wrapper creates independent run directories per config

---

### 2. Config-Driven Reference Selection
- Implemented reference resolution using:
  - `REF_ROOT`
  - `ORGANISM`
  - `GENOME_BUILD`
  - `ANNOTATION_VERSION`
- Wrapper now derives:
  - `SALMON_INDEX`
  - `STAR_INDEX`
  - `TX2GENE`
- Explicit paths remain supported for backward compatibility

---

### 3. Canonical Reference Directory Structure
Established canonical structure:

/home/summitadmin/refs/<organism>/<genome_build>/<annotation_version>/
  ├── star_index/
  ├── salmon_index/
  └── tx2gene/tx2gene.tsv

Current implementation (transitional):
- Uses symlinks to existing assets
- Legacy reference structure retained during migration

---

### 4. Reference Validation (Fail-Fast)
Added wrapper-level validation:
- Verify `SALMON_INDEX` directory exists
- Verify `STAR_INDEX` directory exists
- Verify `TX2GENE` file exists
- Validation conditional on enabled stages

---

### 5. Reference Registration Script
Created reusable helper:

pipelines/bulk_rnaseq/scripts/utils/register_reference.sh

Function:
- Registers canonical reference paths
- Creates directory structure
- Symlinks STAR, Salmon, and tx2gene assets
- Validates source inputs before registration

---

### 6. Reference Switching Validation
Tested config-driven switching:

PASS CASE:
- human / grch38 / gencode_v45
- Wrapper resolved references and entered execution

FAIL CASE:
- human / grch38 / gencode_v49
- Wrapper failed fast due to missing reference assets

Confirms:
- Reference selection is fully config-driven
- Validation prevents invalid execution

---

## Current Reference State

Canonical path in use:

/home/summitadmin/refs/human/grch38/gencode_v45/

Assets:
- STAR index (GENCODE v45)
- Salmon index (GENCODE v44, legacy)
- tx2gene (GENCODE v44)

NOTE:
- Annotation versions are currently mixed (v44 vs v45)
- Full rebuild and alignment deferred to future phase

---

## Outcome

Bulk RNA-seq pipeline now supports:
- Multiple datasets via config
- Config-driven organism/build/reference selection
- Standardized reference layout
- Reusable reference registration
- Robust validation and fail-fast behavior

This completes the bulk portion of:
**Multi-Dataset & Reference Genome Management**

---

## Next Steps

- Apply same system to scRNA-seq pipeline
- Standardize scRNA reference handling
- Align bulk and scRNA reference usage patterns
- Consider future:
  - unified reference builds (consistent annotation versions)
  - automated reference build pipelines
