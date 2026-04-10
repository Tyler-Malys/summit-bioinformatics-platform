#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(SingleCellExperiment)
  library(scuttle)
  library(scran)
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
write_stage_session_info("10_normalize_hvg")

args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 3) {
  stop(
    paste(
      "Usage:",
      "Rscript scripts/downstream/10_normalize_hvg.R <input_sce.rds> <output_sce.rds> <output_hvg.tsv> [top_n_hvgs]",
      sep = "\n"
    )
  )
}

input_sce   <- args[1]
output_sce  <- args[2]
output_hvg  <- args[3]
top_n_hvgs  <- if (length(args) >= 4) as.integer(args[4]) else 2000

if (is.na(top_n_hvgs) || top_n_hvgs <= 0) {
  stop("top_n_hvgs must be a positive integer.")
}

message("=== 10_normalize_hvg.R ===")
message("Input SCE:   ", input_sce)
message("Output SCE:  ", output_sce)
message("Output HVG:  ", output_hvg)
message("Top N HVGs:  ", top_n_hvgs)

if (!file.exists(input_sce)) {
  stop("Input SCE file does not exist: ", input_sce)
}

output_sce_dir <- dirname(output_sce)
output_hvg_dir <- dirname(output_hvg)

if (!dir.exists(output_sce_dir)) {
  dir.create(output_sce_dir, recursive = TRUE, showWarnings = FALSE)
}
if (!dir.exists(output_hvg_dir)) {
  dir.create(output_hvg_dir, recursive = TRUE, showWarnings = FALSE)
}

message("[1/6] Reading input SCE...")
sce <- readRDS(input_sce)

if (!inherits(sce, "SingleCellExperiment")) {
  stop("Input object is not a SingleCellExperiment.")
}

if (!"counts" %in% assayNames(sce)) {
  stop("Input SCE does not contain a 'counts' assay.")
}

message("Loaded object with ",
        nrow(sce), " genes and ",
        ncol(sce), " cells.")

message("[2/6] Performing log-normalization with scuttle::logNormCounts()...")
sce <- logNormCounts(sce)

if (!"logcounts" %in% assayNames(sce)) {
  stop("Normalization failed: 'logcounts' assay was not created.")
}

message("[3/6] Modeling gene variance with scran::modelGeneVar()...")
dec <- modelGeneVar(sce)

if (nrow(dec) != nrow(sce)) {
  stop("Variance modeling output does not match number of genes in SCE.")
}

message("[4/6] Ranking HVGs...")
dec$gene_id <- rownames(dec)

# Reorder columns to put gene_id first if present
dec_df <- as.data.frame(dec)
if ("gene_id" %in% colnames(dec_df)) {
  dec_df <- dec_df[, c("gene_id", setdiff(colnames(dec_df), "gene_id")), drop = FALSE]
}

# Sort by biological component descending
if (!"bio" %in% colnames(dec_df)) {
  stop("Expected column 'bio' not found in modelGeneVar output.")
}
dec_df <- dec_df[order(dec_df$bio, decreasing = TRUE), , drop = FALSE]

top_n_hvgs <- min(top_n_hvgs, nrow(dec_df))
top_hvgs <- dec_df$gene_id[seq_len(top_n_hvgs)]

message("[5/6] Storing HVG annotations in rowData...")
rowData(sce)$hvg_bio <- dec$bio[match(rownames(sce), rownames(dec))]
rowData(sce)$hvg_total <- dec$total[match(rownames(sce), rownames(dec))]
rowData(sce)$hvg_tech <- dec$tech[match(rownames(sce), rownames(dec))]
rowData(sce)$is_hvg <- rownames(sce) %in% top_hvgs

message("Number of HVGs flagged: ", sum(rowData(sce)$is_hvg, na.rm = TRUE))

message("[6/6] Writing outputs...")
write.table(
  dec_df,
  file = output_hvg,
  sep = "\t",
  quote = FALSE,
  row.names = FALSE,
  col.names = TRUE
)

saveRDS(sce, file = output_sce)

message("Done.")
message("Saved normalized/HVG SCE to: ", output_sce)
message("Saved HVG table to: ", output_hvg)
message("Final assays: ", paste(assayNames(sce), collapse = ", "))
