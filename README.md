# Metabarcoding Directory Setup & Pipeline

![GitHub Repo Size](https://img.shields.io/github/repo-size/Leighrs/Metabarcoding)
![License](https://img.shields.io/github/license/Leighrs/Metabarcoding)
![Last Commit](https://img.shields.io/github/last-commit/Leighrs/Metabarcoding)

Welcome to the **Metabarcoding** repository for the **Genomic Variation Laboratory**!  
This repository helps lab members quickly set up a standardized directory structure on the HPC for running metabarcoding analyses using the **nf-core/ampliseq pipeline**.

---

## Repository Overview

This repository contains scripts and configuration files to:

1. Set up your project directory on the HPC.
2. Provide example files (samplesheets, metadata, and RSD sequences) for testing and reference.
3. Run the nf-core/ampliseq pipeline on your data.
4. Perform BLAST searches for unknown ASVs.
5. Update and download the NCBI core nucleotide database.

### Current Files

| File | Description |
|------|-------------|
| `nf-params.json` | Parameter file for the nf-core/ampliseq pipeline. Customize for your project. |
| `setup_metabarcoding_directory.sh` | Shell script to create your project directory with example samplesheets, metadata, and RSD files. |
| `update_blast_db.slurm` | SLURM batch script to download/update the NCBI core nucleotide database. |
| `blast_asv.slurm` | SLURM batch script to BLAST unknown ASVs. |
| `run_ampliseq.slurm` | SLURM batch script to execute the nf-core/ampliseq pipeline. |

> More scripts will be added over time to streamline additional steps.

---

## Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/Leighrs/Metabarcoding.git
cd Metabarcoding
```
### 2. Set Up Your Project Directory on HPC
```bash
bash setup_metabarcoding_directory.sh
```
- Your projectdirectory structure will look like:
```bash
Metabarcoding/
└── <project_name>/
    ├── input/
    │   ├── fastq/
    │   ├── Example_samplesheet.txt
    │   ├── Example_metadata.txt
    │   └── Example_RSD.txt
    └── output/
        └── intermediates_logs_cache/
            └── singularity/
```
### 3. Update the NCBI Database (Optional)
```bash
sbatch update_blast_db.slurm
```
### 4. Run the nf-core/ampliseq Pipeline
```bash
sbatch run_ampliseq.slurm
```
### 5. BLAST Unknown ASVs (Optional)
```bash
sbatch blast_asv.slurm
```
