# Phase 3 Block Completion Note — Pipeline Architecture & Operating Structure
Date: 2026-03-17

## Block Status
Completed.

## Completed work

### 1. Canonical server layout
Defined the canonical server-level filesystem architecture for:
- pipeline repositories
- references
- environments
- tools
- future run roots

### 2. Repository structure standardization
Defined the canonical repository structure for bulk RNA-seq and scRNA-seq pipelines, including:
- config/
- docs/
- scripts/
- README.md
- .gitignore

Defined the canonical scripts/ organization centered on:
- wrappers/
- utils/
- qc/
- preprocessing/
- alignment/
- quantification/
- downstream/
- legacy/

### 3. Standardized run directory structure
Defined the canonical run directory structure:
- input/
- working/
- logs/
- qc/
- outputs/
- downstream/
- final/
- run_metadata/

Defined required metadata artifacts including:
- resolved_config.env
- run_manifest.txt
- pipeline_version.txt
- software_versions.txt
- start_end_status.txt

### 4. Wrapper implementation
Updated the bulk RNA-seq wrapper to create the canonical run directory structure and metadata files.
Validated bulk wrapper execution using a QC-only smoke test, confirming successful run-tree creation and metadata capture.

Implemented a new top-level scRNA-seq wrapper that:
- loads config
- supports engine selection
- creates the canonical run tree
- writes metadata files
- performs basic validation
- dispatches to Cell Ranger or STARsolo execution logic

### 5. Maintainability documentation
Created architecture inventory, target structure, mapping, decisions, server layout, run structure, progress, and completion documentation.

## Notable validation finding
Bulk wrapper validation exposed a MultiQC environment incompatibility (NumPy/SciPy binary mismatch). This was documented and intentionally deferred to the later Environment Modernization & Version Control sub-block within Phase 3.

## Conclusion
The Pipeline Architecture & Operating Structure block is complete at the intended level for Phase 3 hardening. Remaining future work will build on this architecture rather than redefine it.
