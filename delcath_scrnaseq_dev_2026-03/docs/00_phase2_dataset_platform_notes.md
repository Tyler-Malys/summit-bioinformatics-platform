# Delcath scRNA-seq Pipeline Development

Purpose: Public dataset validation and platform configuration  
Date initiated: 2026-03-02  
Environment: DEL-PYTHONV  

---

## Scope of Phase 2 (Initial)
- Identify and select public scRNA-seq dataset
- Confirm platform / chemistry
- Inspect read structure
- Select genome & annotation
- Prepare platform-specific reference build plan

This directory is development-only and not production data.

---

## Candidate Dataset Evaluation

### Candidate 1: 10x PBMC 3k
Platform: 10x Chromium 3' Gene Expression  
Species: Human  
Approximate size: ~3,000 cells  
Data type: UMI-based, paired-end FASTQ  

Rationale:
- Industry benchmark dataset
- Small enough for rapid validation
- Standard UMI-based workflow
- Ideal for testing barcode parsing and reference build
- Commonly used for pipeline benchmarking

Decision: SELECTED for development harness.


---

## Pipeline Engine Strategy

Primary engine: STARsolo (STAR v2.7.10a installed on DEL-PYTHONV)  
Optional engine: 10x Cell Ranger (to be added if/when installed)

Rationale:
- STARsolo provides an open, configurable baseline for FASTQ→matrix processing.
- Cell Ranger can be enabled later for standardization/validation against 10x outputs.
- Shared inputs: standardized FASTQ layout + sample manifest + pinned reference choice.

