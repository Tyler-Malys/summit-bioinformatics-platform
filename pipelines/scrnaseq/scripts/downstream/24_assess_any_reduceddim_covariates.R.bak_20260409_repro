#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(SingleCellExperiment)
})

args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 3) {
  stop(
    paste(
      "Usage:",
      "Rscript scripts/downstream/24_assess_any_reduceddim_covariates.R <input_sce.rds> <reduceddim_name> <output_tsv> [n_dims]",
      sep = "\n"
    )
  )
}

input_sce       <- args[1]
reduceddim_name <- args[2]
output_tsv      <- args[3]
n_dims          <- if (length(args) >= 4) as.integer(args[4]) else 10

if (is.na(n_dims) || n_dims <= 0) {
  stop("n_dims must be a positive integer.")
}

message("=== 24_assess_any_reduceddim_covariates.R ===")
message("Input SCE:        ", input_sce)
message("ReducedDim name:  ", reduceddim_name)
message("Output TSV:       ", output_tsv)
message("N dimensions:     ", n_dims)

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

if (!(reduceddim_name %in% reducedDimNames(sce))) {
  stop("Reduced dimension not found in object: ", reduceddim_name)
}

required_covariates <- c("total_counts", "detected_genes", "pct_mito")
missing_covariates <- setdiff(required_covariates, colnames(colData(sce)))

if (length(missing_covariates) > 0) {
  stop(
    "Missing required covariates in colData(sce): ",
    paste(missing_covariates, collapse = ", ")
  )
}

message("[2/5] Extracting reduced dimension coordinates...")
rd_mat <- reducedDim(sce, reduceddim_name)

if (!is.matrix(rd_mat)) {
  rd_mat <- as.matrix(rd_mat)
}

available_dims <- ncol(rd_mat)
n_dims <- min(n_dims, available_dims)

if (n_dims < 1) {
  stop("No dimensions available for assessment.")
}

message("Number of cells:        ", nrow(rd_mat))
message("Available dimensions:   ", available_dims)
message("Assessing dimensions:   ", n_dims)

message("[3/5] Preparing covariate table...")
cov_df <- as.data.frame(colData(sce)[, required_covariates, drop = FALSE])

for (nm in required_covariates) {
  cov_df[[nm]] <- as.numeric(cov_df[[nm]])
}

message("[4/5] Computing Pearson correlations and p-values...")
results_list <- list()

prefix <- if (grepl("^PC", colnames(rd_mat)[1])) "" else "Dim"

for (dim_idx in seq_len(n_dims)) {
  dim_name <- if (!is.null(colnames(rd_mat)) && nzchar(colnames(rd_mat)[dim_idx])) {
    colnames(rd_mat)[dim_idx]
  } else {
    paste0(prefix, dim_idx)
  }

  dim_values <- rd_mat[, dim_idx]

  for (cov_name in required_covariates) {
    cov_values <- cov_df[[cov_name]]
    keep <- is.finite(dim_values) & is.finite(cov_values)

    if (sum(keep) < 3) {
      cor_est <- NA_real_
      p_val <- NA_real_
      n_used <- sum(keep)
    } else {
      ct <- suppressWarnings(cor.test(dim_values[keep], cov_values[keep], method = "pearson"))
      cor_est <- unname(ct$estimate)
      p_val <- ct$p.value
      n_used <- sum(keep)
    }

    results_list[[length(results_list) + 1]] <- data.frame(
      reduction = reduceddim_name,
      dimension = dim_name,
      dimension_index = dim_idx,
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
results_df <- results_df[order(results_df$dimension_index, results_df$covariate), , drop = FALSE]
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
message("Saved covariate assessment to: ", output_tsv)

top_hits <- results_df[order(results_df$abs_correlation, decreasing = TRUE), , drop = FALSE]
top_n <- min(6, nrow(top_hits))

if (top_n > 0) {
  message("Top associations by absolute correlation:")
  for (i in seq_len(top_n)) {
    row_i <- top_hits[i, , drop = FALSE]
    message(
      "  ",
      row_i$dimension,
      " vs ",
      row_i$covariate,
      ": r=",
      round(row_i$correlation, 4),
      ", p=",
      signif(row_i$p_value, 4)
    )
  }
}
