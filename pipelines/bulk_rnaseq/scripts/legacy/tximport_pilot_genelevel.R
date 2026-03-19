.libPaths("~/R/x86_64-pc-linux-gnu-library/4.1")

suppressPackageStartupMessages({
  library(tximport)
  library(readr)
})

samples <- readLines("results/run_info/pilot_samples.txt")

files <- file.path("results/salmon", samples, "quant.sf")
names(files) <- samples

tx2gene <- read_tsv("~/refs/gencode_grch38/tx2gene.noversion.tsv",
                    col_names = c("TXNAME","GENEID"))

txi <- tximport(files,
                type = "salmon",
                tx2gene = tx2gene,
                ignoreTxVersion = TRUE,
		dropInfReps = TRUE)

dir.create("results/quant", showWarnings = FALSE, recursive = TRUE)
write.csv(txi$counts,    "results/quant/gene_counts_pilot.csv")
write.csv(txi$abundance, "results/quant/gene_tpm_pilot.csv")
