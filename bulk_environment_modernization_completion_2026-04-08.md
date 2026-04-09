Environment Modernization & Version Control — Bulk RNA-seq Pipeline
Completion Note (2026-04-08)

Summary
This task block completed modernization, stabilization, and validation of the bulk RNA-seq pipeline environment and downstream analysis layer. The pipeline is now reproducible, environment-isolated, and validated end-to-end under a pinned conda + R environment.

Environment Modernization
- Created and validated conda environment: bulk_rnaseq_env
- Channels standardized: conda-forge, bioconda, defaults
- All pipeline tools executed from environment (no system leakage)
- Key tools validated:
  - fastp
  - salmon
  - STAR
  - tximport
- R version pinned: 4.3.3

R / Bioconductor Stack Validation
- DESeq2 (1.42.0)
- apeglm (1.24.0)
- fgsea (1.28.0)
- AnnotationDbi
- org.Hs.eg.db
- SummarizedExperiment
- All packages confirmed functional within conda environment

Environment Reproducibility Artifacts
- envs/bulk_rnaseq_env.yml (rebuild spec)
- envs/bulk_rnaseq_env_explicit.txt (exact package lock)
- envs/bulk_rnaseq_env_R_sessionInfo.txt (R session snapshot)

Upstream Pipeline Validation
- End-to-end execution confirmed:
  - raw QC (FastQC/MultiQC)
  - trimming (fastp)
  - quantification (Salmon)
  - gene-level aggregation (tximport)
  - optional STAR alignment validation
- Multi-sample CRC dataset successfully processed

Downstream Analysis Validation
Executed and validated:
- 01_build_analysis_object.R
- 02_pca_qc.R
- 03_differential_expression.R
- 04_gsea_fgsea.R
- 05_gsea_summary_tables.R

Key confirmations:
- DESeq2 modeling successful across 4 contrasts
- LFC shrinkage (apeglm) functional
- PCA generation and export working
- GSEA functional for:
  - Reactome
  - Hallmark
- Ensembl → gene symbol mapping validated
- fgsea multilevel execution confirmed
- Cross-contrast summary generation validated

Hardening & Fixes Implemented
- Fixed column naming mismatch in GSEA summary (dcast output alignment)
- Made column ordering robust to missing columns
- Added guards for:
  - NES_range absence
  - delta column presence
- Added fallback behavior for ranking outputs
- Removed assumptions requiring full contrast completeness

Known Behaviors / Notes
- Downstream scripts are intentionally template-driven, not fully generic automation
- Assumptions include:
  - sample naming conventions
  - cell_line-based design (~cell_line)
  - CRC vs Hep contrast structure
- Minor Fontconfig warnings observed during plotting (non-blocking)

Conclusion
The bulk RNA-seq pipeline is now:
- Environment-isolated
- Reproducible
- End-to-end validated
- Robust to variable downstream data conditions

This completes the Environment Modernization & Version Control task block for bulk RNA-seq.
