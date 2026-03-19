#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(SingleCellExperiment)
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(readr)
})

dir.create("analysis/figures/downstream", recursive = TRUE, showWarnings = FALSE)
dir.create("analysis/figures/downstream/cellranger", recursive = TRUE, showWarnings = FALSE)
dir.create("analysis/figures/downstream/starsolo", recursive = TRUE, showWarnings = FALSE)
dir.create("analysis/figures/downstream/comparison", recursive = TRUE, showWarnings = FALSE)

save_plot <- function(p, path, width = 9, height = 7) {
  ggsave(filename = path, plot = p, width = width, height = height, dpi = 300)
}

make_embedding_df <- function(sce, reduction_name, color_field) {
  emb <- reducedDim(sce, reduction_name)
  df <- as.data.frame(emb)
  colnames(df) <- c("dim1", "dim2")
  df[[color_field]] <- colData(sce)[[color_field]]
  df
}

plot_embedding <- function(sce, reduction_name, color_field, title) {
  df <- make_embedding_df(sce, reduction_name, color_field)
  ggplot(df, aes(x = dim1, y = dim2, color = .data[[color_field]])) +
    geom_point(size = 0.6, alpha = 0.8) +
    labs(
      title = title,
      x = paste0(reduction_name, "_1"),
      y = paste0(reduction_name, "_2"),
      color = color_field
    ) +
    theme_bw(base_size = 12)
}

plot_cluster_sizes <- function(sce, cluster_field, title) {
  df <- as.data.frame(colData(sce)) %>%
    count(.data[[cluster_field]], name = "n") %>%
    rename(cluster = 1)

  ggplot(df, aes(x = factor(cluster), y = n)) +
    geom_col() +
    labs(title = title, x = "Cluster", y = "Cell count") +
    theme_bw(base_size = 12)
}

plot_celltype_composition <- function(sce, title) {
  df <- as.data.frame(colData(sce)) %>%
    count(cell_type_label, name = "n")

  ggplot(df, aes(x = reorder(cell_type_label, -n), y = n)) +
    geom_col() +
    labs(title = title, x = "Cell type", y = "Cell count") +
    theme_bw(base_size = 12) +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
}

plot_marker_dotplot <- function(sce, marker_genes, group_field, title) {
  genes_present <- intersect(marker_genes, rownames(sce))
  if (length(genes_present) == 0) {
    stop("None of the requested marker genes were found in the object.")
  }

  expr <- logcounts(sce)[genes_present, , drop = FALSE]
  meta <- as.data.frame(colData(sce))
  groups <- meta[[group_field]]

  plot_df <- do.call(rbind, lapply(genes_present, function(g) {
    values <- as.numeric(expr[g, ])
    tmp <- data.frame(
      gene = g,
      group = groups,
      expr = values,
      stringsAsFactors = FALSE
    )

    tmp %>%
      group_by(group) %>%
      summarise(
        mean_expr = mean(expr, na.rm = TRUE),
        pct_expr = mean(expr > 0, na.rm = TRUE) * 100,
        .groups = "drop"
      ) %>%
      mutate(gene = g)
  }))

  plot_df$gene <- factor(plot_df$gene, levels = genes_present)

  ggplot(plot_df, aes(x = gene, y = factor(group), size = pct_expr, color = mean_expr)) +
    geom_point() +
    labs(
      title = title,
      x = "Marker gene",
      y = group_field,
      size = "% expressing",
      color = "Mean logexpr"
    ) +
    theme_bw(base_size = 12) +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
}

export_backend_figures <- function(sce_path, backend_name, outdir) {
  sce <- readRDS(sce_path)
  prefix <- paste0("pbmc1k_", backend_name)

  save_plot(
    plot_embedding(sce, "UMAP", "cluster_pca", paste0("PBMC1k | ", backend_name, " UMAP by cluster")),
    file.path(outdir, paste0(prefix, "_umap_clusters.png"))
  )

  save_plot(
    plot_embedding(sce, "UMAP", "cell_type_label", paste0("PBMC1k | ", backend_name, " UMAP by cell type")),
    file.path(outdir, paste0(prefix, "_umap_celltypes.png"))
  )

  save_plot(
    plot_embedding(sce, "UMAP", "lineage", paste0("PBMC1k | ", backend_name, " UMAP by lineage")),
    file.path(outdir, paste0(prefix, "_umap_lineage.png"))
  )

  save_plot(
    plot_embedding(sce, "TSNE", "cluster_pca", paste0("PBMC1k | ", backend_name, " t-SNE by cluster")),
    file.path(outdir, paste0(prefix, "_tsne_clusters.png"))
  )

  save_plot(
    plot_embedding(sce, "TSNE", "cell_type_label", paste0("PBMC1k | ", backend_name, " t-SNE by cell type")),
    file.path(outdir, paste0(prefix, "_tsne_celltypes.png"))
  )

  save_plot(
    plot_cluster_sizes(sce, "cluster_pca", paste0("PBMC1k | ", backend_name, " cluster sizes")),
    file.path(outdir, paste0(prefix, "_cluster_sizes.png"))
  )

  save_plot(
    plot_celltype_composition(sce, paste0("PBMC1k | ", backend_name, " cell type composition")),
    file.path(outdir, paste0(prefix, "_celltype_composition.png"))
  )

  marker_panel <- c(
    "CD3D", "CD3E",
    "MS4A1", "CD79A",
    "NKG7", "GNLY",
    "LYZ", "S100A8", "S100A9",
    "HLA-DRA", "CD74"
  )

  save_plot(
    plot_marker_dotplot(
      sce,
      marker_genes = marker_panel,
      group_field = "cluster_pca",
      title = paste0("PBMC1k | ", backend_name, " canonical marker dot plot")
    ),
    file.path(outdir, paste0(prefix, "_marker_dotplot.png")),
    width = 11,
    height = 7
  )

  invisible(sce)
}

make_backend_comparison_plot <- function(cellranger_path, starsolo_path, outdir) {
  sce_cr <- readRDS(cellranger_path)
  sce_ss <- readRDS(starsolo_path)

  df <- bind_rows(
    as.data.frame(colData(sce_cr)) %>%
      count(cell_type_label, name = "n") %>%
      mutate(backend = "cellranger"),
    as.data.frame(colData(sce_ss)) %>%
      count(cell_type_label, name = "n") %>%
      mutate(backend = "starsolo")
  )

  p <- ggplot(df, aes(x = cell_type_label, y = n, fill = backend)) +
    geom_col(position = "dodge") +
    labs(
      title = "PBMC1k | Cell type composition by preprocessing backend",
      x = "Cell type",
      y = "Cell count"
    ) +
    theme_bw(base_size = 12) +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))

  save_plot(p, file.path(outdir, "pbmc1k_backend_celltype_comparison.png"), width = 10, height = 7)
}

cellranger_path <- "analysis/objects/pbmc1k_cellranger_annotated_sce.rds"
starsolo_path   <- "analysis/objects/pbmc1k_starsolo_annotated_sce.rds"

export_backend_figures(cellranger_path, "cellranger", "analysis/figures/downstream/cellranger")
export_backend_figures(starsolo_path, "starsolo", "analysis/figures/downstream/starsolo")
make_backend_comparison_plot(cellranger_path, starsolo_path, "analysis/figures/downstream/comparison")

message("Downstream visualizations exported successfully.")
