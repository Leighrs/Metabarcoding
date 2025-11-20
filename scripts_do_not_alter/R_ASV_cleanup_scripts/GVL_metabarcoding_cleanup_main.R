# Master script to run all ASV cleanup steps

#================================
# NOTE: Only alter "User-defined parameters" below.
#================================

# -------------------------------
# Load required libraries
# -------------------------------

# Load here package for building paths relative to your project root
if (!requireNamespace("here", quietly = TRUE)) {
  install.packages("here")
}
library(here)

# Load phyloseq package for microbiome data handling
if (!requireNamespace("phyloseq", quietly = TRUE)) {
  install.packages("phyloseq")
}
library(phyloseq)

# Load stringr package for string manipulation
if (!requireNamespace("stringr", quietly = TRUE)) {
  install.packages("stringr")
}
library(stringr)

# Load writexl package to export Excel files
if (!requireNamespace("writexl", quietly = TRUE)) {
  install.packages("writexl")
}
library(writexl)

# Load openxlsx for Excel file creation and formatting
if (!requireNamespace("openxlsx", quietly = TRUE)) {
  install.packages("openxlsx")
}
library(openxlsx)

# Load readxl for reading Excel files
if (!requireNamespace("readxl", quietly = TRUE)) {
  install.packages("readxl")
}
library(readxl)

# Load dplyr for data manipulation functions like sapply, %>%, etc.
if (!requireNamespace("dplyr", quietly = TRUE)) {
  install.packages("dplyr")
}
library(dplyr)

# ===============================
# User-defined parameters (Only alter blue text in quotes or threshold number values)
# ===============================
params <- list(
  project_name = "DSP_12S",   # Define project name to use throughout the script (Will be used when naming output files.)
  phyloseq_file = here("dada2_phyloseq.rds"), # Define path to your phyloseq object that was produced from nf-core/ampliseq pipeline.
  output_dir = here("ASV_cleanup_outputs"), # Define output directory folder name.
  scripts_dir = here("R_ASV_cleanup_scripts"), # Define the folder containing R scripts.
  # ---- control/sample identification parameters ---- #
  sample_type_col    = "Sample_or_Control",  # Column name in metadata for assigning which are controls or samples
  sample_label       = "Sample",             # Label for sample rows
  control_label      = "Control",            # Label for control rows
  assigned_controls  = "Control_Assign",      # Column name in metadata for assigning which controls go to which samples.
    # For this column, controls are assigned a single unique ID. Samples should contain a comma-delimited list for which controls are assigned to them.
      # Example:            sampleID       Control_Assign       Sample_or_Control
      #                     BROA1               1,2,4               Sample          <- Controls 1,2,4 need to be subtracted from this sample
      #                     FLYA2               2,3,4               Sample          <- Controls 2,3,4 need to be subtracted from this sample
      #                     BROAB               1                   Control         <- The ID of this control is 1
      #                     FLYAB               3                   Control         <- The ID of this control is 2
      #                     EXT1                2                   Control         <- The ID of this control is 3
      #                     PCR1                4                   Control         <- The ID of this control is 4
  # ---- threshold parameters ---- #
  sample_thres = 0, # Define per-sample ASV threshold to be applied. You can define as a proportion (e.g., X/100) or an absolute read count (e.g., 10).
    # Removes ASVs that do not reach a minimum read count.
      # Example 1: Sample threshold = 0.05/100 = 0.05% of reads per sample = 0.0005
        # Sample A has 100,000 reads -> This threshold will remove 50 reads from each ASV (i.e., minimum 50 reads per ASV to keep that ASV).
        # Sample B has 10,000 reads -> This threshold will remove 5 reads from each ASV (i.e., minimum 5 reads per ASV to keep that ASV).
      # Example 2: Sample threshold = 10
        # Sample A (sample's total reads don't matter)  <- this threshold would remove 10 reads from each ASV (i.e., minimum 10 reads per ASV to keep that ASV).
  min_depth_thres = 0 # Define minimum sequencing depth for each sample. You can define as a proportion (e.g., X/100) or an absolute read count (e.g., 10).
    # Removes samples that do not reach a minimum read count.
      # Example 1: Min seq depth threshold  = 0.01/100 = 0.01% of total reads = 0.0001
        # Total reads in dataset = 10,000,000 -> This threshold would remove any sample with fewer than 1,000 reads.
      # Example 2: Min seq depth threshold = 10 
        # Total reads in dataset = Doesn't matter -> This threshold would remove any sample with fewer than 10 reads.
)

if (!dir.exists(params$output_dir)) dir.create(params$output_dir, recursive = TRUE) # Create output directory folder if it doesn't exist.

# ===============================
# Load phyloseq object
# ===============================
ps <- readRDS(params$phyloseq_file)
message("✅ Loaded phyloseq object with ", nsamples(ps), " samples and ", ntaxa(ps), " taxa")


# ===============================
# Define the order of scripts
# ===============================
script_files <- sort(list.files(params$scripts_dir, pattern = "\\.R$", full.names = TRUE))

# ===============================
# Run scripts
# ===============================
for (script in script_files) {
  message("Running ", basename(script), " ...")
  sys.source(script, envir = list2env(params))  # each script sees params
  message("✓ Finished ", basename(script), "\n")
}


