#!/usr/bin/env bash

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
#  PROMPT: STANDARD / CUSTOM / NEITHER
# ---------------------------
while true; do
    echo
    echo "Reference database choice:"
    echo "  1) Standardized/curated database"
    echo "  2) Custom sequence database"
    echo "  3) Neither (BLAST all ASVs)"
    read -rp "Enter 1, 2, or 3: " RSD_CHOICE

    case "$RSD_CHOICE" in
        1) DB_MODE="standard"; break ;;
        2) DB_MODE="custom";   break ;;
        3) DB_MODE="none";     break ;;
        *) echo -e "${RED}Invalid input. Please enter 1, 2, or 3.${RESET}" ;;
    esac
done

# ---------------------------
#  CREATE DIRECTORIES
# ---------------------------
mkdir -p "Metabarcoding/$PROJECT"
mkdir -p "Metabarcoding/Logs_archive"
mkdir -p "Metabarcoding/$PROJECT/scripts"
mkdir -p "Metabarcoding/$PROJECT/input/fastq"

# Only create local intermediates/cache if NOT using Azure Blob
if [[ "$USE_AZURE" == "no" ]]; then
    mkdir -p "Metabarcoding/$PROJECT/output/intermediates_logs_cache/singularity"
fi

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
#  COPY CORRECT nf-params.json (ALWAYS named nf-params.json)
# ---------------------------
SRC_STANDARD="$HOME/Metabarcoding/scripts_do_not_alter/nf-params_with_standard_RSD.json"
SRC_CUSTOM="$HOME/Metabarcoding/scripts_do_not_alter/nf-params_with_custom_RSD.json"
SRC_NONE="$HOME/Metabarcoding/scripts_do_not_alter/nf-params_no_RSD.json"
DEST_JSON="$HOME/Metabarcoding/$PROJECT/scripts/${PROJECT}_nf-params.json"

case "$DB_MODE" in
  standard)
    SRC="$SRC_STANDARD"
    MSG="Standardized/curated DB → nf-params_with_standard_RSD.json copied as ${PROJECT}_nf-params.json"
    ;;
  custom)
    SRC="$SRC_CUSTOM"
    MSG="Custom sequence DB → nf-params_with_custom_RSD.json copied as ${PROJECT}_nf-params.json"
    ;;
  none)
    SRC="$SRC_NONE"
    MSG="No DB (BLAST all ASVs) → nf-params_no_RSD.json copied as ${PROJECT}_nf-params.json"
    ;;
esac

if [[ -f "$SRC" ]]; then
    cp "$SRC" "$DEST_JSON"
    echo -e "${GREEN}${MSG}.${RESET}"
else
    echo -e "${RED}WARNING: Missing template: $SRC${RESET}"
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
    ["retrieve_phyloseq_unassigned_ASVs.slurm"]="${PROJECT}_retrieve_phyloseq_unassigned_ASVs.slurm"
    ["review_and_update_phyloseq.R"]="${PROJECT}_review_and_update_phyloseq.R"
)

for SRCFILE in "${!FILES[@]}"; do
    SRC="$HOME/Metabarcoding/scripts_do_not_alter/$SRCFILE"
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
SRC_CON="$HOME/Metabarcoding/scripts_do_not_alter/R_ASV_cleanup_scripts/"
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

if command -v tree >/dev/null 2>&1; then
  tree -C "Metabarcoding/$PROJECT"
else
  echo -e "${YELLOW}NOTE: 'tree' not found; showing directories via find.${RESET}"
  find "Metabarcoding/$PROJECT" -maxdepth 4 -type d | sed "s|^Metabarcoding/||"
fi

# ---------------------------
#  SUMMARY
# ---------------------------
echo -e "${BLUE}Summary of copied files:${RESET}"
echo -e "${GREEN}Setup finished successfully.${RESET}"
