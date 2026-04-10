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
write_stage_session_info("41_annotate_celltypes_cellranger")

infile <- "analysis/objects/pbmc1k_cellranger_umap_tsne_sce.rds"
out_object <- "analysis/objects/pbmc1k_cellranger_annotated_sce.rds"
out_table <- "analysis/markers/pbmc1k_cellranger_cluster_annotations.tsv"

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
  "1"  = "CD14-like monocytes",
  "2"  = "B cells",
  "3"  = "cytotoxic lymphocytes",
  "4"  = "T cells",
  "5"  = "B cells",
  "6"  = "monocytes / antigen-presenting myeloid",
  "7"  = "T cells",
  "8"  = "IL7R+ T cells",
  "9"  = "NK cells",
  "10" = "inflammatory monocytes",
  "11" = "naive / resting T cells",
  "12" = "myeloid APC-like cells"
)

cluster_to_lineage <- c(
  "1"  = "myeloid",
  "2"  = "lymphoid",
  "3"  = "lymphoid",
  "4"  = "lymphoid",
  "5"  = "lymphoid",
  "6"  = "myeloid",
  "7"  = "lymphoid",
  "8"  = "lymphoid",
  "9"  = "lymphoid",
  "10" = "myeloid",
  "11" = "lymphoid",
  "12" = "myeloid"
)

cluster_to_confidence <- c(
  "1"  = "high",
  "2"  = "high",
  "3"  = "medium",
  "4"  = "high",
  "5"  = "medium",
  "6"  = "high",
  "7"  = "medium",
  "8"  = "high",
  "9"  = "high",
  "10" = "high",
  "11" = "high",
  "12" = "medium"
)

cluster_to_notes <- c(
  "1"  = "LYZ S100A8 S100A9 VCAN CTSS PLXDC2",
  "2"  = "CD74 HLA-DRA HLA-DRB1 HLA-DPA1 HLA-DPB1 BANK1 IGHM",
  "3"  = "CCL5 IL32 CD247 SKAP1 MYO1F; may be cytotoxic T or NK-like",
  "4"  = "SKAP1 BCL11B PRKCH FYB1 CD247 TRAC",
  "5"  = "CD74 CD79A; weaker/ribosomal-heavy B-cell cluster",
  "6"  = "CST3 FCER1G LYZ HLA-DRA PLXDC2 LGALS1",
  "7"  = "CCND3 LEF1 BCL11B BACH2 TXK; likely T-cell subset",
  "8"  = "IL7R IL32 SKAP1 CD247 S100A4",
  "9"  = "GNLY NKG7 KLRD1 CTSW",
  "10" = "LYZ S100A8 S100A9 VCAN AOAH CTSS",
  "11" = "BCL11B LEF1 CD247 SKAP1 BACH2 PRKCH",
  "12" = "COTL1 LST1 AIF1 CTSS LYN; likely monocyte/DC-like"
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
