message("Starting Presence/Absence Before_After Decontam Pipeline")

# ===============================
# Presence/Absence Before_After Decontam Pipeline
# Outputs the presence and absence of species in samples before and after decontamination.
# ===============================


# ===============================
# 1. Read sheets from previous decontamination Excel
# ===============================
sample_reads_before <- read_excel(here(output_dir, paste0("1_",project_name, "_decontam_applied.xlsx")), 
                                  sheet = "Sample_Reads_Before")  # Read "Sample_Reads_Before" sheet
sample_reads_after  <- read_excel(here(output_dir, paste0("1_",project_name, "_decontam_applied.xlsx")), 
                                  sheet = "Sample_Reads_After")   # Read "Sample_Reads_After" sheet
message(" Sample reads loaded:")
message("     Before cleaning: ", nrow(sample_reads_before), " ASVs x ", ncol(sample_reads_before)-11, " samples")
message("     After cleaning:  ", nrow(sample_reads_after), " ASVs x ", ncol(sample_reads_after)-11, " samples")

# Extract sample names from 12th column onward (assumes first 11 columns are metadata)
sample_names_before <- colnames(sample_reads_before)[12:ncol(sample_reads_before)]  # Sample names before cleaning
sample_names_after  <- colnames(sample_reads_after)[12:ncol(sample_reads_after)]    # Sample names after cleaning

# ===============================
# 2. Compile all unique species detected in any sample
# ===============================
all_species <- unique(c(
  sample_reads_before[[8]][rowSums(sample_reads_before[, 12:ncol(sample_reads_before)]) >= 0],  # Species from before matrix
  sample_reads_after[[8]][rowSums(sample_reads_after[, 12:ncol(sample_reads_after)]) >= 0]      # Species from after matrix
)) 

all_species[is.na(all_species) | all_species == ""] <- "NA"  # Replace any empty or NA species names with string "NA"
all_species <- sort(all_species)                             # Sort species alphabetically for consistency
message("  Total unique species across all samples: ", length(all_species))

# ===============================
# 3. Create presence/absence matrices (1 = present, 0 = absent)
# ===============================
# Matrix before cleaning
before_matrix <- sapply(sample_names_before, function(samp) {  # Loop over each sample
  as.integer(all_species %in% sample_reads_before[[8]][sample_reads_before[[samp]] > 0])  # 1 if species present
}) %>% as.data.frame()                                           # Convert result to data frame
before_matrix <- cbind(Common_Name = all_species, before_matrix)  # Add species names as first column

# Matrix after cleaning
after_matrix <- sapply(sample_names_after, function(samp) {    # Loop over each sample
  as.integer(all_species %in% sample_reads_after[[8]][sample_reads_after[[samp]] > 0])   # 1 if species present
}) %>% as.data.frame()                                           # Convert to data frame
after_matrix <- cbind(Common_Name = all_species, after_matrix)   # Add species names as first column
message("  Presence/absence matrices created:")
message("     Before cleaning: ", nrow(before_matrix), " species x ", ncol(before_matrix)-1, " samples")
message("     After cleaning:  ", nrow(after_matrix), " species x ", ncol(after_matrix)-1, " samples")

# ===============================
# 4. Create Removed_Detections tab (species removed per sample, comma-separated)
# ===============================
removed_horizontal <- data.frame(Sample = sample_names_before, stringsAsFactors = FALSE)  # Initialize data frame

removed_horizontal$Removed_Species <- sapply(sample_names_before, function(samp) {  # Loop over samples
  before_fish <- sample_reads_before[[8]][sample_reads_before[[samp]] > 0]  # Species present before cleaning
  after_fish  <- sample_reads_after[[8]][sample_reads_after[[samp]] > 0]    # Species present after cleaning
  removed <- setdiff(before_fish, after_fish)                                # Determine species removed
  if(length(removed) == 0) return(NA)                                        # If none removed, set NA
  paste(sort(removed), collapse = ", ")                                       # Otherwise, comma-separated string
})
message("  Removed species per sample calculated")
num_removed_total <- sum(!is.na(removed_horizontal$Removed_Species))
message("     Total samples with at least one species removed: ", num_removed_total)

# ===============================
# 5. Create workbook and add worksheets
# ===============================
wb <- createWorkbook()   # Initialize new Excel workbook

addWorksheet(wb, "Before_Cleaning")              # Add worksheet for before-cleaning presence/absence matrix
writeData(wb, "Before_Cleaning", before_matrix)  # Write before_matrix data to worksheet

addWorksheet(wb, "After_Cleaning")               # Add worksheet for after-cleaning matrix
writeData(wb, "After_Cleaning", after_matrix)    # Write after_matrix data to worksheet

addWorksheet(wb, "Removed_Detections")          # Add worksheet for removed species per sample
writeData(wb, "Removed_Detections", removed_horizontal)  # Write removed_horizontal data

# ===============================
# 6. Apply light green fill to cells containing "1" to highlight presence
# ===============================
green_style <<- createStyle(fgFill = "#C6EFCE")  # Define light green fill style

highlight_ones <- function(sheet, data_matrix) {  # Function to apply green fill to presence cells
  for(col in 2:ncol(data_matrix)){               # Skip first column (species names)
    rows <- which(data_matrix[[col]] == 1)       # Identify rows with value 1
    if(length(rows) > 0){
      addStyle(wb, sheet = sheet, style = green_style, rows = rows + 1, cols = col, gridExpand = TRUE)  
      # Apply style to the identified cells (+1 for header row)
    }
  }
}

highlight_ones("Before_Cleaning", before_matrix)  # Apply highlighting to before matrix
highlight_ones("After_Cleaning", after_matrix)    # Apply highlighting to after matrix

# ===============================
# 7. Save workbook to Excel file
# ===============================
saveWorkbook(wb, here(output_dir, paste0("2_",project_name, "_species_detections_before_after_decontam.xlsx")), overwrite = TRUE)  
# Save workbook to file with project name, overwrite if it already exists
message("  Workbook saved at: ", here(output_dir, paste0("2_",project_name, "_species_detections_before_after_decontam.xlsx")))

# ===============================
# 8. Pipeline completion message
# ===============================
cat("-------------------------------------------------------------------- \n",
    "Presence_Absence after decontam pipeline completed successfully! \n",
    "--------------------------------------------------------------------")  # Print completion message to console



