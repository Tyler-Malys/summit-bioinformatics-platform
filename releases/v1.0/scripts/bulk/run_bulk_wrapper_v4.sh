#!/usr/bin/env bash
set -euo pipefail

# Bulk RNA-seq wrapper v4
# Pipeline Modularity & Stage Architecture implementation
# Runs: FastQC/MultiQC -> fastp -> Salmon -> tximport -> STAR
# Default config: config/pipeline_v3.env

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEFAULT_CONFIG="${PIPELINE_ROOT}/config/pipeline_v3.env"
CONFIG="${1:-$DEFAULT_CONFIG}"

if [[ ! -f "$CONFIG" ]]; then
  echo "ERROR: config file not found: $CONFIG" >&2
  exit 2
fi

load_config() {
  local config_path="$1"
  # shellcheck disable=SC1090
  source "$config_path"
}

require_var() {
  local var_name="$1"
  [[ -n "${!var_name:-}" ]] || {
    echo "ERROR: required config variable missing: $var_name" >&2
    exit 2
  }
}

default_var() {
  local var_name="$1"
  local default_value="$2"
  if [[ -z "${!var_name:-}" ]]; then
    printf -v "$var_name" '%s' "$default_value"
  fi
}

load_config "$CONFIG"

default_var PIPELINE_ROOT "$PIPELINE_ROOT"
default_var RUNS_ROOT "${PIPELINE_ROOT}/runs"
default_var RAW_LOCAL_ROOT "${PIPELINE_ROOT}/data/raw_local"
default_var FASTQC_BIN "/home/summitadmin/miniconda3/envs/bulk_qc_tools/bin/fastqc"
default_var MULTIQC_BIN "/home/summitadmin/miniconda3/envs/bulk_qc_tools/bin/multiqc"
default_var FASTP_BIN "/home/summitadmin/miniconda3/envs/bulk_rnaseq_env/bin/fastp"
default_var SALMON_BIN "/home/summitadmin/miniconda3/envs/bulk_rnaseq_env/bin/salmon"
default_var STAR_BIN "/home/summitadmin/miniconda3/envs/bulk_rnaseq_env/bin/STAR"
default_var RSCRIPT_BIN "/home/summitadmin/miniconda3/envs/bulk_rnaseq_env/bin/Rscript"
QC_SCRIPT="${PIPELINE_ROOT}/scripts/qc_fastq.sh"
TRIM_SCRIPT="${PIPELINE_ROOT}/scripts/trim_fastp.sh"
SALMON_SCRIPT="${PIPELINE_ROOT}/scripts/salmon_quant.sh"
TXIMPORT_SCRIPT="${PIPELINE_ROOT}/scripts/tximport_genelevel.R"
STAR_SCRIPT="${PIPELINE_ROOT}/scripts/star_align.sh"
export FASTP_BIN
export SALMON_BIN
export STAR_BIN
export RSCRIPT_BIN

default_var RUN_ID ""
if [[ -z "$RUN_ID" ]]; then
  RUN_ID="$(date +%Y%m%d_%H%M%S)"
fi

# Transitional normalization
default_var THREADS "${RESOURCE_THREADS:-${THREADS:-}}"
default_var PILOT_FASTQ_DIR "${INPUT_FASTQ_DIR:-${FASTQ_DIR:-${PILOT_FASTQ_DIR:-}}}"
default_var SALMON_INDEX "${REF_SALMON_INDEX:-${SALMON_INDEX:-}}"
default_var STAR_INDEX "${REF_STAR_INDEX:-${STAR_INDEX:-}}"
default_var TX2GENE "${REF_TX2GENE:-${TX2GENE:-}}"

default_var QC_OUT_ROOT "${OUTPUT_QC_ROOT:-${QC_ROOT:-${QC_OUT_ROOT:-}}}"
default_var TRIM_OUT_ROOT "${OUTPUT_TRIM_ROOT:-${TRIM_ROOT:-${TRIM_OUT_ROOT:-}}}"
default_var SALMON_OUT_ROOT "${OUTPUT_SALMON_ROOT:-${SALMON_ROOT:-${SALMON_OUT_ROOT:-}}}"
default_var TXIMPORT_OUT_ROOT "${OUTPUT_TXIMPORT_ROOT:-${TXIMPORT_ROOT:-${TXIMPORT_OUT_ROOT:-}}}"
default_var STAR_OUT_ROOT "${OUTPUT_STAR_ROOT:-${STAR_ROOT:-${STAR_OUT_ROOT:-}}}"

default_var DO_QC_RAW "${QC_DO_RAW:-${DO_QC_RAW:-0}}"
default_var DO_QC_POSTTRIM "${QC_DO_POSTTRIM:-${DO_QC_POSTTRIM:-0}}"
default_var DO_TRIM "${ANALYSIS_DO_TRIM:-${DO_TRIM:-0}}"
default_var DO_SALMON "${ANALYSIS_DO_SALMON:-${DO_SALMON:-0}}"
default_var DO_TXIMPORT "${ANALYSIS_DO_TXIMPORT:-${DO_TXIMPORT:-0}}"
default_var DO_STAR "${ANALYSIS_DO_STAR:-${DO_STAR:-0}}"

default_var DO_LOCALIZE_RAW "${ANALYSIS_DO_LOCALIZE_RAW:-${DO_LOCALIZE_RAW:-0}}"
default_var DO_INTEGRITY "${ANALYSIS_DO_INTEGRITY:-${DO_INTEGRITY_CHECK:-${DO_INTEGRITY:-0}}}"
default_var SKIP_BAD_FASTQS "${ANALYSIS_SKIP_BAD_FASTQS:-${SKIP_BAD_FASTQS:-1}}"

default_var RAW_SRC_DIR "${INPUT_RAW_SOURCE_DIR:-${RAW_SOURCE_DIR:-${RAW_SRC_DIR:-$PILOT_FASTQ_DIR}}}"
default_var SALMON_INPUT "${ANALYSIS_SALMON_INPUT:-${SALMON_INPUT_MODE:-${SALMON_INPUT:-trimmed}}}"
default_var STAR_INPUT "${ANALYSIS_STAR_INPUT:-${STAR_INPUT_MODE:-${STAR_INPUT:-trimmed}}}"

# ========================================
# Restart / Execution Control
# ========================================
default_var START_STAGE ""
default_var END_STAGE ""
default_var RERUN_FAILED_ONLY "false"
default_var MIN_FREE_DISK_GB "10"
default_var MIN_FREE_MEM_GB "4"
default_var MIN_AVAILABLE_CPUS "2"
default_var PIPELINE_SEED "12345"

# ========================================
# Reference auto-resolution (config-driven)
# ========================================
if [[ -z "${SALMON_INDEX:-}" || -z "${STAR_INDEX:-}" || -z "${TX2GENE:-}" ]]; then
  if [[ -n "${REF_ROOT:-}" && -n "${ORGANISM:-}" && -n "${GENOME_BUILD:-}" && -n "${ANNOTATION_VERSION:-}" ]]; then
    REFERENCE_BASE="${REF_ROOT}/${ORGANISM}/${GENOME_BUILD}/${ANNOTATION_VERSION}"

    [[ -z "${SALMON_INDEX:-}" ]] && SALMON_INDEX="${REFERENCE_BASE}/salmon_index"
    [[ -z "${STAR_INDEX:-}" ]] && STAR_INDEX="${REFERENCE_BASE}/star_index"
    [[ -z "${TX2GENE:-}" ]] && TX2GENE="${REFERENCE_BASE}/tx2gene/tx2gene.tsv"
  fi
fi

require_var THREADS
require_var RUN_ID
require_var PILOT_FASTQ_DIR
require_var QC_OUT_ROOT
require_var TRIM_OUT_ROOT
require_var SALMON_OUT_ROOT
require_var TXIMPORT_OUT_ROOT
require_var STAR_OUT_ROOT

if [[ ! -d "$PILOT_FASTQ_DIR" ]]; then
  echo "ERROR: PILOT_FASTQ_DIR not found: $PILOT_FASTQ_DIR" >&2
  exit 3
fi

if [[ ! -r "$PILOT_FASTQ_DIR" ]]; then
  echo "ERROR: PILOT_FASTQ_DIR not readable: $PILOT_FASTQ_DIR" >&2
  exit 3
fi

if [[ "$DO_SALMON" =~ ^(1|true|yes|y|on)$ || "$DO_TXIMPORT" =~ ^(1|true|yes|y|on)$ ]]; then
  require_var SALMON_INDEX
fi

if [[ "$DO_TXIMPORT" =~ ^(1|true|yes|y|on)$ ]]; then
  require_var TX2GENE
fi

if [[ "$DO_STAR" =~ ^(1|true|yes|y|on)$ ]]; then
  require_var STAR_INDEX
fi

if [[ "$DO_SALMON" =~ ^(1|true|yes|y|on)$ || "$DO_TXIMPORT" =~ ^(1|true|yes|y|on)$ ]]; then
  [[ -d "$SALMON_INDEX" ]] || { echo "ERROR: SALMON_INDEX directory not found: $SALMON_INDEX" >&2; exit 3; }
fi

if [[ "$DO_TXIMPORT" =~ ^(1|true|yes|y|on)$ ]]; then
  [[ -f "$TX2GENE" ]] || { echo "ERROR: TX2GENE file not found: $TX2GENE" >&2; exit 3; }
fi

if [[ "$DO_STAR" =~ ^(1|true|yes|y|on)$ ]]; then
  [[ -d "$STAR_INDEX" ]] || { echo "ERROR: STAR_INDEX directory not found: $STAR_INDEX" >&2; exit 3; }
fi

# Initialize stage output vars so summary doesn't break if skipped
QC_RUN_DIR=""
TRIM_RUN_DIR=""
QC_POSTTRIM_RUN_DIR=""
SALMON_RUN_DIR=""
TXI_RUN_DIR=""
STAR_RUN_DIR=""

# Canonical run directory structure (transitional repo-local root for now)
: "${RUNS_ROOT:=${PIPELINE_ROOT}/runs}"
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

STAGE_LOG_DIR="${LOGS_DIR}/stages"
STAGE_STATUS_DIR="${RUN_METADATA_DIR}/stage_status"
mkdir -p "$STAGE_LOG_DIR" "$STAGE_STATUS_DIR"

# Default input for downstream steps = raw fastqs
PROC_FASTQ_DIR="$PILOT_FASTQ_DIR"

# Wrapper log inside canonical run tree
WRAP_DIR="$RUN_DIR"
WRAP_LOG="${LOGS_DIR}/wrapper.log"
START_TIME="$(date '+%F %T')"
START_END_STATUS_FILE="${RUN_METADATA_DIR}/start_end_status.txt"

# Resolved runtime configuration summary
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

# Run metadata capture
cp -f "$CONFIG" "${RUN_METADATA_DIR}/resolved_config.env"

{
  echo "run_id=${RUN_ID}"
  echo "pipeline=bulk_rnaseq"
  echo "timestamp=$(date '+%F %T')"
  echo "operator=$(whoami)"
  echo "project_root=$PIPELINE_ROOT"
  echo "config=$CONFIG"
  echo "pilot_fastq_dir=$PILOT_FASTQ_DIR"
  echo "salmon_index=$SALMON_INDEX"
  echo "star_index=$STAR_INDEX"
  echo "tx2gene=$TX2GENE"
} > "${RUN_METADATA_DIR}/run_manifest.txt"

{
  echo "git_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo NA)"
  echo "git_commit=$(git rev-parse HEAD 2>/dev/null || echo NA)"
  echo "git_status=$(git status --short 2>/dev/null | wc -l | awk '{print ($1==0 ? "clean" : "dirty")}')"
} > "${RUN_METADATA_DIR}/pipeline_version.txt"

{
  echo "date=$(date '+%F %T')"
  echo -n "bash="; bash --version | head -n 1

  echo "Rscript_bin=${RSCRIPT_BIN:-NA}"
  [[ -n "${RSCRIPT_BIN:-}" && -x "$RSCRIPT_BIN" ]] && \
    { echo -n "Rscript="; "$RSCRIPT_BIN" --version 2>&1 | head -n 1; } || \
    echo "Rscript=NA"

  echo "salmon_bin=${SALMON_BIN:-NA}"
  [[ -n "${SALMON_BIN:-}" && -x "$SALMON_BIN" ]] && \
    { echo -n "salmon="; "$SALMON_BIN" --version 2>&1 | head -n 1; } || \
    echo "salmon=NA"

  echo "STAR_bin=${STAR_BIN:-NA}"
  [[ -n "${STAR_BIN:-}" && -x "$STAR_BIN" ]] && \
    { echo -n "STAR="; "$STAR_BIN" --version 2>&1 | head -n 1; } || \
    echo "STAR=NA"

  echo "fastp_bin=${FASTP_BIN:-NA}"
  [[ -n "${FASTP_BIN:-}" && -x "$FASTP_BIN" ]] && \
    { echo -n "fastp="; "$FASTP_BIN" --version 2>&1 | head -n 1; } || \
    echo "fastp=NA"

  echo "fastqc_bin=${FASTQC_BIN:-NA}"
  [[ -n "${FASTQC_BIN:-}" && -x "$FASTQC_BIN" ]] && \
    { echo -n "fastqc="; "$FASTQC_BIN" --version 2>&1 | head -n 1; } || \
    echo "fastqc=NA"

  echo "multiqc_bin=${MULTIQC_BIN:-NA}"
  [[ -n "${MULTIQC_BIN:-}" && -x "$MULTIQC_BIN" ]] && \
    { echo -n "multiqc="; "$MULTIQC_BIN" --version 2>&1 | head -n 1; } || \
    echo "multiqc=NA"
} > "${RUN_METADATA_DIR}/software_versions.txt"

{
  echo "start_time=${START_TIME}"
  echo "status=started"
} > "$START_END_STATUS_FILE"

# ========================================
# Reproducibility & Execution Consistency
# ========================================
ENV_METADATA_DIR="${RUN_METADATA_DIR}/environment"
R_SESSIONS_DIR="${RUN_METADATA_DIR}/r_sessions"
REPRO_DIR="${RUN_METADATA_DIR}/reproducibility"

mkdir -p \
  "$ENV_METADATA_DIR" \
  "$R_SESSIONS_DIR" \
  "$REPRO_DIR"

# Deterministic seed control
export PIPELINE_SEED
echo "pipeline_seed=${PIPELINE_SEED}" > "${RUN_METADATA_DIR}/pipeline_seed.txt"

# Export run-scoped metadata locations for downstream R stages
export PIPELINE_ROOT
export RUN_DIR
export RUN_METADATA_DIR
export ENV_METADATA_DIR
export R_SESSIONS_DIR
export REPRO_DIR

record_environment_snapshots() {
  echo "[INFO] Recording reproducibility metadata snapshot" | tee -a "$WRAP_LOG"
  
  if command -v conda >/dev/null 2>&1; then
    conda env export > "${ENV_METADATA_DIR}/conda_env_export.yml" 2>/dev/null || \
      echo "WARNING: conda env export failed" > "${ENV_METADATA_DIR}/conda_env_export.yml"

    conda list --explicit > "${ENV_METADATA_DIR}/conda_explicit.txt" 2>/dev/null || \
      echo "WARNING: conda list --explicit failed" > "${ENV_METADATA_DIR}/conda_explicit.txt"

    conda list > "${ENV_METADATA_DIR}/conda_list.txt" 2>/dev/null || \
      echo "WARNING: conda list failed" > "${ENV_METADATA_DIR}/conda_list.txt"
  else
    echo "WARNING: conda not found in PATH" > "${ENV_METADATA_DIR}/conda_env_export.yml"
    echo "WARNING: conda not found in PATH" > "${ENV_METADATA_DIR}/conda_explicit.txt"
    echo "WARNING: conda not found in PATH" > "${ENV_METADATA_DIR}/conda_list.txt"
  fi

  {
    echo "timestamp=$(date '+%F %T')"
    echo "run_id=${RUN_ID}"
    echo "pipeline=bulk_rnaseq"
    echo "pipeline_seed=${PIPELINE_SEED}"
    echo "config=${CONFIG}"
    echo "pipeline_root=${PIPELINE_ROOT}"
    echo
    env | sort
  } > "${ENV_METADATA_DIR}/env_vars.txt"

  {
    echo "timestamp=$(date '+%F %T')"
    echo "run_id=${RUN_ID}"
    echo "pipeline_seed=${PIPELINE_SEED}"
    echo
    echo "[R]"
    if [[ -n "${RSCRIPT_BIN:-}" && -x "$RSCRIPT_BIN" ]]; then
      "$RSCRIPT_BIN" --version 2>&1
    else
      echo "Rscript=NA"
    fi
    echo
    echo "[salmon]"
    if [[ -n "${SALMON_BIN:-}" && -x "$SALMON_BIN" ]]; then
      "$SALMON_BIN" --version 2>&1
    else
      echo "salmon=NA"
    fi
    echo
    echo "[STAR]"
    if [[ -n "${STAR_BIN:-}" && -x "$STAR_BIN" ]]; then
      "$STAR_BIN" --version 2>&1
    else
      echo "STAR=NA"
    fi
    echo
    echo "[fastp]"
    if [[ -n "${FASTP_BIN:-}" && -x "$FASTP_BIN" ]]; then
      "$FASTP_BIN" --version 2>&1
    else
      echo "fastp=NA"
    fi
    echo
    echo "[fastqc]"
    if [[ -n "${FASTQC_BIN:-}" && -x "$FASTQC_BIN" ]]; then
      "$FASTQC_BIN" --version 2>&1
    else
      echo "fastqc=NA"
    fi
    echo
    echo "[multiqc]"
    if [[ -n "${MULTIQC_BIN:-}" && -x "$MULTIQC_BIN" ]]; then
      "$MULTIQC_BIN" --version 2>&1
    else
      echo "multiqc=NA"
    fi
  } > "${ENV_METADATA_DIR}/tool_versions_snapshot.txt"
}

record_environment_snapshots

# --- helpers / boolean handling / logging ---
is_true() {
  case "${1,,}" in
    1|true|yes|y|on) return 0 ;;
    *) return 1 ;;
  esac
}

log() {
  local level="INFO"

  if [[ "$1" == "INFO" || "$1" == "WARN" || "$1" == "ERROR" ]]; then
    level="$1"
    shift
  fi

  local message="$*"
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"

  if [[ -n "${CURRENT_STAGE:-}" ]]; then
    echo "[$ts] $level stage=$CURRENT_STAGE message=\"$message\"" | tee -a "$WRAP_LOG"
  else
    echo "[$ts] $level message=\"$message\"" | tee -a "$WRAP_LOG"
  fi
}

log_stage_line() {
  local stage_name="$1"
  local level="$2"
  shift 2

  local message="$*"
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"

  echo "[$ts] $level stage=$stage_name message=\"$message\""
}

get_free_disk_gb() {
  local target_path="$1"
  df -BG "$target_path" | awk 'NR==2 {gsub(/G/, "", $4); print $4}'
}

get_available_mem_gb() {
  awk '/MemAvailable:/ {printf "%d\n", $2/1024/1024}' /proc/meminfo
}

get_available_cpus() {
  nproc
}

validate_resources() {
  local disk_gb
  local mem_gb
  local cpu_count

  disk_gb="$(get_free_disk_gb "$RUN_DIR")"
  mem_gb="$(get_available_mem_gb)"
  cpu_count="$(get_available_cpus)"

  log INFO "Resource check: free_disk_gb=$disk_gb min_required=$MIN_FREE_DISK_GB"
  log INFO "Resource check: available_mem_gb=$mem_gb min_required=$MIN_FREE_MEM_GB"
  log INFO "Resource check: available_cpus=$cpu_count min_required=$MIN_AVAILABLE_CPUS"

  if [[ "$disk_gb" -lt "$MIN_FREE_DISK_GB" ]]; then
    log ERROR "Insufficient disk space: free_disk_gb=$disk_gb required_gb=$MIN_FREE_DISK_GB"
    exit 6
  fi

  if [[ "$mem_gb" -lt "$MIN_FREE_MEM_GB" ]]; then
    log ERROR "Insufficient memory: available_mem_gb=$mem_gb required_gb=$MIN_FREE_MEM_GB"
    exit 6
  fi

  if [[ "$cpu_count" -lt "$MIN_AVAILABLE_CPUS" ]]; then
    log ERROR "Insufficient CPU availability: available_cpus=$cpu_count required_cpus=$MIN_AVAILABLE_CPUS"
    exit 6
  fi
}

stage_marker_path() {
  local stage_name="$1"
  local marker_name="$2"
  echo "${STAGE_STATUS_DIR}/${stage_name}.${marker_name}"
}

mark_stage_started() {
  local stage_name="$1"
  rm -f "$(stage_marker_path "$stage_name" completed)" \
        "$(stage_marker_path "$stage_name" failed)"
  : > "$(stage_marker_path "$stage_name" started)"
}

mark_stage_completed() {
  local stage_name="$1"
  : > "$(stage_marker_path "$stage_name" completed)"
}

mark_stage_failed() {
  local stage_name="$1"
  local exit_code="$2"
  {
    echo "stage=${stage_name}"
    echo "exit_code=${exit_code}"
    echo "timestamp=$(date '+%F %T')"
  } > "$(stage_marker_path "$stage_name" failed)"
}

stage_in_range() {
  local stage="$1"

  if [[ -n "$START_STAGE" && -z "${__START_REACHED:-}" ]]; then
    if [[ "$stage" == "$START_STAGE" ]]; then
      __START_REACHED=1
    else
      return 1
    fi
  fi

  if [[ -n "$END_STAGE" && -n "${__END_REACHED:-}" ]]; then
    return 1
  fi

  if [[ -n "$END_STAGE" && "$stage" == "$END_STAGE" ]]; then
    __END_REACHED=1
  fi

  return 0
}

should_run_stage() {
  local stage="$1"

  local completed
  local failed
  local started

  completed="$(stage_marker_path "$stage" completed)"
  failed="$(stage_marker_path "$stage" failed)"
  started="$(stage_marker_path "$stage" started)"

  if ! stage_in_range "$stage"; then
    return 1
  fi

  if is_true "$RERUN_FAILED_ONLY"; then
    [[ -f "$failed" ]] && return 0
    return 1
  fi

  if [[ -f "$completed" ]]; then
    return 1
  fi

  if [[ -f "$started" && ! -f "$completed" ]]; then
    return 0
  fi

  return 0
}

run_stage() {
  local stage_name="$1"
  shift

  local stage_start_ts
  local stage_end_ts
  local duration
  local exit_code

  CURRENT_STAGE="$stage_name"

  local stage_log="${STAGE_LOG_DIR}/${stage_name}.log"

  if ! should_run_stage "$stage_name"; then
    log INFO "SKIP"
    CURRENT_STAGE=""
    return 0
  fi

  stage_start_ts="$(date +%s)"
  log INFO "START"
  log_stage_line "$stage_name" INFO "START" >> "$stage_log"

  mark_stage_started "$stage_name"

  if "$@" > >(tee -a "$stage_log") 2> >(tee -a "$stage_log" >&2); then
    exit_code=0
  else
    exit_code=$?
  fi

  stage_end_ts="$(date +%s)"
  duration=$((stage_end_ts - stage_start_ts))

  if [[ $exit_code -ne 0 ]]; then
    log ERROR "exit_code=$exit_code detail=Stage failed"
    log ERROR "END status=failure duration=${duration}s"

    log_stage_line "$stage_name" ERROR "exit_code=$exit_code detail=Stage failed" >> "$stage_log"
    log_stage_line "$stage_name" ERROR "END status=failure duration=${duration}s" >> "$stage_log"

    mark_stage_failed "$stage_name" "$exit_code"

    {
      echo "end_time=$(date '+%F %T')"
      echo "status=failed"
      echo "failed_stage=${stage_name}"
      echo "exit_code=${exit_code}"
    } >> "$START_END_STATUS_FILE"

    exit $exit_code
  fi

  mark_stage_completed "$stage_name"

  log INFO "END status=success duration=${duration}s"
  log_stage_line "$stage_name" INFO "END status=success duration=${duration}s" >> "$stage_log"

  CURRENT_STAGE=""
}

########################################
# 0) LOCALIZE RAW FASTQS (staging -> ext4)
########################################
log INFO "=== STAGE 0: LOCALIZE RAW FASTQS ==="
if is_true "$DO_LOCALIZE_RAW"; then
  log INFO "RAW_SRC_DIR=$RAW_SRC_DIR"
  log INFO "RAW_LOCAL_ROOT=$RAW_LOCAL_ROOT"
  [[ -d "$RAW_SRC_DIR" ]] || { echo "ERROR: RAW_SRC_DIR not found: $RAW_SRC_DIR" >&2; exit 3; }

  RAW_LOCAL_DIR="${RAW_LOCAL_ROOT}/${RUN_ID}"
  mkdir -p "$RAW_LOCAL_DIR"

    # Copy ONLY the FASTQs referenced by the symlink farm (PILOT_FASTQ_DIR)
    # This prevents copying unrelated vendor FASTQs.
    shopt -s nullglob
    for link in "$PILOT_FASTQ_DIR"/*.fq.gz "$PILOT_FASTQ_DIR"/*.fastq.gz; do
      real="$(readlink -f "$link" || true)"
      [[ -n "$real" ]] || { log "WARN: could not resolve: $link"; continue; }

      [[ -f "$real" ]] || { log "WARN: resolved path missing: $real (from $link)"; continue; }

      # Safety: ensure the resolved file is actually inside RAW_SRC_DIR
      case "$real" in
        "$RAW_SRC_DIR"/*) : ;;
        *)
          log "WARN: skipping (not under RAW_SRC_DIR): $real (from $link)"
          continue
          ;;
      esac

      base="$(basename "$real")"
      if [[ ! -s "$RAW_LOCAL_DIR/$base" ]]; then
        cp -v "$real" "$RAW_LOCAL_DIR/$base" 2>&1 | tee -a "$WRAP_LOG"
      fi
    done
    shopt -u nullglob

  log INFO "Localized FASTQs: $(ls -1 "$RAW_LOCAL_DIR"/*.gz 2>/dev/null | wc -l)"
else
  log INFO "LOCALIZE skipped (DO_LOCALIZE_RAW=$DO_LOCALIZE_RAW)"
  RAW_LOCAL_DIR="$PILOT_FASTQ_DIR"
fi
echo | tee -a "$WRAP_LOG"

########################################
# 0b) INTEGRITY CHECK (gzip -t)
########################################
INTEGRITY_DIR="$WORKING_DIR/integrity"
OK_FASTQS="$INTEGRITY_DIR/ok_fastqs.txt"
BAD_FASTQS="$INTEGRITY_DIR/bad_fastqs.txt"
mkdir -p "$INTEGRITY_DIR"
: > "$OK_FASTQS"
: > "$BAD_FASTQS"

log INFO "=== STAGE 0b: INTEGRITY CHECK (gzip -t) ==="
if is_true "$DO_INTEGRITY"; then
  shopt -s nullglob
  for f in "$RAW_LOCAL_DIR"/*.fq.gz "$RAW_LOCAL_DIR"/*.fastq.gz; do
    if gzip -t "$f" 2>/dev/null; then
      echo "$f" >> "$OK_FASTQS"
    else
      echo "$f" >> "$BAD_FASTQS"
      log WARN "BAD gzip stream: $f"
    fi
  done
  shopt -u nullglob

  log INFO "Integrity OK: $(wc -l < "$OK_FASTQS")"
  log INFO "Integrity BAD: $(wc -l < "$BAD_FASTQS")"
else
  log INFO "INTEGRITY skipped (DO_INTEGRITY=$DO_INTEGRITY)"
fi
echo | tee -a "$WRAP_LOG"

########################################
# 0c) FILTER INPUT SET (fail-forward)
########################################
FILTER_DIR="$WORKING_DIR/filtered_fastqs"
mkdir -p "$FILTER_DIR"

log INFO "=== STAGE 0c: FILTER FASTQS (based on integrity) ==="
if is_true "$DO_INTEGRITY"; then
  bad_n=$(wc -l < "$BAD_FASTQS" | tr -d ' ')
  if [[ "$bad_n" -gt 0 ]]; then
    if is_true "$SKIP_BAD_FASTQS"; then
      log WARN "BAD FASTQs detected ($bad_n). SKIP_BAD_FASTQS=1 => excluding them from downstream steps."
    else
      echo "ERROR: BAD FASTQs detected ($bad_n) and SKIP_BAD_FASTQS=0. Aborting." >&2
      exit 9
    fi
  fi

  # Build filtered set: symlink only OK FASTQs
  rm -f "$FILTER_DIR"/*.fq.gz "$FILTER_DIR"/*.fastq.gz 2>/dev/null || true
  while read -r f; do
    [[ -n "$f" ]] || continue
    ln -sf "$f" "$FILTER_DIR/$(basename "$f")"
  done < "$OK_FASTQS"

  ok_n=$(wc -l < "$OK_FASTQS" | tr -d ' ')
  if [[ "$ok_n" -eq 0 ]]; then
    echo "ERROR: integrity check produced 0 OK FASTQs; aborting." >&2
    exit 9
  fi

  RAW_LOCAL_DIR="$FILTER_DIR"
  log INFO "Downstream input set to filtered dir: $RAW_LOCAL_DIR (files=$(ls -1 "$RAW_LOCAL_DIR"/*.gz 2>/dev/null | wc -l))"
else
  log INFO "FILTER skipped (DO_INTEGRITY=$DO_INTEGRITY)"
fi
echo | tee -a "$WRAP_LOG"

# Suggested selectors for Salmon/STAR input (raw|trimmed)
: "${SALMON_INPUT:=trimmed}"
: "${STAR_INPUT:=trimmed}"

if is_true "$DO_SALMON" || is_true "$DO_TXIMPORT"; then
  log INFO "SALMON_INPUT=$SALMON_INPUT"
else
  log INFO "SALMON_INPUT=NA (DO_SALMON=$DO_SALMON)"
fi

if is_true "$DO_STAR"; then
  log INFO "STAR_INPUT=$STAR_INPUT"
else
  log INFO "STAR_INPUT=NA (DO_STAR=$DO_STAR)"
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
  [[ -n "${FASTQC_BIN:-}" ]] || { echo "ERROR: FASTQC_BIN is empty" >&2; exit 5; }
  [[ -x "$FASTQC_BIN" ]] || { echo "ERROR: FASTQC_BIN not executable: $FASTQC_BIN" >&2; exit 5; }

  [[ -n "${MULTIQC_BIN:-}" ]] || { echo "ERROR: MULTIQC_BIN is empty" >&2; exit 5; }
  [[ -x "$MULTIQC_BIN" ]] || { echo "ERROR: MULTIQC_BIN not executable: $MULTIQC_BIN" >&2; exit 5; }
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
  [[ -x "$QC_SCRIPT" ]] || { echo "ERROR: $QC_SCRIPT not found or not executable" >&2; exit 5; }
fi

if is_true "$DO_TRIM"; then
  [[ -x "$TRIM_SCRIPT" ]] || { echo "ERROR: $TRIM_SCRIPT not found or not executable" >&2; exit 5; }
fi

if is_true "$DO_SALMON" || is_true "$DO_TXIMPORT"; then
  [[ -x "$SALMON_SCRIPT" ]] || { echo "ERROR: $SALMON_SCRIPT not found or not executable" >&2; exit 5; }
fi

if is_true "$DO_TXIMPORT"; then
  [[ -f "$TXIMPORT_SCRIPT" ]] || { echo "ERROR: $TXIMPORT_SCRIPT not found" >&2; exit 5; }
fi

if is_true "$DO_STAR"; then
  [[ -x "$STAR_SCRIPT" ]] || { echo "ERROR: $STAR_SCRIPT not found or not executable" >&2; exit 5; }
fi

export FASTQC_BIN
export MULTIQC_BIN

validate_resources

########################################
# 1) QC
########################################
log "=== STAGE 1: QC RAW (FastQC + MultiQC) ==="
if is_true "$DO_QC_RAW"; then
  run_stage "qc_raw" \
    "$QC_SCRIPT" \
    -i "$RAW_LOCAL_DIR" \
    -o "$QC_OUT_ROOT" \
    --run-id "qc_${RUN_ID}" \
    -t "$THREADS"

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
  run_stage "trim_fastp" \
    "$TRIM_SCRIPT" \
    -i "$RAW_LOCAL_DIR" \
    -o "$TRIM_OUT_ROOT" \
    --run-id "trim_${RUN_ID}" \
    -t "$THREADS"

TRIM_RUN_DIR="${TRIM_OUT_ROOT}/trim_${RUN_ID}"

if [[ ! -d "$TRIM_RUN_DIR" ]]; then
  log "TRIM_RUN_DIR not found for current RUN_ID, attempting fallback"

  TRIM_RUN_DIR="$(ls -dt ${TRIM_OUT_ROOT}/trim_* 2>/dev/null | head -n 1 || true)"

  if [[ -z "$TRIM_RUN_DIR" || ! -d "$TRIM_RUN_DIR" ]]; then
    echo "ERROR: No existing TRIM_RUN_DIR found for fallback" >&2
    exit 4
  fi

  log "Using fallback TRIM_RUN_DIR=$TRIM_RUN_DIR"
fi

PROC_FASTQ_DIR="$TRIM_RUN_DIR"
log "PROC_FASTQ_DIR=$PROC_FASTQ_DIR"
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
  run_stage "qc_posttrim" \
    "$QC_SCRIPT" \
    -i "$PROC_FASTQ_DIR" \
    -o "$QC_OUT_ROOT" \
    --run-id "qc_posttrim_${RUN_ID}" \
    -t "$THREADS"

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
    raw) echo "$RAW_LOCAL_DIR" ;;
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

  run_stage "salmon_quant" \
    "$SALMON_SCRIPT" \
    -i "$SALMON_INPUT_DIR" \
    -o "$SALMON_OUT_ROOT" \
    --run-id "salmon_${RUN_ID}" \
    -t "$THREADS" \
    -r "$SALMON_INDEX"

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

  run_stage "tximport_genelevel" \
    Rscript "$TXIMPORT_SCRIPT" \
    -i "$SALMON_RUN_DIR" \
    -o "$TXIMPORT_OUT_ROOT" \
    -m "$TX2GENE" \
    --run-id "txi_${RUN_ID}"

  TXI_RUN_DIR="${TXIMPORT_OUT_ROOT}/txi_${RUN_ID}"
  log "TXI_RUN_DIR=$TXI_RUN_DIR"
else
  log "TXIMPORT skipped (DO_TXIMPORT=$DO_TXIMPORT)"
fi
echo | tee -a "$WRAP_LOG"

########################################
# 5) STAR
########################################
if is_true "$DO_STAR"; then
  log "=== STAGE 5: STAR ALIGNMENT [input=$STAR_INPUT] ==="
  if [[ -z "${STAR_INPUT_DIR:-}" ]]; then
    echo "ERROR: STAR_INPUT_DIR is empty; cannot run STAR" >&2
    exit 4
  fi
  if [[ ! -d "$STAR_INPUT_DIR" ]]; then
    echo "ERROR: STAR_INPUT_DIR not found: $STAR_INPUT_DIR" >&2
    exit 4
  fi

  run_stage "star_align" \
    "$STAR_SCRIPT" \
    -i "$STAR_INPUT_DIR" \
    -o "$STAR_OUT_ROOT" \
    --run-id "star_${RUN_ID}" \
    -t "$THREADS" \
    -r "$STAR_INDEX"

  STAR_RUN_DIR="${STAR_OUT_ROOT}/star_${RUN_ID}"
  log "STAR_RUN_DIR=$STAR_RUN_DIR"
else
  log "=== STAGE 5: STAR skipped (DO_STAR=$DO_STAR) ==="
fi
echo | tee -a "$WRAP_LOG"

{
  echo "start_time=${START_TIME}"
  echo "end_time=$(date '+%F %T')"
  echo "status=completed"
} > "$START_END_STATUS_FILE"

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
