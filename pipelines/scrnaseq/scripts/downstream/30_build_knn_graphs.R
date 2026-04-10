#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(SingleCellExperiment)
  library(scran)
  library(igraph)
})

# Reproducibility
pipeline_root_env <- Sys.getenv("PIPELINE_ROOT", unset = "")

pipeline_root <- if (
  nzchar(pipeline_root_env) &&
  file.exists(file.path(pipeline_root_env, "scripts", "utils", "reproducibility_helpers.R"))
) {
  pipeline_root_env
} else if (
  file.exists(file.path(getwd(), "scripts", "utils", "reproducibility_helpers.R"))
) {
  normalizePath(getwd(), winslash = "/", mustWork = TRUE)
} else {
  stop(
    "Could not resolve pipeline root for reproducibility helper. ",
    "Checked PIPELINE_ROOT and current working directory."
  )
}

source(file.path(pipeline_root, "scripts", "utils", "reproducibility_helpers.R"))
PIPELINE_SEED <- initialize_pipeline_seed()
write_stage_session_info("30_build_knn_graphs")

args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 2) {
  stop(
    paste(
      "Usage:",
      "Rscript scripts/downstream/30_build_knn_graphs.R <input_sce.rds> <output_sce.rds> [k] [n_pcs]",
      sep = "\n"
    )
  )
}

input_sce  <- args[1]
output_sce <- args[2]
k          <- if (length(args) >= 3) as.integer(args[3]) else 20
n_pcs      <- if (length(args) >= 4) as.integer(args[4]) else 20

if (is.na(k) || k <= 1) {
  stop("k must be an integer > 1.")
}

if (is.na(n_pcs) || n_pcs <= 1) {
  stop("n_pcs must be an integer > 1.")
}

message("=== 30_build_knn_graphs.R ===")
message("Input SCE:   ", input_sce)
message("Output SCE:  ", output_sce)
message("K:           ", k)
message("N PCs:       ", n_pcs)

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

rd_names <- reducedDimNames(sce)

if (!"PCA" %in% rd_names) {
  stop("Input SCE does not contain reducedDim(sce, 'PCA').")
}

if (!"PCA_regressed" %in% rd_names) {
  stop("Input SCE does not contain reducedDim(sce, 'PCA_regressed').")
}

pca_mat <- reducedDim(sce, "PCA")
pca_reg_mat <- reducedDim(sce, "PCA_regressed")

if (!is.matrix(pca_mat) || !is.matrix(pca_reg_mat)) {
  stop("Reduced dimensions PCA/PCA_regressed must be matrices.")
}

max_pcs <- min(ncol(pca_mat), ncol(pca_reg_mat))
n_pcs <- min(n_pcs, max_pcs)

if (n_pcs < 2) {
  stop("After bounds checking, fewer than 2 PCs are available.")
}

message("Loaded object with ",
        nrow(sce), " genes and ",
        ncol(sce), " cells.")
message("ReducedDims present: ", paste(rd_names, collapse = ", "))
message("Adjusted PCs used for graph construction: ", n_pcs)

message("[2/6] Subsetting PCA embeddings...")
pca_use <- pca_mat[, seq_len(n_pcs), drop = FALSE]
pca_reg_use <- pca_reg_mat[, seq_len(n_pcs), drop = FALSE]

message("[3/6] Building KNN graph from PCA...")
message(sprintf("Using PIPELINE_SEED: %d", PIPELINE_SEED))
g_pca <- buildKNNGraph(t(pca_use), k = k)

message("[4/6] Building KNN graph from PCA_regressed...")
message(sprintf("Using PIPELINE_SEED: %d", PIPELINE_SEED))
g_pca_reg <- buildKNNGraph(t(pca_reg_use), k = k)

message("[5/6] Storing graphs and graph metadata...")
metadata(sce)$graphs <- list(
  knn_pca = g_pca,
  knn_pca_regressed = g_pca_reg
)

metadata(sce)$graph_build <- list(
  method = "scran::buildKNNGraph",
  k = k,
  n_pcs = n_pcs,
  graph_names = c("knn_pca", "knn_pca_regressed"),
  input_reduced_dims = c("PCA", "PCA_regressed"),
  pca_graph_nodes = igraph::vcount(g_pca),
  pca_graph_edges = igraph::ecount(g_pca),
  pca_regressed_graph_nodes = igraph::vcount(g_pca_reg),
  pca_regressed_graph_edges = igraph::ecount(g_pca_reg)
)

message("[6/6] Saving output SCE...")
saveRDS(sce, file = output_sce)

message("Done.")
message("Saved graph-annotated SCE to: ", output_sce)
message("Stored graph objects: knn_pca, knn_pca_regressed")
message("PCA graph nodes/edges: ", igraph::vcount(g_pca), " / ", igraph::ecount(g_pca))
message("PCA_regressed graph nodes/edges: ", igraph::vcount(g_pca_reg), " / ", igraph::ecount(g_pca_reg))
