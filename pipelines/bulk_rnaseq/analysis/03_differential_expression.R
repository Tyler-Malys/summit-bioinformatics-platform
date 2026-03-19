#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(DESeq2)
})

dds_path <- "analysis_objects/dds_crc_vs_hep_20260225.rds"
out_dir  <- "results/de"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

dds <- readRDS(dds_path)

cat("Loaded dds:", dds_path, "\n")
cat("Design:", deparse(design(dds)), "\n")
cat("Groups:\n")
print(table(dds$cell_line))

# Helper: run results + optional shrinkage, then export
run_contrast <- function(dds_obj, contrast_vec, label) {
  cat("\n--- Contrast:", label, "---\n")
  res <- results(dds_obj, contrast = contrast_vec)
  res <- res[order(res$padj), ]

  # Try LFC shrinkage if available (apeglm is best)
  shrunk <- NULL
  if (requireNamespace("apeglm", quietly = TRUE)) {
    cat("Applying LFC shrinkage with apeglm...\n")
    coef_name <- paste0("cell_line_", contrast_vec[2], "_vs_", contrast_vec[3])
    shrunk <- lfcShrink(dds_obj, coef = coef_name, type = "apeglm")
    shrunk <- shrunk[order(shrunk$padj), ]
  } else {
    cat("apeglm not available; skipping LFC shrinkage.\n")
  }

  # Export unshrunk
  out_csv <- file.path(out_dir, paste0("DESeq2_", label, "_unshrunk.csv"))
  write.csv(as.data.frame(res), out_csv, quote = TRUE)
  cat("Wrote:", out_csv, "\n")

  # Export shrunk if available
  if (!is.null(shrunk)) {
    out_csv_s <- file.path(out_dir, paste0("DESeq2_", label, "_lfcShrink_apeglm.csv"))
    write.csv(as.data.frame(shrunk), out_csv_s, quote = TRUE)
    cat("Wrote:", out_csv_s, "\n")
  }

  # Summary counts
  sig <- sum(!is.na(res$padj) & res$padj < 0.05)
  sig_lfc1 <- sum(!is.na(res$padj) & res$padj < 0.05 & abs(res$log2FoldChange) >= 1)
  data.frame(
    contrast = label,
    n_tested = sum(!is.na(res$pvalue)),
    n_sig_padj_0.05 = sig,
    n_sig_padj_0.05_lfc1 = sig_lfc1
  )
}

# Ensure Hep is the reference (should already be)
dds$cell_line <- relevel(dds$cell_line, ref = "Hep")

# 1–3) Per-cell-line contrasts vs Hep
sum_list <- list()
sum_list[[1]] <- run_contrast(dds, c("cell_line", "SW48",  "Hep"), "SW48_vs_Hep")
sum_list[[2]] <- run_contrast(dds, c("cell_line", "SW480", "Hep"), "SW480_vs_Hep")
sum_list[[3]] <- run_contrast(dds, c("cell_line", "SW1116","Hep"), "SW1116_vs_Hep")

# 4) Pooled CRC vs Hep: build a new DESeq2 object with group2
cat("\n--- Building pooled CRC vs Hep model ---\n")

coldata <- as.data.frame(colData(dds))
coldata$group2 <- ifelse(coldata$cell_line == "Hep", "Hep", "CRC")
coldata$group2 <- factor(coldata$group2, levels = c("Hep", "CRC"))

counts_pool <- counts(dds)
counts_pool <- as.matrix(counts_pool)
storage.mode(counts_pool) <- "integer"

dds_pool <- DESeqDataSetFromMatrix(
  countData = counts_pool,
  colData   = coldata,
  design    = ~ group2
)

dds_pool <- DESeq(dds_pool)

# pooled contrast
res_pool <- results(dds_pool, contrast = c("group2", "CRC", "Hep"))
res_pool <- res_pool[order(res_pool$padj), ]

out_pool <- file.path(out_dir, "DESeq2_PooledCRC_vs_Hep_unshrunk.csv")
write.csv(as.data.frame(res_pool), out_pool, quote = TRUE)
cat("Wrote:", out_pool, "\n")

# optional shrinkage for pooled
if (requireNamespace("apeglm", quietly = TRUE)) {
  cat("Applying LFC shrinkage to pooled model with apeglm...\n")
  shr_pool <- lfcShrink(dds_pool, coef = "group2_CRC_vs_Hep", type = "apeglm")
  shr_pool <- shr_pool[order(shr_pool$padj), ]
  out_pool_s <- file.path(out_dir, "DESeq2_PooledCRC_vs_Hep_lfcShrink_apeglm.csv")
  write.csv(as.data.frame(shr_pool), out_pool_s, quote = TRUE)
  cat("Wrote:", out_pool_s, "\n")
} else {
  cat("apeglm not available; skipping pooled shrinkage.\n")
}

sig_pool <- sum(!is.na(res_pool$padj) & res_pool$padj < 0.05)
sig_pool_lfc1 <- sum(!is.na(res_pool$padj) & res_pool$padj < 0.05 & abs(res_pool$log2FoldChange) >= 1)

sum_list[[4]] <- data.frame(
  contrast = "PooledCRC_vs_Hep",
  n_tested = sum(!is.na(res_pool$pvalue)),
  n_sig_padj_0.05 = sig_pool,
  n_sig_padj_0.05_lfc1 = sig_pool_lfc1
)

# Write summary table
summary_df <- do.call(rbind, sum_list)
out_sum <- file.path(out_dir, "DESeq2_contrast_summary.csv")
write.csv(summary_df, out_sum, row.names = FALSE, quote = TRUE)
cat("\nWrote summary:", out_sum, "\n")

cat("\nDone.\n")
