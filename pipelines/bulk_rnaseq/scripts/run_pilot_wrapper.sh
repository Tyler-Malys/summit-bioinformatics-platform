#!/usr/bin/env bash
set -euo pipefail

# Wrapper: pilot smoke run for bulk RNA-seq pipeline
# Runs: FastQC/MultiQC -> fastp -> Salmon -> tximport -> STAR
# Uses central config: config/pipeline.env

CONFIG="${1:-config/pipeline.env}"

if [[ ! -f "$CONFIG" ]]; then
  echo "ERROR: config file not found: $CONFIG" >&2
  exit 2
fi

# Load config (sets RUN_ID, THREADS, paths, etc.)
# shellcheck disable=SC1090
source "$CONFIG"

# Basic validation of required vars
: "${THREADS:?Missing THREADS in config}"
: "${RUN_ID:?Missing RUN_ID in config}"
: "${PILOT_FASTQ_DIR:?Missing PILOT_FASTQ_DIR in config}"
: "${QC_OUT_ROOT:?Missing QC_OUT_ROOT in config}"
: "${TRIM_OUT_ROOT:?Missing TRIM_OUT_ROOT in config}"
: "${SALMON_OUT_ROOT:?Missing SALMON_OUT_ROOT in config}"
: "${TXIMPORT_OUT_ROOT:?Missing TXIMPORT_OUT_ROOT in config}"
: "${STAR_OUT_ROOT:?Missing STAR_OUT_ROOT in config}"
: "${SALMON_INDEX:?Missing SALMON_INDEX in config}"
: "${TX2GENE:?Missing TX2GENE in config}"
: "${STAR_INDEX:?Missing STAR_INDEX in config}"
: "${DO_QC_RAW:?Missing DO_QC_RAW in config}"
: "${DO_TRIM:?Missing DO_TRIM in config}"
: "${DO_QC_POSTTRIM:?Missing DO_QC_POSTTRIM in config}"
: "${DO_SALMON:?Missing DO_SALMON in config}"
: "${DO_TXIMPORT:?Missing DO_TXIMPORT in config}"
: "${DO_STAR:?Missing DO_STAR in config}"

# Initialize stage output vars so summary doesn't break if skipped
QC_RUN_DIR=""
TRIM_RUN_DIR=""
QC_POSTTRIM_RUN_DIR=""
SALMON_RUN_DIR=""
TXI_RUN_DIR=""
STAR_RUN_DIR=""

if [[ ! -d "$PILOT_FASTQ_DIR" ]]; then
  echo "ERROR: PILOT_FASTQ_DIR not found: $PILOT_FASTQ_DIR" >&2
  exit 3
fi

if [[ ! -r "$PILOT_FASTQ_DIR" ]]; then
  echo "ERROR: PILOT_FASTQ_DIR not readable: $PILOT_FASTQ_DIR" >&2
  exit 3
fi

# Default input for downstream steps = raw fastqs
PROC_FASTQ_DIR="$PILOT_FASTQ_DIR"

# Wrapper run dir + log
WRAP_DIR="$PWD/results/wrapper_runs/${RUN_ID}"
mkdir -p "$WRAP_DIR"
WRAP_LOG="${WRAP_DIR}/wrapper.log"

echo "=== WRAPPER RUN ===" | tee -a "$WRAP_LOG"
date | tee -a "$WRAP_LOG"
echo "CONFIG=$CONFIG" | tee -a "$WRAP_LOG"
echo "RUN_ID=$RUN_ID" | tee -a "$WRAP_LOG"
echo "THREADS=$THREADS" | tee -a "$WRAP_LOG"
echo "PILOT_FASTQ_DIR=$PILOT_FASTQ_DIR" | tee -a "$WRAP_LOG"
echo "SALMON_INDEX=$SALMON_INDEX" | tee -a "$WRAP_LOG"
echo "STAR_INDEX=$STAR_INDEX" | tee -a "$WRAP_LOG"
echo "TX2GENE=$TX2GENE" | tee -a "$WRAP_LOG"
echo | tee -a "$WRAP_LOG"

# --- helpers / boolean handling / logging ---
is_true() {
  case "${1,,}" in
    1|true|yes|y|on) return 0 ;;
    *) return 1 ;;
  esac
}

log() { echo "[$(date '+%F %T')] $*" | tee -a "$WRAP_LOG"; }

# Suggested selectors for Salmon/STAR input (raw|trimmed)
: "${SALMON_INPUT:=trimmed}"
: "${STAR_INPUT:=trimmed}"

if is_true "$DO_SALMON" || is_true "$DO_TXIMPORT"; then
  echo "SALMON_INPUT=$SALMON_INPUT" | tee -a "$WRAP_LOG"
else
  echo "SALMON_INPUT=NA (DO_SALMON=$DO_SALMON)" | tee -a "$WRAP_LOG"
fi

if is_true "$DO_STAR"; then
  echo "STAR_INPUT=$STAR_INPUT" | tee -a "$WRAP_LOG"
else
  echo "STAR_INPUT=NA (DO_STAR=$DO_STAR)" | tee -a "$WRAP_LOG"
fi

echo | tee -a "$WRAP_LOG"

# --- dependency checks ---
if is_true "$DO_TXIMPORT" && ! is_true "$DO_SALMON"; then
  echo "ERROR: DO_TXIMPORT=1 requires DO_SALMON=1" >&2
  exit 4
fi

if is_true "$DO_QC_POSTTRIM" && ! is_true "$DO_TRIM"; then
  echo "ERROR: DO_QC_POSTTRIM=1 requires DO_TRIM=1" >&2
  exit 4
fi

# --- tool checks (only for enabled stages) ---
if is_true "$DO_QC_RAW" || is_true "$DO_QC_POSTTRIM"; then
  command -v fastqc  >/dev/null || { echo "ERROR: fastqc not found in PATH"  >&2; exit 5; }
  command -v multiqc >/dev/null || { echo "ERROR: multiqc not found in PATH" >&2; exit 5; }
fi

if is_true "$DO_TRIM"; then
  command -v fastp >/dev/null || { echo "ERROR: fastp not found in PATH" >&2; exit 5; }
fi

if is_true "$DO_SALMON" || is_true "$DO_TXIMPORT"; then
  command -v salmon >/dev/null || { echo "ERROR: salmon not found in PATH" >&2; exit 5; }
fi

if is_true "$DO_TXIMPORT"; then
  command -v Rscript >/dev/null || { echo "ERROR: Rscript not found in PATH" >&2; exit 5; }
fi

if is_true "$DO_STAR"; then
  command -v STAR >/dev/null || { echo "ERROR: STAR not found in PATH" >&2; exit 5; }
fi

# --- script existence checks (only for enabled stages) ---
if is_true "$DO_QC_RAW" || is_true "$DO_QC_POSTTRIM"; then
  [[ -x scripts/qc_fastq.sh ]] || { echo "ERROR: scripts/qc_fastq.sh not found or not executable" >&2; exit 5; }
fi

if is_true "$DO_TRIM"; then
  [[ -x scripts/trim_fastp.sh ]] || { echo "ERROR: scripts/trim_fastp.sh not found or not executable" >&2; exit 5; }
fi

if is_true "$DO_SALMON" || is_true "$DO_TXIMPORT"; then
  [[ -x scripts/salmon_quant.sh ]] || { echo "ERROR: scripts/salmon_quant.sh not found or not executable" >&2; exit 5; }
fi

if is_true "$DO_TXIMPORT"; then
  [[ -f scripts/tximport_genelevel.R ]] || { echo "ERROR: scripts/tximport_genelevel.R not found" >&2; exit 5; }
fi

if is_true "$DO_STAR"; then
  [[ -x scripts/star_align.sh ]] || { echo "ERROR: scripts/star_align.sh not found or not executable" >&2; exit 5; }
fi

########################################
# 1) QC
########################################
log "=== STAGE 1: QC RAW (FastQC + MultiQC) ==="
if is_true "$DO_QC_RAW"; then
  scripts/qc_fastq.sh \
    -i "$PILOT_FASTQ_DIR" \
    -o "$QC_OUT_ROOT" \
    --run-id "qc_${RUN_ID}" \
    -t "$THREADS" \
    2>&1 | tee -a "$WRAP_LOG"

  QC_RUN_DIR="${QC_OUT_ROOT}/qc_${RUN_ID}"
  log "QC_RUN_DIR=$QC_RUN_DIR"
else
  log "QC RAW skipped (DO_QC_RAW=$DO_QC_RAW)"
fi
echo | tee -a "$WRAP_LOG"

########################################
# 2) Trim
########################################
log "=== STAGE 2: TRIM (fastp) ==="
if is_true "$DO_TRIM"; then
  scripts/trim_fastp.sh \
    -i "$PILOT_FASTQ_DIR" \
    -o "$TRIM_OUT_ROOT" \
    --run-id "trim_${RUN_ID}" \
    -t "$THREADS" \
    2>&1 | tee -a "$WRAP_LOG"

  TRIM_RUN_DIR="${TRIM_OUT_ROOT}/trim_${RUN_ID}"
  log "TRIM_RUN_DIR=$TRIM_RUN_DIR"

  # Default processed fastq dir for downstream stages
  PROC_FASTQ_DIR="$TRIM_RUN_DIR"
else
  log "TRIM skipped (DO_TRIM=$DO_TRIM)"
  # Leave PROC_FASTQ_DIR as raw
fi
echo | tee -a "$WRAP_LOG"

########################################
# 2b) QC post-trim (optional)
########################################
log "=== STAGE 2b: QC POST-TRIM (FastQC + MultiQC) ==="
if is_true "$DO_QC_POSTTRIM"; then
  scripts/qc_fastq.sh \
    -i "$PROC_FASTQ_DIR" \
    -o "$QC_OUT_ROOT" \
    --run-id "qc_posttrim_${RUN_ID}" \
    -t "$THREADS" \
    2>&1 | tee -a "$WRAP_LOG"

  QC_POSTTRIM_RUN_DIR="${QC_OUT_ROOT}/qc_posttrim_${RUN_ID}"
  log "QC_POSTTRIM_RUN_DIR=$QC_POSTTRIM_RUN_DIR"
else
  log "QC POST-TRIM skipped (DO_QC_POSTTRIM=$DO_QC_POSTTRIM)"
fi
echo | tee -a "$WRAP_LOG"

########################################
# 3) Salmon
########################################
# Choose inputs for Salmon/STAR: raw|trimmed
choose_input_dir() {
  local which="$1"
  case "${which,,}" in
    raw) echo "$PILOT_FASTQ_DIR" ;;
    trimmed)
      if ! is_true "$DO_TRIM"; then
        echo "ERROR: trimmed input requested but DO_TRIM=$DO_TRIM. Either set DO_TRIM=1 or set the relevant *_INPUT=raw (SALMON_INPUT/STAR_INPUT)." >&2
        exit 4
      fi
      echo "$TRIM_RUN_DIR"
      ;;
    *)
      echo "ERROR: invalid input selector: $which (use raw|trimmed)" >&2
      exit 4
      ;;
  esac
}

SALMON_INPUT_DIR=""
STAR_INPUT_DIR=""

if is_true "$DO_SALMON" || is_true "$DO_TXIMPORT"; then
  SALMON_INPUT_DIR="$(choose_input_dir "$SALMON_INPUT")"
  log "SALMON_INPUT=$SALMON_INPUT => $SALMON_INPUT_DIR"
fi

if is_true "$DO_STAR"; then
  STAR_INPUT_DIR="$(choose_input_dir "$STAR_INPUT")"
  log "STAR_INPUT=$STAR_INPUT => $STAR_INPUT_DIR"
fi

echo | tee -a "$WRAP_LOG"

if is_true "$DO_SALMON"; then
  log "=== STAGE 3: SALMON (quant) [input=$SALMON_INPUT] ==="
  if [[ -z "${SALMON_INPUT_DIR:-}" ]]; then
    echo "ERROR: SALMON_INPUT_DIR is empty; cannot run Salmon" >&2
    exit 4
  fi
  if [[ ! -d "$SALMON_INPUT_DIR" ]]; then
    echo "ERROR: SALMON_INPUT_DIR not found: $SALMON_INPUT_DIR" >&2
    exit 4
  fi

  scripts/salmon_quant.sh \
    -i "$SALMON_INPUT_DIR" \
    -o "$SALMON_OUT_ROOT" \
    --run-id "salmon_${RUN_ID}" \
    -t "$THREADS" \
    -r "$SALMON_INDEX" \
    2>&1 | tee -a "$WRAP_LOG"

  SALMON_RUN_DIR="${SALMON_OUT_ROOT}/salmon_${RUN_ID}"
  log "SALMON_RUN_DIR=$SALMON_RUN_DIR"
else
  log "SALMON skipped (DO_SALMON=$DO_SALMON)"
fi
echo | tee -a "$WRAP_LOG"

########################################
# 4) tximport
########################################
if is_true "$DO_TXIMPORT"; then
  log "=== STAGE 4: TXIMPORT (gene-level) ==="
  if [[ -z "${SALMON_RUN_DIR:-}" ]]; then
    echo "ERROR: SALMON_RUN_DIR is empty; cannot run tximport" >&2
    exit 4
  fi
  if [[ ! -d "$SALMON_RUN_DIR" ]]; then
    echo "ERROR: SALMON_RUN_DIR not found: $SALMON_RUN_DIR" >&2
    exit 4
  fi
  log "TXIMPORT reading Salmon dir: $SALMON_RUN_DIR"

  Rscript scripts/tximport_genelevel.R \
    -i "$SALMON_RUN_DIR" \
    -o "$TXIMPORT_OUT_ROOT" \
    -m "$TX2GENE" \
    --run-id "txi_${RUN_ID}" \
    2>&1 | tee -a "$WRAP_LOG"

  TXI_RUN_DIR="${TXIMPORT_OUT_ROOT}/txi_${RUN_ID}"
  log "TXI_RUN_DIR=$TXI_RUN_DIR"
else
  log "TXIMPORT skipped (DO_TXIMPORT=$DO_TXIMPORT)"
fi
echo | tee -a "$WRAP_LOG"

########################################
# 5) STAR
########################################
log "=== STAGE 5: STAR (align) [input=$STAR_INPUT] ==="
if is_true "$DO_STAR"; then
  if [[ -z "${STAR_INPUT_DIR:-}" ]]; then
    echo "ERROR: STAR_INPUT_DIR is empty; cannot run STAR" >&2
    exit 4
  fi
  if [[ ! -d "$STAR_INPUT_DIR" ]]; then
    echo "ERROR: STAR_INPUT_DIR not found: $STAR_INPUT_DIR" >&2
    exit 4
  fi

  scripts/star_align.sh \
    -i "$STAR_INPUT_DIR" \
    -o "$STAR_OUT_ROOT" \
    --run-id "star_${RUN_ID}" \
    -t "$THREADS" \
    -r "$STAR_INDEX" \
    2>&1 | tee -a "$WRAP_LOG"

  STAR_RUN_DIR="${STAR_OUT_ROOT}/star_${RUN_ID}"
  log "STAR_RUN_DIR=$STAR_RUN_DIR"
else
  log "STAR skipped (DO_STAR=$DO_STAR)"
fi
echo | tee -a "$WRAP_LOG"

echo "=== WRAPPER DONE ===" | tee -a "$WRAP_LOG"
date | tee -a "$WRAP_LOG"

echo
echo "Summary:"
echo "  QC RAW:       ${QC_RUN_DIR:-SKIPPED}"
echo "  TRIM:         ${TRIM_RUN_DIR:-SKIPPED}"
echo "  QC POST-TRIM: ${QC_POSTTRIM_RUN_DIR:-SKIPPED}"
echo "  SALMON:       ${SALMON_RUN_DIR:-SKIPPED}"
echo "  TXIMPORT:     ${TXI_RUN_DIR:-SKIPPED}"
echo "  STAR:         ${STAR_RUN_DIR:-SKIPPED}"
echo "  WRAPLOG:      $WRAP_LOG"
