#!/usr/bin/env bash

MANIFEST="metadata/cellranger_runs.tsv"
CELLRANGER=~/bioinformatics_tools/cellranger-10.0.0/cellranger

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUNS_DIR="$PROJECT_ROOT/runs/cellranger_count"
mkdir -p "$RUNS_DIR"

while IFS=$'\t' read -r run_id sample_id dataset fastq_path reference chemistry expected_cells notes
do
    if [[ "$run_id" == "run_id" ]]; then
        continue
    fi

    OUTDIR="$RUNS_DIR/$run_id"
    if [[ -d "$OUTDIR" ]]; then
        echo "SKIP: $run_id already exists at $OUTDIR"
        continue
    fi

    cd "$RUNS_DIR"
    echo "Running Cell Ranger for $run_id"

    $CELLRANGER count \
        --id="$run_id" \
        --create-bam=true \
        --transcriptome="$PROJECT_ROOT/data/refs/grch38_gencode_v49/$reference" \
        --fastqs="$fastq_path" \
        --sample="$sample_id" \
        --localcores=8 \
        --localmem=40

done < "$PROJECT_ROOT/$MANIFEST"
