#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(SingleCellExperiment)
  library(Rtsne)
})

args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 2) {
  stop(
    paste(
      "Usage:",
      "Rscript scripts/downstream/33_run_tsne.R <input_sce.rds> <output_sce.rds> [n_pcs]",
      sep = "\n"
    )
  )
}

input_sce  <- args[1]
output_sce <- args[2]
n_pcs      <- if (length(args) >= 3) as.integer(args[3]) else 20

if (is.na(n_pcs) || n_pcs <= 1) {
  stop("n_pcs must be an integer > 1.")
}

message("=== 33_run_tsne.R ===")
message("Input SCE:   ", input_sce)
message("Output SCE:  ", output_sce)
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

max_pcs <- min(ncol(pca_mat), ncol(pca_reg_mat))
n_pcs <- min(n_pcs, max_pcs)

if (n_pcs < 2) {
  stop("After bounds checking, fewer than 2 PCs are available.")
}

message("Loaded object with ",
        nrow(sce), " genes and ",
        ncol(sce), " cells.")
message("ReducedDims present: ", paste(rd_names, collapse = ", "))
message("Adjusted PCs used for t-SNE: ", n_pcs)

message("[2/6] Running t-SNE from PCA...")
set.seed(123)
pca_use <- pca_mat[, seq_len(n_pcs), drop = FALSE]
tsne_pca <- Rtsne(
  pca_use,
  dims = 2,
  perplexity = 30,
  check_duplicates = FALSE,
  pca = FALSE,
  verbose = TRUE
)
reducedDim(sce, "TSNE") <- tsne_pca$Y

message("[3/6] Running t-SNE from PCA_regressed...")
set.seed(123)
pca_reg_use <- pca_reg_mat[, seq_len(n_pcs), drop = FALSE]
tsne_reg <- Rtsne(
  pca_reg_use,
  dims = 2,
  perplexity = 30,
  check_duplicates = FALSE,
  pca = FALSE,
  verbose = TRUE
)
reducedDim(sce, "TSNE_regressed") <- tsne_reg$Y

message("[4/6] Recording t-SNE metadata...")
metadata(sce)$tsne <- list(
  method = "Rtsne::Rtsne",
  n_pcs = n_pcs,
  perplexity = 30,
  reduced_dims_used = c("PCA", "PCA_regressed"),
  output_names = c("TSNE", "TSNE_regressed")
)

message("[5/6] Confirming reducedDims...")
message("Reduced dimensions present: ", paste(reducedDimNames(sce), collapse = ", "))

message("[6/6] Saving output SCE...")
saveRDS(sce, file = output_sce)

message("Done.")
message("Saved t-SNE-annotated SCE to: ", output_sce)
