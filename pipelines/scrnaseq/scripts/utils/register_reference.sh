#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage:
  register_reference.sh <ref_root> <organism> <genome_build> <annotation_version> <star_index> <cellranger_ref>

Example:
  register_reference.sh /home/summitadmin/refs human grch38 gencode_v49 \
    /path/to/star_index \
    /path/to/cellranger_ref
EOF
}

[[ $# -eq 6 ]] || { usage; exit 2; }

REF_ROOT="$1"
ORGANISM="$2"
GENOME_BUILD="$3"
ANNOTATION_VERSION="$4"
STAR_INDEX_SRC="$5"
CELLRANGER_REF_SRC="$6"

TARGET_BASE="${REF_ROOT}/${ORGANISM}/${GENOME_BUILD}/${ANNOTATION_VERSION}"

[[ -d "$STAR_INDEX_SRC" ]] || { echo "ERROR: STAR index source not found: $STAR_INDEX_SRC" >&2; exit 3; }
[[ -d "$CELLRANGER_REF_SRC" ]] || { echo "ERROR: Cell Ranger ref not found: $CELLRANGER_REF_SRC" >&2; exit 3; }

mkdir -p "$TARGET_BASE"

ln -sfn "$STAR_INDEX_SRC"      "${TARGET_BASE}/star_index"
ln -sfn "$CELLRANGER_REF_SRC"  "${TARGET_BASE}/cellranger_ref"

echo "Registered scRNA reference:"
echo "  TARGET_BASE=${TARGET_BASE}"
echo "  star_index -> ${STAR_INDEX_SRC}"
echo "  cellranger_ref -> ${CELLRANGER_REF_SRC}"
