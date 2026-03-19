# scRNA-seq Unified Configuration Schema Design — Phase 3 Hardening

Date: 2026-03-18

Purpose:
Design an implementation-ready configuration schema for the scRNA-seq pipeline covering:
- RUN
- INPUT
- REF
- RESOURCE
- OUTPUT
- QC
- ANALYSIS
- LOG

Scope:
- Align with the bulk RNA-seq Phase 3 schema structure where appropriate
- Preserve scRNA-seq-specific requirements where needed
- Keep the schema practical for current hardening needs
- Avoid over-engineering for unsupported future modalities

Status:
- RUN: finalized
- INPUT: finalized
- REF: finalized
- RESOURCE: finalized
- OUTPUT: finalized
- QC: finalized
- ANALYSIS: finalized
- LOG: finalized

Design principles:
- Use the same conceptual top-level sections as bulk RNA-seq
- Keep fixed conventions out of config where practical
- Expose only parameters that are likely to vary across runs, datasets, environments, or engines
- Support current engines:
  - cellranger
  - starsolo
- Support current chemistry assumptions:
  - 10xv2
  - 10xv3
- Treat legacy one-off scripts as non-canonical unless intentionally retained

Open design question:
After scRNA-seq schema design is complete, compare bulk and scRNA schemas to decide between:
- one unified schema with shared core sections and pipeline-specific subsections, or
- separate pipeline schemas following a common top-level design pattern

---

## Proposed scRNA-seq Unified Configuration Schema

### RUN

Purpose:
Define run identity, pipeline mode, engine selection, and execution behavior.

Required parameters:
- ENGINE
  Description: scRNA processing engine
  Type: enum
  Allowed: cellranger | starsolo

Optional parameters:
- RUN_ID
  Default: auto-generated
  Description: Unique identifier for this pipeline execution
  Type: string
  Example: pbmc1k_test_2026_03_18

Optional parameters:
- PIPELINE_NAME
  Default: scrnaseq
  Notes: Mainly for logging / reporting

- PIPELINE_MODE
  Default: full
  Allowed: full | qc_only | downstream_only | validate_only
  Notes: Enables partial execution

- RUNS_ROOT
  Default: runs
  Notes: Root directory for pipeline runs

- SAMPLE_MODE
  Default: single
  Allowed: single | multi

- MANIFEST_PATH
  Default: NULL
  Notes: Required if SAMPLE_MODE = multi

- OPERATOR
  Default: system user
  Notes: captured in logs

- ENABLE_RESUME
  Default: TRUE

- ENABLE_OVERWRITE
  Default: FALSE

Constraints:
- RUN_ID must be filesystem-safe (no spaces, no special chars)
- ENGINE must match implemented wrappers

Implementation notes:
- RUN_ID may be auto-generated if not provided
- Wrapper should create canonical run directory:
  runs/<ENGINE>/<RUN_ID>/

### INPUT

Purpose:
Define dataset/sample inputs, FASTQ structure, chemistry, and matrix selection.

Required parameters (single-sample mode):
- SAMPLE_ID
  Type: string
  Example: pbmc1k

- FASTQ_DIR
  Type: path
  Example: data/fastq/pbmc1k/

Required parameters (multi-sample mode):
- MANIFEST_PATH
  Type: path
  Notes: TSV/CSV describing samples and FASTQ locations

Optional parameters:
- DATASET_ID
  Default: SAMPLE_ID

- FASTQ_ROOT
  Default: NULL
  Notes: Used if FASTQ_DIR is relative

- MATRIX_TYPE
  Default: filtered
  Allowed: filtered | raw
  Notes: Used downstream (not for alignment)

- CHEMISTRY
  Default: auto
  Allowed: auto | 10xv2 | 10xv3
  Notes:
    - cellranger can auto-detect
    - starsolo may require explicit handling later

- READ1_PATTERN
  Default: *_R1_*.fastq.gz

- READ2_PATTERN
  Default: *_R2_*.fastq.gz

- FALLBACK_READ1_PATTERN
  Default: *_1.fastq.gz

- FALLBACK_READ2_PATTERN
  Default: *_2.fastq.gz

- ALLOW_ABSOLUTE_FASTQ_PATHS
  Default: TRUE

Constraints:
- FASTQ_DIR must exist
- Patterns must resolve to matching R1/R2 pairs
- For multi-sample mode, manifest must include:
  - SAMPLE_ID
  - FASTQ_DIR (or equivalent)

Implementation notes:
- Wrapper should resolve FASTQs before execution
- Chemistry is not currently used in scripts → future-proof field
- MATRIX_TYPE is used downstream only

### REF

Purpose:
Define reference genome, annotation, and index resources.

Required parameters:
- SPECIES
  Type: string
  Example: human | mouse

- GENOME_BUILD
  Type: string
  Example: GRCh38 | mm10

Optional parameters:
- REF_ROOT
  Default: references/

- FASTA_PATH
  Default: derived from REF_ROOT + GENOME_BUILD

- GTF_PATH
  Default: derived from REF_ROOT + GENOME_BUILD

- STAR_INDEX
  Default: derived from REF_ROOT + GENOME_BUILD + star_index/

- CELLRANGER_REF
  Default: derived from REF_ROOT + GENOME_BUILD + cellranger/

- GENE_ANNOTATION_SOURCE
  Default: ensembl

- MITO_GENE_PREFIX
  Default:
    human → MT-
    mouse → mt-
  Notes:
    Used for percent.mt calculation

- FEATURE_MODE
  Default: Gene
  Notes:
    STARsolo Solo.out/Gene/

- CB_WHITELIST
  Default: None
  Notes:
    STARsolo barcode whitelist (not currently used)

Constraints:
- At least one of:
  - STAR_INDEX (for starsolo)
  - CELLRANGER_REF (for cellranger)
  must be valid depending on ENGINE

- FASTA and GTF must be consistent with index

Implementation notes:
- Prefer convention-over-configuration:
  auto-resolve paths from REF_ROOT when not provided
- Avoid forcing users to specify all reference paths manually
- MITO_GENE_PREFIX currently inferred in scripts — formalizing here is important

### RESOURCE

Purpose:
Define compute resources, execution limits, and runtime environment settings for pipeline execution.

Required parameters:
- THREADS
  Description: Number of CPU threads available to the pipeline
  Type: integer
  Example: 8

Optional parameters:
- MEMORY_GB
  Default: NULL
  Description: Total memory available for the pipeline in GB
  Notes:
    - Used for tools that require explicit memory limits
    - If NULL, tools use internal defaults

- CELLRANGER_LOCALCORES
  Default: THREADS
  Description: Number of cores passed to Cell Ranger
  Notes:
    - Maps to --localcores
    - Overrides THREADS if explicitly set

- CELLRANGER_LOCALMEM
  Default: MEMORY_GB
  Description: Memory (GB) passed to Cell Ranger
  Notes:
    - Maps to --localmem
    - If NULL, Cell Ranger auto-detects

- STAR_THREADS
  Default: THREADS
  Description: Threads used by STAR / STARsolo

- TMP_DIR
  Default: /tmp
  Description: Temporary directory for intermediate files

- SCRATCH_DIR
  Default: NULL
  Description: Optional high-performance scratch space
  Notes:
    - Used for large intermediate files if available
    - Falls back to TMP_DIR if not set

- MAX_PARALLEL_SAMPLES
  Default: 1
  Description: Number of samples processed in parallel (multi-sample mode only)

Constraints:
- THREADS must be >= 1
- MEMORY_GB must be >= 1 if specified
- TMP_DIR must exist or be creatable
- If both TMP_DIR and SCRATCH_DIR are set:
  SCRATCH_DIR should be preferred for large intermediate files

Implementation notes:
- THREADS is the global default; tool-specific thread parameters inherit unless overridden
- Wrapper should:
  - propagate THREADS → STAR, downstream R scripts
  - propagate CELLRANGER_LOCALCORES → Cell Ranger
- Resource usage is currently inconsistent across scripts → this section standardizes behavior
- TMP_DIR should be exported as environment variable (e.g., TMPDIR) during execution

### OUTPUT

Purpose:
Define output roots, directory structure anchors, and control over exported artifacts.

Required parameters:
- OUTPUT_ROOT
  Description: Root directory for all pipeline outputs
  Type: path
  Example: runs/

Optional parameters:
- RESULTS_ROOT
  Default: <OUTPUT_ROOT>/results
  Description: Root for structured result outputs (tables, metrics, markers, etc.)

- QC_ROOT
  Default: <OUTPUT_ROOT>/qc
  Description: Root for QC outputs (metrics, plots, intermediate QC artifacts)

- DOWNSTREAM_ROOT
  Default: <OUTPUT_ROOT>/downstream
  Description: Root for downstream analysis outputs (DE, enrichment, annotations)

- FIGURES_ROOT
  Default: <OUTPUT_ROOT>/figures
  Description: Root for generated plots and visualizations

- REPORT_ROOT
  Default: <OUTPUT_ROOT>/reports
  Description: Root for compiled reports (PDFs, summaries)

- SAVE_INTERMEDIATE_RDS
  Default: TRUE
  Description: Save intermediate R objects (e.g., SingleCellExperiment objects)

- EXPORT_PLOTS
  Default: TRUE
  Description: Enable generation of PNG plots

- EXPORT_REPORT
  Default: TRUE
  Description: Enable generation of compiled PDF report

- CLEAN_INTERMEDIATE_FILES
  Default: FALSE
  Description: Remove temporary/intermediate files after successful run

Constraints:
- OUTPUT_ROOT must be writable
- Subdirectories should be auto-created if they do not exist
- If CLEAN_INTERMEDIATE_FILES = TRUE:
  must not delete files required for downstream steps or reproducibility

Implementation notes:
- Wrapper should construct canonical structure:
  <OUTPUT_ROOT>/<ENGINE>/<RUN_ID>/

- Within run directory, standard subdirectories should be created:
  - results/
  - qc/
  - downstream/
  - figures/
  - reports/

- Subdirectory naming should remain fixed (not configurable) to ensure:
  - reproducibility
  - compatibility across pipelines
  - ease of navigation

- Individual scripts should not define their own output roots:
  all paths should derive from OUTPUT_ROOT + RUN_ID + ENGINE

- SAVE_INTERMEDIATE_RDS should control:
  - SCE object persistence
  - intermediate analysis checkpoints

- EXPORT_REPORT controls generation of:
  analysis/figures/scRNAseq_pilot_visualization_report.pdf

### QC

Purpose:
Define cell-calling, quality filtering, mitochondrial filtering, and doublet detection behavior for scRNA-seq data.

QC stages (canonical order):
1. Per-cell QC metric calculation
2. Barcode rank visualization
3. Cell calling (emptyDrops or equivalent)
4. Low-quality cell filtering
5. Doublet detection
6. Singlet retention
7. QC reporting and visualization

---

Required parameters:
None (all QC behavior has safe defaults)

---

Optional parameters:

# ---- Cell calling ----

- RUN_EMPTYDROPS
  Default: TRUE
  Description: Enable emptyDrops-based cell calling

- EMPTYDROPS_LOWER
  Default: 100
  Description: Lower UMI threshold for emptyDrops testing

- EMPTYDROPS_FDR
  Default: 0.01
  Description: FDR threshold for calling real cells

- USE_CELLRANGER_CELL_CALLS
  Default: FALSE
  Description: Use Cell Ranger cell calls instead of emptyDrops (cellranger only)

---

# ---- Basic filtering thresholds ----

- MIN_COUNTS
  Default: 500
  Description: Minimum total UMI counts per cell

- MIN_GENES
  Default: 200
  Description: Minimum detected genes per cell

- MAX_PCT_MITO
  Default: 20
  Description: Maximum percent mitochondrial reads per cell

- MAX_COUNTS
  Default: NULL
  Description: Optional upper bound on UMI counts (outlier removal)

---

# ---- Mitochondrial handling ----

- QC_MITO_PATTERN
  Default: derived from REF.MITO_GENE_PREFIX
  Description: Regex pattern for identifying mitochondrial genes

- QC_SPECIES
  Default: REF.SPECIES
  Description: Used for species-specific QC logic if needed

---

# ---- Doublet detection ----

- RUN_DOUBLET_DETECTION
  Default: TRUE

- DOUBLET_METHOD
  Default: scDblFinder
  Allowed: scDblFinder

- DOUBLET_RATE
  Default: NULL
  Description: Expected doublet rate (if required by method)

- DOUBLET_SEED
  Default: 1234

- RETAIN_SINGLET_ONLY
  Default: TRUE
  Description: Remove predicted doublets from downstream data

---

# ---- Output and reporting ----

- EXPORT_QC_PLOTS
  Default: TRUE

- EXPORT_BARCODE_RANK_PLOT
  Default: TRUE

- EXPORT_QC_METRICS_TABLE
  Default: TRUE

- EXPORT_FILTER_SUMMARY
  Default: TRUE

---

Constraints:

- EMPTYDROPS parameters only apply if RUN_EMPTYDROPS = TRUE
- If USE_CELLRANGER_CELL_CALLS = TRUE:
  - RUN_EMPTYDROPS should be ignored
- MIN_COUNTS, MIN_GENES, MAX_PCT_MITO must be non-negative
- MAX_PCT_MITO must be between 0 and 100
- If RUN_DOUBLET_DETECTION = FALSE:
  - doublet-related parameters are ignored

---

Implementation notes:

- QC should operate on SingleCellExperiment (SCE) object
- Metric calculation includes:
  - nCount_RNA
  - nFeature_RNA
  - percent.mt

- Barcode rank plot:
  - log-log rank vs counts
  - generated before filtering

- emptyDrops:
  - applied after initial metric calculation
  - defines initial set of "cells"

- Filtering order:
  1. cell calling (emptyDrops or Cell Ranger)
  2. apply MIN_COUNTS / MIN_GENES / MAX_PCT_MITO
  3. optional MAX_COUNTS filter

- Doublet detection:
  - applied after filtering
  - scDblFinder operates on filtered SCE

- Singlet retention:
  - if RETAIN_SINGLET_ONLY = TRUE:
    remove predicted doublets from SCE

- QC outputs should include:
  - per-cell QC metrics table
  - filter summary (cells before/after each stage)
  - barcode rank plot
  - QC violin/box plots

- QC decisions should be logged explicitly:
  - thresholds used
  - number of cells removed at each stage

- Current scripts:
  - already implement most of this logic
  - config will replace hardcoded thresholds and toggles

### ANALYSIS

Purpose:
Define normalization, highly variable gene selection, dimensionality reduction, graph construction, clustering, annotation, differential expression, pathway enrichment, and visualization behavior for the canonical scRNA-seq downstream workflow.

Canonical downstream stages (current design order):
1. Normalization
2. Highly variable gene (HVG) selection
3. PCA
4. Technical covariate assessment
5. Optional regression of technical covariates and rerun PCA
6. Merge PCA variants
7. Neighbor graph construction
8. Clustering
9. UMAP / t-SNE embedding
10. Marker detection
11. Cell type annotation
12. Differential expression
13. Pathway enrichment
14. Visualization export
15. Report compilation

---

Required parameters:
None (all current analysis behavior can be driven from defaults)

---

Optional parameters:

# ---- Normalization / HVG selection ----

- NORMALIZATION_METHOD
  Default: lognorm
  Allowed: lognorm
  Description: Per-cell normalization method for current pipeline
  Notes:
    - maps to logNormCounts workflow

- TOP_N_HVGS
  Default: 2000
  Description: Number of highly variable genes to retain

- HVG_SELECTION_METHOD
  Default: modelGeneVar
  Allowed: modelGeneVar
  Description: Method used to rank highly variable genes

- HVG_RANK_METRIC
  Default: bio
  Allowed: bio
  Description: Metric used to rank genes for HVG selection

- STORE_HVG_METRICS
  Default: TRUE
  Description: Store HVG metrics in rowData and export HVG table

---

# ---- PCA and technical covariate assessment ----

- PCA_N_PCS
  Default: 30
  Description: Number of PCs to compute for standard PCA

- PCA_USE_HVGS
  Default: TRUE
  Description: Restrict PCA input to HVGs

- PCA_CENTER
  Default: TRUE

- PCA_SCALE
  Default: TRUE

- PCA_METHOD
  Default: exact
  Allowed: exact
  Description: PCA backend for current implementation

- PCA_SEED
  Default: 1234

- ASSESS_PC_COVARIATES
  Default: TRUE
  Description: Run PC vs covariate correlation assessment

- PC_COVARIATE_N_PCS
  Default: 10
  Description: Number of PCs included in covariate assessment

- PC_COVARIATES
  Default:
    - total_counts
    - detected_genes
    - pct_mito
  Description: Covariates tested against PCA axes

- PC_COVARIATE_COR_METHOD
  Default: pearson
  Allowed: pearson

---

# ---- Technical regression / alternate PCA ----

- REGRESS_TECHNICAL_COVARIATES
  Default: TRUE
  Description: Regress selected technical covariates and compute alternate PCA space

- REGRESSION_COVARIATES
  Default:
    - log_total_counts
    - pct_mito
  Description: Covariates to regress from HVG expression matrix

- REGRESSION_LOG_COUNTS
  Default: TRUE
  Description: Apply log10(total_counts + 1) transform for count-depth regression term

- REGRESSED_PCA_N_PCS
  Default: 30
  Description: Number of PCs for regressed PCA space

- REGRESSION_SEED
  Default: 1234

- MERGE_PCA_VARIANTS
  Default: TRUE
  Description: Merge standard PCA and regressed PCA into single SCE object

- REGRESSED_REDUCEDDIM_NAME
  Default: PCA_regressed
  Description: Name used for regressed PCA coordinates

---

# ---- Generic reduced-dimension covariate assessment ----

- ASSESS_ANY_REDUCEDDIM_COVARIATES
  Default: TRUE
  Description: Enable generalized covariate assessment for selected embeddings

- REDUCEDDIMS_TO_ASSESS
  Default:
    - PCA
    - PCA_regressed
  Description: Reduced dimensions to assess against technical covariates

- REDUCEDDIM_ASSESS_N_DIMS
  Default: 10
  Description: Number of dimensions per embedding to evaluate

---

# ---- Neighbor graph construction ----

- BUILD_KNN_GRAPHS
  Default: TRUE

- GRAPH_K
  Default: 20
  Description: Number of nearest neighbors for graph construction

- GRAPH_N_PCS
  Default: 20
  Description: Number of PCs used to construct KNN graphs

- GRAPH_REDUCEDDIMS
  Default:
    - PCA
    - PCA_regressed
  Description: Embeddings used to build neighbor graphs

- GRAPH_METHOD
  Default: buildKNNGraph
  Allowed: buildKNNGraph

- GRAPH_SEED
  Default: 1234

- STORE_GRAPH_OBJECTS
  Default: TRUE
  Description: Store graph objects in metadata(sce)

---

# ---- Clustering ----

- RUN_CLUSTERING
  Default: TRUE

- CLUSTER_ALGORITHM
  Default: louvain
  Allowed:
    - louvain
    - walktrap
    - leiden

- CLUSTER_GRAPH_NAMES
  Default:
    - knn_pca
    - knn_pca_regressed
  Description: Graph objects to cluster

- CLUSTER_LABEL_PREFIX
  Default: cluster
  Description: Prefix for generated cluster labels

- STORE_CLUSTER_METADATA
  Default: TRUE

---

# ---- Embeddings ----

- RUN_UMAP
  Default: TRUE

- UMAP_N_PCS
  Default: 20

- UMAP_NEIGHBORS
  Default: 30

- UMAP_MIN_DIST
  Default: 0.3

- UMAP_METRIC
  Default: cosine

- UMAP_REDUCEDDIMS
  Default:
    - PCA
    - PCA_regressed

- UMAP_OUTPUT_NAMES
  Default:
    - UMAP
    - UMAP_regressed

- UMAP_SEED
  Default: 1234

- RUN_TSNE
  Default: TRUE

- TSNE_N_PCS
  Default: 20

- TSNE_PERPLEXITY
  Default: 30

- TSNE_DIMS
  Default: 2

- TSNE_REDUCEDDIMS
  Default:
    - PCA
    - PCA_regressed

- TSNE_OUTPUT_NAMES
  Default:
    - TSNE
    - TSNE_regressed

- TSNE_SEED
  Default: 1234

---

# ---- Cluster stability / backend comparison ----

- RUN_CLUSTER_STABILITY
  Default: TRUE
  Description: Compare clustering behavior within and across backends

- STABILITY_METHOD
  Default: ARI
  Allowed: ARI

- BACKEND_COMPARISON_MODE
  Default: shared_barcodes
  Description: Compare Cell Ranger and STARsolo on intersected cell barcodes

- CELLRANGER_BARCODE_SUFFIX_TO_TRIM
  Default: -1
  Description: Suffix trimmed when harmonizing Cell Ranger barcodes to STARsolo barcodes

---

# ---- Marker detection ----

- RUN_MARKER_DETECTION
  Default: TRUE

- MARKER_METHOD
  Default: scran_findMarkers
  Allowed: scran_findMarkers

- MARKER_CLUSTER_FIELD
  Default: cluster_pca_regressed
  Description: Cluster field used for marker discovery

- MARKER_ASSAY
  Default: logcounts

- MARKER_DIRECTION
  Default: up
  Allowed: up

- MARKER_LFC
  Default: 0.5

- TOP_MARKERS_PER_CLUSTER
  Default: 10

- EXPORT_FULL_MARKER_TABLE
  Default: TRUE

- EXPORT_TOP_MARKER_TABLE
  Default: TRUE

---

# ---- Cell type annotation ----

- RUN_MANUAL_ANNOTATION
  Default: TRUE

- ANNOTATION_METHOD
  Default: manual_mapping
  Allowed: manual_mapping

- ANNOTATION_CLUSTER_FIELD
  Default: cluster_pca_regressed

- ANNOTATION_SOURCE
  Default: NULL
  Description: External annotation mapping file for cluster-to-label assignment

- STORE_CELLTYPE_LABEL
  Default: TRUE

- STORE_LINEAGE_LABEL
  Default: TRUE

- STORE_ANNOTATION_CONFIDENCE
  Default: TRUE

- STORE_ANNOTATION_NOTES
  Default: TRUE

Notes:
- Current legacy scripts hard-code mappings inline
- Hardened implementation should prefer external mapping file over inline cluster numbering

---

# ---- Differential expression ----

- RUN_DIFFERENTIAL_EXPRESSION
  Default: FALSE
  Description: Enable DE testing for configured contrasts

- DE_METHOD
  Default: limma
  Allowed: limma

- DE_ASSAY
  Default: logcounts

- DE_GROUPING_FIELD
  Default: cell_type_label

- DE_REFERENCE_GROUP
  Default: NULL
  Description: Reference level for DE contrast

- DE_TARGET_GROUP
  Default: NULL
  Description: Target level for DE contrast

- DE_GROUP_MAP
  Default: NULL
  Description: Optional mapping of multiple labels into contrast groups

- DE_SORT_BY
  Default: P

- DE_EXPORT_ALL_RESULTS
  Default: TRUE

Notes:
- Current legacy scripts are one-off backend-specific contrasts
- Hardened design should allow arbitrary contrasts driven by config + metadata

---

# ---- Pathway enrichment ----

- RUN_PATHWAY_ENRICHMENT
  Default: FALSE

- PATHWAY_METHOD
  Default: fgsea
  Allowed: fgsea

- PATHWAY_SPECIES
  Default: Homo sapiens

- PATHWAY_COLLECTIONS
  Default:
    - H
    - C2:CP:REACTOME

- PATHWAY_RANK_STAT
  Default: t
  Description: Column from DE table used for preranked enrichment

- FGSEA_MINSIZE
  Default: 10

- FGSEA_MAXSIZE
  Default: 500

- COLLAPSE_LEADING_EDGE
  Default: TRUE
  Description: Flatten leading-edge genes for TSV export

Notes:
- Current implementation assumes limma t-statistics and human MSigDB collections
- Hardened design should still default to that behavior while externalizing it

---

# ---- Visualization / reporting ----

- EXPORT_DOWNSTREAM_FIGURES
  Default: TRUE

- EXPORT_EMBEDDING_PLOTS
  Default: TRUE

- EXPORT_CLUSTER_SIZE_PLOTS
  Default: TRUE

- EXPORT_CELLTYPE_COMPOSITION
  Default: TRUE

- EXPORT_MARKER_DOTPLOT
  Default: TRUE

- MARKER_PANEL
  Default:
    - CD3D
    - CD3E
    - MS4A1
    - CD79A
    - NKG7
    - GNLY
    - LYZ
    - S100A8
    - S100A9
    - HLA-DRA
    - CD74

- EMBEDDING_COLOR_FIELDS
  Default:
    - cluster_pca
    - cell_type_label
    - lineage

- FIGURE_DPI
  Default: 300

- FIGURE_WIDTH
  Default: 9

- FIGURE_HEIGHT
  Default: 7

- COMPILE_VISUALIZATION_REPORT
  Default: TRUE

- REPORT_FORMAT
  Default: pdf
  Allowed: pdf

---

Constraints:

- TOP_N_HVGS must be >= 1
- PCA_N_PCS, GRAPH_N_PCS, UMAP_N_PCS, TSNE_N_PCS must be >= 2
- GRAPH_K must be > 1
- TSNE_PERPLEXITY must be > 0
- If REGRESS_TECHNICAL_COVARIATES = TRUE:
  - REGRESSION_COVARIATES must be defined
- If RUN_MARKER_DETECTION = TRUE:
  - MARKER_CLUSTER_FIELD must exist in colData
- If RUN_MANUAL_ANNOTATION = TRUE:
  - ANNOTATION_SOURCE should be provided in hardened implementation
- If RUN_DIFFERENTIAL_EXPRESSION = TRUE:
  - DE_GROUPING_FIELD and contrast groups must be resolvable in metadata
- If RUN_PATHWAY_ENRICHMENT = TRUE:
  - differential expression results must exist first

---

Implementation notes:

- Current canonical downstream flow should be implemented as argument-driven stage scripts operating on SCE objects
- Legacy backend-specific scripts for:
  - marker detection
  - manual annotation
  - differential expression
  - pathway enrichment
  - figure export
  should be refactored into generalized stage scripts driven by config

- Recommended canonical object conventions:
  - normalized assay: logcounts
  - HVG flag: rowData(sce)$is_hvg
  - standard PCA: reducedDim(sce, "PCA")
  - regressed PCA: reducedDim(sce, "PCA_regressed")
  - standard UMAP: reducedDim(sce, "UMAP")
  - regressed UMAP: reducedDim(sce, "UMAP_regressed")
  - standard t-SNE: reducedDim(sce, "TSNE")
  - regressed t-SNE: reducedDim(sce, "TSNE_regressed")

- Recommended metadata conventions:
  - metadata(sce)$pca
  - metadata(sce)$regressed_pca
  - metadata(sce)$graph_build
  - metadata(sce)$clustering
  - metadata(sce)$umap
  - metadata(sce)$tsne

- Recommended analysis outputs:
  - HVG table
  - PCA covariate assessment tables
  - reduced-dimension covariate assessment tables
  - cluster assignments
  - cluster stability table
  - marker tables
  - annotation tables
  - DE tables
  - pathway enrichment tables
  - visualization PNGs
  - compiled PDF report

- Bulk-aligned design principle:
  keep the same top-level schema structure as bulk RNA-seq, but allow scRNA-seq-specific specialization inside:
  - QC
  - ANALYSIS

### LOG

Purpose:
Define logging, provenance capture, run metadata, and execution trace behavior.

Required parameters:
- LOG_ROOT
  Description: Root directory for pipeline log and provenance files
  Type: path
  Example: logs/

Optional parameters:
- WRAPPER_LOG
  Default: <LOG_ROOT>/wrapper.log
  Description: Main wrapper execution log

- SAMPLE_LOG_DIR
  Default: <LOG_ROOT>/samples
  Description: Directory for per-sample execution logs

- SAVE_CONFIG_SNAPSHOT
  Default: TRUE
  Description: Save resolved config used for the run

- SAVE_MANIFEST_COPY
  Default: TRUE
  Description: Save a copy of the run manifest inside the run metadata directory

- SAVE_SOFTWARE_VERSIONS
  Default: TRUE
  Description: Record versions of key software tools used in the run

- SAVE_GIT_STATUS
  Default: TRUE
  Description: Record git branch, commit, and clean/dirty state

- SAVE_RUN_MANIFEST
  Default: TRUE
  Description: Write run metadata summary file including run ID, engine, config, manifest, and operator

- SAVE_START_END_STATUS
  Default: TRUE
  Description: Record run start time, end time, and completion status

- VERBOSE
  Default: TRUE
  Description: Emit detailed console and wrapper logging

- APPEND_LOGS
  Default: TRUE
  Description: Append to existing logs if present rather than overwrite

- CAPTURE_FAILURE_STATUS
  Default: TRUE
  Description: Write explicit failed-state metadata if run exits with error

Constraints:
- LOG_ROOT must be writable
- Wrapper log and sample logs must be creatable before execution begins
- If APPEND_LOGS = FALSE:
  existing logs for the same run should be overwritten only when ENABLE_OVERWRITE = TRUE

Implementation notes:
- Wrapper should create canonical logging structure under:
  <OUTPUT_ROOT>/<ENGINE>/<RUN_ID>/logs/

- LOG_ROOT in practice should usually resolve inside the run directory rather than a shared global log directory
- Provenance files should be written under:
  <OUTPUT_ROOT>/<ENGINE>/<RUN_ID>/run_metadata/

- Recommended metadata artifacts:
  - resolved_config.env
  - run_manifest.txt
  - pipeline_version.txt
  - software_versions.txt
  - start_end_status.txt

- CAPTURE_FAILURE_STATUS should be implemented via shell trap in wrapper so failed runs are explicitly marked
- LOG behavior should align closely with bulk RNA-seq schema for consistency across pipelines

---

## Design Summary

Shared top-level schema pattern with bulk RNA-seq:
- RUN
- INPUT
- REF
- RESOURCE
- OUTPUT
- LOG

Sections requiring scRNA-seq-specific specialization:
- QC
- ANALYSIS

Key scRNA-seq-specific configuration domains:
- ENGINE
- CHEMISTRY
- MATRIX_TYPE
- emptyDrops / cell-calling parameters
- doublet detection parameters
- PCA regression settings
- graph / clustering settings
- embedding settings
- marker detection settings
- annotation settings
- differential expression settings
- pathway enrichment settings
- visualization / reporting settings

---

## Implementation Handoff

This schema is now implementation-ready for Phase 3 hardening.

Immediate next tasks:
- create an env-style scRNA-seq config file based on this schema
- implement config loader logic in the bulk RNA-seq wrapper
- design and implement a canonical scRNA-seq wrapper using the same top-level schema pattern
- replace hard-coded values in current scRNA-seq scripts with wrapper-supplied configuration values where appropriate

Implementation guidance:
- use env-style variable naming compatible with bash wrappers
- preserve fixed conventions outside config unless variability is clearly needed
- prioritize canonical stage scripts over legacy one-off backend-specific scripts
- treat legacy scripts as refactor targets, not as the long-term hardened interface

---

## Schema Strategy Recommendation

Recommended approach:
- use a shared top-level schema pattern across bulk RNA-seq and scRNA-seq
- maintain separate pipeline-specific config files under that shared conceptual structure

Rationale:
- bulk RNA-seq and scRNA-seq share the same operational scaffolding:
  RUN, INPUT, REF, RESOURCE, OUTPUT, LOG
- scRNA-seq requires materially more specialized QC and ANALYSIS configuration
- forcing both pipelines into one identical flat schema would add unnecessary complexity
- a shared pattern with pipeline-specific implementations provides consistency without over-constraining either pipeline
