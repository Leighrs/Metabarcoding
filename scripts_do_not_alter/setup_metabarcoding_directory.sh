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
#  CACHE DIRECTORY BASE (GROUP)
# ---------------------------
CACHE_BASE="/group/ajfingergrp/Metabarcoding/intermediates_logs_cache"

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
#  HANDLE PROJECT CACHE DIR:
#   - create ${PROJECT}_cache under CACHE_BASE
#   - if exists: prompt remove OR pick new PROJECT
# ---------------------------
while true; do
    PROJECT_CACHE_DIR="${CACHE_BASE}/${PROJECT}_cache"

    if [[ -d "$PROJECT_CACHE_DIR" ]]; then
        echo
        echo -e "${YELLOW}Cache directory already exists:${RESET} $PROJECT_CACHE_DIR"
        echo "Choose an option:"
        echo "  [R] Remove existing cache folder"
        echo "  [N] Enter a new project name (new project ID)"
        echo "  [A] Abort"

        read -rp "Selection (R/N/A): " choice
        case "$choice" in
            R|r)
                echo -e "${YELLOW}Removing:${RESET} $PROJECT_CACHE_DIR"
                rm -rf "$PROJECT_CACHE_DIR"
                if [[ -d "$PROJECT_CACHE_DIR" ]]; then
                    echo -e "${RED}ERROR: Failed to remove $PROJECT_CACHE_DIR${RESET}"
                    exit 1
                fi
                echo -e "${GREEN}Removed existing cache directory.${RESET}"
                break
                ;;
            N|n)
                read -rp "Enter new project name: " PROJECT
                ;;
            A|a)
                echo -e "${RED}Aborting.${RESET}"
                exit 1
                ;;
            *)
                echo -e "${RED}Invalid selection. Please choose R, N, or A.${RESET}"
                ;;
        esac
    else
        break
    fi
done


# ---------------------------
#  CREATE DIRECTORIES
# ---------------------------
mkdir -p "Metabarcoding/$PROJECT"
mkdir -p "Metabarcoding/Logs_archive"
mkdir -p "Metabarcoding/$PROJECT/params"
mkdir -p "Metabarcoding/$PROJECT/input"
mkdir -p "Metabarcoding/$PROJECT/Example_files"
mkdir -p "Metabarcoding/$PROJECT/output"
mkdir -p "$PROJECT_CACHE_DIR"
mkdir -p "${PROJECT_CACHE_DIR}/singularity"
mkdir -p "/group/ajfingergrp/Metabarcoding/fastq_storage"

echo "$PROJECT_CACHE_DIR" > "Metabarcoding/$PROJECT/input/project_cache_path.txt"
# ---------------------------
#  PROMPT: FASTQ STORAGE LOCATION
# ---------------------------
while true; do
    echo
    echo "Where do you want to store FASTQ files?"
    echo "  1) Home directory (Metabarcoding/$PROJECT/input/fastq)"
    echo "  2) Group directory (/group/ajfingergrp/Metabarcoding/fastq_storage/${USER}_${PROJECT}_fastq_YYYYMMDD)"
    read -rp "Enter 1 or 2 [default 1]: " FASTQ_STORE_CHOICE
    FASTQ_STORE_CHOICE="${FASTQ_STORE_CHOICE:-1}"

    case "$FASTQ_STORE_CHOICE" in
        1)
            FASTQ_DIR="Metabarcoding/$PROJECT/input/fastq"
            mkdir -p "$FASTQ_DIR"
            echo -e "${GREEN}FASTQ storage set to HOME: $FASTQ_DIR${RESET}"
            break
            ;;
        2)
            DATE_TAG="$(date +%Y%m%d)"
            FASTQ_DIR="/group/ajfingergrp/Metabarcoding/fastq_storage/${USER}_${PROJECT}_fastq_${DATE_TAG}"
            USE_GROUP_FASTQ=true

            if [[ ! -d "/group/ajfingergrp" ]]; then
                echo -e "${RED}ERROR: /group/ajfingergrp does not exist or is not accessible.${RESET}"
                echo -e "${YELLOW}Falling back to home FASTQ storage.${RESET}"
                FASTQ_DIR="Metabarcoding/$PROJECT/input/fastq"
                USE_GROUP_FASTQ=false
            fi

            mkdir -p "$FASTQ_DIR"
            echo "$FASTQ_DIR" > "Metabarcoding/$PROJECT/input/fastq_storage_path.txt"

            if [[ "$USE_GROUP_FASTQ" == true ]]; then
                echo -e "${GREEN}FASTQ storage set to GROUP: $FASTQ_DIR${RESET}"
            else
                echo -e "${GREEN}FASTQ storage set to HOME: $FASTQ_DIR${RESET}"
            fi
            break
            ;;
        *)
            echo -e "${RED}Invalid input. Please enter 1 or 2.${RESET}"
            ;;
    esac
done

echo -e "${GREEN}Directory structure created.${RESET}"

# ---------------------------
#  CREATE EXAMPLE FILES
# ---------------------------
cat <<EOT > "Metabarcoding/$PROJECT/Example_files/Example_samplesheet.txt"
sampleID	forwardReads	reverseReads	run
B12A1	${FASTQ_DIR}/B12A1_02_R1.fastq.gz	${FASTQ_DIR}/B12A1_02_R2.fastq.gz	A
B12A2	${FASTQ_DIR}/B12A2_02_R1.fastq.gz	${FASTQ_DIR}/B12A2_02_R2.fastq.gz	A
B12A3	${FASTQ_DIR}/B12A3_02_R1.fastq.gz	${FASTQ_DIR}/B12A3_02_R2.fastq.gz	A
B12AB	${FASTQ_DIR}/B12AB_02_R1.fastq.gz	${FASTQ_DIR}/B12AB_02_R2.fastq.gz	A
EXT1	${FASTQ_DIR}/EXT1_02_R1.fastq.gz	${FASTQ_DIR}/EXT1_02_R2.fastq.gz	A
PCR1	${FASTQ_DIR}/PCR1_02_R1.fastq.gz	${FASTQ_DIR}/PCR1_02_R2.fastq.gz	A
PCR2	${FASTQ_DIR}/PCR2_02_R1.fastq.gz	${FASTQ_DIR}/PCR2_02_R2.fastq.gz	A
EOT

cat <<EOT > "Metabarcoding/$PROJECT/Example_files/Example_metadata.txt"
ID	Replicate	Control_Assign	Sample_or_Control	Site	Month	Year
B12A1	A1	1,E1,T1	Sample	Browns_Island	February	2023
B12A2	A2	1,E1,T1	Sample	Browns_Island	February	2023
B12A3	A3	1,E1,T2	Sample	Browns_Island	February	2023
B12AB	AB	1  Control	Control	Control	Control
EXT1  NA	E1	Control	Control	Control	Control
PCR1  NA	T1	Control	Control	Control	Control
PCR2	NA	T2	Control	Control	Control	Control
EOT

if [[ "$DB_MODE" == "custom" ]]; then
cat <<EOT > "Metabarcoding/$PROJECT/Example_files/Example_RSD.txt"
>Animalia;Chordata;Actinopterygii;Cypriniformes;Catostomidae;Catostomus;Catostomus occidentalis;
CACCGCGGTTATACGAGAGGCCCTAGTTGATA...
EOT

echo -e "${GREEN}Example RSD file created.${RESET}"

fi

echo -e "${GREEN}Example input files created.${RESET}"

# ---------------------------
#  COPY CORRECT nf-params.json (ALWAYS named ${PROJECT}_nf-params.json)
# ---------------------------
SRC_STANDARD="$HOME/Metabarcoding/scripts_do_not_alter/nf-params_with_standardized_RSD.json"
SRC_CUSTOM="$HOME/Metabarcoding/scripts_do_not_alter/nf-params_with_custom_RSD.json"
SRC_NONE="$HOME/Metabarcoding/scripts_do_not_alter/nf-params_no_RSD.json"
DEST_JSON="$HOME/Metabarcoding/$PROJECT/params/${PROJECT}_nf-params.json"

case "$DB_MODE" in
  standard)
    SRC="$SRC_STANDARD"
    MSG="Standardized/curated DB -> nf-params_with_standard_RSD.json copied as ${PROJECT}_nf-params.json"
    ;;
  custom)
    SRC="$SRC_CUSTOM"
    MSG="Custom sequence DB -> nf-params_with_custom_RSD.json copied as ${PROJECT}_nf-params.json"
    ;;
  none)
    SRC="$SRC_NONE"
    MSG="No DB (BLAST all ASVs) -> nf-params_no_RSD.json copied as ${PROJECT}_nf-params.json"
    ;;
esac

if [[ -f "$SRC" ]]; then
    cp "$SRC" "$DEST_JSON"
    echo -e "${GREEN}${MSG}.${RESET}"
else
    echo -e "${RED}WARNING: Missing template : $SRC${RESET}"
fi

# ---------------------------
#  JSON UPDATE HELPERS (usable in custom + none)
# ---------------------------
set_json_int () {
    local key="$1"
    local val="$2"
    sed -i -E "s#(\"${key}\"[[:space:]]*:[[:space:]]*)(<[^>]+>|[0-9]+)#\1${val}#g" "$DEST_JSON"
}

set_json_str () {
    local key="$1"
    local val="$2"
    sed -i -E "s#(\"${key}\"[[:space:]]*:[[:space:]]*\")[^\"]*(\")#\1${val}\2#g" "$DEST_JSON"
}

# ---------------------------
#  IF CUSTOM DB MODE: ASK WHICH REF DB, COPY IT TO INPUT, AND UPDATE PARAMS JSON
# ---------------------------
if [[ "$DB_MODE" == "custom" ]]; then
    REF_12S_SRC="/group/ajfingergrp/Metabarcoding/RSD/12S_SFE_250204_RN_common_names.txt"
    REF_16S_SRC="/group/ajfingergrp/Metabarcoding/RSD/16S_SFE_251118_common_names.txt"
    USER_INPUT_DIR="$HOME/Metabarcoding/$PROJECT/input"

    echo
    echo "Custom reference database selected."
    echo "Which reference database do you want to use?"
    echo "  1) 12S MiFish-U"
    echo "  2) 16S fish-specific"

    while true; do
        read -rp "Enter 1 or 2: " CUSTOM_REF_CHOICE
        case "$CUSTOM_REF_CHOICE" in
            1) REF_SRC="$REF_12S_SRC"; break ;;
            2) REF_SRC="$REF_16S_SRC"; break ;;
            *) echo -e "${RED}Invalid input. Please enter 1 or 2.${RESET}" ;;
        esac
    done

    if [[ ! -f "$REF_SRC" ]]; then
        echo -e "${RED}ERROR: Reference file not found: $REF_SRC${RESET}"
        exit 1
    fi

    mkdir -p "$USER_INPUT_DIR"
    REF_DEST="$USER_INPUT_DIR/$(basename "$REF_SRC")"
    cp -f "$REF_SRC" "$REF_DEST"
    echo -e "${GREEN}Copied reference taxonomy file to: $REF_DEST${RESET}"

    if [[ ! -f "$DEST_JSON" ]]; then
        echo -e "${RED}ERROR: Params file not found: $DEST_JSON${RESET}"
        exit 1
    fi

    # Update custom taxonomy path
    sed -i -E "s#(\"dada_ref_tax_custom\"[[:space:]]*:[[:space:]]*\")[^\"]*(\"[[:space:]]*,?)#\1${REF_DEST}\2#g" "$DEST_JSON"

    # Enforce primer + trunc settings depending on selected DB
    case "$CUSTOM_REF_CHOICE" in
        1)
            # 12S MiFish-U
            set_json_int "trunclenf" 120
            set_json_int "trunclenr" 120
            set_json_str "FW_primer" "GTCGGTAAAACTCGTGCCAGC"
            set_json_str "RV_primer" "CATAGTGGGGTATCTAATCCCAGTTTG"
            echo -e "${GREEN}Set 12S MiFish-U settings in params.${RESET}"
            ;;
        2)
            # 16S fish-specific
            set_json_int "trunclenf" 70
            set_json_int "trunclenr" 70
            set_json_int "min_len" 20
            set_json_str "FW_primer" "CGAGAAGACCCTWTGGAGCTTNAG"
            set_json_str "RV_primer" "GGTCGCCCCAACCRAAG"
            echo -e "${GREEN}Set 16S fish-specific settings in params.${RESET}"
            ;;
    esac

    echo -e "${GREEN}Updated ${DEST_JSON}:${RESET}"
    echo -e "  - dada_ref_tax_custom: ${REF_DEST}"
fi

# ---------------------------
#  IF NO CUSTOM DB MODE: ASK WHICH PRIMERS UPDATE PARAMS JSON
# ---------------------------
if [[ "$DB_MODE" == "none" ]]; then
    USER_INPUT_DIR="$HOME/Metabarcoding/$PROJECT/input"

    echo
    echo "No reference database selected (BLAST all ASVs)."
    echo "Which primers did you use?"
    echo "  1) 12S MiFish-U"
    echo "  2) 16S fish-specific"
    echo "  3) V12S-U"
    echo "  4) V16S-U"
    echo "  5) VCO1-U"
    echo "  6) COI-fsd"
    echo "  7) LCO1490/CO1-CFMRa"
    while true; do
        read -rp "Enter 1-7: " NO_REF_CHOICE
        case "$NO_REF_CHOICE" in
            1|2|3|4|5|6|7) break ;;
            *) echo -e "${RED}Invalid input. Please enter 1-7.${RESET}" ;;
        esac
    done

    if [[ ! -f "$DEST_JSON" ]]; then
        echo -e "${RED}ERROR: Params file not found: $DEST_JSON${RESET}"
        exit 1
    fi

    case "$NO_REF_CHOICE" in
        1)
            # ---- 12S MiFish-U ----
            set_json_int "trunclenf" 120
            set_json_int "trunclenr" 120
            set_json_str "FW_primer" "GTCGGTAAAACTCGTGCCAGC"
            set_json_str "RV_primer" "CATAGTGGGGTATCTAATCCCAGTTTG"
            echo -e "${GREEN}Set 12S MiFish-U settings in params.${RESET}"
            ;;
        2)
            # ---- 16S fish-specific ----
            set_json_int "min_len" 20
            set_json_str "FW_primer" "CGAGAAGACCCTWTGGAGCTTNAG"
            set_json_str "RV_primer" "GGTCGCCCCAACCRAAG"
            echo -e "${GREEN}Set 16S fish-specific settings in params.${RESET}"
            ;;
        3)
            # ---- V12S-U ----
            set_json_str "FW_primer" "GTGCCAGCNRCCGCGGTYANAC"
            set_json_str "RV_primer" "ATAGTRGGGTATCTAATCCYAGT"
            echo -e "${GREEN}Set V12S-U primer settings in params.${RESET}"
            ;;
        4)
            # ---- V16S-U ----
            set_json_str "FW_primer" "ACGAGAAGACCCYRYGRARCTT"
            set_json_str "RV_primer" "TCTHRRANAGGATTGCGCTGTTA"
            echo -e "${GREEN}Set V16S-U primer settings in params.${RESET}"
            ;;
        5)
            # ---- VCO1-U ----
            set_json_str "FW_primer" "CAYGCHTTTGTNATRATYTTYTT"
            set_json_str "RV_primer" "GGRGGRTADACDGTYCANCCNGT"
            echo -e "${GREEN}Set VCO1-U primer settings in params.${RESET}"
            ;;
        6)
            # ---- COI-fsd ----
            set_json_str "FW_primer" "GCATGAGCCGGAATAGTRGG"
            set_json_str "RV_primer" "TGTGAKAGGGCAGGTGGTTT"
            echo -e "${GREEN}Set COI-fsd primer settings in params.${RESET}"
            ;;
        7)
            # ---- LCO1490 / CO1-CFMRa ----
            set_json_str "FW_primer" "GGTCAACAAATCATAAAGATATTGG"
            set_json_str "RV_primer" "GGWACTAATCAATTTCCAAATCC"
            echo -e "${GREEN}Set LCO1490/CO1-CFMRa primer settings in params.${RESET}"
            ;;
    esac

    echo -e "${GREEN}Updated ${DEST_JSON}${RESET}"
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
