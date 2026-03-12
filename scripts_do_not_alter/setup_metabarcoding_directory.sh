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
mkdir -p "/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT"
mkdir -p "/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT/params"
mkdir -p "/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT/input"
mkdir -p "/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT/input/fastq"
mkdir -p "/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT/Example_files"
mkdir -p "/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT/output"
mkdir -p "/group/ajfingergrp/Metabarcoding/Project_Runs/Project_IDs/$USER"
mkdir -p "$PROJECT_CACHE_DIR"
mkdir -p "${PROJECT_CACHE_DIR}/singularity"
mkdir -p "/group/ajfingergrp/Metabarcoding/fastq_storage"

echo "$PROJECT_CACHE_DIR" > "/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT/input/project_cache_path.txt"
# ---------------------------
#  PROMPT: FASTQ STORAGE LOCATION
# ---------------------------
# ---------------------------
#  PROMPT: FASTQ STORAGE LOCATION
# ---------------------------
FASTQ_PATH_FILE="/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT/input/fastq_storage_path.txt"

while true; do
    echo
    echo "Where do you want to store FASTQ files?"
    echo "  1) Group project folder (/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT/input/fastq)"
    echo "  2) Elsewhere (you will be prompted type a full path)"
    read -rp "Enter 1 or 2 [default 1]: " FASTQ_STORE_CHOICE
    FASTQ_STORE_CHOICE="${FASTQ_STORE_CHOICE:-1}"

    case "$FASTQ_STORE_CHOICE" in
        1)
            FASTQ_DIR="/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT/input/fastq"
            mkdir -p "$FASTQ_DIR" || { echo -e "${RED}ERROR: cannot create $FASTQ_DIR${RESET}"; exit 1; }
            echo "$FASTQ_DIR" > "$FASTQ_PATH_FILE"
            echo -e "${GREEN}FASTQ storage set to: $FASTQ_DIR${RESET}"
            break
            ;;

        2)
            echo
            echo "Enter an absolute path where FASTQs should live."
            echo "Examples:"
            echo "  /group/ajfingergrp/Metabarcoding/fastq_storage/$PROJECT"
            echo "  /scratch/$USER/$PROJECT/fastq"
            read -rp "FASTQ directory path: " FASTQ_DIR

            # Must be absolute to avoid surprises
            if [[ -z "$FASTQ_DIR" || "$FASTQ_DIR" != /* ]]; then
                echo -e "${RED}ERROR: Please provide an absolute path starting with /.${RESET}"
                continue
            fi

            # Create if missing (or validate if exists)
            mkdir -p "$FASTQ_DIR" 2>/dev/null
            if [[ ! -d "$FASTQ_DIR" || ! -w "$FASTQ_DIR" ]]; then
                echo -e "${RED}ERROR: '$FASTQ_DIR' does not exist or is not writable.${RESET}"
                echo -e "${YELLOW}Tip: choose a /group path you have permissions for, or /scratch/$USER.${RESET}"
                continue
            fi

            echo "$FASTQ_DIR" > "$FASTQ_PATH_FILE"
            echo -e "${GREEN}FASTQ storage set to: $FASTQ_DIR${RESET}"
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
cat <<EOT > "/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT/Example_files/Example_samplesheet.txt"
sampleID	forwardReads	reverseReads	run
B12A1	${FASTQ_DIR}/B12A1_02_R1.fastq.gz	${FASTQ_DIR}/B12A1_02_R2.fastq.gz	A
B12A2	${FASTQ_DIR}/B12A2_02_R1.fastq.gz	${FASTQ_DIR}/B12A2_02_R2.fastq.gz	A
B12A3	${FASTQ_DIR}/B12A3_02_R1.fastq.gz	${FASTQ_DIR}/B12A3_02_R2.fastq.gz	A
B12AB	${FASTQ_DIR}/B12AB_02_R1.fastq.gz	${FASTQ_DIR}/B12AB_02_R2.fastq.gz	A
EXT1	${FASTQ_DIR}/EXT1_02_R1.fastq.gz	${FASTQ_DIR}/EXT1_02_R2.fastq.gz	A
PCR1	${FASTQ_DIR}/PCR1_02_R1.fastq.gz	${FASTQ_DIR}/PCR1_02_R2.fastq.gz	A
PCR2	${FASTQ_DIR}/PCR2_02_R1.fastq.gz	${FASTQ_DIR}/PCR2_02_R2.fastq.gz	A
EOT

cat <<EOT > "/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT/Example_files/Example_metadata.txt"
ID	Replicate	Control_Assign	Sample_or_Control	Site	Month	Year
B12A1	A1	1,E1,T1	Sample	Browns_Island	February	2023
B12A2	A2	1,E1,T1	Sample	Browns_Island	February	2023
B12A3	A3	1,E1,T2	Sample	Browns_Island	February	2023
B12AB	AB	1	Control	Control	Control	Control
EXT1	NA	E1	Control	Control	Control	Control
PCR1	NA	T1	Control	Control	Control	Control
PCR2	NA	T2	Control	Control	Control	Control
EOT

if [[ "$DB_MODE" == "custom" ]]; then
cat <<EOT > "/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT/Example_files/Example_RSD.txt"
>Animalia;Chordata;Actinopterygii;Acipenseriformes;Acipenseridae;Acipenser;Acipenser transmontanus;White sturgeon;
CACCGCGGTTATACGAGAGGCCCCAACTGATAGTCCACGGCGTAAAGCGTGATTAAAGGATGCCTACTACACTAGAGCCAAAAGCCTCCTAAGCCGTCATACGCACCTGAAGGCCCGAAGCCCAACCACGAAGGTAGCTCTACCTAACAAGGACCCCTTGAACCCACGACAACTGAGACA
>Animalia;Chordata;Actinopterygii;Acipenseriformes;Acipenseridae;Acipenser;Acipenser transmontanus;White sturgeon;
CACCGCGGTTATACGAGAGGCCCCAACTGATAATCCACGGCGTAAAGCGTGATTAAAGGATGCCTACTACACTAGAGCCAAAAGCCTCCTAAGCCGTCATACGCACCTGAAGGCCCGAAGCCCAACCACGAAGGTAGCTCTACCTAACAAGGACCCCTTGAACCCACGACAACTGAGACA
>Animalia;Chordata;Actinopterygii;Anguilliformes;Anguillidae;Anguilla;Anguilla rostrata;American eel;
CACCGCGGTTATACGAGGGGCTCAAATTGATATTACACGGCGTAAAGCGTGATTAAAAAATAAACAAACTAAAGCCAAACACTTCCCAAGCTGTCATACGCTACCGGACAAAACGAAGCCCTATAACGAAAGTAGCTTTAACACCTTTGAACTCACGACAGTTGAGGAA
>Animalia;Chordata;Actinopterygii;Atheriniformes;Atherinopsidae;Atherinopsis;Atherinopsis californiensis;Jack silverside;
CACCGCGGTTATACGAGAGGCCCAAGTTGATAGCCAGCGGCGTAAAGAGTGGTTAAGGGACATCCCCACTAAAGTCGAACGCATTCAGAGCTGTTATACGTTCCCGAAAGCAAGAAGCCCCACTACGAAAGTGACTTTATATTACCTGACTCCACGAAAGCTGTGAAA
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
DEST_JSON="/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT/params/${PROJECT}_nf-params.json"

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
SRC_DB_12S="/group/ajfingergrp/Metabarcoding/RSD/12S_SFE_250204_RN_common_names.txt"
SRC_DB_16S_fish="/group/ajfingergrp/Metabarcoding/RSD/16S_SFE_251118_common_names.txt"
SRC_DB_16S_meta="/group/ajfingergrp/Metabarcoding/RSD/16s_reference_tate.txt"

REF_DB_DIR="/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT/input"
mkdir -p "$REF_DB_DIR"

if [[ "$DB_MODE" == "custom" ]]; then
    echo
    echo "Custom reference database selected."
    echo "What type of custom database will you use?"
    echo "  1) 12S MiFish-U"
    echo "  2) 16S fish-specific"
    echo "  3) 16S meta"
    echo "  4) Other"

    while true; do
        read -rp "Enter 1, 2, 3, or 4: " CUSTOM_REF_CHOICE
        case "$CUSTOM_REF_CHOICE" in
            1|2|3|4) break ;;
            *) echo -e "${RED}Invalid input. Please enter 1, 2, 3, or 4.${RESET}" ;;
        esac
    done

    if [[ ! -f "$DEST_JSON" ]]; then
        echo -e "${RED}ERROR: Params file not found: $DEST_JSON${RESET}"
        exit 1
    fi

    case "$CUSTOM_REF_CHOICE" in
        1)
            set_json_int "trunclenf" null
            set_json_int "trunclenr" null
            set_json_str "FW_primer" "GTCGGTAAAACTCGTGCCAGC"
            set_json_str "RV_primer" "CATAGTGGGGTATCTAATCCCAGTTTG"

            DB_NAME=$(basename "$SRC_DB_12S")
            DEST_DB="$REF_DB_DIR/$DB_NAME"

            cp "$SRC_DB_12S" "$DEST_DB" || { echo -e "${RED}ERROR: failed to copy $SRC_DB_12S${RESET}"; exit 1; }

            sed -i -E "s#(\"dada_ref_tax_custom\"[[:space:]]*:[[:space:]]*\")[^\"]*(\")#\1$DEST_DB\2#g" "$DEST_JSON"

            echo -e "${GREEN}12S reference database copied to:${RESET} $DEST_DB"
            ;;
        2)
            set_json_int "trunclenf" null
            set_json_int "trunclenr" null
            set_json_int "min_len" 20
            set_json_str "FW_primer" "CGAGAAGACCCTWTGGAGCTTNAG"
            set_json_str "RV_primer" "GGTCGCCCCAACCRAAG"

            DB_NAME=$(basename "$SRC_DB_16S_fish")
            DEST_DB="$REF_DB_DIR/$DB_NAME"

            cp "$SRC_DB_16S_fish" "$DEST_DB" || { echo -e "${RED}ERROR: failed to copy $SRC_DB_16S_fish${RESET}"; exit 1; }

            sed -i -E "s#(\"dada_ref_tax_custom\"[[:space:]]*:[[:space:]]*\")[^\"]*(\")#\1$DEST_DB\2#g" "$DEST_JSON"

            echo -e "${GREEN}16S fish-specific reference database copied to:${RESET} $DEST_DB"
            ;;
        3)
            set_json_int "trunclenf" null
            set_json_int "trunclenr" null
            set_json_str "FW_primer" "AGTTACYYTAGGGATAACAGCG"
            set_json_str "RV_primer" "CCGGTCTGAACTCAGATCAYGT"

            DB_NAME=$(basename "$SRC_DB_16S_meta")
            DEST_DB="$REF_DB_DIR/$DB_NAME"

            cp "$SRC_DB_16S_meta" "$DEST_DB" || { echo -e "${RED}ERROR: failed to copy $SRC_DB_16S_meta${RESET}"; exit 1; }

            sed -i -E "s#(\"dada_ref_tax_custom\"[[:space:]]*:[[:space:]]*\")[^\"]*(\")#\1$DEST_DB\2#g" "$DEST_JSON"

            echo -e "${GREEN}16S meta reference database copied to:${RESET} $DEST_DB"
            ;;
        4)
            echo
            echo "Other custom database selected."
            read -rp "Enter forward primer sequence: " FW_CUSTOM
            read -rp "Enter reverse primer sequence: " RV_CUSTOM

            if [[ -z "$FW_CUSTOM" || -z "$RV_CUSTOM" ]]; then
                echo -e "${RED}ERROR: Primer sequences cannot be empty.${RESET}"
                exit 1
            fi

            set_json_str "FW_primer" "$FW_CUSTOM"
            set_json_str "RV_primer" "$RV_CUSTOM"

            sed -i -E 's#("dada_ref_tax_custom"[[:space:]]*:[[:space:]]*")[^"]*(")#\1<ADD_CUSTOM_DB_PATH>\2#g' "$DEST_JSON"

            echo -e "${GREEN}Set custom primer sequences in params.${RESET}"
            echo -e "${YELLOW}Custom database path has not been set yet.${RESET}"
            echo -e "${YELLOW}Before running the pipeline, update:${RESET}"
            echo "  $DEST_JSON"
            echo -e "${YELLOW}and replace dada_ref_tax_custom with the full path to your custom database.${RESET}"
            ;;
    esac

    echo -e "${GREEN}Updated ${DEST_JSON}${RESET}"
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
    echo "  8) 18S_1391f_EukBR"
    echo "  9) 12S_batra"
    echo "  10) 16S_meta"
    echo "  11) trnL_gh"
    echo "  12) ITS2_UniPlant_p4"
    echo "  13) 12S_teleo"
    echo "  14) MOL16S"
    while true; do
        read -rp "Enter 1-14: " NO_REF_CHOICE
        case "$NO_REF_CHOICE" in
            1|2|3|4|5|6|7|8|9|10|11|12|13|14) break ;;
            *) echo -e "${RED}Invalid input. Please enter 1-14.${RESET}" ;;
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
        8)
            # ---- 18S_1391f_EukBR ----
            set_json_str "FW_primer" "GTACACACCGCCCGTC"
            set_json_str "RV_primer" "TGATCCTTCTGCAGGTTCACCTAC"
            echo -e "${GREEN}Set 18S_1391f_EukBR primer settings in params.${RESET}"
            ;;
        9)
            # ---- 12S_batra ----
            set_json_str "FW_primer" "ACACCGCCCGTCACCCT"
            set_json_str "RV_primer" "GTAYACTTACCATGTTACGACTT"
            echo -e "${GREEN}Set 12S_batra primer settings in params.${RESET}"
            ;;
        10)
            # ---- 16S_meta ----
            set_json_str "FW_primer" "AGTTACYYTAGGGATAACAGCG"
            set_json_str "RV_primer" "CCGGTCTGAACTCAGATCAYGT"
            echo -e "${GREEN}Set 16S_meta primer settings in params.${RESET}"
            ;;
        11)
            # ---- trnL_gh ----
            set_json_str "FW_primer" "GGGCAATCCTGAGCCAA"
            set_json_str "RV_primer" "CCATTGAGTCTCTGCACCTATC"
            echo -e "${GREEN}Set trnL_gh primer settings in params.${RESET}"
            ;;
        12)
            # ---- ITS2_UniPlant_p4 ----
            set_json_str "FW_primer" "TGTGAATTGCARRATYCMG"
            set_json_str "RV_primer" "CCGCTTAKTGATATGCTTAAA"
            echo -e "${GREEN}Set ITS2_UniPlant_p4 primer settings in params.${RESET}"
            ;;
        13)
            # ---- 12S_teleo ----
            set_json_str "FW_primer" "ACACCGCCCGTCACTCT"
            set_json_str "RV_primer" "CTTCCGGTACACTTACCATG"
            echo -e "${GREEN}Set 12S_teleo primer settings in params.${RESET}"
            ;;
        14)
            # ---- MOL16S ----
            set_json_str "FW_primer" "RRWRGACRAGAAGACCCT"
            set_json_str "RV_primer" "ARTCCAACATCGAGGT"
            echo -e "${GREEN}Set MOL16S primer settings in params.${RESET}"
            ;;
    esac

    echo -e "${GREEN}Updated ${DEST_JSON}${RESET}"
fi


# ---------------------------
#  SAVE CURRENT PROJECT NAME
# ---------------------------
echo "$PROJECT" > "/group/ajfingergrp/Metabarcoding/Project_Runs/Project_IDs/$USER/current_project_name.txt"

# ---------------------------
#  PRINT COLORIZED DIRECTORY TREE
# ---------------------------
echo -e "${BLUE}"
echo "======================================"
echo " METABARCODING PROJECT SETUP COMPLETE "
echo "======================================"
echo -e "${RESET}"

PROJECT_RUN_DIR="/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT"

if command -v tree >/dev/null 2>&1; then
  tree -C "$PROJECT_RUN_DIR"
else
  echo -e "${YELLOW}NOTE: 'tree' not found; showing directories via find.${RESET}"
  find "$PROJECT_RUN_DIR" -maxdepth 4 -type d
fi

# ---------------------------
#  SUMMARY
# ---------------------------
echo -e "${BLUE}Summary of copied files:${RESET}"
echo -e "${GREEN}Setup finished successfully.${RESET}"
