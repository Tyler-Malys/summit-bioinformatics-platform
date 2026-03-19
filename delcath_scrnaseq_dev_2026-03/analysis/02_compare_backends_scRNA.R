#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (length(idx) == 0) return(default)
  if (idx == length(args)) stop(paste("Missing value after", flag))
  args[idx + 1]
}

run_id <- get_arg("--run_id", default = NA_character_)
if (is.na(run_id)) stop("Provide --run_id")

repo_root <- get_arg("--repo_root", default = ".")
out_base  <- get_arg("--out_base", default = "results/validation")

repo_root <- normalizePath(repo_root, winslash = "/", mustWork = TRUE)

s1 <- file.path(repo_root, out_base, run_id, "starsolo", "counts_summary.csv")
s2 <- file.path(repo_root, out_base, run_id, "cellranger", "counts_summary.csv")

if (!file.exists(s1)) stop(paste("Missing:", s1))
if (!file.exists(s2)) stop(paste("Missing:", s2))

a <- read.csv(s1, stringsAsFactors = FALSE)
b <- read.csv(s2, stringsAsFactors = FALSE)

cmp <- rbind(a, b)

# add deltas (cellranger - starsolo) in one row
delta <- data.frame(
  run_id = run_id,
  backend = "delta_cellranger_minus_starsolo",
  matrix = a$matrix[1],
  n_cells = b$n_cells[1] - a$n_cells[1],
  n_genes = b$n_genes[1] - a$n_genes[1],
  total_umis = b$total_umis[1] - a$total_umis[1],
  median_umis_per_cell = b$median_umis_per_cell[1] - a$median_umis_per_cell[1],
  median_genes_per_cell = b$median_genes_per_cell[1] - a$median_genes_per_cell[1],
  median_percent_mt = b$median_percent_mt[1] - a$median_percent_mt[1],
  stringsAsFactors = FALSE
)

cmp2 <- rbind(cmp, delta)

out_dir <- file.path(repo_root, out_base, run_id)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

out_file <- file.path(out_dir, "backend_comparison_summary.csv")
write.csv(cmp2, out_file, row.names = FALSE)

cat("OK\n")
cat("Wrote: ", out_file, "\n", sep = "")
