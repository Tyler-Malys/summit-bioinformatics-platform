#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(DESeq2)
  library(SummarizedExperiment)
  library(vsn)   # for meanSdPlot()
})

args <- commandArgs(trailingOnly = TRUE)

get_flag_value <- function(flag) {
  idx <- match(flag, args)
  if (is.na(idx)) return(NULL)
  if (idx == length(args)) stop(paste0("ERROR: missing value after ", flag), call. = FALSE)
  args[[idx + 1]]
}

print_usage <- function() {
  cat("Usage:\n")
  cat("  Rscript analysis/01b_vst_diagnostics.R \\\n")
  cat("    --vsd-path <vsd.rds> \\\n")
  cat("    --out-dir <output_dir>\n")
}

if ("-h" %in% args || "--help" %in% args) {
  print_usage()
  quit(status = 0, save = "no")
}

vsd_path <- get_flag_value("--vsd-path")
out_dir  <- get_flag_value("--out-dir")

if (is.null(vsd_path) || is.null(out_dir)) {
  cat("ERROR: required args missing.\n\n")
  print_usage()
  quit(status = 2, save = "no")
}

if (!file.exists(vsd_path)) {
  stop(paste0("ERROR: VSD file not found: ", vsd_path), call. = FALSE)
}

dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

cat("Loading VSD object from:", vsd_path, "\n")
cat("Writing outputs to:", out_dir, "\n")

vsd <- readRDS(vsd_path)

png(file.path(out_dir, "mean_sd_vst_plot.png"), width = 1200, height = 900, res = 150)
meanSdPlot(assay(vsd))
dev.off()

cat("Saved mean–SD VST diagnostic plot:", file.path(out_dir, "mean_sd_vst_plot.png"), "\n")
