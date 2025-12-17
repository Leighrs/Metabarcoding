#!/bin/bash

# ---------------------------
#  COLOR DEFINITIONS
# ---------------------------
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
BLUE="\e[36m"
RESET="\e[0m"

# ---------------------------
#  ASK FOR PROJECT NAME
# ---------------------------
read -p "Enter project name: " PROJECT

# ---------------------------
#  YES/NO INPUT VALIDATION
# ---------------------------
while true; do
    read -p "Are you using a custom reference database? (yes/no): " USE_RSD
    USE_RSD=$(echo "$USE_RSD" | tr '[:upper:]' '[:lower:]')

    if [[ "$USE_RSD" == "yes" ]] || [[ "$USE_RSD" == "no" ]]; then
        break
    else
        echo -e "${RED}Invalid input. Please type 'yes' or 'no'.${RESET}"
    fi

done


# ---------------------------
#  CREATE DIRECTORIES
# ---------------------------
mkdir -p "Metabarcoding/$PROJECT"
mkdir -p "Metabarcoding/Logs_archive"
mkdir -p "Metabarcoding/$PROJECT/scripts"
mkdir -p "Metabarcoding/$PROJECT/input/fastq"
mkdir -p "Metabarcoding/$PROJECT/output/intermediates_logs_cache/singularity"

echo -e "${GREEN}Directory structure created.${RESET}"

# ---------------------------
#  CREATE EXAMPLE FILES
# ---------------------------
cat <<EOT > "Metabarcoding/$PROJECT/input/Example_samplesheet.txt"
sampleID	forwardReads	reverseReads	run
B12A1_02	/path/to/R1.fastq.gz	/path/to/R2.fastq.gz	A
B12A2_02	/path/to/R1.fastq.gz	/path/to/R2.fastq.gz	A
B12A3_02	/path/to/R1.fastq.gz	/path/to/R2.fastq.gz	A
EOT

cat <<EOT > "Metabarcoding/$PROJECT/input/Example_metadata.txt"
ID	Replicate	Control_Assign	Sample_or_Control	Site	Month	Year
B12A1_02	A1	1,2,4	Sample	Browns_Island	February	2023
B12A2_02	A2	1,2,4	Sample	Browns_Island	February	2023
B12A3_02	A3	1,2,4	Sample	Browns_Island	February	2023
EOT

if [[ "$USE_RSD" == "yes" ]]; then
cat <<EOT > "Metabarcoding/$PROJECT/input/Example_RSD.txt"
>Animalia;Chordata;Actinopterygii;Cypriniformes;Catostomidae;Catostomus;Catostomus occidentalis;
CACCGCGGTTATACGAGAGGCCCTAGTTGATA...
EOT

chmod +x "Metabarcoding/$PROJECT/input/Example_RSD.txt"
echo -e "${GREEN}Example RSD file created.${RESET}"
fi

chmod +x "Metabarcoding/$PROJECT/input/"*.txt

echo -e "${GREEN}Example input files created.${RESET}"

# ---------------------------
#  COPY CORRECT nf-params.json
# ---------------------------
SRC_WITH_RSD="$HOME/Metabarcoding/UCD_FARM_scripts_do_not_alter/nf-params_with_RSD.json"
SRC_NO_RSD="$HOME/Metabarcoding/UCD_FARM_scripts_do_not_alter/nf-params_no_RSD.json"
DEST_JSON="$HOME/Metabarcoding/$PROJECT/scripts/${PROJECT}_nf-params.json"

if [[ "$USE_RSD" == "yes" ]]; then
    if [[ -f "$SRC_WITH_RSD" ]]; then
        cp "$SRC_WITH_RSD" "$DEST_JSON"
        echo -e "${GREEN}Using custom RSD → nf-params_with_RSD.json copied.${RESET}"
    else
        echo -e "${RED}WARNING: nf-params_with_RSD.json missing!${RESET}"
    fi
else
    if [[ -f "$SRC_NO_RSD" ]]; then
        cp "$SRC_NO_RSD" "$DEST_JSON"
        echo -e "${GREEN}No RSD → nf-params_no_RSD.json copied.${RESET}"
    else
        echo -e "${RED}WARNING: nf-params_no_RSD.json missing!${RESET}"
    fi
fi

# ---------------------------
#  COPY OTHER PIPELINE SCRIPTS
# ---------------------------
declare -A FILES=(
    ["ncbi_taxonomy.slurm"]="${PROJECT}_ncbi_taxonomy.slurm"
    ["blast_asv.slurm"]="${PROJECT}_blast_asv.slurm"
    ["update_blast_db.slurm"]="${PROJECT}_update_blast_db.slurm"
    ["generate_samplesheet_table.sh"]="${PROJECT}_generate_samplesheet_table.sh"
    ["run_nf-core_ampliseq.slurm"]="${PROJECT}_run_nf-core_ampliseq.slurm"
    ["ncbi_pipeline.py"]="${PROJECT}_ncbi_pipeline.py"
)

for SRCFILE in "${!FILES[@]}"; do
    SRC="$HOME/Metabarcoding/UCD_FARM_scripts_do_not_alter/$SRCFILE"
    DEST="$HOME/Metabarcoding/$PROJECT/scripts/${FILES[$SRCFILE]}"

    if [[ -f "$SRC" ]]; then
        cp "$SRC" "$DEST"
        echo -e "${GREEN}Copied $SRCFILE${RESET}"
    else
        echo -e "${YELLOW}WARNING: $SRCFILE missing.${RESET}"
    fi
done

# ---------------------------
#  COPY R CLEANUP SCRIPTS
# ---------------------------
SRC_CON="$HOME/Metabarcoding/UCD_FARM_scripts_do_not_alter/R_ASV_cleanup_scripts/"
DEST_CON="Metabarcoding/$PROJECT/scripts/${PROJECT}_R_ASV_cleanup_scripts/"

if [[ -d "$SRC_CON" ]]; then
    mkdir -p "$DEST_CON"
    cp -r "$SRC_CON"* "$DEST_CON"/

    for f in "$DEST_CON"/*; do
        base=$(basename "$f")
        mv "$f" "$DEST_CON/${PROJECT}_$base"
    done

    echo -e "${GREEN}R cleanup scripts copied and renamed.${RESET}"
else
    echo -e "${YELLOW}WARNING: R_ASV_cleanup_scripts folder missing.${RESET}"
fi

# ---------------------------
#  SAVE CURRENT PROJECT NAME
# ---------------------------
echo "$PROJECT" > "$HOME/Metabarcoding/current_project_name.txt"

# ---------------------------
#  PRINT COLORIZED DIRECTORY TREE
# ---------------------------
echo -e "${BLUE}"
echo "======================================"
echo " METABARCODING PROJECT SETUP COMPLETE "
echo "======================================"
echo -e "${RESET}"

tree -C Metabarcoding/"$PROJECT"

# ---------------------------
#  SUMMARY
# ---------------------------
echo -e "${BLUE}Summary of copied files:${RESET}"
echo -e "${GREEN}Setup finished successfully.${RESET}"
