Bulk RNA-seq — Pipeline Modularity & Stage Framework Completion
Date: 2026-04-03

Scope
This completion note documents the implementation and validation of:

- Refactor scripts into modular stage-based execution components
- Implement stage wrappers and standardized stage execution framework
- Implement stage-level logging and status markers
- Validate modular execution and stage independence

for the bulk RNA-seq core pipeline.

Architecture Basis
- Stage architecture previously defined in:
  - bulk_stage_architecture_2026-03-27.md

Implementation Summary

1. Stage-based execution framework
- Introduced run_stage() pattern in run_bulk_wrapper_v4.sh
- All core processing stages routed through standardized execution

2. Stage wrappers
- Core stages modularized:
  - QC (qc_fastq.sh)
  - Trim (trim_fastp.sh)
  - Salmon (salmon_quant.sh)
  - Tximport (tximport_genelevel.R)
  - STAR (star_align.sh)

3. Logging and status tracking
- Stage logs written to:
  - runs/<run_id>/logs/stages/<stage>.log
- Stage markers:
  - .started
  - .completed
  - .failed
- Run-level metadata:
  - start_end_status.txt

4. Failure handling
- run_stage() exit handling corrected
- Non-zero exit codes properly terminate pipeline

5. Toolchain hardening (QC toolchain resolution)

Issue Identified:
- MultiQC execution failed when invoked from base environment
- System-installed /usr/bin/multiqc used incompatible Python stack
- Error: NumPy / SciPy binary incompatibility

Root Cause:
- Wrapper relied on PATH-based tool resolution
- System Python environment conflicted with expected dependencies

Resolution Implemented:
- Introduced explicit binary configuration:
  - FASTQC_BIN
  - MULTIQC_BIN

- Updated qc_fastq.sh to:
  - use FASTQC_BIN and MULTIQC_BIN instead of PATH
  - validate executable presence

- Updated run_bulk_wrapper_v4.sh to:
  - define default FASTQC_BIN / MULTIQC_BIN
  - validate binaries at wrapper level
  - export variables to stage scripts

Result:
- Eliminated dependency on system /usr/bin/multiqc
- Achieved environment-independent execution
- Verified successful execution from base environment

6. Configuration integration
- QC tool bindings added to:
  - config/pipeline_v3.env
  - config/template_bulk_rnaseq.env

Validation Summary

Executed test configurations:

- config/tests/01_qc_raw_only.env
- config/tests/02_trim_and_postqc_only.env
- config/tests/03_salmon_txi_trimmed.env
- config/tests/04_star_raw_notrim.env
- config/tests/05_full_trimmed.env

Validated:

- stage independence
- stage chaining
- branching logic
- full integration execution
- environment-independent execution from base (no conda activation required)

Configuration Notes

- QC binary bindings are defined in:
  - pipeline_v3.env (primary runtime config)
  - template_bulk_rnaseq.env (reference template)

- Test configurations (02–05) do not explicitly define FASTQC_BIN / MULTIQC_BIN
  - These rely on wrapper-level defaults
  - This is acceptable for current validation scope

Deferred / Not Modified in This Phase:

- No retroactive modification of all test configs
  - Rationale: avoid unnecessary churn in validation artifacts

- No introduction of dynamic environment activation (conda activate within wrapper)
  - Rationale: explicit binary binding is more deterministic and reproducible

- No refactoring of downstream analysis scripts into wrapper-managed stages
  - Rationale: downstream analysis is treated as a separate layer per architecture definition

Conclusion

The bulk RNA-seq core pipeline:

- is fully modularized
- uses a standardized execution framework
- includes robust logging and status tracking
- is environment-independent and config-driven
- has resolved QC toolchain dependency issues
- has been validated across all execution paths

Status: COMPLETE for core pipeline

Next Step

Proceed to downstream analysis validation (Stage A–G workflow).
