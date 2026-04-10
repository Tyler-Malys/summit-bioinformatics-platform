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
      REF_INDEX="$2"   # STAR genomeDir
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
: "${REF_INDEX:?Missing -r STAR_INDEX}"

########################################
# Setup run directories
########################################

RUN_DIR="${OUTPUT_DIR}/${RUN_ID}"
LOG_DIR="${RUN_DIR}/logs"
mkdir -p "$LOG_DIR"

########################################
# Logging header
########################################

echo "=== STAR alignment ==="
date
echo "INPUT_DIR=$INPUT_DIR"
echo "OUTPUT_DIR=$OUTPUT_DIR"
echo "RUN_ID=$RUN_ID"
echo "THREADS=$THREADS"
echo "STAR_INDEX=$REF_INDEX"
echo "HOST=$(hostname)"
echo "PWD=$(pwd)"
echo

STAR_BIN="${STAR_BIN:-$(command -v STAR || true)}"

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
  echo "ERROR: STAR index dir not found: $REF_INDEX" >&2
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
  echo "[DRY RUN] Would run STAR per sample into: $RUN_DIR/<sample>/"
  exit 0
fi

########################################
# Tool checks
########################################

echo "Checking required tools..."
[[ -n "${STAR_BIN:-}" ]] || { echo "ERROR: STAR_BIN is empty and STAR not found in PATH" >&2; exit 4; }
[[ -x "$STAR_BIN" ]] || { echo "ERROR: STAR_BIN not executable: $STAR_BIN" >&2; exit 4; }
echo "STAR_BIN=$STAR_BIN"
echo "STAR_VERSION=$("$STAR_BIN" --version 2>/dev/null || echo unknown)"
echo

########################################
# Run alignment
########################################

FAILURES=0
SKIPPED=0
PROCESSED=0

# Deterministic order
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

  # Readability checks
  if [[ ! -r "$R1" ]]; then
    echo "ERROR: Cannot read $R1" >&2
    FAILURES=$((FAILURES + 1))
    continue
  fi

  if [[ ! -r "$R2" ]]; then
    echo "ERROR: Cannot read $R2" >&2
    FAILURES=$((FAILURES + 1))
    continue
  fi

  base="$(basename "$R1")"
  sample="${base%_1.fq.gz}"
  sample="${sample%_1.fastq.gz}"

  sample_out="$RUN_DIR/$sample"
  mkdir -p "$sample_out"

  # STAR outputs
  bam="$sample_out/Aligned.sortedByCoord.out.bam"
  final="$sample_out/Log.final.out"
  geneCounts="$sample_out/ReadsPerGene.out.tab"

  if [[ -s "$bam" && -s "$final" ]]; then
    echo "SKIP: $sample (BAM + Log.final.out exist)"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  sample_log="$LOG_DIR/${sample}.star.log"

  echo "--- STAR align: $sample ---"
  date

  if ! "$STAR_BIN" \
      --runThreadN "$THREADS" \
      --genomeDir "$REF_INDEX" \
      --readFilesIn "$R1" "$R2" \
      --readFilesCommand zcat \
      --outFileNamePrefix "$sample_out/" \
      --outSAMtype BAM SortedByCoordinate \
      --outSAMattributes NH HI AS nM \
      --quantMode GeneCounts \
      2>&1 | tee -a "$sample_log"
  then
    echo "ERROR: STAR failed for sample: $sample" >&2
    FAILURES=$((FAILURES + 1))
    continue
  fi

  # Minimal output validation
  if [[ ! -s "$bam" || ! -s "$final" ]]; then
    echo "ERROR: STAR outputs missing/empty for sample: $sample" >&2
    FAILURES=$((FAILURES + 1))
    continue
  fi

  # GeneCounts is expected with --quantMode GeneCounts, but don’t hard-fail if missing (depends on STAR build/settings)
  if [[ -s "$geneCounts" ]]; then
    echo "GeneCounts: $geneCounts"
  else
    echo "WARN: ReadsPerGene.out.tab not found for $sample (STAR may not have produced GeneCounts)"
  fi

  echo "Completed STAR alignment for $sample"
  echo

  PROCESSED=$((PROCESSED + 1))
done

########################################
# Run info + status
########################################

{
  echo "STAR alignment run completed on $(date)"
  echo "Input directory: $INPUT_DIR"
  echo "Threads: $THREADS"
  echo "STAR index: $REF_INDEX"
  echo "STAR bin: $STAR_BIN"
  echo "STAR version: $("$STAR_BIN" --version 2>/dev/null || echo unknown)"  
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
