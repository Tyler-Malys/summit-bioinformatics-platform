#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(SingleCellExperiment)
})

args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 3) {
  stop(
    paste(
      "Usage:",
      "Rscript scripts/downstream/23_merge_pca_variants.R <base_sce_with_PCA.rds> <regressed_sce_with_PCA_regressed.rds> <output_sce.rds>",
      sep = "\n"
    )
  )
}

base_sce_path      <- args[1]
regressed_sce_path <- args[2]
output_sce_path    <- args[3]

message("=== 23_merge_pca_variants.R ===")
message("Base SCE:       ", base_sce_path)
message("Regressed SCE:  ", regressed_sce_path)
message("Output SCE:     ", output_sce_path)

if (!file.exists(base_sce_path)) {
  stop("Base SCE file does not exist: ", base_sce_path)
}
if (!file.exists(regressed_sce_path)) {
  stop("Regressed SCE file does not exist: ", regressed_sce_path)
}

output_dir <- dirname(output_sce_path)
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
}

message("[1/5] Reading input objects...")
sce_base <- readRDS(base_sce_path)
sce_reg  <- readRDS(regressed_sce_path)

if (!inherits(sce_base, "SingleCellExperiment")) {
  stop("Base object is not a SingleCellExperiment.")
}
if (!inherits(sce_reg, "SingleCellExperiment")) {
  stop("Regressed object is not a SingleCellExperiment.")
}

message("[2/5] Validating object compatibility...")
if (nrow(sce_base) != nrow(sce_reg) || ncol(sce_base) != ncol(sce_reg)) {
  stop("Objects do not have matching dimensions.")
}

if (!identical(rownames(sce_base), rownames(sce_reg))) {
  stop("Gene identifiers do not match between objects.")
}

if (!identical(colnames(sce_base), colnames(sce_reg))) {
  stop("Cell identifiers do not match between objects.")
}

if (!"PCA" %in% reducedDimNames(sce_base)) {
  stop("Base object does not contain reducedDim(sce, 'PCA').")
}

if (!"PCA_regressed" %in% reducedDimNames(sce_reg)) {
  stop("Regressed object does not contain reducedDim(sce, 'PCA_regressed').")
}

message("[3/5] Copying regressed PCA into base object...")
reducedDim(sce_base, "PCA_regressed") <- reducedDim(sce_reg, "PCA_regressed")

message("[4/5] Copying regression metadata...")
metadata(sce_base)$regressed_pca <- metadata(sce_reg)$regressed_pca

metadata(sce_base)$downstream_summary <- list(
  has_logcounts = "logcounts" %in% assayNames(sce_base),
  has_hvg_flags = !is.null(rowData(sce_base)$is_hvg),
  n_hvgs = sum(rowData(sce_base)$is_hvg %in% TRUE, na.rm = TRUE),
  reduced_dims = reducedDimNames(sce_base)
)

message("[5/5] Saving merged object...")
saveRDS(sce_base, file = output_sce_path)

message("Done.")
message("Saved merged SCE to: ", output_sce_path)
message("Reduced dimensions present: ", paste(reducedDimNames(sce_base), collapse = ", "))
message("Assays present: ", paste(assayNames(sce_base), collapse = ", "))
