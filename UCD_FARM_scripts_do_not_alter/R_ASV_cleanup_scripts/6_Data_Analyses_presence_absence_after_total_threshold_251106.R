message("🔹 Starting Presence/Absence After Total Threshold Pipeline")
# ===============================
# Presence/Absence Before_After Total Threshold Pipeline
# Outputs the presence and absence of species in samples before and after total threshold was applied.
# ===============================

# ===============================
# 1. Read sheets from previous total threshold Excel
# ===============================
message("  → Reading Sample_Reads_Before_Threshold and Sample_Reads_After_Threshold from Excel")
sample_reads_before_thres2 <<- read_excel(here(output_dir, paste0("5_",project_name, "_min_seq_depth_threshold_applied.xlsx")), 
                                        sheet = "Sample_Reads_Before_Threshold")  # Read "Sample_Reads_Before" sheet
sample_reads_after_thres2  <<- read_excel(here(output_dir, paste0("5_",project_name, "_min_seq_depth_threshold_applied.xlsx")), 
                                        sheet = "Sample_Reads_After_Threshold")   # Read "Sample_Reads_After" sheet

# Extract sample names from 12th column onward (assumes first 11 columns are metadata)
sample_names_before_thres2 <<- colnames(sample_reads_before_thres2)[12:ncol(sample_reads_before_thres2)]  # Sample names before threshold
sample_names_after_thres2  <<- colnames(sample_reads_after_thres2)[12:ncol(sample_reads_after_thres2)]    # Sample names after threshold
message("     • Samples before threshold: ", length(sample_names_before_thres2))
message("     • Samples after threshold: ", length(sample_names_after_thres2))
# ===============================
# 2. Compile all unique species detected in any sample
# ===============================
all_species_thres2 <<- unique(c(
  sample_reads_before_thres2[[8]][rowSums(sample_reads_before_thres2[, 12:ncol(sample_reads_before_thres2)]) >= 0],  # Species from before matrix
  sample_reads_after_thres2[[8]][rowSums(sample_reads_after_thres2[, 12:ncol(sample_reads_after_thres2)]) >= 0]      # Species from after matrix
)) 

all_species_thres2[is.na(all_species_thres2) | all_species_thres2 == ""] <<- "NA"  # Replace any empty or NA species names with string "NA"
all_species_thres2 <<- sort(all_species_thres2)                             # Sort species alphabetically for consistency
message("     • Total unique species: ", length(all_species_thres2))
# ===============================
# 3. Create presence/absence matrices (1 = present, 0 = absent)
# ===============================
# Matrix before cleaning
before_matrix_thres2 <<- sapply(sample_names_before_thres2, function(samp_thres2) {  # Loop over each sample
  as.integer(all_species_thres2 %in% sample_reads_before_thres2[[8]][sample_reads_before_thres2[[samp_thres2]] > 0])  # 1 if species present
}) %>% as.data.frame()                                           # Convert result to data frame
before_matrix_thres2 <<- cbind(Common_Name = all_species_thres2, before_matrix_thres2)  # Add species names as first column

# Matrix after cleaning
after_matrix_thres2 <<- sapply(sample_names_after_thres2, function(samp_thres2) {    # Loop over each sample
  as.integer(all_species_thres2 %in% sample_reads_after_thres2[[8]][sample_reads_after_thres2[[samp_thres2]] > 0])   # 1 if species present
}) %>% as.data.frame()                                           # Convert to data frame
after_matrix_thres2 <<- cbind(Common_Name = all_species_thres2, after_matrix_thres2)   # Add species names as first column
message("     • Presence/absence matrices created")
# ===============================
# 4. Create Removed_Detections tab (species removed per sample, comma-separated)
# ===============================
removed_horizontal_thres2 <<- data.frame(Sample = sample_names_before_thres2, stringsAsFactors = FALSE)  # Initialize data frame

removed_horizontal_thres2$Removed_Species <<- sapply(sample_names_before_thres2, function(samp_thres2) {  # Loop over samples
  before_fish_thres2 <<- sample_reads_before_thres2[[8]][sample_reads_before_thres2[[samp_thres2]] > 0]  # Species present before cleaning
  after_fish_thres2  <<- sample_reads_after_thres2[[8]][sample_reads_after_thres2[[samp_thres2]] > 0]    # Species present after cleaning
  removed_thres2 <<- setdiff(before_fish_thres2, after_fish_thres2)                                # Determine species removed
  if(length(removed_thres2) == 0) return(NA)                                        # If none removed, set NA
  paste(sort(removed_thres2), collapse = ", ")                                       # Otherwise, comma-separated string
})

# ===============================
# Summary messages for Removed_Detections
# ===============================
num_samples_with_removed <- sum(!is.na(removed_horizontal_thres2$Removed_Species))

# Compute number of species removed per sample
removals_per_sample <- sapply(removed_horizontal_thres2$Removed_Species, function(x) {
  if(is.na(x)) return(0)
  length(unlist(strsplit(x, ", ")))
})

avg_removed_species <- mean(removals_per_sample)  # Average per sample

message("  → Removed species summary:")
message("     • Samples with at least one species removed: ", num_samples_with_removed, " / ", nrow(removed_horizontal_thres2))
message("     • Average number of species removed per sample: ", round(avg_removed_species, 2))

if(num_samples_with_removed > 0){
  # Identify sample with most removals
  max_removed_sample <- removed_horizontal_thres2$Sample[which.max(removals_per_sample)]
  message("     • Sample with most species removed: ", max_removed_sample, " (", max(removals_per_sample), " species)")
} else {
  message("     • No species were removed from any sample.")
}

# Identify species completely removed from study
species_removed_completely <- before_matrix_thres2$Common_Name[
  rowSums(before_matrix_thres2[, -1]) > 0 &   # Present in at least one sample before
    rowSums(after_matrix_thres2[, -1]) == 0     # Absent in all samples after
]

num_species_removed_completely <- length(species_removed_completely)

if(num_species_removed_completely > 0){
  message("  → Species completely removed from study: ", num_species_removed_completely)
  message("     • Names: ", paste(head(species_removed_completely, 10), collapse = ", "),
          if(num_species_removed_completely > 10) " …")
} else {
  message("  → No species were completely removed from the study.")
}


# ===============================
# 5. Create workbook and add worksheets
# ===============================
wb_thres2 <<- createWorkbook()   # Initialize new Excel workbook

addWorksheet(wb_thres2, "Before_Cleaning")              # Add worksheet for before-cleaning presence/absence matrix
writeData(wb_thres2, "Before_Cleaning", before_matrix_thres2)  # Write before_matrix data to worksheet

addWorksheet(wb_thres2, "After_Cleaning")               # Add worksheet for after-cleaning matrix
writeData(wb_thres2, "After_Cleaning", after_matrix_thres2)    # Write after_matrix data to worksheet

addWorksheet(wb_thres2, "Removed_Detections")          # Add worksheet for removed species per sample
writeData(wb_thres2, "Removed_Detections", removed_horizontal_thres2)  # Write removed_horizontal data

# ===============================
# 6. Apply light green fill to cells containing "1" to highlight presence
# ===============================
green_style_thres2 <<- createStyle(fgFill = "#C6EFCE")  # Define light green fill style

highlight_ones_thres2 <<- function(sheet, data_matrix_thres2) {  # Function to apply green fill to presence cells
  for(col in 2:ncol(data_matrix_thres2)){               # Skip first column (species names)
    rows <<- which(data_matrix_thres2[[col]] == 1)       # Identify rows with value 1
    if(length(rows) > 0){
      addStyle(wb_thres2, sheet = sheet, style = green_style, rows = rows + 1, cols = col, gridExpand = TRUE)  
      # Apply style to the identified cells (+1 for header row)
    }
  }
}

highlight_ones_thres2("Before_Cleaning", before_matrix_thres2)  # Apply highlighting to before matrix
highlight_ones_thres2("After_Cleaning", after_matrix_thres2)    # Apply highlighting to after matrix

# ===============================
# 7. Save workbook to Excel file
# ===============================
saveWorkbook(wb_thres2, here(output_dir, paste0("6_",project_name, "_species_detections_before_after_total_threshold.xlsx")),
             overwrite = TRUE)
message("  → Excel workbook saved at: ", output_dir)
# ===============================
# 8. Pipeline completion message
# ===============================
cat("-------------------------------------------------------------------- \n",
    "🧬 Presence_Absence after total threshold pipeline completed successfully! 🧬\n",
    "--------------------------------------------------------------------")  # Print completion message to console

