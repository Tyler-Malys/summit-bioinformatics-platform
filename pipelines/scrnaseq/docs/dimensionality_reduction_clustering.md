# Dimensionality Reduction and Clustering

This document summarizes the dimensionality reduction, graph construction, clustering, visualization, and cluster stability evaluation workflow implemented for the Delcath scRNA-seq pilot pipeline.

The downstream workflow was implemented using a modular Bioconductor / SingleCellExperiment architecture rather than Seurat. This approach was selected to support reproducibility, intermediate object persistence, transparent script-level execution, and future enterprise hardening.

---

# Workflow Summary

The downstream analysis stack now proceeds as follows:

Counts → QC → emptyDrops filtering → low-quality filtering → doublet detection → singlet retention → normalization → HVG selection → PCA → covariate regression → KNN graph construction → graph clustering → UMAP → t-SNE → cluster stability evaluation

All downstream scripts are located in:

scripts/downstream/

Current downstream scripts:

10_normalize_hvg.R  
20_run_pca.R  
21_assess_pc_covariates.R  
22_regress_covariates_and_rerun_pca.R  
23_merge_pca_variants.R  
24_assess_any_reduceddim_covariates.R  
30_build_knn_graphs.R  
31_cluster_knn_graphs.R  
32_run_umap.R  
33_run_tsne.R  
34_cluster_stability.R  

---

# PCA and Regression

PCA was performed on the normalized highly variable gene set.

Two PCA representations are retained for each backend:

PCA — standard PCA on the normalized data  
PCA_regressed — PCA after covariate regression  

These are stored in the SCE object as:

reducedDim(sce, "PCA")  
reducedDim(sce, "PCA_regressed")

This design allows downstream comparison of clustering and visualization with and without regression.

---

# KNN Graph Construction

K-nearest neighbor graphs were constructed from the PCA embeddings using:

scran::buildKNNGraph

Parameters used:

k = 20  
n_pcs = 20  

Graph objects are stored in:

metadata(sce)$graphs

with graph metadata recorded in:

metadata(sce)$graph_build

Each backend retains two graph variants:

knn_pca  
knn_pca_regressed  

---

# Graph Clustering

Graph clustering was performed using Louvain community detection via igraph.

Cluster labels are stored in:

colData(sce)$cluster_pca  
colData(sce)$cluster_pca_regressed  

Observed cluster counts:

Cell Ranger backend  
PCA clusters: 11  
PCA_regressed clusters: 12  

STARsolo backend  
PCA clusters: 9  
PCA_regressed clusters: 9  

Cluster size distributions were inspected and found to be biologically plausible for the PBMC 1k validation dataset.

---

# UMAP and t-SNE Embeddings

Two nonlinear embedding methods were generated for visualization.

UMAP was implemented using:

uwot::umap

Stored as:

reducedDim(sce, "UMAP")  
reducedDim(sce, "UMAP_regressed")

t-SNE was implemented using:

Rtsne::Rtsne

Stored as:

reducedDim(sce, "TSNE")  
reducedDim(sce, "TSNE_regressed")

Final reduced dimension content stored in each SCE object:

PCA  
PCA_regressed  
UMAP  
UMAP_regressed  
TSNE  
TSNE_regressed  

Embedding dimensions and plotting behavior were verified for both Cell Ranger and STARsolo outputs.

---

# Cluster Stability Evaluation

Cluster stability was evaluated using Adjusted Rand Index (ARI) via:

mclust::adjustedRandIndex

Two classes of comparisons were performed.

Within-backend comparisons:

cluster_pca vs cluster_pca_regressed

This measures the effect of regression on clustering.

Cross-backend comparisons:

Direct comparison of Cell Ranger and STARsolo clustering.

Because Cell Ranger barcodes include a "-1" suffix while STARsolo barcodes do not, barcodes were harmonized before comparison.

Shared cells available for comparison:

1062 cells

---

# ARI Results

Comparison | ARI | Cells Used  
Cell Ranger PCA vs PCA_regressed | 0.7274 | 1139  
STARsolo PCA vs PCA_regressed | 0.7156 | 1089  
Cell Ranger PCA vs STARsolo PCA | 0.6769 | 1062  
Cell Ranger PCA_regressed vs STARsolo PCA_regressed | 0.7169 | 1062  
Cell Ranger PCA vs STARsolo PCA_regressed | 0.6379 | 1062  
Cell Ranger PCA_regressed vs STARsolo PCA | 0.6393 | 1062  

---

# Interpretation

These results support several conclusions:

Regression changes cluster boundaries moderately but does not disrupt the overall biological structure.

Clustering concordance between Cell Ranger and STARsolo is good for a pilot implementation.

The highest cross-backend agreement was observed when comparing regressed embeddings.

The downstream workflow appears stable across preprocessing backends.

---

# Output Artifacts

Final downstream objects:

analysis/objects/pbmc1k_cellranger_umap_tsne_sce.rds  
analysis/objects/pbmc1k_starsolo_umap_tsne_sce.rds  

Cluster stability metrics:

analysis/metrics/pbmc1k_cluster_stability.tsv

These artifacts represent the completed dimensionality reduction and clustering stage of the pilot pipeline.

---

# Next Stage

Next downstream phase:

Cluster marker detection  
Marker ranking  
Preliminary cell type annotation  
Biological interpretation of cluster structure
