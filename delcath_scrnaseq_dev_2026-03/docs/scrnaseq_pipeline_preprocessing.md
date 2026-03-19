# scRNA-seq Preprocessing Pipeline
Summit Informatics – Delcath Development Environment

## Overview

This repository contains the preprocessing workflows used for development of the
single-cell RNA-seq analysis pipeline for Delcath.

The preprocessing layer generates gene × cell expression matrices from raw
FASTQ sequencing data using two independent processing backends:

- Cell Ranger (10x Genomics reference pipeline)
- STARsolo (open-source alternative implemented with STAR)

Running both pipelines allows validation of preprocessing results and
ensures reproducibility across independent implementations.

---

# Pipeline Phases Completed

## 1. Dataset & Platform Identification

A reference dataset was selected to validate the pipeline.

Dataset:
PBMC 1k v3 (10x Genomics demonstration dataset)

Platform:
10x Genomics Chromium

Reference genome:
GRCh38 primary assembly

Annotation:
GENCODE v49

A compatible reference was generated using:

cellranger mkref

This produced a ~32 GB reference including:

- genome FASTA
- GTF annotation
- STAR genome indices

---

## 2. Data Ingestion & Organization

FASTQ files were downloaded and organized into the standardized project
directory structure.

Key steps:

- Download sequencing FASTQ files
- Validate read structure and lane organization
- Confirm compatibility with the 10x Genomics platform
- Organize files into the project FASTQ directory

A metadata manifest was created:

metadata/cellranger_runs.tsv

This manifest tracks:

- dataset identifiers
- FASTQ locations
- reference genome
- expected cell counts
- chemistry

This enables reproducible pipeline execution.

---

## 3. Raw Processing & Matrix Generation

Two preprocessing pipelines were implemented.

### Cell Ranger

A manifest-driven workflow was implemented using:

scripts/run_cellranger_from_manifest.sh

Features:

- automated dataset processing
- idempotent execution
- structured output directories
- reproducible runs

Outputs generated:

- gene × cell matrices
- sorted BAM alignments
- QC metrics

Location:

runs/cellranger_count/

Validation dataset successfully processed.

---

### STARsolo

A second preprocessing pipeline was implemented using STARsolo.

Execution script:

scripts/starsolo/run_starsolo_from_manifest.sh

Manifest:

metadata/starsolo_runs.tsv

Features:

- multi-lane FASTQ aggregation
- structured logging
- reproducible execution

Output location:

runs/starsolo/

---

## Validation Results

Dataset: PBMC 1k v3

### STARsolo

Raw barcodes detected:
481,442

Filtered cells:
1,233

### Cell Ranger

Filtered cells:
1,211

The close agreement between the pipelines confirms correct preprocessing
implementation.

---

## 4. Cell-Level Quality Control

After matrix generation, matrices are imported into R and processed through a
modular quality control workflow implemented in `scripts/qc/`.

This workflow converts raw gene × cell matrices into filtered singlet-only
SingleCellExperiment objects suitable for downstream analysis.

QC workflow steps:

1. Build SingleCellExperiment object from matrix files
2. Compute per-cell QC metrics
3. Generate barcode-rank plots
4. Identify cell-containing droplets using emptyDrops
5. Apply empty droplet filtering
6. Filter low-quality cells based on UMI counts, gene counts, and mitochondrial percentage
7. Detect doublets using scDblFinder
8. Remove predicted doublets and retain singlets
9. Generate QC summary plots

Outputs generated:

- SingleCellExperiment objects
- QC metrics tables
- emptyDrops result tables
- low-quality filtering summaries
- doublet classification tables
- singlet-filtered analysis objects

These filtered objects are used as inputs for downstream normalization,
feature selection, and clustering.

---

## Downstream Outputs

The preprocessing layer generates:

Gene × cell matrices

STARsolo:
runs/starsolo/<run_id>/Solo.out/Gene/

Cell Ranger:
runs/cellranger_count/<run_id>/outs/

These matrices are used for downstream analysis:

- cell-level quality control
- normalization
- clustering
- cell-type annotation

---

## Next Pipeline Stage

Next steps:

Normalization and feature modeling

This stage will include:

- library size normalization
- highly variable gene selection
- dimensionality reduction (PCA)
- clustering and exploratory visualization
- preparation for cell type annotation

---

## Environment

Execution environment:

Linux (WSL2)

Tools used:

STAR
Cell Ranger
R
SingleCellExperiment
DropletUtils
scDblFinder

---

## Status

The preprocessing and QC layers of the scRNA-seq pipeline have been
successfully implemented and validated using the PBMC 1k reference dataset.

Next stage:
Normalization, feature selection, dimensionality reduction, clustering,
and cell type annotation.
