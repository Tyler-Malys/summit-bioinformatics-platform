# PBMC 1k scRNA-seq QC validation notes

## Inputs evaluated
- Cell Ranger raw matrix
- STARsolo raw matrix

## Core outputs generated
- SCE objects from raw matrices
- Per-barcode QC metrics
- Barcode-rank plots
- emptyDrops results
- emptyDrops-filtered SCE objects
- Low-quality-filtered SCE objects
- Backend QC summary table

## Results summary

| backend | raw_barcodes | emptydrops_retained | lowq_retained | lowq_removed |
|---|---:|---:|---:|---:|
| cellranger | 329735 | 1202 | 1180 | 22 |
| starsolo | 481442 | 1259 | 1123 | 136 |

## Shared low-quality thresholds used
- min_counts = 500
- min_genes = 200
- max_pct_mito = 20

## Observations
- STARsolo emitted more raw barcodes than Cell Ranger.
- emptyDrops converged both backends to ~1.2k candidate cells.
- Under shared thresholds, STARsolo lost more cells during low-quality filtering.
- Major contributor to STARsolo removals was elevated mitochondrial percentage.

## Remaining work
- Implement doublet detection/removal
- Add richer QC plots (counts, genes, mito distributions)
- Decide whether backend-specific QC thresholds are needed
- Apply the finalized framework to Delcath production samples
