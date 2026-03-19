# Delcath scRNA-seq Development Pipeline
Pipeline Version: 0.1.0

This repository contains development workflows for a reproducible single-cell RNA-seq analysis pipeline used in the Delcath bioinformatics environment.

The pipeline supports two independent preprocessing backends:

- Cell Ranger (10x Genomics reference pipeline)
- STARsolo (open-source STAR implementation)

Running both pipelines enables cross-validation of preprocessing results and ensures reproducibility across different implementations.

------------------------------------------------------------

PIPELINE STAGES

Current development status:

✓ Dataset selection
✓ Data ingestion
✓ Reference preparation
✓ Raw preprocessing (Cell Ranger + STARsolo)
✓ Gene × cell matrix generation
✓ Cell-level quality control
✓ Empty droplet filtering (emptyDrops)
✓ Low-quality cell filtering
✓ Doublet detection and singlet retention

Next stage:

- Normalization
- Highly variable gene selection
- Dimensionality reduction and clustering
- Cell type annotation

------------------------------------------------------------

REPOSITORY STRUCTURE

delcath_scrnaseq_dev_2026-03
│
├── README.md
├── VERSION
│
├── analysis/
│   ├── 01_load_counts_scRNA.R
│   ├── 02_compare_backends_scRNA.R
│   └── qc/
│
├── config/
│   └── project.env
│
├── data/
│   ├── fastq/
│   ├── manifest/
│   ├── refs/
│   └── sra/
│
├── docs/
│   ├── pbmc1k_qc_validation_notes.md
│   ├── run_records/
│   └── scrnaseq_pipeline_preprocessing.md
│
├── logs/        (execution logs; ignored by git where applicable)
├── metadata/
│   ├── cellranger_runs.tsv
│   └── starsolo_runs.tsv
├── ref/
│   ├── cellranger_ref/
│   ├── src/
│   └── star_index/
├── results/     (analysis outputs; ignored by git where applicable)
├── runs/        (pipeline outputs; ignored by git where applicable)
│
└── scripts/
    ├── cellranger/
    ├── qc/
    ├── run_cellranger_from_manifest.sh
    ├── starsolo/
    └── utils/

Directory purposes:

analysis/
R scripts used for matrix loading, backend comparison, validation, and downstream analysis.

scripts/
Pipeline execution scripts used for preprocessing, QC, and helper utilities.

metadata/
Manifest files describing datasets, FASTQ locations, reference genome configuration, and pipeline parameters.

docs/
Pipeline documentation, validation notes, and run records.

runs/
Generated pipeline outputs such as alignments and count matrices. These are excluded from version control.

logs/
Execution logs produced during pipeline runs. These are excluded from version control where applicable.

results/
Derived outputs generated during analysis and validation.

ref/
Reference assets used by Cell Ranger and STARsolo workflows.

analysis/qc/
Backend-specific QC summary tables and validation outputs generated during PBMC 1k testing.

------------------------------------------------------------

VALIDATION DATASET

The pipeline was validated using the PBMC 1k v3 dataset from 10x Genomics.

Preprocessing comparison results:

Backend        Filtered Cells
STARsolo       1233
Cell Ranger    1211

The close agreement between pipelines confirms correct preprocessing configuration and successful reference generation.

Downstream QC validation was also performed on PBMC 1k, including:

- per-barcode QC metric calculation
- barcode-rank visualization
- emptyDrops filtering
- low-quality cell filtering
- doublet detection with scDblFinder
- singlet-only object generation

------------------------------------------------------------

ENVIRONMENT

Execution environment:
Linux (WSL2)

Primary tools used:

STAR
Cell Ranger
R
SingleCellExperiment
DropletUtils
scDblFinder

------------------------------------------------------------

PIPELINE OUTPUTS

The preprocessing layer generates gene × cell count matrices.

STARsolo outputs:
runs/starsolo/<run_id>/Solo.out/Gene/

Cell Ranger outputs:
runs/cellranger_count/<run_id>/outs/

These matrices are imported into R and processed through a modular QC workflow that produces:

- SingleCellExperiment objects
- per-cell QC metric tables
- emptyDrops result tables
- low-quality filtering summaries
- scDblFinder doublet classification tables
- singlet-filtered SingleCellExperiment objects

These filtered objects are used for downstream analysis steps including:

- normalization
- highly variable gene selection
- dimensionality reduction (PCA / UMAP)
- clustering
- cell type annotation

------------------------------------------------------------

QC WORKFLOW

The QC stage is implemented as a modular R workflow in scripts/qc/:

- 01_build_sce_object.R
- 02_compute_qc_metrics.R
- 03_barcode_rank_plot.R
- 04_run_emptydrops.R
- 05_apply_emptydrops_filter.R
- 06_filter_low_quality_cells.R
- 07_run_scdblfinder.R
- 08_remove_doublets.R
- 09_plot_qc_metrics.R

This workflow converts raw gene × cell matrices into QC-filtered singlet-only SingleCellExperiment objects suitable for downstream analysis.

------------------------------------------------------------

STATUS

The preprocessing and QC layers of the scRNA-seq pipeline have been successfully implemented and validated on the PBMC 1k reference dataset.

Next stage:
Normalization, feature selection, dimensionality reduction, clustering, and annotation.
