#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

suppressPackageStartupMessages({
  library(SingleCellExperiment)
  library(limma)
})

args_full <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args_full[grep(file_arg, args_full)])

if (length(script_path) == 0) {
  stop("Unable to resolve script path from commandArgs().")
}

script_path <- normalizePath(script_path[1])
script_dir <- dirname(script_path)
pipeline_root <- normalizePath(file.path(script_dir, "..", ".."))

repro_helpers <- file.path(pipeline_root, "scripts", "utils", "reproducibility_helpers.R")
if (!file.exists(repro_helpers)) {
  stop("Could not find reproducibility helpers: ", repro_helpers)
}

source(repro_helpers)

initialize_pipeline_seed()
write_stage_session_info("42_differential_starsolo")

infile <- "analysis/objects/pbmc1k_starsolo_annotated_sce.rds"
out_file <- "analysis/markers/pbmc1k_starsolo_Bcells_vs_Tcells_DE.tsv"

infile <- "analysis/objects/pbmc1k_starsolo_annotated_sce.rds"
out_file <- "analysis/markers/pbmc1k_starsolo_Bcells_vs_Tcells_DE.tsv"

sce <- readRDS(infile)

if (!"cell_type_label" %in% colnames(colData(sce))) {
  stop("cell_type_label not found in colData.")
}

labels <- as.character(colData(sce)$cell_type_label)

group <- ifelse(
  labels == "B cells", "B_cells",
  ifelse(labels == "T cells", "T_cells", NA)
)

keep_cells <- !is.na(group)
sce_sub <- sce[, keep_cells]
group <- factor(group[keep_cells], levels = c("T_cells", "B_cells"))

cat("Group counts:\n")
print(table(group))

expr <- as.matrix(logcounts(sce_sub))

design <- model.matrix(~ group)
fit <- lmFit(expr, design)
fit <- eBayes(fit)

res <- topTable(
  fit,
  coef = "groupB_cells",
  number = Inf,
  sort.by = "P"
)

res$feature_id <- rownames(res)
res$gene_id <- rowData(sce_sub)$gene_id[match(res$feature_id, rownames(sce_sub))]
res$gene_name <- rowData(sce_sub)$gene_name[match(res$feature_id, rownames(sce_sub))]

res <- res[, c("feature_id", "gene_id", "gene_name",
               setdiff(colnames(res), c("feature_id", "gene_id", "gene_name")))]

write.table(
  res,
  file = out_file,
  sep = "\t",
  quote = FALSE,
  row.names = FALSE
)

cat("Wrote:", out_file, "\n\n")

cat("Top DE genes preview:\n")
print(head(res[, c("gene_name", "logFC", "AveExpr", "P.Value", "adj.P.Val")], 20))
