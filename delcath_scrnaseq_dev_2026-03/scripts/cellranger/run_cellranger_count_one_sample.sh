#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/../../config/project.env"

SAMPLE_ID="${1:?Usage: run_cellranger_count_one_sample.sh <sample_id> <fastq_dir>}"
FASTQ_DIR="${2:?Usage: run_cellranger_count_one_sample.sh <sample_id> <fastq_dir>}"

if ! command -v cellranger >/dev/null 2>&1; then
  echo "ERROR: cellranger not found on PATH. Install/enable it to use this engine."
  exit 1
fi

OUTROOT="${PROJECT_ROOT}/results/cellranger"
mkdir -p "$OUTROOT" "${PROJECT_ROOT}/logs"

cellranger count \
  --id="${SAMPLE_ID}" \
  --transcriptome="${CELLRANGER_REF}" \
  --fastqs="${FASTQ_DIR}" \
  --sample="${SAMPLE_ID}" \
  --localcores="${THREADS}" \
  --localmem=64 \
  2>&1 | tee "${PROJECT_ROOT}/logs/cellranger_${SAMPLE_ID}.log"

echo "DONE: ${SAMPLE_ID} -> ${OUTROOT}/${SAMPLE_ID}"
