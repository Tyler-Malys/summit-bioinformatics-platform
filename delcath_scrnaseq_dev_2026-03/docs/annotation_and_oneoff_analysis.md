# Annotation and One-Off Analysis

This section performs biological interpretation and exploratory downstream analysis on the scRNA-seq clustering results generated in the previous pipeline stage. The goals of this stage are to identify cluster marker genes, assign biological cell type labels, demonstrate differential expression analysis, and perform pathway enrichment on differential results.

These steps demonstrate downstream analytical capability and produce interpretable biological outputs for the pilot pipeline. Some components, particularly cell type annotation, are intentionally manual and are expected to involve domain expertise during real analyses.

All analyses in this section were executed independently for both preprocessing backends:

Cell Ranger pipeline  
STARsolo pipeline

Running the same downstream analyses on both pipelines allows verification that biological conclusions are stable across preprocessing methods.

---

# Marker Gene Identification

Scripts used in this step:

scripts/downstream/40_find_markers_cellranger.R  
scripts/downstream/40_find_markers_starsolo.R

Marker genes were identified using the scran::findMarkers function, which performs cluster-versus-rest differential testing across all clusters in the dataset using normalized expression values stored in the SingleCellExperiment object.

Input objects:

analysis/objects/pbmc1k_cellranger_umap_tsne_sce.rds  
analysis/objects/pbmc1k_starsolo_umap_tsne_sce.rds

Output tables:

analysis/markers/pbmc1k_cellranger_markers.tsv  
analysis/markers/pbmc1k_cellranger_top10_markers.tsv  

analysis/markers/pbmc1k_starsolo_markers.tsv  
analysis/markers/pbmc1k_starsolo_top10_markers.tsv

The markers.tsv tables contain complete marker gene results for each cluster, while the top10_markers.tsv tables contain the strongest marker genes per cluster and are used for manual biological interpretation.

Marker discovery is entirely data-driven and provides the evidence required for the annotation stage.

---

# Cell Type Annotation

Scripts used in this step:

scripts/downstream/41_annotate_celltypes_cellranger.R  
scripts/downstream/41_annotate_celltypes_starsolo.R

Cell type annotation is intentionally implemented as a manual interpretation step. This reflects standard practice in single-cell RNA-seq analysis. While automated annotation tools exist, they depend on reference atlases that may not match the biological context of a given experiment.

Cluster annotations were assigned by examining marker genes produced during the marker discovery step and comparing them with known immune cell markers.

Examples of marker patterns used during interpretation include:

LYZ, S100A8, S100A9 → monocytes  
CD74, HLA-DRA, CD79A → B cells  
TRAC, CD247, BCL11B → T cells  
GNLY, NKG7, CTSW → NK cells

The annotation scripts map cluster identifiers to biological cell types and add annotation metadata to the SingleCellExperiment object.

The following metadata fields are added to the colData slot of the object:

cell_type_label  
lineage  
annotation_confidence

Annotated objects written by this step:

analysis/objects/pbmc1k_cellranger_annotated_sce.rds  
analysis/objects/pbmc1k_starsolo_annotated_sce.rds

Annotation summary tables written:

analysis/markers/pbmc1k_cellranger_cluster_annotations.tsv  
analysis/markers/pbmc1k_starsolo_cluster_annotations.tsv

The annotation scripts also include a safeguard that detects clusters lacking annotations if cluster numbering changes, ensuring that updates to clustering do not silently invalidate annotation assignments.

---

# Comparison of Cell Ranger and STARsolo Results

The two preprocessing backends produced slightly different clustering structures.

Cell Ranger produced twelve clusters.  
STARsolo produced nine clusters.

This difference is expected because the pipelines differ in alignment strategy, UMI handling, cell filtering methods, and count matrix generation.

Despite these structural differences, both pipelines recovered consistent immune cell populations including B cells, T cells, NK cells, monocytes, and antigen-presenting myeloid cells.

The lineage distribution between pipelines was highly similar, indicating that the biological signal is robust across preprocessing strategies.

This agreement provides confidence that the preprocessing pipelines are producing biologically valid outputs.

---

# Differential Expression Demonstration

Scripts used in this step:

scripts/downstream/42_differential_cellranger.R  
scripts/downstream/42_differential_starsolo.R

The PBMC1k dataset used for this pilot pipeline does not contain experimental condition metadata. Because of this, differential expression analysis was implemented as a demonstration contrast between annotated cell populations.

The contrast used was:

B cells versus T cells

Differential testing was performed using the limma framework on normalized log expression values stored in the logcounts assay of the SingleCellExperiment object.

Output tables produced:

analysis/markers/pbmc1k_cellranger_Bcells_vs_Tcells_DE.tsv  
analysis/markers/pbmc1k_starsolo_Bcells_vs_Tcells_DE.tsv

These tables contain gene-level statistics including log fold change, average expression, p-values, and adjusted p-values.

The strongest differential genes reflect known lineage markers such as CD79A, HLA-DRA, MS4A1, BANK1, and PAX5 for B cells, demonstrating that the differential analysis is recovering biologically meaningful signals.

---

# Variance Warning in Differential Analysis

During differential analysis, the following warning may appear:

More than half of residual variances are exactly zero: eBayes unreliable

This occurs because single-cell RNA-seq matrices are highly sparse and many genes exhibit little or no variance within specific cell type groups.

The B cell versus T cell contrast used in this demonstration is also biologically strong, which can amplify this effect.

In practice this means that gene rankings and log fold changes remain interpretable, but p-values should be interpreted cautiously.

For this reason the differential expression analysis in this section should be considered exploratory rather than a finalized statistical framework.

In production workflows, more robust approaches would likely involve pseudobulk differential expression or mixed-effects models that better handle single-cell variance structure.

---

# Pathway Enrichment Analysis

Scripts used in this step:

scripts/downstream/43_pathway_enrichment_cellranger.R  
scripts/downstream/43_pathway_enrichment_starsolo.R

Gene ranking for enrichment analysis was generated using log fold changes from the differential expression results.

Pathway enrichment was performed using the fgsea package together with gene sets obtained through msigdbr.

The gene set collections used were:

MSigDB Hallmark pathways  
Reactome pathways

Output files produced:

analysis/markers/pbmc1k_cellranger_Bcells_vs_Tcells_Hallmark_fgsea.tsv  
analysis/markers/pbmc1k_cellranger_Bcells_vs_Tcells_Reactome_fgsea.tsv  

analysis/markers/pbmc1k_starsolo_Bcells_vs_Tcells_Hallmark_fgsea.tsv  
analysis/markers/pbmc1k_starsolo_Bcells_vs_Tcells_Reactome_fgsea.tsv

Hallmark enrichment produced relatively weak signals in this lineage comparison, which is expected given the broad immune cell type contrast used in the demonstration.

Reactome enrichment showed strong B-cell-associated pathways including CD22 mediated B-cell receptor regulation, MHC class II antigen presentation, and signaling by the B-cell receptor.

These results confirm the biological validity of the B cell versus T cell comparison.

---

# Environment and Package Compatibility

During implementation, installation of several enrichment-related packages failed due to version constraints.

The server environment currently uses:

R 4.1.2  
Bioconductor 3.14

Modern versions of packages such as clusterProfiler, ReactomePA, and ggtree require newer versions of R and Bioconductor.

Because of these constraints, pathway enrichment in this pilot pipeline was implemented using fgsea together with msigdbr, which provides equivalent functionality for gene set enrichment analysis.

Future pipeline hardening should include upgrading the R and Bioconductor environment so that modern enrichment and visualization packages can be installed without dependency conflicts.

---

# Outputs Generated in This Section

Annotated objects:

analysis/objects/pbmc1k_cellranger_annotated_sce.rds  
analysis/objects/pbmc1k_starsolo_annotated_sce.rds

Marker gene tables:

analysis/markers/pbmc1k_cellranger_markers.tsv  
analysis/markers/pbmc1k_cellranger_top10_markers.tsv  

analysis/markers/pbmc1k_starsolo_markers.tsv  
analysis/markers/pbmc1k_starsolo_top10_markers.tsv

Differential expression results:

analysis/markers/pbmc1k_cellranger_Bcells_vs_Tcells_DE.tsv  
analysis/markers/pbmc1k_starsolo_Bcells_vs_Tcells_DE.tsv

Pathway enrichment results:

analysis/markers/pbmc1k_cellranger_Bcells_vs_Tcells_Hallmark_fgsea.tsv  
analysis/markers/pbmc1k_cellranger_Bcells_vs_Tcells_Reactome_fgsea.tsv  

analysis/markers/pbmc1k_starsolo_Bcells_vs_Tcells_Hallmark_fgsea.tsv  
analysis/markers/pbmc1k_starsolo_Bcells_vs_Tcells_Reactome_fgsea.tsv

These outputs complete the downstream interpretation stage of the pilot scRNA-seq analysis pipeline.
