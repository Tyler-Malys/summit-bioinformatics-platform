# Downstream Visualization Export

A standardized downstream visualization export layer was added to the scRNA-seq pilot pipeline for both Cell Ranger and STARsolo preprocessing backends.

## Outputs generated
For each backend, the visualization script exports:
- UMAP colored by cluster
- UMAP colored by cell type
- UMAP colored by lineage
- t-SNE colored by cluster
- t-SNE colored by cell type
- cluster size bar plot
- cell type composition bar plot
- canonical marker dot plot

A backend comparison plot is also generated:
- cell type composition by preprocessing backend

## Output locations
- `analysis/figures/downstream/cellranger/`
- `analysis/figures/downstream/starsolo/`
- `analysis/figures/downstream/comparison/`

## Report output
A compiled PDF report of QC and downstream figures is written to:
- `analysis/figures/scRNAseq_pilot_visualization_report.pdf`

## QC thresholds used
Shared QC thresholds were applied across both preprocessing backends for PBMC1k validation:
- minimum total counts: 500
- minimum detected genes: 200
- maximum mitochondrial percentage: 20
- doublet detection: `scDblFinder`

These shared thresholds supported direct backend comparison under a common QC framework.
