#!/bin/bash

# Ask user for project name
read -p "Enter project name: " PROJECT

# Create main directory
mkdir -p "Metabarcoding/$PROJECT"

# Create subdirectories
mkdir -p "Metabarcoding/$PROJECT/input/fastq"
mkdir -p "Metabarcoding/$PROJECT/output/intermediates_logs_cache/singularity"

# Create Example_samplesheet.txt in the input folder
cat <<EOT > "Metabarcoding/$PROJECT/input/Example_samplesheet.txt"
sampleID	forwardReads	reverseReads	run
B12A1_02	/home/leighrs/DSP_12S_251102/input/fastq/B12A1_02_4_S14_L001_R1_001.fastq.gz	/home/leighrs/DSP_12S_251102/input/fastq/B12A1_02_4_S14_L001_R2_001.fastq.gz	A
B12A2_02	/home/leighrs/DSP_12S_251102/input/fastq/B12A2_02_4_S15_L001_R1_001.fastq.gz	/home/leighrs/DSP_12S_251102/input/fastq/B12A2_02_4_S15_L001_R2_001.fastq.gz	A
B12A3_02	/home/leighrs/DSP_12S_251102/input/fastq/B12A3_02_4_S16_L001_R1_001.fastq.gz	/home/leighrs/DSP_12S_251102/input/fastq/B12A3_02_4_S16_L001_R2_001.fastq.gz	A
EOT

# Create Example_metadata.txt in the input folder
cat <<EOT > "Metabarcoding/$PROJECT/input/Example_metadata.txt"
ID	Replicate	Control_Assign	Sample_or_Control	Site	Month	Year
B12A1_02	A1	1,2,4	Sample	Browns_Island	February	2023
B12A2_02	A2	1,2,4	Sample	Browns_Island	February	2023
B12A3_02	A3	1,2,4	Sample	Browns_Island	February	2023
EOT

# Make the .txt files executable
chmod +x "Metabarcoding/$PROJECT/input/Example_samplesheet.txt"
chmod +x "Metabarcoding/$PROJECT/input/Example_metadata.txt"
chmod +x "Metabarcoding/$PROJECT/input/Example_RSD.txt"

echo "Directory structure and files created and set as executable:"
echo "Metabarcoding/"
echo "+-- $PROJECT/"
echo "¦   +-- input/"
echo "¦       +-- fastq/"
echo "¦       +-- Example_samplesheet.txt"
echo "¦       +-- Example_metadata.txt"
echo "¦       +-- Example_RSD.txt"
echo "¦   +-- output/"
echo "¦       +-- intermediates_logs_cache/"
echo "¦           +-- singularity/"

echo "$PROJECT" > "$HOME/Metabarcoding/current_project_name.txt"
