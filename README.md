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
|`review_and_update_phyloseq.R`| This script helps the user to review their BLAST assignments and reimport new assignments back into their phylseq object.
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
>    "outdir": "$HOME/Metabarcoding/$PROJECT_NAME/output/",
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
>   - NOTE: The `assignTaxonomy()` function of DADA2 uses a naive Bayesian classifer with bootstrapping. This random subsampling of k-mers can lead to slightly different assignments for the same ASV across different runs. Using `set.seed()` before running ensures reproducibility, but there is a bug in the script that is causing it to no longer recognize the seed. So some runs may be slightly different in their taxonomic assignments. I am troubleshooting this.
> -----
>   - Select "no" for each row in the E column to disapprove of all BLAST assignments.
>   - For the dissapproval reasoning in column F: 
>     - For each cell, "I want to override taxon naming for each of their species and common name ranks". 
>   - Fill in the new taxon ranks:
>     - If you see an Oncorhynchus ASV, add:
>        - `Oncorhynchus mykiss` to column N and 'Rainbow trout` to column O.
>     - If you see an Lucania ASV, add:
>        - `Lucania spp` to column N and 'Killifish spp` to column O.
>     - If you see an Cottidae ASV, add:
>        - `Cottidae spp` to column N and 'Sculpin spp` to column O.
>     - If you see an Cyprinidae ASV, add:
>        - `Lavinia exilicauda` to column N and 'Hitch` to column O.

>**C. Save edited spreadsheet (same file name) and upload to FARM:**
> - If you have MobaXterm, simply save and close the file.
> - If you are using a MacOS, open your computer terminal in a separate window and use the `scp` command. This should be run on your computer, not on the cluster.
> ```
>scp -r local-directory [USER]@[CLUSTER].hpc.ucdavis.edu:~/[CLUSTER-DATA] 
>
># Example to upload from local directory: scp test_final_LCTR_taxonomy_with_ranks.REVIEW.xlsx leighrs@farm.hpc.ucdavis.edu:/home/leighrs/Metabarcoding/test/output/BLAST/ 
># Example to upload from a specific local directory: scp C:\Users\Leighrs13\Metabarcoding\test_final_LCTR_taxonomy_with_ranks.REVIEW.xlsx leighrs@farm.hpc.ucdavis.edu:/home/leighrs/Metabarcoding/test/output/BLAST/ 
> ```

> **D. After uploading edited spreadsheet into FARM, navigate back to terminal with FARM running your conda environment, and re-run the interactive shell and script code to continue running the script.**
> - Your phyloseq object will now be updated with these taxonomic assignments.
> - You can ignore the intermediate `test_reviewed_assignments.tsv` file created in the BLAST folder.
>   
>**Finally, exit from your conda environment:**
>```
>conda deactivate
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
>**Finally, exit from your conda environment:**
>```
>conda deactivate
>```
</details>

---

















