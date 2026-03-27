## scRNA-seq Pipeline Stage Architecture (Phase 3)

### Overview

This document defines the explicit stage architecture for the scRNA-seq pipeline as implemented in the current production system.

The architecture is derived from:

* the operational wrapper: `scripts/run_scrnaseq_wrapper.sh`
* associated QC and downstream scripts under `scripts/qc/` and `scripts/downstream/`
* validated run directory structure under `runs/`

This pipeline is **config-driven, stage-controlled, and backend-aware**, supporting both Cell Ranger and STARsolo preprocessing.

---

## Architectural Layers

The scRNA-seq pipeline consists of two major layers:

### 1. Core Automated Pipeline (Wrapper-Driven)

* executed via wrapper
* stage toggles control execution
* produces analysis-ready SingleCellExperiment objects

### 2. Extended Analysis Modules (Pipeline-Supported)

* partially integrated into wrapper
* implemented as modular scripts
* support biological interpretation and reporting

---

## Core Automated Pipeline Stages

### Stage 0 — Run Setup & Validation

**Responsibilities**

* load and normalize configuration
* resolve reference paths
* resolve manifest
* validate required inputs and tools
* create run directory structure
* initialize logging and metadata

**Outputs**

* run directory:

  * input/
  * working/
  * logs/
  * outputs/
  * qc/
  * downstream/
  * final/
  * run_metadata/

---

### Stage 1 — Preprocessing (Backend Execution)

Controlled by:

* `RUN_PREPROCESS`

**Branches**

#### Cell Ranger

* per-sample `cellranger count`

#### STARsolo

* per-sample STARsolo execution
* FASTQ pairing and chemistry handling

**Outputs**

* gene count matrices
* BAM files
* backend-specific outputs

---

### Stage 2 — QC & Filtering Pipeline

Controlled by:

* `RUN_QC`

**Scripts**

* `01_build_sce_object.R`
* `02_compute_qc_metrics.R`
* `03_barcode_rank_plot.R`
* `04_run_emptydrops.R`
* `05_apply_emptydrops_filter.R`
* `06_filter_low_quality_cells.R`
* `07_run_scdblfinder.R`
* `08_remove_doublets.R`
* `09_plot_qc_metrics.R`

**Responsibilities**

* construct SCE object
* compute QC metrics
* identify empty droplets
* filter low-quality cells
* detect and remove doublets
* generate QC plots

**Outputs**

* filtered SingleCellExperiment objects
* QC tables and plots

---

### Stage 3 — Downstream Core Analysis

Controlled by:

* `RUN_DOWNSTREAM_CORE`

**Scripts**

* `10_normalize_hvg.R`
* `20_run_pca.R`
* `21_assess_pc_covariates.R`
* `22_regress_covariates_and_rerun_pca.R`
* `23_merge_pca_variants.R`
* `24_assess_any_reduceddim_covariates.R`
* `30_build_knn_graphs.R`
* `31_cluster_knn_graphs.R`
* `32_run_umap.R`
* `33_run_tsne.R`

**Responsibilities**

* normalization and HVG selection
* dimensionality reduction (PCA)
* covariate regression
* graph construction
* clustering
* embedding (UMAP, t-SNE)

**Outputs**

* analysis-ready SCE objects with:

  * clusters
  * embeddings
  * metadata annotations

---

### Stage 4 — Backend Comparison

Controlled by:

* `RUN_COMPARE_BACKENDS`

**Script**

* `34_cluster_stability.R`

**Responsibilities**

* compute Adjusted Rand Index (ARI)
* evaluate:

  * within-backend consistency
  * cross-backend agreement

**Outputs**

* ARI comparison tables

---

## Extended Analysis Modules

These modules are included in the pipeline but are not fully orchestrated by the wrapper.

---

### Stage 5 — Marker Detection

**Scripts**

* `40_find_markers.R`
* `40_find_markers_cellranger.R`
* `40_find_markers_starsolo.R`

**Responsibilities**

* cluster-level marker identification using `scran::findMarkers`

**Outputs**

* marker tables
* top marker summaries

---

### Stage 6 — Cell Type Annotation

**Scripts**

* `41_annotate_celltypes_cellranger.R`
* `41_annotate_celltypes_starsolo.R`

**Responsibilities**

* assign biological labels:

  * cell type
  * lineage
  * confidence
* augment SCE objects

**Outputs**

* annotated SCE objects
* cluster annotation tables

---

### Stage 7 — Differential Expression (Cell-Type Level)

**Scripts**

* `42_differential_cellranger.R`
* `42_differential_starsolo.R`

**Responsibilities**

* perform limma-based DE between selected cell populations

**Outputs**

* differential expression tables

---

### Stage 8 — Pathway Enrichment

**Scripts**

* `43_pathway_enrichment_cellranger.R`
* `43_pathway_enrichment_starsolo.R`

**Responsibilities**

* FGSEA-based enrichment analysis
* Hallmark and Reactome pathways

**Outputs**

* pathway enrichment tables

---

### Stage 9 — Visualization

**Script**

* `50_export_visualizations.R`

**Responsibilities**

* generate:

  * UMAP/t-SNE plots
  * cluster distributions
  * cell type composition
  * marker dot plots
  * backend comparison plots

**Outputs**

* PNG figures

---

### Stage 10 — Reporting

**Script**

* `51_compile_visualization_report.R`

**Responsibilities**

* compile figures into PDF report

**Outputs**

* final visualization report (PDF)

---

## Architectural Notes

1. The scRNA-seq pipeline is **stage-driven and modular**, with explicit stage toggles controlling execution.

2. The pipeline supports **multiple preprocessing backends** (Cell Ranger and STARsolo), with downstream analysis partially backend-specific.

3. Core stages (0–4) are **fully automated**, while extended analysis stages (5–10) are **partially automated and analyst-driven**.

4. Backend comparison is treated as a **first-class stage**, enabling validation of preprocessing strategies.

5. The pipeline produces standardized outputs within a **canonical run directory structure**, enabling reproducibility and traceability.

6. A newer `run_scrnaseq_wrapper_v3.sh` exists as a config-driven scaffold but is not yet the authoritative execution wrapper.

7. Stages 5–10 (marker detection through reporting) are not fully executed by the current wrapper implementation. These stages are provided as pipeline-supported modules and may be executed independently or integrated into future stage-based wrapper execution.

8. Several extended analysis modules include backend-specific implementations (Cell Ranger vs STARsolo), reflecting differences in upstream processing outputs.

---

## Summary

The scRNA-seq pipeline is a **multi-stage analytical system** that integrates:

* preprocessing
* QC and filtering
* dimensional reduction and clustering
* backend comparison
* biological interpretation
* visualization and reporting

This architecture supports both **production execution** and **interactive scientific analysis workflows**.
