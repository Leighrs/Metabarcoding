#!/bin/bash

# Read project name
PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")

# Default FASTQ directory (home/local)
DEFAULT_FASTQ_DIR="$HOME/Metabarcoding/$PROJECT_NAME/input/fastq"

# Pointer file (exists only if user chose group storage in setup)
FASTQ_PTR_FILE="$HOME/Metabarcoding/$PROJECT_NAME/input/fastq_storage_path.txt"

# Decide FASTQ_DIR
if [[ -f "$FASTQ_PTR_FILE" ]]; then
    FASTQ_DIR="$(cat "$FASTQ_PTR_FILE")"
else
    FASTQ_DIR="$DEFAULT_FASTQ_DIR"
fi


# Output file
OUTPUT_FILE="$HOME/Metabarcoding/$PROJECT_NAME/input/${PROJECT_NAME}_samplesheet.txt"

# Basic validation
if [[ -z "$FASTQ_DIR" ]]; then
    echo "ERROR: FASTQ_DIR is empty (this should never happen)."
    exit 1
fi

if [[ ! -d "$FASTQ_DIR" ]]; then
    echo "ERROR: FASTQ directory not found: $FASTQ_DIR"
    echo "Expected either:"
    echo "  - $DEFAULT_FASTQ_DIR"
    echo "  - or a valid path in $FASTQ_PTR_FILE"
    exit 1
fi

echo "Using FASTQ directory: $FASTQ_DIR"

#################################
#  ASK USER ABOUT MULTIPLE RUNS
#################################
echo "Did you sequence samples using multiple sequencing runs? [yes/no]"
read multi_runs

if [[ "$multi_runs" =~ ^([Nn][Oo])$ ]]; then
    RUN_VALUE="A"
    echo "All samples will be assigned to run 'A'."
elif [[ "$multi_runs" =~ ^([Yy][Ee][Ss]|[Yy])$ ]]; then
    RUN_VALUE=""
    echo "NOTE: You will need to manually edit the 'run' column in the samplesheet."
    echo "Use letters (e.g., A, B, etc.) to distinguish sequencing runs."
else
    echo "Invalid response. Please answer yes or no."
    exit 1
fi

#################################
#  HEADER
#################################
echo -e "sampleID\tforwardReads\treverseReads\trun" > "$OUTPUT_FILE"

##############################################
# USER-EDITABLE SAMPLE NAME PARSING FUNCTION #
##############################################
# This function receives the forward read filename WITHOUT the path.
#
# YOU MAY EDIT THE LOGIC TO MATCH YOUR NAMING SCHEME.
# For your example:
#   B12A1_02_4_S14_L001_R1_001.fastq.gz  ?  B12A1_02
#
# Default behavior:
#   Take the first 2 fields separated by underscores (_)
#
extract_sample_id() {
    local filename="$1"
    
    # Remove R1/R2 etc. suffix from filename
    local base="${filename%_R1_001.fastq.gz}"

    # --- DEFAULT RULE ---
    # Extract the first TWO underscore-separated fields
    # e.g. B12A1_02_4_S14 ? B12A1_02
    echo "$base" | awk -F'_' '{print $1"_"$2}'
}


#################################
#  PROCESS FASTQ FILES
#################################
shopt -s nullglob # Sometimes bash shell can print literal name, with wildcards, if no files match. With this, if no files match, the patter expands to nothing.
for fwd in "$FASTQ_DIR"/*_R1_001.fastq.gz; do
    fname=$(basename "$fwd")
    sampleID=$(extract_sample_id "$fname")

    sample_prefix="${fname%_R1_001.fastq.gz}"
    rev="$FASTQ_DIR/${sample_prefix}_R2_001.fastq.gz"

    if [[ ! -f "$rev" ]]; then
        rev=""
    fi

    echo -e "${sampleID}\t$fwd\t$rev\t${RUN_VALUE}" >> "$OUTPUT_FILE"
done
shopt -u nullglob # Restore bash

echo "Sample sheet written to: $OUTPUT_FILE"
