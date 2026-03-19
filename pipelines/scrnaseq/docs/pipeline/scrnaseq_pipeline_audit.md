# scRNA-seq Pipeline Audit — Phase 3 Hardening

Date: 2026-03-18

---

## Script Inventory and Audit Status

### Orchestration / entry-point layer
- [x] scripts/run_scrnaseq_wrapper.sh
- [x] scripts/starsolo/run_starsolo_from_manifest.sh
- [x] scripts/starsolo/run_starsolo_one_sample.sh
- [x] scripts/cellranger/run_cellranger_count_one_sample.sh
- [x] scripts/run_cellranger_from_manifest.sh

### QC processing layer
- [x] scripts/qc/01_build_sce_object.R
- [x] scripts/qc/02_compute_qc_metrics.R
- [x] scripts/qc/03_barcode_rank_plot.R
- [x] scripts/qc/04_run_emptydrops.R
- [x] scripts/qc/05_apply_emptydrops_filter.R
- [x] scripts/qc/06_filter_low_quality_cells.R
- [x] scripts/qc/07_run_scdblfinder.R
- [x] scripts/qc/08_remove_doublets.R
- [x] scripts/qc/09_plot_qc_metrics.R

### Downstream analysis layer
- [x] scripts/downstream/10_normalize_hvg.R
- [x] scripts/downstream/20_run_pca.R
- [x] scripts/downstream/21_assess_pc_covariates.R
- [x] scripts/downstream/22_regress_covariates_and_rerun_pca.R
- [x] scripts/downstream/23_merge_pca_variants.R
- [x] scripts/downstream/24_assess_any_reduceddim_covariates.R
- [x] scripts/downstream/30_build_knn_graphs.R
- [x] scripts/downstream/31_cluster_knn_graphs.R
- [x] scripts/downstream/32_run_umap.R
- [x] scripts/downstream/33_run_tsne.R
- [x] scripts/downstream/34_cluster_stability.R
- [x] scripts/downstream/40_find_markers_cellranger.R
- [x] scripts/downstream/40_find_markers_starsolo.R
- [x] scripts/downstream/41_annotate_celltypes_cellranger.R
- [x] scripts/downstream/41_annotate_celltypes_starsolo.R
- [x] scripts/downstream/42_differential_cellranger.R
- [x] scripts/downstream/42_differential_starsolo.R
- [x] scripts/downstream/43_pathway_enrichment_cellranger.R
- [x] scripts/downstream/43_pathway_enrichment_starsolo.R
- [x] scripts/downstream/50_export_visualizations.R
- [x] scripts/downstream/51_compile_visualization_report.R

### Additional analysis / comparison scripts
- [x] analysis/01_load_counts_scRNA.R
- [x] analysis/02_compare_backends_scRNA.R

### Config reviewed
- [x] config/project.env

### Not primary audit targets for processing logic
- README.md
- VERSION
- docs/
- logs/
- results/
- runs/
- raw/
- data/
- ref/
- validation/
- qc/
- metadata/
- pbmc_1k_v3_GRCh38g49/

---

## File
scripts/run_scrnaseq_wrapper.sh

## Role
Transitional top-level scRNA-seq wrapper.

## What it does
- Loads env-style config file
- Selects engine (cellranger or starsolo)
- Resolves manifest path
- Creates canonical run directory structure
- Captures run metadata and software versions
- Validates required tools and references
- Dispatches per-sample execution by engine

## Hard-coded / assumed behavior
- Default config path: config/project.env
- Default engine: cellranger
- Supported engines:
  - cellranger
  - starsolo
- Default manifests:
  - metadata/cellranger_runs.tsv
  - metadata/starsolo_runs.tsv
- Run ID format:
  - scrna_<engine>_<timestamp>
- Canonical run directories:
  - input/
  - working/
  - logs/
  - qc/
  - outputs/
  - downstream/
  - final/
  - run_metadata/
- Required config variables:
  - PROJECT_ROOT
  - THREADS
  - REF_ROOT
  - STAR_INDEX
  - CELLRANGER_REF

## Engine-specific assumptions

### Cell Ranger
- Manifest columns:
  - sample_run_id sample_id dataset fastq_path reference chemistry expected_cells notes
- Uses:
  - sample_run_id
  - sample_id
  - fastq_path
- Ignores:
  - dataset
  - reference
  - chemistry
  - expected_cells
  - notes
- Hard-coded:
  - --localmem=64

### STARsolo
- Manifest columns:
  - sample_run_id fastq_dir sample_id chemistry
- Supported chemistry:
  - 10xv2
  - 10xv3
- Chemistry mapping:
  - 10xv2 → CB 16, UMI 10
  - 10xv3 → CB 16, UMI 12
- FASTQ naming:
  - *_R1_*.fastq.gz / *_R2_*.fastq.gz
  - fallback *_1.fastq.gz / *_2.fastq.gz
- Hard-coded parameters:
  - --soloType CB_UMI_Simple
  - --soloCBwhitelist None
  - --soloFeatures Gene
  - --soloCellFilter EmptyDrops_CR
  - --soloUMIdedup 1MM_CR
  - --soloUMIfiltering MultiGeneUMI_CR

## Strengths
- Strict bash mode
- Canonical run directory structure
- Config + manifest snapshotting
- Git + software version capture
- Tool/reference validation
- Structured logging

## Issues / refactor notes
- PROJECT_ROOT duplicated (script + config)
- Manifest copied before validation
- FASTQ handling inconsistent across engines
- Manifest schemas differ by engine
- Cell Ranger memory hard-coded
- STARsolo chemistry logic embedded
- No failure-status capture

## Config candidates
- THREADS
- RUNS_ROOT
- STAR_INDEX
- CELLRANGER_REF
- Cell Ranger memory
- manifest path
- engine selection

## Fixed conventions
- env-based config
- run directory structure
- metadata capture
- logging structure
- engine set (cellranger, starsolo)

---

## File
scripts/starsolo/run_starsolo_from_manifest.sh

## Role
Legacy / direct STARsolo manifest runner.

## What it does
- Accepts manifest path argument, defaulting to metadata/starsolo_runs.tsv
- Resolves repo root from script location
- Hard-codes STAR index, output base, and log base relative to repo root
- Iterates through STARsolo manifest rows
- Resolves per-sample FASTQ directory, output directory, and log file
- Skips samples if expected STARsolo matrix output already exists
- Maps chemistry to barcode / UMI coordinates
- Discovers R1/R2 FASTQ files
- Runs STARsolo per sample

## Hard-coded / assumed behavior
- Default manifest path: metadata/starsolo_runs.tsv
- Repo root derived as parent of scripts/starsolo
- Hard-coded paths:
  - STAR_INDEX = <repo>/ref/star_index
  - OUT_BASE = <repo>/runs/starsolo
  - LOG_BASE = <repo>/logs/starsolo
- Manifest columns:
  - run_id fastq_dir sample_id chemistry
- FASTQ directory treated as repo-relative:
  - FASTQ_DIR = $REPO_ROOT/$fastq_dir
- Skip logic based on existence of either:
  - Solo.out/Gene/raw/matrix.mtx.gz
  - Solo.out/Gene/filtered/matrix.mtx.gz
- Supported chemistry:
  - 10xv2
  - 10xv3
- Chemistry mapping:
  - 10xv2 → CB 16, UMI 10
  - 10xv3 → CB 16, UMI 12
- FASTQ naming:
  - primary: *_R1_*.fastq.gz / *_R2_*.fastq.gz
  - fallback: *_1.fastq.gz / *_2.fastq.gz
- STAR threads hard-coded:
  - --runThreadN 16
- Hard-coded STARsolo parameters:
  - --outSAMtype BAM SortedByCoordinate
  - --soloType CB_UMI_Simple
  - --soloCBwhitelist None
  - --soloFeatures Gene
  - --soloCellFilter EmptyDrops_CR
  - --soloUMIdedup 1MM_CR
  - --soloUMIfiltering MultiGeneUMI_CR

## Strengths
- Uses strict bash mode
- Simple manifest-driven execution
- Includes skip-if-complete behavior
- Performs basic manifest, reference, and FASTQ validation
- Produces per-sample log files

## Issues / refactor notes
- Legacy direct runner duplicates logic now also present in top-level wrapper
- STAR index path is hard-coded instead of config-driven
- Output and log roots are hard-coded instead of run-structured
- FASTQ paths assumed repo-relative only
- sample_id is read from manifest but not used
- Threads hard-coded to 16
- Chemistry mapping embedded inline
- No metadata capture, config snapshot, git capture, or software version capture
- No canonical run directory / provenance model
- No failure trap or explicit final status tracking

## Config candidates
- manifest path
- STAR_INDEX
- output root
- log root
- threads
- chemistry mapping inputs (or centralized chemistry handling)

## Fixed conventions
- current STARsolo chemistry support limited to 10xv2 / 10xv3
- current FASTQ naming conventions
- current baseline STARsolo counting/filtering settings

---

## File
scripts/starsolo/run_starsolo_one_sample.sh

## Role
Legacy / direct one-sample STARsolo runner.

## What it does
- Sources config/project.env directly
- Accepts sample ID and FASTQ directory as positional arguments
- Creates result directory under results/starsolo/<sample_id>
- Defines inline STARsolo parameters for a presumed 10x-style layout
- Detects one R1 and one R2 FASTQ using *_1.fastq.gz / *_2.fastq.gz naming
- Runs STAR on one sample and writes a sample log

## Hard-coded / assumed behavior
- Config path hard-coded:
  - config/project.env
- Output path hard-coded:
  - ${PROJECT_ROOT}/results/starsolo/${SAMPLE_ID}
- Log path hard-coded:
  - ${PROJECT_ROOT}/logs/starsolo_${SAMPLE_ID}.log
- Assumes STAR_INDEX and THREADS are provided by sourced config
- Assumes 10x-style barcode/UMI structure:
  - --soloType CB_UMI_Simple
  - CB start 1, length 16
  - UMI start 17, length 12
  - --soloBarcodeReadLength 0
- Assumes read orientation:
  - R2 = cDNA
  - R1 = barcode / UMI
- FASTQ naming assumption:
  - *_1.fastq.gz
  - *_2.fastq.gz
- Only uses first matching R1 and first matching R2 file
- No manifest support
- No chemistry input argument

## Strengths
- Uses strict bash mode
- Simple single-sample smoke-test style execution
- Uses config for STAR index and threads
- Useful as an early development / validation runner

## Issues / refactor notes
- Legacy one-off runner, not suitable as canonical hardened entry point
- Hard-coded config path
- Hard-coded output and log locations
- No manifest or metadata capture
- No provenance / git / software version capture
- No chemistry abstraction; assumes one fixed 10x layout
- Only supports *_1/*_2 naming, not *_R1_*/ *_R2_*
- Only grabs first matching FASTQ pair, which is unsafe for multi-lane input
- No explicit validation of STAR availability or reference existence
- No skip/resume logic
- No structured failure-status capture

## Config candidates
- config path
- output root
- log root
- chemistry / barcode-UMI layout parameters
- FASTQ naming / discovery rules if ever needed

## Fixed conventions
- none recommended from this script as canonical, except the general assumption that STAR receives cDNA read first and barcode read second for supported 10x layouts

---

## File
scripts/cellranger/run_cellranger_count_one_sample.sh

## Role
Legacy / direct one-sample Cell Ranger runner.

## What it does
- Sources config/project.env directly
- Accepts sample ID and FASTQ directory as positional arguments
- Verifies cellranger is available on PATH
- Runs cellranger count for one sample
- Writes a sample log under the project logs directory

## Hard-coded / assumed behavior
- Config path hard-coded:
  - config/project.env
- Output root hard-coded:
  - ${PROJECT_ROOT}/results/cellranger
- Log path hard-coded:
  - ${PROJECT_ROOT}/logs/cellranger_${SAMPLE_ID}.log
- Assumes CELLRANGER_REF and THREADS are provided by sourced config
- Uses:
  - --sample="${SAMPLE_ID}"
- Hard-coded:
  - --localmem=64
- No manifest support
- No chemistry input handling
- No expected-cells handling
- No dataset/reference selection beyond global CELLRANGER_REF

## Strengths
- Uses strict bash mode
- Checks that cellranger is installed
- Uses config for reference path and threads
- Useful as a simple single-sample development runner

## Issues / refactor notes
- Legacy one-off runner, not suitable as canonical hardened entry point
- Hard-coded config path
- Hard-coded output and log locations
- No manifest or metadata capture
- No git/software version capture
- No skip/resume logic
- No structured failure-status capture
- Cell Ranger memory hard-coded
- Sample ID is reused as both run ID and sample filter value
- OUTROOT is created but script does not cd there or explicitly control Cell Ranger working location

## Config candidates
- config path
- output root
- log root
- Cell Ranger memory
- possibly expected-cells if needed later

## Fixed conventions
- none recommended from this script as canonical beyond basic single-sample execution intent

---

## File
scripts/run_cellranger_from_manifest.sh

## Role
Legacy / direct Cell Ranger manifest runner.

## What it does
- Uses a fixed Cell Ranger manifest
- Uses a fixed Cell Ranger executable path
- Resolves project root from script location
- Creates runs/cellranger_count as output root
- Iterates through manifest rows
- Skips samples if output directory already exists
- Runs cellranger count per sample

## Hard-coded / assumed behavior
- Manifest path hard-coded:
  - metadata/cellranger_runs.tsv
- Cell Ranger executable hard-coded:
  - ~/bioinformatics_tools/cellranger-10.0.0/cellranger
- Output root hard-coded:
  - ${PROJECT_ROOT}/runs/cellranger_count
- Manifest columns:
  - run_id sample_id dataset fastq_path reference chemistry expected_cells notes
- Header skip logic assumes first column header literal:
  - run_id
- Transcriptome path hard-coded by pattern:
  - ${PROJECT_ROOT}/data/refs/grch38_gencode_v49/${reference}
- Uses:
  - run_id
  - sample_id
  - fastq_path
  - reference
- Ignores:
  - dataset
  - chemistry
  - expected_cells
  - notes
- Hard-coded Cell Ranger arguments:
  - --create-bam=true
  - --localcores=8
  - --localmem=40
- Skip logic based only on output directory existence

## Strengths
- Simple manifest-driven execution
- Includes basic skip-if-output-directory-exists behavior
- Allows manifest-level reference subdirectory selection

## Issues / refactor notes
- No strict bash mode
- Legacy direct runner duplicates logic now also present in wrapper
- Manifest path hard-coded
- Cell Ranger executable path hard-coded to a user-specific install location
- Output root hard-coded and not aligned to canonical wrapper run structure
- No config sourcing
- No tool/reference/path validation before execution
- No metadata capture, config snapshot, git capture, or software version capture
- No structured logging beyond console output
- No per-sample log files
- Skip logic based only on directory existence is weak
- Chemistry and expected_cells are present in manifest but unused
- Cell Ranger memory and cores hard-coded

## Config candidates
- manifest path
- Cell Ranger executable path or PATH-based discovery
- output root
- transcriptome root / reference selection
- threads / cores
- memory
- create-bam setting if needed

## Fixed conventions
- none recommended from this script as canonical beyond the general use of a tab-delimited Cell Ranger manifest

---

## File
scripts/qc/01_build_sce_object.R

## Role
QC stage 01. Builds a SingleCellExperiment object from matrix-market count output.

## What it does
- Accepts four command-line arguments:
  - input_dir
  - sample_id
  - backend
  - output_file
- Expects matrix-market style count inputs in input_dir:
  - barcodes.tsv.gz or barcodes.tsv
  - features.tsv.gz or features.tsv
  - matrix.mtx.gz or matrix.mtx
- Reads counts with Matrix::readMM
- Reads barcodes and features with read.delim
- Verifies matrix dimensions match barcodes and features
- Sets rownames from feature gene names using make.unique
- Sets colnames from barcode values
- Builds rowData with:
  - gene_id
  - gene_name
  - feature_type
- Builds colData with:
  - barcode
- Creates SingleCellExperiment with counts assay
- Stores metadata:
  - sample_id
  - backend
  - matrix_type = basename(input_dir)
- Saves SCE object as RDS

## Hard-coded / assumed behavior
- Requires exactly 4 positional arguments
- Assumes matrix-market file naming conventions:
  - barcodes.tsv(.gz)
  - features.tsv(.gz)
  - matrix.mtx(.gz)
- Assumes features file has at least 3 columns:
  - V1 = gene_id
  - V2 = gene_name
  - V3 = feature_type
- Assumes gene names in features$V2 should be used as rownames
- Uses make.unique(features$V2) to resolve duplicate gene names
- Assumes barcode file first column contains cell barcode IDs
- Assumes input_dir basename is meaningful enough to store as matrix_type
- Assumes a single counts assay named counts
- No support here for alternate feature modes beyond what is already present in features.tsv

## Strengths
- Clear single-purpose script
- Performs file existence and dimension checks
- Supports both gzipped and uncompressed matrix-market files
- Produces a standard SingleCellExperiment object for downstream QC
- Captures sample_id and backend in metadata

## Issues / refactor notes
- No explicit creation of parent directory for output_file
- Minimal validation of backend value
- Assumes features$V2 is always the preferred row identifier
- Assumes features$V3 exists; may fail on nonstandard feature files
- No logging/provenance beyond console messages
- No capture of source input paths in metadata beyond matrix_type basename
- No support for adding sample_id into colData directly, only metadata
- No multi-sample merge logic; single-sample object only

## Config candidates
- none immediate at script level; this script is mostly argument-driven
- input_dir and output_file should remain wrapper-supplied
- possible future policy choice:
  - whether to use gene_id or gene_name as rownames

## Fixed conventions
- SingleCellExperiment as the core QC object
- counts assay name = counts
- matrix-market input contract
- rowData fields:
  - gene_id
  - gene_name
  - feature_type
- colData field:
  - barcode

---

## File
scripts/qc/02_compute_qc_metrics.R

## Role
QC stage 02. Computes per-cell (barcode-level) QC metrics and augments the SCE object.

## What it does
- Accepts four arguments:
  - input_sce_rds
  - species
  - output_sce_rds
  - output_qc_tsv
- Loads SingleCellExperiment object
- Extracts counts assay
- Computes per-cell metrics:
  - total_counts (library size)
  - detected_genes (non-zero features)
  - mito_counts
  - pct_mito
- Identifies mitochondrial genes based on species:
  - human → "^MT-"
  - mouse → "^mt-"
- Adds QC metrics to colData(sce)
- Writes:
  - updated SCE (RDS)
  - QC table (TSV)

## Hard-coded / assumed behavior
- Requires exactly 4 positional arguments
- Assumes counts assay exists and is named "counts"
- Assumes rowData(sce)$gene_name exists
- Species must be one of:
  - human
  - mouse
- Mitochondrial gene detection:
  - human → prefix "MT-"
  - mouse → prefix "mt-"
- QC metrics computed:
  - total_counts = colSums(counts)
  - detected_genes = colSums(counts > 0)
  - pct_mito = 100 * mito_counts / total_counts
- Output:
  - QC TSV always written
  - Updated SCE always written

## Strengths
- Clear, focused QC metric computation step
- Adds metrics directly into colData for downstream use
- Writes both machine-readable (RDS) and human-readable (TSV) outputs
- Handles zero-count edge case in pct_mito calculation
- Creates output directories if missing

## Issues / refactor notes
- Species handling is hard-coded and limited to human/mouse
- Mito gene detection depends on naming convention in gene_name
- No support for alternate mitochondrial naming schemes
- No ribosomal or other QC feature categories computed
- No parameterization of QC metric definitions
- No logging/provenance capture beyond console messages
- No validation that gene_name field exists before use
- Does not store species in metadata for downstream reference

## Config candidates
- species (should be passed from config or manifest)
- mitochondrial gene prefix pattern (if expanded later)

## Fixed conventions
- QC metrics set:
  - total_counts
  - detected_genes
  - mito_counts
  - pct_mito
- counts assay name = counts
- QC metrics stored in colData
- TSV export format for QC summary

---

## File
scripts/qc/03_barcode_rank_plot.R

## Role
QC stage 03. Generates a barcode rank plot from QC metrics.

## What it does
- Accepts two arguments:
  - qc_metrics_tsv
  - output_png
- Reads QC metrics table
- Extracts total_counts per barcode
- Filters to positive counts only
- Sorts counts in descending order
- Computes rank for each barcode
- Plots rank vs counts on log-log scale
- Saves plot as PNG

## Hard-coded / assumed behavior
- Requires exactly 2 positional arguments
- Assumes QC TSV contains column:
  - total_counts
- Filters out all zero-count barcodes
- Uses descending sort of counts to define rank
- Plot characteristics fixed:
  - log10 x-axis (rank)
  - log10 y-axis (counts)
  - line plot
  - theme_bw()
  - fixed labels:
    - "Barcode Rank Plot"
    - "Barcode Rank"
    - "Total UMI Counts"
- Output size fixed:
  - width = 6
  - height = 5

## Strengths
- Simple and standard implementation of barcode rank plot
- Uses QC output from previous stage cleanly
- Handles edge case where no positive counts exist
- Produces visualization useful for cell-calling assessment

## Issues / refactor notes
- No validation that total_counts column exists
- Drops zero-count barcodes without reporting count removed
- No configurable plot parameters (labels, scales, size)
- No option to overlay knee/inflection point
- No logging/provenance capture
- No directory creation for output_png path

## Config candidates
- none required for current hardening phase
- possible future:
  - plot dimensions
  - output format
  - additional annotations (knee point)

## Fixed conventions
- barcode rank plot based on total_counts
- log-log scaling
- sorted descending rank definition
- PNG output format

---

## File
scripts/qc/04_run_emptydrops.R

## Role
QC stage 04. Performs empty droplet detection using DropletUtils::emptyDrops.

## What it does
- Accepts four arguments:
  - input_sce_rds
  - lower (UMI threshold for testing)
  - output_tsv
  - fdr_threshold
- Loads SingleCellExperiment object
- Extracts counts assay
- Runs emptyDrops on count matrix
- Converts result to data frame
- Adds:
  - barcode column
  - retain_fdr flag (FDR <= threshold)
- Writes full emptyDrops result table to TSV

## Hard-coded / assumed behavior
- Requires exactly 4 positional arguments
- Assumes counts assay exists and is named "counts"
- Uses DropletUtils::emptyDrops with only:
  - lower parameter supplied
- Random seed fixed:
  - set.seed(123)
- FDR-based retention rule:
  - retain_fdr = FDR <= fdr_threshold
- Retains all rows in output, including NA FDR values
- Output column order forces barcode first
- No modification of SCE object (output is TSV only)

## Strengths
- Uses standard and widely accepted emptyDrops method
- Explicitly exposes key parameters:
  - lower
  - fdr_threshold
- Produces full result table for transparency
- Adds clear retain_fdr flag for downstream filtering
- Reproducible due to fixed random seed

## Issues / refactor notes
- No validation that lower and fdr_threshold are sensible values
- Seed is hard-coded and not configurable
- No direct integration with SCE object (filtering handled in later step)
- No logging/provenance capture beyond console output
- No capture of parameters (lower, fdr_threshold) in output metadata
- No support for alternative cell-calling methods
- Assumes input is raw (unfiltered) matrix

## Config candidates
- lower (important QC parameter)
- fdr_threshold (important QC parameter)
- possibly random seed if reproducibility control needed

## Fixed conventions
- use of emptyDrops for droplet-based cell calling
- FDR-based retention rule
- TSV output of full emptyDrops results

---

## File
scripts/qc/05_apply_emptydrops_filter.R

## Role
QC stage 05. Applies emptyDrops filtering to retain high-confidence cell barcodes.

## What it does
- Accepts three arguments:
  - input_sce_rds
  - emptydrops_tsv
  - output_sce_rds
- Loads SCE object
- Loads emptyDrops results table
- Verifies barcode order matches between SCE and emptyDrops output
- Extracts retain_fdr logical vector
- Filters SCE columns (cells) using retain_fdr
- Saves filtered SCE object

## Hard-coded / assumed behavior
- Requires exactly 3 positional arguments
- Assumes emptyDrops TSV contains columns:
  - barcode
  - retain_fdr
- Assumes barcode order in emptyDrops TSV exactly matches colnames(sce)
- Uses retain_fdr directly as logical filter
- Assumes one-to-one alignment between TSV rows and SCE columns
- No reordering or joining logic; strict positional matching only

## Strengths
- Clear separation of statistical test (04) and filtering step (05)
- Enforces strict barcode alignment, preventing silent mismatches
- Simple and deterministic filtering behavior
- Creates output directory if needed

## Issues / refactor notes
- Strict requirement that barcode order matches exactly is brittle
- No support for joining on barcode if ordering differs
- No handling of NA values in retain_fdr (implicitly dropped)
- No storage of filtering decision in colData (only applied)
- No logging/provenance capture beyond console output
- No summary written to file (only console messages)

## Config candidates
- none at script level; depends entirely on upstream emptyDrops output

## Fixed conventions
- filtering based on retain_fdr from emptyDrops
- SCE column subsetting as filtering mechanism

---

## File
scripts/qc/06_filter_low_quality_cells.R

## Role
QC stage 06. Applies threshold-based filtering to remove low-quality cells.

## What it does
- Accepts six arguments:
  - input_sce_rds
  - min_counts
  - min_genes
  - max_pct_mito
  - output_sce_rds
  - output_tsv
- Loads SCE object
- Extracts QC metrics from colData:
  - total_counts
  - detected_genes
  - pct_mito
- Computes logical filter:
  - total_counts >= min_counts
  - detected_genes >= min_genes
  - pct_mito <= max_pct_mito
- Creates filter summary table
- Subsets SCE to retained cells
- Writes:
  - filtered SCE (RDS)
  - filter summary TSV

## Hard-coded / assumed behavior
- Requires exactly 6 positional arguments
- Assumes QC metrics already exist in colData:
  - total_counts
  - detected_genes
  - pct_mito
- Filtering criteria fixed to:
  - minimum counts
  - minimum detected genes
  - maximum mitochondrial percentage
- Logical filter is strict AND across all criteria
- Output TSV always includes:
  - barcode
  - total_counts
  - detected_genes
  - pct_mito
  - keep_lowq_filter

## Strengths
- Clear and standard QC filtering step
- Thresholds fully parameterized via arguments
- Produces both filtered object and full audit table
- Explicit reporting of retained vs removed cells
- Creates output directories if needed

## Issues / refactor notes
- No validation that required QC fields exist before use
- No support for additional QC metrics (e.g., ribosomal %, doublet score)
- No storage of filter decisions in colData (only written to TSV)
- No logging/provenance capture beyond console messages
- No handling of NA values in QC metrics
- Threshold logic fixed (no percentile-based or adaptive filtering)

## Config candidates
- min_counts
- min_genes
- max_pct_mito

## Fixed conventions
- core QC thresholds:
  - library size (total_counts)
  - feature count (detected_genes)
  - mitochondrial fraction (pct_mito)
- filtering via SCE column subsetting
- TSV audit output for filtering decisions

---

## File
scripts/qc/07_run_scdblfinder.R

## Role
QC stage 07. Performs doublet detection using scDblFinder.

## What it does
- Accepts three arguments:
  - input_sce_rds
  - output_sce_rds
  - output_tsv
- Loads SCE object
- Runs scDblFinder on dataset
- Adds doublet annotations to colData:
  - scDblFinder.score
  - scDblFinder.class (singlet/doublet)
- Creates output table with:
  - barcode
  - score
  - class
- Writes:
  - updated SCE (RDS)
  - TSV summary of doublet calls

## Hard-coded / assumed behavior
- Requires exactly 3 positional arguments
- Uses scDblFinder with default parameters
- Random seed fixed:
  - set.seed(123)
- Assumes scDblFinder adds:
  - scDblFinder.score
  - scDblFinder.class to colData
- Output TSV always includes:
  - barcode
  - scDblFinder_score
  - scDblFinder_class

## Strengths
- Uses widely accepted doublet detection method
- Integrates results directly into SCE object
- Produces both machine-readable (RDS) and tabular output
- Clear reporting of singlet vs doublet counts
- Reproducible due to fixed seed

## Issues / refactor notes
- No parameterization of scDblFinder settings (e.g., expected doublet rate)
- Seed is hard-coded and not configurable
- No validation that required colData fields were added
- No downstream filtering (handled in next step)
- No logging/provenance capture beyond console output
- No storage of parameters used for doublet detection

## Config candidates
- none required for initial hardening
- possible future:
  - expected doublet rate
  - clustering parameters used by scDblFinder
  - random seed

## Fixed conventions
- use of scDblFinder for doublet detection
- storage of results in colData
- TSV export of score and class

---

## File
scripts/qc/08_remove_doublets.R

## Role
QC stage 08. Removes doublets identified by scDblFinder, retaining singlet cells.

## What it does
- Accepts three arguments:
  - input_sce_rds
  - output_sce_rds
  - output_tsv
- Loads SCE object
- Validates presence of scDblFinder.class in colData
- Extracts cell classification (singlet/doublet)
- Creates logical filter:
  - keep = (class == "singlet")
- Generates summary table with:
  - barcode
  - scDblFinder_class
  - keep_singlet
- Subsets SCE to singlet cells only
- Writes:
  - filtered SCE (RDS)
  - TSV summary of filtering decisions

## Hard-coded / assumed behavior
- Requires exactly 3 positional arguments
- Assumes scDblFinder.class exists in colData
- Assumes class values include:
  - "singlet"
  - "doublet"
- Filtering rule fixed:
  - retain only "singlet"
- No handling of unexpected class labels or NA values beyond implicit exclusion

## Strengths
- Clean separation between detection (07) and filtering (08)
- Explicit validation of required input field
- Produces both filtered object and audit table
- Clear reporting of retained vs removed cells
- Deterministic filtering behavior

## Issues / refactor notes
- No parameterization of filtering rule (always keeps singlets only)
- No handling of ambiguous or NA classifications
- No storage of filtering decision in colData (only written to TSV)
- No logging/provenance capture beyond console output
- No summary file beyond TSV (e.g., JSON/metadata)

## Config candidates
- none required for current hardening phase

## Fixed conventions
- doublet removal based on scDblFinder.class
- singlet-only retention
- SCE column subsetting for filtering
- TSV audit output of classification and retention

---

## File
scripts/qc/09_plot_qc_metrics.R

## Role
QC stage 09. Generates comprehensive QC visualization suite across all filtering stages.

## What it does
- Accepts seven arguments:
  - raw_qc_tsv
  - emptydrops_tsv
  - lowq_filter_tsv
  - scdblfinder_tsv
  - backend_name
  - sample_id
  - output_dir
- Loads QC tables from all prior stages
- Validates presence of barcode column across all inputs
- Generates multiple plots:

### 1. Barcode rank plot
- Based on raw_qc total_counts
- Log-log rank vs counts

### 2. EmptyDrops histogram
- total_counts distribution
- colored by retain_fdr

### 3. Low-quality filter distributions
- total_counts (log scale)
- detected_genes (log scale)
- pct_mito
- colored by keep_lowq_filter

### 4. Doublet detection plots
- scDblFinder score histogram
- class distribution barplot

### 5. QC stage summary
- raw barcodes
- emptyDrops retained
- low-quality retained
- singlets retained

- Saves all plots as PNG files with standardized naming

## Hard-coded / assumed behavior
- Requires exactly 7 positional arguments
- Assumes required columns exist:
  - raw_qc: total_counts
  - emptydrops: retain_fdr
  - lowq: keep_lowq_filter, total_counts, detected_genes, pct_mito
  - dbl: scDblFinder_score, scDblFinder_class
- Joins performed using barcode (inner_join for emptyDrops plot)
- Plot settings largely fixed:
  - theme_bw()
  - histogram bin counts fixed (60–100)
  - log10 scaling for counts/genes
- File naming convention fixed:
  - <sample_id>_<backend>_<plot_type>.png

## Strengths
- Centralized QC visualization across entire pipeline
- Integrates all QC stages into coherent visual report
- Consistent naming and structure of outputs
- Provides both distributional and summary-level diagnostics
- Useful for both debugging and reporting

## Issues / refactor notes
- No validation beyond barcode presence (other required columns assumed)
- No handling of mismatched barcodes across tables
- Plot parameters (bins, sizes, themes) not configurable
- No option to disable specific plots
- No report bundling (e.g., PDF or HTML summary)
- No logging/provenance capture beyond console messages
- Assumes all prior stages completed successfully

## Config candidates
- none required for initial hardening phase
- possible future:
  - plot dimensions
  - bin counts
  - output formats (PNG vs PDF)
  - plot inclusion/exclusion flags

## Fixed conventions
- QC visualization outputs as PNG files
- standardized naming using sample_id and backend
- core QC stages visualized:
  - raw
  - emptyDrops
  - low-quality filtering
  - doublet detection


---

## File
scripts/downstream/10_normalize_hvg.R

## Role
Downstream stage 10. Performs normalization and highly variable gene (HVG) selection.

## What it does
- Accepts arguments:
  - input_sce_rds
  - output_sce_rds
  - output_hvg_tsv
  - optional: top_n_hvgs (default = 2000)
- Loads SCE object
- Validates:
  - object is SingleCellExperiment
  - counts assay exists
- Performs normalization:
  - scuttle::logNormCounts → creates logcounts assay
- Models gene variance:
  - scran::modelGeneVar
- Ranks genes by biological variance (bio)
- Selects top N HVGs
- Stores HVG annotations in rowData:
  - hvg_bio
  - hvg_total
  - hvg_tech
  - is_hvg (logical flag)
- Writes:
  - full variance table (TSV)
  - updated SCE (RDS)

## Hard-coded / assumed behavior
- Requires ≥3 arguments, optional 4th for top_n_hvgs
- Default top_n_hvgs = 2000
- Assumes:
  - counts assay exists
  - modelGeneVar output contains "bio", "total", "tech"
- HVGs selected purely by:
  - descending biological variance (bio)
- Uses log-normalization (no alternative methods)
- No batch correction or blocking in variance modeling
- HVG flag stored directly in rowData

## Strengths
- Clean and standard normalization workflow (scuttle + scran)
- Strong validation of input structure
- Stores HVG annotations directly in SCE for downstream reuse
- Outputs full variance table for transparency
- Handles edge case where requested HVGs > gene count
- Clear step-wise logging

## Issues / refactor notes
- No support for batch-aware variance modeling (e.g., block argument)
- No alternative normalization methods (e.g., SCTransform)
- No parameterization of normalization method
- HVG selection strictly tied to "bio" metric
- No option for variance stabilization or filtering before HVG selection
- No logging/provenance capture beyond console output
- No storage of top_n_hvgs parameter in metadata

## Config candidates
- top_n_hvgs (important)
- possible future:
  - normalization method
  - variance modeling options (block, trend fitting)

## Fixed conventions
- normalization via logNormCounts
- variance modeling via modelGeneVar
- HVG selection based on biological variance
- HVG annotation stored in rowData
- TSV export of full variance table

---

## File
scripts/downstream/20_run_pca.R

## Role
Downstream stage 20. Performs PCA on normalized, HVG-filtered data.

## What it does
- Accepts arguments:
  - input_sce_rds
  - output_sce_rds
  - optional: n_pcs (default = 30)
- Loads SCE object
- Validates:
  - object is SingleCellExperiment
  - logcounts assay exists
  - rowData(sce)$is_hvg exists
- Subsets to HVGs
- Runs PCA:
  - BiocSingular::runPCA
  - centered and scaled
- Stores results:
  - reducedDim(sce, "PCA") → PC scores
  - metadata(sce)$pca:
    - percent_var
    - sdev
    - rotation (loadings)
    - hvg_gene_ids
    - n_hvgs_used
    - n_pcs
- Saves updated SCE

## Hard-coded / assumed behavior
- Requires ≥2 arguments, optional 3rd for n_pcs
- Default n_pcs = 30
- Assumes:
  - logcounts assay present
  - is_hvg flag exists in rowData
- PCA always run on:
  - HVG subset only
- PCA implementation:
  - ExactParam (deterministic SVD)
  - center = TRUE
  - scale = TRUE
- Random seed fixed:
  - set.seed(123)
- n_pcs bounded by:
  - number of HVGs
  - number of cells - 1

## Strengths
- Strong validation of upstream dependencies (normalization + HVG)
- Uses HVGs for dimensionality reduction (best practice)
- Stores rich PCA metadata for downstream use
- Handles edge cases for PC count safely
- Clean separation of PCA stage
- Deterministic due to ExactParam + seed

## Issues / refactor notes
- No support for alternative PCA backends (e.g., randomized SVD)
- No parameterization of scaling/centering behavior
- No batch correction or regression before PCA
- No option to use all genes vs HVGs
- Seed is hard-coded and not configurable
- No logging/provenance capture beyond console output
- PCA stored under fixed name "PCA" (no variant tracking)

## Config candidates
- n_pcs (important)
- possible future:
  - PCA method (exact vs approximate)
  - scaling/centering flags
  - HVG vs full matrix toggle

## Fixed conventions
- PCA computed on HVGs only
- results stored in reducedDim(sce, "PCA")
- metadata stored under metadata(sce)$pca

---

## File
scripts/downstream/21_assess_pc_covariates.R

## Role
Downstream stage 21. Assesses association between principal components and QC covariates.

## What it does
- Accepts arguments:
  - input_sce_rds
  - output_tsv
  - optional: n_pcs (default = 10)
- Loads SCE object
- Validates:
  - PCA exists in reducedDim(sce, "PCA")
  - required covariates exist in colData:
    - total_counts
    - detected_genes
    - pct_mito
- Extracts PCA coordinates
- Computes Pearson correlation between each PC and each covariate
- Calculates:
  - correlation coefficient
  - absolute correlation
  - p-value
  - number of cells used
- Adjusts p-values (Benjamini-Hochberg FDR)
- Outputs results table (TSV)
- Prints top associations to console

## Hard-coded / assumed behavior
- Requires ≥2 arguments, optional 3rd for n_pcs
- Default n_pcs = 10
- Covariates hard-coded to:
  - total_counts
  - detected_genes
  - pct_mito
- Correlation method fixed:
  - Pearson
- Requires ≥3 valid observations per test
- FDR correction method:
  - BH (Benjamini-Hochberg)
- Output sorted by:
  - PC index
  - covariate name

## Strengths
- Provides quantitative assessment of technical effects in PCs
- Includes both effect size (correlation) and statistical significance
- Handles missing/invalid values safely
- Outputs structured table suitable for downstream decision-making
- Includes FDR correction for multiple testing
- Useful for deciding whether regression is needed (next step)

## Issues / refactor notes
- Covariates are hard-coded (not configurable)
- No support for additional covariates (e.g., batch, donor, cell cycle)
- Pearson-only (no Spearman option)
- No visualization output (only TSV + console)
- No storage of results in SCE metadata
- No logging/provenance capture beyond console output
- No thresholding or flagging of problematic PCs

## Config candidates
- n_pcs (important)
- possible future:
  - list of covariates to test
  - correlation method (pearson/spearman)
  - significance thresholds

## Fixed conventions
- QC covariates tested:
  - total_counts
  - detected_genes
  - pct_mito
- PCA used from reducedDim(sce, "PCA")
- output as TSV with correlation statistics and FDR

---

## File
scripts/downstream/22_regress_covariates_and_rerun_pca.R

## Role
Downstream stage 22. Regresses out technical covariates and recomputes PCA.

## What it does
- Accepts arguments:
  - input_sce_rds
  - output_sce_rds
  - optional: n_pcs (default = 30)
- Loads SCE object
- Validates:
  - logcounts assay exists
  - rowData(sce)$is_hvg exists
  - required covariates exist:
    - total_counts
    - pct_mito
- Constructs regression design matrix:
  - log10(total_counts + 1)
  - pct_mito
- Extracts HVG logcounts
- Performs linear regression:
  - gene-by-gene regression using QR decomposition
- Computes residualized expression matrix
- Adds intercept back to preserve scale
- Runs PCA on residualized matrix
- Stores results:
  - reducedDim(sce, "PCA_regressed")
  - metadata(sce)$regressed_pca:
    - regressors
    - formula
    - HVG info
    - PCA outputs (variance, rotation, etc.)
- Saves updated SCE

## Hard-coded / assumed behavior
- Requires ≥2 arguments, optional 3rd for n_pcs
- Default n_pcs = 30
- Covariates fixed to:
  - log_total_counts
  - pct_mito
- Transformation:
  - log10(total_counts + 1)
- Regression method:
  - linear model via QR decomposition
- PCA:
  - ExactParam
  - centered and scaled
- Random seed fixed:
  - set.seed(123)
- Regression applied only to HVGs
- Output PCA stored as:
  - "PCA_regressed"

## Strengths
- Explicit removal of major technical covariates
- Clean separation between raw PCA and regressed PCA
- Efficient matrix-based regression implementation
- Stores full regression + PCA metadata
- Preserves interpretability by adding intercept back
- Follows best practice for technical noise correction

## Issues / refactor notes
- Covariates are hard-coded (not configurable)
- No support for additional covariates (e.g., batch, donor)
- No option to disable regression or choose method
- Assumes linear relationship between covariates and expression
- No validation of overfitting or variance loss
- No storage of residual matrix (only PCA output)
- No logging/provenance capture beyond console output

## Config candidates
- n_pcs (important)
- possible future:
  - list of covariates to regress
  - transformation functions (e.g., log base)
  - regression method (linear vs other)

## Fixed conventions
- regression covariates:
  - total_counts (log-transformed)
  - pct_mito
- regression applied to HVGs only
- PCA on residualized data stored as "PCA_regressed"
- metadata stored under metadata(sce)$regressed_pca

---

## File
scripts/downstream/23_merge_pca_variants.R

## Role
Downstream stage 23. Merges standard PCA and regressed PCA into a single SCE object.

## What it does
- Accepts arguments:
  - base_sce_with_PCA.rds
  - regressed_sce_with_PCA_regressed.rds
  - output_sce.rds
- Loads two SCE objects:
  - base (contains PCA)
  - regressed (contains PCA_regressed)
- Validates:
  - both are SingleCellExperiment objects
  - identical dimensions
  - identical gene and cell identifiers
  - presence of required reducedDims:
    - "PCA" in base
    - "PCA_regressed" in regressed
- Copies:
  - PCA_regressed from regressed → base object
  - metadata(sce)$regressed_pca
- Adds summary metadata:
  - presence of logcounts
  - HVG flags
  - number of HVGs
  - available reducedDims
- Saves merged SCE

## Hard-coded / assumed behavior
- Requires exactly 3 positional arguments
- Assumes:
  - base SCE contains PCA
  - regressed SCE contains PCA_regressed
- Requires strict identity:
  - rownames (genes)
  - colnames (cells)
- Metadata copied under:
  - metadata(sce)$regressed_pca
  - metadata(sce)$downstream_summary
- No merging of assays or other metadata beyond PCA components

## Strengths
- Clean separation of base vs regressed workflows
- Strict validation prevents silent mismatches
- Consolidates dimensionality reductions into a single object
- Adds useful summary metadata for downstream inspection
- Keeps pipeline modular while enabling unified output

## Issues / refactor notes
- No flexibility for mismatched but alignable datasets (strict identity only)
- No merging of other metadata fields beyond PCA
- No versioning of multiple PCA variants (fixed names only)
- No logging/provenance capture beyond console output
- No validation of consistency between PCA and PCA_regressed dimensions
- No option to overwrite or rename existing reducedDims

## Config candidates
- none required for current hardening phase

## Fixed conventions
- base PCA stored as "PCA"
- regressed PCA stored as "PCA_regressed"
- merged object retains both in reducedDims
- regression metadata stored under metadata(sce)$regressed_pca

---

## File
scripts/downstream/24_assess_any_reduceddim_covariates.R

## Role
Downstream stage 24. Generalized assessment of covariate associations for any reduced dimension (e.g., PCA, PCA_regressed, UMAP, tSNE).

## What it does
- Accepts arguments:
  - input_sce_rds
  - reduceddim_name
  - output_tsv
  - optional: n_dims (default = 10)
- Loads SCE object
- Validates:
  - specified reducedDim exists
  - required covariates exist:
    - total_counts
    - detected_genes
    - pct_mito
- Extracts reduced dimension matrix
- Computes Pearson correlation between each dimension and each covariate
- Calculates:
  - correlation
  - absolute correlation
  - p-value
  - number of cells used
- Applies FDR correction (BH)
- Outputs results as TSV
- Prints top associations to console

## Hard-coded / assumed behavior
- Requires ≥3 arguments, optional 4th for n_dims
- Default n_dims = 10
- Covariates fixed to:
  - total_counts
  - detected_genes
  - pct_mito
- Correlation method fixed:
  - Pearson
- Requires ≥3 valid observations per test
- FDR correction:
  - BH method
- Dimension naming:
  - uses column names if available
  - otherwise assigns "Dim1", "Dim2", etc.
- Output sorted by:
  - dimension index
  - covariate name

## Strengths
- Generalizes covariate assessment beyond PCA
- Reusable for multiple embeddings (PCA, PCA_regressed, UMAP, etc.)
- Robust handling of missing/invalid values
- Structured output suitable for downstream interpretation
- Includes FDR correction
- Dynamic dimension naming improves interpretability

## Issues / refactor notes
- Covariates are hard-coded (not configurable)
- No support for additional biological or batch covariates
- Pearson-only (no Spearman option)
- No visualization output
- No storage of results in SCE metadata
- No logging/provenance capture beyond console output
- No thresholding or automated flagging of problematic dimensions

## Config candidates
- n_dims (important)
- reduceddim_name (already parameterized)
- possible future:
  - covariate list
  - correlation method
  - thresholds for flagging

## Fixed conventions
- covariates tested:
  - total_counts
  - detected_genes
  - pct_mito
- works on any reducedDim(sce, <name>)
- output as TSV with correlation statistics and FDR

---

## File
scripts/downstream/30_build_knn_graphs.R

## Role
Downstream stage 30. Builds KNN graphs from standard and regressed PCA embeddings.

## What it does
- Accepts arguments:
  - input_sce_rds
  - output_sce_rds
  - optional: k (default = 20)
  - optional: n_pcs (default = 20)
- Loads SCE object
- Validates:
  - object is SingleCellExperiment
  - reducedDim(sce, "PCA") exists
  - reducedDim(sce, "PCA_regressed") exists
- Subsets both embeddings to first n_pcs dimensions
- Builds KNN graphs using scran::buildKNNGraph:
  - one from PCA
  - one from PCA_regressed
- Stores graph objects in metadata(sce)$graphs:
  - knn_pca
  - knn_pca_regressed
- Stores graph construction metadata in metadata(sce)$graph_build
- Saves updated SCE

## Hard-coded / assumed behavior
- Requires at least 2 positional arguments
- Default k = 20
- Default n_pcs = 20
- Requires both PCA variants to be present
- Graph method fixed:
  - scran::buildKNNGraph
- Builds graphs from:
  - PCA
  - PCA_regressed
- Stores graphs in metadata rather than reducedDims or external files
- Random seed fixed:
  - set.seed(123)
- Uses same k and n_pcs for both graph variants

## Strengths
- Clean comparison-ready graph construction for raw vs regressed embeddings
- Strong validation of required upstream dimensionality reductions
- Stores both graph objects and summary metadata
- Captures node/edge counts for sanity checking
- Parameterizes key graph settings (k, n_pcs)

## Issues / refactor notes
- Assumes both PCA and PCA_regressed must exist; no single-embedding mode
- Stores potentially large graph objects inside SCE metadata
- No support for alternative neighbor graph methods
- No support for approximate nearest neighbors
- No logging/provenance capture beyond console output
- Seed is hard-coded and not configurable
- No graph export outside the SCE object

## Config candidates
- k
- n_pcs
- possible future:
  - graph method
  - embedding choice(s)
  - approximate neighbor settings

## Fixed conventions
- graph construction from both PCA and PCA_regressed
- graph storage in metadata(sce)$graphs
- graph build summary in metadata(sce)$graph_build

---

## File
scripts/downstream/31_cluster_knn_graphs.R

## Role
Downstream stage 31. Clusters KNN graphs derived from PCA and PCA_regressed embeddings.

## What it does
- Accepts arguments:
  - input_sce_rds
  - output_sce_rds
  - optional: algorithm (default = louvain)
- Loads SCE object
- Validates:
  - metadata(sce)$graphs exists
  - graphs contain:
    - knn_pca
    - knn_pca_regressed
  - both graph objects are igraph objects
- Applies graph clustering to both graphs
- Supports algorithms:
  - louvain
  - walktrap
  - leiden
- Stores cluster labels in colData:
  - cluster_pca
  - cluster_pca_regressed
- Stores clustering summary in metadata(sce)$clustering
- Saves updated SCE

## Hard-coded / assumed behavior
- Requires at least 2 positional arguments
- Default algorithm = louvain
- Supported algorithms limited to:
  - louvain
  - walktrap
  - leiden
- Always clusters both:
  - knn_pca
  - knn_pca_regressed
- Output cluster labels stored as:
  - cluster_pca
  - cluster_pca_regressed
- Clustering metadata stored under:
  - metadata(sce)$clustering
- No resolution parameter exposed for clustering methods

## Strengths
- Clean comparison of clustering results across raw vs regressed embeddings
- Supports multiple graph clustering algorithms
- Strong validation of graph presence and type
- Stores cluster assignments directly in colData
- Stores cluster counts and algorithm metadata

## Issues / refactor notes
- No resolution control for Leiden/Louvain-style clustering
- No seed control exposed
- Always clusters both graph variants; no single-graph mode
- No support for other graph inputs or clustering methods
- No logging/provenance capture beyond console output
- Cluster IDs are factorized directly from membership output without renaming/versioning
- No external cluster summary TSV

## Config candidates
- clustering algorithm
- possible future:
  - resolution parameter
  - graph selection
  - random seed
  - cluster label prefix

## Fixed conventions
- cluster both knn_pca and knn_pca_regressed
- store labels in colData as:
  - cluster_pca
  - cluster_pca_regressed
- store metadata in metadata(sce)$clustering

---

## File
scripts/downstream/32_run_umap.R

## Role
Downstream stage 32. Runs UMAP on PCA and PCA_regressed embeddings.

## What it does
- Accepts arguments:
  - input_sce_rds
  - output_sce_rds
  - optional: n_pcs (default = 20)
- Loads SCE object
- Validates presence of:
  - reducedDim(sce, "PCA")
  - reducedDim(sce, "PCA_regressed")
- Subsets both embeddings to first n_pcs dimensions
- Runs uwot::umap on:
  - PCA
  - PCA_regressed
- Stores outputs in reducedDims:
  - UMAP
  - UMAP_regressed
- Stores run metadata in metadata(sce)$umap
- Saves updated SCE

## Hard-coded / assumed behavior
- Requires at least 2 positional arguments
- Default n_pcs = 20
- Requires both PCA variants to exist
- UMAP parameters hard-coded:
  - n_neighbors = 30
  - min_dist = 0.3
  - metric = "cosine"
  - verbose = TRUE
- Random seed fixed:
  - set.seed(123)
- Output names fixed:
  - UMAP
  - UMAP_regressed
- Metadata method label says:
  - scater::runUMAP
  although implementation uses uwot::umap directly

## Strengths
- Builds embeddings for both raw and regressed PCA workflows
- Stores both embeddings in reducedDims for downstream plotting
- Parameterizes number of PCs
- Reuses shared embedding structure across variants
- Saves metadata describing UMAP inputs and outputs

## Issues / refactor notes
- Metadata method label is inconsistent with actual implementation
- UMAP tuning parameters are hard-coded
- Requires both PCA variants; no single-embedding mode
- No model reuse or transform mode
- No logging/provenance capture beyond console output
- Seed is hard-coded and not configurable
- No storage of full uwot model object

## Config candidates
- n_pcs
- possible future:
  - n_neighbors
  - min_dist
  - metric
  - embedding selection
  - random seed

## Fixed conventions
- run UMAP on both PCA and PCA_regressed
- store embeddings as:
  - UMAP
  - UMAP_regressed
- store summary metadata in metadata(sce)$umap

---

## File
scripts/downstream/33_run_tsne.R

## Role
Downstream stage 33. Runs t-SNE on PCA and PCA_regressed embeddings.

## What it does
- Accepts arguments:
  - input_sce_rds
  - output_sce_rds
  - optional: n_pcs (default = 20)
- Loads SCE object
- Validates presence of:
  - reducedDim(sce, "PCA")
  - reducedDim(sce, "PCA_regressed")
- Subsets both embeddings to first n_pcs dimensions
- Runs Rtsne on:
  - PCA
  - PCA_regressed
- Stores outputs in reducedDims:
  - TSNE
  - TSNE_regressed
- Stores run metadata in metadata(sce)$tsne
- Saves updated SCE

## Hard-coded / assumed behavior
- Requires at least 2 positional arguments
- Default n_pcs = 20
- Requires both PCA variants to exist
- t-SNE parameters hard-coded:
  - dims = 2
  - perplexity = 30
  - check_duplicates = FALSE
  - pca = FALSE
  - verbose = TRUE
- Random seed fixed:
  - set.seed(123)
- Output names fixed:
  - TSNE
  - TSNE_regressed

## Strengths
- Builds embeddings for both raw and regressed PCA workflows
- Stores both embeddings in reducedDims for downstream plotting
- Parameterizes number of PCs
- Captures basic t-SNE metadata
- Clean parallel structure with UMAP stage

## Issues / refactor notes
- t-SNE tuning parameters are hard-coded
- Requires both PCA variants; no single-embedding mode
- No storage of full Rtsne model object
- No logging/provenance capture beyond console output
- Seed is hard-coded and not configurable
- No checks for sample-size/perplexity compatibility beyond Rtsne defaults

## Config candidates
- n_pcs
- possible future:
  - perplexity
  - embedding selection
  - random seed
  - t-SNE dimensionality

## Fixed conventions
- run t-SNE on both PCA and PCA_regressed
- store embeddings as:
  - TSNE
  - TSNE_regressed
- store summary metadata in metadata(sce)$tsne

---

## File
scripts/downstream/34_cluster_stability.R

## Role
Downstream stage 34. Compares clustering stability within and across backends using adjusted Rand index (ARI).

## What it does
- Accepts arguments:
  - cellranger_sce.rds
  - starsolo_sce.rds
  - output_tsv
- Loads two SCE objects:
  - Cell Ranger result
  - STARsolo result
- Validates required clustering fields in both objects:
  - cluster_pca
  - cluster_pca_regressed
- Computes within-backend ARI:
  - Cell Ranger: cluster_pca vs cluster_pca_regressed
  - STARsolo: cluster_pca vs cluster_pca_regressed
- Harmonizes cell barcodes across backends:
  - removes trailing "-1" from Cell Ranger barcodes
  - uses STARsolo colnames as-is
- Intersects shared cells
- Computes cross-backend ARI on shared cells:
  - cellranger_pca vs starsolo_pca
  - cellranger_pca_regressed vs starsolo_pca_regressed
  - cellranger_pca vs starsolo_pca_regressed
  - cellranger_pca_regressed vs starsolo_pca
- Writes summary TSV with:
  - comparison
  - ari
  - n_cells_used

## Hard-coded / assumed behavior
- Requires exactly 3 positional arguments
- Assumes both input objects are SingleCellExperiment
- Assumes required cluster fields exist in both objects:
  - cluster_pca
  - cluster_pca_regressed
- Stability metric fixed:
  - mclust::adjustedRandIndex
- Cell barcode harmonization hard-coded:
  - remove trailing "-1" from Cell Ranger barcodes only
- STARsolo barcodes assumed already comparable after that transformation
- Requires at least 2 shared cells for cross-backend comparison
- Comparison set fixed to 6 ARI summaries

## Strengths
- Explicitly quantifies clustering stability within and across backends
- Includes both raw and regressed clustering comparisons
- Handles backend barcode-format mismatch in a simple practical way
- Produces compact TSV summary suitable for reporting
- Useful for backend validation and hardening assessment

## Issues / refactor notes
- Barcode harmonization is hard-coded and limited
- Assumes Cell Ranger uses "-1" suffix and STARsolo does not
- No validation that shared cells are in the same biological order beyond matching barcodes
- No support for alternative cluster fields or additional embeddings
- No visualization output
- No logging/provenance capture beyond console output
- No storage of stability results in SCE metadata
- No handling for partially overlapping or duplicated barcodes beyond simple intersect/match

## Config candidates
- none required for current hardening phase
- possible future:
  - cluster field names to compare
  - barcode harmonization rule
  - comparison set selection

## Fixed conventions
- stability metric = adjusted Rand index
- compare:
  - within-backend raw vs regressed
  - cross-backend raw vs raw
  - cross-backend regressed vs regressed
  - cross-backend mixed comparisons
- output as TSV summary table

---

## File
scripts/downstream/40_find_markers_cellranger.R

## Role
Downstream stage 40. Legacy backend-specific marker discovery script for Cell Ranger output.

## What it does
- Loads a hard-coded Cell Ranger SCE object
- Uses hard-coded clustering field:
  - cluster_pca_regressed
- Removes genes with zero counts across all cells
- Runs scran::findMarkers on clusters using:
  - assay.type = "logcounts"
  - direction = "up"
  - lfc = 0.5
- Builds per-cluster marker tables
- Adds annotation columns:
  - feature_id
  - gene_id
  - gene_name
  - cluster
- Merges cluster tables into one marker table
- Writes:
  - full marker table
  - top 10 markers per cluster table
- Prints preview to console

## Hard-coded / assumed behavior
- Input SCE hard-coded:
  - analysis/objects/pbmc1k_cellranger_umap_tsne_sce.rds
- Output directory hard-coded:
  - analysis/markers
- Cluster field hard-coded:
  - cluster_pca_regressed
- Output files hard-coded:
  - pbmc1k_cellranger_markers.tsv
  - pbmc1k_cellranger_top10_markers.tsv
- Assumes:
  - logcounts assay exists
  - rowData contains gene_id and gene_name
  - clustering field exists in colData
  - findMarkers output contains FDR and summary.logFC
- Marker method fixed:
  - scran::findMarkers
  - direction = up
  - lfc = 0.5
- Top marker selection fixed:
  - top 10 per cluster
  - sort by FDR then descending summary.logFC

## Strengths
- Produces both full and summarized marker outputs
- Adds useful gene annotation columns
- Handles variable marker-table column sets across clusters
- Straightforward and interpretable backend-specific analysis

## Issues / refactor notes
- Legacy one-off analysis script, not wrapper- or argument-driven
- Hard-coded input, output, and cluster field
- No command-line arguments
- No metadata/provenance capture
- No validation of required object structure before use
- Cell Ranger specific naming embedded in filenames
- Duplicates logic likely mirrored in STARsolo version
- Not yet suitable as canonical hardened pipeline stage

## Config candidates
- input SCE path
- output directory
- cluster field
- lfc threshold
- direction
- top N markers

## Fixed conventions
- marker discovery via scran::findMarkers
- annotation columns:
  - feature_id
  - gene_id
  - gene_name
  - cluster
- export of both full marker table and top-marker summary

---

## File
scripts/downstream/40_find_markers_starsolo.R

## Role
Downstream stage 40. Legacy backend-specific marker discovery script for STARsolo output.

## What it does
- Loads a hard-coded STARsolo SCE object
- Uses hard-coded clustering field:
  - cluster_pca_regressed
- Removes genes with zero counts across all cells
- Runs scran::findMarkers on clusters using:
  - assay.type = "logcounts"
  - direction = "up"
  - lfc = 0.5
- Builds per-cluster marker tables
- Adds annotation columns:
  - feature_id
  - gene_id
  - gene_name
  - cluster
- Merges cluster tables into one marker table
- Writes:
  - full marker table
  - top 10 markers per cluster table
- Prints preview to console

## Hard-coded / assumed behavior
- Input SCE hard-coded:
  - analysis/objects/pbmc1k_starsolo_umap_tsne_sce.rds
- Output directory hard-coded:
  - analysis/markers
- Cluster field hard-coded:
  - cluster_pca_regressed
- Output files hard-coded:
  - pbmc1k_starsolo_markers.tsv
  - pbmc1k_starsolo_top10_markers.tsv
- Assumes:
  - logcounts assay exists
  - rowData contains gene_id and gene_name
  - clustering field exists in colData
  - findMarkers output contains FDR and summary.logFC
- Marker method fixed:
  - scran::findMarkers
  - direction = up
  - lfc = 0.5
- Top marker selection fixed:
  - top 10 per cluster
  - sort by FDR then descending summary.logFC

## Strengths
- Produces both full and summarized marker outputs
- Adds useful gene annotation columns
- Handles variable marker-table column sets across clusters
- Straightforward and interpretable backend-specific analysis

## Issues / refactor notes
- Legacy one-off analysis script, not wrapper- or argument-driven
- Hard-coded input, output, and cluster field
- No command-line arguments
- No metadata/provenance capture
- No validation of required object structure before use
- STARsolo-specific naming embedded in filenames
- Duplicates logic from Cell Ranger marker script
- Not yet suitable as canonical hardened pipeline stage

## Config candidates
- input SCE path
- output directory
- cluster field
- lfc threshold
- direction
- top N markers

## Fixed conventions
- marker discovery via scran::findMarkers
- annotation columns:
  - feature_id
  - gene_id
  - gene_name
  - cluster
- export of both full marker table and top-marker summary

---

## File
scripts/downstream/41_annotate_celltypes_cellranger.R

## Role
Downstream stage 41. Legacy backend-specific manual cell type annotation script for Cell Ranger output.

## What it does
- Loads a hard-coded Cell Ranger SCE object
- Uses hard-coded clustering field:
  - cluster_pca_regressed
- Applies manual cluster-to-label mappings for:
  - cell_type_label
  - lineage
  - annotation_confidence
  - notes
- Validates that all observed clusters have annotations
- Adds per-cell annotations to SCE colData
- Builds cluster-level annotation summary table
- Merges cluster cell counts into annotation table
- Writes:
  - annotated SCE object
  - cluster annotation TSV
- Prints cell type counts, lineage counts, and annotation table

## Hard-coded / assumed behavior
- Input SCE hard-coded:
  - analysis/objects/pbmc1k_cellranger_umap_tsne_sce.rds
- Output object hard-coded:
  - analysis/objects/pbmc1k_cellranger_annotated_sce.rds
- Output table hard-coded:
  - analysis/markers/pbmc1k_cellranger_cluster_annotations.tsv
- Cluster field hard-coded:
  - cluster_pca_regressed
- Annotation mapping hard-coded for clusters 1–12
- Assumes:
  - input object is SingleCellExperiment
  - cluster_pca_regressed exists in colData
  - current cluster numbering is stable and meaningful
- Per-cell annotations written to colData fields:
  - cell_type_label
  - lineage
  - annotation_confidence

## Strengths
- Explicit and interpretable manual annotation step
- Validates that all observed clusters are annotated
- Captures both per-cell and per-cluster annotation outputs
- Includes confidence and marker-note fields, which is useful for review
- Provides cluster cell counts in summary table

## Issues / refactor notes
- Legacy one-off script, not wrapper- or argument-driven
- Hard-coded input/output paths and cluster field
- Manual annotation tied to one specific dataset and one specific clustering result
- Cluster numbering is brittle; annotations break if clustering changes
- No provenance capture for annotation rationale beyond free-text notes
- No versioning of annotation scheme
- No support for automated or semi-automated annotation methods
- Not suitable as canonical hardened pipeline stage without parameterization

## Config candidates
- input SCE path
- output object path
- output annotation table path
- cluster field
- annotation mapping source file

## Fixed conventions
- manual annotation should produce:
  - per-cell labels in colData
  - cluster-level annotation summary table
- useful annotation fields:
  - cell_type_label
  - lineage
  - annotation_confidence
  - notes

---

## File
scripts/downstream/41_annotate_celltypes_starsolo.R

## Role
Downstream stage 41. Legacy backend-specific manual cell type annotation script for STARsolo output.

## What it does
- Loads a hard-coded STARsolo SCE object
- Uses hard-coded clustering field:
  - cluster_pca_regressed
- Applies manual cluster-to-label mappings for:
  - cell_type_label
  - lineage
  - annotation_confidence
  - notes
- Validates that all observed clusters have annotations
- Adds per-cell annotations to SCE colData
- Builds cluster-level annotation summary table
- Merges cluster cell counts into annotation table
- Writes:
  - annotated SCE object
  - cluster annotation TSV
- Prints cell type counts, lineage counts, and annotation table

## Hard-coded / assumed behavior
- Input SCE hard-coded:
  - analysis/objects/pbmc1k_starsolo_umap_tsne_sce.rds
- Output object hard-coded:
  - analysis/objects/pbmc1k_starsolo_annotated_sce.rds
- Output table hard-coded:
  - analysis/markers/pbmc1k_starsolo_cluster_annotations.tsv
- Cluster field hard-coded:
  - cluster_pca_regressed
- Annotation mapping hard-coded for clusters 1–9
- Assumes:
  - input object is SingleCellExperiment
  - cluster_pca_regressed exists in colData
  - current cluster numbering is stable and meaningful
- Per-cell annotations written to colData fields:
  - cell_type_label
  - lineage
  - annotation_confidence

## Strengths
- Explicit and interpretable manual annotation step
- Validates that all observed clusters are annotated
- Captures both per-cell and per-cluster annotation outputs
- Includes confidence and marker-note fields for review
- Provides cluster cell counts in summary table

## Issues / refactor notes
- Legacy one-off script, not wrapper- or argument-driven
- Hard-coded input/output paths and cluster field
- Manual annotation tied to one specific dataset and one specific clustering result
- Cluster numbering is brittle; annotations break if clustering changes
- No provenance capture for annotation rationale beyond free-text notes
- No versioning of annotation scheme
- No support for automated or semi-automated annotation methods
- Duplicates logic from Cell Ranger annotation script
- Not suitable as canonical hardened pipeline stage without parameterization

## Config candidates
- input SCE path
- output object path
- output annotation table path
- cluster field
- annotation mapping source file

## Fixed conventions
- manual annotation should produce:
  - per-cell labels in colData
  - cluster-level annotation summary table
- useful annotation fields:
  - cell_type_label
  - lineage
  - annotation_confidence
  - notes

---

## File
scripts/downstream/42_differential_cellranger.R

## Role
Downstream stage 42. Legacy backend-specific differential expression script for Cell Ranger output.

## What it does
- Loads a hard-coded annotated Cell Ranger SCE object
- Requires cell_type_label in colData
- Defines comparison groups:
  - B_cells
  - T_cells
- T_cells group includes:
  - T cells
  - IL7R+ T cells
  - naive / resting T cells
- Excludes all other cell types
- Extracts logcounts matrix
- Fits limma linear model
- Runs empirical Bayes moderation
- Extracts full differential expression table for:
  - B_cells vs T_cells
- Adds annotation columns:
  - feature_id
  - gene_id
  - gene_name
- Writes DE results to TSV
- Prints top DE genes preview

## Hard-coded / assumed behavior
- Input SCE hard-coded:
  - analysis/objects/pbmc1k_cellranger_annotated_sce.rds
- Output file hard-coded:
  - analysis/markers/pbmc1k_cellranger_Bcells_vs_Tcells_DE.tsv
- Comparison hard-coded:
  - B cells vs T-cell-related labels
- Group definitions hard-coded in script
- Reference level fixed:
  - T_cells
- Uses:
  - logcounts assay
  - limma::lmFit
  - limma::eBayes
  - limma::topTable
- Assumes:
  - logcounts exists
  - cell_type_label exists
  - gene_id and gene_name exist in rowData
- Full output written:
  - number = Inf
  - sort.by = "P"

## Strengths
- Clear and interpretable DE comparison
- Uses standard limma workflow
- Adds gene annotation to results
- Simple targeted downstream biological comparison
- Produces full ranked DE table

## Issues / refactor notes
- Legacy one-off script, not wrapper- or argument-driven
- Hard-coded input, output, and comparison definition
- Not generalizable to arbitrary group comparisons
- No validation of minimum group sizes
- No provenance capture
- No parameterization of contrast, labels, or output naming
- Cell Ranger-specific naming embedded in filename
- Not suitable as canonical hardened pipeline stage without refactor

## Config candidates
- input SCE path
- output file path
- grouping variable
- group definitions
- contrast/reference group
- DE method

## Fixed conventions
- DE output should include:
  - feature_id
  - gene_id
  - gene_name
- export as TSV ranked by significance

---

## File
scripts/downstream/42_differential_starsolo.R

## Role
Downstream stage 42. Legacy backend-specific differential expression script for STARsolo output.

## What it does
- Loads a hard-coded annotated STARsolo SCE object
- Requires cell_type_label in colData
- Defines comparison groups:
  - B_cells
  - T_cells
- Excludes all other cell types
- Extracts logcounts matrix
- Fits limma linear model
- Runs empirical Bayes moderation
- Extracts full differential expression table for:
  - B_cells vs T_cells
- Adds annotation columns:
  - feature_id
  - gene_id
  - gene_name
- Writes DE results to TSV
- Prints top DE genes preview

## Hard-coded / assumed behavior
- Input SCE hard-coded:
  - analysis/objects/pbmc1k_starsolo_annotated_sce.rds
- Output file hard-coded:
  - analysis/markers/pbmc1k_starsolo_Bcells_vs_Tcells_DE.tsv
- Comparison hard-coded:
  - B cells vs T cells
- Group definitions hard-coded in script
- Reference level fixed:
  - T_cells
- Uses:
  - logcounts assay
  - limma::lmFit
  - limma::eBayes
  - limma::topTable
- Assumes:
  - logcounts exists
  - cell_type_label exists
  - gene_id and gene_name exist in rowData
- Full output written:
  - number = Inf
  - sort.by = "P"

## Strengths
- Clear and interpretable DE comparison
- Uses standard limma workflow
- Adds gene annotation to results
- Simple targeted downstream biological comparison
- Produces full ranked DE table

## Issues / refactor notes
- Legacy one-off script, not wrapper- or argument-driven
- Hard-coded input, output, and comparison definition
- Not generalizable to arbitrary group comparisons
- No validation of minimum group sizes
- No provenance capture
- No parameterization of contrast, labels, or output naming
- STARsolo-specific naming embedded in filename
- Not suitable as canonical hardened pipeline stage without refactor

## Config candidates
- input SCE path
- output file path
- grouping variable
- group definitions
- contrast/reference group
- DE method

## Fixed conventions
- DE output should include:
  - feature_id
  - gene_id
  - gene_name
- export as TSV ranked by significance

---

## File
scripts/downstream/43_pathway_enrichment_cellranger.R

## Role
Downstream stage 43. Legacy backend-specific pathway enrichment script for Cell Ranger differential expression results.

## What it does
- Loads a hard-coded Cell Ranger DE result table
- Requires DE columns:
  - gene_name
  - t
- Removes rows with missing/empty gene names or missing t-statistics
- Ranks genes by t-statistic
- Deduplicates genes by keeping the highest absolute-t occurrence
- Runs fgsea on two MSigDB collections:
  - Hallmark
  - Reactome
- Writes two pathway enrichment result tables
- Prints top enriched pathways to console

## Hard-coded / assumed behavior
- Input DE file hard-coded:
  - analysis/markers/pbmc1k_cellranger_Bcells_vs_Tcells_DE.tsv
- Output files hard-coded:
  - analysis/markers/pbmc1k_cellranger_Bcells_vs_Tcells_Hallmark_fgsea.tsv
  - analysis/markers/pbmc1k_cellranger_Bcells_vs_Tcells_Reactome_fgsea.tsv
- Species hard-coded:
  - Homo sapiens
- Gene set collections hard-coded:
  - H (Hallmark)
  - C2 / CP:REACTOME
- Ranking statistic fixed:
  - limma t-statistic
- fgsea parameters hard-coded:
  - minSize = 10
  - maxSize = 500
- Duplicate gene names handled by sorting on abs(t) and keeping first occurrence
- leadingEdge collapsed to semicolon-delimited string before export

## Strengths
- Clear and standard preranked GSEA workflow
- Uses informative ranking statistic from DE analysis
- Produces separate outputs for major pathway collections
- Deduplicates genes in a sensible practical way
- Converts leadingEdge list column into exportable text format

## Issues / refactor notes
- Legacy one-off script, not wrapper- or argument-driven
- Hard-coded input/output paths and comparison context
- Hard-coded species and pathway collections
- No provenance capture
- No parameterization of ranking metric, collections, or fgsea thresholds
- No validation that DE table corresponds to intended comparison beyond filename
- Cell Ranger-specific naming embedded in filenames
- Not suitable as canonical hardened pipeline stage without refactor

## Config candidates
- input DE file
- output file paths
- species
- pathway collections
- ranking statistic column
- minSize
- maxSize

## Fixed conventions
- preranked GSEA via fgsea
- rank genes by DE statistic
- export enrichment results as TSV
- flatten leadingEdge to delimited text for output

---

## File
scripts/downstream/43_pathway_enrichment_starsolo.R

## Role
Downstream stage 43. Legacy backend-specific pathway enrichment script for STARsolo differential expression results.

## What it does
- Loads a hard-coded STARsolo DE result table
- Requires DE columns:
  - gene_name
  - t
- Removes rows with missing/empty gene names or missing t-statistics
- Ranks genes by t-statistic
- Deduplicates genes by keeping the highest absolute-t occurrence
- Runs fgsea on two MSigDB collections:
  - Hallmark
  - Reactome
- Writes two pathway enrichment result tables
- Prints top enriched pathways to console

## Hard-coded / assumed behavior
- Input DE file hard-coded:
  - analysis/markers/pbmc1k_starsolo_Bcells_vs_Tcells_DE.tsv
- Output files hard-coded:
  - analysis/markers/pbmc1k_starsolo_Bcells_vs_Tcells_Hallmark_fgsea.tsv
  - analysis/markers/pbmc1k_starsolo_Bcells_vs_Tcells_Reactome_fgsea.tsv
- Species hard-coded:
  - Homo sapiens
- Gene set collections hard-coded:
  - H (Hallmark)
  - C2 / CP:REACTOME
- Ranking statistic fixed:
  - limma t-statistic
- fgsea parameters hard-coded:
  - minSize = 10
  - maxSize = 500
- Duplicate gene names handled by sorting on abs(t) and keeping first occurrence
- leadingEdge collapsed to semicolon-delimited string before export

## Strengths
- Clear and standard preranked GSEA workflow
- Uses informative ranking statistic from DE analysis
- Produces separate outputs for major pathway collections
- Deduplicates genes in a sensible practical way
- Converts leadingEdge list column into exportable text format

## Issues / refactor notes
- Legacy one-off script, not wrapper- or argument-driven
- Hard-coded input/output paths and comparison context
- Hard-coded species and pathway collections
- No provenance capture
- No parameterization of ranking metric, collections, or fgsea thresholds
- No validation that DE table corresponds to intended comparison beyond filename
- STARsolo-specific naming embedded in filenames
- Duplicates logic from Cell Ranger pathway enrichment script
- Not suitable as canonical hardened pipeline stage without refactor

## Config candidates
- input DE file
- output file paths
- species
- pathway collections
- ranking statistic column
- minSize
- maxSize

## Fixed conventions
- preranked GSEA via fgsea
- rank genes by DE statistic
- export enrichment results as TSV
- flatten leadingEdge to delimited text for output

---

## File
scripts/downstream/50_export_visualizations.R

## Role
Downstream stage 50. Legacy visualization export script for backend-specific and cross-backend downstream figures.

## What it does
- Creates hard-coded downstream figure directories:
  - analysis/figures/downstream
  - analysis/figures/downstream/cellranger
  - analysis/figures/downstream/starsolo
  - analysis/figures/downstream/comparison
- Defines helper plotting functions for:
  - embeddings
  - cluster size barplots
  - cell type composition barplots
  - marker dotplots
- Loads hard-coded annotated Cell Ranger and STARsolo SCE objects
- Exports backend-specific figures including:
  - UMAP by cluster
  - UMAP by cell type
  - UMAP by lineage
  - t-SNE by cluster
  - t-SNE by cell type
  - cluster sizes
  - cell type composition
  - canonical marker dotplot
- Exports cross-backend comparison figure:
  - cell type composition by backend

## Hard-coded / assumed behavior
- Input SCE files hard-coded:
  - analysis/objects/pbmc1k_cellranger_annotated_sce.rds
  - analysis/objects/pbmc1k_starsolo_annotated_sce.rds
- Output directories hard-coded under:
  - analysis/figures/downstream/
- Dataset naming hard-coded:
  - PBMC1k
- Embeddings assumed present:
  - UMAP
  - TSNE
- Annotation / grouping fields assumed present:
  - cluster_pca
  - cell_type_label
  - lineage
- Marker panel hard-coded:
  - CD3D, CD3E, MS4A1, CD79A, NKG7, GNLY, LYZ, S100A8, S100A9, HLA-DRA, CD74
- Plot aesthetics largely fixed:
  - theme_bw
  - point size / alpha
  - figure sizes
  - dpi = 300
- Dot plot uses:
  - logcounts(sce)
  - mean expression
  - percent expressing
- Backend comparison plot fixed to:
  - cell type composition only

## Strengths
- Produces a broad and useful downstream visualization suite
- Includes both backend-specific and backend-comparison outputs
- Reuses helper functions to keep plotting logic relatively organized
- Canonical marker dotplot is useful for annotation review
- Publication/report-friendly PNG output

## Issues / refactor notes
- Legacy one-off script, not wrapper- or argument-driven
- Hard-coded input files, output locations, dataset naming, and marker panel
- No validation that required reducedDims / colData fields exist before plotting
- No parameterization of plot set, marker panel, titles, or aesthetics
- No provenance capture
- No support for arbitrary datasets or grouping fields
- No report bundling; just raw figure export
- Not suitable as canonical hardened pipeline stage without refactor

## Config candidates
- input object paths
- output root
- dataset label
- plot inclusion flags
- marker panel
- grouping/color fields
- figure dimensions and dpi

## Fixed conventions
- downstream visual export should include:
  - embedding plots
  - cluster summaries
  - cell type composition
  - marker expression visualization
  - backend comparison figure(s)
- PNG export is acceptable as current standard

---

## File
scripts/downstream/51_compile_visualization_report.R

## Role
Downstream stage 51. Legacy report-compilation script that assembles QC and downstream PNG figures into a single PDF.

## What it does
- Defines hard-coded figure directories:
  - analysis/figures/qc/cellranger
  - analysis/figures/qc/starsolo
  - analysis/figures/downstream/cellranger
  - analysis/figures/downstream/starsolo
  - analysis/figures/downstream/comparison
- Collects all PNG files from those directories
- Sorts file paths
- Writes a PDF report:
  - analysis/figures/scRNAseq_pilot_visualization_report.pdf
- Adds each PNG as a page with the file path as a page title

## Hard-coded / assumed behavior
- Figure directories hard-coded
- Input figure type fixed:
  - PNG only
- Output report path hard-coded:
  - analysis/figures/scRNAseq_pilot_visualization_report.pdf
- Output page size fixed:
  - width = 11
  - height = 8.5
- Assumes png and grid namespaces are available without explicit library() calls
- Page title is derived directly from file path
- Includes all PNGs found; no filtering or ordering beyond lexical sort

## Strengths
- Simple and practical way to bundle QC/downstream figures
- Automatically includes all available PNG outputs
- Produces a shareable single-file report artifact
- No dependence on R Markdown or more complex reporting tooling

## Issues / refactor notes
- Legacy one-off script, not wrapper- or argument-driven
- Hard-coded figure directories and output path
- No validation of figure ordering or grouping by section
- No captions or narrative context; only file-path titles
- Assumes png::readPNG and grid functions are available without explicit imports
- No provenance capture
- No support for alternate output formats
- Not suitable as canonical hardened reporting stage without parameterization

## Config candidates
- input figure directories
- output PDF path
- figure ordering / inclusion rules
- page size

## Fixed conventions
- report bundling of QC and downstream figures into a PDF is useful
- PNG-to-PDF compilation is acceptable as a current reporting approach

---

## File
analysis/01_load_counts_scRNA.R

## Role
Additional analysis / validation script. Early backend-agnostic loader for scRNA count matrices with baseline per-cell metrics.

## What it does
- Accepts flag-based arguments:
  - --run_id
  - --backend (cellranger | starsolo)
  - --matrix (filtered | raw; default filtered)
  - --out_base (default results/validation)
  - --repo_root (default .)
- Loads count matrices from backend-specific directory structures:
  - STARsolo:
    - runs/starsolo/<run_id>/Solo.out/Gene/<matrix>
  - Cell Ranger:
    - runs/cellranger_count/<run_id>/outs/{filtered|raw}_feature_bc_matrix
- Supports gzipped and uncompressed 10X matrix files for Cell Ranger
- Parses matrix, features, and barcodes
- Builds simple list object:
  - counts
  - genes
  - barcodes
- Computes baseline per-cell metrics:
  - nCount_RNA
  - nFeature_RNA
  - percent.mt
- Writes:
  - per_cell_basic_metrics.csv
  - counts_summary.csv
  - counts_object.rds

## Hard-coded / assumed behavior
- Supported backends limited to:
  - cellranger
  - starsolo
- Default matrix type:
  - filtered
- Default output base:
  - results/validation
- STARsolo path hard-coded:
  - runs/starsolo/<run_id>/Solo.out/Gene/<matrix>
- Cell Ranger path hard-coded:
  - runs/cellranger_count/<run_id>/outs/{filtered|raw}_feature_bc_matrix
- Mitochondrial prefix hard-coded:
  - ^MT-
- Output filenames fixed:
  - per_cell_basic_metrics.csv
  - counts_summary.csv
  - counts_object.rds
- Returns a simple list object, not SCE/Seurat
- Uses gene names as rownames
- Assumes Cell Ranger raw matrices may use features.tsv or genes.tsv

## Strengths
- Useful early validation / smoke-test loader
- Backend-aware while remaining lightweight
- Supports gzipped and uncompressed 10X-style inputs
- Provides simple comparative metrics across backends
- Flag-based CLI is more flexible than many of the legacy downstream scripts

## Issues / refactor notes
- Not integrated into main hardened pipeline flow
- Uses simple list object instead of canonical SingleCellExperiment
- Mitochondrial detection only supports human-style MT- prefix
- No provenance capture beyond written CSV/RDS outputs
- Some path logic is hard-coded to historical run structures
- Overlaps conceptually with newer QC stage 01/02 logic
- Likely a validation helper rather than canonical processing stage

## Config candidates
- backend
- matrix type
- out_base
- repo_root
- mitochondrial prefix / species handling

## Fixed conventions
- lightweight validation loader can remain separate from canonical QC pipeline
- backend-specific count loading is useful for comparison workflows

---

## File
analysis/02_compare_backends_scRNA.R

## Role
Additional analysis / validation script. Compares summary metrics between STARsolo and Cell Ranger for a given run.

## What it does
- Accepts flag-based arguments:
  - --run_id
  - --repo_root (default .)
  - --out_base (default results/validation)
- Loads backend summary files:
  - results/validation/<run_id>/starsolo/counts_summary.csv
  - results/validation/<run_id>/cellranger/counts_summary.csv
- Combines the two summary rows
- Computes a delta row:
  - cellranger minus starsolo
- Writes:
  - backend_comparison_summary.csv

## Hard-coded / assumed behavior
- Requires:
  - --run_id
- Default output base:
  - results/validation
- Assumes prior outputs exist from analysis/01_load_counts_scRNA.R
- Assumes exactly one summary row per backend file
- Delta direction fixed:
  - cellranger minus starsolo
- Output filename fixed:
  - backend_comparison_summary.csv
- Metrics compared:
  - n_cells
  - n_genes
  - total_umis
  - median_umis_per_cell
  - median_genes_per_cell
  - median_percent_mt

## Strengths
- Simple backend comparison utility
- Useful for quick validation of preprocessing differences
- Flag-based CLI is flexible
- Produces a compact comparison artifact

## Issues / refactor notes
- Not integrated into canonical hardened wrapper flow
- Depends on outputs from legacy validation script rather than main SCE/QC pipeline
- Assumes one-row summary files
- No provenance capture beyond written CSV
- Comparison direction is fixed
- No visualization output
- Likely a validation helper rather than a core pipeline stage

## Config candidates
- run_id
- repo_root
- out_base
- comparison direction if ever needed

## Fixed conventions
- backend summary comparison is useful as a validation/helper workflow
- CSV output is sufficient for this comparison artifact

---

## Initial Audit Status Summary
- Orchestration layer: complete
- QC layer: complete
- Downstream layer: complete
- Additional analysis / validation scripts: complete

## Audit Conclusion
- scRNA-seq script inventory and file-level audit completed.
- Canonical stage structure identified across orchestration, QC, and downstream analysis.
- Legacy one-off backend-specific scripts identified and separated from future hardened canonical flow.
- Sufficient information now exists to design a unified scRNA-seq configuration schema aligned to the bulk RNA-seq Phase 3 model.
