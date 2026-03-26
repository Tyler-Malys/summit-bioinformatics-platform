#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage:
  register_reference.sh <ref_root> <organism> <genome_build> <annotation_version> <star_index> <salmon_index> <tx2gene_file>

Example:
  register_reference.sh /home/summitadmin/refs human grch38 gencode_v45 \
    /home/summitadmin/bioinformatics_projects/pipelines/bulk_rnaseq/star_pilot/index \
    /home/summitadmin/refs/gencode_grch38/salmon_index \
    /home/summitadmin/refs/gencode_grch38/tx2gene.tsv
EOF
}

[[ $# -eq 7 ]] || { usage; exit 2; }

REF_ROOT="$1"
ORGANISM="$2"
GENOME_BUILD="$3"
ANNOTATION_VERSION="$4"
STAR_INDEX_SRC="$5"
SALMON_INDEX_SRC="$6"
TX2GENE_SRC="$7"

TARGET_BASE="${REF_ROOT}/${ORGANISM}/${GENOME_BUILD}/${ANNOTATION_VERSION}"
TARGET_TX2GENE_DIR="${TARGET_BASE}/tx2gene"

[[ -d "$STAR_INDEX_SRC" ]] || { echo "ERROR: STAR index source not found: $STAR_INDEX_SRC" >&2; exit 3; }
[[ -d "$SALMON_INDEX_SRC" ]] || { echo "ERROR: Salmon index source not found: $SALMON_INDEX_SRC" >&2; exit 3; }
[[ -f "$TX2GENE_SRC" ]] || { echo "ERROR: tx2gene source file not found: $TX2GENE_SRC" >&2; exit 3; }

mkdir -p "$TARGET_TX2GENE_DIR"

ln -sfn "$STAR_INDEX_SRC"   "${TARGET_BASE}/star_index"
ln -sfn "$SALMON_INDEX_SRC" "${TARGET_BASE}/salmon_index"
ln -sfn "$TX2GENE_SRC"      "${TARGET_TX2GENE_DIR}/tx2gene.tsv"

echo "Registered reference:"
echo "  TARGET_BASE=${TARGET_BASE}"
echo "  star_index -> ${STAR_INDEX_SRC}"
echo "  salmon_index -> ${SALMON_INDEX_SRC}"
echo "  tx2gene.tsv -> ${TX2GENE_SRC}"
