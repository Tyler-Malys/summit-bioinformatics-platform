#!/usr/bin/env bash
set -euo pipefail

CONFIG="${1:-config/project.env}"
ENGINE="${2:-cellranger}"
MANIFEST="${3:-}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

if [[ ! -f "$CONFIG" ]]; then
  echo "ERROR: config file not found: $CONFIG" >&2
  exit 2
fi

# shellcheck disable=SC1090
source "$CONFIG"

: "${PROJECT_ROOT:?Missing PROJECT_ROOT in config}"
: "${THREADS:?Missing THREADS in config}"
: "${REF_ROOT:?Missing REF_ROOT in config}"
: "${STAR_INDEX:?Missing STAR_INDEX in config}"
: "${CELLRANGER_REF:?Missing CELLRANGER_REF in config}"

if [[ -z "$MANIFEST" ]]; then
  case "${ENGINE,,}" in
    cellranger)
      MANIFEST="metadata/cellranger_runs.tsv"
      ;;
    starsolo)
      MANIFEST="metadata/starsolo_runs.tsv"
      ;;
    *)
      echo "ERROR: unsupported ENGINE: $ENGINE (use cellranger|starsolo)" >&2
      exit 2
      ;;
  esac
fi

RUN_ID="scrna_${ENGINE}_$(date +%Y%m%d_%H%M%S)"

# Canonical run directory structure (transitional repo-local root for now)
: "${RUNS_ROOT:=$PROJECT_ROOT/runs}"
RUN_DIR="${RUNS_ROOT}/${RUN_ID}"

INPUT_DIR="${RUN_DIR}/input"
WORKING_DIR="${RUN_DIR}/working"
LOGS_DIR="${RUN_DIR}/logs"
QC_DIR="${RUN_DIR}/qc"
OUTPUTS_DIR="${RUN_DIR}/outputs"
DOWNSTREAM_DIR="${RUN_DIR}/downstream"
FINAL_DIR="${RUN_DIR}/final"
RUN_METADATA_DIR="${RUN_DIR}/run_metadata"

mkdir -p \
  "$INPUT_DIR" \
  "$WORKING_DIR" \
  "$LOGS_DIR" \
  "$QC_DIR" \
  "$OUTPUTS_DIR" \
  "$DOWNSTREAM_DIR" \
  "$FINAL_DIR" \
  "$RUN_METADATA_DIR"

WRAP_LOG="${LOGS_DIR}/wrapper.log"

log() { echo "[$(date '+%F %T')] $*" | tee -a "$WRAP_LOG"; }

echo "=== scRNA-seq WRAPPER RUN ===" | tee -a "$WRAP_LOG"
date | tee -a "$WRAP_LOG"
echo "CONFIG=$CONFIG" | tee -a "$WRAP_LOG"
echo "ENGINE=$ENGINE" | tee -a "$WRAP_LOG"
echo "MANIFEST=$MANIFEST" | tee -a "$WRAP_LOG"
echo "RUN_ID=$RUN_ID" | tee -a "$WRAP_LOG"
echo "THREADS=$THREADS" | tee -a "$WRAP_LOG"
echo "PROJECT_ROOT=$PROJECT_ROOT" | tee -a "$WRAP_LOG"
echo "STAR_INDEX=$STAR_INDEX" | tee -a "$WRAP_LOG"
echo "CELLRANGER_REF=$CELLRANGER_REF" | tee -a "$WRAP_LOG"
echo | tee -a "$WRAP_LOG"

# Metadata capture
cp -f "$CONFIG" "${RUN_METADATA_DIR}/resolved_config.env"
cp -f "$MANIFEST" "${INPUT_DIR}/$(basename "$MANIFEST")"

{
  echo "run_id=${RUN_ID}"
  echo "pipeline=scrnaseq"
  echo "engine=${ENGINE}"
  echo "timestamp=$(date '+%F %T')"
  echo "operator=$(whoami)"
  echo "project_root=$PROJECT_ROOT"
  echo "config=$CONFIG"
  echo "manifest=$MANIFEST"
  echo "star_index=$STAR_INDEX"
  echo "cellranger_ref=$CELLRANGER_REF"
} > "${RUN_METADATA_DIR}/run_manifest.txt"

{
  echo "git_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo NA)"
  echo "git_commit=$(git rev-parse HEAD 2>/dev/null || echo NA)"
  echo "git_status=$(git status --short 2>/dev/null | wc -l | awk '{print ($1==0 ? "clean" : "dirty")}')"
} > "${RUN_METADATA_DIR}/pipeline_version.txt"

{
  echo "date=$(date '+%F %T')"
  echo -n "bash="; bash --version | head -n 1
  echo -n "Rscript="; Rscript --version 2>&1 | head -n 1 || true
  echo -n "STAR="; STAR --version 2>&1 | head -n 1 || true
  echo -n "cellranger="; cellranger --version 2>&1 | head -n 1 || true
} > "${RUN_METADATA_DIR}/software_versions.txt"

{
  echo "start_time=$(date '+%F %T')"
  echo "status=started"
} > "${RUN_METADATA_DIR}/start_end_status.txt"

# Basic validation
[[ -f "$MANIFEST" ]] || { echo "ERROR: manifest not found: $MANIFEST" >&2; exit 3; }

case "${ENGINE,,}" in
  cellranger)
    command -v cellranger >/dev/null 2>&1 || { echo "ERROR: cellranger not found in PATH" >&2; exit 4; }
    [[ -d "$CELLRANGER_REF" ]] || { echo "ERROR: CELLRANGER_REF not found: $CELLRANGER_REF" >&2; exit 4; }
    ;;
  starsolo)
    command -v STAR >/dev/null 2>&1 || { echo "ERROR: STAR not found in PATH" >&2; exit 4; }
    [[ -d "$STAR_INDEX" ]] || { echo "ERROR: STAR_INDEX not found: $STAR_INDEX" >&2; exit 4; }
    ;;
  *)
    echo "ERROR: unsupported ENGINE: $ENGINE (use cellranger|starsolo)" >&2
    exit 2
    ;;
esac

# Engine dispatch
if [[ "${ENGINE,,}" == "cellranger" ]]; then
  log "=== ENGINE: Cell Ranger ==="

  tail -n +2 "$MANIFEST" | while IFS=$'\t' read -r sample_run_id sample_id dataset fastq_path reference chemistry expected_cells notes; do
    [[ -z "${sample_run_id:-}" ]] && continue

    SAMPLE_OUT_DIR="${OUTPUTS_DIR}/cellranger/${sample_run_id}"
    SAMPLE_LOG="${LOGS_DIR}/${sample_run_id}_cellranger.log"

    mkdir -p "$SAMPLE_OUT_DIR"

    if [[ ! -d "$fastq_path" ]]; then
      echo "ERROR: FASTQ path not found for ${sample_run_id}: $fastq_path" >&2
      exit 5
    fi

    log "Running Cell Ranger for ${sample_run_id}"
    log "FASTQ path: $fastq_path"
    log "Output dir: $SAMPLE_OUT_DIR"

    (
      cd "$OUTPUTS_DIR/cellranger"
      cellranger count \
        --id="${sample_run_id}" \
        --transcriptome="${CELLRANGER_REF}" \
        --fastqs="${fastq_path}" \
        --sample="${sample_id}" \
        --localcores="${THREADS}" \
        --localmem=64
    ) 2>&1 | tee "$SAMPLE_LOG"
  done

elif [[ "${ENGINE,,}" == "starsolo" ]]; then
  log "=== ENGINE: STARsolo ==="

  tail -n +2 "$MANIFEST" | while IFS=$'\t' read -r sample_run_id fastq_dir sample_id chemistry; do
    [[ -z "${sample_run_id:-}" ]] && continue

    if [[ "$fastq_dir" = /* ]]; then
      FASTQ_DIR="$fastq_dir"
    else
      FASTQ_DIR="$PROJECT_ROOT/$fastq_dir"
    fi

    SAMPLE_OUT_DIR="${OUTPUTS_DIR}/starsolo/${sample_run_id}"
    SAMPLE_LOG="${LOGS_DIR}/${sample_run_id}_starsolo.log"

    mkdir -p "$SAMPLE_OUT_DIR"

    if [[ ! -d "$FASTQ_DIR" ]]; then
      echo "ERROR: FASTQ directory not found for ${sample_run_id}: $FASTQ_DIR" >&2
      exit 5
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
      echo "ERROR: unsupported chemistry $chemistry for ${sample_run_id}" >&2
      exit 5
    fi

    R1=$(ls -1 "$FASTQ_DIR"/*_R1_*.fastq.gz 2>/dev/null | paste -sd, -)
    R2=$(ls -1 "$FASTQ_DIR"/*_R2_*.fastq.gz 2>/dev/null | paste -sd, -)

    if [[ -z "$R1" || -z "$R2" ]]; then
      R1=$(ls -1 "$FASTQ_DIR"/*_1.fastq.gz 2>/dev/null | paste -sd, -)
      R2=$(ls -1 "$FASTQ_DIR"/*_2.fastq.gz 2>/dev/null | paste -sd, -)
    fi

    if [[ -z "$R1" || -z "$R2" ]]; then
      echo "ERROR: could not locate FASTQ pairs in $FASTQ_DIR for ${sample_run_id}" >&2
      exit 5
    fi

    log "Running STARsolo for ${sample_run_id}"
    log "FASTQ dir: $FASTQ_DIR"
    log "Output dir: $SAMPLE_OUT_DIR"

    STAR \
      --runThreadN "${THREADS}" \
      --genomeDir "$STAR_INDEX" \
      --readFilesIn "$R2" "$R1" \
      --readFilesCommand zcat \
      --outFileNamePrefix "${SAMPLE_OUT_DIR}/" \
      --outSAMtype BAM SortedByCoordinate \
      --soloType CB_UMI_Simple \
      --soloCBwhitelist None \
      --soloCBstart "${CB_START}" \
      --soloCBlen "${CB_LEN}" \
      --soloUMIstart "${UMI_START}" \
      --soloUMIlen "${UMI_LEN}" \
      --soloFeatures Gene \
      --soloCellFilter EmptyDrops_CR \
      --soloUMIdedup 1MM_CR \
      --soloUMIfiltering MultiGeneUMI_CR \
      2>&1 | tee "$SAMPLE_LOG"
  done
fi

echo "=== scRNA-seq WRAPPER DONE ===" | tee -a "$WRAP_LOG"
date | tee -a "$WRAP_LOG"

{
  echo "end_time=$(date '+%F %T')"
  echo "status=completed"
} >> "${RUN_METADATA_DIR}/start_end_status.txt"

echo
echo "Summary:"
echo "  RUN_ID:   $RUN_ID"
echo "  ENGINE:   $ENGINE"
echo "  RUN_DIR:  $RUN_DIR"
echo "  WRAPLOG:  $WRAP_LOG"
