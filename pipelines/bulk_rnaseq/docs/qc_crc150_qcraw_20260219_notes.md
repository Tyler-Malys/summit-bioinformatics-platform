# CRC 150-sample QC (raw FASTQ) — MultiQC Notes
**Run:** `qc_crc150_qcraw_20260219_132903`  
**Tooling:** MultiQC (FastQC aggregate)  
**Scope:** 150 samples (raw FASTQ QC prior to trimming or alignment)  
**Read Layout:** 150 bp single-end reads  

---

# 1) Executive Summary

QC review completed prior to alignment to document dataset characteristics and preprocessing decisions.

The dataset demonstrates strong overall sequencing quality across all 150 CRC samples.

Key observations:

- Uniform read length (150 bp across all samples)
- Excellent per-base and per-sequence quality (mean Phred ~38–40)
- Minimal N content
- Consistent GC distribution across cohort
- Low overrepresented sequence burden (<1%)
- Mild late-cycle adapter signal at 3′ end
- Elevated duplication across cohort, with a subset of clear outliers

The primary QC feature requiring documentation is **elevated duplication**, including several outlier samples exceeding 70% duplicated reads.

No trimming was performed at this stage due to strong read quality and limited expected benefit relative to risk of introducing preprocessing variability.

---

# 2) General Statistics Summary

## 2.1 Sequencing Depth
- Most samples fall within ~20–27 million reads.
- No catastrophic low-depth failures observed.

## 2.2 GC Content
- GC% tightly clustered around ~46–49%.
- No evidence of bimodal or aberrant GC distributions.
- Outlier duplication samples do not show GC distortion.

## 2.3 Duplication Overview

Most samples exhibit duplication in the ~55–65% range, consistent with RNA-seq datasets where PCR amplification and high transcript abundance contribute to duplicate reads.

However, several samples exceed 70% duplication and are flagged as outliers.

---

# 3) Duplication Outliers

## Threshold Definition

Samples with ≥70% duplicated reads are flagged as high-duplication outliers.

## Identified High-Duplication Samples (≥70%)

| Sample | % Dups | M Seqs | % GC |
|--------|--------|--------|------|
| SW1116_DMSO_2_1 | 82.5% | 21.0 | 46% |
| SW1116_DMSO_2_2 | 81.8% | 21.0 | 46% |
| SW1116_D3_3_1 | 72.7% | 22.9 | 46% |
| SW1116_D3_3_2 | 72.3% | 22.9 | 46% |

## Elevated but Below Threshold (~68–69%)

| Sample | % Dups | M Seqs | % GC |
|--------|--------|--------|------|
| SW48_D2_1_1 | 68.7% | 25.1 | 49% |
| SW48_D2_1_2 | 68.7% | 25.1 | 49% |

---

## 3.1 Notable Pattern

High-duplication samples occur in matched replicate pairs:

- SW1116_DMSO_2 replicates (~82%)
- SW1116_D3_3 replicates (~72%)
- SW48_D2_1 replicates (~69%)

This replicate-level concordance suggests duplication is likely related to:

- Biological expression dominance
- Library complexity characteristics
- Batch/library preparation effects

Rather than random sequencing machine failure.

---

## 3.2 Interpretation of Duplication Impact

Elevated duplication reduces effective unique fragment depth.

Example:
- 21M reads at 82% duplication leaves ~3.8M–4M effectively unique fragments.

*Note: FastQC duplication metrics are sequence-level estimates and may not perfectly reflect fragment-level duplication after alignment.*

Potential downstream impacts:

- Reduced sensitivity for low-abundance transcripts
- Slightly compressed dynamic range
- Increased variance for weakly expressed genes
- Possible minor reduction in gene detection count

Importantly:

- Duplication does not affect base quality.
- Duplication is not corrected by adapter trimming.
- Duplication alone does not invalidate RNA-seq data.

---

# 4) FastQC Module Review

## 4.1 Per Base Quality
- Flat high-quality scores across 150 bp.
- No 3′ quality decay.
- No systemic degradation.

Conclusion: No quality-driven reason to trim.

## 4.2 Per Sequence Quality
- Strong concentration at high Phred values.
- No secondary low-quality population.

## 4.3 Per Base N Content
- Near-zero N content across reads.

## 4.4 Sequence Length Distribution
- Uniform 150 bp reads across all samples.

## 4.5 Per Sequence GC Content
- Cohort-consistent bell-shaped distribution.
- No GC-shift in high-dup samples.

## 4.6 Overrepresented Sequences
- <1% across samples.
- No dominant contamination detected.

## 4.7 Adapter Content
- Mild late-cycle rise at 3′ end.
- Generally <5% for most samples.
- Pattern consistent with occasional read-through in 150 bp libraries.

---

# 5) Trimming Decision

## 5.1 Rationale for Not Trimming

Trimming was not performed for the following reasons:

1. Base quality is uniformly high.
2. No substantial low-quality tails are present.
3. Adapter signal is limited to extreme 3′ end.
4. STAR can soft-clip terminal mismatches.
5. Duplication is not mitigated by trimming.
6. Avoiding trimming prevents:
   - Over-trimming artifacts
   - Effective read length variability
   - Parameter-dependent preprocessing bias

Given the strong QC profile and limited expected benefit, proceeding without trimming is scientifically justified.

---

# 6) Downstream Validation Plan

Duplication outliers will be evaluated using alignment and quantification metrics.

Post-STAR metrics:
- % uniquely mapped reads
- % multi-mapped reads
- Mismatch rate per base
- Soft-clipping prevalence
- Unmapped read breakdown

Post-quantification metrics:
- Number of genes detected (e.g., TPM > 1)
- Effective library size
- PCA clustering behavior
- Sample-to-sample correlation

If high-duplication samples:
- Map normally
- Detect comparable gene counts
- Cluster appropriately with biological replicates

Then duplication is considered biologically tolerable and not technically detrimental.

If significant deviations are observed, further investigation (including optional adapter-only trimming) will be considered.

---

# 7) Overall Conclusion

The CRC 150-sample dataset demonstrates strong sequencing quality and cohort consistency.

Elevated duplication, including several outlier replicate pairs, is the primary QC feature requiring monitoring. However:

- Duplication is consistent with RNA-seq library behavior.
- No quality degradation or compositional abnormalities accompany high-dup samples.
- Trimming is unlikely to correct duplication-related complexity limitations.

We proceed to alignment without trimming, with explicit downstream validation checkpoints to confirm alignment integrity and expression stability.
