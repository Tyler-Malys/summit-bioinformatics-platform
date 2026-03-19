# Delcath Pipeline Architecture Inventory — 2026-03-17

## Canonical hardening bases
- bulk RNA-seq: delcath_crc_bulk_rnaseq_2026-02
- scRNA-seq: delcath_scrnaseq_dev_2026-03

## Legacy / reference-only project areas
- delcath_bulk_rnaseq = early bulk RNA-seq pilot on public data; reference only, not canonical for hardening

## High-level findings

### Home directory
- bioinformatics_projects = active pipeline workspace root
- refs = current reference root candidate
- miniconda3 = current environment/install root
- bioinformatics_tools = third-party tool area
- R / Rlibs = current R library/tooling area
- melphalan_project = separate project-specific area, not part of canonical Delcath pipeline architecture

### Bulk RNA-seq repo: delcath_crc_bulk_rnaseq_2026-02

Strengths:
- stronger config maturity
- multiple env/config files
- config/tests present
- README and docs present

Structural issues:
- scripts are flat at top level
- wrapper and stage scripts are mixed together
- backup/versioned files (.v0, .bak) are present in active script area
- logs/results/data are repo-local
- stray root-level operational files exist

### scRNA-seq repo: delcath_scrnaseq_dev_2026-03

Strengths:
- stronger script modularity
- scripts grouped into qc, downstream, starsolo, cellranger, utils
- README and VERSION present
- documentation structure is fairly strong

Structural issues:
- config is still minimal
- logs/results/runs/raw/ref are repo-local
- dataset-specific folders exist at repo top level
- stray root-level workflow artifact exists

## Preliminary standardization direction
- Use bulk RNA-seq repo as config-model reference
- Use scRNA-seq repo as script-organization reference
- Standardize both repos to a shared top-level structure
- Treat repo-local logs/results/runs/raw/ref as transitional, with future move toward canonical external run/reference layout
