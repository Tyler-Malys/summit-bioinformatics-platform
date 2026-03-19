#!/usr/bin/env Rscript

# Minimal scRNA loader + baseline metrics WITHOUT Seurat.
# Supports:
#  - STARsolo matrix.mtx + barcodes.tsv + features.tsv
#  - Cell Ranger 10X matrix directory (requires Matrix + optional gzip)

args <- commandArgs(trailingOnly = TRUE)

get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (length(idx) == 0) return(default)
  if (idx == length(args)) stop(paste("Missing value after", flag))
  args[idx + 1]
}

run_id   <- get_arg("--run_id", default = NA_character_)
backend  <- tolower(get_arg("--backend", default = NA_character_))  # cellranger|starsolo
matrix   <- tolower(get_arg("--matrix", default = "filtered"))      # filtered|raw
out_base <- get_arg("--out_base", default = "results/validation")
repo_root <- get_arg("--repo_root", default = ".")

if (is.na(run_id) || is.na(backend)) {
  cat("USAGE:\n",
      "  Rscript analysis/01_load_counts_scRNA.R --run_id <RUN_ID> --backend <cellranger|starsolo> [--matrix filtered|raw]\n",
      "OPTIONAL:\n",
      "  --out_base results/validation\n",
      "  --repo_root .\n",
      sep = "")
  quit(status = 2)
}

suppressPackageStartupMessages({
  if (!requireNamespace("Matrix", quietly = TRUE)) {
    stop("R package 'Matrix' is required. Install it with: install.packages('Matrix')")
  }
})
library(Matrix)

repo_root <- normalizePath(repo_root, winslash = "/", mustWork = TRUE)
out_dir <- file.path(repo_root, out_base, run_id, backend)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

read_lines_maybe_gz <- function(path) {
  if (grepl("\\.gz$", path)) {
    con <- gzfile(path, open = "rt")
    on.exit(close(con), add = TRUE)
    readLines(con)
  } else {
    readLines(path)
  }
}

read_mtx_maybe_gz <- function(path) {
  if (grepl("\\.gz$", path)) {
    con <- gzfile(path, open = "rt")
    on.exit(close(con), add = TRUE)
    Matrix::readMM(con)
  } else {
    Matrix::readMM(path)
  }
}

load_starsolo <- function(run_id, matrix) {
  mdir <- file.path(repo_root, "runs/starsolo", run_id, "Solo.out", "Gene", matrix)
  mtx <- file.path(mdir, "matrix.mtx")
  features <- file.path(mdir, "features.tsv")
  barcodes <- file.path(mdir, "barcodes.tsv")

  if (!file.exists(mtx) || !file.exists(features) || !file.exists(barcodes)) {
    stop(paste0("STARsolo files missing in: ", mdir, "\nExpected: matrix.mtx, features.tsv, barcodes.tsv"))
  }

  mat <- readMM(mtx)
  feats <- readLines(features)
  bcs <- readLines(barcodes)

  # features.tsv is usually: gene_id \t gene_name \t feature_type (or similar)
  feat_df <- do.call(rbind, strsplit(feats, "\t", fixed = TRUE))
  if (ncol(feat_df) < 1) stop("features.tsv parse error")
  gene_ids <- feat_df[, 1]
  gene_names <- if (ncol(feat_df) >= 2) feat_df[, 2] else gene_ids

  # Ensure dimensions line up
  if (nrow(mat) != length(gene_ids)) stop("Matrix rows != features length")
  if (ncol(mat) != length(bcs)) stop("Matrix cols != barcodes length")

  rownames(mat) <- gene_names
  colnames(mat) <- bcs

  list(counts = mat, genes = gene_names, barcodes = bcs)
}

load_cellranger <- function(run_id, matrix) {
  # 10X directory structure; may be gzipped
  mdir <- if (matrix == "filtered") {
    file.path(repo_root, "runs/cellranger_count", run_id, "outs", "filtered_feature_bc_matrix")
  } else {
    file.path(repo_root, "runs/cellranger_count", run_id, "outs", "raw_feature_bc_matrix")
  }

  if (!dir.exists(mdir)) stop(paste0("Cell Ranger matrix dir not found: ", mdir))

  # Newer CR: matrix.mtx.gz + features.tsv.gz + barcodes.tsv.gz
  mtx <- if (file.exists(file.path(mdir, "matrix.mtx.gz"))) file.path(mdir, "matrix.mtx.gz") else file.path(mdir, "matrix.mtx")
  feats <- if (file.exists(file.path(mdir, "features.tsv.gz"))) file.path(mdir, "features.tsv.gz") else file.path(mdir, "genes.tsv.gz")
  if (!file.exists(feats)) feats <- if (file.exists(file.path(mdir, "features.tsv"))) file.path(mdir, "features.tsv") else file.path(mdir, "genes.tsv")
  bcs <- if (file.exists(file.path(mdir, "barcodes.tsv.gz"))) file.path(mdir, "barcodes.tsv.gz") else file.path(mdir, "barcodes.tsv")

  if (!file.exists(mtx) || !file.exists(feats) || !file.exists(bcs)) {
    stop(paste0("Missing Cell Ranger matrix files in: ", mdir))
  }

  mat <- read_mtx_maybe_gz(mtx)
  feat_lines <- read_lines_maybe_gz(feats)
  bc_lines <- read_lines_maybe_gz(bcs)

  feat_df <- do.call(rbind, strsplit(feat_lines, "\t", fixed = TRUE))
  gene_ids <- feat_df[, 1]
  gene_names <- if (ncol(feat_df) >= 2) feat_df[, 2] else gene_ids

  if (nrow(mat) != length(gene_ids)) stop("Matrix rows != features length")
  if (ncol(mat) != length(bc_lines)) stop("Matrix cols != barcodes length")

  rownames(mat) <- gene_names
  colnames(mat) <- bc_lines

  list(counts = mat, genes = gene_names, barcodes = bc_lines)
}

obj <- if (backend == "starsolo") {
  load_starsolo(run_id, matrix)
} else if (backend == "cellranger") {
  load_cellranger(run_id, matrix)
} else {
  stop("Invalid --backend. Use cellranger or starsolo.")
}

counts <- obj$counts

# Baseline metrics
nCount_RNA <- Matrix::colSums(counts)
nFeature_RNA <- Matrix::colSums(counts > 0)

# percent.mt based on gene symbol prefix "MT-"
gene_names <- rownames(counts)
mt_idx <- grepl("^MT-", gene_names)
percent_mt <- if (any(mt_idx)) {
  mt_counts <- Matrix::colSums(counts[mt_idx, , drop = FALSE])
  as.numeric((mt_counts / nCount_RNA) * 100)
} else {
  rep(0, length(nCount_RNA))
}

per_cell <- data.frame(
  barcode = colnames(counts),
  nCount_RNA = as.numeric(nCount_RNA),
  nFeature_RNA = as.numeric(nFeature_RNA),
  percent.mt = as.numeric(percent_mt),
  stringsAsFactors = FALSE
)

summary_out <- data.frame(
  run_id = run_id,
  backend = backend,
  matrix = matrix,
  n_cells = ncol(counts),
  n_genes = nrow(counts),
  total_umis = as.numeric(sum(nCount_RNA)),
  median_umis_per_cell = as.numeric(median(nCount_RNA)),
  median_genes_per_cell = as.numeric(median(nFeature_RNA)),
  median_percent_mt = as.numeric(median(percent_mt)),
  stringsAsFactors = FALSE
)

write.csv(per_cell, file = file.path(out_dir, "per_cell_basic_metrics.csv"), row.names = FALSE)
write.csv(summary_out, file = file.path(out_dir, "counts_summary.csv"), row.names = FALSE)
saveRDS(obj, file = file.path(out_dir, "counts_object.rds"))

cat("OK\n")
cat("Wrote:\n")
cat(" - ", file.path(out_dir, "per_cell_basic_metrics.csv"), "\n", sep = "")
cat(" - ", file.path(out_dir, "counts_summary.csv"), "\n", sep = "")
cat(" - ", file.path(out_dir, "counts_object.rds"), "\n", sep = "")
