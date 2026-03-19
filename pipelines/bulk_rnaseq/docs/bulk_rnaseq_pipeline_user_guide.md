# Bulk RNA-seq Pipeline User Guide  
Project: Delcath CRC Bulk RNA-seq  
Author: Summit Informatics  
Last Updated: 2026-02-18  

---

# 1. Overview

This pipeline performs modular, production-style processing of bulk RNA-seq FASTQ data.

It supports the following stages:

1. Raw Quality Control (FastQC + MultiQC)
2. Adapter trimming and filtering (fastp)
3. Optional post-trim QC
4. Transcript quantification (Salmon)
5. Gene-level summarization (tximport)
6. Genome alignment and gene counts (STAR)

Execution is controlled via:

- A configuration file (.env)
- A centralized wrapper script

The pipeline is fully stage-toggle driven, supports raw vs trimmed input selection, and logs all runs with isolated run identifiers.

---

# 2. Directory Structure

bioinformatics_projects/
└── delcath_crc_bulk_rnaseq_2026-02/
    ├── scripts/
    ├── config/
    │   ├── pipeline.env
    │   └── tests/
    ├── data/
    ├── results/
    ├── docs/
    └── star_pilot/

---

# 3. Core Components

---

# 3.1 Wrapper Script

File:
scripts/run_pilot_wrapper.sh

Purpose:
Central orchestration script controlling the entire workflow.

Responsibilities:
- Load configuration
- Validate required variables
- Enforce stage dependencies
- Validate tool availability
- Select raw vs trimmed inputs
- Execute enabled stages
- Track run-specific output directories
- Log execution metadata

Execution:

bash scripts/run_pilot_wrapper.sh config/<config_file>.env

---

# 3.2 Configuration Files

Location:
config/
config/tests/

Purpose:
Externalize runtime parameters and stage toggles.

Each processing scenario should use a separate .env file.

---

## Required Variables

THREADS  
RUN_ID  
PILOT_FASTQ_DIR  
QC_OUT_ROOT  
TRIM_OUT_ROOT  
SALMON_OUT_ROOT  
TXIMPORT_OUT_ROOT  
STAR_OUT_ROOT  
SALMON_INDEX  
TX2GENE  
STAR_INDEX  

---

## Stage Toggles (1 = enabled, 0 = disabled)

DO_QC_RAW  
DO_TRIM  
DO_QC_POSTTRIM  
DO_SALMON  
DO_TXIMPORT  
DO_STAR  

---

## Optional Input Selection

SALMON_INPUT=raw|trimmed  
STAR_INPUT=raw|trimmed  

Defaults to trimmed.

If trimmed is selected, DO_TRIM must equal 1.

---

# 4. Workflow Scripts

---

# 4.1 QC Script

File:
scripts/qc_fastq.sh

Tools:
- FastQC
- MultiQC

Inputs:
-i FASTQ directory  
-o Output root  
--run-id  
-t Threads  

Outputs:

<OUTPUT_ROOT>/<run_id>/
├── fastqc outputs
├── multiqc_report.html
└── multiqc_data/

Purpose:
Evaluates:
- Base quality
- Adapter presence
- GC content
- Duplication rate
- Overrepresented sequences

---

# 4.2 Trimming Script

File:
scripts/trim_fastp.sh

Tool:
fastp

Inputs:
Raw paired-end FASTQs

Outputs:

<TRIM_OUT_ROOT>/trim_<RUN_ID>/
├── trimmed FASTQs
├── reports/
│   ├── *.fastp.html
│   └── *.fastp.json

Operations:
- Adapter detection
- Quality filtering
- Length filtering
- Paired-end synchronization

---

# 4.3 Salmon Quantification

File:
scripts/salmon_quant.sh

Tool:
Salmon (selective-alignment mode)

Inputs:
Paired FASTQs  
Salmon index  

Outputs:

<SALMON_OUT_ROOT>/salmon_<RUN_ID>/
└── <Sample>/
    ├── quant.sf
    ├── aux_info/
    ├── logs/
    └── cmd_info.json

Notes:
- Automatically detects library type
- Uses validateMappings
- Generates transcript-level abundance estimates

---

# 4.4 tximport Gene-Level Summarization

File:
scripts/tximport_genelevel.R

Tool:
R + tximport

Inputs:
Salmon output directory  
tx2gene mapping file  

Outputs:

<TXIMPORT_OUT_ROOT>/txi_<RUN_ID>/
├── gene_counts.csv
├── gene_tpm.csv
├── run_info.txt
└── logs/

Purpose:
Converts transcript-level abundance estimates to gene-level matrices suitable for:
- DESeq2
- edgeR
- Downstream statistical analysis

---

# 4.5 STAR Alignment

File:
scripts/star_align.sh

Tool:
STAR aligner

Inputs:
FASTQs (raw or trimmed)  
STAR genome index  

Outputs:

<STAR_OUT_ROOT>/star_<RUN_ID>/
└── <Sample>/
    ├── Aligned.sortedByCoord.out.bam
    ├── ReadsPerGene.out.tab
    ├── Log.final.out
    ├── SJ.out.tab

Metrics Reported:
- Mapping rate
- Unique mapping %
- Multi-mapping %
- Splice junction counts
- Mismatch rate
- Unmapped read categories

STAR produces coordinate-sorted BAM files and gene-level counts.

---

# 5. Execution Workflow

---

## Step 1: Create a Config File

Example:

nano config/production_crc.env

---

## Step 2: Run the Wrapper

bash scripts/run_pilot_wrapper.sh config/production_crc.env

---

## Step 3: Monitor Logs

Wrapper log location:

results/wrapper_runs/<RUN_ID>/wrapper.log

Each stage also logs internally within its run directory.

---

# 6. Stage Dependency Rules

DO_TXIMPORT=1 requires DO_SALMON=1  
DO_QC_POSTTRIM=1 requires DO_TRIM=1  
SALMON_INPUT=trimmed requires DO_TRIM=1  
STAR_INPUT=trimmed requires DO_TRIM=1  

Dependency violations will terminate execution.

---

# 7. Storage Considerations

Approximate sizes per sample:

Trimmed FASTQs: ~6 GB  
Salmon output: <200 MB  
tximport output: ~3 MB  
STAR BAM: ~1.5–2 GB  

STAR alignment is the primary storage consumer.

Ensure sufficient disk space before production runs.

---

# 8. Reproducibility Features

- Config-driven execution
- Explicit RUN_ID tagging
- Tool version logging
- Structured output directories
- Stage isolation
- Dependency enforcement
- Central wrapper logging

---

# 9. Recommended Production Flow (CRC Dataset)

1. Confirm FASTQ location and accessibility
2. Verify reference genome consistency
3. Create dedicated production config
4. Execute full trimmed pipeline
5. Review QC reports
6. Review STAR Log.final.out metrics
7. Validate Salmon mapping rate
8. Deliver gene-level matrices

---

# 10. Summary

This pipeline provides:

- Modular execution
- Configurable stage control
- Transcript-level quantification (Salmon)
- Alignment-based quantification (STAR)
- Gene-level summarization (tximport)
- Structured logging
- Production-grade safeguards

It is suitable for:
- Internal data processing
- Enterprise handoff
- Expansion to additional datasets
- Long-term operational use
