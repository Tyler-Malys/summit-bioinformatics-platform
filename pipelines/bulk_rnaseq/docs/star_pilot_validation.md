# STAR Alignment Pilot — Validation (DEL-PYTHON)

## Purpose
Validate that the DEL-PYTHON environment can support STAR splice-aware genome alignment for human RNA-seq data and establish practical guidance for when to use STAR vs Salmon.

---

## Environment
Server: DEL-PYTHON  
STAR version: 2.7.10a  
Threads used: 8  
Reference: GENCODE GRCh38 primary assembly + v45 GTF  

---

## Genome Index Build

Reference files:
- GRCh38.primary_assembly.genome.fa
- gencode.v45.annotation.gtf

Results:
- Genome index built successfully
- Index size: ~28 GB
- Build completed without errors

Notes:
- Index generation is compute- and I/O-intensive
- Suffix array generation is the longest step
- Suitable for one-time build, reused across runs

---

## Pilot Alignment

Sample:
SW1116_D1_1

Input:
~21.1M paired-end reads (300 bp)

Output:
Coordinate-sorted BAM

Run completed successfully.

---

## Alignment Metrics

Uniquely mapped reads:
93.75%

Multi-mapping:
2.54%

Unmapped:
~3.7% (mostly too short)

Mismatch rate:
0.17%

Mapping speed:
~121M reads/hour

Output BAM size:
1.6 GB

Interpretation:
Excellent alignment quality consistent with high-quality RNA-seq.

---

## Practical Guidance

### Use Salmon (default) when:
- Transcript/gene quantification is the goal
- Running DESeq2/edgeR workflows
- High-throughput processing needed
- BAM files are not required

Advantages:
- Faster
- Lower compute cost
- Minimal storage burden

---

### Use STAR when:
- BAMs are required
- IGV visualization needed
- Splice junction analysis required
- Alignment-based QC needed

Tradeoffs:
- Heavy CPU/RAM usage
- Large storage footprint
- Slower than pseudoalignment

---

## Infrastructure Observations

Current VM handles:
- Index building
- Single-sample alignment

For large-scale STAR usage:
- More CPU cores recommended
- Higher RAM beneficial
- Significant storage required

STAR is viable but should be used selectively.

---

## Status

STAR Alignment Pilot: ✅ COMPLETE

Environment validated and documented.
