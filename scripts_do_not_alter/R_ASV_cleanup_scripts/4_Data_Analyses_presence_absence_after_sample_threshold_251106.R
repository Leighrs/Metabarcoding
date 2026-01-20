message(" Starting Presence/Absence After Per-Sample ASV Threshold Pipeline")

# ===============================
# Presence/Absence After Per-Sample ASV Threshold Pipeline
# Outputs the presence and absence of species in samples before and after sample threshold was applied.
# ===============================

# ===============================
# 1. Read sheets from previous sample threshold Excel
# ===============================
sample_reads_before_thres <<- read_excel(here(output_dir, paste0("3_",project_name, "_sample_threshold_applied.xlsx")), 
                                  sheet = "Sample_Reads_Before_Threshold")  # Read "Sample_Reads_Before" sheet
sample_reads_after_thres  <<- read_excel(here(output_dir, paste0("3_",project_name, "_sample_threshold_applied.xlsx")), 
                                  sheet = "Sample_Reads_After_Threshold")   # Read "Sample_Reads_After" sheet

# Extract sample names from 12th column onward (assumes first 11 columns are metadata)
sample_names_before_thres <<- colnames(sample_reads_before_thres)[12:ncol(sample_reads_before_thres)]  # Sample names before threshold
sample_names_after_thres  <<- colnames(sample_reads_after_thres)[12:ncol(sample_reads_after_thres)]    # Sample names after threshold
message("  -> Sample reads loaded from previous threshold step:")
message("     * Before threshold: ", nrow(sample_reads_before_thres), " ASVs x ", length(sample_names_before_thres), " samples")
message("     * After threshold:  ", nrow(sample_reads_after_thres), " ASVs x ", length(sample_names_after_thres), " samples")
# ===============================
# 2. Compile all unique species detected in any sample
# ===============================
all_species_thres <<- unique(c(
  sample_reads_before_thres[[8]][rowSums(sample_reads_before_thres[, 12:ncol(sample_reads_before_thres)]) >= 0],  # Species from before matrix
  sample_reads_after_thres[[8]][rowSums(sample_reads_after_thres[, 12:ncol(sample_reads_after_thres)]) >= 0]      # Species from after matrix
)) 

all_species_thres[is.na(all_species_thres) | all_species_thres == ""] <<- "NA"  # Replace any empty or NA species names with string "NA"
all_species_thres <<- sort(all_species_thres)                             # Sort species alphabetically for consistency
message("  -> Total unique species across all samples: ", length(all_species_thres))


# ===============================
# 3. Create presence/absence matrices (1 = present, 0 = absent)
# ===============================
# Matrix before cleaning
before_matrix_thres <<- sapply(sample_names_before_thres, function(samp_thres) {  # Loop over each sample
  as.integer(all_species_thres %in% sample_reads_before_thres[[8]][sample_reads_before_thres[[samp_thres]] > 0])  # 1 if species present
}) %>% as.data.frame()                                           # Convert result to data frame
before_matrix_thres <<- cbind(Common_Name = all_species_thres, before_matrix_thres)  # Add species names as first column

# Matrix after cleaning
after_matrix_thres <<- sapply(sample_names_after_thres, function(samp_thres) {    # Loop over each sample
  as.integer(all_species_thres %in% sample_reads_after_thres[[8]][sample_reads_after_thres[[samp_thres]] > 0])   # 1 if species present
}) %>% as.data.frame()                                           # Convert to data frame
after_matrix_thres <<- cbind(Common_Name = all_species_thres, after_matrix_thres)   # Add species names as first column
message("  -> Presence/absence matrices created:")
message("     * Before threshold: ", nrow(before_matrix_thres), " species x ", ncol(before_matrix_thres)-1, " samples")
message("     * After threshold:  ", nrow(after_matrix_thres), " species x ", ncol(after_matrix_thres)-1, " samples")

# ===============================
# 4. Create Removed_Detections tab (species removed per sample, comma-separated)
# ===============================
removed_horizontal_thres <<- data.frame(Sample = sample_names_before_thres, stringsAsFactors = FALSE)  # Initialize data frame

removed_horizontal_thres$Removed_Species <<- sapply(sample_names_before_thres, function(samp_thres) {  # Loop over samples
  before_fish_thres <<- sample_reads_before_thres[[8]][sample_reads_before_thres[[samp_thres]] > 0]  # Species present before cleaning
  after_fish_thres  <<- sample_reads_after_thres[[8]][sample_reads_after_thres[[samp_thres]] > 0]    # Species present after cleaning
  removed_thres <<- setdiff(before_fish_thres, after_fish_thres)                                # Determine species removed
  if(length(removed_thres) == 0) return(NA)                                        # If none removed, set NA
  paste(sort(removed_thres), collapse = ", ")                                       # Otherwise, comma-separated string
})
num_removed_total <- sum(!is.na(removed_horizontal_thres$Removed_Species))
message("  -> Removed species per sample calculated")
message("     * Samples with at least one species removed: ", num_removed_total)

# ===============================
# 5. Create workbook and add worksheets
# ===============================
wb_thres <<- createWorkbook()   # Initialize new Excel workbook

addWorksheet(wb_thres, "Before_Cleaning")              # Add worksheet for before-cleaning presence/absence matrix
writeData(wb_thres, "Before_Cleaning", before_matrix_thres)  # Write before_matrix data to worksheet

addWorksheet(wb_thres, "After_Cleaning")               # Add worksheet for after-cleaning matrix
writeData(wb_thres, "After_Cleaning", after_matrix_thres)    # Write after_matrix data to worksheet

addWorksheet(wb_thres, "Removed_Detections")          # Add worksheet for removed species per sample
writeData(wb_thres, "Removed_Detections", removed_horizontal_thres)  # Write removed_horizontal data

# ===============================
# 6. Apply light green fill to cells containing "1" to highlight presence
# ===============================
green_style_thres <<- createStyle(fgFill = "#C6EFCE")  # Define light green fill style

highlight_ones_thres <<- function(sheet, data_matrix_thres) {  # Function to apply green fill to presence cells
  for(col in 2:ncol(data_matrix_thres)){               # Skip first column (species names)
    rows <<- which(data_matrix_thres[[col]] == 1)       # Identify rows with value 1
    if(length(rows) > 0){
      addStyle(wb_thres, sheet = sheet, style = green_style, rows = rows + 1, cols = col, gridExpand = TRUE)  
      # Apply style to the identified cells (+1 for header row)
    }
  }
}

highlight_ones_thres("Before_Cleaning", before_matrix_thres)  # Apply highlighting to before matrix
highlight_ones_thres("After_Cleaning", after_matrix_thres)    # Apply highlighting to after matrix

# ===============================
# 7. Save workbook to Excel file
# ===============================
saveWorkbook(wb_thres, here(output_dir, paste0("4_",project_name, "_species_detections_before_after_sample_threshold.xlsx")),
             overwrite = TRUE)
threshold_output_path <- here(output_dir, paste0("4_",project_name, "_species_detections_before_after_sample_threshold.xlsx"))
message("  -> Workbook saved at: ", threshold_output_path)

# ===============================
# 8. Pipeline completion message
# ===============================
cat("-------------------------------------------------------------------- \n",
    " Presence_Absence after sample threshold pipeline completed successfully! \n",
    "--------------------------------------------------------------------")  # Print completion message to console


