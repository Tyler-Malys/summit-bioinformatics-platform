#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

suppressPackageStartupMessages({
  library(SingleCellExperiment)
})

args_full <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args_full[grep(file_arg, args_full)])

if (length(script_path) == 0) {
  stop("Unable to resolve script path from commandArgs().")
}

script_path <- normalizePath(script_path[1])
script_dir <- dirname(script_path)
pipeline_root <- normalizePath(file.path(script_dir, "..", ".."))

repro_helpers <- file.path(pipeline_root, "scripts", "utils", "reproducibility_helpers.R")
if (!file.exists(repro_helpers)) {
  stop("Could not find reproducibility helpers: ", repro_helpers)
}

source(repro_helpers)

initialize_pipeline_seed()
write_stage_session_info("41_annotate_celltypes_starsolo")

infile <- "analysis/objects/pbmc1k_starsolo_umap_tsne_sce.rds"
out_object <- "analysis/objects/pbmc1k_starsolo_annotated_sce.rds"
out_table <- "analysis/markers/pbmc1k_starsolo_cluster_annotations.tsv"

cluster_col <- "cluster_pca_regressed"

infile <- "analysis/objects/pbmc1k_starsolo_umap_tsne_sce.rds"
out_object <- "analysis/objects/pbmc1k_starsolo_annotated_sce.rds"
out_table <- "analysis/markers/pbmc1k_starsolo_cluster_annotations.tsv"

cluster_col <- "cluster_pca_regressed"

sce <- readRDS(infile)

if (!inherits(sce, "SingleCellExperiment")) {
  stop("Input object is not a SingleCellExperiment.")
}

if (!(cluster_col %in% colnames(colData(sce)))) {
  stop("Cluster column not found in colData: ", cluster_col)
}

clusters <- as.character(colData(sce)[[cluster_col]])

cluster_to_celltype <- c(
  "1" = "CD14-like / inflammatory monocytes",
  "2" = "B cells",
  "3" = "cytotoxic T / NK-like lymphocytes",
  "4" = "T cells",
  "5" = "B cells",
  "6" = "monocytes / antigen-presenting myeloid",
  "7" = "T cells",
  "8" = "NK cells",
  "9" = "myeloid APC-like cells",
  "10" = "myeloid APC-like cells"
)

cluster_to_lineage <- c(
  "1" = "myeloid",
  "2" = "lymphoid",
  "3" = "lymphoid",
  "4" = "lymphoid",
  "5" = "lymphoid",
  "6" = "myeloid",
  "7" = "lymphoid",
  "8" = "lymphoid",
  "9" = "myeloid",
  "10" = "myeloid"
)

cluster_to_confidence <- c(
  "1" = "high",
  "2" = "high",
  "3" = "medium",
  "4" = "medium",
  "5" = "medium",
  "6" = "high",
  "7" = "medium",
  "8" = "high",
  "9" = "medium",
  "10" = "medium"
)

cluster_to_notes <- c(
  "1" = "LYZ S100A8 S100A9 CTSS TYROBP AIF1 VCAN",
  "2" = "HLA-DRA CD74 IGHM HLA-DPA1 HLA-DRB1 CD79A",
  "3" = "IL32 HCST CCL5 NKG7 GZMA CD3E; mixed cytotoxic lymphocyte signature",
  "4" = "TRAC LTB IL32 LDHB; broad T-cell cluster",
  "5" = "CD74 CD79A HLA-DRB1 HLA-DPA1; smaller B-cell cluster",
  "6" = "FCER1G CST3 HLA-DRA LYZ GRN; antigen-presenting myeloid signature",
  "7" = "LDHB ribosomal-rich lymphoid cluster; likely T-cell subset",
  "8" = "GZMA NKG7 CTSW GNLY KLRD1 HCST TYROBP",
  "9" = "COTL1 TYROBP AIF1 LST1 SAT1; myeloid APC-like cluster",
  "10" = "AIF1 COTL1 TYROBP LST1 FCGR3A MS4A7 HLA-DPA1; myeloid APC-like cluster"
)

missing_clusters <- setdiff(sort(unique(clusters)), names(cluster_to_celltype))
if (length(missing_clusters) > 0) {
  stop("Missing annotation for cluster(s): ", paste(missing_clusters, collapse = ", "))
}

sce$cell_type_label <- unname(cluster_to_celltype[clusters])
sce$lineage <- unname(cluster_to_lineage[clusters])
sce$annotation_confidence <- unname(cluster_to_confidence[clusters])

annotation_table <- data.frame(
  cluster = sort(unique(clusters)),
  cell_type_label = unname(cluster_to_celltype[sort(unique(clusters))]),
  lineage = unname(cluster_to_lineage[sort(unique(clusters))]),
  confidence = unname(cluster_to_confidence[sort(unique(clusters))]),
  notes = unname(cluster_to_notes[sort(unique(clusters))]),
  stringsAsFactors = FALSE
)

cluster_counts <- as.data.frame(table(clusters), stringsAsFactors = FALSE)
colnames(cluster_counts) <- c("cluster", "n_cells")

annotation_table <- merge(
  annotation_table,
  cluster_counts,
  by = "cluster",
  all.x = TRUE,
  sort = FALSE
)

annotation_table <- annotation_table[
  match(sort(unique(clusters)), annotation_table$cluster),
]

saveRDS(sce, out_object)

write.table(
  annotation_table,
  file = out_table,
  sep = "\t",
  quote = FALSE,
  row.names = FALSE
)

cat("Wrote annotated object:", out_object, "\n")
cat("Wrote annotation table:", out_table, "\n\n")

cat("Cell type counts:\n")
print(table(sce$cell_type_label, useNA = "ifany"))

cat("\nLineage counts:\n")
print(table(sce$lineage, useNA = "ifany"))

cat("\nCluster annotation table:\n")
print(annotation_table)
