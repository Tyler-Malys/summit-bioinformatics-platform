# Delcath Pipeline Repository Mapping — Current to Target (2026-03-17)

## Purpose
Map current repository contents for the canonical bulk RNA-seq and scRNA-seq repos into the target canonical repository structure.

---

# 1. Bulk RNA-seq Repo
Current repo: delcath_crc_bulk_rnaseq_2026-02

## Top-level directories

### analysis/
- Status: keep but reclassify
- Likely target: scripts/downstream/ or retained analysis/ if downstream analysis remains a distinct repo code area
- Action: treat as reusable downstream analysis script directory, not output-like content

### analysis_objects/
- Status: non-canonical
- Likely target: externalize later or move under data/working/output model outside repo
- Action: treat as output/intermediate object area, not long-term repo structure

### config/
- Status: keep
- Likely target: config/
- Action: retain; use as model for standard config structure

### data/
- Status: transitional
- Likely target: externalize later
- Action: keep temporarily; not part of final canonical repo layout for production-style execution

### docs/
- Status: keep
- Likely target: docs/
- Action: retain and normalize substructure over time

### logs/
- Status: non-canonical
- Likely target: externalize later
- Action: remove from long-term repo architecture

### notes/
- Status: non-essential / currently empty
- Likely target: remove or fold into docs/ if needed later
- Action: do not preserve as a canonical top-level directory unless populated with meaningful documentation

### results/
- Status: non-canonical
- Likely target: externalize later
- Action: remove from long-term repo architecture

### scripts/
- Status: keep but refactor
- Likely target: scripts/
- Action: reorganize into wrappers/, qc/, preprocessing/, alignment/, quantification/, downstream/, legacy/

### star_pilot/
- Status: confirmed non-canonical pilot artifact
- Likely target: archive/reference only; external validation or legacy area if retained
- Action: do not preserve as canonical repo structure

## Top-level files

### README.md
- Status: keep
- Likely target: root README.md

### .gitignore
- Status: keep
- Likely target: root .gitignore

### pilot_fastqs.txt / pilot_fastqs.clean.txt
- Status: non-canonical at repo root
- Likely target: examples/ or docs/inputs/ or externalized metadata location
- Action: relocate later

### salmon_crc150.log
- Status: non-canonical at repo root
- Likely target: external run/log area
- Action: remove from repo root

## scripts/ mapping

### run_pilot_wrapper.sh
### run_pilot_wrapper_v2.sh
- Status: keep but move
- Likely target: scripts/wrappers/

### qc_fastq.sh
- Status: keep but move
- Likely target: scripts/qc/

### trim_fastp.sh
- Status: keep but move
- Likely target: scripts/preprocessing/

### star_align.sh
- Status: keep but move
- Likely target: scripts/alignment/

### salmon_quant.sh
- Status: keep but move
- Likely target: scripts/quantification/

### tximport_genelevel.R
- Status: keep but move
- Likely target: scripts/downstream/

### *.v0 / *.bak
- Status: non-canonical active files
- Likely target: scripts/legacy/ or remove if safely preserved in git

### scripts/legacy/*
- Status: keep as transitional archive
- Likely target: scripts/legacy/

---

# 2. scRNA-seq Repo
Current repo: delcath_scrnaseq_dev_2026-03

## Top-level directories

### analysis/
- Status: mixed-content / non-canonical as currently structured
- Likely target: split into code components and externalized output/object/figure areas
- Action: move reusable scripts into scripts/downstream/ or similar; treat objects, figures, markers, metrics, and QC outputs as non-canonical repo-local artifacts for later externalization

### config/
- Status: keep
- Likely target: config/
- Action: retain; expand to match stronger bulk config model later

### data/
- Status: transitional
- Likely target: externalize later
- Action: keep temporarily; not final production-style repo structure

### docs/
- Status: keep
- Likely target: docs/
- Action: retain and normalize substructure over time

### logs/
- Status: non-canonical
- Likely target: externalize later
- Action: remove from long-term repo architecture

### metadata/
- Status: keep but normalize
- Likely target: config/, examples/, or retained metadata/ if run-manifest inputs are promoted to a first-class canonical concept
- Action: treat as useful input/run-manifest metadata, not clutter

### pbmc_1k_v3_GRCh38g49/
- Status: non-canonical at repo top level
- Likely target: externalized data/run/example area
- Action: remove from long-term repo root

### qc/
- Status: non-essential / currently empty
- Likely target: remove unless later used meaningfully
- Action: do not preserve as a canonical top-level directory in current form

### raw/
- Status: non-canonical
- Likely target: externalized raw data location
- Action: remove from long-term repo architecture

### ref/
- Status: non-canonical
- Likely target: canonical shared reference location outside repo
- Action: remove from long-term repo architecture

### results/
- Status: non-canonical
- Likely target: externalize later
- Action: remove from long-term repo architecture

### runs/
- Status: non-canonical
- Likely target: canonical run root outside repo
- Action: remove from long-term repo architecture

### scripts/
- Status: keep
- Likely target: scripts/
- Action: use as baseline model for canonical script organization

### validation/
- Status: non-essential / currently empty
- Likely target: remove unless later used meaningfully; future validation assets could live under tests/ or docs/validation/
- Action: do not preserve as a canonical top-level directory in current form

## Top-level files

### README.md
- Status: keep
- Likely target: root README.md

### .gitignore
- Status: keep
- Likely target: root .gitignore

### VERSION
- Status: keep
- Likely target: root VERSION or future run/version metadata model

### __pbmc_1k_v3_GRCh38g49.mro
- Status: non-canonical at repo root
- Likely target: scripts/alignment/, examples/, or external workflow artifact location depending on role
- Action: inspect before deciding

## scripts/ mapping

### run_cellranger_from_manifest.sh
- Status: keep but move
- Likely target: scripts/wrappers/

### scripts/cellranger/*
- Status: keep
- Likely target: scripts/alignment/ or scripts/cellranger/ depending on final decision

### scripts/starsolo/*
- Status: keep
- Likely target: scripts/alignment/ or scripts/starsolo/ depending on final decision

### scripts/qc/*
- Status: keep
- Likely target: scripts/qc/

### scripts/downstream/*
- Status: keep
- Likely target: scripts/downstream/

### scripts/utils/
- Status: keep
- Likely target: scripts/utils/

---

## Provisional cross-repo standardization decisions

### Bulk RNA-seq will borrow from scRNA-seq:
- stage-grouped script layout
- stronger modular separation inside scripts/

### scRNA-seq will borrow from bulk RNA-seq:
- stronger configuration structure
- more developed config template/test pattern

### Both repos:
- should retain README.md and .gitignore at root
- should converge on config/, docs/, scripts/ as the core root directories
- should gradually remove repo-local logs/results/runs/raw/ref from final architecture
