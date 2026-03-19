#!/usr/bin/env bash
set -euo pipefail

########################################
# Defaults
########################################

THREADS=8
RUN_ID=$(date +"%Y%m%d_%H%M%S")
DRY_RUN=0

########################################
# Parse arguments
########################################

while [[ $# -gt 0 ]]; do
  case "$1" in
    -i)
      INPUT_DIR="$2"
      shift 2
      ;;
    -o)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    -t)
      THREADS="$2"
      shift 2
      ;;
    --run-id)
      RUN_ID="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

########################################
# Validate required args
########################################

: "${INPUT_DIR:?Missing -i INPUT_DIR}"
: "${OUTPUT_DIR:?Missing -o OUTPUT_DIR}"

########################################
# Setup run directories
########################################

RUN_DIR="${OUTPUT_DIR}/${RUN_ID}"
LOG_DIR="${RUN_DIR}/logs"
REPORT_DIR="${RUN_DIR}/reports"

mkdir -p "$LOG_DIR" "$REPORT_DIR"

########################################
# Logging header
########################################

echo "=== TRIM: fastp ==="
date
echo "INPUT_DIR=$INPUT_DIR"
echo "OUTPUT_DIR=$OUTPUT_DIR"
echo "RUN_ID=$RUN_ID"
echo "THREADS=$THREADS"
echo "RUN_DIR=$RUN_DIR"
echo

########################################
# Input validation
########################################

if [[ ! -d "$INPUT_DIR" ]]; then
  echo "ERROR: INPUT_DIR does not exist: $INPUT_DIR" >&2
  exit 2
fi

shopt -s nullglob
R1S=("$INPUT_DIR"/*_1.fq.gz "$INPUT_DIR"/*_1.fastq.gz)

if [ ${#R1S[@]} -eq 0 ]; then
  echo "ERROR: No *_1.fq.gz or *_1.fastq.gz files found in $INPUT_DIR" >&2
  exit 2
fi

echo "Found ${#R1S[@]} R1 FASTQs"

########################################
# Dry run
########################################

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "[DRY RUN] Would trim paired-end FASTQs with fastp into: $RUN_DIR"
  echo "[DRY RUN] Would write per-sample reports to: $REPORT_DIR"
  exit 0
fi

########################################
# Tool checks
########################################

echo "Checking required tools..."
command -v fastp >/dev/null 2>&1 || { echo "ERROR: fastp not found in PATH" >&2; exit 3; }
echo

########################################
# Run trimming
########################################

FAILURES=0

for R1 in "${R1S[@]}"; do
  case "$R1" in
    *_1.fq.gz)    R2="${R1%_1.fq.gz}_2.fq.gz" ;;
    *_1.fastq.gz) R2="${R1%_1.fastq.gz}_2.fastq.gz" ;;
    *) echo "ERROR: Unexpected R1 filename pattern: $R1" >&2; exit 4 ;;
  esac

  if [[ ! -f "$R2" ]]; then
    echo "ERROR: Missing R2 for $R1 (expected $R2)" >&2
    exit 5
  fi

  base="$(basename "$R1")"
  sample="${base%_1.fq.gz}"
  sample="${sample%_1.fastq.gz}"

  # Preserve extension style per your original logic
  if [[ "$R1" == *_1.fastq.gz ]]; then
    outR1="$RUN_DIR/${sample}_1.fastq.gz"
    outR2="$RUN_DIR/${sample}_2.fastq.gz"
  else
    outR1="$RUN_DIR/${sample}_1.fq.gz"
    outR2="$RUN_DIR/${sample}_2.fq.gz"
  fi

  html="$REPORT_DIR/${sample}.fastp.html"
  json="$REPORT_DIR/${sample}.fastp.json"
  sample_log="$LOG_DIR/${sample}.fastp.log"

  echo "--- Trimming $sample ---"
  date

  # Run fastp and tee to per-sample log
  if ! fastp \
      -i "$R1" -I "$R2" \
      -o "$outR1" -O "$outR2" \
      --detect_adapter_for_pe \
      --thread "$THREADS" \
      --html "$html" \
      --json "$json" \
      --report_title "$sample" \
      2>&1 | tee "$sample_log"
  then
    echo "ERROR: fastp failed for sample: $sample" >&2
    FAILURES=$((FAILURES + 1))
    continue
  fi

  # Minimal output validation
  if [[ ! -s "$outR1" || ! -s "$outR2" ]]; then
    echo "ERROR: Trimmed outputs missing/empty for sample: $sample" >&2
    FAILURES=$((FAILURES + 1))
    continue
  fi

  echo "Completed trimming for $sample"

  echo
done

########################################
# Run info + status
########################################

{
  echo "Trim run completed on $(date)"
  echo "Input directory: $INPUT_DIR"
  echo "Threads: $THREADS"
  echo "fastp version: $(fastp --version 2>&1 || echo unknown)"
  echo "Samples detected: ${#R1S[@]}"
  echo "Failures: $FAILURES"
} > "${RUN_DIR}/run_info.txt"

if [[ "$FAILURES" -gt 0 ]]; then
  echo "DONE with failures: $FAILURES"
  exit 10
fi

echo "DONE"
date

