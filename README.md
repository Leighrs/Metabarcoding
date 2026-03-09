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
- [Running Your Data](#running-your-data)
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
| `nf-params_with_custom_RSD.json` | Contents of this parameter file for the nf-core/ampliseq pipeline will be uploaded to project directory if user specifies the use of a custom RSD. Customize for your project. |
| `check_ids_match.sh` | A shell script that scans your metadata and samplesheet files to make sure sample IDs match. Also adds metadata PATH to your params file. |
| `nf-params_with_standardized_RSD.json` | Contents of this parameter file for the nf-core/ampliseq pipeline will be uploaded to project directory if user specifies the use of a standardized (included in ampliseq pipeline) RSD. Customize for your project. |
| `setup_metabarcoding_directory.sh` | Shell script to create your project directory with example samplesheets, metadata, and RSD files. |
| `update_blast_db.slurm` | SLURM batch script to download/update the NCBI core nucleotide database. |
| `blast_asv.slurm` | SLURM batch script to BLAST unknown ASVs. |
| `submit_ampliseq.sh` | A wrapper shell script to specify where to place sbatch log files. Sometimes sbatch struggles with using environmental variables so this gets around that. |
| `run_nf-core_ampliseq.slurm` | SLURM batch script to execute the nf-core/ampliseq pipeline using UCD HPC FARM resrouces. |
| `R_ASV_cleanup_scripts/` | Folder containing R scripts for cleaning and formatting ASV tables after nf-core/ampliseq and optional BLAST. |
| `generate_samplesheet_table.sh` | Shell script to generate a samplesheet for your project that will work with the nf-core/ampliseq pipeline. |
| `ncbi_taxonomy.slurm` | SLURM batch script to run a python taxonomy-processing script on BLAST output. |
| `ncbi_pipeline.py` | This script fetches NCBI taxonomy for BLAST hits, determines each ASVâ€™s best and consensus taxonomy, and outputs the merged, ranked results. |
| `review_and_update_phyloseq.R`| This script helps the user to review their BLAST assignments and reimport new assignments back into their phylseq object. |
| `retrieve_phyloseq_unassigned_ASVs.slurm`| This script retrieves unassigned ASVs from phyloseq objects following the nf-core/ampliseq pipeline. |
| `run_GVL_metabarcoding_cleanup_main.sh`| This script runs the R scripts for decontaminating ASVs. |
| `run_review_and_update_phyloseq.sh`| This script runs the R scripts for reviewing BLAST assignments and updated your phyloseq object. |
</details>

---

<details>
<summary><h2>Running Test Data</h2></summary>
  
<br>

**1. Clone the Repository**

> Ensure you are in your home directory and clone in the Metabarcoding repository from Github.
>
>```
>cd ~
>git clone https://github.com/Leighrs/Metabarcoding.git
>```

**2. Set Up Your Project Directory**

> Ensure you are in your home directory and execute a shell script that will set up a project directory for you.
>
>```
>cd ~
>./Metabarcoding/scripts_do_not_alter/setup_metabarcoding_directory.sh
>```
>- **When prompted:**
>    - *Enter project name:* ${\color{green}test}$
>    - *Reference database choice:* ${\color{green}2}$
>    - If you get this prompt -> *Cache directory already exists:* ${\color{green}R}$
>    - *Where do you want to store FASTQ files?:* ${\color{green}1}$
>    - *Which reference database do you want to use?:* ${\color{green}1}$

**3. Import fastq files, metadata, and custom reference sequence database.**

> Ensure you are in your home directory and copy over the test data into your test project folder.
>
>```
>cd ~
>PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")
>
>cp -r $HOME/Metabarcoding/test_data/test_fastq/. $HOME/Metabarcoding/$PROJECT_NAME/input/fastq/
>cp "$HOME/Metabarcoding/test_data/12S_RSD.txt" \
>   "$HOME/Metabarcoding/$PROJECT_NAME/input/${PROJECT_NAME}_12S_RSD.txt"
>cp "$HOME/Metabarcoding/test_data/metadata.txt" \
>   "$HOME/Metabarcoding/$PROJECT_NAME/input/${PROJECT_NAME}_metadata.txt"
>```

**4. Generate a samplesheet file.**

> Ensure you are in your home directory and run the following shell script.
>
> *This script will autopopulate the PATHs for each of your fastq files, extrapolate sample names from those files, and prompt you to specify how many metabarcoding runs these samples were sequenced in.*
>
>```
>cd ~
>PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")
>"$HOME/Metabarcoding/scripts_do_not_alter/generate_samplesheet_table.sh" 
>```

>- **When prompted:**
>    - *Did you sequence samples using multiple sequencing runs?:* ${\color{red}no}$
>    - *How should sampleID be extracted from FASTQ filenames?:* ${\color{green}2}$

**5. Confirm that sample IDs are valid and match between metadata and samplesheet:** 

> Ensure you are in your home directory and run the following shell script.
>
>```
>cd ~
>PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")
>"$HOME/Metabarcoding/scripts_do_not_alter/check_ids_match.sh"
>```
>This script will also locate your metafile and add that path to your params file.

**6. Edit Run Parameters.**

> Open the parameter file for the nf-core/ampliseq pipeline:
> 
> - The `${PROJECT_NAME}_nf-params.json` file contains all the parameters needed to run the nf-core/ampliseq workflow for your specific project.
> - Edit this file so that the input paths, primer sequences, and filtering settings match your dataset.
>
>```
>PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")
>nano $HOME/Metabarcoding/$PROJECT_NAME/params/${PROJECT_NAME}_nf-params.json
>```
> **For the test data, only replace the RSD path using the following information:**
> 
> Nano files are little tricky to work with. Here are some tips for ${\color{red}Windows}$ Users:
>
>  - First, navigate to the end of the parameter you want to edit using your arrow keys.
>  - Backspace to remove file path, string, or number.
>  - Copy new file path, string, or number.
>  - Right click to paste into parameter file.
>  - Exit the script using `Ctrl` + `X`. Then `Y` to save. Press **Enter**.
>
>```
>{
>    "dada_ref_tax_custom": "$HOME/Metabarcoding/$PROJECT_NAME/input/${PROJECT_NAME}_12S_RSD.txt",
>}
>```
>
> JSON files can't expand environment variables, like `$HOME` or `$PROJECT_NAME`. Create a file with an expanded variable unique to your system.
> 
>```
>cd ~
>export PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")
>envsubst '$HOME $PROJECT_NAME' \
>  < "$HOME/Metabarcoding/$PROJECT_NAME/params/${PROJECT_NAME}_nf-params.json" \
>  > "$HOME/Metabarcoding/$PROJECT_NAME/params/${PROJECT_NAME}_nf-params_expanded.json"
>```

**7. Run the nf-core/ampliseq Pipeline:** 

> Ensure you are in your home directory and run the following shell script.
>
>```
>cd ~
>PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")
>sbatch "$HOME/Metabarcoding/scripts_do_not_alter/submit_ampliseq.sh"
>```
> To see your current running slurm job and get your jobID:
>```
>cd ~
>squeue -u $USER
>```
> To view your slurm error and output logs, navigate to `/group/ajfingergrp/Metabarcoding/intermediates_logs_cache/slurm_logs/` and locate the files called `ampliseq_<jobID>.err` and `ampliseq_<jobID>.out`. 


**8. BLAST Unknown ASVs:**

> To BLAST your ASVs that did not assign during the nf-core/ampliseq pipeline, run the following code:
>
>```bash
>cd ~
>PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")
>RUN_BLAST=yes sbatch "$HOME/Metabarcoding/scripts_do_not_alter/retrieve_phyloseq_unassigned_ASVs.slurm"
>```
>  - `RUN_BLAST=no` will extract your unassigned ASVs into a fasta file for you to see, but will not BLAST them.
>  - *NOTE: When working with your real data, this code chunk will only work if you used a custom reference sequence database (RSD). If you did not use a custom RSD, a separate code chunk will be provided.*
 
**9. Clean up NCBI Blast Taxonomy:**
   
> This script will auto process your raw BLAST output to output the single 'best' taxonomic rank for each assigned ASV:
>
>- Final taxa ranks are chosen based on highest percent identity (similarity), bit score (alignment quality/score), and e-value (statistical significance).
>- For tied results, this script will assign the least common taxonomic rank to the ASV.
>- Explanations for the final taxonomic assignment will be provided for each ASV.
>- Hopefully this will make parsing through and proofreading BLAST assignments much easier.
>
>```bash
>cd ~
>PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")
>sbatch "$HOME/Metabarcoding/scripts_do_not_alter/ncbi_taxonomy.slurm" option2
>```
>
>- `option2`: If you used a custom RSD, which we did for this test data.
>
><details>
><summary><strong>Expected output files (click to expand).</strong></summary>
>
><br>
>
>| File | Description |
>|------|-------------|
>| `{$PROJECT_NAME}_ncbi_taxon_rank_casche.tsv` | Simple list of all your unique final taxa and ranks. |
>| `{$PROJECT_NAME}_final_LCTR_taxonomy_with_ranks.tsv` | Most useful. Lists ASV ID, ASV sequence, taxa assignment, taxa rank, and assignment explanation for each ASV. |
>| `{$PROJECT_NAME}_final_LCTR_taxonomy.tsv` | Same as file above, but does not include ranks. This is an intermediate file the script uses to make rank assignments. |
>| `{$PROJECT_NAME}_best_taxa_per_ASV.tsv` | Raw BLAST output for only the 'best' aligment for each ASV. |
>| `{$PROJECT_NAME}_blast_taxonomy_merged.tsv` | A file containing raw BLAST output merged with taxonomic information fetched from NCBI (see file below). |
>| `{$PROJECT_NAME}_ncbi_taxonomy_results.tsv` | A file containing further taxonomic information (fetched from NCBI) for each BLAST alignment. |
>
></details>

**10. Review and approve BLAST taxonomic assignments:**

> This script requires a manual review step to approve/dissaprove and change BLAST taxonomic assignments if needed.
>
>First, run a shell script to review BLAST assignments and update phylseq object:
>```
>cd ~
>PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")
>"$HOME/Metabarcoding/scripts_do_not_alter/run_review_and_update_phyloseq.sh" 
>```

>**A. When prompted, open the `${PROJECT_NAME}_final_LCTR_taxonomy_with_ranks.REVIEW.xlsx` spreadsheet.** 
> - If you have MobaXterm, simply right click the file and open with Excel. 
> - If you are using a MacOS, open your computer terminal in a separate window and use the `scp` command. This should be run on your computer, not on the cluster. After uploading the file, navigate to local directory and open the spreadsheet.
> ```
> scp -r [USER]@[CLUSTER].hpc.ucdavis.edu:~/[CLUSTER-DATA] local-directory
> 
> # Example to upload to current local directory: scp leighrs@farm.hpc.ucdavis.edu:/home/leighrs/Metabarcoding/test/output/BLAST/Review/test_final_LCTR_taxonomy_with_ranks.REVIEW.xlsx .
> # Example to upload to a specific local directory: scp leighrs@farm.hpc.ucdavis.edu:/home/leighrs/Metabarcoding/test/output/BLAST/Review/test_final_LCTR_taxonomy_with_ranks.REVIEW.xlsx C:\Users\Leighrs13\Metabarcoding
> ```

>**B. Manually review BLAST taxonomic assignments:**
>
><details>
>
><summary><strong>For an explanation on columns, click here to expand:</strong></summary>
>
><br>
>
> - Column A: ASV ID
> - Column B: ASV sequence
> - Columns C and D: BLAST taxonomic assignments
> - Column E: Do you approve the taxonomic assignment?
>   - blank: I approve
>   - no: I dissaprove
> - Column F: Leave a note here for your dissaproval reasoning.
> - Column G: Remove ASV from dataset (including phyloseq object)?
>   - blank: Leave ASV in dataset
>   - yes: Remove ASV from dataset
> - Columns H-O: Taxon name override columns
>   - If you disapprove of BLAST taxon assignment, you can override by specifying desired taxon names here. 
>   - You only need to fill out the ranks you want to change.
>   - If you disapprove of a BLAST taxon assignment, but do not override ANY taxon ranks then ALL ranks will be set to "unknown".
> Column P: Explanation for BLAST taxon assignment.
>
></details>
>
> **When reviewing the test data:**
>   - You should see one unassigned ASV that BLASTed to Lucania (Killifish) genus. This ASV was not assigned in the nf-core/ampliseq pipeline because I removed this species from the reference sequence database so that we could practice getting assignments for ASVs that need to be BLASTed.
>   - Columns E-L: Current taxonomic classification based on nf-core/ampliseq pipeline DADA2 taxonomic assignment using custom RSD.
>   - Columns: M-T: Proposed BLAST taxonomic classification.
>   - Leave the U column to approve of the BLAST assignment.
>   - Fill in the missing taxa ranks into columns X-AE that BLAST did not assign:
>        - Column AA: Cyprinodontiformes
>        - Column AB: Fundulidae
>        - Column AE: Killifish spp

>**C. Save edited spreadsheet (same file name) and upload to FARM:**
> - If you have MobaXterm, simply save and close the file.
> - If you are using a MacOS, open your computer terminal in a separate window and use the `scp` command. This should be run on your computer, not on the cluster.
> ```
>scp -r local-directory [USER]@[CLUSTER].hpc.ucdavis.edu:~/[CLUSTER-DATA] 
>
># Example to upload from local directory: scp test_final_LCTR_taxonomy_with_ranks.REVIEW.xlsx leighrs@farm.hpc.ucdavis.edu:/home/leighrs/Metabarcoding/test/output/BLAST/Review/ 
># Example to upload from a specific local directory: scp C:\Users\Leighrs13\Metabarcoding\test_final_LCTR_taxonomy_with_ranks.REVIEW.xlsx leighrs@farm.hpc.ucdavis.edu:/home/leighrs/Metabarcoding/test/output/BLAST/Review/ 
> ```

> **D. After uploading edited spreadsheet into FARM, navigate back to terminal with FARM and re-run the following code:**
> 
> ```
> cd ~
>PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")
>"$HOME/Metabarcoding/scripts_do_not_alter/run_review_and_update_phyloseq.sh" 
> ```
> - Your phyloseq object will now be updated with these taxonomic assignments.
> - You can ignore the intermediate `test_reviewed_assignments.tsv` file created in the BLAST folder.

**11. Remove contaminant reads from ASVs:**

>Define label parameters:
>```
>cd ~
>export SAMPLE_TYPE_COL="Sample_or_Control"
>export SAMPLE_LABEL="Sample"
>export CONTROL_LABEL="Control"
>export ASSIGNED_CONTROLS_COL="Control_Assign"
>```
> - `SAMPLE_TYPE_COL`: Column name in metadata for assigning which are controls or samples.
> - `SAMPLE_LABEL`: Label for sample rows.
> - `CONTROL_LABEL`: Label for control rows.
> - `ASSIGNED_CONTROLS_COL`: Column name in metadata for assigning which controls go to which samples.
>   -  For this column, controls are assigned a single unique ID. Samples should contain a comma-delimited list for which controls are assigned to them.
>     -  For example:
>
> | sampleID | Control_Assign | Sample_or_Control | Explanation |
> |------|-------------|-------------|-------------|
> |BROA1|1,2,4|Sample|Controls 1,2,4 need to be subtracted from this sample|
> |FLYA2|2,3,4|Sample|Controls 2,3,4 need to be subtracted from this sample|
> |BROAB|1|Control|The ID of this control is 1|
> |FLYAB|3|Control|The ID of this control is 2|
> |EXT1|2|Control|The ID of this control is 3|
> |PCR1|4|Control|The ID of this control is 4|
>
>Define threshold parameters:
>```
>cd ~
>export SAMPLE_THRES=0.0005
>export MIN_DEPTH_THRES=0.0005
>```
> - `SAMPLE_THRES`: Defines per-sample ASV threshold to be applied. You can define as a proportion (e.g., 0.01) or an absolute read count (e.g., 10).
>   - Removes ASVs that do not reach a minimum read count.
>     - Example 1: Sample threshold = 0.0005 = 0.05% of reads per sample = 
>       - Sample A has 100,000 reads -> This threshold will remove 50 reads from each ASV (i.e., minimum 50 reads per ASV to keep that ASV).
>       - Sample B has 10,000 reads -> This threshold will remove 5 reads from each ASV (i.e., minimum 5 reads per ASV to keep that ASV).
>     - Example 2: Sample threshold = 10
>       - Sample A (sample's total reads don't matter)  <- this threshold would remove 10 reads from each ASV (i.e., minimum 10 reads per ASV to keep that ASV).
> - `MIN_DEPTH_THRES`: Defines minimum sequencing depth for each sample. You can define as a proportion (e.g., 0.01) or an absolute read count (e.g., 10).
>   - Removes samples that do not reach a minimum read count.
>     - Example 1: Min seq depth threshold  = 0.0001 = 0.01% of total reads
>       - Total reads in dataset = 10,000,000 -> This threshold would remove any sample with fewer than 1,000 reads.
>     - Example 2: Min seq depth threshold = 10 
>       -Total reads in dataset = Doesn't matter -> This threshold would remove any sample with fewer than 10 reads.
>
>Then, run shell script to start decontamination script:
>```
>cd ~
>PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")
>"$HOME/Metabarcoding/scripts_do_not_alter/run_GVL_metabarcoding_cleanup_main.sh"
>```
>You will now have a cleaned ready-to-go phyloseq object to start your data analyses!
>   - Originally developed for microbial communites, a `phyloseq.rds` object operates as a single container designed to simplify data management and ensure that all data compenents are tracked and manipulated together. The main classes of data that a `phyloseq.rds` object hold:
>     - `otu_table`: A matrix containing abundance data for OTU/ASV across all samples.
>     - `sam_data`: A data frame containing all your metadata.
>     - `tax_table`: A matrix containing taxa assignments for each ASV/OTU.
>     -  It can also hold an optional `refseq` class to contain representative DNA sequences for each OTU/ASV. This allows the sequences to be renamed to something simpler in the other classes.
>     -  A `phylo` class can also be created to show evolutionary relationshiops among OTUs/ASVs.
>  - There are lots of analyses and data visualizations you can do with your phyloseq object. But to get started, try installing phyloseq in RStudio and importing in your final, cleaned phyloseq object from: `$HOME/Metabarcoding/$PROJECT_NAME/output/ASV_cleanup_output/dada2_phyloseq_cleaned.rds`
>  - In R:
>```
>View(dada2_phyloseq_cleaned@sam_data) # Shows you your metadata
>View(dada2_phyloseq_cleaned@tax_table) # Shows you your taxa assignments
>View(dada2_phyloseq_cleaned@otu_table) # Shows you your ASV abundance matrix
>```

</details>

---

<details>
<summary><h2>Running Your Data</h2></summary>
  
<br>

**1. Clone the Repository**

> Ensure you are in your home directory and clone in the Metabarcoding repository from Github.
>
>```
>cd ~
>git clone https://github.com/Leighrs/Metabarcoding.git
>```

**2. Set Up Your Project Directory**

> Execute a shell script that will set up a project directory for you.
>
>```
>$HOME/Metabarcoding/scripts_do_not_alter/setup_metabarcoding_directory.sh
>```
>- **When prompted:**
>    - ${\color{green}Enter}$ ${\color{green}project}$ ${\color{green}name:}$ Enter a unique project name of your choice.
>    - ${\color{green}Reference}$ ${\color{green}database}$ ${\color{green}choice:}$
>      - 1 : Standardized/curated database -> Choose this option if you are using one of nf-core/ampliseq's built-in reference databases. If you choose this option, you will need to specify which reference database you are using in your parameter *.json* file under the `dada_ref_taxonomy` param. Databases used in nf-core/ampliseq found [here](https://nf-co.re/ampliseq/2.16.1/docs/usage/#taxonomic-classification).
>      - 2 : Custom sequence database -> Choose this option if you will be using a custom sequence database.
>      - 3 : Neither (BLAST all ASVs) -> Choose this option if you do not have any reference databases to use and instead will have all your ASVs BLASTed.
>    - ${\color{green}Cache}$ ${\color{green}directory}$ ${\color{green}already}$ ${\color{green}exists,}$ ${\color{green}Choose}$ ${\color{green}an}$ ${\color{green}option:}$ Each project creates its own cache folder with your project name in the group directory to store intermedite files, logs, and cache from the nf-core/ampliseq pipeline. If someone else used the same project name or you are doing another run using the same name, you will get this error. Only cache folders with unique names can exist. Choose an option to resolve this issue.
>      - A : Remove existing cache folder
>      - B : Enter a new project name (new project ID)
>      - C : Abort
>    - ${\color{green}Where}$ ${\color{green}do}$ ${\color{green}you}$ ${\color{green}want}$ ${\color{green}to}$ ${\color{green}store}$ ${\color{green}FASTQ}$ ${\color{green}files?:}$ It is recommended to store on group directory to save space on your home directory.
>      - 1 : Group directory (PATH for where you will upload your FASTQ files to)
>      - 2 : Elsewhere (Will prompt you for a path)
>    - ${\color{green}Which}$ ${\color{green}reference}$ ${\color{green}database}$ ${\color{green}do}$ ${\color{green}you}$ ${\color{green}want}$ ${\color{green}to}$ ${\color{green}use?:}$ This option will only show for those who selected to use a custom sequence database. It lists custom sequence databases that are logged into this pipeline. Choosing one will upload that reference database to your project directory and add the primer sequences and PATH to the RSD to your parameter file. If you would like to log a custom reference database, contact Leigh Sanders (lrsanders@ucdavis.edu). Current databases logged include:
>      -  1 : 12S MiFish-U
>      -  2 : 16S fish-specific

**3A. Import fastq files:**

> If storing your fastq files on FARM already, copy fastq files to the subfolder (`/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT_NAME/input/fastq`) created for your project:
>
>```
>#Example
>cp -r $HOME/Metabarcoding/16Sv1/fastq/. /group/ajfingergrp/Metabarcoding/Project_Runs/16Sv1/input/fastq
>```
> If you need to transfer fastq files from your local directory:
>  - If you have MobaXterm, simply drag/drop or copy/paste into folder.
>  - If you are using a Mac, use the  `scp` command to transfer files:
> ```
>scp -r local-directory [USER]@[CLUSTER].hpc.ucdavis.edu:~/[CLUSTER-DATA] 
>
>Example:
>scp -r /Users/leighrs/Documents/UCDavis/GVL/eDNA/16Sv1/. leighrs@farm.hpc.ucdavis.edu:/group/ajfingergrp/Metabarcoding/Project_Runs/16Sv1/input/fastq
>```

**3B. Import metadata:**

>If storing your metadata on FARM already, copy metadata file to the subfolder (`/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT_NAME/input`) created for your project:
>
>```
>#Example
>cp $HOME/Metabarcoding/16Sv1/16Sv1_metadata.txt /group/ajfingergrp/Metabarcoding/Project_Runs/16Sv1/input/
>```
> If you need to transfer your metadata file from your local directory:
>  - If you have MobaXterm, simply drag/drop or copy/paste into folder.
>  - If you are using a Mac, use the  `scp` command to transfer file:
> ```
>scp local-directory [USER]@[CLUSTER].hpc.ucdavis.edu:~/[CLUSTER-DATA] 
>
>Example:
>scp /Users/leighrs/Documents/UCDavis/GVL/eDNA/16Sv1/16Sv1_metadata.txt leighrs@farm.hpc.ucdavis.edu:/group/ajfingergrp/Metabarcoding/Project_Runs/16Sv1/input
>```
> **Metadata File Rules for nf-core/ampliseq:***
>
>- **File names must contain the word `metadata`.**
>- File must be either:
>  - a **tab-delimited `.txt` file**, or
>  - a **`.tsv` file**.
>- The **first column must be labeled `ID`** and contain your **sequencing IDs**.
>  - **These IDs must match the sequencing IDs in your samplesheet.**
>- **No hyphens `-` or spaces** are allowed in sequencing IDs.
>- **Sequencing IDs must follow these rules:**
>   - **No duplicates**
>   - **Do NOT start with a number**
>     - ❌ `18S_32`
>     - ✅ `Meow_18S_32`
>   - **All sequencing IDs must have the same number of underscore-separated fields**
>     - ❌ `MEOW_A_1`, `MEOW_A_2`, `MEOW_C`  
    (two IDs have 3 fields, one has 2)
>     - ✅ `MEOW_1_A`, `Meow_456_B`, `hiss_45_meow`  
    (all have three fields)
>   - **Sample names must be unique without being contained inside another sample name**
>     - Never use sample IDs where **one name is the prefix of another**
>     - ❌ `Sample`, `Sample_10`
>     - ❌ `BROA`, `BROA1`
>     - ✅ `BROA_1`, `BROB_1`
>   - These sequencing IDs will ultimately become your **FASTQ file names**, which will be parsed by the **nf-core/ampliseq pipeline** as your sample names.
>- **Add in a Biological Sample IDs to metadata *(Recommended)***
>   - If your sequencing IDs are **not the identifiers you want to use for downstream analyses**, it is recommended that you add in this additional metadata column.
>   - Example:
>
>        | ID | sampleID |
>        |----|----------|
>        | MEOW_1_A | SoilSample1 |
>        | MEOW_2_A | SoilSample2 |
>   - The pipeline will still use the **sequencing IDs**, but having biological IDs recorded here will make **later analysis and interpretation easier**.
>- **If your samples were sequenced across *multiple runs*, add a `Run` column.**
>   - **nf-core/ampliseq prefers run IDs in `A`, `B`, `C`, ... format.**
>   - Specifying run IDs is **essential for proper sequence error handling**.
>   - Example:
>
>        | ID | sampleID | Run |
>        |----|----------|-----|
>        | BROA1 | Sample1 | A |
>        | FLYA2 | Sample2 | B |
>- **If you plan to use a *decontamination protocol later*, add a column called `Control_Assign`:**
>   - This assigns which controls are paired with which samples.
>   - Example:
>
>        | ID | Control_Assign | Sample_or_Control | Run | Notes *(not in metadata)* |
>        |----|----------------|-------------------|-----|---------------------------|
>        | BROA1 | 1,2,4 | Sample | A | Controls 1,2,4 need to be subtracted |
>        | FLYA2 | 2,3,4 | Sample | B | Controls 2,3,4 need to be subtracted |
>        | BROAB | 1 | Control | A | Control ID = 1 |
>        | FLYAB | 3 | Control | B | Control ID = 3 |
>        | EXT1 | 2 | Control | C | Control ID = 2 |
>        | PCR1 | 4 | Control | C | Control ID = 4 |
>- Add any other columns for metadata you wish to attach to these samples for downstream analyses.
>- To view an example metadata file, run the following code:
>```
>PROJECT_NAME=$(cat "/group/ajfingergrp/Metabarcoding/Project_Runs/Project_IDs/$USER/current_project_name.txt")
>nano $HOME/Metabarcoding/$PROJECT_NAME/Example_files/Example_metadata.txt
>```
>- **Summary Checklist**
>   - Before running `nf-core/ampliseq`, confirm:
>       - File name contains **`metadata`**
>       - File is **tab-delimited `.txt` or `.tsv`**
>       - First column is **`ID`** and contains sequencing IDs
>       - Sequencing IDs **match the samplesheet**
>       - No **hyphens or spaces**
>       - IDs:
>           - have **no duplicates**
>           - **do not start with numbers**
>           - have the **same number of underscore-separated fields**
>           - **are not prefixes of other sample names**
>       - `Run` column included if multiple sequencing runs exist
>       - Optional `sampleID` column included for biological identifiers
>       - Optional `Control_Assign` column included if using **decontamination**
>
>**After uploading, run this code to confirm your metadata is likely formatted correctly:**
>```
>"$HOME/Metabarcoding/scripts_do_not_alter/validate_metadata.sh"
>```
> - Checks for:
>   - Filename contains "metadata"
>   - File is .txt (tab-delimited) or .tsv
>   - First column header must be "ID"
>   - Run column missing. If present, validates A/B/C... style
>   - Control_Assign is missing (needed for decontam later)
>   - CRLF (^M) and inconsistent field counts (classic "line X did not have N elements")
>   - Empty/duplicate sample IDs
>   - Hypens and spaces

**3C. Import custom reference sequence database (optional):**

> If your custom pipeline has been logged into this pipeline, your custom RSD should already be uploaded and in the subfolder (`$HOME/Metabarcoding/${PROJECT_NAME}/input/`).
>   - Naviate to this subfolder to confirm it is there. If not follow these directions to transfer RSD into your project folder:
>
>If storing your RSD on FARM already copy file to the subfolder (`/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT_NAME/input`) created for your project:
>
>```
>#Example
>cp $HOME/Metabarcoding/16Sv1/16Sv1_RSD.txt /group/ajfingergrp/Metabarcoding/Project_Runs/16Sv1/input/
>```
> If you need to transfer your RSD file from your local directory:
>  - If you have MobaXterm, simply drag/drop or copy/paste into folder.
>  - If you are using a Mac, use the  `scp` command to transfer file:
> ```
>scp local-directory [USER]@[CLUSTER].hpc.ucdavis.edu:~/[CLUSTER-DATA] 
>
>Example:
>scp /Users/leighrs/Documents/UCDavis/GVL/eDNA/16Sv1/16Sv1_RSD.txt leighrs@farm.hpc.ucdavis.edu:/group/ajfingergrp/Metabarcoding/Project_Runs/16Sv1/input
>```
>  - **Rules:**
>    - Needs to be a **tab-deliminated** *.txt* file or a *.tsv* file.
>    - Each taxa record myst follow this structure:
>       - Each entry starts with `>`
>       - Taxonomic levels separated by semicolons `;`
>       - Always end the header with a trailing semicolon
>       - ASV sequence following on the next line
>       - No spaces inside sequences
>       - *If you would like to create a custom RSD with different taxa levels, email Leigh Sanders (lrsanders@ucdavis.edu). It is possible, but it will require some changes to other scripts so that there are no conflicts.*
>       - **Example:**
>```
>>Kingdom;Phylum;Class;Order;Family;Genus;Species;Common Name;
>SEQUENCE
>```
>  
> To view the example RSD, run the following code:
>```
>PROJECT_NAME=$(cat "/group/ajfingergrp/Metabarcoding/Project_Runs/Project_IDs/$USER/current_project_name.txt")
>nano $HOME/Metabarcoding/$PROJECT_NAME/Example_files/Example_RSD.txt
>```

**4. Generate a samplesheet file.**

> The samplesheet is required for the pipeline to locate you fastq files.
> Execute the following shell script.
>
> *This script will autopopulate the PATHs for each of your fastq files, extrapolate sample names from those files, and prompt you to specify how many metabarcoding runs these samples were sequenced in.*
>
> *If you sequenced your samples in multiple runs and specified run IDs in your metadata, this script will also autopopulate your run IDs to your samplesheet.*
>
>```
>"$HOME/Metabarcoding/scripts_do_not_alter/generate_samplesheet_table.sh" 
>```
>
>**When prompted:**
>    - *Did you sequence samples using multiple sequencing runs?:* ${\color{green}yes}$ or ${\color{red}no}$
>       - If you answer ${\color{red}no}$: 
>           - All samples will be assigned to a single run "A"
>      - If you answer ${\color{green}yes}$: 
>           - Sequencing run ID will be assigned to your samplesheet if you provided run IDs in your metadata. 
>           - If not, you must go into the samplesheet and manually assign sequence IDs to the last column for each sample. Each sequencing run needs to be assigned a unique letter (e.g., A, B, C, ...).
>           - The nf-core/ampliseq pipeline prefers sequence IDs in the A, B, C, ... format.
>     
><details>
>
><summary><strong>If you wish to extrapolate a different part of the file name using the awk command, click to expand:</strong></summary>
>
><br>
>
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
></details>
>

**5. Confirm that sample IDs are valid and match between metadata and samplesheet:** 

> Execute the following shell script.
>
>```
>"$HOME/Metabarcoding/scripts_do_not_alter/check_ids_match.sh"
>```
>This script will also locate your metafile and add that path to your params file.
>
> **Following on-screen instructions/prompts if you get any errors.**

**6. Edit Run Parameters.**

> Open the parameter file for the nf-core/ampliseq pipeline:
> 
> - The `$HOME/Metabarcoding/${PROJECT_NAME}/params/${PROJECT_NAME}_nf-params.json` file contains all the parameters needed to run the nf-core/ampliseq workflow for your specific project.
> - In ideal cases, you may find your samplesheet is already completely filled out and no space holder PATHs/variables exist. 
>      - But double check everything is correct and edit as necessary so that your input paths, primer sequences, and filtering settings match your dataset.
>      - Environmental variables, `$HOME` and `$PROJECT_NAME` should be left as is.
>
>```
>PROJECT_NAME=$(cat "/group/ajfingergrp/Metabarcoding/Project_Runs/Project_IDs/$USER/current_project_name.txt")
>nano /group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT_NAME/params/${PROJECT_NAME}_nf-params.json
>```
> To exit the nano script, use `Ctrl` + `X`. Then `Y` to save. Press **Enter**.
> Notes:
>    - If you do not want to set a parameter (e.g., `trunclenf`), use `null` or remove parameter line entirely. Leaving it blank will cause a JSON parsing error.
>    - Booleans must be written without quotes:
>        - `true` / `false` ← correct!
>        - `"true"` / `"false"` ← invalid!
>    - Primer sequences must include only the *target-specific* portion, not the adapters.
>
><details>    
><summary><strong>Quick Start: Parameters You *Must* Edit (click to expand):</strong></summary>
>
><br>
>
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
></details>
>
><details>
><summary><strong>Other Parameters (click here to expand):</strong></summary>
>
><br>
>
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
></details>
>
> JSON files can't expand environment variables, like `$HOME` or `$PROJECT_NAME`. To make sure all your paths are absolute paths, create a file with an expanded variable unique to your system.
>```
>export PROJECT_NAME=$(cat "/group/ajfingergrp/Metabarcoding/Project_Runs/Project_IDs/$USER/current_project_name.txt")
>envsubst '$HOME $PROJECT_NAME' \
>  < "/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT_NAME/params/${PROJECT_NAME}_nf-params.json" \
>  > "/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT_NAME/params/${PROJECT_NAME}_nf-params_expanded.json"
>```

**7. Run the nf-core/ampliseq Pipeline:** 

> Execute the following shell script.
>
>```
>$HOME/Metabarcoding/scripts_do_not_alter/submit_ampliseq.sh
>```
> Check your current running slurm job and get your jobID:
>```
>squeue -u $USER
>```
>Once you no longer see a running job, your pipeline is complete.
>
>Run the following shell script to check if your script was **likely** successful, and check for samples that may have failed trimming and filtering. 
>
>*Note: This script is not 100% effective and determining success or reason for failure. It is only designed to look for certain key output files that indicate success was likely. Regarding unsuccessful runs, it only looks for causes associated with samples that failed trimming or filtering. For a complete error log, check your SLURM logs.*
>   - To view your slurm error and output logs, navigate to `/group/ajfingergrp/Metabarcoding/intermediates_logs_cache/slurm_logs/` and locate the files called `ampliseq_<jobID>.err` and `ampliseq_<jobID>.out`. 
>```
>"$HOME/Metabarcoding/scripts_do_not_alter/check_ampliseq_success.sh"
>```
>**Script prompts you may get below:**
>
>   - **Do you expect a phyloseq object to be produced?**
>       - ${\color{green}yes}$: Choose this option if you using used a standard or custom reference sequence database.
>           - The script will look for a phyloseq object to see if your pipeline was **likely** successful.
>       - ${\color{red}no}$: Choose this option if you did not use a standard or custom reference sequence database.
>           - The script will look for a fasta file to see if your pipeline was **likely** successful.
> 
>   - **Enter the SLURM job ID to inspect logs:**
>       - This prompt will appear if the script could not locate a phyloseq object or fasta file.
>       - It will scan your SLURM output log to see if there were any samples that failed trimming or filtering. 
 >           - This pipeline is set to fail if any sample fails these steps. That way the user can get early signs that trimming or filtering parameters need to be adjusted. 
>           - Additionally, it gives the user the opportunity to record samples that truly did fail at those steps and may need to be removed from the study.
>       - If it can't identify any failed samples, you will be prompted to check your SLURM logs for errors.
>        - If you wish to ignore any failed samples, add these parameters to the file for future runs: `"/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT_NAME/params/${PROJECT_NAME}_nf-params.json"`
>          - `"ignore_failed_trimming": true`
>          - `"ignore_failed_filtering": true`
>          - If you want to add these parameter and resume your current run, be sure to run the following code block to make sure your `${PROJECT_NAME}_nf-params_expanded.json` file is updated with these parameters because the expanded *.json* file is the file the nf-core/ampliseq pipeline will use.
>```
>export PROJECT_NAME=$(cat "/group/ajfingergrp/Metabarcoding/Project_Runs/Project_IDs/$USER/current_project_name.txt")
>envsubst '$HOME $PROJECT_NAME' \
>  < "/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT_NAME/params/${PROJECT_NAME}_nf-params.json" \
>  > "/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT_NAME/params/${PROJECT_NAME}_nf-params_expanded.json"
>```
> 
>   - **Would you like to remove the FASTQ files for those samples from the study be removing them from the samplesheet and metadata?**
>       - This prompt will appear if the script identifies any samples in  your SLURM log that failed filtering or trimming.
>       - ${\color{green}yes}$: This option will remove the samples and save the removed samples to a new file for recording purposes:
>            - Samples that failed filtering and were removed can be found here: `/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT_NAME/output/Removed_Samples/Samples_Removed_Failed_Filtering.txt`
>
>       - ${\color{red}no}$: This option will not remove the samples. You will instead be prompted to review your filtering or trimming settings or pipeline configuration and rerun nf-core/ampliseq pipeline"
>

**8. BLAST Unknown ASVs:**

> Execute the following script to BLAST unassigned ASVs. 
>
>*Optionally, if you used a reference database, you can choose to retrieve your unassigned/incomplete assigned ASVs from your phyloseq object and not BLAST them.*
>   - *This is useful for folks who want their unassigned ASVs but prefer ID them using some other method than BLAST.*
>```
>"$HOME/Metabarcoding/scripts_do_not_alter/submit_retrieve_phyloseq_unassigned_asv_and_blast.sh"
>```
> **Script prompts:**
>   - **What do you want to do?**
>       - **1A** : Extract AND BLAST unassigned/incomplete assigned ASVs from phyloseq object.
>           - You can only choose this option if you used a reference sequence database.
>       - **1B** : Extract unassigned/incomplete assigned ASVs from phyloseq object (NO BLAST).
>           - You can only choose this option if you used a reference sequence database.
>       - **2** : BLAST ALL ASVs (use ...output/dada2/ASV_seqs.fasta).
>           - You can choose this option whether or not you used a custom reference database.
>   - **Enter BLAST percent identity threshold [default:97]:**
>       - Choose the % identity threshold you would like for your BLAST assignments.
>   - **Enter BLAST max target sequences [default:5]:**
>       - Choose max target sequences you want BLAST to output for each ASV.
> 
>Check your current running slurm job and get your jobID:
>```
>squeue -u $USER
>```
>Once you no longer see a running job, your pipeline is complete.
>
>Run the following shell script to check if your script was **likely** successful. 
>
>*Note: This script is not 100% effective and determining success or reason for failure. It is only designed to look for certain key output files that indicate success was likely. For unsuccessful runs, check your SLURM logs.*
>   - To view your slurm error and output logs, navigate to `/group/ajfingergrp/Metabarcoding/intermediates_logs_cache/slurm_logs/` and locate the files called `blast_asv_<jobID>.err` and `blast_asv_<jobID>.out`. 
>```
>"$HOME/Metabarcoding/scripts_do_not_alter/check_blast_run_success.sh"
>```
><details>
><summary><strong>Files exported (click here to expand).</strong></summary>
>
><br>
>
>   *Note: Files marked with a (*) were created by nf-core/ampliseq pipeline. This is just a reminder of where to find them.*
>  - `RUN_BLAST=no`:
>    - Fasta file will be saved at: `/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT_NAME/output/R/${PROJECT_NAME}_DADA2_unassigned_ASVs.fasta`
>  - `RUN_BLAST=yes`: 
>    - Raw blast results will be saved at: `/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT_NAME/output/BLAST/${PROJECT_NAME}_raw_blast_results.tsv`
>    - If option 1A was chosen:
>       - Fasta file of only unassigned ASVs will be saved at: `/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT_NAME/output/R/${PROJECT_NAME}_DADA2_unassigned_ASVs.fasta`
>       - *Fasta file of ALL ASVs can be found at: `/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT_NAME/output/dada2/ASV_seqs.fasta`
>    - If option 2 was chosen:
>       - *Fasta file of ALL ASVs can be found at: `/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT_NAME/output/dada2/ASV_seqs.fasta`
>
> </details>

**9. Clean up NCBI Blast Taxonomy:**
   
> Run the following script to auto process your raw BLAST results to output the single 'best' taxonomic rank for each assigned ASV:
>
>- Final taxa ranks are chosen based on highest percent identity (similarity), bit score (alignment quality/score), and e-value (statistical significance).
>- For tied results, this script will assign the least common taxonomic rank to the ASV.
>- Explanations for the final taxonomic assignment will be provided for each ASV.
>- Hopefully this will make parsing through and proofreading BLAST assignments much easier.
>```
>"$HOME/Metabarcoding/scripts_do_not_alter/submit_blast_cleanup.sh"
>```
>
>Check your current running slurm job and get your jobID:
>
>```
>squeue -u $USER
>```
>Once you no longer see a running job, your pipeline is complete.
>
>Run the following shell script to check if your script was **likely** successful. 
>
>*Note: This script is not 100% effective and determining success or reason for failure. It is only designed to look for certain key output files that indicate success was likely. For unsuccessful runs, check your SLURM logs.*
>   - To view your slurm error and output logs, navigate to `/group/ajfingergrp/Metabarcoding/intermediates_logs_cache/slurm_logs/` and locate the files called `blast_cleanup_<jobID>.err` and `blast_cleanup_<jobID>.out`. 
>```
>"$HOME/Metabarcoding/scripts_do_not_alter/check_blast_cleanup_success.sh"
>```
><details>
><summary><strong>Expected output files in BLAST folder (click to expand).</strong></summary>
>
><br>
>
>| File | Description |
>|------|-------------|
>| `{$PROJECT_NAME}_ncbi_taxon_rank_casche.tsv` | Simple list of all your unique final taxa and ranks. |
>| `{$PROJECT_NAME}_final_LCTR_taxonomy_with_ranks.tsv` | Most useful. Lists ASV ID, ASV sequence, taxa assignment, taxa rank, and assignment explanation for each ASV. |
>| `{$PROJECT_NAME}_final_LCTR_taxonomy.tsv` | Same as file above, but does not include ranks. This is an intermediate file the script uses to make rank assignments. |
>| `{$PROJECT_NAME}_best_taxa_per_ASV.tsv` | Raw BLAST output for only the 'best' aligment for each ASV. |
>| `{$PROJECT_NAME}_blast_taxonomy_merged.tsv` | A file containing raw BLAST output merged with taxonomic information fetched from NCBI (see file below). |
>| `{$PROJECT_NAME}_ncbi_taxonomy_results.tsv` | A file containing further taxonomic information (fetched from NCBI) for each BLAST alignment. |
></details>


**10. Review and approve BLAST taxonomic assignments:**

> Run the following shell script to review BLAST assignments and update phylseq object: 
>
>*Note: This script requires a manual review step to approve/dissaprove and change BLAST taxonomic assignments if needed.*
>
>```
>"$HOME/Metabarcoding/scripts_do_not_alter/run_review_and_update_phyloseq.sh" 
>```

>**A. When prompted, open the `"/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT_NAME/output/BLAST/Review/${PROJECT_NAME}_final_LCTR_taxonomy_with_ranks.REVIEW.xlsx"` spreadsheet.** 
> - If you have MobaXterm, simply right click the file and open with Excel. 
> - If you are using a MacOS, open your computer terminal in a separate window and use the `scp` command. This should be run on your computer, not on the cluster. After uploading the file, navigate to local directory and open the spreadsheet.
> ```
> scp [USER]@[CLUSTER].hpc.ucdavis.edu:~/[CLUSTER-DATA] local-directory
> 
> # Example to upload to current local directory: scp leighrs@farm.hpc.ucdavis.edu:"/group/ajfingergrp/Metabarcoding/Project_Runs/16Sv7/output/BLAST/Review/16Sv7_final_LCTR_taxonomy_with_ranks.REVIEW.xlsx" .
> # Example to upload to a specific local directory: scp leighrs@farm.hpc.ucdavis.edu:"/group/ajfingergrp/Metabarcoding/Project_Runs/16Sv7/output/BLAST/Review/16Sv7_final_LCTR_taxonomy_with_ranks.REVIEW.xlsx" C:\Users\Leighrs13\Metabarcoding
> ```

>**B. Manually review BLAST taxonomic assignments:**
>
><details>
>
><summary><strong>For an explanation on columns, click here to expand:</strong></summary>
>
><br>
>
> - Column A: ASV ID
> - Column B: ASV sequence
> - Columns C and D: BLAST taxonomic assignments
> - Column E: Do you approve the taxonomic assignment?
>   - blank: I approve
>   - no: I dissaprove
> - Column F: Leave a note here for your dissaproval reasoning.
> - Column G: Remove ASV from dataset (including phyloseq object)?
>   - blank: Leave ASV in dataset
>   - yes: Remove ASV from dataset
> - Columns H-O: Taxon name override columns
>   - If you disapprove of BLAST taxon assignment, you can override by specifying desired taxon names here. 
>   - You only need to fill out the ranks you want to change.
>   - If you disapprove of a BLAST taxon assignment, but do not override ANY taxon ranks then ALL ranks will be set to "unknown".
>   - Even if you approve of the BLAST assignment (Column E left blank):
>      - You can still add in common names because BLAST does not assign at that level.
>      - You can also add in the remaining taxa levels if you approve of a BLAST assignment above species level.
>        - For example, if I approve of a Cottidae (family level), I can fill in "Cottidae spp" for the genus and species level, and "Sculpin spp" for the common name.
> Column P: Explanation for BLAST taxon assignment.
>
></details>

>**C. Save edited spreadsheet (same file name) and upload to FARM:**
> - If you have MobaXterm, simply save and close the file.
> - If you are using a MacOS, open your computer terminal in a separate window and use the `scp` command. This should be run on your computer, not on the cluster.
> ```
>scp local-directory [USER]@[CLUSTER].hpc.ucdavis.edu:~/[CLUSTER-DATA] 
>
># Example to upload from local directory: scp test_final_LCTR_taxonomy_with_ranks.REVIEW.xlsx leighrs@farm.hpc.ucdavis.edu:/group/ajfingergrp/Metabarcoding/Project_Runs/16Sv7/output/BLAST/Review/ 
># Example to upload from a specific local directory: scp C:\Users\Leighrs13\Metabarcoding\test_final_LCTR_taxonomy_with_ranks.REVIEW.xlsx leighrs@farm.hpc.ucdavis.edu:/group/ajfingergrp/Metabarcoding/Project_Runs/16Sv7/output/BLAST/Review/ 
> ```

> **D. After uploading edited spreadsheet into FARM, navigate back to terminal with FARM and re-run the following code:**
> 
> ```
>"$HOME/Metabarcoding/scripts_do_not_alter/run_review_and_update_phyloseq.sh" 
> ```
> - Your phyloseq object will now be updated with these taxonomic assignments.
>    - Updated phyloseq object can be found at `"/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT_NAME/output/BLAST/Review/phyloseq_${PROJECT_NAME}_UPDATED_reviewed_taxonomy.rds"`.
> - `"/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT_NAME/output/BLAST/Review/${PROJECT_NAME}_final_LCTR_taxonomy_with_ranks.REVIEW.xlsx"` now has an updated sheet with ASVs excluded after the review process.
> - You can ignore the intermediate `${PROJECT_NAME}_reviewed_assignments.tsv` file created in the BLAST/Review folder.
>   

**11. Remove contaminant reads from ASVs:**
> Run this shell script to start decontamination process and follow on-screen prompts:
>```
>"$HOME/Metabarcoding/scripts_do_not_alter/run_GVL_metabarcoding_cleanup_main.sh" 
>```
> **Script prompts:**
>
> *Configure ASV cleanup parameters (press **Enter** to use defaults)*
>
> *NOTE: Characters are **case-sensitive**. (e.g., `Sample_or_Control` does NOT equal `sample_or_control`).
>   - **Metadata column name indicating sample/control type [Default: Sample_or_Control]:**
>       - Column name in metadata for assigning which are controls or samples.
>   - **Metadata label type for biological samples [Default: Sample]:**
>       - Label for sample rows.
>   - **Metadata label type for controls [Default: Control]:**
>       - Label for control rows.
>   - **Metadata column name assigning controls to samples [Default: Control_Assign]:**
>       - Column name in metadata for assigning which controls go to which samples.
>       -  For this column, controls are assigned a single unique ID. Samples should contain a comma-delimited list for which controls are assigned to them.
>           -  For example:
>
> | sampleID | Control_Assign | Sample_or_Control | Explanation |
> |------|-------------|-------------|-------------|
> |BROA1|1,2,4|Sample|Controls 1,2,4 need to be subtracted from this sample|
> |FLYA2|2,3,4|Sample|Controls 2,3,4 need to be subtracted from this sample|
> |BROAB|1|Control|The ID of this control is 1|
> |FLYAB|3|Control|The ID of this control is 2|
> |EXT1|2|Control|The ID of this control is 3|
> |PCR1|4|Control|The ID of this control is 4|
>
>   - **Sample ASV threshold [Default: 0.0005]:**
>       - Defines per-sample ASV threshold to be applied. You can define as a proportion (e.g., 0.01) or an absolute read count (e.g., 10).
>       - Removes ASVs that do not reach a minimum read count.
>       - *Example 1:* Sample threshold = 0.0005 = 0.05% of reads per sample = 
>           - Sample A has 100,000 reads -> This threshold will remove 50 reads from each ASV (i.e., minimum 50 reads per ASV to keep that ASV).
>            - Sample B has 10,000 reads -> This threshold will remove 5 reads from each ASV (i.e., minimum 5 reads per ASV to keep that ASV).
>       - *Example 2:* Sample threshold = 10
>           - Sample A (sample's total reads don't matter)  <- this threshold would remove 10 reads from each ASV (i.e., minimum 10 reads per ASV to keep that ASV).
>   - **Minimum sequencing depth threshold [Default: 0.0005]:**
>       - Defines minimum sequencing depth for each sample. You can define as a proportion (e.g., 0.01) or an absolute read count (e.g., 10).
>       - Removes samples that do not reach a minimum read count.
>       - *Example 1:* Min seq depth threshold  = 0.0001 = 0.01% of total reads
>           - Total reads in dataset = 10,000,000 -> This threshold would remove any sample with fewer than 1,000 reads.
>       - *Example 2:* Min seq depth threshold = 10 
>           - Total reads in dataset = Doesn't matter -> This threshold would remove any sample with fewer than 10 reads.
>
> **You final updated, and cleaned phyloseq object can be found here: `"/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT_RUN/output/ASV_cleanup_output/dada2_phyloseq_cleaned.rds"`**
><details>
><summary><strong>Other expected output files in ASV_cleanup_output folder (click to expand).</strong></summary>
>
><br>
>
>| File | Description |
>|------|-------------|
>| `1_{$PROJECT_NAME}_decontam_applied.xlsx` | An Excel spreadsheet that contains (1) ASVs abundances for controls and sample before/after control reads were removed from them, (2) decontamination metrics, (3) assigned controls for each sample, and (4) a summary. |
>| `2_{$PROJECT_NAME}_species_detections_before_after_decontam.xlsx` | An Excel spreadsheet showing a presence/absence matrix for species before and after control decontaminations. There is also a tab that shows which (if any) species were removed from samples after control decontamination. |
>| `3_{$PROJECT_NAME}_sample_threshold_applied.xlsx` | An Excel spreadsheet that contains (1) ASVs abundances for samples before/after the sample threshold was applied, (2) threshold metrics, (3) assigned controls for each sample, (4) a summary, (5) ASVs that were removed from the whole study, and (6) which ASVs were removed from which samples (some of these ASVs will overlap with ASVs removed from study). |
>| `4_{$PROJECT_NAME}_species_detections_before_after_sample_threshold.xlsx` | An Excel spreadsheet showing a presence/absence matrix for species before and after sample threshold was applied. There is also a tab that shows which (if any) species were removed from samples after threshold. |
>| `5_{$PROJECT_NAME}_min_seq_depth_threshold_applied.xlsx` | An Excel spreadsheet that contains (1) ASVs abundances for samples before/after the min depth threshold was applied, (2) threshold metrics, (3) ASVs and samples that were removed from the whole study after min depth threshold, and (4) which ASVs were removed from which sample after min depth threshold (some of these ASVs will overlap with ASVs removed from study). |
>| `6_{$PROJECT_NAME}_species_detections_before_after_total_threshold.xlsx` | An Excel spreadsheet showing a presence/absence matrix for species before and after min seq threshold was applied. There is also a tab that shows which (if any) species were removed from samples after threshold. |
></details>
>

**10. Download your output:**

> It is recommended to download your project directory to archive (usually on an external drive, cloud service, etc.)
>   - You can also choose to archive your project into the group directory:
>
> *NOTE: This script will submit an sbatch run.*
>```
>"$HOME/Metabarcoding/scripts_do_not_alter/archive_metabarcoding_project.sh"
>```
>
>   - To download your project directory to your local directory:
>       - If you have MobaXterm, simply click on your `${PROJECT_NAME}` folder and export.
>       - If you are using a MacOS, open your computer terminal in a separate window and use the `scp` command. This should be run on your computer, not on the cluster.
> ```
> scp -r [USER]@[CLUSTER].hpc.ucdavis.edu:~/[CLUSTER-DATA] local-directory
>
> # Example to upload to a specific local directory:
>  scp -r leighrs@farm.hpc.ucdavis.edu:/group/ajfingergrp/Metabarcoding/Project_Runs/16Sv7/ D:\UCD_Bioinformatics\Metabarcoding\
> ```
>   - This folder will be quite large. I recommend downloading directly to an external hard drive. Or only locally downloading a few folders/files. See example below for only downloading the phyloseq object:
> 
>  - If you only want to download your final phyloseq object:
>     - `"/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT_NAME/output/ASV_cleanup_output/dada2_phyloseq_cleaned.rds"`
>     - Use the `scp` command to download to your local system.
>     - Because you will **not** be on the FARM when using this command, remember to manually fill in your `$PROJECT_NAME` variable.
</details>

---

<details>
<summary><h2>Set-up for using phyloseq objects: (WIP)</h2></summary>
  
<br>

**1. Download base R:**

> Navigate to the (The Comprehensive R Archive Network)[https://ftp.osuosl.org/pub/cran/] to download and install R.
>  - For Windows: choose the option to (install R for the first time)[https://ftp.osuosl.org/pub/cran/].
>  - For Mac: choose the option (R-4.5.2-arm64.pkg)[https://ftp.osuosl.org/pub/cran/bin/macosx/big-sur-arm64/base/R-4.5.2-arm64.pkg] for Apple silicon macs or (R-4.5.2-x86_64.pkg)[https://ftp.osuosl.org/pub/cran/bin/macosx/big-sur-x86_64/base/R-4.5.2-x86_64.pkg] for Intel Macs.

**2. Download RStudio Desktop:**

> Navigate to the (Posit RStudio Desktop site)[https://posit.co/download/rstudio-desktop/] to download and install RStudio.
>  - (For Windows)[https://download1.rstudio.org/electron/windows/RStudio-2026.01.0-392.exe].
>  - (For Mac)[https://download1.rstudio.org/electron/macos/RStudio-2026.01.0-392.dmg].

**2. Download Rtools (for Windows only):**

> Navigate to the (RTools: Toolchains for building R and R packages from source on Windows)[https://cran.rstudio.com/bin/windows/Rtools/] to download.

</details>































































