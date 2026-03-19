options(stringsAsFactors = FALSE)

suppressPackageStartupMessages({
  library(SingleCellExperiment)
  library(scran)
})

infile <- "analysis/objects/pbmc1k_cellranger_umap_tsne_sce.rds"
outdir <- "analysis/markers"
cluster_col <- "cluster_pca_regressed"

dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

cat("Reading object:", infile, "\n")
sce <- readRDS(infile)

clusters <- factor(colData(sce)[[cluster_col]])

cat("Cluster counts:\n")
print(table(clusters))

keep <- rowSums(counts(sce) > 0) > 0
sce <- sce[keep, ]
cat("Retained genes:", nrow(sce), "\n")

cat("Running findMarkers...\n")

fm <- findMarkers(
  sce,
  groups = clusters,
  assay.type = "logcounts",
  direction = "up",
  lfc = 0.5
)

cat("Returned", length(fm), "cluster tables\n")

all_tabs <- lapply(names(fm), function(cl) {

  tab <- as.data.frame(fm[[cl]])
  tab$feature_id <- rownames(tab)

  tab$gene_id <- rowData(sce)$gene_id[match(tab$feature_id, rownames(sce))]
  tab$gene_name <- rowData(sce)$gene_name[match(tab$feature_id, rownames(sce))]

  tab$cluster <- cl

  tab
})

all_cols <- unique(unlist(lapply(all_tabs, colnames)))

all_tabs <- lapply(all_tabs, function(tab) {
  missing_cols <- setdiff(all_cols, colnames(tab))
  if (length(missing_cols) > 0) {
    for (mc in missing_cols) {
      tab[[mc]] <- NA
    }
  }
  tab[, all_cols, drop = FALSE]
})

markers <- do.call(rbind, all_tabs)

markers <- markers[, c(
  "cluster",
  "feature_id",
  "gene_id",
  "gene_name",
  setdiff(colnames(markers), c("cluster","feature_id","gene_id","gene_name"))
)]

outfile <- file.path(outdir, "pbmc1k_cellranger_markers.tsv")

write.table(
  markers,
  outfile,
  sep="\t",
  quote=FALSE,
  row.names=FALSE
)

cat("Wrote:", outfile, "\n")


top10 <- do.call(rbind,
  lapply(split(markers, markers$cluster), function(x) {

    x <- x[order(x$FDR, -x$summary.logFC), ]

    head(x, 10)

  })
)

topfile <- file.path(outdir, "pbmc1k_cellranger_top10_markers.tsv")

write.table(
  top10,
  topfile,
  sep="\t",
  quote=FALSE,
  row.names=FALSE
)

cat("Wrote:", topfile, "\n")

cat("\nTop markers preview:\n")
print(top10[,c("cluster","gene_name","FDR","summary.logFC")])
