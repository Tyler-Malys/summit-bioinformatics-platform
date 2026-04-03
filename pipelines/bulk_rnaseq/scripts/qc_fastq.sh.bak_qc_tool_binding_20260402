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

mkdir -p "$LOG_DIR"

########################################
# Logging header
########################################

echo "=== QC: FastQC + MultiQC ==="
date
echo "INPUT_DIR=$INPUT_DIR"
echo "OUTPUT_DIR=$OUTPUT_DIR"
echo "RUN_ID=$RUN_ID"
echo "THREADS=$THREADS"
echo "RUN_DIR=$RUN_DIR"

########################################
# Input validation
########################################

if [[ ! -d "$INPUT_DIR" ]]; then
  echo "ERROR: INPUT_DIR does not exist"
  exit 2
fi

shopt -s nullglob
FASTQS=("$INPUT_DIR"/*.fq.gz "$INPUT_DIR"/*.fastq.gz)

if [ ${#FASTQS[@]} -eq 0 ]; then
  echo "ERROR: No FASTQs found in $INPUT_DIR"
  exit 2
fi

echo "Found ${#FASTQS[@]} FASTQs"

########################################
# Dry run
########################################

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "[DRY RUN] Would run FastQC + MultiQC"
  exit 0
fi

########################################
# Tool checks
########################################
echo "Checking required tools..."

command -v fastqc >/dev/null 2>&1 || { echo "ERROR: fastqc not found"; exit 3; }
command -v multiqc >/dev/null 2>&1 || { echo "ERROR: multiqc not found"; exit 3; }

########################################
# Run FastQC
########################################
echo "Running FastQC..."

fastqc -t "$THREADS" -o "$RUN_DIR" "${FASTQS[@]}" \
  2>&1 | tee "${LOG_DIR}/fastqc.log"

########################################
# Run MultiQC
########################################
echo "Running MultiQC..."

multiqc "$RUN_DIR" -o "$RUN_DIR" \
  2>&1 | tee "${LOG_DIR}/multiqc.log"

########################################
# Run info
########################################

{
  echo "QC run completed on $(date)"
  echo "Input directory: $INPUT_DIR"
  echo "Threads: $THREADS"
  echo "fastqc version: $(fastqc --version 2>&1 || echo unknown)"
  echo "multiqc version: $(multiqc --version 2>&1 || echo unknown)"
} > "${RUN_DIR}/run_info.txt"

echo "DONE"
date


