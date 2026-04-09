#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(data.table)
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
  cat("  Rscript analysis/05_gsea_summary_tables.R \\\n")
  cat("    --gsea-root <gsea_root_dir> \\\n")
  cat("    --out-dir <summary_output_dir>\n")
}

if ("-h" %in% args || "--help" %in% args) {
  print_usage()
  quit(status = 0, save = "no")
}

message("Starting GSEA summary table generation...")

# ----------------------------
# Output directory
# ----------------------------

GSEA_ROOT <- get_flag_value("--gsea-root")
OUT_DIR   <- get_flag_value("--out-dir")

if (is.null(GSEA_ROOT) || is.null(OUT_DIR)) {
  cat("ERROR: required args missing.\n\n")
  print_usage()
  quit(status = 2, save = "no")
}

if (!dir.exists(GSEA_ROOT)) {
  stop(paste0("ERROR: GSEA root directory not found: ", GSEA_ROOT), call. = FALSE)
}

dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

message("Using GSEA root: ", GSEA_ROOT)
message("Writing summary outputs to: ", OUT_DIR)

# ----------------------------
# Locate fgsea result files
# ----------------------------

files <- list.files(
  GSEA_ROOT,
  pattern = "_fgsea_stat\\.csv$",
  recursive = TRUE,
  full.names = TRUE
)

if (length(files) == 0) {
  stop("No fgsea result files found.")
}

message("Found ", length(files), " fgsea result files.")

# ----------------------------
# Read and combine
# ----------------------------

all <- rbindlist(lapply(files, function(f) {

  dt <- fread(f)

  run_id <- basename(dirname(dirname(f)))

  dt[, run_id := run_id]

  dt[, collection :=
        ifelse(grepl("hallmark", run_id, ignore.case = TRUE),
               "Hallmark", "Reactome")]

  dt[, contrast :=
        sub("_(hallmark|reactome)_.*$", "",
            run_id, ignore.case = TRUE)]

  dt
}), fill = TRUE)

# ----------------------------
# Add direction
# ----------------------------

all[, direction := ifelse(NES > 0,
                          "Up_in_CRC",
                          "Down_in_CRC")]

# ----------------------------
# Keep significant pathways
# ----------------------------

sig <- all[padj <= 0.05]

# Ensure OUT_DIR exists
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

out_sig <- file.path(OUT_DIR, "gsea_all_significant_pathways.csv")
fwrite(sig, out_sig)

message("Wrote: ", basename(out_sig))

# ----------------------------
# Shared Hallmark across all 4 contrasts (padj<=0.05) with same direction
# ----------------------------

hallmark <- sig[collection == "Hallmark"]

# If contrast parsing ever misbehaves, regenerate it safely here
hallmark[, contrast := sub("_(hallmark|reactome)_.*$", "", run_id, ignore.case = TRUE)]

shared_hallmark <- hallmark[
  ,
  .(
    n_contrasts = uniqueN(contrast),
    n_dirs      = uniqueN(direction),
    directions  = paste(sort(unique(direction)), collapse=";")
  ),
  by = pathway
][n_contrasts == 4 & n_dirs == 1][order(pathway)]

fwrite(
  shared_hallmark,
  file.path(OUT_DIR, "gsea_shared_hallmark_all4_same_direction.csv")
)

message("Wrote: gsea_shared_hallmark_all4_same_direction.csv")

# ----------------------------
# Shared Reactome across all 4 contrasts (padj<=0.05) with same direction
# ----------------------------

reactome <- sig[collection == "Reactome"]

reactome[, contrast := sub("_(hallmark|reactome)_.*$", "", run_id, ignore.case = TRUE)]

shared_reactome <- reactome[
  ,
  .(
    n_contrasts = uniqueN(contrast),
    n_dirs      = uniqueN(direction),
    directions  = paste(sort(unique(direction)), collapse=";")
  ),
  by = pathway
][n_contrasts == 4 & n_dirs == 1][order(pathway)]

fwrite(
  shared_reactome,
  file.path(OUT_DIR, "gsea_shared_reactome_all4_same_direction.csv")
)

message("Wrote: gsea_shared_reactome_all4_same_direction.csv")

# ---- Enrich shared Hallmark table with per-contrast NES/padj + deltas vs pooled ----

# Take significant Hallmark rows and define contrast label
h_sig <- sig[collection == "Hallmark"]
h_sig[, contrast := sub("_(hallmark|reactome)_.*$", "", run_id, ignore.case = TRUE)]

# Keep only the shared pathways we already identified
shared <- fread(file.path(OUT_DIR, "gsea_shared_hallmark_all4_same_direction.csv"))
h_shared <- h_sig[pathway %in% shared$pathway]

# Keep only columns we want to pivot
h_shared_small <- h_shared[, .(pathway, contrast, NES, padj, direction)]

# Pivot wider: one row per pathway, columns per contrast
wide <- dcast(
  h_shared_small,
  pathway ~ contrast,
  value.var = c("NES", "padj", "direction")
)

# Optional: add delta NES vs pooled (requires pooled column to exist)
# Adjust "crc_vs_hep_pooled" if your pooled contrast label differs.
pooled_key <- "crc_vs_hep_pooled"

# Desired contrast order for output columns
contrast_order <- c("crc_vs_hep_pooled", "sw48_vs_hep", "sw480_vs_hep", "sw1116_vs_hep")

# Reorder pivoted columns into a stable, human-friendly order (if present)
nes_cols  <- paste0(contrast_order, "_NES")
padj_cols <- paste0(contrast_order, "_padj")
dir_cols  <- paste0(contrast_order, "_direction")

keep_nes  <- nes_cols[nes_cols %in% names(wide)]
keep_padj <- padj_cols[padj_cols %in% names(wide)]
keep_dir  <- dir_cols[dir_cols %in% names(wide)]

nes_pooled_col <- paste0(pooled_key, "_NES")
if (nes_pooled_col %in% names(wide)) {
  for (c in setdiff(keep_nes, nes_pooled_col)) {
    delta_name <- sub("_NES$", "_dNES_vs_pooled", c)
    wide[, (delta_name) := get(c) - get(nes_pooled_col)]
  }
}

# Summary metrics across contrasts (using available NES columns)
if (length(keep_nes) >= 2) {
  wide[, NES_min := do.call(pmin, c(.SD, na.rm = TRUE)), .SDcols = keep_nes]
  wide[, NES_max := do.call(pmax, c(.SD, na.rm = TRUE)), .SDcols = keep_nes]
  wide[, NES_range := NES_max - NES_min]
}

# Which contrast is closest to pooled (smallest absolute delta)
delta_cols <- grep("^dNES_vs_pooled_", names(wide), value = TRUE)
if (length(delta_cols) > 0) {
  wide[, closest_to_pooled := {
    x <- unlist(.SD)
    nm <- names(x)
    nm <- nm[!is.na(x)]
    if (length(nm) == 0) NA_character_ else sub("_dNES_vs_pooled$", "", nm[which.min(abs(x[nm]))])
  }, by = pathway, .SDcols = delta_cols]
}

# Which contrast is most divergent from pooled (largest absolute delta)
if (length(delta_cols) > 0) {
  wide[, most_divergent_from_pooled := {
    x <- unlist(.SD)
    nm <- names(x)
    nm <- nm[!is.na(x)]
    if (length(nm) == 0) NA_character_ else sub("_dNES_vs_pooled$", "", nm[which.max(abs(x[nm]))])
  }, by = pathway, .SDcols = delta_cols]
}

# Reorder columns: pathway, NES*, padj*, direction*, then deltas
delta_cols <- grep("^dNES_vs_pooled_", names(wide), value = TRUE)

col_order <- c(
  "pathway",
  keep_nes,
  keep_padj,
  keep_dir,
  delta_cols,
  "NES_range",
  "closest_to_pooled",
  "most_divergent_from_pooled"
)

col_order <- col_order[col_order %in% names(wide)]

setcolorder(wide, col_order)

# Helpful ordering: by absolute pooled NES (if present), else alphabetic
if (nes_pooled_col %in% names(wide)) {
  wide[, absNES_pooled := abs(get(nes_pooled_col))]
  setorder(wide, -absNES_pooled, pathway)
  wide[, absNES_pooled := NULL]
} else {
  setorder(wide, pathway)
}

out_wide <- file.path(OUT_DIR, "gsea_shared_hallmark_all4_same_direction_wide.csv")
fwrite(wide, out_wide)
message("Wrote: ", basename(out_wide))

# ----------------------------
# Ranked summary: Top 10 Hallmark by pooled |NES| (fallback: mean |NES|)
# ----------------------------

pooled_col <- paste0(pooled_key, "_NES")
nes_cols_present <- grep("^NES_", names(wide), value = TRUE)

wide_rank_h <- copy(wide)

if (pooled_col %in% names(wide_rank_h)) {
  wide_rank_h[, pooled_abs_NES := abs(get(pooled_col))]
} else {
  # fallback if pooled is absent: mean(|NES|) over available NES columns
  wide_rank_h[, pooled_abs_NES := if (length(nes_cols_present) > 0) rowMeans(abs(as.matrix(.SD)), na.rm = TRUE) else NA_real_, .SDcols = nes_cols_present]
}

top10_hallmark <- wide_rank_h[order(-pooled_abs_NES)][1:min(10, .N)]

out_top10_h <- file.path(OUT_DIR, "gsea_top10_hallmark_by_pooled_absNES.csv")
fwrite(top10_hallmark, out_top10_h)
message("Wrote: ", basename(out_top10_h))

# ---- Reactome wide summary (shared only) ----
r_sig <- sig[collection == "Reactome"]
r_sig[, contrast := sub("_(hallmark|reactome)_.*$", "", run_id, ignore.case = TRUE)]

shared_r <- fread(file.path(OUT_DIR, "gsea_shared_reactome_all4_same_direction.csv"))
r_shared <- r_sig[pathway %in% shared_r$pathway]

r_shared_small <- r_shared[, .(pathway, contrast, NES, padj, direction)]

wide_r <- dcast(
  r_shared_small,
  pathway ~ contrast,
  value.var = c("NES", "padj", "direction")
)

pooled_key <- "crc_vs_hep_pooled"
contrast_order <- c("crc_vs_hep_pooled", "sw48_vs_hep", "sw480_vs_hep", "sw1116_vs_hep")

nes_cols  <- paste0(contrast_order, "_NES")
padj_cols <- paste0(contrast_order, "_padj")
dir_cols  <- paste0(contrast_order, "_direction")

keep_nes  <- nes_cols[nes_cols %in% names(wide_r)]
keep_padj <- padj_cols[padj_cols %in% names(wide_r)]
keep_dir  <- dir_cols[dir_cols %in% names(wide_r)]

nes_pooled_col <- paste0(pooled_key, "_NES")

if (nes_pooled_col %in% names(wide_r)) {
  for (c in setdiff(keep_nes, nes_pooled_col)) {
    delta_name <- sub("_NES$", "_dNES_vs_pooled", c)
    wide_r[, (delta_name) := get(c) - get(nes_pooled_col)]
  }
}

if (length(keep_nes) >= 2) {
  wide_r[, NES_min := do.call(pmin, c(.SD, na.rm = TRUE)), .SDcols = keep_nes]
  wide_r[, NES_max := do.call(pmax, c(.SD, na.rm = TRUE)), .SDcols = keep_nes]
  wide_r[, NES_range := NES_max - NES_min]
}

delta_cols <- grep("^dNES_vs_pooled_", names(wide_r), value = TRUE)

if (length(delta_cols) > 0) {
  wide_r[, closest_to_pooled := {
    x <- unlist(.SD)
    nm <- names(x)
    keep <- !is.na(x)
    if (!any(keep)) NA_character_
    else {
      best <- nm[keep][which.min(abs(x[keep]))]
      sub("_dNES_vs_pooled$", "", best)
    }
  }, .SDcols = delta_cols]

  wide_r[, most_divergent_from_pooled := {
    x <- unlist(.SD)
    nm <- names(x)
    keep <- !is.na(x)
    if (!any(keep)) NA_character_
    else {
      worst <- nm[keep][which.max(abs(x[keep]))]
      sub("_dNES_vs_pooled$", "", worst)
    }
  }, .SDcols = delta_cols]
}

col_order_r <- c(
  "pathway",
  keep_nes,
  keep_padj,
  keep_dir,
  delta_cols,
  "NES_range",
  "closest_to_pooled",
  "most_divergent_from_pooled"
)

col_order_r <- col_order_r[col_order_r %in% names(wide_r)]

setcolorder(wide_r, col_order_r)

out_wide_r <- file.path(OUT_DIR, "gsea_shared_reactome_all4_same_direction_wide.csv")
fwrite(wide_r, out_wide_r)

message("Wrote: ", basename(out_wide_r))

# ----------------------------
# Ranked summary: Top 20 Reactome by NES_range
# ----------------------------
if (!("NES_range" %in% names(wide_r))) {
  message("NES_range not present in wide_r; writing fallback top20 without NES_range ordering.")
}

top20_reactome <- if ("NES_range" %in% names(wide_r)) {
  wide_r[order(-NES_range)][1:min(20, .N)]
} else {
  wide_r[1:min(20, .N)]
}

out_top20_r <- file.path(OUT_DIR, "gsea_top20_reactome_by_NES_range.csv")
fwrite(top20_reactome, out_top20_r)
message("Wrote: ", basename(out_top20_r))

# ----------------------------
# NES matrix (Hallmark - significant only)
# ----------------------------

hallmark_mat <- dcast(
  hallmark,
  pathway ~ contrast,
  value.var = "NES"
)

fwrite(
  hallmark_mat,
  file.path(OUT_DIR, "gsea_hallmark_NES_matrix.csv")
)

# ----------------------------
# NES matrix (Reactome - shared significant only)
# ----------------------------

reactome_mat <- dcast(
  r_shared,
  pathway ~ contrast,
  value.var = "NES"
)

fwrite(
  reactome_mat,
  file.path(OUT_DIR, "gsea_reactome_NES_matrix.csv")
)

message("Wrote: gsea_reactome_NES_matrix.csv")

message("Wrote: gsea_hallmark_NES_matrix.csv")

message("Done.")
