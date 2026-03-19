#!/usr/bin/env Rscript

dirs <- c(
  "analysis/figures/qc/cellranger",
  "analysis/figures/qc/starsolo",
  "analysis/figures/downstream/cellranger",
  "analysis/figures/downstream/starsolo",
  "analysis/figures/downstream/comparison"
)

files <- unlist(lapply(dirs, function(d) {
  if (dir.exists(d)) {
    list.files(d, pattern = "\\.png$", full.names = TRUE)
  } else {
    character(0)
  }
}))

files <- sort(files)

if (length(files) == 0) {
  stop("No PNG files found to include in report.")
}

out_pdf <- "analysis/figures/scRNAseq_pilot_visualization_report.pdf"
dir.create(dirname(out_pdf), recursive = TRUE, showWarnings = FALSE)

pdf(out_pdf, width = 11, height = 8.5)

for (f in files) {
  img <- png::readPNG(f)
  grid::grid.newpage()
  title_txt <- gsub("^\\./", "", f)
  grid::grid.text(title_txt, x = 0.02, y = 0.98, just = c("left", "top"),
                  gp = grid::gpar(fontsize = 12))
  grid::grid.raster(img, x = 0.5, y = 0.46, width = 0.95, height = 0.85)
}

dev.off()

message("Visualization report written to: ", out_pdf)
