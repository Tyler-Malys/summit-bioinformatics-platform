#!/usr/bin/env bash
set -euo pipefail

# Usage:
# qc_then_optional_trim.sh <raw_dir> <work_root> [threads]
# Produces:
#   <work_root>/qc/raw
#   <work_root>/trimmed
#   <work_root>/qc/trimmed

RAW_DIR="${1:?Usage: qc_then_optional_trim.sh <raw_dir> <work_root> [threads]}"
WORK_ROOT="${2:?Usage: qc_then_optional_trim.sh <raw_dir> <work_root> [threads]}"
THREADS="${3:-8}"
MODE="${4:-prompt}"   # prompt|trim|notrim
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

QC_RAW="$WORK_ROOT/qc/raw"
TRIM_DIR="$WORK_ROOT/trimmed"
QC_TRIM="$WORK_ROOT/qc/trimmed"

mkdir -p "$QC_RAW" "$TRIM_DIR" "$QC_TRIM"

echo "Step 1: QC on raw reads"
"$SCRIPT_DIR/qc_fastq.sh" "$RAW_DIR" "$QC_RAW" "$THREADS"

echo
echo "Review MultiQC report:"
echo "  $QC_RAW/multiqc_report.html"
echo

do_trim="N"

if [ "$MODE" = "trim" ]; then
  do_trim="Y"
elif [ "$MODE" = "notrim" ]; then
  do_trim="N"
else
  read -r -p "Do you want to run trimming + re-QC? (y/N): " ans
  ans="${ans:-N}"
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    do_trim="Y"
  fi
fi

if [ "$do_trim" = "Y" ]; then
  echo "Step 2: Trimming with fastp"
  "$SCRIPT_DIR/trim_fastp.sh" "$RAW_DIR" "$TRIM_DIR" "$THREADS"

  echo "Step 3: QC on trimmed reads"
  "$SCRIPT_DIR/qc_fastq.sh" "$TRIM_DIR" "$QC_TRIM" "$THREADS"

  echo "Trimmed MultiQC report:"
  echo "  $QC_TRIM/multiqc_report.html"
else
  echo "Skipping trimming."
fi

echo "DONE"
date
