.libPaths("~/R/x86_64-pc-linux-gnu-library/4.1")

suppressPackageStartupMessages({
  library(tximport)
  library(readr)
})

########################################
# Defaults
########################################
threads <- 1  # tximport itself is not threaded; kept for future parity
run_id <- format(Sys.time(), "%Y%m%d_%H%M%S")
dry_run <- FALSE
ignore_tx_version <- TRUE
drop_inf_reps <- TRUE
counts_from_abundance <- NA_character_  # e.g. "lengthScaledTPM" or "scaledTPM"

########################################
# Arg parsing (minimal, flag-based)
########################################
args <- commandArgs(trailingOnly = TRUE)

get_flag_value <- function(flag) {
  idx <- match(flag, args)
  if (is.na(idx)) return(NULL)
  if (idx == length(args)) stop(paste0("ERROR: missing value after ", flag), call. = FALSE)
  args[[idx + 1]]
}

has_flag <- function(flag) {
  flag %in% args
}

print_usage <- function() {
  cat("Usage:\n")
  cat("  Rscript scripts/tximport_genelevel.R \\\n")
  cat("    -i <salmon_dir> \\\n")
  cat("    -o <out_dir> \\\n")
  cat("    -m <tx2gene_tsv> \\\n")
  cat("    [--samples-txt <samples.txt>] \\\n")
  cat("    [--run-id <id>] [--dry-run] \\\n")
  cat("    [--counts-from-abundance <lengthScaledTPM|scaledTPM|no>] \\\n")
  cat("\n")
  cat("Notes:\n")
  cat("  - salmon_dir should contain per-sample folders with quant.sf\n")
  cat("  - tx2gene_tsv should have 2 columns: TXNAME<TAB>GENEID (or no header)\n")
}

if (length(args) == 0 || has_flag("-h") || has_flag("--help")) {
  print_usage()
  quit(status = 0, save = "no")
}

salmon_dir <- get_flag_value("-i")
out_root   <- get_flag_value("-o")
tx2gene_path <- get_flag_value("-m")
samples_txt <- get_flag_value("--samples-txt")

tmp_run_id <- get_flag_value("--run-id")
if (!is.null(tmp_run_id)) run_id <- tmp_run_id

if (has_flag("--dry-run")) dry_run <- TRUE

cfa <- get_flag_value("--counts-from-abundance")
if (!is.null(cfa)) {
  # allow "no" to mean NA / disabled
  if (tolower(cfa) == "no") {
    counts_from_abundance <- NA_character_
  } else {
    counts_from_abundance <- cfa
  }
}

########################################
# Validate required args
########################################
if (is.null(salmon_dir) || is.null(out_root) || is.null(tx2gene_path)) {
  cat("ERROR: missing required arguments.\n\n")
  print_usage()
  quit(status = 2, save = "no")
}

########################################
# Setup run directories + logging
########################################
run_dir <- file.path(out_root, run_id)
log_dir <- file.path(run_dir, "logs")
dir.create(log_dir, showWarnings = FALSE, recursive = TRUE)

log_file <- file.path(log_dir, "tximport.log")

# Open a single connection and use it for both output + messages
log_con <- file(log_file, open = "wt")  # or "at" to append
sink(log_con, split = TRUE)
sink(log_con, type = "message")

on.exit({
  sink(type = "message")
  sink()
  close(log_con)
}, add = TRUE)

########################################
# Input validation
########################################
if (!dir.exists(salmon_dir)) stop(paste0("ERROR: salmon_dir not found: ", salmon_dir), call. = FALSE)
if (!file.exists(tx2gene_path)) stop(paste0("ERROR: tx2gene not found: ", tx2gene_path), call. = FALSE)

# Determine samples
samples <- character()

if (!is.null(samples_txt)) {
  if (!file.exists(samples_txt)) stop(paste0("ERROR: samples_txt not found: ", samples_txt), call. = FALSE)
  samples <- readLines(samples_txt, warn = FALSE)
  samples <- samples[nzchar(samples)]
} else {
  # Discover samples by scanning salmon_dir/*/quant.sf
  qfiles <- list.files(salmon_dir, pattern = "^quant\\.sf$", recursive = TRUE, full.names = TRUE)
  # keep only immediate child dirs: salmon_dir/<sample>/quant.sf
  qfiles <- qfiles[dirname(qfiles) != salmon_dir]
  samples <- basename(dirname(qfiles))
  samples <- sort(unique(samples))
}

if (length(samples) == 0) stop("ERROR: no samples found (empty samples list and/or no quant.sf discovered).", call. = FALSE)

cat("num_samples=", length(samples), "\n", sep = "")
cat("samples=", paste(samples, collapse = ","), "\n", sep = "")
cat("\n")

files <- file.path(salmon_dir, samples, "quant.sf")
names(files) <- samples

missing <- files[!file.exists(files)]
if (length(missing) > 0) {
  cat("ERROR: Missing quant.sf for:\n")
  cat(paste0("  ", names(missing), " -> ", missing), sep = "\n")
  cat("\n")
  stop("ERROR: One or more quant.sf files are missing.", call. = FALSE)
}

# Ensure non-empty quant.sf
empty <- files[file.info(files)$size <= 0]
if (length(empty) > 0) {
  cat("ERROR: Empty quant.sf for:\n")
  cat(paste0("  ", names(empty), " -> ", empty), sep = "\n")
  cat("\n")
  stop("ERROR: One or more quant.sf files are empty.", call. = FALSE)
}

########################################
# Dry run
########################################
if (dry_run) {
  cat("[DRY RUN] Would run tximport on ", length(files), " samples.\n", sep = "")
  cat("[DRY RUN] Would write outputs under: ", run_dir, "\n", sep = "")
  quit(status = 0, save = "no")
}

########################################
# Load tx2gene
########################################
tx2gene <- read_tsv(
  tx2gene_path,
  col_names = FALSE,
  show_col_types = FALSE,
  progress = FALSE
)

if (ncol(tx2gene) < 2) stop("ERROR: tx2gene must have at least 2 columns (TXNAME, GENEID).", call. = FALSE)
tx2gene <- tx2gene[, 1:2]
colnames(tx2gene) <- c("TXNAME", "GENEID")

# Strip transcript version suffix (e.g., ENST00000335137.4 -> ENST00000335137)
tx2gene$TXNAME <- sub("\\.[0-9]+$", "", tx2gene$TXNAME)

if (nrow(tx2gene) == 0) stop("ERROR: tx2gene has 0 rows.", call. = FALSE)

cat("tx2gene rows=", nrow(tx2gene), "\n", sep = "")
cat("\n")

########################################
# Run tximport
########################################
cat("Running tximport...\n")
txi <- tximport(
  files,
  type = "salmon",
  tx2gene = tx2gene,
  ignoreTxVersion = ignore_tx_version,
  dropInfReps = drop_inf_reps,
  countsFromAbundance = if (is.na(counts_from_abundance)) NULL else counts_from_abundance
)

if (is.null(txi$counts) || nrow(txi$counts) == 0) stop("ERROR: tximport produced empty counts matrix.", call. = FALSE)

########################################
# Write outputs
########################################
dir.create(run_dir, showWarnings = FALSE, recursive = TRUE)

counts_path <- file.path(run_dir, "gene_counts.csv")
tpm_path    <- file.path(run_dir, "gene_tpm.csv")

write.csv(txi$counts, counts_path, quote = FALSE)
if (!is.null(txi$abundance)) {
  write.csv(txi$abundance, tpm_path, quote = FALSE)
}

# run_info
run_info <- file.path(run_dir, "run_info.txt")
cat(
  paste0(
    "tximport run completed on ", format(Sys.time()), "\n",
    "salmon_dir: ", salmon_dir, "\n",
    "tx2gene: ", tx2gene_path, "\n",
    "samples detected: ", length(samples), "\n",
    "ignoreTxVersion: ", ignore_tx_version, "\n",
    "dropInfReps: ", drop_inf_reps, "\n",
    "countsFromAbundance: ", ifelse(is.na(counts_from_abundance), "<disabled>", counts_from_abundance), "\n",
    "outputs:\n",
    "  ", counts_path, "\n",
    if (file.exists(tpm_path)) paste0("  ", tpm_path, "\n") else ""
  ),
  file = run_info
)

cat("Wrote:\n")
cat("  ", counts_path, "\n", sep = "")
if (file.exists(tpm_path)) cat("  ", tpm_path, "\n", sep = "")
cat("  ", run_info, "\n", sep = "")
cat("DONE\n")
cat(format(Sys.time()), "\n")
