#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

suppressPackageStartupMessages({
  library(fgsea)
  library(msigdbr)
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
write_stage_session_info("43_pathway_enrichment_starsolo")

infile <- "analysis/markers/pbmc1k_starsolo_Bcells_vs_Tcells_DE.tsv"
out_hallmark <- "analysis/markers/pbmc1k_starsolo_Bcells_vs_Tcells_Hallmark_fgsea.tsv"
out_reactome <- "analysis/markers/pbmc1k_starsolo_Bcells_vs_Tcells_Reactome_fgsea.tsv"

de <- read.delim(infile, check.names = FALSE)

required_cols <- c("gene_name", "t")
missing_cols <- setdiff(required_cols, colnames(de))
if (length(missing_cols) > 0) {
  stop("Missing required column(s) in DE table: ", paste(missing_cols, collapse = ", "))
}

de <- de[!is.na(de$gene_name) & de$gene_name != "", ]
de <- de[!is.na(de$t), ]

de <- de[order(abs(de$t), decreasing = TRUE), ]
de <- de[!duplicated(de$gene_name), ]

ranks <- de$t
names(ranks) <- de$gene_name
ranks <- sort(ranks, decreasing = TRUE)

cat("Ranked genes:", length(ranks), "\n")

run_fgsea_collection <- function(pathway_df, outfile, label) {
  pathways <- split(pathway_df$gene_symbol, pathway_df$gs_name)

  cat("\nRunning", label, "fgsea on", length(pathways), "pathways\n")

  fg <- fgsea(
    pathways = pathways,
    stats = ranks,
    minSize = 10,
    maxSize = 500
  )

  fg <- as.data.frame(fg)
  fg <- fg[order(fg$padj, -abs(fg$NES)), ]

  if ("leadingEdge" %in% colnames(fg)) {
    fg$leadingEdge <- vapply(
      fg$leadingEdge,
      function(x) paste(x, collapse = ";"),
      character(1)
    )
  }

  write.table(
    fg,
    file = outfile,
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
  )

  cat("Wrote:", outfile, "\n")
  cat("\nTop", label, "pathways:\n")
  print(fg[, c("pathway", "NES", "pval", "padj", "size")][1:min(15, nrow(fg)), ])

  invisible(fg)
}

hallmark_df <- msigdbr(
  species = "Homo sapiens",
  collection = "H"
)

reactome_df <- msigdbr(
  species = "Homo sapiens",
  collection = "C2",
  subcollection = "CP:REACTOME"
)

hallmark_res <- run_fgsea_collection(hallmark_df, out_hallmark, "Hallmark")
reactome_res <- run_fgsea_collection(reactome_df, out_reactome, "Reactome")

cat("\nDone.\n")
