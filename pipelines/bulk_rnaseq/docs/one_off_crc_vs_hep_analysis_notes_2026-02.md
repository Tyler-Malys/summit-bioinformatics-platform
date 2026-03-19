# One-Off Analysis Notes  
## CRC Cell Lines vs Hepatocytes (Preliminary Section)  
Date: 2026-02-25  
Project: Delcath CRC Bulk RNA-seq  
Analyst: Tyler Malys, Ph.D.

---

## 1. Input Data & Quantification Method

Gene-level counts were generated using:

FASTQ → Salmon (transcript-level quantification) → tximport (gene-level aggregation)

### Fractional Gene Counts

The gene count matrix contains fractional values (e.g., 1281.001).  
This occurs because:

- Salmon performs probabilistic assignment of reads to transcripts.
- Reads mapping to multiple transcripts are distributed proportionally.
- tximport aggregates transcript-level estimated counts to genes.
- Resulting gene counts represent expected fragment counts.

This is accepted and standard practice in modern RNA-seq workflows and is consistent with current best practices recommended by Salmon, tximport, and DESeq2 developers.

Relevant points:

- Fractional counts reflect probabilistic assignment, not normalization.
- This workflow is supported by the authors of Salmon, tximport, and DESeq2.
- Many contemporary RNA-seq pipelines use this approach instead of alignment-based integer counting.

### Conversion for DESeq2

Because DESeqDataSetFromMatrix() requires integer counts:

- Gene counts were rounded to nearest integer.
- Conversion performed after low-expression filtering.
- Rounding error is negligible relative to count magnitude.
- This is standard practice when working from exported tximport matrices.

---

## 2. Sample Inclusion Criteria

Approved comparison (per Feb 9 guidance):

Included:
- SW48
- SW480
- SW1116
- Hepatocytes

Excluded:
- THLE-2

Post-filter sample count:

- 15 replicates per cell line
- 60 total samples included in analysis

---

## 3. Gene Filtering Strategy

Filtering rule:
- Retain genes with ≥10 counts in at least 2 samples.

Results:
- Genes before filtering: 62,266
- Genes after filtering: 23,753
- Genes removed: 38,513

This removes low-expression noise and improves dispersion modeling stability.

---

## 4. Statistical Design

Design formula:
~ cell_line

Reference level:
Hepatocytes

Dose levels were collapsed for this preliminary section to align with scoped analysis goals and avoid scope expansion.

Dose-specific modeling may be considered in subsequent phases.

---

## 5. Model Diagnostics

DESeq2 successfully performed:

- Size factor estimation
- Dispersion estimation
- Model fitting
- Outlier replacement (82 genes; expected behavior)
- Variance Stabilizing Transformation (VST)

Sanity checks performed:

- Verified sample counts per group
- Verified size factor range (~0.9–1.1)
- Confirmed dispersion estimates present
- Confirmed VST matrix scale appropriate (~4–11 range)
- Mean–SD trend consistent with expected variance stabilization under VST.

No structural anomalies detected.

### Output Files

- DESeq2 object: analysis_objects/dds_crc_vs_hep_20260225.rds
- VST object: analysis_objects/vsd_crc_vs_hep_20260225.rds
- Mean–SD VST plot: results/qc/mean_sd_vst_plot.png
- Build execution log: docs/run_records/2026-02-25_build_analysis_object.log
- VST diagnostics log: docs/run_records/2026-02-25_vst_diagnostics.log

---

## 6. PCA / Exploratory QC

PCA was performed on VST-transformed counts.

Variance explained:
- PC1: 72%
- PC2: 15%
- Combined (PC1 + PC2): 87%

Findings:

- PC1 clearly separates hepatocytes from all CRC cell lines.
- No overlap observed between Hep and CRC clusters.
- CRC cell lines (SW48, SW480, SW1116) form distinct, tight clusters.
- Replicates within each group cluster tightly.
- No apparent outliers detected.
- No visible sub-clustering suggestive of dominant dose-driven structure.

Interpretation:

Cell line identity is the primary driver of transcriptional variation in this dataset. The dataset demonstrates strong biological separation and high internal consistency. No QC concerns identified.

### Output Files

- PCA plot: results/qc/pca_crc_vs_hep.png
- PCA scores: results/qc/pca_scores_crc_vs_hep.csv
- PCA execution log: docs/run_records/2026-02-25_pca_qc.log

---

## 7. Differential Expression

Differential expression was performed using DESeq2 with dose levels pooled within each cell line (per scoped preliminary design).

Contrasts evaluated:
- SW48 vs Hep
- SW480 vs Hep
- SW1116 vs Hep
- Pooled CRC (SW48 + SW480 + SW1116) vs Hep

Total genes tested: 23,753
All differential expression tests were conducted on the filtered gene set defined in Section 3.

Significant genes (FDR < 0.05):

- SW48 vs Hep: 18,820
- SW480 vs Hep: 18,040
- SW1116 vs Hep: 17,973
- Pooled CRC vs Hep: 16,862

Significant genes (FDR < 0.05 & |log2FC| ≥ 1):

- SW48 vs Hep: 13,191
- SW480 vs Hep: 12,115
- SW1116 vs Hep: 12,235
- Pooled CRC vs Hep: 11,633

Interpretation:

Substantial transcriptional divergence is observed between hepatocytes and colorectal cancer cell lines. The pooled CRC contrast retains a strong shared CRC-specific transcriptional signature while smoothing line-specific variation.

LFC shrinkage (apeglm) was not applied because the apeglm package was not available in the current environment; unshrunk DESeq2 results were exported.

Sanity checks were performed on DESeq2 outputs:

- Verified expected column structure (baseMean, log2FoldChange, lfcSE, stat, pvalue, padj).
- Confirmed symmetric log2 fold-change distribution centered near zero.
- Observed wide dynamic range (|log2FC| > 20), consistent with strong biological separation.
- Majority of genes significantly different at padj < 0.05, expected for CRC vs primary hepatocyte comparison.
- No structural anomalies detected in exported result tables.

### Output Files

- DE summary table: results/de/DESeq2_contrast_summary.csv
- SW48 vs Hep: results/de/DESeq2_SW48_vs_Hep_unshrunk.csv
- SW480 vs Hep: results/de/DESeq2_SW480_vs_Hep_unshrunk.csv
- SW1116 vs Hep: results/de/DESeq2_SW1116_vs_Hep_unshrunk.csv
- Pooled CRC vs Hep: results/de/DESeq2_PooledCRC_vs_Hep_unshrunk.csv
- DE execution log: docs/run_records/2026-02-25_differential_expression.log

---

---

## 8. Gene Set Enrichment Analysis (GSEA)

Gene set enrichment analysis was performed using ranked gene statistics derived from each DE contrast.

Gene sets evaluated:
- MSigDB Hallmark
- Reactome

Enrichment was computed using fgsea.
Significant pathways were defined as padj < 0.05.

Shared pathway subsets were defined as:
- Significant in all four contrasts
- Consistent direction of enrichment across contrasts

---

### 8.1 Hallmark Summary

Shared Hallmark pathways (all four contrasts; same direction):
- 24 total pathways

Dominant enriched programs:

- Strong and consistent activation of proliferation pathways across all CRC models:
  - E2F Targets (NES ~3.2)
  - G2M Checkpoint (NES ~3.1)
  - Mitotic Spindle

- Broad suppression of metabolic and detoxification programs in CRC relative to Hep:
  - Xenobiotic Metabolism
  - Bile Acid Metabolism
  - Fatty Acid Metabolism
  - Adipogenesis
  - Peroxisome

- Complement and Coagulation pathways are consistently downregulated in CRC.

Hallmark heatmap (shared-only) demonstrates:
- Clear separation of proliferation (positive NES) and metabolic/immune suppression (negative NES).
- Tight clustering of pooled CRC and individual cell lines.
- No directional reversals across contrasts.

---

### 8.2 Reactome Summary

Shared Reactome pathways (all four contrasts; same direction):
- 150 total pathways

For visualization clarity, the top 40 pathways ranked by NES_range were plotted.

Dominant enriched programs:

- DNA replication and genome maintenance:
  - DNA Replication
  - DNA Replication Pre-Initiation
  - Chromosome Maintenance
  - TP53-regulated transcription of cell cycle genes
  - Centromere/CENPA-associated processes

- Chromatin organization and post-translational regulatory pathways:
  - SUMOylation of chromatin and RNA-binding proteins
  - Nuclear envelope reformation
  - Chromosome structural programs

- Immune-associated and TLR-regulatory pathways trend down in CRC relative to Hep.

Observed variability across CRC lines is magnitude-based (NES differences), not directional reversal.

Reactome Top-40 heatmap preserves the two-block structure:
- Proliferation/genome maintenance cluster (positive NES)
- Metabolic/immune suppression cluster (negative NES)

---

### 8.3 Model Consistency

- All four CRC contrasts cluster tightly in both Hallmark and Reactome heatmaps.
- No shared pathway direction reversals detected.
- Differences between pooled and individual CRC contrasts reflect effect size variation, not biological contradiction.

Overall, GSEA demonstrates a coherent CRC transcriptional program characterized by strong activation of proliferation and genome maintenance pathways, with coordinated suppression of metabolic and immune-associated processes relative to hepatocytes.

---

### 8.4 GSEA Output Files

Summary tables:
- results/gsea/summary/gsea_all_significant_pathways.csv
- results/gsea/summary/gsea_shared_hallmark_all4_same_direction.csv
- results/gsea/summary/gsea_shared_reactome_all4_same_direction.csv
- results/gsea/summary/gsea_top10_hallmark_by_pooled_absNES.csv
- results/gsea/summary/gsea_top20_reactome_by_NES_range.csv

Heatmaps:
- results/gsea/figures/hallmark_shared_heatmap.pdf
- results/gsea/figures/reactome_shared_top40_heatmap.pdf

Execution logs:
- docs/run_records/2026-02-26_gsea_summary.log
- docs/run_records/2026-02-26_gsea_heatmaps.log

---

## 9. Next Steps

- Optional dose-specific modeling if requested
- Pathway-level refinement or figure polishing if needed
- Integration with additional data modalities (future phase)
- Preparation of client-facing executive summary document
