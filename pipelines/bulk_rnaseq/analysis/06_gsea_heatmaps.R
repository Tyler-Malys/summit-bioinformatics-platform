#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(data.table)
  library(pheatmap)
})

message("Starting GSEA heatmap generation...")

# ----------------------------
# Directories
# ----------------------------

IN_DIR  <- file.path("results", "gsea", "summary")
OUT_DIR <- file.path("results", "gsea", "figures")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# ----------------------------
# Utility functions
# ----------------------------

pick_nes_cols <- function(dt, preferred_order) {
  cols <- paste0("NES_", preferred_order)
  cols[cols %in% names(dt)]
}

make_mat <- function(dt, nes_cols) {
  m <- as.matrix(dt[, ..nes_cols])
  rownames(m) <- dt$pathway
  storage.mode(m) <- "numeric"
  m
}

cap_symmetric <- function(m, cap = 3) {
  m[m >  cap] <-  cap
  m[m < -cap] <- -cap
  m
}

plot_heatmap <- function(m, title, out_prefix, cap = 3) {

  if (nrow(m) == 0) {
    stop(paste("Matrix for", out_prefix, "has 0 rows. Nothing to plot."))
  }

  m2 <- cap_symmetric(m, cap = cap)

  palette <- colorRampPalette(c("#2C7BB6", "#FFFFFF", "#D7191C"))(101)

  pdf(file.path(OUT_DIR, paste0(out_prefix, ".pdf")), width = 8, height = 10)

  pheatmap(
    m2,
    color = palette,
    cluster_rows = TRUE,
    cluster_cols = TRUE,
    scale = "none",
    fontsize_row = 7,
    fontsize_col = 10,
    border_color = NA,
    main = title,
    breaks = seq(-cap, cap, length.out = 102)
  )

  dev.off()

  png(file.path(OUT_DIR, paste0(out_prefix, ".png")), width = 2000, height = 2500, res = 300)

  pheatmap(
    m2,
    color = palette,
    cluster_rows = TRUE,
    cluster_cols = TRUE,
    scale = "none",
    fontsize_row = 7,
    fontsize_col = 10,
    border_color = NA,
    main = title,
    breaks = seq(-cap, cap, length.out = 102)
  )

  dev.off()
}

# ----------------------------
# Contrast order (stable)
# ----------------------------

contrast_order <- c(
  "crc_vs_hep_pooled",
  "sw48_vs_hep",
  "sw480_vs_hep",
  "sw1116_vs_hep"
)

# ----------------------------
# Hallmark (shared-only)
# ----------------------------

hallmark_file <- file.path(
  IN_DIR,
  "gsea_shared_hallmark_all4_same_direction_wide.csv"
)

if (!file.exists(hallmark_file)) {
  stop("Hallmark wide file not found: ", hallmark_file)
}

hallmark_dt <- fread(hallmark_file)

hallmark_nes_cols <- pick_nes_cols(hallmark_dt, contrast_order)

if (length(hallmark_nes_cols) < 2) {
  stop("Not enough Hallmark NES columns found.")
}

hallmark_mat <- make_mat(hallmark_dt, hallmark_nes_cols)

plot_heatmap(
  hallmark_mat,
  title = "GSEA Hallmark (shared; padj<=0.05; same direction) - NES",
  out_prefix = "hallmark_shared_heatmap",
  cap = 3
)

message("Wrote: hallmark_shared_heatmap.pdf/png")

# ----------------------------
# Reactome (shared-only)
# ----------------------------

reactome_file <- file.path(
  IN_DIR,
  "gsea_shared_reactome_all4_same_direction_wide.csv"
)

if (!file.exists(reactome_file)) {
  stop("Reactome wide file not found: ", reactome_file)
}

reactome_dt <- fread(reactome_file)

# Keep a readable subset for Reactome: Top 40 by NES_range
TOP_N_REACTOME <- 40

if (!("NES_range" %in% names(reactome_dt))) {
  stop("Expected NES_range in Reactome wide table but did not find it.")
}

reactome_dt <- reactome_dt[order(-NES_range)][1:min(TOP_N_REACTOME, .N)]

reactome_nes_cols <- pick_nes_cols(reactome_dt, contrast_order)

if (length(reactome_nes_cols) < 2) {
  stop("Not enough Reactome NES columns found.")
}

reactome_mat <- make_mat(reactome_dt, reactome_nes_cols)

plot_heatmap(
  reactome_mat,
  title = "GSEA Reactome (shared; Top 40 by NES_range) - NES",
  out_prefix = "reactome_shared_top40_heatmap",
  cap = 3
)

message("Wrote: reactome_shared_heatmap.pdf/png")

message("Done.")
