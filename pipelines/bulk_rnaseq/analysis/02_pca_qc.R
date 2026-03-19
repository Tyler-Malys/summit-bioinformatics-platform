#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(DESeq2)
  library(ggplot2)
  library(SummarizedExperiment)
})

vsd_path <- "analysis_objects/vsd_crc_vs_hep_20260225.rds"
out_dir  <- "results/qc"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

vsd <- readRDS(vsd_path)

# PCA colored by cell line
pdat <- plotPCA(vsd, intgroup = "cell_line", returnData = TRUE)
percentVar <- round(100 * attr(pdat, "percentVar"))

p <- ggplot(pdat, aes(PC1, PC2, color = cell_line)) +
  geom_point(size = 3, alpha = 0.9) +
  xlab(paste0("PC1: ", percentVar[1], "% variance")) +
  ylab(paste0("PC2: ", percentVar[2], "% variance")) +
  ggtitle("PCA (VST): SW48 / SW480 / SW1116 vs Hep") +
  theme_bw()

ggsave(file.path(out_dir, "pca_crc_vs_hep.png"), p, width = 7, height = 5, dpi = 300)

# Save PCA scores (includes sample metadata used by plotPCA)
write.csv(pdat, file.path(out_dir, "pca_scores_crc_vs_hep.csv"), row.names = FALSE)

cat("Saved PCA plot:", file.path(out_dir, "pca_crc_vs_hep.png"), "\n")
cat("Saved PCA scores:", file.path(out_dir, "pca_scores_crc_vs_hep.csv"), "\n")
