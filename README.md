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
| `nf-params_with_standardized_RSD.json` | Contents of this parameter file for the nf-core/ampliseq pipeline will be uploaded to project directory if user specifies the use of a standardized (included in ampliseq pipeline) RSD. Customize for your project. |
| `setup_metabarcoding_directory.sh` | Shell script to create your project directory with example samplesheets, metadata, and RSD files. |
| `update_blast_db.slurm` | SLURM batch script to download/update the NCBI core nucleotide database. |
| `blast_asv.slurm` | SLURM batch script to BLAST unknown ASVs. |
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
>    - *Where do you want to store FASTQ files?:* ${\color{green}1}$

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
>"$HOME/Metabarcoding/$PROJECT_NAME/scripts/${PROJECT_NAME}_generate_samplesheet_table.sh" 
>```

>- **When prompted:**
>    - *Did you sequence samples using multiple sequencing runs?:* ${\color{red}no}$

**5. Edit Run Parameters.**

> Open the parameter file for the nf-core/ampliseq pipeline:
> 
> - The `${PROJECT_NAME}_nf-params.json` file contains all the parameters needed to run the nf-core/ampliseq workflow for your specific project.
> - Edit this file so that the input paths, primer sequences, and filtering settings match your dataset.
>
>```
>PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")
>nano $HOME/Metabarcoding/$PROJECT_NAME/scripts/${PROJECT_NAME}_nf-params.json
>```
> **Replace these parameters for the test data using the following information:**
> 
> Nano files are little tricky to work with. Here are some tips:
>
>- First, highlight the entire script:
>  - Go to the top of the script using `Ctrl` + `_`, then type 1, press **Enter**.
>  - Then, start selecting text using `Ctrl` + `^`.
>  - Highlight the rest of the script using `Ctrl` + `_`, then type 100, press **Enter**.
>  - Everything should now be selected.
>- Delete all the text in the scriptusing `Ctrl` + `K`.
>- Copy the new text below, and paste into the empty script using a right-click to paste. Some terminals may require `Ctrl` + `Shift` + `V`.
>- Exit the script using `Ctrl` + `X`. Then `Y` to save. Press **Enter**.
>
>```
>{
>    "input": "$HOME/Metabarcoding/$PROJECT_NAME/input/${PROJECT_NAME}_samplesheet.txt",
>    "FW_primer": "GTCGGTAAAACTCGTGCCAGC",
>    "RV_primer": "CATAGTGGGGTATCTAATCCCAGTTTG",
>
>    "metadata": "$HOME/Metabarcoding/$PROJECT_NAME/input/${PROJECT_NAME}_metadata.txt",
>
>    "seed": 13,
>
>    "ignore_failed_trimming": true,
>    "ignore_failed_filtering": true,
>
>    "trunclenf": 120,
>    "trunclenr": 120,
>
>    "dada_ref_taxonomy": false,
>    "skip_dada_addspecies": true,
>    "dada_ref_tax_custom": "$HOME/Metabarcoding/$PROJECT_NAME/input/${PROJECT_NAME}_12S_RSD.txt",
>    "dada_min_boot": 80,
>    "dada_assign_taxlevels": "Kingdom,Phylum,Class,Order,Family,Genus,Species,Common",
>
>    "exclude_taxa": "none",
>
>    "skip_qiime": true,
>    "skip_barrnap": true,
>    "skip_dada_addspecies": true,
>    "skip_tse": true
>}
>
>```
>
> JSON files can't expand environment variables, like `$HOME` or `$PROJECT_NAME`. Create a file with an expanded variable unique to your system.
> 
>```
>export PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")
>envsubst '$HOME $PROJECT_NAME' \
>  < "$HOME/Metabarcoding/$PROJECT_NAME/scripts/${PROJECT_NAME}_nf-params.json" \
>  > "$HOME/Metabarcoding/$PROJECT_NAME/scripts/${PROJECT_NAME}_nf-params_expanded.json"
>```

**6. Run the nf-core/ampliseq Pipeline:** 

> Ensure you are in your home directory and run the following shell script.
>
>```
>cd ~
>PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")
>sbatch "$HOME/Metabarcoding/$PROJECT_NAME/scripts/${PROJECT_NAME}_run_nf-core_ampliseq.slurm"
>```

**7. BLAST Unknown ASVs:**

> To BLAST your ASVs that did not assign during the nf-core/ampliseq pipeline, run the following code:
>
>```bash
>cd ~
>PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")
>RUN_BLAST=yes sbatch "$HOME/Metabarcoding/$PROJECT_NAME/scripts/${PROJECT_NAME}_retrieve_phyloseq_unassigned_ASVs.slurm"
>```
>  - `RUN_BLAST=no` will extract your unassigned ASVs into a fasta file for you to see, but will not BLAST them.
>  - *NOTE: When working with your real data, this code chunk will only work if you used a custom reference sequence database (RSD). If you did not use a custom RSD, a separate code chunk will be provided.*
 
**8. Clean up NCBI Blast Taxonomy:**
   
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
>sbatch "$HOME/Metabarcoding/$PROJECT_NAME/scripts/${PROJECT_NAME}_ncbi_taxonomy.slurm" option2
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

**9. Review and approve BLAST taxonomic assignments:**

> This script requires a manual review step to approve/dissaprove and change BLAST taxonomic assignments if needed.
>
>Start an interactive shell:
>```
>srun --account=millermrgrp \
>     --partition=bmh \
>     --ntasks=1 \
>     --cpus-per-task=1 \
>     --mem=32G \
>     --time=01:30:00 \
>     --pty bash
>```
>Then, run shell script to review BLAST assignments and update phylseq object:
>```
>cd ~
>PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")
>"$HOME/Metabarcoding/$PROJECT_NAME/scripts/${PROJECT_NAME}_run_review_and_update_phyloseq.sh" 
>```

>**A. When prompted, open the `${PROJECT_NAME}_final_LCTR_taxonomy_with_ranks.REVIEW.xlsx` spreadsheet.** 
> - If you have MobaXterm, simply right click the file and open with Excel. 
> - If you are using a MacOS, open your computer terminal in a separate window and use the `scp` command. This should be run on your computer, not on the cluster. After uploading the file, navigate to local directory and open the spreadsheet.
> ```
> scp -r [USER]@[CLUSTER].hpc.ucdavis.edu:~/[CLUSTER-DATA] local-directory
> 
> # Example to upload to current local directory: scp leighrs@farm.hpc.ucdavis.edu:/home/leighrs/Metabarcoding/test/output/BLAST/test_final_LCTR_taxonomy_with_ranks.REVIEW.xlsx .
> # Example to upload to a specific local directory: scp leighrs@farm.hpc.ucdavis.edu:/home/leighrs/Metabarcoding/test/output/BLAST/test_final_LCTR_taxonomy_with_ranks.REVIEW.xlsx C:\Users\Leighrs13\Metabarcoding
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
>   - Select "no" for E column to disapprove of the BLAST assignment.
>   - For the dissapproval reasoning in column F: 
>     - "I want to override some taxon name ranks". 
>   - Fill in the new taxon ranks:
>        - Column K: Cyprinodontiformes
>        - Column L: Fundulidae
>        - Column M: Lucania
>        - Column N: Lucania spp
>        - Column O: Killifish spp

>**C. Save edited spreadsheet (same file name) and upload to FARM:**
> - If you have MobaXterm, simply save and close the file.
> - If you are using a MacOS, open your computer terminal in a separate window and use the `scp` command. This should be run on your computer, not on the cluster.
> ```
>scp -r local-directory [USER]@[CLUSTER].hpc.ucdavis.edu:~/[CLUSTER-DATA] 
>
># Example to upload from local directory: scp test_final_LCTR_taxonomy_with_ranks.REVIEW.xlsx leighrs@farm.hpc.ucdavis.edu:/home/leighrs/Metabarcoding/test/output/BLAST/ 
># Example to upload from a specific local directory: scp C:\Users\Leighrs13\Metabarcoding\test_final_LCTR_taxonomy_with_ranks.REVIEW.xlsx leighrs@farm.hpc.ucdavis.edu:/home/leighrs/Metabarcoding/test/output/BLAST/ 
> ```

> **D. After uploading edited spreadsheet into FARM, navigate back to terminal with FARM running your interactive shell and re-run the following code:**
> 
> If your interactive shell has ended, restart it using the  `srun` code above.
> ```
> cd ~
>PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")
>"$HOME/Metabarcoding/$PROJECT_NAME/scripts/${PROJECT_NAME}_run_review_and_update_phyloseq.sh" 
> ```
> - Your phyloseq object will now be updated with these taxonomic assignments.
> - You can ignore the intermediate `test_reviewed_assignments.tsv` file created in the BLAST folder.
>   
>**Finally, exit from your interactive shell:**
>```
>exit
>```

**10. Remove contaminant reads from ASVs:**

>Start an interactive shell:
>```
>srun --account=millermrgrp \
>     --partition=bmh \
>     --ntasks=1 \
>     --cpus-per-task=1 \
>     --mem=32G \
>     --time=01:30:00 \
>     --pty bash
>```
>>
>Define label parameters:
>```
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
>export SAMPLE_THRES=0.0005
>export MIN_DEPTH_THRES=10
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
>"$HOME/Metabarcoding/$PROJECT_NAME/scripts/${PROJECT_NAME}_run_GVL_metabarcoding_cleanup_main.sh" 
>```
>
>**Finally, exit from your interactive shell:**
>```
>conda exit
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

> Ensure you are in your home directory and execute a shell script that will set up a project directory for you.
>
>```
>cd ~
>./Metabarcoding/scripts_do_not_alter/setup_metabarcoding_directory.sh
>```
>- **When prompted:**
>    - *Enter project name:* 
>    - *Reference database choice:* 
>    - *Where do you want to store FASTQ files?:* 

**3A. Import fastq files:**

> If storing your fastq files on group storage (recommended), copy fastq files to the subfolder (`${PROJECT_NAME}_fastq_YYYYMMDD`) created for your project:
>  - If you have MobaXterm, simply drag/drop or copy/paste into `/group/ajfingergrp/Metabarcoding/fastq_storage/${PROJECT_NAME}_fastq_YYYYMMDD`.
>  - If you are using a Mac, use the  `scp` command to transfer files:
> ```
>scp -r local-directory [USER]@[CLUSTER].hpc.ucdavis.edu:~/[CLUSTER-DATA] 
>
># Example to upload from local directory: scp "C:\Bioinformatics\12S_Fastq_251106\." leighrs@farm.hpc.ucdavis.edu: "/group/ajfingergrp/Metabarcoding/fastq_storage/12S_fastq_20260127/"
> ```
> If storing your fastq files on home storage, copy fastq files to the subfolder (`fastq`) created for your project:
>  - If you have MobaXterm, simply drag/drop or copy/paste into `$HOME/Metabarcoding/${PROJECT_NAME}/input/fastq/`.
>  - If you are using a Mac, use the  `scp` command to transfer files:
> ```
>scp -r local-directory [USER]@[CLUSTER].hpc.ucdavis.edu:~/[CLUSTER-DATA] 
>
># Example to upload from local directory: scp "C:\Bioinformatics\12S_Fastq_251106\." leighrs@farm.hpc.ucdavis.edu: "/home/leighrs/Metabarcoding/12S/input/fastq/"
> ```

**3B. Import metadata:**

> Copy metadata to the subfolder (`input`) created for your project:
>  - If you have MobaXterm, simply drag/drop or copy/paste into `$HOME/Metabarcoding/${PROJECT_NAME}/input/`.
>  - If you are using a Mac, use the  `scp` command to transfer files:
> ```
>scp local-directory path to metadata [USER]@[CLUSTER].hpc.ucdavis.edu:~/[CLUSTER-DATA] 
>
># Example to upload from local directory: scp "C:\Bioinformatics\12S_metadata.txt" leighrs@farm.hpc.ucdavis.edu:/home/leighrs/Metabarcoding/12S/input/
> ```
>  - Rules:
>    - Needs to be a tab-deliminated text file or a .tsv file.
>    - First column is labeled "ID" for your sample IDs. **Make sure these IDs match the sample IDs in your samplesheet you just made.**
>    - If you wish to use a decontamination protocol later, add a column called "Control_Assign" to assign which controls are paired with which samples.
>      - For example:
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

**3C. Import custom reference sequence database (optional):**

> Copy metadata to the subfolder (`input`) created for your project:
>  - If you have MobaXterm, simply drag/drop or copy/paste into `$HOME/Metabarcoding/${PROJECT_NAME}/input/`.
>  - If you are using a Mac, use the  `scp` command to transfer files:
> ```
>scp local-directory path to RSD [USER]@[CLUSTER].hpc.ucdavis.edu:~/[CLUSTER-DATA] 
>
># Example to upload from local directory: scp "C:\Bioinformatics\12S_RSD.txt" leighrs@farm.hpc.ucdavis.edu:/home/leighrs/Metabarcoding/12S/input/
> ```
>  - Rules:
>    - There is an example RSD .txt file found in your project input folder.
>    - Needs to be a tab-deliminated text file or a .tsv file.
>  To view the example RSD txt, run the following code:
>```
>cd ~
>PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")
>nano $HOME/Metabarcoding/$PROJECT_NAME/input/Example_RSD.txt
>```

**4. Generate a samplesheet file.**

> The samplesheet is required for the pipeline to locate you fastq files.
> Ensure you are in your home directory and run the following shell script.
>
> *This script will autopopulate the PATHs for each of your fastq files, extrapolate sample names from those files, and prompt you to specify how many metabarcoding runs these samples were sequenced in.*
>
>```
>cd ~
>PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")
>"$HOME/Metabarcoding/$PROJECT_NAME/scripts/${PROJECT_NAME}_generate_samplesheet_table.sh" 
>```
>
>- **When prompted:**
>    - *Did you sequence samples using multiple sequencing runs?:* ${\color{green}yes}$ or ${\color{red}no}$
>      - If you answer ${\color{red}no}$: All samples will be assigned to a single run "A"
>      - If you answer ${\color{green}yes}$: Sequencing run ID will not be assigned on the samplesheet. You must go into the samplesheet and manually assign sequence IDs to the last column for each sample. Each sequencing run needs to be assigned a unique letter (e.g., A, B, C, ...).
>     
> The script's default is to extrapolate sample names from the forward reads (R1) using the first two fields of the `_R1_001.fastq.gz` file names separated by and underscore ("_").
> 
> For example:
> 
>        File name: B12A1_02_4_S14_L001_R1_001.fastq.gz  ->  Sample ID: B12A1_02
>
><details>
>
><summary><strong>If you wish to extrapolate a different part of the file name or if your fastq files have a different file name ending, click to expand:</strong></summary>
>
><br>
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
></details>

**5. Edit Run Parameters.**

> Open the parameter file for the nf-core/ampliseq pipeline:
> 
> - The `${PROJECT_NAME}_nf-params.json` file contains all the parameters needed to run the nf-core/ampliseq workflow for your specific project.
> - Edit this file so that the input paths, primer sequences, and filtering settings match your dataset.
>
>```
>PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")
>nano $HOME/Metabarcoding/$PROJECT_NAME/scripts/${PROJECT_NAME}_nf-params.json
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
>export PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")
>envsubst '$HOME $PROJECT_NAME' \
>  < "$HOME/Metabarcoding/$PROJECT_NAME/scripts/${PROJECT_NAME}_nf-params.json" \
>  > "$HOME/Metabarcoding/$PROJECT_NAME/scripts/${PROJECT_NAME}_nf-params_expanded.json"
>```

**6. Run the nf-core/ampliseq Pipeline:** 

> Ensure you are in your home directory and run the following shell script.
>
>```
>cd ~
>PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")
>sbatch "$HOME/Metabarcoding/$PROJECT_NAME/scripts/${PROJECT_NAME}_run_nf-core_ampliseq.slurm"
>```

**7. BLAST Unknown ASVs:**

>Set your percent identity threshold and the max number of BLAST hits reported:
>  - *If these environmental variables are not exported, the script will default to 97% identity and 5 hits.*
>```
>export BLAST_PERC_IDENTITY=97
>export BLAST_MAX_TARGET_SEQS=5
>```
>To BLAST your entire .fasta file created from the nf-core/ampliseq pipeline, run the following code:
>
>-  If you did not include a custom reference sequence database, choose this option.
>
>```bash
>cd ~
>PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")
>sbatch "$HOME/Metabarcoding/$PROJECT_NAME/scripts/${PROJECT_NAME}_blast_asv.slurm"
>```
>
>If you included a custom reference sequence database (RSD), you can instead BLAST only the ASVs that did not receive taxonomic assignments or only received an incomplete assignment:
>- Do not use this option if you did not use a custom RSD. This option requires pulling data from a phyloseq object, which is only generated for those you used an RSD.
>
>```bash
>cd ~
>PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")
>RUN_BLAST=yes sbatch "$HOME/Metabarcoding/$PROJECT_NAME/scripts/${PROJECT_NAME}_retrieve_phyloseq_unassigned_ASVs.slurm"
>```
>  - If you only wish to retrieve your unassigned (or incomplete assigned) ASVs and not BLAST them, change to `RUN_BLAST=no`.
>    - Fasta file will be saved at: `$HOME/Metabarcoding/$PROJECT_NAME/output/R/${PROJECT_NAME}_DADA2_unassigned_ASVs.fasta`
>  - If you did use BLAST (`RUN_BLAST=yes`), you will get the following files:
>    - `$HOME/Metabarcoding/$PROJECT_NAME/output/R/${PROJECT_NAME}_DADA2_unassigned_ASVs.fasta`
>    - `$HOME/Metabarcoding/$PROJECT_NAME/output/BLAST/${PROJECT_NAME}_raw_blast_results_from_phyloseq_obj.tsv`
 
**8. Clean up NCBI Blast Taxonomy:**
   
> This script will auto process your raw BLAST output to output the single 'best' taxonomic rank for each assigned ASV:
>
>- Final taxa ranks are chosen based on highest percent identity (similarity), bit score (alignment quality/score), and e-value (statistical significance).
>- For tied results, this script will assign the least common taxonomic rank to the ASV.
>- Explanations for the final taxonomic assignment will be provided for each ASV.
>- Hopefully this will make parsing through and proofreading BLAST assignments much easier.
>
> If you did NOT use a custom RSD, run this code chunk:
>   - NOTE: Make sure you metadata file name is correct.
>```bash
>cd ~
>PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")
>
># default metadata path (user may override)
>export METADATA_TSV="${PROJECT_DIR}/output/input/${PROJECT_NAME}_metadata.txt"
>
> # Do not alter these below
>export ASV_TABLE_TSV="${PROJECT_DIR}/output/dada2/DADA2_table.tsv"
>export ASV_FASTA="${PROJECT_DIR}/output/dada2/ASV_seqs.fasta"
>sbatch "$HOME/Metabarcoding/$PROJECT_NAME/scripts/${PROJECT_NAME}_ncbi_taxonomy.slurm" option1
>```
> If you did NOT use a custom RSD, run this code chunk:
>```bash
>cd ~
>PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")
>sbatch "$HOME/Metabarcoding/$PROJECT_NAME/scripts/${PROJECT_NAME}_ncbi_taxonomy.slurm" option2
>```
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

**9. Review and approve BLAST taxonomic assignments:**

> This script requires a manual review step to approve/dissaprove and change BLAST taxonomic assignments if needed.
>
>Start an interactive shell:
>```
>srun --account=millermrgrp \
>     --partition=bmh \
>     --ntasks=1 \
>     --cpus-per-task=1 \
>     --mem=32G \
>     --time=01:30:00 \
>     --pty bash
>```
>Then, run shell script to review BLAST assignments and update phylseq object:
>```
>cd ~
>PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")
>"$HOME/Metabarcoding/$PROJECT_NAME/scripts/${PROJECT_NAME}_run_review_and_update_phyloseq.sh" 
>```

>**A. When prompted, open the `${PROJECT_NAME}_final_LCTR_taxonomy_with_ranks.REVIEW.xlsx` spreadsheet.** 
> - If you have MobaXterm, simply right click the file and open with Excel. 
> - If you are using a MacOS, open your computer terminal in a separate window and use the `scp` command. This should be run on your computer, not on the cluster. After uploading the file, navigate to local directory and open the spreadsheet.
> ```
> scp [USER]@[CLUSTER].hpc.ucdavis.edu:~/[CLUSTER-DATA] local-directory
> 
> # Example to upload to current local directory: scp leighrs@farm.hpc.ucdavis.edu:/home/leighrs/Metabarcoding/test/output/BLAST/test_final_LCTR_taxonomy_with_ranks.REVIEW.xlsx .
> # Example to upload to a specific local directory: scp leighrs@farm.hpc.ucdavis.edu:/home/leighrs/Metabarcoding/test/output/BLAST/test_final_LCTR_taxonomy_with_ranks.REVIEW.xlsx C:\Users\Leighrs13\Metabarcoding
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
># Example to upload from local directory: scp test_final_LCTR_taxonomy_with_ranks.REVIEW.xlsx leighrs@farm.hpc.ucdavis.edu:/home/leighrs/Metabarcoding/test/output/BLAST/ 
># Example to upload from a specific local directory: scp C:\Users\Leighrs13\Metabarcoding\test_final_LCTR_taxonomy_with_ranks.REVIEW.xlsx leighrs@farm.hpc.ucdavis.edu:/home/leighrs/Metabarcoding/test/output/BLAST/ 
> ```

> **D. After uploading edited spreadsheet into FARM, navigate back to terminal with FARM running your interactive shell and re-run the following code:**
> 
> If your interactive shell has ended, restart it using the  `srun` code above.
> ```
> cd ~
>PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")
>"$HOME/Metabarcoding/$PROJECT_NAME/scripts/${PROJECT_NAME}_run_review_and_update_phyloseq.sh" 
> ```
> - Your phyloseq object will now be updated with these taxonomic assignments.
>    - Updated phyloseq object can be found at `$HOME/Metabarcoding/$PROJECT_NAME/output/BLAST/Review/phyloseq_${PROJECT_NAME}_UPDATED_reviewed_taxonomy.rds`.
> - `$HOME/Metabarcoding/${PROJECT_NAME}/output/BLAST/Review/{PROJECT_NAME}_final_LCTR_taxonomy_with_ranks.REVIEW.xlsx` now has an updated sheet with ASVs excluded after the review process.
> - You can ignore the intermediate `${PROJECT_NAME}_reviewed_assignments.tsv` file created in the BLAST folder.
>   
>**Finally, exit from your interactive shell:**
>```
>exit
>```

**10. Remove contaminant reads from ASVs:**

>
>Start an interactive shell:
>```
>srun --account=millermrgrp \
>     --partition=bmh \
>     --ntasks=1 \
>     --cpus-per-task=1 \
>     --mem=32G \
>     --time=01:30:00 \
>     --pty bash
>```
>
>Define label parameters:
>```
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
>"$HOME/Metabarcoding/$PROJECT_NAME/scripts/${PROJECT_NAME}_run_GVL_metabarcoding_cleanup_main.sh" 
>```
>
>**Finally, exit from your interactive shell:**
>```
>exit
>```

**10. Download your output:**

> It is recommended to download your project directory to archive (usually on an external drive, the group directory, cloud service, etc.)
> To download your project directory:
>   - If you have MobaXterm, simply click on your `${PROJECT_NAME}` folder and export.
>   - If you are using a MacOS, open your computer terminal in a separate window and use the `scp` command. This should be run on your computer, not on the cluster.
> ```
> scp -r [USER]@[CLUSTER].hpc.ucdavis.edu:~/[CLUSTER-DATA] local-directory
>
> # Example to upload to a specific local directory:
>   ## I recommend renaming metabarcoding folder with something unique (rename XXX): scp -r leighrs@farm.hpc.ucdavis.edu:/home/leighrs/Metabarcoding/ D:\UCD_Bioinformatics\Metabarcoding_XXX\
> ```
>   - This folder will be quite large, especially if you have your fastq files stored in it instead of the group directory. I recommend downloading directly to an external hard drive. Or only locally downloading a few folders/files. See example below for only downloading the phyloseq object:
> 
>  - If you only want to download your final phyloseq object:
>     - `"$HOME/Metabarcoding/$PROJECT_NAME/output/ASV_cleanup_output/dada2_phyloseq_cleaned.rds"`
>     - Use the `scp` command to download to your local system.
>     - Because you will **not** be on the FARM when using this command, remember to manually fill in your `$HOME` and `$PROJECT_NAME` variables.
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



































