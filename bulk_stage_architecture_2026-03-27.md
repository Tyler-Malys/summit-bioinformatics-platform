# Bulk RNA-seq Stage Architecture
Date: 2026-03-27

## Objective
Define explicit stage architecture for the bulk RNA-seq pipeline as part of Phase 3 (Pipeline Hardening & Configurability), aligned with the current implementation and without redesigning the pipeline.

## Current Canonical Run Structure
Bulk runs are currently organized under:

runs/<run_id>/
  input/
  working/
  logs/
  qc/
  outputs/
  downstream/
  final/
  run_metadata/

This structure is created by the wrapper and is consistent across observed runs.

## Canonical Wrapper
Primary wrapper:
- scripts/run_bulk_wrapper_v3.sh

Primary stage-capable scripts:
- scripts/qc_fastq.sh
- scripts/trim_fastp.sh
- scripts/salmon_quant.sh
- scripts/tximport_genelevel.R
- scripts/star_align.sh

Supporting utility:
- scripts/utils/register_reference.sh

Legacy / historical scripts:
- scripts/legacy/*
- scripts/run_pilot_wrapper.sh
- scripts/run_pilot_wrapper_v2.sh

## Bulk Logical Stage Architecture

### Stage 0 — Input Preparation & Validation
Purpose:
- prepare and validate the input FASTQ set before analytical processing

Current substages:
- Stage 0a: localize raw FASTQs
- Stage 0b: integrity check (gzip -t)
- Stage 0c: filter usable FASTQs for downstream execution

Inputs:
- configured FASTQ source / pilot FASTQ directory

Outputs:
- localized FASTQ directory (when enabled)
- filtered FASTQ directory
- integrity reports:
  - working/integrity/ok_fastqs.txt
  - working/integrity/bad_fastqs.txt

### Stage 1 — Raw QC
Script:
- scripts/qc_fastq.sh

Purpose:
- run FastQC and MultiQC on raw input FASTQs

Inputs:
- raw/localized/filtered FASTQ set

Outputs:
- QC reports under configured QC output root

### Stage 2 — Read Preprocessing
Script:
- scripts/trim_fastp.sh

Purpose:
- perform optional adapter/quality trimming with fastp

Inputs:
- raw/localized/filtered FASTQ set

Outputs:
- trimmed FASTQ output directory
- trimming reports/logs

### Stage 2b — Post-trim QC
Script:
- scripts/qc_fastq.sh

Purpose:
- optional FastQC/MultiQC on trimmed FASTQs

Dependency:
- requires Stage 2

Inputs:
- trimmed FASTQ directory

Outputs:
- post-trim QC reports under configured QC output root

### Stage 3 — Salmon Quantification
Script:
- scripts/salmon_quant.sh

Purpose:
- transcript-level quantification with Salmon

Inputs:
- raw or trimmed FASTQs, selected by config

Outputs:
- Salmon quantification run directory

### Stage 4 — Gene-Level Consolidation
Script:
- scripts/tximport_genelevel.R

Purpose:
- summarize Salmon transcript quantification to gene-level outputs

Dependency:
- requires Stage 3

Inputs:
- Salmon run directory
- tx2gene mapping

Outputs:
- gene-level quantification directory

### Stage 5 — STAR Alignment
Script:
- scripts/star_align.sh

Purpose:
- alignment with STAR

Inputs:
- raw or trimmed FASTQs, selected by config

Outputs:
- STAR alignment run directory

## Architectural Notes
1. The pipeline is config-driven and stage-toggled.
2. The pipeline is not a single strictly linear chain.
3. Salmon and STAR are optional execution branches.
4. tximport depends on Salmon output.
5. post-trim QC depends on trimming output.
6. The canonical run container structure is already in place even where some stage outputs are still written to configured external roots.
7. register_reference.sh is a support utility, not a runtime analytical stage.

## Summary
The bulk RNA-seq pipeline already has a clear production-oriented wrapper and canonical run structure. The current architecture can be explicitly documented as a staged, config-driven pipeline with:
- input preparation/validation
- QC
- preprocessing
- optional quantification/alignment branches
- optional gene-level consolidation
- canonical run metadata and logging

This stage definition will support the next Phase 3 steps:
- refactoring scripts into modular stage-based components
- implementing a standardized stage execution framework
- adding stage-level logging/status markers
- validating stage independence

## Additional Delivered Downstream Analysis Modules

In addition to the core automated wrapper-driven processing pipeline, the bulk RNA-seq package includes a structured downstream analysis workflow built on top of the gene-level outputs produced by the core pipeline.

These downstream components are not currently executed by the main bulk wrapper, but they are included as pipeline-supported, analyst-invoked modules and form a logical follow-on analysis sequence.

### Downstream Analysis Module Architecture

#### Stage A — Analysis Object Construction
Script:
- analysis/01_build_analysis_object.R

Purpose:
- build analysis-ready DESeq2 objects from gene-level count matrices
- perform gene filtering
- generate normalized DESeq2 object and variance-stabilized object

Inputs:
- gene-level counts matrix

Outputs:
- DESeq2 object (`dds.rds`)
- VST object (`vsd.rds`)

#### Stage B — Transformation Diagnostics
Script:
- analysis/01b_vst_diagnostics.R

Purpose:
- evaluate variance-stabilizing transformation behavior

Inputs:
- VST object

Outputs:
- mean-SD diagnostic plot

#### Stage C — Exploratory Data Analysis / PCA QC
Script:
- analysis/02_pca_qc.R

Purpose:
- perform PCA-based sample-level QC and exploratory analysis

Inputs:
- VST object

Outputs:
- PCA plot
- PCA scores table

#### Stage D — Differential Expression Analysis
Script:
- analysis/03_differential_expression.R

Purpose:
- run DESeq2-based differential expression contrasts
- export unshrunk and optionally shrunken results
- summarize contrast-level significance counts

Inputs:
- DESeq2 object

Outputs:
- DE result tables
- contrast summary table

#### Stage E — Gene Set Enrichment Analysis
Script:
- analysis/04_gsea_fgsea.R

Purpose:
- generate ranked gene lists from DE results
- map identifiers as needed
- run fgsea-based pathway enrichment analysis

Inputs:
- differential expression result tables
- GMT pathway collection files
- GSEA output root

Outputs:
- fgsea result tables
- ranked gene tables
- enrichment plots
- serialized RDS outputs

#### Stage F — GSEA Aggregation / Reporting
Script:
- analysis/05_gsea_summary_tables.R

Purpose:
- aggregate pathway enrichment results across contrasts
- identify shared pathways, directional consistency, and pooled-vs-individual comparison patterns
- generate wide-format summary tables and ranked summary outputs

Inputs:
- fgsea output root

Outputs:
- significant pathway summary tables
- shared Hallmark/Reactome summary tables
- NES matrices
- ranked summary CSVs

#### Stage G — GSEA Visualization
Script:
- analysis/06_gsea_heatmaps.R

Purpose:
- generate clustered pathway heatmaps from GSEA summary tables

Inputs:
- GSEA summary tables

Outputs:
- Hallmark and Reactome heatmaps (PDF/PNG)

### Supporting Materials for Downstream Analysis
Additional downstream-analysis-related materials currently present in the bulk pipeline package include:

- cached analysis objects under `analysis_objects/`
- supporting notes and run records under `docs/`
- analysis-specific execution logs under `docs/run_records/`

### Architectural Notes on Scope
1. The bulk RNA-seq package therefore contains two major layers:
   - a core automated processing pipeline
   - a supported downstream analysis workflow
2. The downstream analysis workflow is structured, modular, and sequential, but is not currently orchestrated by the main bulk wrapper.
3. These downstream scripts should be treated as pipeline-supported analysis modules rather than mandatory stages of the core automated processing path.
4. Utility and administrative scripts such as `scripts/utils/register_reference.sh` remain outside both the core processing stage sequence and the downstream analysis sequence.
5. The downstream analysis workflow (Stages A–G) is executed independently of the main wrapper and is not currently integrated into wrapper-driven stage execution.

