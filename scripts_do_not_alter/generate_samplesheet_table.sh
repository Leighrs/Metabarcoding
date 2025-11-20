#!/bin/bash

# Read project name
PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")

# Define input directory
FASTQ_DIR="$HOME/Metabarcoding/$PROJECT_NAME/input/fastq"

# Output file
OUTPUT_FILE="$HOME/Metabarcoding/$PROJECT_NAME/input/${PROJECT_NAME}_samplesheet.txt"

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
for fwd in "$FASTQ_DIR"/*_R1_001.fastq.gz; do
    [ -e "$fwd" ] || continue

    fname=$(basename "$fwd")
    sampleID=$(extract_sample_id "$fname")

    sample_prefix="${fname%_R1_001.fastq.gz}"
    rev="$FASTQ_DIR/${sample_prefix}_R2_001.fastq.gz"

    if [[ ! -f "$rev" ]]; then
        rev=""
    fi

    # If RUN_VALUE is empty, user will fill manually
    echo -e "${sampleID}\t$fwd\t$rev\t${RUN_VALUE}" >> "$OUTPUT_FILE"
done

echo "Sample sheet written to: $OUTPUT_FILE"
