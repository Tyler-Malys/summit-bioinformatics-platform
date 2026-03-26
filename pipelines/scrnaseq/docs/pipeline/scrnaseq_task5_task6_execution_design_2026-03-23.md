# scRNA-seq Phase 3 Task 5/6 Execution Design
Date: 2026-03-23

## Objective
Bring the scRNA-seq pipeline into compliance with:
- Task 5: Replace hard-coded paths and parameters with configuration variables
- Task 6: Validate configuration handling across all pipeline stages

## Canonical wrapper
The canonical wrapper will be:
- scripts/run_scrnaseq_wrapper.sh

The following script will be treated as transitional / deprecated:
- scripts/run_scrnaseq_wrapper_v3.sh

## Canonical config base
The canonical config system will be based on:
- config/template_scrnaseq.env
- config/examples/*.env

The following file is considered stale and should not remain the authoritative config:
- config/project.env

## Stage model

### Core stages
- preprocess
- qc
- downstream_core

### Optional analysis stages
- markers
- annotation
- differential
- pathway
- visualization
- report

### Comparison-only stage
- compare_backends

## Required wrapper responsibilities
- load config
- normalize defaults
- validate required variables
- validate manifest schema
- create canonical run directory structure
- dispatch preprocessing by engine
- dispatch QC stages
- dispatch downstream core stages
- dispatch optional stages only when enabled
- write run metadata and software version records

## Canonical run directory structure
Each run will use:
- input/
- working/
- logs/
- qc/
- outputs/
- downstream/
- final/
- run_metadata/

Per-sample QC and downstream outputs will be written under run-specific subdirectories rather than repo-level analysis paths.

## Script classification

### Already close to compliant
QC:
- scripts/qc/01_build_sce_object.R
- scripts/qc/02_compute_qc_metrics.R
- scripts/qc/03_barcode_rank_plot.R
- scripts/qc/04_run_emptydrops.R
- scripts/qc/05_apply_emptydrops_filter.R
- scripts/qc/06_filter_low_quality_cells.R
- scripts/qc/07_run_scdblfinder.R
- scripts/qc/08_remove_doublets.R
- scripts/qc/09_plot_qc_metrics.R

Downstream core:
- scripts/downstream/10_normalize_hvg.R
- scripts/downstream/20_run_pca.R
- scripts/downstream/21_assess_pc_covariates.R
- scripts/downstream/22_regress_covariates_and_rerun_pca.R
- scripts/downstream/23_merge_pca_variants.R
- scripts/downstream/24_assess_any_reduceddim_covariates.R
- scripts/downstream/31_cluster_knn_graphs.R
- scripts/downstream/34_cluster_stability.R

### Must be modified
Wrapper/backend:
- scripts/run_scrnaseq_wrapper.sh
- scripts/run_cellranger_from_manifest.sh
- scripts/starsolo/run_starsolo_from_manifest.sh
- scripts/cellranger/run_cellranger_count_one_sample.sh
- scripts/starsolo/run_starsolo_one_sample.sh

Core downstream fixes:
- scripts/downstream/30_build_knn_graphs.R
- scripts/downstream/32_run_umap.R
- scripts/downstream/33_run_tsne.R

Late downstream / pilot analysis:
- scripts/downstream/40_find_markers_cellranger.R
- scripts/downstream/40_find_markers_starsolo.R
- scripts/downstream/41_annotate_celltypes_cellranger.R
- scripts/downstream/41_annotate_celltypes_starsolo.R
- scripts/downstream/42_differential_cellranger.R
- scripts/downstream/42_differential_starsolo.R
- scripts/downstream/43_pathway_enrichment_cellranger.R
- scripts/downstream/43_pathway_enrichment_starsolo.R
- scripts/downstream/50_export_visualizations.R
- scripts/downstream/51_compile_visualization_report.R

## Immediate implementation order
1. Expand config template to support stage toggles and qc/downstream parameters
2. Refactor canonical wrapper
3. Refactor backend runners to obey wrapper-provided paths and config
4. Integrate QC stages 01–09 into wrapper
5. Integrate downstream core stages 10–34 into wrapper
6. Fix downstream scripts with parameter/config issues
7. Refactor optional pilot-analysis stages 40–51
8. Run validation tests across representative stage combinations
