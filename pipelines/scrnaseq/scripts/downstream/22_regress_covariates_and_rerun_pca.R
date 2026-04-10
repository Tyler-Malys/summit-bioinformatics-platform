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
write_stage_session_info("22_regress_covariates_and_rerun_pca")

args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 2) {
  stop(
    paste(
      "Usage:",
      "Rscript scripts/downstream/22_regress_covariates_and_rerun_pca.R <input_sce.rds> <output_sce.rds> [n_pcs]",
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

message("=== 22_regress_covariates_and_rerun_pca.R ===")
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

message("[1/7] Reading input SCE...")
sce <- readRDS(input_sce)

if (!inherits(sce, "SingleCellExperiment")) {
  stop("Input object is not a SingleCellExperiment.")
}

if (!"logcounts" %in% assayNames(sce)) {
  stop("Input SCE does not contain a 'logcounts' assay.")
}

if (is.null(rowData(sce)$is_hvg)) {
  stop("Input SCE does not contain rowData(sce)$is_hvg.")
}

required_covariates <- c("total_counts", "pct_mito")
missing_covariates <- setdiff(required_covariates, colnames(colData(sce)))
if (length(missing_covariates) > 0) {
  stop(
    "Missing required covariates in colData(sce): ",
    paste(missing_covariates, collapse = ", ")
  )
}

hvg_idx <- which(rowData(sce)$is_hvg %in% TRUE)
if (length(hvg_idx) < 2) {
  stop("Fewer than 2 HVGs found. Cannot run regression/PCA.")
}

message("Loaded object with ",
        nrow(sce), " genes and ",
        ncol(sce), " cells.")
message("Number of HVGs used: ", length(hvg_idx))

message("[2/7] Building regression design matrix...")
cov_df <- data.frame(
  log_total_counts = log10(as.numeric(colData(sce)$total_counts) + 1),
  pct_mito = as.numeric(colData(sce)$pct_mito)
)

if (any(!is.finite(cov_df$log_total_counts))) {
  stop("Non-finite values detected in log_total_counts.")
}
if (any(!is.finite(cov_df$pct_mito))) {
  stop("Non-finite values detected in pct_mito.")
}

design <- model.matrix(~ log_total_counts + pct_mito, data = cov_df)

message("[3/7] Extracting logcounts for HVGs...")
mat_hvg <- logcounts(sce)[hvg_idx, , drop = FALSE]

# Convert genes x cells -> cells x genes for linear modeling
y <- t(as.matrix(mat_hvg))

if (nrow(y) != nrow(design)) {
  stop("Number of cells in expression matrix does not match design matrix.")
}

message("[4/7] Regressing out technical covariates gene-by-gene...")
qr_design <- qr(design)
coef_mat <- qr.coef(qr_design, y)
fitted_mat <- design %*% coef_mat
resid_mat <- y - fitted_mat

# Add back the intercept so gene expression remains on a comparable scale
intercept_only <- coef_mat[1, , drop = FALSE]
resid_centered <- sweep(resid_mat, 2, intercept_only, FUN = "+")

# Convert back to genes x cells
resid_hvg <- t(resid_centered)
rownames(resid_hvg) <- rownames(mat_hvg)
colnames(resid_hvg) <- colnames(mat_hvg)

message("[5/7] Running PCA on residualized HVG matrix...")
n_pcs <- min(n_pcs, nrow(resid_hvg), ncol(resid_hvg) - 1)
if (n_pcs < 2) {
  stop("After bounds checking, fewer than 2 PCs can be computed.")
}

message(sprintf("Using PIPELINE_SEED: %d", PIPELINE_SEED))
pca_out <- runPCA(
  t(resid_hvg),
  rank = n_pcs,
  BSPARAM = ExactParam(),
  center = TRUE,
  scale = TRUE
)

message("[6/7] Storing regression and PCA outputs...")
reducedDim(sce, "PCA_regressed") <- pca_out$x

percent_var <- (pca_out$sdev ^ 2) / sum(pca_out$sdev ^ 2) * 100

metadata(sce)$regressed_pca <- list(
  regressors = c("log_total_counts", "pct_mito"),
  formula = "~ log_total_counts + pct_mito",
  hvg_gene_ids = rownames(resid_hvg),
  n_hvgs_used = nrow(resid_hvg),
  n_pcs = n_pcs,
  percent_var = percent_var,
  sdev = pca_out$sdev,
  rotation = pca_out$rotation
)

message("[7/7] Saving output SCE...")
saveRDS(sce, file = output_sce)

message("Done.")
message("Saved regressed PCA SCE to: ", output_sce)
message("Reduced dimensions present: ", paste(reducedDimNames(sce), collapse = ", "))
message("Top 5 regressed PC variance percentages: ",
        paste(round(percent_var[seq_len(min(5, length(percent_var)))], 2), collapse = ", "))
