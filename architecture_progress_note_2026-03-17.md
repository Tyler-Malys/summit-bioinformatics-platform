# Phase 3 Progress Note — Pipeline Architecture & Operating Structure
Date: 2026-03-17

## Work completed today

Completed an architectural inventory of the Delcath pipeline workspace and identified the canonical hardening bases for both pipelines:
- bulk RNA-seq: delcath_crc_bulk_rnaseq_2026-02
- scRNA-seq: delcath_scrnaseq_dev_2026-03

Confirmed that the older delcath_bulk_rnaseq workspace should be treated as legacy/reference-only and not as the primary hardening target.

Defined a canonical repository structure for both pipelines centered on:
- config/
- docs/
- scripts/
- README.md
- .gitignore

Defined a canonical scripts/ structure centered on:
- wrappers/
- utils/
- qc/
- preprocessing/
- alignment/
- quantification/
- downstream/
- legacy/

Documented current-to-target mapping for both canonical repos, including classification of repo-local logs, results, runs, raw data, references, analysis objects, and pilot artifacts as transitional rather than canonical long-term repo structure.

Confirmed key standardization decisions:
- bulk RNA-seq provides the stronger configuration model
- scRNA-seq provides the stronger script-organization model

Defined a canonical server-level layout separating:
- repository zone
- reference zone
- environment zone
- tool zone
- future run zone

Established the architectural principle that each pipeline should have one canonical development source, and any shared/client-facing distribution should be an intentional release artifact derived from the hardened canonical source.

## Immediate next steps
- refine reference-zone inventory under refs/
- refine tool-zone inventory under bioinformatics_tools/
- optionally begin low-risk bulk repo script reorganization into canonical subfolders
- defer large filesystem moves until later hardening steps

## Validation Finding — MultiQC Environment Failure

During validation of the bulk RNA-seq wrapper using the QC-only test configuration, FastQC executed successfully, but MultiQC failed with a Python binary incompatibility error:

ValueError: numpy.dtype size changed, may indicate binary incompatibility.

### Root Cause

The failure is due to a mismatch between:
- system-installed MultiQC
- NumPy version
- SciPy version

This indicates that the current execution environment is not version-controlled or reproducible.

### Interpretation

This is not a pipeline logic failure, but an environment management issue.

The wrapper, run structure, and execution flow were validated successfully up to the MultiQC stage.

### Action Plan

Do not resolve this issue within the current architecture phase.

This will be addressed in a later phase:

Environment Modernization & Version Control

Planned actions:
- move pipeline execution into conda-managed environments
- pin versions for:
  - MultiQC
  - NumPy
  - SciPy
  - other Python dependencies
- ensure full reproducibility of pipeline execution

### Conclusion

The wrapper architecture and canonical run structure are functioning as intended.

The observed failure is a valid and expected outcome of running in an uncontrolled system environment and will be resolved during environment hardening.
