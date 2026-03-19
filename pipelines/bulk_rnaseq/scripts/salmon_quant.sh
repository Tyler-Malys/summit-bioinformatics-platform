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
    -r)
      REF_INDEX="$2"   # salmon index dir
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
: "${REF_INDEX:?Missing -r SALMON_INDEX}"

########################################
# Setup run directories
########################################

RUN_DIR="${OUTPUT_DIR}/${RUN_ID}"
LOG_DIR="${RUN_DIR}/logs"
mkdir -p "$LOG_DIR"

########################################
# Logging header
########################################

echo "=== Salmon quantification ==="
date
echo "INPUT_DIR=$INPUT_DIR"
echo "OUTPUT_DIR=$OUTPUT_DIR"
echo "RUN_ID=$RUN_ID"
echo "THREADS=$THREADS"
echo "SALMON_INDEX=$REF_INDEX"
echo "HOST=$(hostname)"
echo "PWD=$(pwd)"
echo

########################################
# Input validation
########################################

if [[ ! -d "$INPUT_DIR" ]]; then
  echo "ERROR: INPUT_DIR not found: $INPUT_DIR" >&2
  exit 2
fi

if [[ ! -r "$INPUT_DIR" ]]; then
  echo "ERROR: INPUT_DIR not readable: $INPUT_DIR" >&2
  exit 2
fi

if [[ ! -d "$REF_INDEX" ]]; then
  echo "ERROR: Salmon index dir not found: $REF_INDEX" >&2
  exit 2
fi

shopt -s nullglob
R1S=("$INPUT_DIR"/*_1.fq.gz "$INPUT_DIR"/*_1.fastq.gz)

if [ ${#R1S[@]} -eq 0 ]; then
  echo "ERROR: No R1 FASTQs found in $INPUT_DIR (expected *_1.fq.gz or *_1.fastq.gz)" >&2
  exit 3
fi

echo "Found ${#R1S[@]} R1 FASTQs (samples) to process."
echo

########################################
# Dry run
########################################

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "[DRY RUN] Would run salmon quant per sample into: $RUN_DIR/<sample>/"
  exit 0
fi

########################################
# Tool checks
########################################

echo "Checking required tools..."
command -v salmon >/dev/null 2>&1 || { echo "ERROR: salmon not found in PATH" >&2; exit 4; }
echo "SALMON_VERSION=$(salmon --version 2>&1 | head -n 1 || echo unknown)"
echo

########################################
# Run quantification
########################################

FAILURES=0
SKIPPED=0
PROCESSED=0

# Sort for deterministic order
IFS=$'\n' R1S_SORTED=($(printf "%s\n" "${R1S[@]}" | sort))
unset IFS

for R1 in "${R1S_SORTED[@]}"; do
  case "$R1" in
    *_1.fq.gz)    R2="${R1%_1.fq.gz}_2.fq.gz" ;;
    *_1.fastq.gz) R2="${R1%_1.fastq.gz}_2.fastq.gz" ;;
    *) echo "ERROR: Unexpected R1 filename pattern: $R1" >&2; exit 5 ;;
  esac

  if [[ ! -f "$R2" ]]; then
    echo "ERROR: Missing R2 for $R1 (expected $R2)" >&2
    FAILURES=$((FAILURES + 1))
    continue
  fi

  base="$(basename "$R1")"
  sample="${base%_1.fq.gz}"
  sample="${sample%_1.fastq.gz}"

  sample_out="$RUN_DIR/$sample"
  mkdir -p "$sample_out"

  quant_sf="$sample_out/quant.sf"
  sample_log="$LOG_DIR/${sample}.salmon.log"

  if [[ -s "$quant_sf" ]]; then
    echo "SKIP: $sample (quant.sf exists)"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  echo "--- Salmon quant: $sample ---"
  date

  if ! salmon quant \
      -i "$REF_INDEX" \
      -l A \
      -1 "$R1" \
      -2 "$R2" \
      -p "$THREADS" \
      --validateMappings \
      -o "$sample_out" \
      2>&1 | tee "$sample_log"
  then
    echo "ERROR: salmon quant failed for sample: $sample" >&2
    FAILURES=$((FAILURES + 1))
    continue
  fi

  if [[ ! -s "$quant_sf" ]]; then
    echo "ERROR: quant.sf missing/empty for sample: $sample" >&2
    FAILURES=$((FAILURES + 1))
    continue
  fi

  echo "Completed salmon quant for $sample"
  echo

  PROCESSED=$((PROCESSED + 1))
done

########################################
# Run info + status
########################################

{
  echo "Salmon quant run completed on $(date)"
  echo "Input directory: $INPUT_DIR"
  echo "Threads: $THREADS"
  echo "Salmon index: $REF_INDEX"
  echo "salmon version: $(salmon --version 2>&1 | head -n 1 || echo unknown)"
  echo "Samples detected: ${#R1S[@]}"
  echo "Processed: $PROCESSED"
  echo "Skipped: $SKIPPED"
  echo "Failures: $FAILURES"
} > "${RUN_DIR}/run_info.txt"

if [[ "$FAILURES" -gt 0 ]]; then
  echo "DONE with failures: $FAILURES"
  exit 10
fi

echo "DONE"
date

