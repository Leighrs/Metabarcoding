#!/bin/bash

# Ask user for project name
read -p "Enter project name: " PROJECT

# Create main directory
mkdir -p "Metabarcoding/$PROJECT"

# Create subdirectories
mkdir -p "Metabarcoding/$PROJECT/input/fastq"
mkdir -p "Metabarcoding/$PROJECT/output/intermediates_logs_cache/singularity"

echo "Directory structure created:"
echo "Metabarcoding/"
echo "+-- $PROJECT/"
echo "¦   +-- input/"
echo "        +-- fastq/"
echo "¦   +-- output/"
echo "        +-- intermediates_logs_cache/"
echo "            +-- singularity/"
