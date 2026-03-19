# Delcath Pipeline Canonical Repository Structure — v1

## Purpose
Define the standard repository structure for all bioinformatics pipelines (bulk RNA-seq and scRNA-seq) to ensure consistency, maintainability, and enterprise readiness.

---

## Canonical Top-Level Structure

Each pipeline repository should follow this structure:

<repo>/
  README.md
  .gitignore

  config/
  docs/
  scripts/

  tests/            (optional, recommended)
  examples/         (optional)

---

## Top-Level Directory Definitions

### config/
- Environment and run configuration files
- Dataset-specific config templates
- Pipeline parameter definitions
- Subfolders:
  - tests/         (for staged/test configs)

### docs/
- Pipeline documentation
- User guides
- Architecture notes
- Execution logs (temporary, may later move out)

Subcategories (logical, not enforced):
- pipeline/
- analysis_notes/
- run_records/

### scripts/
- All executable pipeline logic
- Must be modular and structured by function

---

## Canonical scripts/ Structure

scripts/
  wrappers/
  utils/

  qc/
  preprocessing/
  alignment/
  quantification/
  downstream/

  legacy/      (for deprecated or experimental scripts)

---

## scripts/ Directory Definitions

### wrappers/
- Top-level execution scripts
- Entry points for pipeline runs
- Should orchestrate stages but not contain heavy logic

### utils/
- Shared helper functions
- Logging helpers
- Validation utilities

### qc/
- Quality control scripts (FASTQ QC, cell QC, etc.)

### preprocessing/
- Data preparation (trimming, filtering, formatting)

### alignment/
- Alignment steps (e.g., STAR, CellRanger alignment components)

### quantification/
- Quantification steps (e.g., Salmon)

### downstream/
- Statistical analysis
- Dimensionality reduction
- Differential expression
- Pathway analysis

### legacy/
- Deprecated scripts
- Backup scripts (.v0, .bak)
- Experimental or superseded logic

---

## What SHOULD NOT live in the repository

The following should NOT be part of the canonical repo structure:

- logs/
- results/
- runs/
- raw/
- ref/
- large datasets
- temporary working files
- one-off output artifacts

These should be externalized to canonical server locations (defined separately).

---

## Transitional Note

During hardening, some of the above may still exist in repos temporarily.
These should be gradually migrated out as pipeline execution is standardized.

---

## Standardization Strategy

- Adopt scRNA-seq script structure as baseline
- Adopt bulk RNA-seq config structure as baseline
- Refactor both pipelines to conform to this shared model
- Move run/output data out of repo over time
