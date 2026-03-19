#!/usr/bin/env bash
set -euo pipefail

MANIFEST="${1:-metadata/starsolo_runs.tsv}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

STAR_INDEX="$REPO_ROOT/ref/star_index"
OUT_BASE="$REPO_ROOT/runs/starsolo"
LOG_BASE="$REPO_ROOT/logs/starsolo"

mkdir -p "$OUT_BASE" "$LOG_BASE"

if [[ ! -f "$MANIFEST" ]]; then
  echo "ERROR: manifest not found: $MANIFEST" >&2
  exit 1
fi

if [[ ! -d "$STAR_INDEX" ]]; then
  echo "ERROR: STAR index directory not found: $STAR_INDEX" >&2
  exit 1
fi

tail -n +2 "$MANIFEST" | while IFS=$'\t' read -r run_id fastq_dir sample_id chemistry; do
  [[ -z "${run_id:-}" ]] && continue

  FASTQ_DIR="$REPO_ROOT/$fastq_dir"
  OUT_DIR="$OUT_BASE/$run_id"
  LOG_FILE="$LOG_BASE/${run_id}.log"

  mkdir -p "$OUT_DIR"

  if [[ -f "$OUT_DIR/Solo.out/Gene/raw/matrix.mtx.gz" ]] || [[ -f "$OUT_DIR/Solo.out/Gene/filtered/matrix.mtx.gz" ]]; then
    echo "SKIP: $run_id already completed"
    continue
  fi

  if [[ ! -d "$FASTQ_DIR" ]]; then
    echo "ERROR: FASTQ directory not found: $FASTQ_DIR"
    exit 1
  fi

  if [[ "$chemistry" == "10xv3" ]]; then
    CB_START=1
    CB_LEN=16
    UMI_START=17
    UMI_LEN=12
  elif [[ "$chemistry" == "10xv2" ]]; then
    CB_START=1
    CB_LEN=16
    UMI_START=17
    UMI_LEN=10
  else
    echo "ERROR: unsupported chemistry $chemistry"
    exit 1
  fi

  R1=$(ls -1 "$FASTQ_DIR"/*_R1_*.fastq.gz 2>/dev/null | paste -sd, -)
  R2=$(ls -1 "$FASTQ_DIR"/*_R2_*.fastq.gz 2>/dev/null | paste -sd, -)

  if [[ -z "$R1" || -z "$R2" ]]; then
    # fallback to SRA-style *_1/_2.fastq.gz
    R1=$(ls -1 "$FASTQ_DIR"/*_1.fastq.gz 2>/dev/null | paste -sd, -)
    R2=$(ls -1 "$FASTQ_DIR"/*_2.fastq.gz 2>/dev/null | paste -sd, -)
  fi

  if [[ -z "$R1" || -z "$R2" ]]; then
    echo "ERROR: could not locate FASTQ pairs in $FASTQ_DIR"
    exit 1
  fi

  echo "Running STARsolo for $run_id"
  echo "R1: $R1"
  echo "R2: $R2"
  echo "Output: $OUT_DIR"

  STAR \
    --runThreadN 16 \
    --genomeDir "$STAR_INDEX" \
    --readFilesIn "$R2" "$R1" \
    --readFilesCommand zcat \
    --outFileNamePrefix "$OUT_DIR/" \
    --outSAMtype BAM SortedByCoordinate \
    --soloType CB_UMI_Simple \
    --soloCBwhitelist None \
    --soloCBstart $CB_START \
    --soloCBlen $CB_LEN \
    --soloUMIstart $UMI_START \
    --soloUMIlen $UMI_LEN \
    --soloFeatures Gene \
    --soloCellFilter EmptyDrops_CR \
    --soloUMIdedup 1MM_CR \
    --soloUMIfiltering MultiGeneUMI_CR \
    2>&1 | tee "$LOG_FILE"

  echo "Completed $run_id"

done
