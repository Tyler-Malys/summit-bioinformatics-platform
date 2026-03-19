# Delcath Canonical Server Layout — v1

## Purpose
Define the canonical server-level filesystem architecture for Delcath bioinformatics pipelines, including repositories, runs, references, environments, tools, and shared documentation.

---

## Design Principles

- Separate pipeline source code from run outputs
- Separate shared references from pipeline-specific repositories
- Separate environment/tool installations from repositories
- Support multiple pipelines with parallel structure
- Support future production/shared releases derived from canonical working sources

---

## Canonical Server Layout

/home/summitadmin/
  bioinformatics_projects/
    delcath_crc_bulk_rnaseq_2026-02/
    delcath_scrnaseq_dev_2026-03/
    architecture_inventory_2026-03-17.md
    architecture_target_repo_structure.md
    architecture_repo_mapping_2026-03-17.md
    architecture_decisions_2026-03-17.md
    architecture_target_server_layout.md

  refs/
    human/
      grch38/
        gencode_v45/
          salmon_index/
          star_index/
          tx2gene/
          annotation/
    mouse/
      mm10/
        gencode_vM*/
          salmon_index/
          star_index/
          tx2gene/
          annotation/

  miniconda3/
    envs/

  bioinformatics_tools/
    cellranger-10.0.0/
    sratoolkit/
    other_shared_tools/

---

## Canonical Logical Zones

### 1. Repository Zone
Current root:
- /home/summitadmin/bioinformatics_projects/

Purpose:
- canonical working pipeline repositories
- architecture and planning notes
- source-controlled code, config, and docs

Should contain:
- pipeline repos
- architecture notes
- repository-local docs/config/scripts

Should NOT contain long-term:
- production run outputs
- raw data dumps
- reference genomes
- large intermediate objects
- stable shared tools

---

### 2. Reference Zone
Current root:
- /home/summitadmin/refs/

Purpose:
- shared reference genomes
- annotations
- transcript-to-gene maps
- STAR and Salmon indices
- organism/build/version-specific reference assets

Design rule:
- reference assets should be centralized and reusable across pipelines
- pipeline repos should not carry their own permanent ref/ directories

Future desired structure:
- refs/<organism>/<build>/<annotation_version>/

---

### 3. Environment Zone
Current root:
- /home/summitadmin/miniconda3/envs/

Purpose:
- conda environments used by pipeline execution

Design rule:
- environments are part of server infrastructure, not individual repos
- environment naming should be standardized later in Environment Modernization & Version Control

Possible future naming:
- bulk_rnaseq_env
- scrnaseq_env
- shared_bioinfo_env

---

### 4. Tool Zone
Current root:
- /home/summitadmin/bioinformatics_tools/
- /home/summitadmin/sratoolkit.3.3.0-ubuntu64/   (currently outside canonical tool root)

Purpose:
- third-party software installations not managed entirely through conda
- cellranger
- sratoolkit
- other large external tool distributions

Design rule:
- large shared tools should live in a dedicated tool root, not inside repos

Future normalization target:
- move standalone tool installs into bioinformatics_tools/ over time where practical

---

### 5. Run Zone
Current state:
- repo-local logs/, results/, runs/, raw/, analysis objects, pilot artifacts

Target state:
- runs should eventually move outside repos into a canonical run root

Future desired structure:
/home/summitadmin/bioinformatics_runs/
  bulk_rnaseq/
    <run_id>/
  scrnaseq/
    <run_id>/

Inside each run:
- input/
- working/
- logs/
- qc/
- outputs/
- downstream/
- final/
- run_metadata/

Design rule:
- repositories define logic
- run directories hold execution artifacts

---

## Transitional Reality

Current repositories still contain repo-local:
- logs/
- results/
- raw/
- ref/
- runs/
- analysis objects
- pilot validation artifacts

These are transitional and should be externalized gradually during hardening rather than moved all at once.

---

## Canonical Working Rule

For Phase 3 hardening:
- delcath_crc_bulk_rnaseq_2026-02 is the canonical bulk RNA-seq development source
- delcath_scrnaseq_dev_2026-03 is the canonical scRNA-seq development source
- delcath_bulk_rnaseq is legacy/reference only
- shared/client-facing distributions should be generated later from hardened canonical sources

---

## Near-Term Implementation Guidance

### Keep as current canonical roots for now
- bioinformatics_projects/
- refs/
- miniconda3/envs/
- bioinformatics_tools/

### Do not yet perform large filesystem moves
- avoid disruptive migration during architecture-definition phase
- document target structure first
- externalize runs/results/refs from repos progressively in later hardening tasks

### Priority later
- standardize run root
- standardize reference layout
- standardize environment naming
- standardize shared/public production release location
