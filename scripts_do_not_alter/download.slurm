#!/bin/bash
#SBATCH --account=millermrgrp
#SBATCH --partition=bmh
#SBATCH --job-name=blast_cleanup
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=05:30:00

rsync -vrt bioshare@bioshare.bioinformatics.ucdavis.edu:/rxtdiuwkw6mhqdh/20260325_AV100006_aviti0842B/ /group/ajfingergrp/Metabarcoding/fastq_storage/220260325_AV100006_aviti0842B/
