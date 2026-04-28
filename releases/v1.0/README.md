# Summit Informatics Bioinformatics Pipelines v1.0

## Overview

This release provides a production-grade bioinformatics pipeline system for processing and analyzing RNA sequencing data, including both bulk RNA-seq and single-cell RNA-seq (scRNA-seq) workflows.

The system is designed for reproducible, configurable, and scalable execution in a research or translational environment. It supports end-to-end processing from raw sequencing data through core analytical outputs, with standardized logging, environment tracking, and restartable execution.

Two primary pipelines are included:

- **Bulk RNA-seq pipeline** for gene-level quantification, quality control, and differential expression-ready outputs
- **scRNA-seq pipeline** supporting both Cell Ranger and STARsolo backends, with downstream dimensionality reduction and clustering

The pipelines are implemented using a modular, stage-based architecture and are driven by structured configuration files. Each run captures complete metadata, including configuration snapshots, software environments, and R session information, enabling full reproducibility and auditability.

This release is intended to serve as a stable, shareable reference implementation for RNA-seq data processing workflows, with clear separation between core pipeline functionality and downstream analytical templates.

## What This Release Contains

This release bundle (`v1.0`) provides a complete, self-contained bioinformatics pipeline system for bulk RNA-seq and scRNA-seq workflows.

The top-level structure is organized as follows:

- **bulk/**
  - Final validated bulk RNA-seq pipeline run and associated outputs
- **scrna/**
  - Final validated scRNA-seq runs for both Cell Ranger and STARsolo backends
- **docs/**
  - Documentation for pipeline usage, configuration, and outputs (this directory)
- **reports/**
  - Consolidated validation summaries and supporting materials
- **examples/**
  - Example outputs and reference artifacts for downstream interpretation
- **envs/**
  - Exported Conda environment specifications for reproducible environment setup
- **manifests/**
  - Example input manifests and configuration files used for validated runs

Each pipeline run included in this release contains:

- **run_metadata/**
  - Configuration snapshots, environment exports, and execution metadata
- **logs/**
  - Wrapper-level and stage-level logs for execution traceability
- **qc/**, **outputs/**, or **downstream/** directories (as applicable)
  - Core pipeline outputs and intermediate results

This release is structured to allow a user to:

1. Reconstruct the execution environment
2. Run pipelines using provided configurations and manifests
3. Inspect validated outputs and logs
4. Extend the system for additional datasets or downstream analyses

## System Architecture

The pipeline system is built around a modular, configuration-driven architecture designed for reproducibility, transparency, and controlled execution.

### Wrapper-Based Execution

Each pipeline is executed through a top-level wrapper script that orchestrates all stages of the workflow. The wrapper is responsible for:

- Loading configuration parameters from environment files
- Resolving input data and reference paths
- Managing execution flow across pipeline stages
- Capturing logs and run metadata
- Enforcing reproducibility and environment tracking

This design ensures that all runs follow a consistent execution model and produce standardized outputs.

### Stage-Based Pipeline Design

Pipelines are divided into discrete, ordered stages (e.g., QC, trimming, alignment, quantification, downstream analysis). Each stage:

- Executes independently with clearly defined inputs and outputs
- Writes its own log file
- Generates completion or failure markers

This structure enables:

- Partial execution of pipelines
- Restarting from intermediate stages
- Clear isolation of failures for debugging

### Configuration-Driven Behavior

All pipeline behavior is controlled through structured configuration files (e.g., `.env` files). These define:

- Input datasets and manifests
- Reference genome and annotation settings
- Resource allocation (threads, memory)
- Stage execution toggles
- Output locations and run identifiers

This approach allows the same pipeline code to be reused across datasets and environments without modification.

### Logging and Run Metadata

Each pipeline run produces a complete set of logs and metadata, including:

- Wrapper-level execution logs
- Stage-specific logs
- Resolved configuration files
- Environment snapshots (Conda exports, tool versions)
- Run status and timing information

All metadata is stored within a structured `run_metadata/` directory, providing full traceability of each execution.

### Reproducibility Model

Reproducibility is enforced through:

- Version-controlled pipeline code
- Pinned Conda environments
- Captured environment exports for each run
- Recorded R session information for analysis steps
- Controlled random seed initialization for stochastic components

Together, these features ensure that pipeline runs can be reproduced or audited with full fidelity.

---

This architecture supports consistent execution across environments while remaining flexible enough to support extension, parameterization, and future pipeline development.

## Supported Pipelines

This release includes two production-grade RNA-seq processing pipelines designed for reproducible and configurable execution.

### Bulk RNA-seq Pipeline

The bulk RNA-seq pipeline processes raw sequencing reads to generate gene-level quantification and analysis-ready outputs.

Core stages include:

- Raw FASTQ quality control
- Adapter trimming and read preprocessing
- Transcript-level quantification (Salmon)
- Gene-level summarization (tximport)
- Optional genome alignment (STAR)
- Quality control aggregation (MultiQC)

The pipeline produces standardized outputs including:

- Gene count matrices
- Transcript per million (TPM) matrices
- Quality control reports
- Alignment outputs (if enabled)

These outputs are suitable for downstream statistical analysis, including differential expression and pathway analysis.

---

### scRNA-seq Pipeline

The scRNA-seq pipeline processes single-cell sequencing data through preprocessing, quality control, and core downstream analysis.

Two backends are supported:

- **Cell Ranger**
- **STARsolo**

Both backends produce comparable outputs and are integrated into a unified downstream analysis workflow.

Core stages include:

- Read alignment and count matrix generation
- Cell-level quality control and filtering
- Normalization and feature selection
- Dimensionality reduction (PCA)
- Embedding (UMAP, t-SNE)
- Clustering and cluster stability analysis

The pipeline produces:

- Processed count matrices
- Single-cell experiment objects
- Dimensionality reduction embeddings
- Cluster assignments and metadata

These outputs provide a structured foundation for downstream interpretation, including cell type annotation, differential expression, and pathway analysis.

Downstream biological interpretation is not included as part of the core pipeline and is provided separately as optional analysis templates.

## Core Design Principles

The pipeline system is designed around a set of core principles to ensure reliability, reproducibility, and maintainability across environments and use cases.

### Reproducibility First

All pipeline runs are fully reproducible through:

- Configuration snapshotting
- Environment capture (Conda exports, tool versions)
- R session recording for analysis steps
- Controlled random seed initialization

Each run contains the information required to reproduce results without relying on external state.

---

### Configuration Over Code

Pipeline behavior is controlled through structured configuration files rather than code modification. This enables:

- Reuse of pipeline logic across datasets
- Consistent parameterization
- Reduced risk of user-introduced errors

Users interact with the system by modifying configuration, not pipeline scripts.

---

### Modular, Stage-Based Execution

Pipelines are organized into discrete stages with well-defined inputs and outputs. This allows:

- Partial execution
- Restart from intermediate stages
- Clear failure isolation and debugging

Execution is deterministic at the stage level.

---

### Standardized Run Structure

All pipeline runs follow a consistent directory structure, including:

- Logs
- Outputs
- Quality control artifacts
- Run metadata

This ensures that outputs are predictable and easy to navigate across runs and datasets.

---

### Transparent Execution and Logging

Every step of the pipeline is logged and traceable. Users can:

- Inspect wrapper-level execution flow
- Review stage-level logs
- Audit configuration and environment details

No pipeline behavior is hidden or implicit.

---

### Separation of Core Processing and Analysis

The system separates:

- Core data processing (included in pipelines)
- Downstream biological interpretation (provided as optional templates)

This ensures that the pipeline remains stable, generalizable, and aligned with its intended scope, while allowing flexibility for downstream analytical workflows.

## Release Layout

The `v1.0` release bundle is organized as a structured, self-contained directory intended for reproducible execution and inspection.

    <RELEASE_ROOT>/
    ├── bulk/
    │   └── final_run/
    │
    ├── scrna/
    │   ├── cellranger_final_run/
    │   └── starsolo_final_run/
    │
    ├── docs/
    ├── reports/
    ├── examples/
    ├── envs/
    ├── manifests/
    └── README.md

### Directory Overview

- **bulk/**
  - Final validated bulk RNA-seq pipeline run and outputs

- **scrna/**
  - Final validated scRNA-seq pipeline runs for both backends:
    - Cell Ranger
    - STARsolo

- **docs/**
  - Pipeline documentation (usage, configuration, outputs)

- **reports/**
  - Consolidated validation reports and summaries

- **examples/**
  - Example outputs and reference artifacts

- **envs/**
  - Conda environment specifications for reproducible setup

- **manifests/**
  - Example input manifests and configuration files

### Run Directory Structure

Each pipeline run follows a standardized internal structure:

    <run_directory>/
    ├── input/
    ├── logs/
    │   └── stages/
    ├── outputs/ or downstream/
    ├── qc/
    └── run_metadata/
        ├── stage_status/
        ├── environment/
        ├── r_sessions/
        └── resolved_config.env

This structure ensures that all runs are:

- Self-contained 
- Fully traceable 
- Consistent across pipelines and datasets 

## Requirements

The pipeline system is designed to run in a Linux-based environment with Conda-managed dependencies and R-based downstream analysis components.

### Operating System

- Linux (tested on Ubuntu 22.04)
- Windows Subsystem for Linux (WSL2) is supported and was used during development and validation

---

### Environment Management

- Conda (Miniconda or Anaconda)
- Ability to create environments from provided `.yml` files

---

### Core Software Dependencies

The following tools are required and are included via the provided Conda environments:

- FastQC
- MultiQC
- fastp
- Salmon
- STAR
- R (version 4.3.3)

---

### R Packages

R-based analysis steps depend on a set of CRAN and Bioconductor packages, including:

- DESeq2
- tximport
- SingleCellExperiment
- scran
- scuttle
- scDblFinder
- ggplot2
- dplyr

All required R packages are installed through the provided Conda environments and do not require manual installation.

---

### Hardware Requirements

Minimum recommended resources:

- CPU: 4+ cores
- Memory: 16+ GB RAM

Actual requirements depend on dataset size, particularly for scRNA-seq workflows.

---

### Data Requirements

- Input FASTQ files for bulk or scRNA-seq experiments
- Valid sample manifests and configuration files
- Reference genome and annotation resources (configured via environment settings)

---

### Notes

- All dependencies are managed through the provided environment specifications in the `envs/` directory
- Users should not install or modify dependencies manually outside of these environments
- Pipeline execution assumes access to sufficient disk space for intermediate and final outputs

## Environments

The pipeline system uses multiple Conda environments to isolate dependencies across pipeline stages and ensure reproducible execution.

All environments are defined in the `envs/` directory and can be recreated using the provided `.yml` files.

### Bulk RNA-seq Environments

- **bulk_rnaseq_env**
  - Primary environment for bulk RNA-seq processing
  - Includes core tools such as Salmon, STAR, fastp, and R (4.3.3)
  - Used for quantification, alignment, and downstream analysis steps

- **bulk_qc_tools**
  - Dedicated environment for quality control tools
  - Includes FastQC and MultiQC
  - Isolates QC dependencies to avoid conflicts with core processing tools

---

### scRNA-seq Environments

- **scrnaseq_env**
  - Primary environment for scRNA-seq processing
  - Supports both Cell Ranger and STARsolo workflows
  - Includes core single-cell analysis dependencies

- **scrna_dbl**
  - Specialized environment for doublet detection
  - Includes scDblFinder and required Bioconductor dependencies

- **scrnaseq_env_postcore**
  - Environment for downstream scRNA-seq analysis templates
  - Includes additional R packages for visualization, pathway analysis, and reporting

---

### Environment Management

- All environments are version-pinned and exported for reproducibility
- Environment specifications are located in the `envs/` directory
- Users should create environments directly from these specifications
- Manual modification of environments is not recommended

---

### Notes

- Environment separation is intentional to reduce dependency conflicts and improve stability
- Each pipeline stage invokes the appropriate environment as required
- Reproducibility depends on using the provided environment specifications without alteration

## Quick Start

This section provides a minimal workflow to set up the environment and execute the pipelines using the provided release bundle.

### 1. Prepare the environment

Set the release root directory:

    export RELEASE_ROOT=/mnt/c/bioinformatics/pipelines/v1.0
    cd $RELEASE_ROOT

Create Conda environments from the provided specifications:

    conda env create -f envs/bulk_rnaseq_env.yml
    conda env create -f envs/scrnaseq_env.yml
    conda env create -f envs/scrna_dbl.exported.yml
    conda env create -f envs/scrnaseq_env_postcore.yml

### 2. Review configuration

- Inspect example configuration files in the `manifests/` directory
- Update paths for:
  - input FASTQ files
  - reference genome resources
  - output locations

Ensure all required variables are defined before execution.

### 3. Run the bulk RNA-seq pipeline

Use the bulk wrapper script from the release bundle:

    bash $RELEASE_ROOT/scripts/bulk/run_bulk_wrapper_v4.sh --config $RELEASE_ROOT/manifests/validation_bulk_crc_subset.env

### 4. Run the scRNA-seq pipeline

Cell Ranger backend:

    bash $RELEASE_ROOT/scripts/scrna/run_scrnaseq_wrapper.sh --config $RELEASE_ROOT/manifests/validation_scrnaseq.env

STARsolo backend:

    bash $RELEASE_ROOT/scripts/scrna/run_scrnaseq_wrapper.sh --config $RELEASE_ROOT/manifests/validation_scrnaseq_starsolo.env

### 5. Review outputs and logs

After execution, results can be found in each run directory:

- `logs/` – wrapper and stage-level execution logs
- `qc/` – quality control outputs
- `outputs/` or `downstream/` – processed data and analysis outputs
- `run_metadata/` – configuration, environment, and execution metadata

Review logs and outputs to confirm successful execution.

## Configuration Model

The pipeline system is driven by structured environment-style configuration files (`.env`) that define inputs, references, resources, execution scope, and output behavior.

Configuration files are used to parameterize runs without modifying pipeline code. This allows the same pipeline implementation to be reused across datasets, environments, and analysis scenarios.

### Shared configuration structure

Both pipelines use a common configuration pattern organized around the following logical groups:

- **RUN**
  - Defines run identity and execution mode
  - Typical fields include:
    - `RUN_ID`
    - `PIPELINE_NAME`
    - `RUN_MODE`
    - `DRY_RUN`

- **INPUT**
  - Defines dataset-specific inputs and manifest references
  - Typical fields include:
    - `FASTQ_ROOT`
    - `MANIFEST_FILE`
    - `SAMPLE_SHEET`
    - `SPECIES`

- **REF**
  - Defines reference genome and annotation resources
  - Typical fields include:
    - `REF_ROOT`
    - `ORGANISM`
    - `GENOME_BUILD`
    - `ANNOTATION_VERSION`
    - `STAR_INDEX`
    - `SALMON_INDEX`
    - `CELLRANGER_REF`

- **RESOURCE**
  - Defines computational resource settings
  - Typical fields include:
    - `THREADS`
    - `MEMORY_GB`

- **OUTPUT**
  - Defines output and working locations
  - Typical fields include:
    - output directories
    - run-specific storage paths
    - result destinations

- **QC**
  - Defines quality-control behavior and related toggles

- **ANALYSIS**
  - Defines downstream core analysis behavior and optional stage execution

- **LOG**
  - Defines logging behavior and log destinations

This shared structure provides consistency across pipelines while allowing pipeline-specific extensions where needed.

### Bulk RNA-seq configuration notes

The bulk RNA-seq pipeline uses configuration to control preprocessing, quantification, summarization, alignment, and downstream core analysis behavior.

Typical bulk-specific settings include:

- Stage toggles for:
  - raw FASTQ QC
  - trimming
  - post-trim QC
  - Salmon quantification
  - tximport summarization
  - STAR alignment

- Reference configuration for:
  - Salmon index
  - STAR genome index
  - transcript-to-gene mapping

- Dataset-level settings for:
  - sample manifests
  - FASTQ locations
  - run identifiers
  - output destinations

This design allows the same bulk wrapper to be reused across validation runs, production runs, and future datasets without changing the underlying scripts.

### scRNA-seq configuration notes

The scRNA-seq pipeline uses configuration to control backend selection, preprocessing, quality control, and downstream core analysis.

Typical scRNA-seq-specific settings include:

- Backend selection:
  - Cell Ranger
  - STARsolo

- Manifest selection for backend-specific runs

- Stage toggles for:
  - preprocessing
  - QC
  - core downstream analysis
  - optional analysis templates

- Reference configuration for:
  - Cell Ranger reference packages
  - STAR genome index
  - organism and annotation version

- Output and comparison settings for:
  - backend-specific runs
  - optional backend comparison workflows

This configuration model allows both supported scRNA-seq backends to be executed within a consistent wrapper framework while preserving backend-specific requirements.

Users should modify configuration files rather than editing pipeline code directly.

## Pipeline Execution Model

The pipeline system executes through wrapper-driven, stage-based workflows that enable controlled execution, restartability, and full traceability.

### Stage-based execution

Each pipeline is composed of a series of ordered stages, where each stage performs a specific function (e.g., QC, trimming, alignment, quantification, downstream analysis).

Execution is managed by a top-level wrapper script that:

- Reads configuration parameters
- Determines which stages to execute
- Invokes each stage in sequence
- Records execution status and outputs

Each stage:

- Has clearly defined inputs and outputs
- Produces a dedicated log file
- Writes status markers indicating success or failure

This design enables modular execution and simplifies debugging by isolating failures to specific stages.

---

### Restart behavior

Pipelines support restartable execution through stage-level status tracking.

For each stage, the system records:

- `.started`
- `.completed`
- `.failed`

markers within the run metadata directory.

This allows the wrapper to:

- Skip completed stages
- Resume execution from the last incomplete stage
- Optionally rerun failed stages only

Restart behavior can be controlled through configuration parameters such as:

- `START_STAGE`
- `END_STAGE`
- `RERUN_FAILED_ONLY`

This enables efficient recovery from failures without reprocessing completed steps.

---

### Logging and run metadata

Each pipeline run generates a complete and structured set of logs and metadata, including:

- Wrapper-level execution logs
- Stage-specific logs
- Execution timestamps and status tracking
- Resolved configuration files
- Tool version snapshots
- Environment exports

All metadata is stored within a standardized `run_metadata/` directory.

This ensures that every run is fully auditable and that execution details can be inspected post hoc.

---

### Reproducibility features

Reproducibility is enforced through a combination of configuration control, environment capture, and deterministic execution practices.

Key features include:

- Configuration snapshotting for each run
- Exported Conda environment specifications
- Tool version recording
- R session capture for analysis steps
- Controlled random seed initialization

These mechanisms ensure that results can be reproduced consistently across environments and over time.

---

### Execution flow summary

At a high level, pipeline execution follows this pattern:

1. Load configuration and resolve all parameters
2. Initialize run directory and metadata structure
3. Execute pipeline stages sequentially
4. Record logs and status markers for each stage
5. Generate outputs and finalize run metadata

This execution model provides a balance of flexibility, transparency, and reliability for both development and production use.

## Outputs

The pipeline system produces structured, standardized outputs for both bulk RNA-seq and scRNA-seq workflows, along with comprehensive run metadata for reproducibility and auditing.

### Bulk RNA-seq outputs

The bulk RNA-seq pipeline generates gene-level quantification and quality control outputs suitable for downstream statistical analysis.

Core outputs include:

- Gene count matrices
- Transcript per million (TPM) matrices
- Transcript-level quantification outputs (Salmon)
- Gene-level summarized counts (tximport)
- Optional genome alignment outputs (STAR)

Quality control outputs include:

- Raw and post-trim FASTQ quality reports
- MultiQC aggregated reports

These outputs are suitable for:

- Differential expression analysis
- Pathway and enrichment analysis
- Integration with downstream statistical workflows

---

### scRNA-seq outputs

The scRNA-seq pipeline produces processed single-cell datasets and core analytical results.

Core outputs include:

- Cell-by-gene count matrices
- Filtered and normalized datasets
- SingleCellExperiment objects
- Dimensionality reduction embeddings:
  - PCA
  - UMAP
  - t-SNE
- Cluster assignments and associated metadata

Outputs are generated for both supported backends:

- Cell Ranger
- STARsolo

These outputs provide a structured foundation for:

- Cell type annotation
- Differential expression analysis
- Pathway and enrichment analysis

Downstream biological interpretation is not included in the core pipeline and is provided separately as optional analysis templates.

---

### Run metadata and audit artifacts

Each pipeline run includes a complete set of metadata to ensure traceability and reproducibility.

The `run_metadata/` directory contains:

- Resolved configuration files used for execution
- Stage-level status markers (`.started`, `.completed`, `.failed`)
- Environment snapshots (Conda exports and tool versions)
- R session information for analysis steps
- Execution timestamps and run status summaries

Additional execution artifacts include:

- Wrapper-level logs
- Stage-specific logs located in `logs/stages/`

---

### Output organization

Outputs are organized within each run directory using a consistent structure:

- `qc/` – quality control results
- `outputs/` or `downstream/` – processed data and analysis outputs
- `logs/` – execution logs
- `run_metadata/` – configuration, environment, and execution metadata

This standardized layout ensures that outputs are:

- Easy to locate and interpret
- Consistent across pipelines and datasets
- Fully traceable to the configuration and environment used for execution

## Core Pipeline Scope vs Example Analysis Templates

This release distinguishes between core pipeline functionality and downstream analytical workflows.

### Core Pipeline Scope

The core pipelines are responsible for:

- Processing raw sequencing data (FASTQ)
- Performing quality control and preprocessing
- Generating standardized, analysis-ready outputs
- Producing structured metadata for reproducibility and auditing

For bulk RNA-seq, this includes:

- Quality control and trimming
- Transcript quantification (Salmon)
- Gene-level summarization (tximport)
- Optional genome alignment (STAR)

For scRNA-seq, this includes:

- Read alignment and count matrix generation (Cell Ranger or STARsolo)
- Cell-level quality control and filtering
- Normalization and feature selection
- Dimensionality reduction (PCA, UMAP, t-SNE)
- Clustering and cluster stability analysis

These steps define the validated, production-supported scope of the pipeline system.

---

### Example Analysis Templates

Additional downstream analyses are provided as example templates, including:

- Differential expression analysis
- Marker identification
- Cell type annotation
- Pathway and enrichment analysis
- Visualization and reporting workflows

These templates are:

- Provided for reference and extension
- Not part of the core validated pipeline
- Not guaranteed to run across all datasets without modification

---

### Design Rationale

This separation ensures that:

- The core pipeline remains stable, reproducible, and generalizable
- Downstream analysis can be adapted to project-specific needs
- The system avoids coupling core processing with interpretation-specific logic

Users are expected to build upon the provided templates or integrate outputs into their own analytical frameworks as needed.

## Validated Release Runs

This release includes fully executed and validated pipeline runs for both bulk RNA-seq and scRNA-seq workflows. These runs serve as reference executions demonstrating correct pipeline behavior, output structure, and reproducibility.

### Bulk RNA-seq

- **Run ID:** `bulk_final_release`
- **Dataset:** CRC validation subset
- **Pipeline stages executed:**
  - Raw FASTQ quality control
  - Adapter trimming and preprocessing
  - Transcript quantification (Salmon)
  - Gene-level summarization (tximport)
  - Optional genome alignment (STAR)
  - Quality control aggregation (MultiQC)

All stages completed successfully, and outputs include:

- Gene count matrices
- TPM matrices
- MultiQC reports
- Alignment outputs (if enabled)
- Full run metadata and logs

---

### scRNA-seq — Cell Ranger

- **Run ID:** `scrna_cellranger_final_release_3`
- **Dataset:** PBMC 1k (GRCh38, Gencode v49)
- **Backend:** Cell Ranger

Pipeline stages executed:

- Read alignment and count matrix generation
- Cell-level quality control and filtering
- Normalization and feature selection
- Dimensionality reduction (PCA)
- Embedding (UMAP, t-SNE)
- Clustering and cluster stability analysis

Outputs include:

- Processed count matrices
- SingleCellExperiment objects
- Dimensionality reduction embeddings
- Cluster assignments and metadata
- Full run metadata and logs

---

### scRNA-seq — STARsolo

- **Run ID:** `scrna_starsolo_final_release`
- **Dataset:** PBMC 1k (GRCh38, Gencode v49)
- **Backend:** STARsolo

Pipeline stages executed are equivalent to the Cell Ranger workflow, producing comparable outputs:

- Processed count matrices
- SingleCellExperiment objects
- Dimensionality reduction embeddings
- Cluster assignments and metadata
- Full run metadata and logs

---

### Validation Summary

- All pipelines executed end-to-end without failure
- Outputs were verified for structural and analytical consistency
- Reproducibility metadata was captured for all runs
- Both scRNA-seq backends produced valid and comparable downstream results

These validated runs are included in the release bundle and can be used as reference implementations for future analyses.

## Known Operational Notes

The following notes capture important operational behaviors and considerations observed during pipeline execution and validation.

### Working directory assumptions

- Some pipeline scripts assume execution from specific directories
- Users should ensure they are running commands from the intended working directory (e.g., run directory or pipeline root)
- Incorrect working directories may result in missing file errors or incorrect path resolution

---

### Configuration path resolution

- All input, reference, and output paths must be explicitly defined in configuration files
- Relative paths may lead to unexpected behavior if the working directory changes
- Absolute paths are recommended for production use

---

### Environment isolation

- Different pipeline stages rely on separate Conda environments
- All environments must be created prior to execution
- Missing or improperly configured environments may result in runtime errors (e.g., missing R packages or binaries)

---

### Restart behavior

- Restart logic depends on stage-level status markers stored in `run_metadata/stage_status/`
- Reusing a `RUN_ID` without cleaning previous markers may cause stages to be skipped unintentionally
- For clean re-execution, either:
  - use a new `RUN_ID`, or
  - remove existing stage status markers

---

### Resource considerations

- Bulk RNA-seq workflows are generally moderate in resource usage but scale with dataset size
- scRNA-seq workflows can be memory-intensive, particularly during downstream analysis steps (e.g., PCA, clustering)
- Ensure sufficient CPU, memory, and disk space before execution

---

### Reference compatibility

- Reference genome resources must be compatible with the tool versions used
- In particular:
  - STAR indices must match the STAR version used at runtime
  - Cell Ranger references must be correctly formatted and version-compatible

---

### Output size and storage

- Pipeline runs generate intermediate and final outputs that may be large
- Disk usage should be monitored, especially for scRNA-seq workflows
- Users should ensure adequate storage capacity before execution

---

### Downstream analysis templates

- Example downstream analysis scripts are provided for reference only
- These scripts may require adjustment depending on dataset structure and analysis goals
- They are not part of the validated core pipeline execution

---

### Logging and debugging

- Detailed logs are available in:
  - `logs/` (wrapper-level)
  - `logs/stages/` (stage-level)
- These logs should be the first point of inspection when troubleshooting failures

---

These notes reflect observed behaviors during validation and are intended to help users avoid common issues during deployment and execution.

## Extension and Customization Notes

The pipeline system is designed to support extension and customization while maintaining stability and reproducibility of the core workflows.

### Adding new datasets

New datasets can be processed by:

- Creating or updating a configuration file (`.env`)
- Defining:
  - input FASTQ locations
  - sample manifests
  - reference genome settings
  - output destinations

No changes to pipeline scripts are required for standard use cases.

---

### Modifying pipeline behavior

Pipeline behavior should be modified through configuration whenever possible, including:

- Enabling or disabling stages
- Adjusting resource usage (threads, memory)
- Changing reference datasets
- Updating input and output paths

Direct modification of pipeline scripts is not recommended unless extending core functionality.

---

### Extending pipeline stages

Advanced users may extend the pipeline by:

- Adding new stage scripts
- Integrating additional tools or analysis steps
- Updating wrapper logic to include new stages

When extending pipelines:

- Ensure new stages follow the existing structure:
  - clear inputs and outputs
  - dedicated logging
  - stage-level status markers
- Maintain compatibility with existing configuration patterns

---

### Working with downstream analysis templates

Example analysis templates are provided for:

- Differential expression analysis
- Marker identification
- Pathway and enrichment analysis
- Visualization and reporting

Users are expected to:

- Adapt these templates to their specific datasets
- Extend or replace them based on project requirements
- Integrate outputs into their own analytical workflows

---

### Adding new reference datasets

New reference genomes or annotations can be incorporated by:

- Placing reference data within the configured reference directory structure
- Updating configuration variables to point to:
  - genome indices
  - annotation files
  - transcript-to-gene mappings

Ensure compatibility with the tools and versions used in the pipeline environments.

---

### Maintaining reproducibility

When customizing or extending the pipeline:

- Preserve configuration-driven execution
- Avoid hardcoding paths or parameters in scripts
- Capture environment changes using Conda exports
- Maintain logging and metadata consistency

Reproducibility should be treated as a primary requirement for any extension.

---

### Recommended approach

For most users:

- Use existing pipeline functionality with configuration changes only
- Treat core pipelines as stable and validated
- Use templates and extensions for project-specific analysis

This approach ensures that core functionality remains reliable while allowing flexibility for evolving analytical needs.

## Support Materials in This Release

The release bundle includes supporting materials intended to aid in understanding, validation, and extension of the pipeline system.

These materials are organized within the following directories:

- **docs/**
  - Contains documentation for pipeline usage, configuration, and outputs

- **reports/**
  - Includes consolidated validation reports and summary materials demonstrating successful pipeline execution

- **examples/**
  - Provides example outputs and reference artifacts for downstream interpretation and workflow development

- **envs/**
  - Contains exported Conda environment specifications required to reproduce the execution environment

- **manifests/**
  - Includes example configuration files and input manifests used for validated runs

---

These materials are provided to:

- Support reproducible setup and execution
- Serve as reference implementations for new datasets
- Enable users to extend and adapt the pipeline system for their own workflows

## Version

**v1.0**

This release represents the first production-ready version of the Summit Informatics bioinformatics pipeline system.

It includes:

- Fully validated bulk RNA-seq and scRNA-seq pipelines
- Standardized configuration and execution model
- Reproducible environment specifications
- Documented workflows and reference runs

This version is intended for stable use, extension, and deployment in research and translational settings.
