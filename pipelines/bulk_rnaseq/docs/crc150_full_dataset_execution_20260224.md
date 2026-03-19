# CRC150 Full Dataset — Execution Completion & Matrix Validation
Date: 2026-02-24
Run ID: crc150_salmon_20260223

## Overview
Full CRC dataset (75 samples; 150 FASTQs) successfully processed through Salmon quantification and gene-level aggregation via tximport. Dataset is confirmed analysis-ready.

---

## QC + Preprocessing

- Raw FastQC/MultiQC reviewed.
- Trimming evaluated; no material improvement observed. Proceeded with raw reads.
- Salmon quantification completed for all 75 samples.
- All quant.sf files verified present and non-empty.

Output directory:
results/salmon/salmon_crc150_salmon_20260223

---

## Annotation Harmonization

- Encountered transcript version mismatch between Salmon quant.sf IDs and GENCODE tx2gene mapping.
- Root cause: versioned transcript IDs in tx2gene (e.g., ENST00000000233.10) vs versionless IDs in Salmon output.
- Resolution: normalized transcript IDs by stripping version suffix prior to tximport.
- Re-ran tximport successfully.

---

## Gene-Level Matrix Outputs

Output directory:
results/tximport/txi_crc150_salmon_20260223

Files generated:
- gene_counts.csv
- gene_tpm.csv
- run_info.txt

Matrix dimensions:
- 62,266 genes × 75 samples
- 45,067 genes with nonzero counts
- No missing values detected

---

## Sanity Validation Checks

Library Sizes:
- Min: 14.7M
- Median: 18.8M
- Max: 23.7M
- No under-sequenced outliers observed.

PCA (filtered genes, log2 counts):
- PC1: 24.5%
- PC2: 19.7%
- PC3: 16.0%
- Structure consistent with biological grouping (cell line effect).

Sample Correlation:
- Off-diagonal range: 0.67 – 0.99
- No low-correlation technical outliers detected.

---

## Infrastructure & Storage Workflow

Due to WSL2 filesystem performance characteristics and drive layout:

- Raw FASTQ files are stored long-term on high-capacity D: drive.
- For active processing (Salmon quantification), FASTQs are copied to C: drive (ext4-backed Linux filesystem) to ensure stable I/O performance and avoid cross-filesystem slowdowns.
- After successful completion and validation of quantification and tximport outputs, localized FASTQs on C: may be removed to reclaim processing space.
- D: drive remains the archival source of truth for raw data.

This workflow will be maintained for future batch processing to ensure performance and scalability.

---

## Status

Full dataset execution complete.
Gene-level count matrix validated.
Pipeline hardened (annotation compatibility fix implemented).

Transitioning to experimental-design-driven one-off analysis phase.
