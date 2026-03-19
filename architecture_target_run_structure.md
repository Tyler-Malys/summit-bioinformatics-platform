# Delcath Canonical Run Directory Structure — v1

## Purpose
Define the canonical directory structure created for each pipeline run so that execution is consistent, auditable, and maintainable across bulk RNA-seq and scRNA-seq pipelines.

---

## Canonical Run Root

Future canonical run roots:

/home/summitadmin/bioinformatics_runs/
  bulk_rnaseq/
    <run_id>/
  scrnaseq/
    <run_id>/

During transition, repos may still create run-related outputs locally.
The target structure below should govern future wrapper behavior.

---

## Canonical Run Directory Structure

<run_id>/
  input/
  working/
  logs/
  qc/
  outputs/
  downstream/
  final/
  run_metadata/

---

## Directory Definitions

### input/
Purpose:
- run-specific input manifests
- copied or linked metadata
- resolved sample sheets
- dataset-specific input references used by the run

Examples:
- sample_manifest.tsv
- metadata.tsv
- fastq_manifest.tsv

### working/
Purpose:
- temporary and intermediate execution products
- localized fastqs
- staging files
- intermediate matrices
- scratch artifacts

Examples:
- localized_fastqs/
- temp/
- intermediate/

### logs/
Purpose:
- run-level and stage-level logs
- stdout/stderr captures
- tool version captures where appropriate

Examples:
- wrapper.log
- qc_fastq.log
- trim_fastp.log
- salmon_quant.log
- star_align.log

### qc/
Purpose:
- QC reports and QC summary artifacts

Examples:
- fastqc/
- multiqc/
- raw_qc_metrics.tsv
- barcode_rank_plots/
- qc_summary.tsv

### outputs/
Purpose:
- core pipeline-produced outputs
- matrices, quantification outputs, alignments, standardized result objects

Examples:
- counts/
- quants/
- alignments/
- matrices/
- sce_objects/

### downstream/
Purpose:
- higher-level downstream analysis artifacts
- differential expression
- marker detection
- pathway enrichment
- clustering summaries
- visualization tables

Examples:
- differential_expression/
- markers/
- fgsea/
- clustering/
- annotations/
- figures/

### final/
Purpose:
- curated final deliverables intended for handoff, review, or reporting

Examples:
- final reports
- summary tables
- curated figures
- client-facing deliverables

### run_metadata/
Purpose:
- execution metadata required for reproducibility and auditability

Examples:
- run_manifest.txt
- resolved_config.env
- pipeline_version.txt
- software_versions.txt
- start_end_status.txt

---

## Required Wrapper Behavior

Each wrapper should:

1. determine pipeline type and RUN_ID
2. create the full canonical run directory tree
3. write key metadata files into run_metadata/
4. direct stage outputs into the correct canonical subdirectories
5. fail early if required input/config/reference paths are missing

---

## Minimum Required Metadata Files

### run_manifest.txt
Should capture:
- run_id
- pipeline name
- timestamp
- operator
- input source
- reference set
- key execution parameters

### resolved_config.env
Should capture:
- exact resolved runtime config used for the run

### pipeline_version.txt
Should capture:
- git branch
- git commit hash
- dirty/clean working state if practical

### software_versions.txt
Should capture:
- key tool versions used in execution
- examples: salmon, STAR, fastp, R, python

### start_end_status.txt
Should capture:
- start time
- end time
- success/failure
- failed stage if applicable

---

## Transitional Guidance

During current hardening:
- repo-local execution may still occur
- wrappers should begin creating this structure even if rooted temporarily inside the repo
- later hardening phases can move the run root fully outside the repos without changing internal run layout

---

## Cross-Pipeline Rule

Bulk RNA-seq and scRNA-seq may differ in stage contents, but every run should still follow the same top-level run structure:
- input/
- working/
- logs/
- qc/
- outputs/
- downstream/
- final/
- run_metadata/

This consistency is required for maintainability and future productionization.
