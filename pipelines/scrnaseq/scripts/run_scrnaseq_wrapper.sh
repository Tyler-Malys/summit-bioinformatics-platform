#!/usr/bin/env bash
set -euo pipefail

########################################
# scRNA-seq canonical wrapper
########################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_ROOT_DEFAULT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEFAULT_CONFIG="${PIPELINE_ROOT_DEFAULT}/config/template_scrnaseq.env"

CONFIG="${1:-$DEFAULT_CONFIG}"
CLI_ENGINE="${2:-}"
CLI_MANIFEST="${3:-}"

EXTERNAL_RUN_ID="${RUN_ID:-}"
EXTERNAL_START_STAGE="${START_STAGE:-}"
EXTERNAL_END_STAGE="${END_STAGE:-}"
EXTERNAL_RERUN_FAILED_ONLY="${RERUN_FAILED_ONLY:-}"

if [[ ! -f "$CONFIG" ]]; then
  echo "ERROR: config file not found: $CONFIG" >&2
  exit 2
fi

# shellcheck disable=SC1090
source "$CONFIG"

if [[ -n "$EXTERNAL_RUN_ID" ]]; then
  RUN_ID="$EXTERNAL_RUN_ID"
fi

if [[ -n "$EXTERNAL_START_STAGE" ]]; then
  START_STAGE="$EXTERNAL_START_STAGE"
fi

if [[ -n "$EXTERNAL_END_STAGE" ]]; then
  END_STAGE="$EXTERNAL_END_STAGE"
fi

if [[ -n "$EXTERNAL_RERUN_FAILED_ONLY" ]]; then
  RERUN_FAILED_ONLY="$EXTERNAL_RERUN_FAILED_ONLY"
fi

########################################
# helpers
########################################

log() {
  local level="INFO"

  if [[ "$1" == "INFO" || "$1" == "WARN" || "$1" == "ERROR" ]]; then
    level="$1"
    shift
  fi

  local message="$*"
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"

  if [[ "${WRITE_WRAPPER_LOG:-1}" == "1" ]]; then
    if [[ -n "${CURRENT_STAGE:-}" ]]; then
      echo "[$ts] $level stage=$CURRENT_STAGE message=\"$message\"" | tee -a "$WRAP_LOG"
    else
      echo "[$ts] $level message=\"$message\"" | tee -a "$WRAP_LOG"
    fi
  else
    if [[ -n "${CURRENT_STAGE:-}" ]]; then
      echo "[$ts] $level stage=$CURRENT_STAGE message=\"$message\""
    else
      echo "[$ts] $level message=\"$message\""
    fi
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

require_var() {
  local var_name="$1"
  if [[ -z "${!var_name:-}" ]]; then
    echo "ERROR: required variable missing: $var_name" >&2
    exit 2
  fi
}

require_file() {
  local path="$1"
  [[ -f "$path" ]] || { echo "ERROR: required file not found: $path" >&2; exit 3; }
}

require_dir() {
  local path="$1"
  [[ -d "$path" ]] || { echo "ERROR: required directory not found: $path" >&2; exit 3; }
}

normalize_bool() {
  local var_name="$1"
  local val="${!var_name:-0}"
  case "$val" in
    1|true|TRUE|yes|YES) printf -v "$var_name" "1" ;;
    0|false|FALSE|no|NO|"") printf -v "$var_name" "0" ;;
    *)
      echo "ERROR: invalid boolean value for $var_name: $val" >&2
      exit 2
      ;;
  esac
}

manifest_has_columns() {
  local manifest="$1"
  shift
  local expected=("$@")

  local header
  header="$(head -n 1 "$manifest")"

  local missing=()
  local col
  for col in "${expected[@]}"; do
    if ! printf '%s\n' "$header" | tr '\t' '\n' | grep -Fxq "$col"; then
      missing+=("$col")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "ERROR: manifest missing expected columns: ${missing[*]}" >&2
    echo "Manifest: $manifest" >&2
    echo "Header: $header" >&2
    exit 3
  fi
}

########################################
# normalize config
########################################

PIPELINE_ROOT="${PIPELINE_ROOT:-$PIPELINE_ROOT_DEFAULT}"
RUNS_ROOT="${RUNS_ROOT:-${PIPELINE_ROOT}/runs}"
WRAPPER_LOG_NAME="${WRAPPER_LOG_NAME:-wrapper.log}"

if [[ -n "$CLI_ENGINE" ]]; then
  ENGINE="$CLI_ENGINE"
fi
ENGINE="${ENGINE:-starsolo}"

if [[ -n "$CLI_MANIFEST" ]]; then
  MANIFEST_FILE="$CLI_MANIFEST"
fi
MANIFEST_FILE="${MANIFEST_FILE:-}"
PREPROCESS_SOURCE_RUN_DIR="${PREPROCESS_SOURCE_RUN_DIR:-}"
COMPARE_SOURCE_RUN_DIR="${COMPARE_SOURCE_RUN_DIR:-}"
COMPARE_CELLRANGER_SOURCE_RUN_DIR="${COMPARE_CELLRANGER_SOURCE_RUN_DIR:-}"
COMPARE_STARSOLO_SOURCE_RUN_DIR="${COMPARE_STARSOLO_SOURCE_RUN_DIR:-}"

RUN_ID="${RUN_ID:-}"
if [[ -z "$RUN_ID" ]]; then
  RUN_ID="scrna_${ENGINE}_$(date +%Y%m%d_%H%M%S)"
fi

normalize_bool DRY_RUN
normalize_bool WRITE_WRAPPER_LOG
normalize_bool WRITE_REPO_LEVEL_EXPORTS
normalize_bool RUN_PREPROCESS
normalize_bool RUN_QC
normalize_bool RUN_DOWNSTREAM_CORE
normalize_bool RUN_MARKERS
normalize_bool RUN_ANNOTATION
normalize_bool RUN_DIFFERENTIAL
normalize_bool RUN_PATHWAY
normalize_bool RUN_VISUALIZATION
normalize_bool RUN_REPORT
normalize_bool RUN_COMPARE_BACKENDS

# ========================================
# Restart / Execution Control
# ========================================
START_STAGE="${START_STAGE:-}"
END_STAGE="${END_STAGE:-}"
RERUN_FAILED_ONLY="${RERUN_FAILED_ONLY:-false}"
MIN_FREE_DISK_GB="${MIN_FREE_DISK_GB:-10}"
MIN_FREE_MEM_GB="${MIN_FREE_MEM_GB:-4}"
MIN_AVAILABLE_CPUS="${MIN_AVAILABLE_CPUS:-2}"
# ========================================
# Reproducibility / Execution Consistency
# ========================================
PIPELINE_SEED="${PIPELINE_SEED:-12345}"
########################################
# validate config
########################################

require_var PIPELINE_ROOT
require_var RUNS_ROOT
require_var ENGINE
require_var THREADS
require_var MEMORY_GB
require_var SPECIES
require_var RSCRIPT_BIN
require_var SCDBLFINDER_RSCRIPT_BIN
require_file "$RSCRIPT_BIN"
require_file "$SCDBLFINDER_RSCRIPT_BIN"

case "${ENGINE,,}" in
  cellranger|starsolo) ;;
  *)
    echo "ERROR: ENGINE must be one of: cellranger, starsolo" >&2
    exit 2
    ;;
esac

if [[ -z "$MANIFEST_FILE" ]]; then
  case "${ENGINE,,}" in
    cellranger) MANIFEST_FILE="${PIPELINE_ROOT}/metadata/cellranger_runs.tsv" ;;
    starsolo)   MANIFEST_FILE="${PIPELINE_ROOT}/metadata/starsolo_runs.tsv" ;;
  esac
fi

########################################
# reference resolution
########################################

REF_ROOT="${REF_ROOT:-/home/summitadmin/refs}"
ORGANISM="${ORGANISM:-}"
GENOME_BUILD="${GENOME_BUILD:-}"
ANNOTATION_VERSION="${ANNOTATION_VERSION:-}"

if [[ -n "$ORGANISM" && -n "$GENOME_BUILD" && -n "$ANNOTATION_VERSION" ]]; then
  REF_BASE="${REF_ROOT}/${ORGANISM}/${GENOME_BUILD}/${ANNOTATION_VERSION}"
  STAR_INDEX="${STAR_INDEX:-${REF_BASE}/star_index}"
  CELLRANGER_REF="${CELLRANGER_REF:-${REF_BASE}/cellranger_ref}"
fi

require_dir "$PIPELINE_ROOT"
require_file "$MANIFEST_FILE"

########################################
# run directory setup
########################################

RUN_DIR="${RUNS_ROOT}/${RUN_ID}"
INPUT_DIR="${RUN_DIR}/input"
WORKING_DIR="${RUN_DIR}/working"
LOGS_DIR="${RUN_DIR}/logs"
QC_DIR="${RUN_DIR}/qc"
OUTPUTS_DIR="${RUN_DIR}/outputs"
DOWNSTREAM_DIR="${RUN_DIR}/downstream"
FINAL_DIR="${RUN_DIR}/final"
RUN_METADATA_DIR="${RUN_DIR}/run_metadata"
ENV_METADATA_DIR="${RUN_METADATA_DIR}/environment"
R_SESSIONS_DIR="${RUN_METADATA_DIR}/r_sessions"

mkdir -p \
  "$INPUT_DIR" \
  "$WORKING_DIR" \
  "$LOGS_DIR" \
  "$QC_DIR" \
  "$OUTPUTS_DIR" \
  "$DOWNSTREAM_DIR" \
  "$FINAL_DIR" \
  "$RUN_METADATA_DIR" \
  "$ENV_METADATA_DIR" \
  "$R_SESSIONS_DIR"

WRAP_LOG="${LOGS_DIR}/${WRAPPER_LOG_NAME}"
START_TIME="$(date '+%F %T')"
START_END_STATUS_FILE="${RUN_METADATA_DIR}/start_end_status.txt"

STAGE_LOG_DIR="${LOGS_DIR}/stages"
STAGE_STATUS_DIR="${RUN_METADATA_DIR}/stage_status"
mkdir -p "$STAGE_LOG_DIR" "$STAGE_STATUS_DIR"

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

record_environment_snapshots() {
  log INFO "Recording environment snapshots"

  if command -v conda >/dev/null 2>&1; then
    conda env export > "${ENV_METADATA_DIR}/conda_env.yml" 2>/dev/null || true
    conda list > "${ENV_METADATA_DIR}/conda_list.txt" 2>/dev/null || true
    conda list --explicit > "${ENV_METADATA_DIR}/conda_explicit.txt" 2>/dev/null || true
  else
    log WARN "conda not found in PATH; skipping conda environment exports"
  fi

  env | sort > "${ENV_METADATA_DIR}/environment_variables.txt"

  {
    echo "date=$(date '+%F %T')"
    echo "pipeline_seed=${PIPELINE_SEED}"
    echo -n "bash="; bash --version | head -n 1
    echo -n "R="; R --version 2>/dev/null | head -n 1 || true
    echo -n "Rscript="; Rscript --version 2>&1 | head -n 1 || true
    echo -n "STAR="; STAR --version 2>&1 | head -n 1 || true
    if [[ -n "${CELLRANGER_BIN:-}" ]]; then
      echo -n "cellranger="; "$CELLRANGER_BIN" --version 2>&1 | head -n 1 || true
    else
      echo "cellranger=NA"
    fi
  } > "${ENV_METADATA_DIR}/tool_versions.txt"
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

  if [[ "$RERUN_FAILED_ONLY" == "true" ]]; then
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
# metadata capture
########################################

cp -f "$CONFIG" "${RUN_METADATA_DIR}/resolved_config.env"
cp -f "$MANIFEST_FILE" "${INPUT_DIR}/$(basename "$MANIFEST_FILE")"

{
  echo "run_id=${RUN_ID}"
  echo "pipeline_name=${PIPELINE_NAME:-scrnaseq}"
  echo "run_mode=${RUN_MODE:-unknown}"
  echo "engine=${ENGINE}"
  echo "config=${CONFIG}"
  echo "manifest_file=${MANIFEST_FILE}"
  echo "pipeline_root=${PIPELINE_ROOT}"
  echo "runs_root=${RUNS_ROOT}"
  echo "run_dir=${RUN_DIR}"
  echo "timestamp=$(date '+%F %T')"
  echo "operator=$(whoami)"
} > "${RUN_METADATA_DIR}/run_manifest.txt"

{
  echo "git_branch=$(git -C "$PIPELINE_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo NA)"
  echo "git_commit=$(git -C "$PIPELINE_ROOT" rev-parse HEAD 2>/dev/null || echo NA)"
  echo "git_status=$(git -C "$PIPELINE_ROOT" status --short 2>/dev/null | wc -l | awk '{print ($1==0 ? "clean" : "dirty")}')"
} > "${RUN_METADATA_DIR}/pipeline_version.txt"

{
  echo "date=$(date '+%F %T')"
  echo -n "bash="; bash --version | head -n 1
  echo -n "Rscript="; Rscript --version 2>&1 | head -n 1 || true
  echo -n "STAR="; STAR --version 2>&1 | head -n 1 || true
  if [[ -n "${CELLRANGER_BIN:-}" ]]; then
    echo -n "cellranger="; "$CELLRANGER_BIN" --version 2>&1 | head -n 1 || true
  else
    echo "cellranger=NA"
  fi
} > "${RUN_METADATA_DIR}/software_versions.txt"
  echo "${PIPELINE_SEED}" > "${RUN_METADATA_DIR}/pipeline_seed.txt"

  record_environment_snapshots
{
  echo "start_time=${START_TIME}"
  echo "status=started"
} > "$START_END_STATUS_FILE"

export PIPELINE_ROOT
export RUN_DIR
export RUN_METADATA_DIR
export ENV_METADATA_DIR
export R_SESSIONS_DIR
export PIPELINE_SEED

########################################
# banner
########################################

log "=== scRNA-seq wrapper start ==="
log "CONFIG=$CONFIG"
log "ENGINE=$ENGINE"
log "MANIFEST_FILE=$MANIFEST_FILE"
log "RUN_ID=$RUN_ID"
log "RUN_DIR=$RUN_DIR"
log "THREADS=$THREADS"
log "MEMORY_GB=$MEMORY_GB"
log "RUN_PREPROCESS=$RUN_PREPROCESS"
log "RUN_QC=$RUN_QC"
log "RUN_DOWNSTREAM_CORE=$RUN_DOWNSTREAM_CORE"
log "RUN_MARKERS=$RUN_MARKERS"
log "RUN_ANNOTATION=$RUN_ANNOTATION"
log "RUN_DIFFERENTIAL=$RUN_DIFFERENTIAL"
log "RUN_PATHWAY=$RUN_PATHWAY"
log "RUN_VISUALIZATION=$RUN_VISUALIZATION"
log "RUN_REPORT=$RUN_REPORT"
log "RUN_COMPARE_BACKENDS=$RUN_COMPARE_BACKENDS"

########################################
# engine-specific validation
########################################

case "${ENGINE,,}" in
  cellranger)
    require_var CELLRANGER_REF
    require_dir "$CELLRANGER_REF"
    require_var CELLRANGER_BIN
    require_file "$CELLRANGER_BIN"
    manifest_has_columns "$MANIFEST_FILE" run_id sample_id dataset fastq_path reference chemistry expected_cells notes
    ;;
  starsolo)
    require_var STAR_INDEX
    require_dir "$STAR_INDEX"
    command -v STAR >/dev/null 2>&1 || { echo "ERROR: STAR not found in PATH" >&2; exit 4; }
    manifest_has_columns "$MANIFEST_FILE" run_id fastq_dir sample_id chemistry
    ;;
esac
validate_resources

########################################
# dry run exit
########################################

if [[ "$DRY_RUN" == "1" ]]; then
  log "DRY_RUN=1, validation complete, exiting before execution."
  {
    echo "start_time=${START_TIME}"
    echo "end_time=$(date '+%F %T')"
    echo "status=dry_run_validated"
  } > "$START_END_STATUS_FILE"
  exit 0
fi

########################################
# stage placeholders
########################################

run_preprocess_stage() {
if [[ "$RUN_PREPROCESS" == "1" ]]; then
  log "PREPROCESS stage enabled"

  case "${ENGINE,,}" in
    cellranger)
      log "Dispatching Cell Ranger preprocessing"

      tail -n +2 "$MANIFEST_FILE" | while IFS=$'\t' read -r sample_run_id sample_id dataset fastq_path reference chemistry expected_cells notes; do
        [[ -z "${sample_run_id:-}" ]] && continue

        SAMPLE_OUT_DIR="${OUTPUTS_DIR}/cellranger/${sample_run_id}"
        SAMPLE_LOG="${LOGS_DIR}/${sample_run_id}_cellranger.log"

        mkdir -p "${OUTPUTS_DIR}/cellranger"

        if [[ "$fastq_path" = /* ]]; then
          FASTQ_PATH_RESOLVED="$fastq_path"
        else
          FASTQ_PATH_RESOLVED="${PIPELINE_ROOT}/${fastq_path}"
        fi

        require_dir "$FASTQ_PATH_RESOLVED"

        log "Cell Ranger sample=${sample_run_id} sample_id=${sample_id} fastq_path=${FASTQ_PATH_RESOLVED}"

        (
          cd "${OUTPUTS_DIR}/cellranger"
          "$CELLRANGER_BIN" count \
            --id="${sample_run_id}" \
            --create-bam=true \
            --transcriptome="${CELLRANGER_REF}" \
            --fastqs="${FASTQ_PATH_RESOLVED}" \
            --sample="${sample_id}" \
            --localcores="${THREADS}" \
            --localmem="${MEMORY_GB}"
        ) 2>&1 | tee "$SAMPLE_LOG"
      done
      ;;
    starsolo)
      log "Dispatching STARsolo preprocessing"

      tail -n +2 "$MANIFEST_FILE" | while IFS=$'\t' read -r sample_run_id fastq_dir sample_id chemistry; do
        [[ -z "${sample_run_id:-}" ]] && continue

        mkdir -p "${OUTPUTS_DIR}/starsolo"
        SAMPLE_OUT_DIR="${OUTPUTS_DIR}/starsolo/${sample_run_id}"
        SAMPLE_LOG="${LOGS_DIR}/${sample_run_id}_starsolo.log"

        if [[ "$fastq_dir" = /* ]]; then
          FASTQ_DIR_RESOLVED="$fastq_dir"
        else
          FASTQ_DIR_RESOLVED="${PIPELINE_ROOT}/${fastq_dir}"
        fi

        require_dir "$FASTQ_DIR_RESOLVED"
        mkdir -p "$SAMPLE_OUT_DIR"

        case "$chemistry" in
          10xv3)
            CB_START=1
            CB_LEN=16
            UMI_START=17
            UMI_LEN=12
            ;;
          10xv2)
            CB_START=1
            CB_LEN=16
            UMI_START=17
            UMI_LEN=10
            ;;
          *)
            echo "ERROR: unsupported chemistry for ${sample_run_id}: ${chemistry}" >&2
            exit 5
            ;;
        esac

        R1=$(ls -1 "$FASTQ_DIR_RESOLVED"/*_R1_*.fastq.gz 2>/dev/null | paste -sd, -)
        R2=$(ls -1 "$FASTQ_DIR_RESOLVED"/*_R2_*.fastq.gz 2>/dev/null | paste -sd, -)

        if [[ -z "$R1" || -z "$R2" ]]; then
          R1=$(ls -1 "$FASTQ_DIR_RESOLVED"/*_1.fastq.gz 2>/dev/null | paste -sd, -)
          R2=$(ls -1 "$FASTQ_DIR_RESOLVED"/*_2.fastq.gz 2>/dev/null | paste -sd, -)
        fi

        if [[ -z "$R1" || -z "$R2" ]]; then
          echo "ERROR: could not locate FASTQ pairs in ${FASTQ_DIR_RESOLVED} for ${sample_run_id}" >&2
          exit 5
        fi

        log "STARsolo sample=${sample_run_id} sample_id=${sample_id} fastq_dir=${FASTQ_DIR_RESOLVED}"

        STAR \
          --runThreadN "${THREADS}" \
          --genomeDir "${STAR_INDEX}" \
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
      ;;
  esac
else
  log "PREPROCESS stage disabled"
fi
}

run_qc_stage() {
if [[ "$RUN_QC" == "1" ]]; then
  log "QC stage enabled"

  case "${ENGINE,,}" in
    cellranger)
      tail -n +2 "$MANIFEST_FILE" | while IFS=$'\t' read -r sample_run_id sample_id dataset fastq_path reference chemistry expected_cells notes; do
        [[ -z "${sample_run_id:-}" ]] && continue

        if [[ "$RUN_PREPROCESS" == "1" ]]; then
          PREPROCESS_SAMPLE_DIR="${OUTPUTS_DIR}/cellranger/${sample_run_id}"
        else
          if [[ -z "$PREPROCESS_SOURCE_RUN_DIR" ]]; then
            echo "ERROR: RUN_QC=1 with RUN_PREPROCESS=0 requires PREPROCESS_SOURCE_RUN_DIR to be set" >&2
            exit 6
          fi
          PREPROCESS_SAMPLE_DIR="${PREPROCESS_SOURCE_RUN_DIR}/outputs/cellranger/${sample_run_id}"
        fi

        case "${QC_MATRIX_TYPE}" in
          filtered)
            MATRIX_DIR="${PREPROCESS_SAMPLE_DIR}/outs/filtered_feature_bc_matrix"
            ;;
          raw)
            MATRIX_DIR="${PREPROCESS_SAMPLE_DIR}/outs/raw_feature_bc_matrix"
            ;;
          *)
            echo "ERROR: unsupported QC_MATRIX_TYPE for cellranger: ${QC_MATRIX_TYPE}" >&2
            exit 6
            ;;
        esac

        require_dir "$MATRIX_DIR"

        SAMPLE_QC_DIR="${QC_DIR}/${sample_run_id}"
        QC_OBJECTS_DIR="${SAMPLE_QC_DIR}/objects"
        QC_TABLES_DIR="${SAMPLE_QC_DIR}/tables"
        QC_PLOTS_DIR="${SAMPLE_QC_DIR}/plots"

        mkdir -p "$QC_OBJECTS_DIR" "$QC_TABLES_DIR" "$QC_PLOTS_DIR"

        RAW_SCE="${QC_OBJECTS_DIR}/${sample_run_id}_${ENGINE}_raw_sce.rds"
        RAW_QC_SCE="${QC_OBJECTS_DIR}/${sample_run_id}_${ENGINE}_raw_qc_sce.rds"
        EMPTYDROPS_SCE="${QC_OBJECTS_DIR}/${sample_run_id}_${ENGINE}_emptydropsfiltered_sce.rds"
        LOWQ_SCE="${QC_OBJECTS_DIR}/${sample_run_id}_${ENGINE}_lowqfiltered_sce.rds"
        SCDBL_SCE="${QC_OBJECTS_DIR}/${sample_run_id}_${ENGINE}_scdblfinder_sce.rds"
        SINGLET_SCE="${QC_OBJECTS_DIR}/${sample_run_id}_${ENGINE}_singlets_sce.rds"

        RAW_QC_TSV="${QC_TABLES_DIR}/${sample_run_id}_${ENGINE}_raw_qc_metrics.tsv"
        EMPTYDROPS_TSV="${QC_TABLES_DIR}/${sample_run_id}_${ENGINE}_emptydrops.tsv"
        LOWQ_TSV="${QC_TABLES_DIR}/${sample_run_id}_${ENGINE}_lowq_filter.tsv"
        SCDBL_TSV="${QC_TABLES_DIR}/${sample_run_id}_${ENGINE}_scdblfinder.tsv"
        SINGLET_TSV="${QC_TABLES_DIR}/${sample_run_id}_${ENGINE}_singlet_filter.tsv"

        BARCODE_RANK_PNG="${QC_PLOTS_DIR}/${sample_run_id}_${ENGINE}_barcode_rank.png"

        log "Running QC for ${sample_run_id} using matrix dir ${MATRIX_DIR}"

        "$RSCRIPT_BIN" scripts/qc/01_build_sce_object.R "$MATRIX_DIR" "$sample_run_id" "$ENGINE" "$RAW_SCE"
        "$RSCRIPT_BIN" scripts/qc/02_compute_qc_metrics.R "$RAW_SCE" "$SPECIES" "$RAW_QC_SCE" "$RAW_QC_TSV"
        "$RSCRIPT_BIN" scripts/qc/03_barcode_rank_plot.R "$RAW_QC_TSV" "$BARCODE_RANK_PNG"
        "$RSCRIPT_BIN" scripts/qc/04_run_emptydrops.R "$RAW_QC_SCE" "$QC_EMPTYDROPS_LOWER" "$EMPTYDROPS_TSV" "$QC_EMPTYDROPS_FDR"
        "$RSCRIPT_BIN" scripts/qc/05_apply_emptydrops_filter.R "$RAW_QC_SCE" "$EMPTYDROPS_TSV" "$EMPTYDROPS_SCE"
        "$RSCRIPT_BIN" scripts/qc/06_filter_low_quality_cells.R "$EMPTYDROPS_SCE" "$QC_MIN_COUNTS" "$QC_MIN_GENES" "$QC_MAX_PCT_MITO" "$LOWQ_SCE" "$LOWQ_TSV"
        "$SCDBLFINDER_RSCRIPT_BIN" scripts/qc/07_run_scdblfinder.R "$LOWQ_SCE" "$SCDBL_SCE" "$SCDBL_TSV"
        "$SCDBLFINDER_RSCRIPT_BIN" scripts/qc/08_remove_doublets.R "$SCDBL_SCE" "$SINGLET_SCE" "$SINGLET_TSV"
        "$RSCRIPT_BIN" scripts/qc/09_plot_qc_metrics.R "$RAW_QC_TSV" "$EMPTYDROPS_TSV" "$LOWQ_TSV" "$SCDBL_TSV" "$ENGINE" "$sample_run_id" "$QC_PLOTS_DIR"

        log "Completed QC for ${sample_run_id}"
      done
      ;;
    starsolo)
      tail -n +2 "$MANIFEST_FILE" | while IFS=$'\t' read -r sample_run_id fastq_dir sample_id chemistry; do
        [[ -z "${sample_run_id:-}" ]] && continue

        if [[ "$RUN_PREPROCESS" == "1" ]]; then
          PREPROCESS_SAMPLE_DIR="${OUTPUTS_DIR}/starsolo/${sample_run_id}"
        else
          if [[ -z "$PREPROCESS_SOURCE_RUN_DIR" ]]; then
            echo "ERROR: RUN_QC=1 with RUN_PREPROCESS=0 requires PREPROCESS_SOURCE_RUN_DIR to be set" >&2
            exit 6
          fi
          PREPROCESS_SAMPLE_DIR="${PREPROCESS_SOURCE_RUN_DIR}/outputs/starsolo/${sample_run_id}"
        fi

        case "${QC_MATRIX_TYPE}" in
          filtered|raw)
            MATRIX_DIR="${PREPROCESS_SAMPLE_DIR}/Solo.out/Gene/${QC_MATRIX_TYPE}"
            ;;
          *)
            echo "ERROR: unsupported QC_MATRIX_TYPE for starsolo: ${QC_MATRIX_TYPE}" >&2
            exit 6
            ;;
        esac

        require_dir "$MATRIX_DIR"

        SAMPLE_QC_DIR="${QC_DIR}/${sample_run_id}"
        QC_OBJECTS_DIR="${SAMPLE_QC_DIR}/objects"
        QC_TABLES_DIR="${SAMPLE_QC_DIR}/tables"
        QC_PLOTS_DIR="${SAMPLE_QC_DIR}/plots"

        mkdir -p "$QC_OBJECTS_DIR" "$QC_TABLES_DIR" "$QC_PLOTS_DIR"

        RAW_SCE="${QC_OBJECTS_DIR}/${sample_run_id}_${ENGINE}_raw_sce.rds"
        RAW_QC_SCE="${QC_OBJECTS_DIR}/${sample_run_id}_${ENGINE}_raw_qc_sce.rds"
        EMPTYDROPS_SCE="${QC_OBJECTS_DIR}/${sample_run_id}_${ENGINE}_emptydropsfiltered_sce.rds"
        LOWQ_SCE="${QC_OBJECTS_DIR}/${sample_run_id}_${ENGINE}_lowqfiltered_sce.rds"
        SCDBL_SCE="${QC_OBJECTS_DIR}/${sample_run_id}_${ENGINE}_scdblfinder_sce.rds"
        SINGLET_SCE="${QC_OBJECTS_DIR}/${sample_run_id}_${ENGINE}_singlets_sce.rds"

        RAW_QC_TSV="${QC_TABLES_DIR}/${sample_run_id}_${ENGINE}_raw_qc_metrics.tsv"
        EMPTYDROPS_TSV="${QC_TABLES_DIR}/${sample_run_id}_${ENGINE}_emptydrops.tsv"
        LOWQ_TSV="${QC_TABLES_DIR}/${sample_run_id}_${ENGINE}_lowq_filter.tsv"
        SCDBL_TSV="${QC_TABLES_DIR}/${sample_run_id}_${ENGINE}_scdblfinder.tsv"
        SINGLET_TSV="${QC_TABLES_DIR}/${sample_run_id}_${ENGINE}_singlet_filter.tsv"

        BARCODE_RANK_PNG="${QC_PLOTS_DIR}/${sample_run_id}_${ENGINE}_barcode_rank.png"

        log "Running QC for ${sample_run_id} using matrix dir ${MATRIX_DIR}"

        "$RSCRIPT_BIN" scripts/qc/01_build_sce_object.R "$MATRIX_DIR" "$sample_run_id" "$ENGINE" "$RAW_SCE"
        "$RSCRIPT_BIN" scripts/qc/02_compute_qc_metrics.R "$RAW_SCE" "$SPECIES" "$RAW_QC_SCE" "$RAW_QC_TSV"
        "$RSCRIPT_BIN" scripts/qc/03_barcode_rank_plot.R "$RAW_QC_TSV" "$BARCODE_RANK_PNG"
        "$RSCRIPT_BIN" scripts/qc/04_run_emptydrops.R "$RAW_QC_SCE" "$QC_EMPTYDROPS_LOWER" "$EMPTYDROPS_TSV" "$QC_EMPTYDROPS_FDR"
        "$RSCRIPT_BIN" scripts/qc/05_apply_emptydrops_filter.R "$RAW_QC_SCE" "$EMPTYDROPS_TSV" "$EMPTYDROPS_SCE"
        "$RSCRIPT_BIN" scripts/qc/06_filter_low_quality_cells.R "$EMPTYDROPS_SCE" "$QC_MIN_COUNTS" "$QC_MIN_GENES" "$QC_MAX_PCT_MITO" "$LOWQ_SCE" "$LOWQ_TSV"
        "$SCDBLFINDER_RSCRIPT_BIN" scripts/qc/07_run_scdblfinder.R "$LOWQ_SCE" "$SCDBL_SCE" "$SCDBL_TSV"
        "$SCDBLFINDER_RSCRIPT_BIN" scripts/qc/08_remove_doublets.R "$SCDBL_SCE" "$SINGLET_SCE" "$SINGLET_TSV"
        "$RSCRIPT_BIN" scripts/qc/09_plot_qc_metrics.R "$RAW_QC_TSV" "$EMPTYDROPS_TSV" "$LOWQ_TSV" "$SCDBL_TSV" "$ENGINE" "$sample_run_id" "$QC_PLOTS_DIR"

        log "Completed QC for ${sample_run_id}"
      done
      ;;
  esac
else
  log "QC stage disabled"
fi
}

run_downstream_core_stage() {
if [[ "$RUN_DOWNSTREAM_CORE" == "1" ]]; then
  log "DOWNSTREAM_CORE stage enabled"

  case "${ENGINE,,}" in
    cellranger|starsolo)
      tail -n +2 "$MANIFEST_FILE" | while IFS=$'\t' read -r c1 c2 c3 c4 c5 c6 c7 c8; do
        sample_run_id="$c1"
        [[ -z "${sample_run_id:-}" ]] && continue

        SAMPLE_QC_DIR="${QC_DIR}/${sample_run_id}"
        QC_OBJECTS_DIR="${SAMPLE_QC_DIR}/objects"
        if [[ -n "$COMPARE_CELLRANGER_SOURCE_RUN_DIR" && -n "$COMPARE_STARSOLO_SOURCE_RUN_DIR" ]]; then
          CR_SCE="${COMPARE_CELLRANGER_SOURCE_RUN_DIR}/downstream/${sample_run_id}/objects/${sample_run_id}_cellranger_clusters_sce.rds"
          SS_SCE="${COMPARE_STARSOLO_SOURCE_RUN_DIR}/downstream/${sample_run_id}/objects/${sample_run_id}_starsolo_clusters_sce.rds"
          SAMPLE_DOWNSTREAM_DIR="${DOWNSTREAM_DIR}/${sample_run_id}"
        else
           SAMPLE_DOWNSTREAM_DIR="${DOWNSTREAM_DIR}/${sample_run_id}"

           CR_SCE="${SAMPLE_DOWNSTREAM_DIR}/objects/${sample_run_id}_cellranger_clusters_sce.rds"
           SS_SCE="${SAMPLE_DOWNSTREAM_DIR}/objects/${sample_run_id}_starsolo_clusters_sce.rds"
        fi
        DOWNSTREAM_OBJECTS_DIR="${SAMPLE_DOWNSTREAM_DIR}/objects"
        DOWNSTREAM_TABLES_DIR="${SAMPLE_DOWNSTREAM_DIR}/tables"

        mkdir -p "$DOWNSTREAM_OBJECTS_DIR" "$DOWNSTREAM_TABLES_DIR"

        INPUT_SINGLET_SCE="${QC_OBJECTS_DIR}/${sample_run_id}_${ENGINE}_singlets_sce.rds"
        require_file "$INPUT_SINGLET_SCE"

        NORM_HVG_SCE="${DOWNSTREAM_OBJECTS_DIR}/${sample_run_id}_${ENGINE}_norm_hvg_sce.rds"
        HVG_TSV="${DOWNSTREAM_TABLES_DIR}/${sample_run_id}_${ENGINE}_hvg.tsv"

        PCA_SCE="${DOWNSTREAM_OBJECTS_DIR}/${sample_run_id}_${ENGINE}_norm_hvg_pca_sce.rds"
        PCA_COV_TSV="${DOWNSTREAM_TABLES_DIR}/${sample_run_id}_${ENGINE}_PCA_covariates.tsv"

        PCA_REG_SCE="${DOWNSTREAM_OBJECTS_DIR}/${sample_run_id}_${ENGINE}_norm_hvg_regressed_pca_sce.rds"
        PCA_REG_COV_TSV="${DOWNSTREAM_TABLES_DIR}/${sample_run_id}_${ENGINE}_PCA_regressed_covariates.tsv"

        MERGED_SCE="${DOWNSTREAM_OBJECTS_DIR}/${sample_run_id}_${ENGINE}_downstream_ready_sce.rds"

        GRAPH_SCE="${DOWNSTREAM_OBJECTS_DIR}/${sample_run_id}_${ENGINE}_graphs_sce.rds"
        CLUSTER_SCE="${DOWNSTREAM_OBJECTS_DIR}/${sample_run_id}_${ENGINE}_clusters_sce.rds"
        UMAP_SCE="${DOWNSTREAM_OBJECTS_DIR}/${sample_run_id}_${ENGINE}_umap_sce.rds"
        TSNE_SCE="${DOWNSTREAM_OBJECTS_DIR}/${sample_run_id}_${ENGINE}_umap_tsne_sce.rds"

        log "Running downstream core for ${sample_run_id} from ${INPUT_SINGLET_SCE}"

        "$RSCRIPT_BIN" scripts/downstream/10_normalize_hvg.R \
          "$INPUT_SINGLET_SCE" \
          "$NORM_HVG_SCE" \
          "$HVG_TSV" \
          "$N_TOP_HVGS"

        "$RSCRIPT_BIN" scripts/downstream/20_run_pca.R \
          "$NORM_HVG_SCE" \
          "$PCA_SCE" \
          "$N_PCS"

        "$RSCRIPT_BIN" scripts/downstream/21_assess_pc_covariates.R \
          "$PCA_SCE" \
          "$PCA_COV_TSV" \
          "$PC_COVARIATE_N"

        "$RSCRIPT_BIN" scripts/downstream/22_regress_covariates_and_rerun_pca.R \
          "$NORM_HVG_SCE" \
          "$PCA_REG_SCE" \
          "$N_PCS"

        "$RSCRIPT_BIN" scripts/downstream/24_assess_any_reduceddim_covariates.R \
          "$PCA_REG_SCE" \
          "PCA_regressed" \
          "$PCA_REG_COV_TSV" \
          "$PC_COVARIATE_N"

        "$RSCRIPT_BIN" scripts/downstream/23_merge_pca_variants.R \
          "$PCA_SCE" \
          "$PCA_REG_SCE" \
          "$MERGED_SCE"

        "$RSCRIPT_BIN" scripts/downstream/30_build_knn_graphs.R \
          "$MERGED_SCE" \
          "$GRAPH_SCE" \
          "$GRAPH_K" \
          "$N_PCS"

        "$RSCRIPT_BIN" scripts/downstream/31_cluster_knn_graphs.R \
          "$GRAPH_SCE" \
          "$CLUSTER_SCE" \
          "$CLUSTER_ALGORITHM"

        "$RSCRIPT_BIN" scripts/downstream/32_run_umap.R \
          "$CLUSTER_SCE" \
          "$UMAP_SCE" \
          "$N_PCS"

        "$RSCRIPT_BIN" scripts/downstream/33_run_tsne.R \
          "$UMAP_SCE" \
          "$TSNE_SCE" \
          "$N_PCS"

        log "Completed downstream core for ${sample_run_id}"
      done
      ;;
  esac
else
  log "DOWNSTREAM_CORE stage disabled"
fi
}

if [[ "$RUN_MARKERS" == "1" ]]; then
  log "MARKERS stage enabled"
fi

if [[ "$RUN_ANNOTATION" == "1" ]]; then
  log "ANNOTATION stage enabled"
fi

if [[ "$RUN_DIFFERENTIAL" == "1" ]]; then
  log "DIFFERENTIAL stage enabled"
fi

if [[ "$RUN_PATHWAY" == "1" ]]; then
  log "PATHWAY stage enabled"
fi

if [[ "$RUN_VISUALIZATION" == "1" ]]; then
  log "VISUALIZATION stage enabled"
fi

if [[ "$RUN_REPORT" == "1" ]]; then
  log "REPORT stage enabled"
fi

run_compare_backends_stage() {
if [[ "$RUN_COMPARE_BACKENDS" == "1" ]]; then
  log "COMPARE_BACKENDS stage enabled"

  tail -n +2 "$MANIFEST_FILE" | while IFS=$'\t' read -r c1 c2 c3 c4 c5 c6 c7 c8; do
    sample_run_id="$c1"
    [[ -z "${sample_run_id:-}" ]] && continue

    if [[ -n "$COMPARE_CELLRANGER_SOURCE_RUN_DIR" && -n "$COMPARE_STARSOLO_SOURCE_RUN_DIR" ]]; then
      CR_SCE="${COMPARE_CELLRANGER_SOURCE_RUN_DIR}/downstream/${sample_run_id}/objects/${sample_run_id}_cellranger_clusters_sce.rds"
      SS_SCE="${COMPARE_STARSOLO_SOURCE_RUN_DIR}/downstream/${sample_run_id}/objects/${sample_run_id}_starsolo_clusters_sce.rds"
      SAMPLE_DOWNSTREAM_DIR="${DOWNSTREAM_DIR}/${sample_run_id}"
    else
      SAMPLE_DOWNSTREAM_DIR="${DOWNSTREAM_DIR}/${sample_run_id}"
      DOWNSTREAM_OBJECTS_DIR="${SAMPLE_DOWNSTREAM_DIR}/objects"

      CR_SCE="${DOWNSTREAM_OBJECTS_DIR}/${sample_run_id}_cellranger_clusters_sce.rds"
      SS_SCE="${DOWNSTREAM_OBJECTS_DIR}/${sample_run_id}_starsolo_clusters_sce.rds"
    fi

    COMPARE_DIR="${SAMPLE_DOWNSTREAM_DIR}/compare_backends"
    OUTPUT_TSV="${COMPARE_DIR}/${sample_run_id}_backend_comparison.tsv"

    if [[ -f "$CR_SCE" && -f "$SS_SCE" ]]; then
      mkdir -p "$COMPARE_DIR"

      log "Running backend comparison for ${sample_run_id}"

      "$RSCRIPT_BIN" scripts/downstream/34_cluster_stability.R \
        "$CR_SCE" \
        "$SS_SCE" \
        "$OUTPUT_TSV"

      log "Completed backend comparison for ${sample_run_id}"
    else
      log "Skipping backend comparison for ${sample_run_id} (missing one or both SCEs)"
      log "  Cell Ranger SCE: $CR_SCE"
      log "  STARsolo SCE:    $SS_SCE"
    fi

  done
fi
}
########################################
# standardized stage execution
########################################

if [[ "$RUN_PREPROCESS" == "1" ]]; then
  run_stage "preprocess" run_preprocess_stage
else
  log "PREPROCESS stage disabled"
fi

if [[ "$RUN_QC" == "1" ]]; then
  run_stage "qc" run_qc_stage
else
  log "QC stage disabled"
fi

if [[ "$RUN_DOWNSTREAM_CORE" == "1" ]]; then
  run_stage "downstream_core" run_downstream_core_stage
else
  log "DOWNSTREAM_CORE stage disabled"
fi

if [[ "$RUN_COMPARE_BACKENDS" == "1" ]]; then
  run_stage "compare_backends" run_compare_backends_stage
else
  log "COMPARE_BACKENDS stage disabled"
fi

########################################
# completion
########################################

log "=== scRNA-seq wrapper complete ==="

{
  echo "start_time=${START_TIME}"
  echo "end_time=$(date '+%F %T')"
  echo "status=completed"
} > "$START_END_STATUS_FILE"

echo
echo "Summary:"
echo "  RUN_ID:   $RUN_ID"
echo "  ENGINE:   $ENGINE"
echo "  RUN_DIR:  $RUN_DIR"
echo "  WRAPLOG:  $WRAP_LOG"
