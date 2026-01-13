# Master script to run all ASV cleanup steps

#================================
# NOTE: Only alter "User-defined parameters" below.
#================================

# -------------------------------
# Load required libraries
# -------------------------------

suppressPackageStartupMessages({
  library(here)
  library(phyloseq)
  library(stringr)
  library(openxlsx)
  library(writexl)
  library(readxl)
  library(dplyr)
})

# ----------------------------
# Define Helper Functions
# ----------------------------

stop_if_missing <- function(x, name) {
  if (is.null(x) || !nzchar(x)) stop("Missing required env var: ", name, call. = FALSE) # If x is null or x is empty, then halt script, and print an error. But don't print full function error.
}

# ----------------------------
# Inputs via environment variables
# ----------------------------
PROJECT_NAME <- Sys.getenv("PROJECT_NAME", unset = "") #unset returns an empty string "" if the variable does not exist.
stop_if_missing(PROJECT_NAME, "PROJECT_NAME")

PROJECT_DIR <- Sys.getenv("PROJECT_DIR", unset = file.path(Sys.getenv("HOME"), "Metabarcoding", PROJECT_NAME))

PHYLOSEQ_RDS <- Sys.getenv("PHYLOSEQ_RDS_REVIEWED", unset = "")
stop_if_missing(PHYLOSEQ_RDS, "PHYLOSEQ_RDS_REVIEWED")

SCRIPT_DIR <- Sys.getenv("SCRIPT_DIR", unset = "")
stop_if_missing(SCRIPT_DIR, "SCRIPT_DIR")

OUT_DIR <- Sys.getenv("ASV_CLEANUP_DIR", unset = "")
stop_if_missing(OUT_DIR, "ASV_CLEANUP_DIR")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

message("Project dir: ", PROJECT_DIR)
message("Reviewed phyloseq: ", PHYLOSEQ_RDS)
message("Scripts dir: ", SCRIPT_DIR)
message("Output dir: ", OUT_DIR)

if (!file.exists(PHYLOSEQ_RDS)) stop("Cannot find phyloseq RDS: ", PHYLOSEQ_RDS, call. = FALSE)


# ===============================
# Parameters:
# ===============================
params <- list(
  project_name = PROJECT_NAME,   # Defines project name to use throughout the script (Will be used when naming output files.)
  phyloseq_file = PHYLOSEQ_RDS, # Defines path to your phyloseq object that was produced from nf-core/ampliseq pipeline.
  output_dir = OUT_DIR, # Defines output directory folder name.
  scripts_dir = SCRIPT_DIR, # Defines the folder containing R scripts.
  # ---- control/sample identification parameters ---- #
  sample_type_col    = Sys.getenv("SAMPLE_TYPE_COL", unset = "Sample_or_Control"),  # Column name in metadata for assigning which are controls or samples
  sample_label       = Sys.getenv("SAMPLE_LABEL", unset = "Sample"),           # Label for sample rows
  control_label      = Sys.getenv("CONTROL_LABEL", unset = "Control"),            # Label for control rows
  assigned_controls  = Sys.getenv("ASSIGNED_CONTROLS_COL", unset = "Control_Assign"),      # Column name in metadata for assigning which controls go to which samples.
    # For this column, controls are assigned a single unique ID. Samples should contain a comma-delimited list for which controls are assigned to them.
      # Example:            sampleID       Control_Assign       Sample_or_Control
      #                     BROA1               1,2,4               Sample          <- Controls 1,2,4 need to be subtracted from this sample
      #                     FLYA2               2,3,4               Sample          <- Controls 2,3,4 need to be subtracted from this sample
      #                     BROAB               1                   Control         <- The ID of this control is 1
      #                     FLYAB               3                   Control         <- The ID of this control is 2
      #                     EXT1                2                   Control         <- The ID of this control is 3
      #                     PCR1                4                   Control         <- The ID of this control is 4
  # ---- threshold parameters ---- #
  sample_thres = as.numeric(Sys.getenv("SAMPLE_THRES", unset = "0")), # Define per-sample ASV threshold to be applied. You can define as a proportion (e.g., X/100) or an absolute read count (e.g., 10).
    # Removes ASVs that do not reach a minimum read count.
      # Example 1: Sample threshold = 0.05/100 = 0.05% of reads per sample = 0.0005
        # Sample A has 100,000 reads -> This threshold will remove 50 reads from each ASV (i.e., minimum 50 reads per ASV to keep that ASV).
        # Sample B has 10,000 reads -> This threshold will remove 5 reads from each ASV (i.e., minimum 5 reads per ASV to keep that ASV).
      # Example 2: Sample threshold = 10
        # Sample A (sample's total reads don't matter)  <- this threshold would remove 10 reads from each ASV (i.e., minimum 10 reads per ASV to keep that ASV).
  min_depth_thres = as.numeric(Sys.getenv("MIN_DEPTH_THRES", unset = "0")) # Define minimum sequencing depth for each sample. You can define as a proportion (e.g., X/100) or an absolute read count (e.g., 10).
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
# Fail early if scripts directory does not exist
if (!dir.exists(params$scripts_dir)) {
  stop("Scripts dir does not exist: ", params$scripts_dir, call. = FALSE)
}

script_files <- sort(list.files(params$scripts_dir, pattern = "\\.R$", full.names = TRUE))

# Exclude the master script / runner script(s) so we don't recurse
script_files <- script_files[basename(script_files) != "test_GVL_metabarcoding_cleanup_main.R"]


# ===============================
# Run scripts
# ===============================
for (script in script_files) {
  message("Running ", basename(script), " ...")
  sys.source(script, envir = list2env(params))  # each script sees params
  message("✓ Finished ", basename(script), "\n")
}

message("Decontamination complete! Final phyloseq object stored at: $HOME/Metabarcoding/$PROJECT_NAME/output/ASV_cleanup_output/dada2_phyloseq_cleaned.rds")


