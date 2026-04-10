#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(DESeq2)
  library(ggplot2)
  library(SummarizedExperiment)
})

source(file.path(Sys.getenv("PIPELINE_ROOT", unset = "."), "analysis", "lib", "reproducibility_utils.R"))

pipeline_seed <- initialize_pipeline_seed()
cat("PIPELINE_SEED:", pipeline_seed, "\n")

args <- commandArgs(trailingOnly = TRUE)

get_flag_value <- function(flag) {
  idx <- match(flag, args)
  if (is.na(idx)) return(NULL)
  if (idx == length(args)) stop(paste0("ERROR: missing value after ", flag), call. = FALSE)
  args[[idx + 1]]
}

print_usage <- function() {
  cat("Usage:\n")
  cat("  Rscript analysis/02_pca_qc.R \\\n")
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

write_stage_session_info("02_pca_qc")
