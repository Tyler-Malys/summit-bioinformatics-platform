#!/usr/bin/env bash
set -euo pipefail

# Usage:
# qc_then_optional_trim_then_salmon.sh <raw_dir> <work_root> <salmon_index> [threads] [mode] [libtype]
#
# mode:
#   auto   = decide trimming based on FastQC summary (recommended default)
#   prompt = ask user
#   trim   = force trim
#   notrim = force no trim
#
# Outputs under:
#   <work_root>/qc/raw
#   <work_root>/trimmed
#   <work_root>/qc/trimmed
#   <work_root>/salmon/{raw|trimmed}/runs/<run_id>/...

RAW_DIR="${1:?Usage: qc_then_optional_trim_then_salmon.sh <raw_dir> <work_root> <salmon_index> [threads] [mode] [libtype]}"
WORK_ROOT="${2:?Usage: qc_then_optional_trim_then_salmon.sh <raw_dir> <work_root> <salmon_index> [threads] [mode] [libtype]}"
SALMON_INDEX="${3:?Usage: qc_then_optional_trim_then_salmon.sh <raw_dir> <work_root> <salmon_index> [threads] [mode] [libtype]}"
THREADS="${4:-8}"
MODE="${5:-auto}"    # auto|prompt|trim|notrim
LIBTYPE="${6:-A}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

QC_RAW="$WORK_ROOT/qc/raw"
TRIM_DIR="$WORK_ROOT/trimmed"
QC_TRIM="$WORK_ROOT/qc/trimmed"

mkdir -p "$QC_RAW" "$TRIM_DIR" "$QC_TRIM" "$WORK_ROOT/salmon/raw" "$WORK_ROOT/salmon/trimmed"

echo "Step 1: QC on raw reads"
"$SCRIPT_DIR/qc_fastq.sh" "$RAW_DIR" "$QC_RAW" "$THREADS"

echo
echo "Raw MultiQC report:"
echo "  $QC_RAW/multiqc_report.html"
echo

do_trim="N"

if [ "$MODE" = "trim" ]; then
  do_trim="Y"
elif [ "$MODE" = "notrim" ]; then
  do_trim="N"
elif [ "$MODE" = "prompt" ]; then
  read -r -p "Do you want to run trimming + re-QC? (y/N): " ans
  ans="${ans:-N}"
  [[ "$ans" =~ ^[Yy]$ ]] && do_trim="Y" || do_trim="N"
else
  # MODE=auto: decide based on FastQC summary flags from the raw QC outputs
  # Trigger trimming if any WARN/FAIL in modules often associated with adapters/contamination.
  # This is intentionally conservative.
  echo "Auto mode: inspecting FastQC summaries to decide trimming..."
  shopt -s nullglob
  ZIPS=( "$QC_RAW"/*_fastqc.zip )
  if [ ${#ZIPS[@]} -eq 0 ]; then
    echo "WARN: No *_fastqc.zip found in $QC_RAW; defaulting to NOTRIM" >&2
    do_trim="N"
  else
    # Look for WARN/FAIL in Adapter Content, Overrepresented sequences, Kmer Content
    # If any match, trim.
    if unzip -p "${ZIPS[@]}" "*/summary.txt" 2>/dev/null \
      | grep -E '^(WARN|FAIL)\s+(Adapter Content|Overrepresented sequences|Kmer Content)\b' -q; then
      do_trim="Y"
    else
      do_trim="N"
    fi
  fi
fi

INPUT_FOR_SALMON="$RAW_DIR"
SALMON_OUT="$WORK_ROOT/salmon/raw"

if [ "$do_trim" = "Y" ]; then
  echo "Step 2: Trimming with fastp"
  "$SCRIPT_DIR/trim_fastp.sh" "$RAW_DIR" "$TRIM_DIR" "$THREADS"

  echo "Step 3: QC on trimmed reads"
  "$SCRIPT_DIR/qc_fastq.sh" "$TRIM_DIR" "$QC_TRIM" "$THREADS"

  echo "Trimmed MultiQC report:"
  echo "  $QC_TRIM/multiqc_report.html"

  INPUT_FOR_SALMON="$TRIM_DIR"
  SALMON_OUT="$WORK_ROOT/salmon/trimmed"
else
  echo "Skipping trimming."
fi

echo "Step 4: Salmon quantification"
"$SCRIPT_DIR/salmon_quant.sh" \
  "$INPUT_FOR_SALMON" \
  "$SALMON_OUT" \
  "$SALMON_INDEX" \
  "$THREADS" \
  "$LIBTYPE"

echo "DONE"
date
