#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(SingleCellExperiment)
  library(igraph)
})

args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 2) {
  stop(
    paste(
      "Usage:",
      "Rscript scripts/downstream/31_cluster_knn_graphs.R <input_sce.rds> <output_sce.rds> [algorithm]",
      sep = "\n"
    )
  )
}

input_sce  <- args[1]
output_sce <- args[2]
algorithm  <- if (length(args) >= 3) args[3] else "louvain"

algorithm <- tolower(algorithm)

if (!algorithm %in% c("louvain", "walktrap", "leiden")) {
  stop("algorithm must be one of: louvain, walktrap, leiden")
}

message("=== 31_cluster_knn_graphs.R ===")
message("Input SCE:   ", input_sce)
message("Output SCE:  ", output_sce)
message("Algorithm:   ", algorithm)

if (!file.exists(input_sce)) {
  stop("Input SCE file does not exist: ", input_sce)
}

output_dir <- dirname(output_sce)
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
}

message("[1/6] Reading input SCE...")
sce <- readRDS(input_sce)

if (!inherits(sce, "SingleCellExperiment")) {
  stop("Input object is not a SingleCellExperiment.")
}

if (!"graphs" %in% names(metadata(sce))) {
  stop("Input SCE does not contain metadata(sce)$graphs.")
}

graphs <- metadata(sce)$graphs

if (!"knn_pca" %in% names(graphs)) {
  stop("metadata(sce)$graphs does not contain 'knn_pca'.")
}

if (!"knn_pca_regressed" %in% names(graphs)) {
  stop("metadata(sce)$graphs does not contain 'knn_pca_regressed'.")
}

g_pca <- graphs$knn_pca
g_pca_reg <- graphs$knn_pca_regressed

if (!inherits(g_pca, "igraph")) {
  stop("'knn_pca' is not an igraph object.")
}

if (!inherits(g_pca_reg, "igraph")) {
  stop("'knn_pca_regressed' is not an igraph object.")
}

run_graph_clustering <- function(g, algorithm) {
  if (algorithm == "louvain") {
    cl <- igraph::cluster_louvain(g)
  } else if (algorithm == "walktrap") {
    cl <- igraph::cluster_walktrap(g)
    cl <- igraph::as_membership(cl)
  } else if (algorithm == "leiden") {
    cl <- igraph::cluster_leiden(g)
  } else {
    stop("Unsupported algorithm: ", algorithm)
  }

  if (inherits(cl, "membership")) {
    membership <- as.vector(cl)
  } else {
    membership <- igraph::membership(cl)
  }

  return(list(
    membership = membership,
    n_clusters = length(unique(membership))
  ))
}

message("[2/6] Clustering PCA graph...")
res_pca <- run_graph_clustering(g_pca, algorithm)

message("[3/6] Clustering PCA_regressed graph...")
res_pca_reg <- run_graph_clustering(g_pca_reg, algorithm)

if (length(res_pca$membership) != ncol(sce)) {
  stop("PCA graph clustering membership length does not match number of cells.")
}

if (length(res_pca_reg$membership) != ncol(sce)) {
  stop("PCA_regressed graph clustering membership length does not match number of cells.")
}

message("[4/6] Storing cluster labels in colData(sce)...")
colData(sce)$cluster_pca <- factor(res_pca$membership)
colData(sce)$cluster_pca_regressed <- factor(res_pca_reg$membership)

message("[5/6] Storing clustering metadata...")
metadata(sce)$clustering <- list(
  algorithm = algorithm,
  graph_names = c("knn_pca", "knn_pca_regressed"),
  cluster_fields = c("cluster_pca", "cluster_pca_regressed"),
  pca_n_clusters = res_pca$n_clusters,
  pca_regressed_n_clusters = res_pca_reg$n_clusters
)

message("[6/6] Saving output SCE...")
saveRDS(sce, file = output_sce)

message("Done.")
message("Saved clustered SCE to: ", output_sce)
message("PCA clusters: ", res_pca$n_clusters)
message("PCA_regressed clusters: ", res_pca_reg$n_clusters)
