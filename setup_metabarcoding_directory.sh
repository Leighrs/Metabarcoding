#!/bin/bash

# Ask user for project name
read -p "Enter project name: " PROJECT

# Create main directory
mkdir -p "Metabarcoding/$PROJECT"

# Create subdirectories
mkdir -p "Metabarcoding/Logs_archive"
mkdir -p "Metabarcoding/$PROJECT/scripts"
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

# Create Example_RSD.txt in the input folder
cat <<EOT > "Metabarcoding/$PROJECT/input/Example_RSD.txt"
>Animalia;Chordata;Actinopterygii;Cypriniformes;Catostomidae;Catostomus;Catostomus occidentalis; Sacramento Sucker;
CACCGCGGTTATACGAGAGGCCCTAGTTGATAGGCACGGCGTAAAGGGTGGTTAAGGGAGTACACAAATAAAGCCGAAGGACCCTCTGGCCGTTATACGCTTCTGGACGCCCGAAGCCCAAATACGAAAGTAGCTTTAATTTAGCCCACCTGACCCCACGAAAACTGAGAAA
>Animalia;Chordata;Actinopterygii;Cypriniformes;Cobitidae;Paramisgurnus;Paramisgurnus dabryanus;Large-scale Loach;
CACCGCGGTTATACGAGAGGCCCCAGTTGATGAACACGGCGTAAAGGGTGGTTAAGGTTTAACTAAAATAAAGTCAAAAGACTTCTTGGCCGTCATACGCCCCTGAACATCTGAAGCTCATATACGAAAGTAACTTTAATATTAGCCCACCTGACCCCACGAAAACTGAGAAA
>Animalia;Chordata;Actinopterygii;Cypriniformes;Cyprinidae;Carassius;Carassius auratus;Goldfish;
CACCGCGGTTAGACGAGAGGCCCTAGTTGATATTACAACGGCGTAAAGGGTGGTTAAGGATAAATAAAAATAAAGTCAAATGGCCCCTTGGCCGTCATACGCTTCTAGGCGTCCGAAGCCCTAATACGAAAGTAACTTTAATGAACCCACCTGACCCCACGAAAGCTGAGGAA
>Animalia;Chordata;Actinopterygii;Cypriniformes;Cyprinidae;Cyprinella;Cyprinella lutrensis;Red Shiner;
CACCGCGGTTAGACGAGAGGCCCTAGTTGATAGAACAACGGCGTAAAGGGTGGTTAAGGATAGCGAGATAATAAAGTCGAATGGCCCTTTGGCTGTCATACGCTTCTAGGAGTCTGAAGCCCAATATACGAAAGTAACTTTAATAACGTCCACCTGACCCCACGAAAACTGAGAAA
>Animalia;Chordata;Actinopterygii;Cypriniformes;Cyprinidae;Cyprinus;Cyprinus carpio;Common Carp;
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
echo "¦   +-- scripts/"
echo "¦       +-- $PROJECT_ncbi_taxonomy.slurm"
echo "¦       +-- $PROJECT_nf-params.json"
echo "¦       +-- $PROJECT_ncbi_pipeline.py"
echo "¦       +-- $PROJECT_blast_asv.slurm"
echo "¦       +-- $PROJECT_generate_samplesheet_table.sh"
echo "¦       +-- $PROJECT_update_blast_db.slurm"
echo "¦       +-- $PROJECT_R_ASV_cleanup_scripts/"
echo "¦           +-- $PROJECT_1_Data_Analyses_decontam_removal_251106.R"
echo "¦           +-- $PROJECT_2_Data_Analyses_presence_absence_after_decontam_removal_251106.R"
echo "¦           +-- $PROJECT_3_Data_Analyses_sample_threshold_251106.R"
echo "¦           +-- $PROJECT_4_Data_Analyses_presence_absence_after_sample_threshold_251106.R"
echo "¦           +-- $PROJECT_5_Data_Analyses_total_threshold_251106.R"
echo "¦           +-- $PROJECT_6_Data_Analyses_presence_absence_after_total_threshold_251106.R"
echo "¦           +-- $PROJECT_GVL_metabarcoding_cleanup_main.R"
echo "+-- current_project_name.txt"
echo "Logs_archive/"

#################################
#  COPY & RENAME scripts
#################################
SRC_JSON="$HOME/Metabarcoding/scripts_do_not_alter/nf-params.json"
DEST_JSON="$HOME/Metabarcoding/$PROJECT/scripts/${PROJECT}_nf-params.json"

if [[ -f "$SRC_JSON" ]]; then
    cp "$SRC_JSON" "$DEST_JSON"
    echo "Copied nf-params.json to: $DEST_JSON"
else
    echo "WARNING: nf-params.json not found at $SRC_JSON"
fi

##

SRC_NCBI="$HOME/Metabarcoding/scripts_do_not_alter/ncbi_taxonomy.slurm"
DEST_NCBI="$HOME/Metabarcoding/$PROJECT/scripts/${PROJECT}_ncbi_taxonomy.slurm"

if [[ -f "$SRC_NCBI" ]]; then
    cp "$SRC_NCBI" "$DEST_NCBI"
    echo "Copied ncbi_taxonomy.slurm to: $DEST_NCBI"
else
    echo "WARNING: ncbi_taxonomy.slurm not found at $SRC_NCBI"
fi

##

SRC_BLAST="$HOME/Metabarcoding/scripts_do_not_alter/blast_asv.slurm"
DEST_BLAST="$HOME/Metabarcoding/$PROJECT/scripts/${PROJECT}_blast_asv.slurm"

if [[ -f "$SRC_BLAST" ]]; then
    cp "$SRC_BLAST" "$DEST_BLAST"
    echo "Copied blast_asv.slurm to: $DEST_BLAST"
else
    echo "WARNING: blast_asv.slurm not found at $SRC_BLAST"
fi

##

SRC_UPDATE="$HOME/Metabarcoding/scripts_do_not_alter/update_blast_db.slurm"
DEST_UPDATE="$HOME/Metabarcoding/$PROJECT/scripts/${PROJECT}_update_blast_db.slurm"

if [[ -f "$SRC_UPDATE" ]]; then
    cp "$SRC_UPDATE" "$DEST_UPDATE"
    echo "Copied update_blast_db.slurm to: $DEST_UPDATE"
else
    echo "WARNING: update_blast_db.slurm not found at $SRC_UPDATE"
fi

##

SRC_SAMPLE="$HOME/Metabarcoding/scripts_do_not_alter/generate_samplesheet_table.sh"
DEST_SAMPLE="$HOME/Metabarcoding/$PROJECT/scripts/${PROJECT}_generate_samplesheet_table.sh"

if [[ -f "$SRC_SAMPLE" ]]; then
    cp "$SRC_SAMPLE" "$DEST_SAMPLE"
    echo "Copied generate_samplesheet_table.sh to: $DEST_SAMPLE"
else
    echo "WARNING: generate_samplesheet_table.sh not found at $SRC_SAMPLE"
fi

##

SRC_NF="$HOME/Metabarcoding/scripts_do_not_alter/run_nf-core_ampliseq.slurm"
DEST_NF="$HOME/Metabarcoding/$PROJECT/scripts/${PROJECT}_run_nf-core_ampliseq.slurm"

if [[ -f "$SRC_NF" ]]; then
    cp "$SRC_NF" "$DEST_NF"
    echo "Copied run_nf-core_ampliseq.slurm to: $DEST_NF"
else
    echo "WARNING: run_nf-core_ampliseq.slurm not found at $SRC_NF"
fi

##

SRC_NCBI_PY="$HOME/Metabarcoding/scripts_do_not_alter/ncbi_pipeline.py"
DEST_NCBI_PY="$HOME/Metabarcoding/$PROJECT/scripts/${PROJECT}_ncbi_pipeline.py"

if [[ -f "$SRC_NCBI_PY" ]]; then
    cp "$SRC_NCBI_PY" "$DEST_NCBI_PY"
    echo "Copied ncbi_pipeline.py to: $DEST_NCBI_PY"
else
    echo "WARNING: ncbi_pipeline.py not found at $SRC_NCBI_PY"
fi

##

SRC_CON="/home/leighrs/Metabarcoding/scripts_do_not_alter/R_ASV_cleanup_scripts/"
DEST_CON="$HOME/Metabarcoding/$PROJECT/scripts/${PROJECT}_R_ASV_cleanup_scripts/"

if [[ -d "$SRC_CON" ]]; then
    mkdir -p "$DEST_CON"
    cp -r "$SRC_CON/"* "$DEST_CON/"
    echo "Copied R_ASV_cleanup_scripts folder to: $DEST_CON"

    # Rename files inside folder with project prefix
    for f in "$DEST_CON"/*; do
        base=$(basename "$f")
        mv "$f" "$DEST_CON/${PROJECT}_$base"
    done

    echo "Renamed files inside R_ASV_cleanup_scripts with project prefix."

else
    echo "WARNING: R_ASV_cleanup_scripts folder not found at $SRC_CON"
fi

##


echo "$PROJECT" > "$HOME/Metabarcoding/current_project_name.txt"
