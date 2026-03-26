#!/usr/bin/env bash
set -euo pipefail

# scRNA-seq wrapper v3
# Task 3: config-driven execution

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEFAULT_CONFIG="${PIPELINE_ROOT}/config/pipeline_v3.env"

CONFIG="${1:-$DEFAULT_CONFIG}"
ENGINE="${2:-cellranger}"
MANIFEST="${3:-}"

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

########################################
# Defaults + normalization
########################################

default_var PIPELINE_ROOT "$PIPELINE_ROOT"
default_var RUNS_ROOT "${PIPELINE_ROOT}/runs"

default_var THREADS "${RESOURCE_THREADS:-${THREADS:-8}}"

default_var STAR_INDEX "${REF_STAR_INDEX:-${STAR_INDEX:-}}"
default_var CELLRANGER_REF "${REF_CELLRANGER_REF:-${CELLRANGER_REF:-}}"

########################################
# Required variables
########################################

require_var THREADS

########################################
# Manifest resolution
########################################

if [[ -z "$MANIFEST" ]]; then
  case "${ENGINE,,}" in
    cellranger) MANIFEST="${PIPELINE_ROOT}/metadata/cellranger_runs.tsv" ;;
    starsolo)   MANIFEST="${PIPELINE_ROOT}/metadata/starsolo_runs.tsv" ;;
    *) echo "ERROR: unsupported ENGINE: $ENGINE" >&2; exit 2 ;;
  esac
fi

[[ -f "$MANIFEST" ]] || { echo "ERROR: manifest not found: $MANIFEST" >&2; exit 3; }

########################################
# Run setup
########################################

RUN_ID="scrna_${ENGINE}_$(date +%Y%m%d_%H%M%S)"
RUN_DIR="${RUNS_ROOT}/${RUN_ID}"

LOGS_DIR="${RUN_DIR}/logs"
OUTPUTS_DIR="${RUN_DIR}/outputs"
RUN_METADATA_DIR="${RUN_DIR}/run_metadata"

mkdir -p "$LOGS_DIR" "$OUTPUTS_DIR" "$RUN_METADATA_DIR"

WRAP_LOG="${LOGS_DIR}/wrapper.log"

log() { echo "[$(date '+%F %T')] $*" | tee -a "$WRAP_LOG"; }

########################################
# Summary
########################################

echo "=== scRNA-seq WRAPPER v3 ===" | tee -a "$WRAP_LOG"
echo "CONFIG=$CONFIG" | tee -a "$WRAP_LOG"
echo "ENGINE=$ENGINE" | tee -a "$WRAP_LOG"
echo "MANIFEST=$MANIFEST" | tee -a "$WRAP_LOG"
echo "RUN_ID=$RUN_ID" | tee -a "$WRAP_LOG"
echo "THREADS=$THREADS" | tee -a "$WRAP_LOG"
echo "PIPELINE_ROOT=$PIPELINE_ROOT" | tee -a "$WRAP_LOG"
echo | tee -a "$WRAP_LOG"

########################################
# Engine dispatch
########################################

if [[ "${ENGINE,,}" == "cellranger" ]]; then
  require_var CELLRANGER_REF
  command -v cellranger >/dev/null || { echo "ERROR: cellranger not found" >&2; exit 4; }

  log "Running Cell Ranger"

elif [[ "${ENGINE,,}" == "starsolo" ]]; then
  require_var STAR_INDEX
  command -v STAR >/dev/null || { echo "ERROR: STAR not found" >&2; exit 4; }

  log "Running STARsolo"

else
  echo "ERROR: unsupported ENGINE: $ENGINE" >&2
  exit 2
fi

########################################
# TODO (Task 4)
########################################
# - implement per-sample loop
# - integrate manifest parsing
# - stage outputs
