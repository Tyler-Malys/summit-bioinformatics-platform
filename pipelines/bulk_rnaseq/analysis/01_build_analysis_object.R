#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(DESeq2)
})

cat("---- Building Analysis-Ready DESeq2 Object ----\n")

# ===============================
# 1. Define Paths
# ===============================

counts_path <- "results/tximport/txi_crc150_salmon_20260223/gene_counts.csv"

out_dds <- "analysis_objects/dds_crc_vs_hep_20260225.rds"
out_vsd <- "analysis_objects/vsd_crc_vs_hep_20260225.rds"

# ===============================
# 2. Load Gene Counts
# ===============================

cat("Loading counts from:", counts_path, "\n")

counts <- read.csv(
  counts_path,
  row.names = 1,
  check.names = FALSE
)

cat("Initial dimensions (genes x samples):", dim(counts), "\n")

# Remove any empty gene IDs (safety)
counts <- counts[rownames(counts) != "" & !is.na(rownames(counts)), ]

# ===============================
# 3. Build Metadata from Sample Names
# ===============================

samples <- colnames(counts)

meta <- data.frame(
  sample_id = samples,
  stringsAsFactors = FALSE
)

# Extract cell line (prefix before first underscore)
meta$cell_line <- sub("_.*", "", meta$sample_id)

# Extract dose (D1/D2/D3/D4/DMSO)
meta$dose <- sub(".*_(D[0-9]+|DMSO)_.*", "\\1", meta$sample_id)

# Extract replicate number (last numeric token)
meta$replicate <- sub(".*_([0-9]+)$", "\\1", meta$sample_id)

meta$cell_line <- factor(meta$cell_line)
meta$dose      <- factor(meta$dose)

cat("Cell line breakdown (before filtering):\n")
print(table(meta$cell_line))

# ===============================
# 4. Keep Approved Cell Lines
#    (Exclude THLE_2)
# ===============================

keep <- meta$cell_line %in% c("Hep", "SW48", "SW480", "SW1116")

counts <- counts[, keep]
meta   <- meta[keep, , drop = FALSE]

# Reorder metadata to match counts
meta <- meta[match(colnames(counts), meta$sample_id), ]

stopifnot(all(meta$sample_id == colnames(counts)))

cat("Cell line breakdown (after filtering):\n")
print(table(meta$cell_line))

cat("Dimensions after sample filtering:", dim(counts), "\n")

# ===============================
# 5. Gene Filtering
#    Keep genes with >=10 counts
#    in at least 2 samples
# ===============================

genes_before <- nrow(counts)

keep_genes <- rowSums(counts >= 10) >= 2
counts_f   <- counts[keep_genes, ]

# Convert to matrix, then round to integers for DESeq2
counts_f <- as.matrix(counts_f)
counts_f <- round(counts_f)
storage.mode(counts_f) <- "integer"

genes_after <- nrow(counts_f)

cat("Genes before filtering:", genes_before, "\n")
cat("Genes after filtering:", genes_after, "\n")
cat("Genes removed:", genes_before - genes_after, "\n")

# ===============================
# 6. Create DESeq2 Object
# ===============================

dds <- DESeqDataSetFromMatrix(
  countData = counts_f,
  colData   = meta,
  design    = ~ cell_line
)

# Set hepatocytes as reference
dds$cell_line <- relevel(dds$cell_line, ref = "Hep")

cat("Design formula:", deparse(design(dds)), "\n")

# ===============================
# 7. Run DESeq (Normalization + Model)
# ===============================

cat("Running DESeq...\n")

dds <- DESeq(dds)

cat("DESeq complete.\n")

# ===============================
# 8. Variance Stabilizing Transform
# ===============================

cat("Performing VST transformation...\n")

vsd <- DESeq2::vst(dds, blind = FALSE)

cat("VST complete.\n")

# ===============================
# 9. Save Objects
# ===============================
dir.create("analysis_objects", showWarnings = FALSE, recursive = TRUE)

saveRDS(dds, out_dds)
saveRDS(vsd, out_vsd)

cat("Saved DESeq2 object to:", out_dds, "\n")
cat("Saved VST object to:", out_vsd, "\n")

cat("---- Analysis Object Build Complete ----\n")
