#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(SingleCellExperiment)
  library(mclust)
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
write_stage_session_info("34_cluster_stability")

args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 3) {
  stop(
    paste(
      "Usage:",
      "Rscript scripts/downstream/34_cluster_stability.R <cellranger_sce.rds> <starsolo_sce.rds> <output_tsv>",
      sep = "\n"
    )
  )
}

cellranger_path <- args[1]
starsolo_path   <- args[2]
output_tsv      <- args[3]

message("=== 34_cluster_stability.R ===")
message("Cell Ranger SCE: ", cellranger_path)
message("STARsolo SCE:    ", starsolo_path)
message("Output TSV:      ", output_tsv)

if (!file.exists(cellranger_path)) {
  stop("Cell Ranger SCE file does not exist: ", cellranger_path)
}
if (!file.exists(starsolo_path)) {
  stop("STARsolo SCE file does not exist: ", starsolo_path)
}

output_dir <- dirname(output_tsv)
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
}

message("[1/5] Reading input objects...")
sce_cr <- readRDS(cellranger_path)
sce_ss <- readRDS(starsolo_path)

if (!inherits(sce_cr, "SingleCellExperiment")) {
  stop("Cell Ranger object is not a SingleCellExperiment.")
}
if (!inherits(sce_ss, "SingleCellExperiment")) {
  stop("STARsolo object is not a SingleCellExperiment.")
}

required_fields <- c("cluster_pca", "cluster_pca_regressed")

for (fld in required_fields) {
  if (!fld %in% colnames(colData(sce_cr))) {
    stop("Cell Ranger object missing colData field: ", fld)
  }
  if (!fld %in% colnames(colData(sce_ss))) {
    stop("STARsolo object missing colData field: ", fld)
  }
}

message("[2/5] Computing within-backend ARI values...")
cr_pca_vs_reg <- adjustedRandIndex(
  as.vector(colData(sce_cr)$cluster_pca),
  as.vector(colData(sce_cr)$cluster_pca_regressed)
)

ss_pca_vs_reg <- adjustedRandIndex(
  as.vector(colData(sce_ss)$cluster_pca),
  as.vector(colData(sce_ss)$cluster_pca_regressed)
)

message("[3/5] Computing cross-backend ARI values on shared cells...")

cr_ids <- sub("-1$", "", colnames(sce_cr))
ss_ids <- colnames(sce_ss)

shared_cells <- intersect(cr_ids, ss_ids)

if (length(shared_cells) < 2) {
  stop("Fewer than 2 shared harmonized cell barcodes between Cell Ranger and STARsolo objects.")
}

cr_idx <- match(shared_cells, cr_ids)
ss_idx <- match(shared_cells, ss_ids)

sce_cr_shared <- sce_cr[, cr_idx]
sce_ss_shared <- sce_ss[, ss_idx]

cr_pca_vs_ss_pca <- adjustedRandIndex(
  as.vector(colData(sce_cr_shared)$cluster_pca),
  as.vector(colData(sce_ss_shared)$cluster_pca)
)

cr_reg_vs_ss_reg <- adjustedRandIndex(
  as.vector(colData(sce_cr_shared)$cluster_pca_regressed),
  as.vector(colData(sce_ss_shared)$cluster_pca_regressed)
)

cr_pca_vs_ss_reg <- adjustedRandIndex(
  as.vector(colData(sce_cr_shared)$cluster_pca),
  as.vector(colData(sce_ss_shared)$cluster_pca_regressed)
)

cr_reg_vs_ss_pca <- adjustedRandIndex(
  as.vector(colData(sce_cr_shared)$cluster_pca_regressed),
  as.vector(colData(sce_ss_shared)$cluster_pca)
)

message("[4/5] Assembling results table...")
results <- data.frame(
  comparison = c(
    "cellranger_pca_vs_pca_regressed",
    "starsolo_pca_vs_pca_regressed",
    "cellranger_pca_vs_starsolo_pca",
    "cellranger_pca_regressed_vs_starsolo_pca_regressed",
    "cellranger_pca_vs_starsolo_pca_regressed",
    "cellranger_pca_regressed_vs_starsolo_pca"
  ),
  ari = c(
    cr_pca_vs_reg,
    ss_pca_vs_reg,
    cr_pca_vs_ss_pca,
    cr_reg_vs_ss_reg,
    cr_pca_vs_ss_reg,
    cr_reg_vs_ss_pca
  ),
  n_cells_used = c(
    ncol(sce_cr),
    ncol(sce_ss),
    length(shared_cells),
    length(shared_cells),
    length(shared_cells),
    length(shared_cells)
  ),
  stringsAsFactors = FALSE
)

message("[5/5] Writing output...")
write.table(
  results,
  file = output_tsv,
  sep = "\t",
  quote = FALSE,
  row.names = FALSE
)

message("Done.")
message("Shared cells used for cross-backend comparison: ", length(shared_cells))
print(results)
