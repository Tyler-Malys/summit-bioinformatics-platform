# STAR Alignment Pilot — Notes (DEL-PYTHON)

## Summary
We performed a STAR alignment pilot setup to validate that the DEL-PYTHON environment can support splice-aware genome alignment (BAM generation) as an optional complement to the Salmon transcript-quant workflow.

Status:
- STAR installed and version verified: 2.7.10a
- Human reference staged (GENCODE GRCh38 primary assembly + GTF v45)
- Genome index generation in progress (GRCh38; suffix array chunk build)

## When to use STAR vs Salmon (practical guidance)

### Salmon (default for expression quantification)
Use Salmon for:
- Transcript/gene abundance quantification (fast)
- Differential expression workflows (tximport → DESeq2 / edgeR)
- High-throughput processing when BAMs are not required
Key advantages:
- Typically much faster and lighter on compute than full genome alignment
- Produces quant files directly; no large BAM storage required

### STAR (optional, alignment/BAM-oriented)
Use STAR for:
- Producing aligned reads (BAM) when downstream analyses require alignments, e.g.:
  - QC/visual inspection in IGV
  - splice junction / alternative splicing analyses
  - fusion detection
  - variant calling (rare for RNA-seq, but sometimes requested)
  - alignment-based QC metrics (insert size, duplication, etc.)

Cautions:
- STAR is significantly heavier than Salmon (CPU, RAM, disk).
- Requires a genome index (one-time per reference build) and generates large BAMs.

## Compute observations (DEL-PYTHON virtual hardware)
Host/VM observed resources:
- RAM: ~31 GiB
- Swap: 8 GiB
- Linux filesystem available: ~900+ GiB free at start of indexing

STAR index build notes:
- Human GRCh38 index requires uncompressed FASTA/GTF inputs.
- Index generation is the most expensive one-time step (suffix array chunking; ~29 chunks observed).
- Expect index directory to grow into the tens of GB range.

Operational implications:
- STAR is feasible for pilot / small batches on current hardware.
- For large-scale alignment (hundreds to thousands of paired-end FASTQs), throughput will likely be limited by CPU and disk I/O.
- Alignment at scale may require:
  - more CPU cores (higher parallelism)
  - more RAM headroom (stability during indexing and parallel runs)
  - high-throughput storage (BAMs are large; disk growth can be substantial)
  - job scheduling / batching strategy to avoid I/O contention

## Storage considerations
- STAR index: one-time cost, tens of GB (per reference build)
- BAM outputs: can be very large; plan retention/archival strategy if STAR is used for many samples
- Salmon avoids BAMs and is typically lighter on storage

## Next steps (pilot completion)
1) Confirm STAR genomeGenerate completes successfully.
2) Align 1 representative sample pair (e.g., THLE_2_DMSO_1) and capture:
   - mapping rates (Log.final.out)
   - runtime (wall time)
   - BAM size
3) Record results here to inform future decisions on STAR usage at scale.
STAR indexing status as of Thu Feb 12 13:52:20 EST 2026: 0/29 SA chunks complete
