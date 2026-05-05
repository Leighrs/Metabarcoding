#!/bin/bash

# 1. Define the path to the current project name file
PROJECT_NAME_FILE="/group/ajfingergrp/Metabarcoding/Project_Runs/Project_IDs/$USER/current_project_name.txt"

# 2. Check if the project name file exists
if [[ ! -f "$PROJECT_NAME_FILE" ]]; then
    echo "Error: Project name file not found for $USER"
    exit 1
fi

# 3. Read the project name
PROJECT_NAME=$(cat "$PROJECT_NAME_FILE")
FASTQ_DIR="/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT_NAME/input/fastq/"

echo "--------------------------------------------------------"
echo "Checking Project: $PROJECT_NAME"
echo "Directory: $FASTQ_DIR"
echo "--------------------------------------------------------"

# 4. Define the Nextera Adapter to look for
ADAPTER="AGATGTGTATAAGAGACAG"

# 5. Loop through fastq.gz files
# We check the first 20,000 lines (5,000 reads) per file
for f in "$FASTQ_DIR"/*.fastq.gz; do
    [ -e "$f" ] || continue # Handle empty directories
    
    FILE_NAME=$(basename "$f")
    
    # Count occurrences of the adapter in the first 5000 reads
    COUNT=$(zcat "$f" | head -n 20000 | grep -c "$ADAPTER")
    
    if [ "$COUNT" -gt 0 ]; then
        echo -e "\e[31m[DIRTY]\e[0m $FILE_NAME: Found $COUNT adapter matches in sample."
    else
        echo -e "\e[32m[CLEAN]\e[0m $FILE_NAME: No adapters found."
    fi
done

echo "--------------------------------------------------------"
echo "Done."