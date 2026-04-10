#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(SingleCellExperiment)
  library(uwot)
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
write_stage_session_info("32_run_umap")

args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 2) {
  stop(
    paste(
      "Usage:",
      "Rscript scripts/downstream/32_run_umap.R <input_sce.rds> <output_sce.rds> [n_pcs]",
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

message("=== 32_run_umap.R ===")
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
message("Adjusted PCs used for UMAP: ", n_pcs)

message("[2/6] Running UMAP from PCA...")
message(sprintf("Using PIPELINE_SEED: %d", PIPELINE_SEED))

pca_use <- reducedDim(sce, "PCA")[, seq_len(n_pcs), drop = FALSE]

umap_pca <- uwot::umap(
  pca_use,
  n_neighbors = 30,
  min_dist = 0.3,
  metric = "cosine",
  verbose = TRUE
)

reducedDim(sce, "UMAP") <- umap_pca


message("[3/6] Running UMAP from PCA_regressed...")
message(sprintf("Using PIPELINE_SEED: %d", PIPELINE_SEED))

pca_reg_use <- reducedDim(sce, "PCA_regressed")[, seq_len(n_pcs), drop = FALSE]

umap_reg <- uwot::umap(
  pca_reg_use,
  n_neighbors = 30,
  min_dist = 0.3,
  metric = "cosine",
  verbose = TRUE
)

reducedDim(sce, "UMAP_regressed") <- umap_reg

message("[4/6] Recording UMAP metadata...")
metadata(sce)$umap <- list(
  method = "scater::runUMAP",
  n_pcs = n_pcs,
  reduced_dims_used = c("PCA", "PCA_regressed"),
  output_names = c("UMAP", "UMAP_regressed")
)

message("[5/6] Confirming reducedDims...")
message("Reduced dimensions present: ", paste(reducedDimNames(sce), collapse = ", "))

message("[6/6] Saving output SCE...")
saveRDS(sce, file = output_sce)

message("Done.")
message("Saved UMAP-annotated SCE to: ", output_sce)
