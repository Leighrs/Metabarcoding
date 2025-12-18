# Metabarcoding Directory Setup & Pipeline

![GitHub Repo Size](https://img.shields.io/github/repo-size/Leighrs/Metabarcoding)
![License](https://img.shields.io/github/license/Leighrs/Metabarcoding)
![Last Commit](https://img.shields.io/github/last-commit/Leighrs/Metabarcoding)

Welcome to the **Metabarcoding** repository for the **Genomic Variation Laboratory**!  
This repository helps lab members quickly set up a standardized directory structure on the HPC for running metabarcoding analyses using the **nf-core/ampliseq pipeline**.

---
<details>
<summary><h2>Table of Contents</h2></summary>
  
<br>

- [Repository Overview](#repository-overview)
- [Current Repository Files](#current-repository-files)
- [Running Test Data](#running-test-data)
- [Getting Started](#getting-started)
  - [1. Clone the Repository](1.-clone-the-repository)
  - [2. Set Up Your Project Directory on-hpc](2.-set-up-your-project-directory-on-hpc)
  - [3. Update the NCBI Database (Optional)](3.-update-the-ncbi-database-optional)
- [Running Pipeline](#running-pipeline)
  - [4. Run the nf-coreampliseq Pipeline](4.-run-the-nf-coreampliseq-pipeline)
  - [5. BLAST Unknown ASVs (Optional)](5.-blast-unknown-asvs-optional)
  - [6. Clean up NCBI BLAST Taxonomy Information](6.-clean-up-ncbi-blast-taxonomy-information)
  - [7. Decontaminate ASVs and apply read thresholds (Optional)](6.-decontaminate-asvs-and-apply-read-thresholds)
</details>

---

<details>
<summary><h2>Repository Overview</h2></summary>
  
<br>

This repository contains scripts and configuration files to:

1. Set up your project directory on the HPC.
2. Provide example files (samplesheets, metadata, and RSD sequences) for testing and reference.
3. Run the nf-core/ampliseq pipeline on your data.
4. Perform BLAST searches for unknown ASVs.
5. Update and download the NCBI core nucleotide database (if needed).
6. Clean and process ASV tables using downstream R scripts.
</details>

---

<details>
<summary><h2>Current Repository Files</h2></summary>
  
<br>

| File | Description |
|------|-------------|
| `nf-params_no_RSD.json` | Contents of this parameter file for the nf-core/ampliseq pipeline will be uploaded to project directory if user specifies no RSD. Customize for your project. |
| `nf-params_with_RSD.json` | Contents of this arameter file for the nf-core/ampliseq pipeline will be uploaded to project directory if user specifies the use of an RSD. Customize for your project. |
| `setup_metabarcoding_directory.sh` | Shell script to create your project directory with example samplesheets, metadata, and RSD files. |
| `update_blast_db.slurm` | SLURM batch script to download/update the NCBI core nucleotide database. |
| `blast_asv.slurm` | SLURM batch script to BLAST unknown ASVs. |
| `run_nf-core_ampliseq.slurm` | SLURM batch script to execute the nf-core/ampliseq pipeline using UCD HPC FARM resrouces. |
| `R_ASV_cleanup_scripts/` | Folder containing R scripts for cleaning and formatting ASV tables after nf-core/ampliseq and optional BLAST. |
| `generate_samplesheet_table.sh` | Shell script to generate a samplesheet for your project that will work with the nf-core/ampliseq pipeline. |
| `ncbi_taxonomy.slurm` | SLURM batch script to run a python taxonomy-processing script on BLAST output. |
| `ncbi_pipeline.py` | This script fetches NCBI taxonomy for BLAST hits, determines each ASV’s best and consensus taxonomy, and outputs the merged, ranked results. |
| `run_ampliseq_azure.sh` | This script is for running nf-core/ampliseq using DWR's Azure Batch resources. |
</details>

---

<details>
<summary><h2>Running Test Data</h2></summary>
  
<br>

1. **Clone the Repository**

Ensure you are in your home directory and clonee in the Metabarcoding repository from Github.

```
cd ~
git clone https://github.com/Leighrs/Metabarcoding.git
```

2. **Set Up Your Project Directory**

Ensure you are in your home directory and execute a shell script that will set up a project directory for you.

```
cd ~
./Metabarcoding/scripts_do_not_alter/setup_metabarcoding_directory.sh
```
- **When prompted:**
  - *Enter project name:* ${\color{green}test}$
  - *Are you using a custom reference database?:* ${\color{green}yes}$

3. **Import fastq files, metadata, and custom reference sequence database.**

Ensure you are in your home directory and copy over the test data into your test project folder.

```
cd ~
PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")

cp -r $HOME/Metabarcoding/test_data/test_fastq/. $HOME/Metabarcoding/$PROJECT_NAME/input/fastq/
cp "$HOME/Metabarcoding/test_data/12S_RSD.txt" \
   "$HOME/Metabarcoding/$PROJECT_NAME/input/${PROJECT_NAME}_12S_RSD.txt"
cp "$HOME/Metabarcoding/test_data/metadata.txt" \
   "$HOME/Metabarcoding/$PROJECT_NAME/input/${PROJECT_NAME}_metadata.txt"
```
4. **Generate a samplesheet file.**

Ensure you are in your home directory and run the following shell script.

*This script will autopopulate the PATHs for each of your fastq files, extrapolate sample names from those files, and prompt you to specify how many metabarcoding runs these samples were sequenced in.*

```
cd ~
PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")
"$HOME/Metabarcoding/$PROJECT_NAME/scripts/${PROJECT_NAME}_generate_samplesheet_table.sh" 
```

- **When prompted:**
  - *Did you sequence samples using multiple sequencing runs?:* ${\color{red}no}$

5. **Edit Run Parameters.**

Open the parameter file for the nf-core/ampliseq pipeline:

- The `${PROJECT_NAME}_nf-params.json` file contains all the parameters needed to run the nf-core/ampliseq workflow for your specific project.
- Edit this file so that the input paths, primer sequences, and filtering settings match your dataset.

```
PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")
nano $HOME/Metabarcoding/$PROJECT_NAME/scripts/${PROJECT_NAME}_nf-params.json
```
**Replace these parameters for the test data using the following information:**

Nano files are little tricky to work with. Here are some tips:

- First, highlight the entire script:
  - Go to the top of the script using `Ctrl` + `_`, then type 1, press **Enter**.
  - Then, start selecting text using `Ctrl` + `^`.
  - Highlight the rest of the script using `Ctrl` + `_`, then type 100, press **Enter**.
  - Everything should now be selected.
- Delete all the text in the scriptusing `Ctrl` + `K`.
- Copy the new text below, and paste into the empty script using a right-click to paste. Some terminals may require `Ctrl` + `Shift` + `V`.
- Exit the script using `Ctrl` + `X`. Then `Y` to save. Press **Enter**.

```
{
    "input": "$HOME/Metabarcoding/$PROJECT_NAME/input/${PROJECT_NAME}_samplesheet.txt",
    "FW_primer": "GTCGGTAAAACTCGTGCCAGC",
    "RV_primer": "CATAGTGGGGTATCTAATCCCAGTTTG",

    "metadata": "$HOME/Metabarcoding/$PROJECT_NAME/input/${PROJECT_NAME}_metadata.txt",
    "outdir": "$HOME/Metabarcoding/$PROJECT_NAME/output/",

    "seed": 13,

    "ignore_failed_trimming": true,
    "ignore_failed_filtering": true,

    "trunclenf": 120,
    "trunclenr": 120,

    "dada_ref_taxonomy": false,
    "skip_dada_addspecies": true,
    "dada_ref_tax_custom": "$HOME/Metabarcoding/$PROJECT_NAME/input/${PROJECT_NAME}_12S_RSD.txt",
    "dada_min_boot": 80,
    "dada_assign_taxlevels": "Kingdom,Phylum,Class,Order,Family,Genus,Species,Common",

    "exclude_taxa": "none",

    "skip_qiime": true,
    "skip_barrnap": true,
    "skip_dada_addspecies": true,
    "skip_tse": true
}

```

JSON files can't expand environment variables, like `$HOME` or `$PROJECT_NAME`. Create a file with an expanded variable unique to your system.
```
export PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")
envsubst '$HOME $PROJECT_NAME' \
  < "$HOME/Metabarcoding/$PROJECT_NAME/scripts/${PROJECT_NAME}_nf-params.json" \
  > "$HOME/Metabarcoding/$PROJECT_NAME/scripts/${PROJECT_NAME}_nf-params_expanded.json"
```
6. If you are using ${\color{red}DWR}$ ${\color{red}Azure}$ ${\color{red}Batch}$ resources, create `config` files. If you are using UCD HPC Farm resources, skip this step.

First, create and open a new file called  `azure_esm_ampliseq.config` and `config`:
```
nano $HOME/azure_esm_ampliseq.config
```
Paste in the following:
```
process.executor = 'azurebatch'
docker.enabled = true
workDir = '<REDACTED>'


azure {
    batch {
        autoPoolMode = false
        deletePoolsOnCompletion = false
    }
}

process {
  queue = '<REDACTED>'
}
```
```
nano $HOME/config
```
*This file will need Azure Storage and Batch resource keys/tokens.*

For each file, you will need to request the required resource information from DWR.

7. **Run the nf-core/ampliseq Pipeline:** 

Ensure you are in your home directory and run the following shell script.

**If you are using** ${\color{red}UCD}$ ${\color{red}HPC}$ ${\color{red}Farm}$ **resources, run this script:**

```
cd ~
PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")
sbatch "$HOME/Metabarcoding/$PROJECT_NAME/scripts/${PROJECT_NAME}_blast_asv.slurm"
```
**OR if you are using** ${\color{red}DWR}$ ${\color{red}Azure}$ ${\color{red}Batch}$ **resources, run this script:**

```
cd ~
PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")
$HOME/Metabarcoding/$PROJECT_NAME/scripts/${PROJECT_NAME}_run_ampliseq_azure.sh
```

</details>

---

<details>
<summary><h2>Getting Started</h2></summary>
  
<br>

<details>
<summary><strong>1. Clone the Repository</strong></summary>

<br>

>Ensure you are in your home directory and clone in the **Metabarcoding** repository from Github.
>
>```bash
>cd ~
>git clone https://github.com/Leighrs/Metabarcoding.git
>```

</details>

<details>
<summary><strong>2. Set Up Your Project Directory on HPC</strong></summary>

<br>

>Ensure you are in your home directory and execute a shell script that will set up a project directory for you.
>
>```bash
>cd ~
>./Metabarcoding/scripts_do_not_alter/setup_metabarcoding_directory.sh
>```
>When prompted, type ${\color{green}yes}$ if you are using a custom reference sequence database (RSD) or ${\color{red}no}$ if you are not using a custom RSD.
>
><details>
><summary><strong>📁 Your project directory structure will look like this (click to expand).</strong></summary>
>
><br>
>
>```bash
>Metabarcoding/
>└── <project_name>/
>    ├── input/
>    │   ├── fastq/
>    │   ├── Example_samplesheet.txt
>    │   ├── Example_metadata.txt
>    │   └── Example_RSD.txt # Will not import if you answer "no" to having a custom RSD.
>    ├── output/
>    │   └── intermediates_logs_cache/
>    │       └── singularity/
>    └── scripts/ # If you need alter any scripts, edit these. I recommend leaving the originals alone in case you need to revert back to them.
>        ├── <project_name>_ncbi_taxonomy.slurm
>        ├── <project_name>_nf-params.json
>        ├── <project_name>_ncbi_pipeline.py
>        ├── <project_name>_blast_asv.slurm
>        ├── <project_name>_generate_samplesheet_table.sh
>        ├── <project_name>_run_nf-core_ampliseq.slurm
>        ├── <project_name>_update_blast_db.slurm
>        └── <project_name>_R_ASV_cleanup_scripts/
>            ├── <project_name>_1_Data_Analyses_decontam_removal_251106.R
>            ├── <project_name>_2_Data_Analyses_presence_absence_after_decontam_removal_251106.R
>            ├── <project_name>_3_Data_Analyses_sample_threshold_251106.R
>            ├── <project_name>_4_Data_Analyses_presence_absence_after_sample_threshold_251106.R
>            ├── <project_name>_5_Data_Analyses_total_threshold_251106.R
>            ├── <project_name>_6_Data_Analyses_presence_absence_after_total_threshold_251106.R
>            └── <project_name>_GVL_metabarcoding_cleanup_main.R
>current_project_name.txt # Do not edit this file. Other SLURM scripts need access to it.
>Logs_archive/
>```
></details>
</details>

<details>
<summary><strong>3. Update the NCBI Database (Optional)</strong></summary>

<br>

>```bash
>cd ~
>PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")
>sbatch "$HOME/Metabarcoding/$PROJECT_NAME/scripts/${PROJECT_NAME}_update_ncbi_db.sh" --delete-old
>```
>This script will generate a new NCBI database with today's current date in its file name.
>
>Adding `--delete-old` will remove the previous nucleotide database. This option is recommended to save space in the group folder.
>
>If you wish to keep the old database for some purpose, omit `--delete-old`.
</details>
</details>

---

<details>
<summary><h2>Run the nf-core/ampliseq Pipeline</h2></summary>
  
<br>

<details>
<summary><strong>4. Create and import required files to run the pipeline.</strong></summary>

<br>

<details>
<summary><strong>A. Import fastq files:</strong></summary>

<br>

> Import location: `$HOME/Metabarcoding/<project_name>/input/fastq/`
> 
> If you are using a terminal, such as MobaXterm, you can drag and drop the files.
> 
> Other terminals may require you using code to transfer the files in. Online resources for this process can be found here: https://docs.hpc.ucdavis.edu/data-transfer/
> 
> If you are unsure of your `<project_name>`, run this code to print it to the terminal:
> 
>```bash
>cat $HOME/Metabarcoding/current_project_name.txt
>```

</details>

<details>
<summary><strong>B. Generate a samplesheet file:</strong></summary>

<br>
 
> Import location: `$HOME/Metabarcoding/<project_name>/input/fastq/`
>
>Ensure you are in your home directory and execute a shell script to generate a samplesheet.
>
> The samplesheet is required for the pipeline to locate you fastq files.
>```bash
>cd ~
>PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")
>"$HOME/Metabarcoding/$PROJECT_NAME/scripts/${PROJECT_NAME}_generate_samplesheet_table.sh" 
>```
>
> This script will autopopulate the PATHs for each of your fastq files, extrapolate sample names from those files, and prompt you to specify how many metabarcoding runs these samples were sequenced in.
> 
> The script's default is to extrapolate sample names from the forward reads (R1) using the first two fields of the `_R1_001.fastq.gz` file names separated by and underscore ("_").
> 
> For example:
> 
>        File name: B12A1_02_4_S14_L001_R1_001.fastq.gz  ->  Sample ID: B12A1_02
> 
> If you wish to extrapolate a different part of the file name or if your fastq files have a different file name ending than `_R1_001.fastq.gz`, you can edit the following code chunk from the `${PROJECT_NAME}_generate_samplesheet_table.sh` file:
>
> First, open sample sheet generation shell script:
>```bash
>PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")
>nano $HOME/Metabarcoding/$PROJECT_NAME/scripts/${PROJECT_NAME}_generate_samplesheet_table.sh
>```
>
> Second, locate the following code chunk in the script:
> 
> ```bash
>extract_sample_id() {
>   local filename="$1"
>    
>    # Remove R1/R2 etc. suffix from filename
>    local base="${filename%_R1_001.fastq.gz}"
>
>    # --- DEFAULT RULE ---
>    # Extract the first TWO underscore-separated fields
>    # e.g. B12A1_02_4_S14 ? B12A1_02
>    echo "$base" | awk -F'_' '{print $1"_"$2}'
>}
> ```
>
> Third, if you have a different forward fastq file ending than `_R1_001.fasq.gz`, edit this field with the appropiate ending:
>
> ```bash
> local base="${filename%_R1_001.fastq.gz}"
> ```
>
> Lastly, if you need to extrapolate a different part of the file name for your sample IDs, edit this field:
> ```bash
>    # Extract ONLY the first underscore-separated field
>    echo "$base" | awk -F'_' '{print $1}'
>```
> When using awk, the input line is automatically split into fields based on a delimiter (also called the field separator). In this case the delimiter is set to be an underscore.
>
> Fields are numbered from left to right in the file name, and each field is referred to using a dollar sign ($) plus its number.
>
> Examples:
> `echo "$base" | awk -F'_' '{print $1}'`: prints text before the first underscore
> 
> `echo "$base" | awk -F'_' '{print $2}'`: prints text between 1st and 2nd underscore
> 
> `echo "$base" | awk -F'_' '{print $2_$3}'`: prints text between 1st and 2nd underscore, and between 2nd and 3rd underscore. Connect text with an underscore.
> 
> `echo "$base" | awk -F'_' '{print $2_$4}'`: prints text between 1st and 2nd underscore, and between 3rd and 4th underscore. Connect text with an underscore.
</details>

<details>
<summary><strong>C. Upload Metadata:</strong></summary>

<br>

> Import location: `$HOME/Metabarcoding/<project_name>/input/fastq/`
> Rules:
>  - Needs to be a tab-deliminated text file or a .tsv file.
>  - First column is labeled "ID" for your sample IDs. These IDs match the sample IDs in your samplesheet you just made.
>  - If you wish to use a decontamination protocol later, add a column called "Control_Assign" to assign which controls are paired with which samples.
>    - For example:
>          
>| sampleID | Control_Assign | Sample_or_Control | Notes |
>|----------|----------------|-------------------|-------|
>| BROA1 | 1,2,4 | Sample | ← Controls 1,2,4 need to be subtracted |
>| FLYA2 | 2,3,4 | Sample | ← Controls 2,3,4 need to be subtracted |
>| BROAB | 1     | Control | ← Control ID = 1 |
>| FLYAB | 3     | Control | ← Control ID = 3 |
>| EXT1  | 2     | Control | ← Control ID = 2 |
>| PCR1  | 4     | Control | ← Control ID = 4 |
>
> Add any other columns for metadata you wish to attach to these samples for downstream analyses.
> 
> Drag and drop metadata file in, or use the directions here: https://docs.hpc.ucdavis.edu/data-transfer/
</details>

<details>
<summary><strong>D. Upload a Reference Sequence Database [Optional, but highly recommended]:</strong></summary>

<br>

>Import location: `$HOME/Metabarcoding/<project_name>/input/fastq/`
>  - Rules:
>    - There is an example RSD .txt file found in your project input folder.
>    - Needs to be a tab-deliminated text file or a .tsv file.
>Drag and drop RSD file in, or use the directions here: https://docs.hpc.ucdavis.edu/data-transfer/
 
</details>
</details>

<details>
<summary><strong>5. Edit run parameters.</strong></summary>

<br>

> Open the parameter file for the nf-core/ampliseq pipeline:
>```bash
>PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")
>nano $HOME/Metabarcoding/$PROJECT_NAME/scripts/${PROJECT_NAME}_nf-params.json
>```
>  - The `${PROJECT_NAME}_nf-params.json` file contains all the parameters needed to run the `nf-core/ampliseq` workflow for your specific project. 
>  - Edit this file so that the input paths, primer sequences, and filtering settings match your dataset.
>  - Notes:
>    - All paths *must be absolute (full paths)*, not environment variables or relative paths.
>    - If you do want to set a parameter (e.g., `trunclenf`), use `null` or remove parameter line entirely. Leaving it blank will cause a JSON parsing error.
>    - Booleans must be written without quotes:
>        - `true` / `false` ← correct!
>        - `"true"` / `"false"` ← invalid!
>    - Primer sequences must include only the *target-specific* portion, not the adapters.
>      
>  - **Quick Start: Parameters You *Must* Edit:**
>    - *Most projects only need to adjust the following parameters:*
>        - **Input Files**
>          - `input`: Path to sample sheet (`*.txt`).
>          - `metadata`: Path to metadata (`*.txt`).
>        - **Primer Sequences**
>          - `FW_primer`: Forward primer sequence (target-specific region only).
>          - `RV_primer`: Reverse primer sequence (target-specific region only).
>              - **Do not** include Illumina tails, adapters, barcodes, or indexes.
>        - **Output Directory**
>          - `outdir`: Output directory in project folder.
>        - **Optional: Read Trimming**
>          -  Use only if quality profiles suggest specific truncation lengths.
>          - `trunclenf`: Truncate forward reads at fixed length (or `null`).
>          - `trunclenr`: Truncate reverse reads at fixed length (or `null`).
>            -  If unsure, leave as **`null`**.
>  - **Other Parameters (for more advanced users)**
>    - Below are explanations for *all other parameters included in your JSON file*.
>      - **Primer Removal & Cutadapt Settings**
>        - `illumina_pe_its`: Whether to treat reads as ITS paired-end Illumina amplicons.
>        - `cutadapt_min_overlap`: Minimum primer/read overlap required for trimming.
>        - `cutadapt_max_error_rate`: Allowed mismatch rate during primer matching.
>        - `double_primer`: Trim primers twice (commonly used for ITS workflows).
>        - `ignore_failed_trimming`: Retain reads even if primer trimming fails.
>      - **Filtering & DADA2 Settings**
>        - `min_read_counts`: Minimum number of reads required per sample.
>        - `ignore_empty_input_files`: Skip empty FASTQ files rather than failing.
>        - `seed`: Random seed for reproducibility.
>        - `trunq`: Quality trimming threshold at the 3′ end.
>        - `trunclenf`, `trunclenr`: Truncate reads to fixed lengths (or set to `null` to disable).
>        - `trunc_qmin`: Minimum per-base quality threshold.
>        - `trunc_rmin`: Fraction of reads required to retain a truncation.
>        - `max_ee`: Maximum expected errors allowed per read.
>        - `min_len`: Minimum read length allowed after filtering.
>        - `ignore_failed_filtering`: Keep samples even if filtering is insufficient.
>      - **ASV Inference (DADA2)**
>        - `sample_inference`: Choose `"independent"` or `"pooled"`.
>        - `mergepairs_strategy`: Strategy to merge paired-end reads (`"merge"` or `"consensus"`).
>      - **Consensus merger parameters:** *These control alignment scoring in consensus merging.*
>        - `mergepairs_consensus_match`
>        - `mergepairs_consensus_mismatch`
>        - `mergepairs_consensus_gap`
>        - `mergepairs_consensus_mino`
>        - `mergepairs_consensus_percentile_cutoff`
>      - **ASV Length Filtering**
>        - `min_len_asv`, `max_len_asv`: Set allowable ASV lengths (e.g., 150–190 bp for 12S minibarcodes).
>      - **Codon-Based Filtering**
>        - `filter_codons`: Enable or disable codon frame filtering.
>        - `stop_codons`: Stops used to detect unrealistic coding sequences.
>      - **Taxonomy Assignment**
>        - `dada_ref_taxonomy`: DADA2 classifier reference database.
>        - `dada_ref_tax_custom`: Path to a custom taxonomy file.
>        - `dada_ref_tax_custom_sp`: Optional species-level taxonomy.
>        - `dada_taxonomy_rc`: Reverse complement handling.
>        - `dada_min_boot`: Minimum bootstrap threshold (confidence cutoff).
>        - `dada_assign_taxlevels`: Comma-separated taxonomic levels to assign.
>        - `exclude_taxa`: Taxa to be removed.
>      - **ITS-Specific Options**
>        - `cut_its`: ITS extraction tool (or `"none"` to disable).
>        - `its_partial`: Allow partial ITS extraction (or `null`).
>      - **QIIME2 & Diversity Analysis**
>        - `min_frequency`: Feature count threshold.
>        - `min_samples`: Minimum number of samples required for a feature.
>        - `metadata_category`: Metadata ID used for grouping (optional).
>        - `metadata_category_barplot`: Column used for QIIME2 barplots.
>        - `picrust`: Enable predicted functional profiles.
>        - `diversity_rarefaction_depth`: Depth used for rarefaction.
>        - `tax_agglom_min`, `tax_agglom_max`: Taxonomic levels to aggregate.
>      - **Skip Flags (Workflow Control)**
>        - `skip_fastqc`: Skip FastQC.
>        - `skip_cutadapt`: Skip primer trimming.
>        - `skip_dada_quality`: Skip DADA2 quality plots.
>        - `skip_qiime`: Skip all QIIME2 steps.
>        - `skip_taxonomy`: Skip taxonomy assignment.
>        - `skip_dada_taxonomy`: Skip DADA2 taxonomy.
>        - `skip_dada_addspecies`: Skip species refinement.
>        - `skip_barplot`: Skip QIIME barplots.
>        - `skip_abundance_tables`: Skip feature tables.
>        - `skip_alpha_rarefaction`: Skip rarefaction analyses.
>        - `skip_diversity_indices`: Skip diversity metrics.
>        - `skip_phyloseq`: Skip phyloseq output.
>        - `skip_tse`: Skip TSE output.
>        - `skip_report`: Skip MultiQC report.
</details>

<details>
<summary><strong>6. Run pipeline.</strong></summary>

<br>

>```bash
>cd ~
>PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")
>sbatch "$HOME/Metabarcoding/$PROJECT_NAME/scripts/${PROJECT_NAME}_run_nf-core_ampliseq.slurm"
>```
></details>
</details>


---


<details>
<summary><h2>BLAST Unknown ASVs</h2></summary>
  
<br>
To BLAST your entire .fasta file created from the nf-core/ampliseq pipeline, run the following code:

-  If you did not include a custom reference sequence database, choose this option.

```bash
cd ~
PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")
sbatch "$HOME/Metabarcoding/$PROJECT_NAME/scripts/${PROJECT_NAME}_blast_asv.slurm"
```

If you included a custom reference sequence database (RSD), you can instead BLAST only the ASVs that did not receive taxonomic assignments or only received an incomplete assignment:
- Do not use this option if you did not use a custom RSD. This option requires pulling data from a phyloseq object, which is only generated for those you used an RSD.

```bash
cd ~
PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")
RUN_BLAST=yes sbatch "$HOME/Metabarcoding/$PROJECT_NAME/scripts/${PROJECT_NAME}_retrieve_phyloseq_unassigned_ASVs.slurm"
```
- If you only wish to retrieve your unassigned (or incomplete assigned) ASVs and not BLAST them, change to `RUN_BLAST=no`.
</details>

---

<details>
<summary><h2>Clean up NCBI BLAST Taxonomy Information</h2></summary>
  
<br>
This script will auto process your raw BLAST output to output the single 'best' taxonomic rank for each assigned ASV:

- Final taxa ranks are chosen based on highest percent identity (similarity), bit score (alignment quality/score), and e-value (statistical significance).
- For tied results, this script will assign the least common taxonomic rank to the ASV.
- Explanations for the final taxonomic assignment will be provided for each ASV.
- Hopefully this will make parsing through and proofreading BLAST assignments much easier.

```bash
cd ~
PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")
sbatch "$HOME/Metabarcoding/$PROJECT_NAME/scripts/${PROJECT_NAME}_ncbi_taxonomy.slurm" option1
#OR
sbatch "$HOME/Metabarcoding/$PROJECT_NAME/scripts/${PROJECT_NAME}_ncbi_taxonomy.slurm" option2
```
- If your fasta file was generated directly from the nf-core/ampliseq pipeline, specify `option1`.
- If your fasta file was generated by pulling out unassigned ASVs from a phyloseq object, specify `option2`.

<details>
<summary><strong>📁 Expected output files (click to expand).</strong></summary>

<br>

| File | Description |
|------|-------------|
| `{$PROJECT_NAME}_ncbi_taxon_rank_casche.tsv` | Simple list of all your unique final taxa and ranks. |
| `{$PROJECT_NAME}_final_LCTR_taxonomy_with_ranks.tsv` | Most useful. Lists ASV ID, ASV sequence, taxa assignment, taxa rank, and assignment explanation for each ASV. |
| `{$PROJECT_NAME}_final_LCTR_taxonomy.tsv` | Same as file above, but does not include ranks. This is an intermediate file the script uses to make rank assignments. |
| `{$PROJECT_NAME}_best_taxa_per_ASV.tsv` | Raw BLAST output for only the 'best' aligment for each ASV. |
| `{$PROJECT_NAME}_blast_taxonomy_merged.tsv` | A file containing raw BLAST output merged with taxonomic information fetched from NCBI (see file below). |
| `{$PROJECT_NAME}_ncbi_taxonomy_results.tsv` | A file containing further taxonomic information (fetched from NCBI) for each BLAST alignment. |

</details>

</details>

---

<details>
<summary><h2>Decontaminate ASVs and Apply Read Thresholds</h2></summary>
  
<br>

- NOTE: This part of the pipeline is not yet edited to be on the FARM. I am currently working on integrating it all into a single shell script with minimal interactive user prompts for use on FARM.
- The folder `R_ASV_cleanup_scripts/` contains a collection of R scripts used for cleaning ASV data generated by the nf-core/ampliseq pipeline to prepare finalized datasets for analyses.
#### Available scripts include:
| Script | Description |
|------|-------------|
| `GVL_metabarcoding_cleanup_main.R` | Master script to run all ASV cleanup steps below. |
| `1_Data_Analyses_decontam_removal_251106.R` | Removes reads found in control samples from samples assigned to those controls. |
| `2_Data_Analyses_presence_absence_after_decontam_removal_251106.R` | Produces a presence/absence matrix after decontamination removal. |
| `3_Data_Analyses_sample_threshold_251106.R` | Applies an optional per-sample ASV abundance threshold. |
| `4_Data_Analyses_presence_absence_after_sample_threshold_251106.R` | Produces a presence/absence matrix after per-sample ASV abundance threshold. |
| `5_Data_Analyses_total_threshold_251106.R` | Applies a minimum sequencing depth threshold across all samples. |
| `6_Data_Analyses_presence_absence_after_total_threshold_251106.R` | Produces a final presence/absence matrix after minimum sequencing depth threshold. |

- These scripts are optional but extremely helpful for producing clean, analysis ready ASV tables.
- You should only need to open the `GVL_metabarcoding_cleanup_main.R` script to run this pipeline. To avoid breaking the script, only edit the **"User-defined parameters"** in the script.

</details>

---

- Currently working on:
  - Integrating all of the R scripts from the decontamination part of the pipline into a single shell script with minimal interactive user prompts for use on FARM.
  - For those who used an RSD: A script to get the aligned (and assigned) ASVs back into the phyloseq object and remove any remainining unassigned ASVs.
  - For those who BLASTed their entire dataset: A script to create a phyloseq object for them.
