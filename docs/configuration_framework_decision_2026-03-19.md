# Configuration Framework Decision
Date: 2026-03-19

## Purpose

This note records the architecture decision reached after completing:

- bulk RNA-seq configuration audit
- bulk RNA-seq schema design
- scRNA-seq configuration audit
- scRNA-seq schema design

It defines the canonical direction for the next hardening phases:

- implement configuration loader logic within pipeline wrappers
- create configuration templates and example dataset configuration files
- replace hard-coded paths and parameters with configuration variables
- validate configuration handling across all pipeline stages

---

## Decision

Adopt a **shared platform-level configuration framework** for bioinformatics pipeline development, using a **common top-level schema pattern** across pipelines, while keeping **pipeline-specific configuration implementations** for bulk RNA-seq and scRNA-seq.

### Shared top-level schema pattern

All pipelines should use the same conceptual top-level sections:

- `RUN`
- `INPUT`
- `REF`
- `RESOURCE`
- `OUTPUT`
- `QC`
- `ANALYSIS`
- `LOG`

### Implementation model

The framework should **not** force bulk RNA-seq and scRNA-seq into one identical flat config file.

Instead, the framework should use:

- a shared schema philosophy
- shared naming conventions
- shared wrapper behavior expectations
- separate pipeline-specific config files
- pipeline-specific specialization within `QC` and `ANALYSIS`

---

## Final Recommendation

### Recommended architecture

Use:

- one **shared configuration framework pattern**
- two **pipeline-specific config implementations**

Specifically:

- `pipelines/bulk_rnaseq/config/...`
- `pipelines/scrnaseq/config/...`

Each pipeline config should follow the same top-level conceptual structure, but only expose fields relevant to that pipeline.

### Recommended practical outcome

- Bulk RNA-seq and scRNA-seq should share:
  - run control conventions
  - input/reference/resource/output/logging structure
  - wrapper-level config loading model
  - provenance and metadata conventions

- Bulk RNA-seq and scRNA-seq should differ where their workflows materially differ:
  - QC logic
  - analysis stages
  - engine-specific behavior
  - object model
  - stage dependencies

---

## Rationale

### Why a shared framework is justified

Bulk RNA-seq and scRNA-seq both require the same operational scaffolding:

- run identity
- config loading
- input resolution
- reference selection
- resource assignment
- output structure
- logging and provenance capture

These domains are sufficiently common that they should be standardized once at the platform level.

### Why one identical flat schema is not appropriate

Although the pipelines share operational scaffolding, they differ substantially in:

- biological workflow structure
- object model
- stage dependencies
- engine branching
- QC logic
- downstream analysis surface area

Bulk RNA-seq is centered on:

- FASTQ processing
- optional trimming
- quantification / alignment
- tximport
- DESeq2
- GSEA
- reporting

scRNA-seq is centered on:

- engine-specific count generation
- matrix-market / 10x-style output loading
- SingleCellExperiment state
- cell calling
- QC filtering
- doublet detection
- HVG selection
- PCA / regression / embeddings
- graph clustering
- annotation
- downstream DE / enrichment / visualization

These differences are too substantial to justify one identical detailed config schema.

### Why two unrelated frameworks are also not appropriate

Completely separate frameworks would:

- duplicate architectural effort
- weaken consistency
- make wrapper behavior less predictable
- complicate provenance and documentation
- reduce future maintainability

The better approach is shared structure with controlled specialization.

---

## Shared Top-Level Schema

The following sections are platform-level standards and should exist conceptually in both pipelines.

## RUN

Defines:

- pipeline identity
- run ID
- run mode
- execution toggles
- wrapper-level stage enablement
- dry-run / resume / overwrite behavior

### Shared design expectations

- run ID generated once at wrapper level
- run ID propagated downstream
- wrappers own execution control
- stage scripts should not independently invent run identity

---

## INPUT

Defines:

- raw input locations
- manifest/sample sheet paths
- dataset/sample identity
- naming/discovery rules
- optional explicit metadata inputs
- optional downstream input object paths

### Shared design expectations

- wrappers resolve inputs before stage execution
- input assumptions should be explicit where variability matters
- legacy pilot-specific names should be normalized

---

## REF

Defines:

- species
- genome build
- index locations
- annotation resources
- pathway/gene-set resources where applicable

### Shared design expectations

- references should be explicit or conventionally derivable
- species-dependent assumptions should not remain hidden
- reference handling should be compatible with wrapper validation

---

## RESOURCE

Defines:

- threads
- memory
- scratch/tmp locations
- required tools
- required packages
- tool-specific resource overrides when needed

### Shared design expectations

- global thread count should be wrapper-visible
- tool-specific overrides should be supported only where needed
- environment assumptions should be declared, not hidden in scripts

---

## OUTPUT

Defines:

- output root
- stage output roots
- run-tree conventions
- figure/report export controls
- intermediate object persistence rules

### Shared design expectations

- wrappers create canonical run structure
- scripts should derive outputs from wrapper-resolved roots
- output naming should become run-based and systematic
- stable directory structure should remain a documented convention

---

## LOG

Defines:

- wrapper log
- per-stage/per-sample logs
- config snapshot
- manifest snapshot
- software versions
- git capture
- start/end/failure status
- run metadata capture

### Shared design expectations

- provenance should be standardized across pipelines
- failed runs should be explicitly marked
- metadata capture should happen at wrapper level
- logging behavior should be consistent enough that users can navigate either pipeline the same way

---

## Pipeline-Specific Specialization

The following sections should remain specialized by pipeline.

## QC

### Bulk RNA-seq QC specialization

Bulk QC includes concepts such as:

- raw FASTQ QC
- post-trim QC
- integrity checking
- trimming validation
- gene filtering
- downstream QC plots

Typical bulk-specific examples:

- accepted FASTQ extensions
- paired-end assumptions
- read suffix conventions
- trimming behavior
- gene filter thresholds
- VST / PCA QC settings

### scRNA-seq QC specialization

scRNA QC includes concepts such as:

- cell calling
- barcode rank behavior
- emptyDrops thresholds
- low-quality filtering
- mitochondrial filtering
- doublet detection
- singlet retention
- QC plot/report generation

Typical scRNA-specific examples:

- emptyDrops lower/FDR
- min counts / min genes / max pct mito
- doublet method and seed
- use of Cell Ranger cell calls
- QC plot inclusion flags

### Decision for QC

`QC` should remain a shared top-level section, but its detailed fields should be pipeline-specific.

---

## ANALYSIS

### Bulk RNA-seq ANALYSIS specialization

Bulk analysis includes:

- tximport
- DESeq2 object construction
- differential expression
- GSEA
- GSEA summary reporting
- GSEA heatmaps
- downstream QC/diagnostics

Typical bulk-specific examples:

- design formula
- reference level
- contrast definitions
- pooled contrast logic
- shrinkage behavior
- gene-set collection settings
- heatmap/reporting thresholds

### scRNA-seq ANALYSIS specialization

scRNA analysis includes:

- normalization
- HVG selection
- PCA
- technical covariate assessment
- optional regression and alternate PCA
- graph construction
- clustering
- UMAP / t-SNE
- marker detection
- annotation
- differential expression
- pathway enrichment
- visualization/reporting
- backend comparison / stability analysis

Typical scRNA-specific examples:

- engine-specific behavior
- HVG count
- PCA settings
- regression covariates
- graph k / PC count
- clustering algorithm
- embedding settings
- marker settings
- annotation source
- DE grouping fields
- pathway rank statistic
- figure export controls

### Decision for ANALYSIS

`ANALYSIS` should remain a shared top-level section, but its detailed subsections should be pipeline-specific.

---

## Engine-Specific Handling

scRNA-seq requires additional specialization because it supports multiple engines:

- `cellranger`
- `starsolo`

This engine branching does **not** justify a separate framework.

Instead, it should be handled as a controlled specialization within the scRNA pipeline.

### Recommendation

Engine-specific behavior should be represented through:

- `RUN.engine`
- engine-specific manifest logic
- engine-specific reference requirements
- engine-specific execution arguments
- engine-specific defaults documented in config templates and wrapper logic

### Important constraint

Engine branching should be resolved by the **scRNA wrapper**, not distributed as ad hoc logic across legacy scripts wherever possible.

---

## Fixed Conventions vs Configurable Fields

A key design principle across both pipelines is:

> not every hard-coded item should become a config variable

The framework should explicitly distinguish between:

- required config
- optional config
- documented defaults
- fixed conventions

### Fixed conventions should remain fixed when reasonable

Examples:

- canonical run-tree layout
- wrapper-owned run metadata capture
- stage scripts acting as execution units
- stable reducedDim naming conventions for scRNA
- expected output structure for known stages
- accepted core object conventions

### Promote to config only when variability is likely to matter

Examples:

- input paths
- references
- resource limits
- stage toggles
- thresholds
- contrast definitions
- engine selection
- output export controls
- selected analysis parameters

---

## Configuration File Strategy

## Recommended format for next phase

For the next implementation phase, retain **env-style config files** compatible with bash wrappers.

This is the recommended transitional strategy because it:

- fits current wrappers
- minimizes implementation friction
- supports deliberate refactor without requiring immediate YAML/TOML parser adoption

### Recommended file pattern

Bulk RNA-seq:
- `pipelines/bulk_rnaseq/config/bulk_rnaseq.env`
- `pipelines/bulk_rnaseq/config/examples/...`

scRNA-seq:
- `pipelines/scrnaseq/config/scrnaseq.env`
- `pipelines/scrnaseq/config/examples/...`

### Recommended naming convention

Use section-aligned variable naming, for example:

- `RUN_*`
- `INPUT_*`
- `REF_*`
- `RESOURCE_*`
- `OUTPUT_*`
- `QC_*`
- `ANALYSIS_*`
- `LOG_*`

This preserves shell compatibility while aligning with the conceptual schema.

---

## Wrapper Design Implications

The next implementation phase should treat wrappers as the canonical config consumers.

## Wrapper responsibilities

Wrappers should:

- load config
- validate required fields
- resolve defaults
- normalize paths
- construct run directories
- snapshot config / manifests
- validate tools and references
- propagate explicit arguments to stage scripts
- capture provenance and status

## Stage script responsibilities

Stage scripts should:

- act as execution units
- accept explicit inputs from wrappers
- avoid reloading global config where possible
- avoid generating their own run identity
- avoid embedding output-root logic where wrapper context should supply it

---

## Implementation Guidance for the Next Task Blocks

This decision directly guides the next hardening tasks.

## 1. Implement configuration loader logic within pipeline wrappers

### Bulk RNA-seq
Implement canonical config loading in the bulk wrapper first.

Goals:
- map current flat env variables into canonical section-aligned names
- normalize run ID handling
- centralize defaults in wrapper
- remove duplicated defaults from stage scripts where practical

### scRNA-seq
Implement canonical config loading in the scRNA wrapper using the same top-level section philosophy.

Goals:
- centralize engine selection
- centralize manifest resolution
- centralize output/run structure creation
- centralize reference/resource validation
- centralize provenance capture

### Important principle
Both wrappers should behave similarly at the control-plane level even though the detailed pipeline logic differs.

---

## 2. Create configuration templates and example dataset configuration files

Use this decision to create:

### Bulk templates
- one canonical example bulk config
- one small test/pilot config
- one fuller production-style config if useful

### scRNA templates
- one Cell Ranger example config
- one STARsolo example config
- one single-sample example
- one multi-sample/manifest-driven example if useful

### Template purpose
Templates should demonstrate:
- shared section naming
- realistic defaults
- pipeline-specific specialization
- minimal required fields vs optional overrides

---

## 3. Replace hard-coded paths and parameters with configuration variables

Do this selectively.

### Highest-priority replacement targets
- wrapper-level config paths
- input/output roots
- resource settings
- manifest selection
- reference selection
- thresholds and analysis choices that genuinely vary across runs
- study-specific hard-coded downstream paths
- legacy one-off scripts that should become canonical stages

### Lower-priority targets
Do not immediately externalize every implementation detail unless there is a real use case.

Preserve reasonable house conventions as documented standards.

---

## 4. Validate configuration handling across all pipeline stages

Validation should confirm:

- config loads cleanly
- defaults resolve correctly
- required fields are enforced
- wrapper passes resolved arguments correctly
- run directories and log metadata are created consistently
- stage behavior changes appropriately when config values change
- no stage silently falls back to outdated hard-coded paths

### Validation priority
Start with canonical wrapper-driven paths, not every legacy helper script.

---

## Priority Decisions Already Established

The following decisions are now considered settled enough to guide implementation.

1. Use one shared framework pattern across pipelines
2. Keep separate concrete config files per pipeline
3. Standardize top-level sections
4. Let `QC` and `ANALYSIS` specialize by pipeline
5. Keep wrappers as the primary config consumers
6. Treat legacy one-off scripts as refactor targets, not canonical long-term interfaces
7. Continue with env-style configs for the next implementation phase

---

## Risks to Avoid

### 1. Forcing one identical schema file for both pipelines
This would create unnecessary clutter and complexity.

### 2. Over-configuring stable conventions
This would make the system harder to use and maintain.

### 3. Leaving downstream analysis outside the config model
Both audits showed that downstream analysis is a major source of hard-coded assumptions.

### 4. Allowing wrappers and stage scripts to diverge in config semantics
Wrapper should be the source of truth for config interpretation.

### 5. Preserving legacy one-off scripts as if they are canonical
They should be treated as temporary until generalized or retired.

---

## Conclusion

The platform should proceed with a **shared top-level configuration architecture** and **pipeline-specific configuration implementations**.

This gives:

- consistency across pipelines
- clean wrapper behavior
- controlled specialization where biology and workflow differ
- a practical path for the next hardening tasks
- a strong foundation for future multi-pipeline development

This decision is sufficient to begin:

- wrapper config-loader implementation
- config template creation
- hard-coded parameter replacement
- stage-level validation work
