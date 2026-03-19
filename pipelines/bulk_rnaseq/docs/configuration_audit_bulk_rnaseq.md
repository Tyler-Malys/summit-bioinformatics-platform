# Configuration Audit — Bulk RNA-seq
Date: 2026-03-18

## Pipeline
bulk_rnaseq

## Scope
This audit covers the bulk RNA-seq pipeline.

Design intent:
- Identify hard-coded assumptions and parameters across pipeline scripts
- Define what should be externalized into a unified configuration system
- Establish a foundation for future extension to other pipelines (e.g., scRNA-seq)

---

## Audit Approach

This audit is intended to cover the full active bulk RNA-seq pipeline, including:
- orchestration / wrapper logic
- preprocessing and quantification shell scripts
- downstream R analysis scripts

Design goal:
- produce one unified configuration schema for the full bulk RNA-seq pipeline
- avoid fragmented configuration systems for sequence processing vs downstream analysis

---

## Categories
- RUN
- INPUT
- REF
- RESOURCE
- OUTPUT
- QC
- ANALYSIS
- LOG

---

## File: scripts/run_pilot_wrapper_v2.sh

### Summary
Main orchestration wrapper. Loads central config and coordinates all pipeline stages. Partially parameterized, but still contains embedded assumptions and conventions.

---

### Already Parameterized (Config-driven)

**RUN**
- RUN_ID
- DO_QC_RAW
- DO_TRIM
- DO_QC_POSTTRIM
- DO_SALMON
- DO_TXIMPORT
- DO_STAR
- DO_LOCALIZE_RAW
- DO_INTEGRITY
- SKIP_BAD_FASTQS
- SALMON_INPUT (raw|trimmed)
- STAR_INPUT (raw|trimmed)

**INPUT**
- PILOT_FASTQ_DIR
- RAW_SRC_DIR
- RAW_LOCAL_ROOT

**REF**
- SALMON_INDEX
- STAR_INDEX
- TX2GENE

**RESOURCE**
- THREADS

**OUTPUT**
- QC_OUT_ROOT
- TRIM_OUT_ROOT
- SALMON_OUT_ROOT
- TXIMPORT_OUT_ROOT
- STAR_OUT_ROOT
- RUNS_ROOT

---

### Hard-coded / Embedded Assumptions

**RUN**
- Default config path: `config/pipeline.env`
- Pipeline identity: `bulk_rnaseq`
- Stage run naming conventions:
  - qc_${RUN_ID}
  - trim_${RUN_ID}
  - qc_posttrim_${RUN_ID}
  - salmon_${RUN_ID}
  - txi_${RUN_ID}
  - star_${RUN_ID}

**INPUT**
- FASTQ extensions limited to:
  - `.fq.gz`
  - `.fastq.gz`
- Input mode restricted to:
  - raw
  - trimmed
- Assumes symlink-based FASTQ input is possible
- Assumes localization copies only symlink-referenced files
- Assumes localized files must reside under RAW_SRC_DIR

**OUTPUT**
- Canonical run directory structure:
  - input/
  - working/
  - logs/
  - qc/
  - outputs/
  - downstream/
  - final/
  - run_metadata/

**LOG**
- Fixed metadata files:
  - resolved_config.env
  - run_manifest.txt
  - pipeline_version.txt
  - software_versions.txt
  - start_end_status.txt
- Wrapper log location:
  - logs/wrapper.log

**QC**
- Integrity check method:
  - gzip -t

**RESOURCE / ENVIRONMENT**
- Tools must exist in PATH:
  - fastqc
  - multiqc
  - fastp
  - salmon
  - Rscript
  - STAR

**EXECUTION CONTEXT**
- Assumes execution from repository root
- Assumes scripts located under:
  - scripts/

---

### Notes / Design Implications

- Wrapper is already well-structured and close to fully configurable
- Remaining work is primarily:
  - formalizing implicit assumptions
  - deciding which items become configurable vs fixed conventions
- Run directory structure may remain a fixed design decision (not user-configurable)
- FASTQ pattern and input modes should likely become explicit schema fields
- Environment/toolchain expectations should be documented as part of RESOURCE or ENV specification

---

## Next Files to Audit
- scripts/qc_fastq.sh
- scripts/trim_fastp.sh
- scripts/salmon_quant.sh
- scripts/star_align.sh
- scripts/tximport_genelevel.R

---

## File: scripts/qc_fastq.sh

### Summary
Stage-level QC script (FastQC + MultiQC). CLI-driven tool invoked by wrapper. Does not load central config directly.

---

### Parameterization

**INPUT (via CLI)**
- INPUT_DIR (-i)

**OUTPUT (via CLI)**
- OUTPUT_DIR (-o)
- RUN_ID (--run-id)

**RESOURCE (via CLI)**
- THREADS (-t)

---

### Hard-coded / Embedded Assumptions

**RUN**
- Default THREADS=8 (overridden by wrapper)
- Default RUN_ID generated from timestamp if not provided

**INPUT**
- FASTQ extensions limited to:
  - `.fq.gz`
  - `.fastq.gz`
- Requires at least one FASTQ in INPUT_DIR

**OUTPUT**
- Stage output structure:
  - ${OUTPUT_DIR}/${RUN_ID}
  - logs/ subdirectory
- FastQC and MultiQC outputs written directly into RUN_DIR

**LOG**
- Fixed log files:
  - logs/fastqc.log
  - logs/multiqc.log
- Stage-level metadata file:
  - run_info.txt

**QC**
- FastQC + MultiQC workflow is fixed (not configurable)

**RESOURCE / ENVIRONMENT**
- Tools must exist in PATH:
  - fastqc
  - multiqc

**EXECUTION CONTEXT**
- Assumes valid FASTQ directory structure
- Assumes gzip-compressed FASTQs

---

### Notes / Design Implications

- Stage script is clean and appropriately minimal
- Wrapper correctly handles configuration; stage acts as execution unit
- FASTQ pattern assumption is duplicated (wrapper + stage) → should be unified
- Logging is split between:
  - wrapper-level metadata
  - stage-level run_info.txt
- Consider whether:
  - stage metadata should be centralized
  - or standardized across all stages
- Dry-run capability exists here but is not exposed at wrapper level

---

## File: scripts/trim_fastp.sh

### Summary
Stage-level trimming script using fastp. CLI-driven tool invoked by wrapper. Assumes paired-end bulk RNA-seq FASTQs with `_1/_2` naming.

---

### Parameterization

**INPUT (via CLI)**
- INPUT_DIR (-i)

**OUTPUT (via CLI)**
- OUTPUT_DIR (-o)
- RUN_ID (--run-id)

**RESOURCE (via CLI)**
- THREADS (-t)

**RUN / EXECUTION**
- DRY_RUN (--dry-run)

---

### Hard-coded / Embedded Assumptions

**RUN**
- Default THREADS=8 (overridden by wrapper)
- Default RUN_ID generated from timestamp if not provided
- Continues across samples and records per-sample failures
- Exits nonzero (`exit 10`) if one or more samples fail

**INPUT**
- Paired-end input required
- R1 pattern limited to:
  - `*_1.fq.gz`
  - `*_1.fastq.gz`
- R2 inferred strictly as:
  - `*_2.fq.gz`
  - `*_2.fastq.gz`
- Requires exact mate-pair naming convention
- Single-end input not supported

**OUTPUT**
- Stage output structure:
  - `${OUTPUT_DIR}/${RUN_ID}`
  - `logs/`
  - `reports/`
- Trimmed FASTQs written directly into RUN_DIR
- Output extension style preserved from input (`.fq.gz` vs `.fastq.gz`)

**LOG**
- Fixed per-sample log naming:
  - `logs/<sample>.fastp.log`
- Stage-level metadata file:
  - `run_info.txt`

**QC / PREPROCESSING**
- Trimming tool fixed as `fastp`
- Adapter handling fixed as:
  - `--detect_adapter_for_pe`
- Minimal output validation checks only for non-empty trimmed FASTQs

**RESOURCE / ENVIRONMENT**
- Tool must exist in PATH:
  - `fastp`

**EXECUTION CONTEXT**
- Assumes gzip-compressed paired-end FASTQs
- Assumes sample identity can be derived from R1 basename by removing `_1.fq.gz` or `_1.fastq.gz`

---

### Notes / Design Implications

- This script is explicitly bulk paired-end oriented
- Mate-pair naming convention should likely become an explicit INPUT schema rule
- Need decision on whether paired-end assumptions remain fixed pipeline convention or become configurable
- Adapter-detection behavior is currently embedded and could remain a fixed default unless future datasets require overrides
- Logging/metadata pattern remains stage-local (`run_info.txt`) and is not yet unified with wrapper-level metadata capture
- Dry-run support exists at stage level but is not currently surfaced by wrapper

---

## File: scripts/salmon_quant.sh

### Summary
Stage-level quantification script using Salmon. CLI-driven tool invoked by wrapper. Assumes paired-end bulk RNA-seq FASTQs with `_1/_2` naming and runs one Salmon quantification per sample.

---

### Parameterization

**INPUT (via CLI)**
- INPUT_DIR (-i)

**OUTPUT (via CLI)**
- OUTPUT_DIR (-o)
- RUN_ID (--run-id)

**REF (via CLI)**
- REF_INDEX (-r)

**RESOURCE (via CLI)**
- THREADS (-t)

**RUN / EXECUTION**
- DRY_RUN (--dry-run)

---

### Hard-coded / Embedded Assumptions

**RUN**
- Default THREADS=8 (overridden by wrapper)
- Default RUN_ID generated from timestamp if not provided
- Samples processed in sorted deterministic order
- Existing sample quantification is skipped if `quant.sf` already exists
- Continues across samples and records failures
- Exits nonzero (`exit 10`) if one or more samples fail

**INPUT**
- Paired-end input required
- R1 pattern limited to:
  - `*_1.fq.gz`
  - `*_1.fastq.gz`
- R2 inferred strictly as:
  - `*_2.fq.gz`
  - `*_2.fastq.gz`
- Requires exact mate-pair naming convention
- Single-end input not supported

**REF**
- Reference input must be a Salmon index directory

**OUTPUT**
- Stage output structure:
  - `${OUTPUT_DIR}/${RUN_ID}`
  - per-sample subdirectories under RUN_DIR
  - `logs/`
- Expected per-sample quant output file:
  - `quant.sf`

**LOG**
- Fixed per-sample log naming:
  - `logs/<sample>.salmon.log`
- Stage-level metadata file:
  - `run_info.txt`

**ANALYSIS / QUANTIFICATION**
- Quantification tool fixed as `salmon quant`
- Library type handling fixed as:
  - `-l A`
- Mapping behavior fixed as:
  - `--validateMappings`
- Quantification performed one sample at a time

**RESOURCE / ENVIRONMENT**
- Tool must exist in PATH:
  - `salmon`

**EXECUTION CONTEXT**
- Assumes gzip-compressed paired-end FASTQs
- Assumes sample identity can be derived from R1 basename by removing `_1.fq.gz` or `_1.fastq.gz`

---

### Notes / Design Implications

- This script is explicitly bulk paired-end oriented
- Mate-pair naming convention is now repeated across trim and Salmon and should likely be formalized centrally
- Salmon runtime options (`-l A`, `--validateMappings`) are currently fixed implementation choices and should be documented as defaults or promoted to schema fields if flexibility is needed
- Resume/skip behavior based on existing `quant.sf` is an important operational convention and should be documented
- Logging/metadata pattern remains stage-local (`run_info.txt`) and is not yet unified with wrapper-level metadata capture
- Dry-run support exists at stage level but is not currently surfaced by wrapper

---

## File: scripts/star_align.sh

### Summary
Stage-level alignment script using STAR. CLI-driven tool invoked by wrapper. Assumes paired-end bulk RNA-seq FASTQs with `_1/_2` naming and runs one STAR alignment per sample.

---

### Parameterization

**INPUT (via CLI)**
- INPUT_DIR (-i)

**OUTPUT (via CLI)**
- OUTPUT_DIR (-o)
- RUN_ID (--run-id)

**REF (via CLI)**
- REF_INDEX (-r)

**RESOURCE (via CLI)**
- THREADS (-t)

**RUN / EXECUTION**
- DRY_RUN (--dry-run)

---

### Hard-coded / Embedded Assumptions

**RUN**
- Default THREADS=8 (overridden by wrapper)
- Default RUN_ID generated from timestamp if not provided
- Samples processed in sorted deterministic order
- Existing sample alignment is skipped if both completion markers exist:
  - `Aligned.sortedByCoord.out.bam`
  - `Log.final.out`
- Continues across samples and records failures
- Exits nonzero (`exit 10`) if one or more samples fail

**INPUT**
- Paired-end input required
- R1 pattern limited to:
  - `*_1.fq.gz`
  - `*_1.fastq.gz`
- R2 inferred strictly as:
  - `*_2.fq.gz`
  - `*_2.fastq.gz`
- Requires exact mate-pair naming convention
- Single-end input not supported
- Assumes gzip-compressed FASTQs readable via `zcat`

**REF**
- Reference input must be a STAR genome index directory

**OUTPUT**
- Stage output structure:
  - `${OUTPUT_DIR}/${RUN_ID}`
  - per-sample subdirectories under RUN_DIR
  - `logs/`
- Expected primary completion files:
  - `Aligned.sortedByCoord.out.bam`
  - `Log.final.out`
- Optional/expected gene-count output:
  - `ReadsPerGene.out.tab`

**LOG**
- Fixed per-sample log naming:
  - `logs/<sample>.star.log`
- Stage-level metadata file:
  - `run_info.txt`

**ANALYSIS / ALIGNMENT**
- Alignment tool fixed as `STAR`
- Compressed input handling fixed as:
  - `--readFilesCommand zcat`
- Output BAM mode fixed as:
  - `--outSAMtype BAM SortedByCoordinate`
- Output SAM attributes fixed as:
  - `--outSAMattributes NH HI AS nM`
- Gene counting requested by default:
  - `--quantMode GeneCounts`
- Alignment performed one sample at a time

**RESOURCE / ENVIRONMENT**
- Tool must exist in PATH:
  - `STAR`

**EXECUTION CONTEXT**
- Assumes sample identity can be derived from R1 basename by removing `_1.fq.gz` or `_1.fastq.gz`

---

### Notes / Design Implications

- This script is explicitly bulk paired-end oriented
- Mate-pair naming convention is now repeated across trim, Salmon, and STAR and should likely be formalized centrally
- STAR runtime options are fixed implementation choices and should be documented as defaults or promoted to schema fields only if future flexibility is required
- Resume/skip behavior based on BAM + `Log.final.out` is an important operational convention
- `ReadsPerGene.out.tab` is requested but not treated as a hard requirement, which should be documented explicitly
- Logging/metadata pattern remains stage-local (`run_info.txt`) and is not yet unified with wrapper-level metadata capture
- Dry-run support exists at stage level but is not currently surfaced by wrapper

---

## File: scripts/tximport_genelevel.R

### Summary
Stage-level gene-level summarization script using tximport. CLI-driven tool invoked by wrapper. Assumes Salmon per-sample output directories containing `quant.sf` and a transcript-to-gene mapping table.

---

### Parameterization

**INPUT (via CLI)**
- salmon_dir (-i)
- optional sample list (--samples-txt)

**OUTPUT (via CLI)**
- out_root (-o)
- run_id (--run-id)

**REF (via CLI)**
- tx2gene_tsv (-m)

**ANALYSIS**
- counts_from_abundance (--counts-from-abundance)

**RUN / EXECUTION**
- dry_run (--dry-run)

---

### Hard-coded / Embedded Assumptions

**RUN**
- Default thread placeholder set to 1, though tximport itself is not threaded
- Default run_id generated from timestamp if not provided

**INPUT**
- Expects Salmon outputs under:
  - `salmon_dir/<sample>/quant.sf`
- If `--samples-txt` is not provided, samples are auto-discovered by scanning for `quant.sf`
- Sample discovery assumes immediate child sample directories under salmon_dir
- All discovered quant.sf files must exist and be non-empty

**REF**
- tx2gene input must be a TSV-like file with at least 2 columns
- First two columns are interpreted as:
  - TXNAME
  - GENEID
- Transcript version suffixes are stripped from TXNAME using:
  - `sub("\\.[0-9]+$", "", TXNAME)`

**OUTPUT**
- Stage output structure:
  - `${out_root}/${run_id}`
  - `logs/`
- Fixed output files:
  - `gene_counts.csv`
  - `gene_tpm.csv` (if abundance present)
  - `run_info.txt`
  - `logs/tximport.log`

**LOG**
- Logging captured through sink() into:
  - `logs/tximport.log`
- Stage-level metadata file:
  - `run_info.txt`

**ANALYSIS**
- tximport type fixed as:
  - `type = "salmon"`
- Default tximport options fixed as:
  - `ignoreTxVersion = TRUE`
  - `dropInfReps = TRUE`
- `countsFromAbundance` is optional and configurable via CLI
- Produces gene-level counts and abundance matrices

**RESOURCE / ENVIRONMENT**
- Hard-coded R library path:
  - `~ /R/x86_64-pc-linux-gnu-library/4.1`
- Requires R packages:
  - `tximport`
  - `readr`

**EXECUTION CONTEXT**
- Assumes R runtime can load packages from the specified .libPaths entry
- Assumes Salmon stage output format is stable and consistent

---

### Notes / Design Implications

- This script is tightly coupled to the current Salmon output convention and should remain aligned with that stage
- Hard-coded `.libPaths()` is an important environment assumption and should likely be removed or externalized
- Transcript version stripping is a biologically meaningful normalization rule and should be explicitly documented in schema/design notes
- tximport defaults (`ignoreTxVersion`, `dropInfReps`) are currently implementation choices and should be documented as defaults unless future flexibility is required
- Logging/metadata pattern remains stage-local (`run_info.txt`) and is not yet unified with wrapper-level metadata capture
- This stage is the clearest example so far of ANALYSIS-specific parameters that may belong in the unified schema

---

## File: config/pipeline.env

### Summary
Current central wrapper configuration file. Defines core execution settings for the bulk RNA-seq wrapper, but remains flat, pilot-oriented, and incomplete relative to a fully unified schema.

---

### Current Coverage

**RUN**
- THREADS
- RUN_ID
- DO_QC_RAW
- DO_TRIM
- DO_QC_POSTTRIM
- DO_SALMON
- DO_TXIMPORT
- DO_STAR

**INPUT**
- PILOT_FASTQ_DIR

**OUTPUT**
- QC_OUT_ROOT
- TRIM_OUT_ROOT
- SALMON_OUT_ROOT
- TXIMPORT_OUT_ROOT
- STAR_OUT_ROOT

**REF**
- SALMON_INDEX
- TX2GENE
- STAR_INDEX

---

### Hard-coded / Embedded Assumptions Reflected in Current Config Design

**RUN**
- Configuration structure is flat shell-variable based, not sectioned by schema category
- RUN_ID default is generated in config using shell date expansion

**INPUT**
- Input naming remains pilot-oriented:
  - `PILOT_FASTQ_DIR`

**OUTPUT**
- Output roots are stage-specific and test-oriented:
  - `results/qc_test`
  - `results/trim_test`
  - `results/salmon_test`
  - `results/tximport_test`
  - `results/star_test`

**REF**
- Reference paths mix:
  - absolute paths (`/home/summitadmin/...`)
  - `$HOME/...`
  - repo-relative `$PWD/...`

**CONFIG DESIGN**
- Covers wrapper-level execution only
- Does not currently define:
  - FASTQ naming conventions
  - localization/integrity parameters
  - input selection policy (`raw|trimmed`)
  - logging conventions
  - stage-level runtime options
  - downstream analysis parameters
  - QC thresholds
  - analysis toggles beyond wrapper execution stages

---

### Notes / Design Implications

- Current config is a strong transitional starting point but not yet a complete unified schema
- Current file is wrapper-centric rather than full-pipeline in scope
- Variable naming remains pilot/test oriented and should likely be generalized for hardened use
- Mixed path styles reduce portability and should be standardized where possible
- RUN_ID default generation is currently duplicated across config, wrapper, and stage scripts and should be normalized in the final design
- Task 2 should define a canonical schema that supersedes the current flat structure while remaining easy to load from shell

---

## File: analysis/01_build_analysis_object.R

### Summary
Downstream analysis script that builds a DESeq2 analysis object and VST-transformed object from tximport gene-level counts. Currently highly analysis-specific and largely hard-coded.

---

### Parameterization

Current state:
- No formal CLI or central config loading
- Script is driven by embedded paths and analysis choices

---

### Hard-coded / Embedded Assumptions

**INPUT**
- Fixed counts input path:
  - `results/tximport/txi_crc150_salmon_20260223/gene_counts.csv`
- Assumes tximport output is a CSV count matrix with genes as rownames and samples as columns

**OUTPUT**
- Fixed output object paths:
  - `analysis_objects/dds_crc_vs_hep_20260225.rds`
  - `analysis_objects/vsd_crc_vs_hep_20260225.rds`
- Uses `analysis_objects/` as fixed output directory

**METADATA / INPUT INTERPRETATION**
- Metadata is inferred from sample names rather than loaded from an external sample sheet
- Sample naming assumptions:
  - `cell_line` = prefix before first underscore
  - `dose` = token matching `D1/D2/D3/D4/DMSO`
  - `replicate` = final numeric token
- Assumes sample IDs are structured consistently enough to support regex parsing

**ANALYSIS**
- Allowed cell lines hard-coded as:
  - `Hep`
  - `SW48`
  - `SW480`
  - `SW1116`
- Implicitly excludes other lines (e.g. `THLE_2`)
- Gene filtering rule fixed as:
  - keep genes with count >= 10 in at least 2 samples
- Count matrix converted to integer by rounding before DESeq2
- DESeq2 design fixed as:
  - `~ cell_line`
- Reference level fixed as:
  - `Hep`
- DESeq model is run immediately in this script
- VST settings fixed as:
  - `blind = FALSE`

**RESOURCE / ENVIRONMENT**
- Requires R package:
  - `DESeq2`

**EXECUTION CONTEXT**
- Assumes counts matrix is already cleaned enough for DESeq2 except for empty gene IDs
- Assumes analysis can be driven from inferred metadata without a formal metadata file

---

### Notes / Design Implications

- This is the strongest example so far that downstream analysis parameters must be included in the unified schema
- Metadata derivation from sample names is a major implicit dependency and should either:
  - be formalized as a supported parsing rule, or
  - be replaced by explicit metadata input
- Cell-line inclusion/exclusion should likely become configurable
- Gene filtering thresholds should become explicit ANALYSIS or QC schema fields
- DESeq2 design formula and reference level should become explicit ANALYSIS schema fields
- Output object naming should be made run-based and systematic rather than manually date-labeled

---

## File: analysis/01b_vst_diagnostics.R

### Summary
Downstream QC/diagnostic script that generates a mean-SD plot from a saved VST object. Currently simple and fully path-driven.

---

### Parameterization

Current state:
- No formal CLI or central config loading
- Script is driven by embedded input/output paths

---

### Hard-coded / Embedded Assumptions

**INPUT**
- Fixed VST object path:
  - `analysis_objects/vsd_crc_vs_hep_20260225.rds`

**OUTPUT**
- Fixed QC output directory:
  - `results/qc`
- Fixed output filename:
  - `mean_sd_vst_plot.png`

**ANALYSIS / QC**
- Diagnostic plot type fixed as:
  - mean-SD plot on `assay(vsd)`

**RESOURCE / ENVIRONMENT**
- Requires R packages:
  - `DESeq2`
  - `SummarizedExperiment`
  - `vsn`

**EXECUTION CONTEXT**
- Assumes VST object exists and is readable as an RDS file
- Assumes `assay(vsd)` is valid input for `meanSdPlot()`

---

### Notes / Design Implications

- This script is simple but reinforces that downstream QC outputs should be included in the unified schema
- Input object path and output figure directory should become configurable
- QC figure naming conventions should likely be standardized under OUTPUT/LOG or QC

---

## File: analysis/02_pca_qc.R

### Summary
Downstream QC/visualization script that generates a PCA plot and PCA score table from a saved VST object. Currently path-driven and analysis-specific.

---

### Parameterization

Current state:
- No formal CLI or central config loading
- Script is driven by embedded input/output paths and plotting choices

---

### Hard-coded / Embedded Assumptions

**INPUT**
- Fixed VST object path:
  - `analysis_objects/vsd_crc_vs_hep_20260225.rds`

**OUTPUT**
- Fixed QC output directory:
  - `results/qc`
- Fixed PCA figure filename:
  - `pca_crc_vs_hep.png`
- Fixed PCA score table filename:
  - `pca_scores_crc_vs_hep.csv`

**ANALYSIS / QC**
- PCA grouping variable fixed as:
  - `cell_line`
- PCA uses:
  - `plotPCA(vsd, intgroup = "cell_line", returnData = TRUE)`
- Plot title fixed as:
  - `PCA (VST): SW48 / SW480 / SW1116 vs Hep`
- Plot aesthetics fixed:
  - color mapped to `cell_line`
  - point size = 3
  - alpha = 0.9
  - `theme_bw()`

**RESOURCE / ENVIRONMENT**
- Requires R packages:
  - `DESeq2`
  - `ggplot2`
  - `SummarizedExperiment`

**EXECUTION CONTEXT**
- Assumes VST object exists and is readable as an RDS file
- Assumes `cell_line` exists in colData(vsd)
- Assumes PCA on the current VST object is an appropriate QC summary

---

### Notes / Design Implications

- PCA grouping variable should likely become an ANALYSIS or QC schema field
- Output figure/table naming should be standardized and run-based
- Plot title is currently analysis-specific and should not remain hard-coded
- This script reinforces the need for configurable downstream QC output locations

---

## File: analysis/03_differential_expression.R

### Summary
Downstream differential expression script that runs DESeq2 contrasts from a saved DESeq2 object and exports per-contrast result tables plus a summary table. Currently highly analysis-specific and hard-coded.

---

### Parameterization

Current state:
- No formal CLI or central config loading
- Script is driven by embedded input/output paths and fixed contrast logic

---

### Hard-coded / Embedded Assumptions

**INPUT**
- Fixed DESeq2 object path:
  - `analysis_objects/dds_crc_vs_hep_20260225.rds`

**OUTPUT**
- Fixed DE output directory:
  - `results/de`
- Fixed output naming convention for contrast result tables:
  - `DESeq2_<contrast>_unshrunk.csv`
  - `DESeq2_<contrast>_lfcShrink_apeglm.csv`
- Fixed pooled output filenames:
  - `DESeq2_PooledCRC_vs_Hep_unshrunk.csv`
  - `DESeq2_PooledCRC_vs_Hep_lfcShrink_apeglm.csv`
- Fixed summary filename:
  - `DESeq2_contrast_summary.csv`

**ANALYSIS**
- Assumes DESeq2 object contains:
  - `cell_line`
- Reference level fixed as:
  - `Hep`
- Per-cell-line contrasts hard-coded as:
  - `SW48_vs_Hep`
  - `SW480_vs_Hep`
  - `SW1116_vs_Hep`
- Additional pooled contrast hard-coded as:
  - `PooledCRC_vs_Hep`
- Pooled model is built by collapsing all non-Hep cell lines into:
  - `CRC`
- Pooled design fixed as:
  - `~ group2`
- Unshrunk DESeq2 results always exported
- LFC shrinkage attempted only if `apeglm` is installed
- Shrinkage type fixed as:
  - `type = "apeglm"`
- Coefficient naming convention assumed for shrinkage:
  - `cell_line_<case>_vs_<ref>`
  - `group2_CRC_vs_Hep`

**SIGNIFICANCE / THRESHOLDS**
- Summary significance threshold fixed as:
  - `padj < 0.05`
- Additional summary effect-size threshold fixed as:
  - `abs(log2FoldChange) >= 1`

**RESOURCE / ENVIRONMENT**
- Requires R package:
  - `DESeq2`
- Optionally uses:
  - `apeglm`

**EXECUTION CONTEXT**
- Assumes the DESeq2 object is already fitted and ready for results extraction
- Assumes current grouping structure is appropriate for both individual contrasts and pooled CRC-vs-Hep modeling
- Assumes coefficient names follow DESeq2 defaults derived from factor levels

---

### Notes / Design Implications

- Contrast definitions clearly need to become explicit ANALYSIS schema fields
- Reference group should become configurable
- Pooled-group analysis should be configurable rather than embedded
- Summary significance thresholds (`padj`, `|log2FC|`) should become explicit schema fields
- Shrinkage behavior should be documented as configurable or defaulted in the final schema
- Output file naming should be standardized and run-based rather than manually analysis-labeled

---

## File: analysis/04_gsea_fgsea.R

### Summary
Downstream GSEA script using fgsea. Accepts limited CLI overrides (`--key=value`) but still contains many embedded assumptions about DE input structure, identifier mapping, ranking behavior, pathway inputs, and output organization.

---

### Parameterization

**INPUT / ANALYSIS (via CLI overrides)**
- `de_csv`
- `run_id`
- `gmt_file`
- `rank_by`
- `min_size`
- `max_size`

Current defaults if not overridden:
- `DE_CSV = results/de/DESeq2_PooledCRC_vs_Hep_unshrunk.csv`
- `RUN_ID = <current date YYYYMMDD>`
- `GMT_FILE = results/gsea/msigdb/REPLACE_WITH_GMT_FILENAME.gmt`
- `RANK_BY = log2FoldChange`
- `MIN_SIZE = 15`
- `MAX_SIZE = 500`

---

### Hard-coded / Embedded Assumptions

**INPUT**
- Default DE input file fixed as:
  - `results/de/DESeq2_PooledCRC_vs_Hep_unshrunk.csv`
- Assumes DE input is tabular and readable via `data.table::fread`
- Gene column is guessed from a fixed candidate list:
  - `gene`, `Gene`, `symbol`, `SYMBOL`, `gene_symbol`, `hgnc_symbol`, `external_gene_name`, `X`, `V1`, `Row.names`, `rowname`, `row.names`, `Unnamed: 0`, `...1`
- If no expected gene column is found, first column is used as gene identifier
- Assumes DE input contains a usable ranking column
- If `rank_by = log2FoldChange` but a `stat` column exists, script automatically switches to `stat`

**REF / GENE SETS**
- Default GMT location fixed under:
  - `results/gsea/msigdb/`
- Assumes GMT uses HGNC gene symbols
- Assumes ranked genes may be Ensembl IDs with version suffixes
- Strips Ensembl version suffixes from gene IDs using:
  - `sub("\\.[0-9]+$", "", gene_raw)`
- Maps Ensembl IDs to HGNC symbols using:
  - `org.Hs.eg.db`
  - `AnnotationDbi::mapIds(..., keytype = "ENSEMBL", column = "SYMBOL")`
- Keeps first mapping when multiple mappings exist (`multiVals = "first"`)

**ANALYSIS**
- GSEA engine fixed as:
  - `fgseaMultilevel`
- Rank deduplication rule fixed as:
  - keep one row per symbol using max absolute rank
- Size filters default to:
  - `minSize = 15`
  - `maxSize = 500`
- Results sorted by:
  - `padj`, then descending `abs(NES)`
- Top plot threshold fixed as:
  - `padj < 0.05`
- Plot includes at most top 30 enriched pathways

**OUTPUT**
- Output structure fixed as:
  - `results/gsea/<RUN_ID>/tables`
  - `results/gsea/<RUN_ID>/plots`
  - `results/gsea/<RUN_ID>/rds`
  - `results/gsea/ranks`
  - `results/gsea/logs`
  - `results/gsea/msigdb`
- Fixed output naming conventions:
  - `<RUN_ID>_ranks_<rank_col>.csv`
  - `<RUN_ID>_fgsea_<rank_col>.csv`
  - `<RUN_ID>_fgsea_<rank_col>.rds`
  - `<RUN_ID>_topNES_<rank_col>.png`

**LOG / DIAGNOSTICS**
- Uses `message()` output for run logging but does not currently write to a dedicated log file despite defining `OUT_LOGS`
- Reports overlap between ranked genes and pathway genes
- Warns when overlap is low (`< 1000` genes)

**RESOURCE / ENVIRONMENT**
- Requires R packages:
  - `fgsea`
  - `data.table`
  - `ggplot2`
  - `AnnotationDbi`
  - `org.Hs.eg.db`

**EXECUTION CONTEXT**
- Assumes human annotation (`org.Hs.eg.db`)
- Assumes symbol-based GMTs and Ensembl-derived DE gene identifiers
- Assumes current DE export structure is compatible with automated gene/rank column detection

---

### Notes / Design Implications

- This script strongly supports adding a dedicated `ANALYSIS.GSEA` section to the unified schema
- Ranking metric should be explicit in schema and auto-switch behavior should be documented clearly if retained
- Species/annotation dependency is currently human-specific and should become explicit if cross-species support is desired
- Gene identifier normalization and mapping rules are important hidden assumptions and should be documented in the final design
- GMT path, min/max gene set sizes, and plot thresholds should become explicit configurable fields
- Output organization for GSEA is relatively structured already and can likely serve as the basis for standardized downstream output conventions
- `OUT_LOGS` is defined but not actually used for a persistent log file, suggesting an incomplete logging design

---

## File: analysis/05_gsea_summary_tables.R

### Summary
Downstream reporting script that aggregates fgsea outputs across multiple contrasts and produces shared-pathway summary tables, wide-format comparison tables, and ranked summary exports for Hallmark and Reactome results. Currently highly study-specific and hard-coded.

---

### Parameterization

Current state:
- No formal CLI or central config loading
- Script is driven by embedded file-discovery rules, contrast assumptions, thresholds, and output conventions

---

### Hard-coded / Embedded Assumptions

**INPUT**
- Searches recursively under:
  - `results/gsea`
- Restricts fgsea inputs to files matching:
  - `_fgsea_stat.csv`
- Further restricts files to runs matching:
  - `_20260226`
- Assumes fgsea result tables are readable by `data.table::fread`

**OUTPUT**
- Fixed output directory:
  - `results/gsea/summary`
- Fixed output files include:
  - `gsea_all_significant_pathways.csv`
  - `gsea_shared_hallmark_all4_same_direction.csv`
  - `gsea_shared_reactome_all4_same_direction.csv`
  - `gsea_shared_hallmark_all4_same_direction_wide.csv`
  - `gsea_shared_reactome_all4_same_direction_wide.csv`
  - `gsea_top10_hallmark_by_pooled_absNES.csv`
  - `gsea_top20_reactome_by_NES_range.csv`
  - `gsea_hallmark_NES_matrix.csv`
  - `gsea_reactome_NES_matrix.csv`

**ANALYSIS / GSEA SUMMARY**
- Collection is inferred from `run_id` using name matching:
  - `hallmark` -> Hallmark
  - otherwise -> Reactome
- Contrast label is inferred from `run_id` by stripping:
  - `_(hallmark|reactome)_.*`
- Direction is defined as:
  - `NES > 0` -> `Up_in_CRC`
  - else -> `Down_in_CRC`
- Significance threshold fixed as:
  - `padj <= 0.05`
- Shared-pathway logic fixed as:
  - pathway must appear in all 4 contrasts
  - pathway must have the same direction in all 4 contrasts
- Number of required contrasts fixed as:
  - `4`

**CONTRAST STRUCTURE**
- Pooled contrast label fixed as:
  - `crc_vs_hep_pooled`
- Contrast order fixed as:
  - `crc_vs_hep_pooled`
  - `sw48_vs_hep`
  - `sw480_vs_hep`
  - `sw1116_vs_hep`
- Delta NES calculations are always relative to pooled contrast
- Hallmark ranking summary fixed as:
  - top 10 by pooled absolute NES
  - fallback to mean absolute NES if pooled absent
- Reactome ranking summary fixed as:
  - top 20 by NES range

**TABLE CONSTRUCTION**
- Wide tables pivot on:
  - `pathway ~ contrast`
- Wide tables include:
  - NES
  - padj
  - direction
  - dNES_vs_pooled
  - NES_range
  - closest_to_pooled
  - most_divergent_from_pooled
- NES matrices are generated separately for:
  - Hallmark
  - Reactome

**RESOURCE / ENVIRONMENT**
- Requires R package:
  - `data.table`

**EXECUTION CONTEXT**
- Assumes fgsea run IDs encode both contrast and collection in a consistent naming format
- Assumes there are exactly four expected contrasts in the current study design
- Assumes pooled CRC comparison is present or meaningful for summary ranking logic
- Assumes Hallmark and Reactome are the only relevant collections for current summaries

---

### Notes / Design Implications

- This script is highly specific to the current CRC-vs-Hep analysis and should not remain hard-coded in a hardened generic pipeline
- GSEA summary/reporting rules should become configurable if this reporting layer is meant to persist
- Contrast order, pooled-label semantics, and required number of contrasts are strong candidates for schema fields
- File-discovery by hard-coded date substring (`_20260226`) should be removed in favor of explicit run selection
- Hallmark/Reactome collection inference from run naming should be replaced with explicit metadata where possible
- This script suggests the pipeline may need a distinct `REPORTING` or `SUMMARY` subsection within ANALYSIS if these outputs are considered part of the supported workflow

---

## File: analysis/06_gsea_heatmaps.R

### Summary
Downstream reporting/visualization script that generates GSEA heatmaps from summary tables for Hallmark and Reactome pathways. Currently fully path-driven and study-specific.

---

### Parameterization

Current state:
- No formal CLI or central config loading
- Script is driven by embedded input/output paths, contrast order, filtering rules, and plotting choices

---

### Hard-coded / Embedded Assumptions

**INPUT**
- Fixed summary input directory:
  - `results/gsea/summary`
- Fixed Hallmark input file:
  - `gsea_shared_hallmark_all4_same_direction_wide.csv`
- Fixed Reactome input file:
  - `gsea_shared_reactome_all4_same_direction_wide.csv`

**OUTPUT**
- Fixed figure output directory:
  - `results/gsea/figures`
- Fixed figure prefixes:
  - `hallmark_shared_heatmap`
  - `reactome_shared_top40_heatmap`
- Each figure is written as both:
  - `.pdf`
  - `.png`

**ANALYSIS / REPORTING**
- Contrast order fixed as:
  - `crc_vs_hep_pooled`
  - `sw48_vs_hep`
  - `sw480_vs_hep`
  - `sw1116_vs_hep`
- Hallmark heatmap uses all shared pathways from input summary table
- Reactome heatmap is restricted to:
  - top 40 pathways by `NES_range`
- Reactome top-N threshold fixed as:
  - `TOP_N_REACTOME = 40`
- Heatmap values are symmetrically capped at:
  - `cap = 3`
- Heatmap uses NES values only
- Requires at least 2 NES columns to plot

**PLOTTING**
- Color palette fixed as blue-white-red:
  - `#2C7BB6`
  - `#FFFFFF`
  - `#D7191C`
- Clustering fixed as:
  - `cluster_rows = TRUE`
  - `cluster_cols = TRUE`
- Scale fixed as:
  - `scale = "none"`
- Font sizes fixed as:
  - `fontsize_row = 7`
  - `fontsize_col = 10`
- Border color fixed as:
  - `NA`
- Breaks fixed as:
  - `seq(-cap, cap, length.out = 102)`

**RESOURCE / ENVIRONMENT**
- Requires R packages:
  - `data.table`
  - `pheatmap`

**EXECUTION CONTEXT**
- Assumes GSEA summary tables already exist and have stable wide-format structure
- Assumes columns named `NES_<contrast>` are present or derivable using the expected contrast order
- Assumes `NES_range` is present in the Reactome summary table

---

### Notes / Design Implications

- This script confirms that downstream reporting/figure-generation conventions should be part of the full pipeline design if these outputs are considered supported deliverables
- Contrast order should become a configurable reporting parameter rather than a hard-coded assumption
- Heatmap styling could remain a fixed house standard, but should still be documented explicitly
- Reactome top-N selection should become configurable if this script is intended for reuse beyond the current study
- Output figure locations and names should be standardized under the final OUTPUT schema
