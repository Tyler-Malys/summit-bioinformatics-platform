Cell Ranger Preprocessing Workflow

Inputs:
- 10x Genomics FASTQ files (R1 barcode/UMI, R2 cDNA)
- GRCh38 + Gencode v49 reference genome

Steps:
1. Build reference using cellranger mkref
2. Validate FASTQ read structure and lane layout
3. Execute cellranger count

Example command:

cellranger count \
  --id=<run_id> \
  --create-bam=true \
  --transcriptome=<reference_path> \
  --fastqs=<fastq_directory> \
  --sample=<sample_name> \
  --localcores=8 \
  --localmem=40

Outputs:
- gene × cell expression matrices
- BAM alignment file
- QC metrics summary
- Loupe visualization file

Outputs are located in:
runs/cellranger_count/<run_id>/outs/
