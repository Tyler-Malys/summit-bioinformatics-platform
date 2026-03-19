## CLI Contract v1 — Bulk RNA-seq Pipeline

### Purpose
Standardize command-line interfaces across pipeline stage scripts to ensure consistency, reproducibility, and easy wrapper orchestration.

---

### Standard Required Flags (All Bash Stage Scripts)

-i INPUT_DIR      Path to input FASTQ or stage input directory  
-o OUTPUT_DIR     Base output directory  
-t THREADS        Number of threads to use (default: 8)  
--run-id RUN_ID   Unique run identifier (default: timestamp)

---

### Defaults

THREADS = 8  
RUN_ID = timestamp if not provided

---

### Optional Flags (All Scripts)

--sample-sheet FILE   CSV mapping sample IDs to FASTQs  
--log-dir DIR         Custom log directory (default: within run folder)  
--dry-run             Print actions without executing

---

### Stage-Specific Required Flags

Salmon  
-r SALMON_INDEX  

STAR  
-r STAR_INDEX  

Trim (fastp)  
(no additional required flags)

---

### Standard Run Directory Structure

Each script writes to:

OUTPUT_DIR/RUN_ID/  
  logs/  
  run_info.txt

---

### Internal Standard Variable Names

Scripts should normalize flags to:

INPUT_DIR  
OUTPUT_DIR  
THREADS  
RUN_ID  
SAMPLE_SHEET  
LOG_DIR  
REF_INDEX  
DRY_RUN

---

### Notes

- This contract may evolve; update version if changed.  
- Simplicity preferred over feature creep.  
- Wrapper script will rely on this interface.
