#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(SingleCellExperiment)
  library(BiocSingular)
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
write_stage_session_info("20_run_pca")

args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 2) {
  stop(
    paste(
      "Usage:",
      "Rscript scripts/downstream/20_run_pca.R <input_sce.rds> <output_sce.rds> [n_pcs]",
      sep = "\n"
    )
  )
}

input_sce  <- args[1]
output_sce <- args[2]
n_pcs      <- if (length(args) >= 3) as.integer(args[3]) else 30

if (is.na(n_pcs) || n_pcs <= 0) {
  stop("n_pcs must be a positive integer.")
}

message("=== 20_run_pca.R ===")
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

if (!"logcounts" %in% assayNames(sce)) {
  stop("Input SCE does not contain a 'logcounts' assay. Run normalization first.")
}

if (!"is_hvg" %in% colnames(as.data.frame(rowData(sce)))) {
  stop("Input SCE does not contain rowData(sce)$is_hvg. Run HVG selection first.")
}

hvg_idx <- which(rowData(sce)$is_hvg %in% TRUE)

if (length(hvg_idx) < 2) {
  stop("Fewer than 2 HVGs found. Cannot run PCA.")
}

n_pcs <- min(n_pcs, length(hvg_idx), ncol(sce) - 1)
if (n_pcs < 2) {
  stop("After bounds checking, fewer than 2 PCs can be computed.")
}

message("Loaded object with ",
        nrow(sce), " genes and ",
        ncol(sce), " cells.")
message("Number of HVGs used for PCA: ", length(hvg_idx))
message("Adjusted number of PCs: ", n_pcs)

message("[2/6] Extracting logcounts matrix...")
mat <- logcounts(sce)

message("[3/6] Subsetting to HVGs...")
mat_hvg <- mat[hvg_idx, , drop = FALSE]

message("[4/6] Running PCA with centering and scaling...")
message(sprintf("Using PIPELINE_SEED: %d", PIPELINE_SEED))
pca_out <- runPCA(
  t(mat_hvg),
  rank = n_pcs,
  BSPARAM = ExactParam(),
  center = TRUE,
  scale = TRUE
)

message("[5/6] Storing PCA results in reducedDims(sce)...")
reducedDim(sce, "PCA") <- pca_out$x

rotation <- pca_out$rotation
percent_var <- (pca_out$sdev ^ 2) / sum(pca_out$sdev ^ 2) * 100

metadata(sce)$pca <- list(
  percent_var = percent_var,
  sdev = pca_out$sdev,
  rotation = rotation,
  hvg_gene_ids = rownames(mat_hvg),
  n_hvgs_used = nrow(mat_hvg),
  n_pcs = n_pcs
)

message("[6/6] Saving output SCE...")
saveRDS(sce, file = output_sce)

message("Done.")
message("Saved PCA-annotated SCE to: ", output_sce)
message("Reduced dimensions present: ", paste(reducedDimNames(sce), collapse = ", "))
message("Top 5 PC variance percentages: ",
        paste(round(percent_var[seq_len(min(5, length(percent_var)))], 2), collapse = ", "))
