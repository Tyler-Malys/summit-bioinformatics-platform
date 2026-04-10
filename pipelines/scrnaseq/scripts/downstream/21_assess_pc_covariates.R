#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(SingleCellExperiment)
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
write_stage_session_info("21_assess_pc_covariates")

args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 2) {
  stop(
    paste(
      "Usage:",
      "Rscript scripts/downstream/21_assess_pc_covariates.R <input_sce.rds> <output_tsv> [n_pcs]",
      sep = "\n"
    )
  )
}

input_sce  <- args[1]
output_tsv <- args[2]
n_pcs      <- if (length(args) >= 3) as.integer(args[3]) else 10

if (is.na(n_pcs) || n_pcs <= 0) {
  stop("n_pcs must be a positive integer.")
}

message("=== 21_assess_pc_covariates.R ===")
message("Input SCE:   ", input_sce)
message("Output TSV:  ", output_tsv)
message("N PCs:       ", n_pcs)

if (!file.exists(input_sce)) {
  stop("Input SCE file does not exist: ", input_sce)
}

output_dir <- dirname(output_tsv)
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
}

message("[1/5] Reading input SCE...")
sce <- readRDS(input_sce)

if (!inherits(sce, "SingleCellExperiment")) {
  stop("Input object is not a SingleCellExperiment.")
}

if (!"PCA" %in% reducedDimNames(sce)) {
  stop("Input SCE does not contain reducedDim(sce, 'PCA'). Run PCA first.")
}

required_covariates <- c("total_counts", "detected_genes", "pct_mito")
missing_covariates <- setdiff(required_covariates, colnames(colData(sce)))

if (length(missing_covariates) > 0) {
  stop(
    "Missing required covariates in colData(sce): ",
    paste(missing_covariates, collapse = ", ")
  )
}

message("[2/5] Extracting PCA coordinates...")
pc_mat <- reducedDim(sce, "PCA")

if (!is.matrix(pc_mat)) {
  pc_mat <- as.matrix(pc_mat)
}

available_pcs <- ncol(pc_mat)
n_pcs <- min(n_pcs, available_pcs)

if (n_pcs < 1) {
  stop("No PCs available for assessment.")
}

message("Number of cells: ", nrow(pc_mat))
message("Available PCs:   ", available_pcs)
message("Assessing PCs:   ", n_pcs)

message("[3/5] Preparing covariate table...")
cov_df <- as.data.frame(colData(sce)[, required_covariates, drop = FALSE])

# Ensure numeric
for (nm in required_covariates) {
  cov_df[[nm]] <- as.numeric(cov_df[[nm]])
}

message("[4/5] Computing Pearson correlations and p-values...")
results_list <- list()

for (pc_idx in seq_len(n_pcs)) {
  pc_name <- paste0("PC", pc_idx)
  pc_values <- pc_mat[, pc_idx]

  for (cov_name in required_covariates) {
    cov_values <- cov_df[[cov_name]]

    keep <- is.finite(pc_values) & is.finite(cov_values)

    if (sum(keep) < 3) {
      cor_est <- NA_real_
      p_val <- NA_real_
      n_used <- sum(keep)
    } else {
      ct <- suppressWarnings(cor.test(pc_values[keep], cov_values[keep], method = "pearson"))
      cor_est <- unname(ct$estimate)
      p_val <- ct$p.value
      n_used <- sum(keep)
    }

    results_list[[length(results_list) + 1]] <- data.frame(
      pc = pc_name,
      pc_index = pc_idx,
      covariate = cov_name,
      correlation = cor_est,
      abs_correlation = abs(cor_est),
      p_value = p_val,
      n_cells_used = n_used,
      stringsAsFactors = FALSE
    )
  }
}

results_df <- do.call(rbind, results_list)
results_df <- results_df[order(results_df$pc_index, results_df$covariate), , drop = FALSE]
results_df$fdr <- p.adjust(results_df$p_value, method = "BH")

message("[5/5] Writing results...")
write.table(
  results_df,
  file = output_tsv,
  sep = "\t",
  quote = FALSE,
  row.names = FALSE,
  col.names = TRUE
)

message("Done.")
message("Saved PC-covariate assessment to: ", output_tsv)

top_hits <- results_df[order(results_df$abs_correlation, decreasing = TRUE), , drop = FALSE]
top_n <- min(6, nrow(top_hits))

if (top_n > 0) {
  message("Top associations by absolute correlation:")
  for (i in seq_len(top_n)) {
    row_i <- top_hits[i, , drop = FALSE]
    message(
      "  ",
      row_i$pc,
      " vs ",
      row_i$covariate,
      ": r=",
      round(row_i$correlation, 4),
      ", p=",
      signif(row_i$p_value, 4)
    )
  }
}
