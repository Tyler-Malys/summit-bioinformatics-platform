# Extension Notes

## Purpose

This document provides guidance on extending the Summit Informatics v1.0 pipeline system. It is intended for advanced users who wish to add new datasets, reference genomes, or extend pipeline functionality.

---

## Adding New Datasets

To process a new dataset:

1. Place input FASTQ files in a directory under:

        /srv/bioinformatics/data/

2. Create or update a configuration file (`.env`) specifying:

   - `FASTQ_ROOT`
   - `MANIFEST_FILE`
   - relevant metadata

3. Assign a new `RUN_ID` to avoid overwriting previous runs.

4. Execute the pipeline using the appropriate wrapper script.

---

## Adding New Reference Genomes

Reference data is stored under:

    /srv/bioinformatics/refs/

To add a new reference:

1. Create a directory structure:

        <REF_ROOT>/<organism>/<genome_build>/<annotation_version>/

2. Populate with required resources:

   - STAR genome index
   - Salmon index
   - annotation files (GTF/GFF)
   - transcript-to-gene mapping

3. Update configuration values:

   - `ORGANISM`
   - `GENOME_BUILD`
   - `ANNOTATION_VERSION`

4. Validate that paths resolve correctly before running pipelines.

---

## Pipeline Extension

Pipeline functionality can be extended by adding or modifying stages.

Guidelines:

- Maintain stage-based structure
- Follow existing naming conventions
- Ensure each stage writes logs and status markers
- Avoid modifying core pipeline logic unless necessary

---

## Extending Downstream Analysis

Downstream analysis scripts can be extended to include:

- additional statistical tests
- custom visualizations
- new pathway or enrichment analyses

Recommendations:

- add new scripts under appropriate pipeline directories
- ensure outputs follow existing directory structure
- document any new parameters in configuration files

---

## Multi-User Considerations

The system is designed for shared use:

- avoid modifying shared resources during active runs
- use unique `RUN_ID` values for all executions
- ensure proper permissions for new files and directories

---

## Known Constraints

- pipelines assume Linux-native file systems
- reference paths must be valid and accessible
- configuration files must be complete before execution
- large datasets may require tuning of resource parameters

---

## Summary

The system is designed to be modular and extensible while maintaining reproducibility and consistency.

Extensions should follow existing patterns to ensure compatibility with the pipeline architecture.
