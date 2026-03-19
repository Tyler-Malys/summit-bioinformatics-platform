#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(DESeq2)
  library(SummarizedExperiment)
  library(vsn)   # for meanSdPlot()
})

vsd_path <- "analysis_objects/vsd_crc_vs_hep_20260225.rds"
out_dir  <- "results/qc"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

vsd <- readRDS(vsd_path)

png(file.path(out_dir, "mean_sd_vst_plot.png"), width = 1200, height = 900, res = 150)
meanSdPlot(assay(vsd))
dev.off()

cat("Saved mean–SD VST diagnostic plot:", file.path(out_dir, "mean_sd_vst_plot.png"), "\n")
