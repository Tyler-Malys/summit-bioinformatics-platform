# Summit Bioinformatics Platform

Umbrella repository for bioinformatics pipeline development, architecture, and shared tooling.

## Structure

- docs/
  - architecture/ — platform design and decisions
  - configuration/ — configuration schema and audits
  - legacy/ — preserved historical artifacts

- pipelines/
  - bulk_rnaseq/ — bulk RNA-seq pipeline (Salmon / STAR / tximport / DESeq2 / GSEA)
  - scrnaseq/ — single-cell RNA-seq pipeline (CellRanger / STARsolo / downstream analysis)

## Repository Policy

This repository tracks:

- source code
- scripts
- configuration files
- documentation
- analysis logic

This repository does NOT track:

- raw data
- intermediate pipeline outputs
- results
- logs
- reference genomes
- serialized objects (.rds, .rda)
- generated figures/reports

## Purpose

To support:

- reproducible bioinformatics pipelines
- enterprise-grade pipeline architecture
- cross-pipeline standardization
- scalable consulting delivery through Summit Informatics

