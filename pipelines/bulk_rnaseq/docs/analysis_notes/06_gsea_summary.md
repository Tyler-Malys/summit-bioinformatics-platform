# 06 – Gene Set Enrichment Analysis (GSEA) Summary

## Overview

Gene set enrichment analysis (GSEA) was performed across four contrasts:
- CRC pooled vs HEP
- SW48 vs HEP
- SW480 vs HEP
- SW1116 vs HEP

Pathways were filtered at padj <= 0.05 and evaluated for:
- Directional consistency
- Shared enrichment across all four contrasts
- Magnitude stability (NES range)

Representative heatmaps and ranked summary tables were generated to summarize dominant biological programs.

---

## Dominant Hallmark Programs

- Strong and consistent enrichment of proliferation programs across all CRC models, including **E2F Targets** and **G2M Checkpoint** (NES ~3.0–3.2 across contrasts).

- Mitotic and cell-cycle machinery is uniformly activated in CRC relative to HEP, including **Mitotic Spindle**.

- Broad suppression of metabolic and detoxification pathways in CRC, including:
  - Xenobiotic Metabolism
  - Bile Acid Metabolism
  - Fatty Acid Metabolism
  - Adipogenesis
  - Peroxisome

- Complement and coagulation pathways are consistently downregulated in CRC relative to HEP.

Hallmark heatmap (shared-only) shows a clean separation between proliferation (positive NES) and metabolic/immune suppression (negative NES), with strong concordance across pooled and individual CRC lines.

---

## Reactome Mechanistic Themes (Top 40 by NES_range)

- DNA replication and genome maintenance pathways are strongly enriched across CRC models, including:
  - DNA Replication
  - DNA Replication Pre-Initiation
  - Chromosome Maintenance
  - TP53-regulated transcription of cell cycle genes
  - Centromere and CENPA-associated processes

- Chromatin organization and post-translational regulatory processes are consistently activated, including:
  - SUMOylation of chromatin and RNA-binding proteins
  - Nuclear envelope reformation
  - Chromosome structural pathways

- Immune-associated and TLR-regulatory pathways trend down in CRC in shared Reactome sets.

- Variability across CRC models is primarily magnitude-based (NES differences), not directional reversal, indicating a stable biological program across lines.

Reactome Top-40 heatmap preserves the two-block structure observed in Hallmark:
- Proliferation/genome maintenance cluster (positive NES)
- Metabolic/immune suppression cluster (negative NES)

---

## Model Consistency

- All four CRC contrasts cluster tightly in both Hallmark and Reactome heatmaps.
- No pathway direction reversals were observed in shared significant sets.
- Differences between pooled and individual CRC lines are limited to effect size (NES magnitude), not biological direction.

Overall, GSEA indicates a coherent CRC transcriptional program characterized by strong proliferation activation and coordinated metabolic/immune suppression relative to HEP.
