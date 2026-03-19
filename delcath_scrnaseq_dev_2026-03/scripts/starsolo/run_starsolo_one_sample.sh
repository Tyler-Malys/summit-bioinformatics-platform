#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/../../config/project.env"

SAMPLE_ID="${1:?Usage: run_starsolo_one_sample.sh <sample_id> <fastq_dir>}"
FASTQ_DIR="${2:?Usage: run_starsolo_one_sample.sh <sample_id> <fastq_dir>}"

OUTDIR="${PROJECT_ROOT}/results/starsolo/${SAMPLE_ID}"
mkdir -p "$OUTDIR" "${PROJECT_ROOT}/logs"

# NOTE: We will set these after confirming chemistry from the smoke test FASTQs.
# Typical 10x 3' v3:
#   CB: 16 bp starting at 1
#   UMI: 12 bp starting at 17
SOLO_PARAMS=(
  --soloType CB_UMI_Simple
  --soloCBstart 1 --soloCBlen 16
  --soloUMIstart 17 --soloUMIlen 12
  --soloBarcodeReadLength 0
)

# STAR expects cDNA read first, barcode read second for many 10x layouts.
# We'll confirm which file is which after we see read lengths.
# Commonly:
#   R2 = cDNA (long)
#   R1 = barcode/UMI (short)
R1_GZ=$(ls "${FASTQ_DIR}"/*_1.fastq.gz 2>/dev/null | head -n 1 || true)
R2_GZ=$(ls "${FASTQ_DIR}"/*_2.fastq.gz 2>/dev/null | head -n 1 || true)

if [[ -z "${R1_GZ}" || -z "${R2_GZ}" ]]; then
  echo "ERROR: Could not find *_1.fastq.gz and *_2.fastq.gz in ${FASTQ_DIR}"
  exit 1
fi

STAR \
  --genomeDir "${STAR_INDEX}" \
  --readFilesIn "${R2_GZ}" "${R1_GZ}" \
  --readFilesCommand zcat \
  --runThreadN "${THREADS}" \
  --outFileNamePrefix "${OUTDIR}/" \
  "${SOLO_PARAMS[@]}" \
  2>&1 | tee "${PROJECT_ROOT}/logs/starsolo_${SAMPLE_ID}.log"

echo "DONE: ${SAMPLE_ID} -> ${OUTDIR}"
