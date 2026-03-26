# Phase 3 Block Completion Note — scRNA-seq Task 5/6 (STARsolo path)
Date: 2026-03-24

## Block Scope
Task 5: Replace hard-coded paths and parameters with configuration variables  
Task 6: Validate configuration handling across all pipeline stages

This note documents completion status for the scRNA-seq STARsolo branch.

## Status
Substantially completed and validated for the STARsolo path.

## Completed work

### 1. Wrapper brought into config-driven operation
The scRNA-seq wrapper was updated to support:
- config-driven execution
- manifest-driven sample iteration
- canonical run directory creation
- stage toggles for preprocess, QC, and downstream core
- reuse of prior preprocessing outputs via `PREPROCESS_SOURCE_RUN_DIR`

### 2. Preprocessing integrated into wrapper
STARsolo preprocessing is now dispatched from the wrapper using:
- manifest-defined sample metadata
- config-defined reference paths
- config-defined thread and memory settings
- canonical run output locations under `runs/<run_id>/outputs/starsolo/<sample_run_id>/`

This replaced prior reliance on standalone one-off execution patterns.

### 3. QC stage parameterized and integrated
The QC pipeline was fully wired into the wrapper for STARsolo, including:
- `01_build_sce_object.R`
- `02_compute_qc_metrics.R`
- `03_barcode_rank_plot.R`
- `04_run_emptydrops.R`
- `05_apply_emptydrops_filter.R`
- `06_filter_low_quality_cells.R`
- `07_run_scdblfinder.R`
- `08_remove_doublets.R`
- `09_plot_qc_metrics.R`

QC output paths are now generated under the canonical run structure:
- `qc/<sample_run_id>/objects`
- `qc/<sample_run_id>/tables`
- `qc/<sample_run_id>/plots`

### 4. Runtime/environment handling parameterized
To support mixed R runtime requirements, config variables were added:
- `RSCRIPT_BIN`
- `SCDBLFINDER_RSCRIPT_BIN`

Wrapper behavior now uses:
- base R for standard QC/downstream steps
- dedicated `scrna_dbl` R runtime for:
  - `07_run_scdblfinder.R`
  - `08_remove_doublets.R`

This eliminated dependence on the active shell environment and made execution deterministic.

### 5. Downstream core integrated into wrapper
The downstream core stage was wired into the wrapper using the QC singlet-filtered SCE as input. The wrapper now dispatches:
- `10_normalize_hvg.R`
- `20_run_pca.R`
- `21_assess_pc_covariates.R`
- `22_regress_covariates_and_rerun_pca.R`
- `24_assess_any_reduceddim_covariates.R`
- `23_merge_pca_variants.R`
- `30_build_knn_graphs.R`
- `31_cluster_knn_graphs.R`
- `32_run_umap.R`
- `33_run_tsne.R`

Downstream outputs are organized under:
- `downstream/<sample_run_id>/objects`
- `downstream/<sample_run_id>/tables`

### 6. Configuration templates updated
The following config files were updated to align with wrapper runtime needs:
- `config/template_scrnaseq.env`
- `config/examples/scrna_pbmc1k_starsolo.env`
- `config/examples/scrna_pbmc1k_cellranger.env`

Updates included:
- `RSCRIPT_BIN`
- `SCDBLFINDER_RSCRIPT_BIN`
- `QC_MATRIX_TYPE="raw"` as the safe default for QC chains using EmptyDrops

## Validation performed

### A. Wrapper validation
Confirmed:
- config loading works
- manifest validation works
- run directory creation works
- dry-run validation works
- stage toggles behave correctly

### B. STARsolo preprocessing validation
Confirmed the wrapper can dispatch STARsolo preprocessing and produce outputs in canonical run locations.

Validated sample:
- `pbmc_1k_v3_GRCh38g49`

### C. STARsolo QC validation
Confirmed successful QC execution from wrapper using reused preprocessing outputs.

Observed validated counts:
- raw barcodes: 481,442
- EmptyDrops retained: 1,259
- low-quality retained: 1,123
- doublets called: 34
- singlets retained: 1,089

### D. STARsolo downstream core validation
Confirmed successful downstream execution from the wrapper on the singlet-filtered object, including:
- HVG selection
- PCA and regressed PCA
- covariate assessment
- graph construction
- clustering
- UMAP
- t-SNE

Observed validated outputs included:
- normalized/HVG SCE
- PCA SCE
- regressed PCA SCE
- merged downstream-ready SCE
- graph-annotated SCE
- clustered SCE
- UMAP SCE
- UMAP+tSNE SCE

## Remaining gap
The Cell Ranger branch has not yet been fully validated through the same wrapper/QC/downstream flow. The structure is now aligned, but an explicit end-to-end validation pass is still needed to close the entire scRNA-seq task block across both preprocessing engines.

## Conclusion
For the STARsolo path, Task 5 and Task 6 are functionally complete:
- hard-coded execution paths have been replaced with config/wrapper-driven execution
- pipeline stages are parameterized and organized under the canonical run structure
- configuration handling has been validated across preprocess reuse, QC, and downstream core
- mixed-runtime handling for scDblFinder has been implemented and validated

Full scRNA-seq block closure now depends primarily on validating the Cell Ranger branch through the same wrapper-controlled path.
