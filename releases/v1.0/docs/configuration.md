# Configuration Guide

## Purpose

The Summit Informatics v1.0 pipelines are controlled through environment-style configuration files (`.env`). These files define all parameters required to execute a pipeline run, including dataset inputs, reference resources, compute settings, stage selection, and output behavior.

Users should modify configuration files rather than editing pipeline scripts directly.

This guide applies to the deployed shared production environment:

    /srv/bioinformatics/pipelines/v1.0

---

## Configuration Model

Both bulk RNA-seq and scRNA-seq pipelines use structured `.env` configuration files.

These files are loaded by wrapper scripts and control:

- Input data and manifests
- Reference genome and annotation resolution
- Resource allocation (threads, memory)
- Pipeline stage execution
- Output locations
- Logging and metadata capture

This allows the same pipeline code to be reused across datasets and environments without modification.

---

## Configuration Structure

Configuration files are organized into logical sections:

### RUN

Defines run identity and execution behavior.

Typical fields:

- `RUN_ID` — unique identifier for the run (auto-generated if not provided)
- `PIPELINE_NAME` — pipeline identifier (e.g., `bulk_rnaseq`, `scrnaseq`)
- `RUN_MODE` — execution mode (e.g., full, partial)
- `DRY_RUN` — if set, validates configuration without executing

---

### INPUT

Defines dataset-specific inputs.

Typical fields:

- `FASTQ_ROOT` — directory containing input FASTQ files
- `MANIFEST_FILE` — sample manifest describing input files
- `SAMPLE_SHEET` — optional structured metadata
- `SPECIES` — organism identifier

---

### REF

Defines reference genome and annotation resources.

Typical fields:

- `REF_ROOT` — root reference directory
- `ORGANISM` — species name
- `GENOME_BUILD` — genome version (e.g., GRCh38)
- `ANNOTATION_VERSION` — annotation release (e.g., gencode_v49)

Optional resolved paths:

- `STAR_INDEX`
- `SALMON_INDEX`
- `CELLRANGER_REF`

References are typically stored under:

    /srv/bioinformatics/refs/

---

### RESOURCE

Defines compute resources.

Typical fields:

- `THREADS` — number of CPU threads
- `MEMORY_GB` — memory allocation

---

### OUTPUT

Defines output and working directories.

Typical fields:

- run output directories
- intermediate storage paths
- final result locations

All outputs are generated within structured run directories.

---

### QC

Controls quality control stages.

Typical fields:

- enable/disable QC steps
- thresholds for filtering
- QC reporting behavior

---

### ANALYSIS

Controls downstream core analysis stages.

Typical fields:

- normalization settings
- clustering parameters
- stage toggles for downstream processing

---

### LOG

Controls logging behavior.

Typical fields:

- log directory locations
- verbosity levels
- execution trace options

---

## Bulk RNA-seq Configuration Notes

Bulk RNA-seq configuration controls:

- Raw FASTQ quality control
- Adapter trimming
- Salmon quantification
- tximport summarization
- Optional STAR alignment

Stage toggles allow enabling or disabling:

- QC
- trimming
- post-trim QC
- quantification
- alignment

Reference settings must include:

- Salmon index
- STAR genome index
- transcript-to-gene mapping

---

## scRNA-seq Configuration Notes

The scRNA-seq pipeline supports two backends:

- Cell Ranger
- STARsolo

Configuration controls:

- backend selection
- manifest selection
- preprocessing and QC stages
- downstream core analysis

Typical controls include:

- enabling preprocessing
- enabling QC
- enabling downstream analysis
- optional analysis templates

Reference configuration must match the selected backend.

---

## Execution Controls

Pipelines support controlled execution and restart behavior.

Key parameters:

- `START_STAGE` — begin execution from a specific stage
- `END_STAGE` — stop execution at a specific stage
- `RERUN_FAILED_ONLY` — rerun only failed stages

These controls allow:

- partial execution
- restart from failure
- targeted reruns

---

## Minimal Example

```bash
RUN_ID=test_run
PIPELINE_NAME=bulk_rnaseq

FASTQ_ROOT=/srv/bioinformatics/data/example_fastq
MANIFEST_FILE=/srv/bioinformatics/pipelines/v1.0/manifests/example.env

REF_ROOT=/srv/bioinformatics/refs
ORGANISM=human
GENOME_BUILD=grch38
ANNOTATION_VERSION=gencode_v49

THREADS=8
MEMORY_GB=32
```

---

## Using Configuration Files

Configuration files are passed to pipeline wrapper scripts at runtime.

### Bulk RNA-seq

    bash /srv/bioinformatics/pipelines/v1.0/scripts/bulk/run_bulk_wrapper_v4.sh \
      --config /srv/bioinformatics/pipelines/v1.0/manifests/example.env

### scRNA-seq (Cell Ranger)

    bash /srv/bioinformatics/pipelines/v1.0/scripts/scrna/run_scrnaseq_wrapper.sh \
      --config /srv/bioinformatics/pipelines/v1.0/manifests/example.env

### scRNA-seq (STARsolo)

    bash /srv/bioinformatics/pipelines/v1.0/scripts/scrna/run_scrnaseq_wrapper.sh \
      --config /srv/bioinformatics/pipelines/v1.0/manifests/example_starsolo.env

---

Configuration files are the primary interface to the pipeline system. All execution behavior should be controlled through configuration rather than direct script modification.
