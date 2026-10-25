# ============================================================
# STEP 2 - UNIFIED ELIGIBILITY FILTER
# Year + Language + Document Type
# 2000-2025 | English | Article / Review
# NO DEDUPLICATION
# ============================================================


# ------------------------------------------------------------
# 1. PACKAGES
# ------------------------------------------------------------

library(readr)
library(dplyr)


# ------------------------------------------------------------
# 2. INPUT / OUTPUT PATHS
# ------------------------------------------------------------

input_file <- 
  "D:/Thesis/data/Step1_Scopus_WoS_Merged_RAW/Scopus_WoS_Merged_RAW.csv"

output_dir <- 
  "D:/Thesis/data/Step2_Eligibility_2000_2025_English_Article_Review"

dir.create(
  output_dir,
  recursive = TRUE,
  showWarnings = FALSE
)


# ------------------------------------------------------------
# 3. OUTPUT FILES
# ------------------------------------------------------------

main_output <- file.path(
  output_dir,
  "Scopus_WoS_Eligible_2000_2025_English_Article_Review_PRE_DEDUP.csv"
)

excluded_output <- file.path(
  output_dir,
  "Records_Excluded_Step2.csv"
)

report_file <- file.path(
  output_dir,
  "Step2_Eligibility_Report.txt"
)

database_summary_file <- file.path(
  output_dir,
  "Step2_Database_Summary.csv"
)

year_before_file <- file.path(
  output_dir,
  "Step2_Year_Summary_BEFORE.csv"
)

year_after_file <- file.path(
  output_dir,
  "Step2_Year_Summary_AFTER.csv"
)

language_summary_file <- file.path(
  output_dir,
  "Step2_Language_Summary.csv"
)

document_type_summary_file <- file.path(
  output_dir,
  "Step2_Document_Type_Summary.csv"
)

exclusion_summary_file <- file.path(
  output_dir,
  "Step2_Exclusion_Summary.csv"
)


# ------------------------------------------------------------
# 4. READ STEP 1 DATA
# ------------------------------------------------------------

cat("\nReading Step 1 data...\n")

data <- read_csv(
  input_file,
  show_col_types = FALSE
)

cat("Records loaded:", nrow(data), "\n")
cat("Columns loaded:", ncol(data), "\n\n")


# ------------------------------------------------------------
# 5. BASIC COLUMN CHECK
# ------------------------------------------------------------

required_columns <- c(
  "Year",
  "Language",
  "Document_Type",
  "Source_Database"
)

missing_columns <- setdiff(
  required_columns,
  names(data)
)

if (length(missing_columns) > 0) {
  
  stop(
    paste(
      "ERROR: The following required columns are missing:",
      paste(missing_columns, collapse = ", ")
    )
  )
}


# ------------------------------------------------------------
# 6. STANDARDIZE VARIABLES FOR CHECKING
# ------------------------------------------------------------

data <- data %>%
  mutate(
    
    Year_num = suppressWarnings(
      as.numeric(Year)
    ),
    
    Language_check = toupper(
      trimws(
        as.character(Language)
      )
    ),
    
    Document_Type_check = toupper(
      trimws(
        as.character(Document_Type)
      )
    )
  )


# ------------------------------------------------------------
# 7. YEAR ELIGIBILITY
# ------------------------------------------------------------

data <- data %>%
  mutate(
    
    Eligible_Year =
      !is.na(Year_num) &
      Year_num >= 2000 &
      Year_num <= 2025
    
  )


# ------------------------------------------------------------
# 8. LANGUAGE ELIGIBILITY
# ------------------------------------------------------------

data <- data %>%
  mutate(
    
    Eligible_Language =
      !is.na(Language_check) &
      Language_check == "ENGLISH"
    
  )


# ------------------------------------------------------------
# 9. DOCUMENT TYPE ELIGIBILITY
#
# IMPORTANT:
# A record is eligible if its document type contains
# ARTICLE or REVIEW.
#
# This accommodates WoS combinations such as:
# ARTICLE; EARLY ACCESS
# ARTICLE; DATA PAPER
# ARTICLE; PROCEEDINGS PAPER
# REVIEW; EARLY ACCESS
# etc.
# ------------------------------------------------------------

data <- data %>%
  mutate(
    
    Eligible_Document_Type =
      grepl(
        "ARTICLE|REVIEW",
        Document_Type_check
      )
    
  )


# ------------------------------------------------------------
# 10. OVERALL ELIGIBILITY
# ------------------------------------------------------------

data <- data %>%
  mutate(
    
    Eligible_Step2 =
      Eligible_Year &
      Eligible_Language &
      Eligible_Document_Type
    
  )


# ------------------------------------------------------------
# 11. EXCLUSION REASON
# ------------------------------------------------------------

data <- data %>%
  mutate(
    
    Exclusion_Reason = case_when(
      
      Eligible_Step2 ~
        "Eligible",
      
      !Eligible_Year &
        !Eligible_Language &
        !Eligible_Document_Type ~
        "Year + Language + Document Type",
      
      !Eligible_Year &
        !Eligible_Language ~
        "Year + Language",
      
      !Eligible_Year &
        !Eligible_Document_Type ~
        "Year + Document Type",
      
      !Eligible_Language &
        !Eligible_Document_Type ~
        "Language + Document Type",
      
      !Eligible_Year ~
        "Year",
      
      !Eligible_Language ~
        "Language",
      
      !Eligible_Document_Type ~
        "Document Type",
      
      TRUE ~
        "Other"
    )
    
  )


# ------------------------------------------------------------
# 12. SAVE MAIN ELIGIBLE DATASET
# ------------------------------------------------------------

eligible_data <- data %>%
  filter(
    Eligible_Step2
  ) %>%
  select(
    -Year_num,
    -Language_check,
    -Document_Type_check,
    -Eligible_Year,
    -Eligible_Language,
    -Eligible_Document_Type,
    -Eligible_Step2,
    -Exclusion_Reason
  )


write_csv(
  eligible_data,
  main_output
)


# ------------------------------------------------------------
# 13. SAVE EXCLUDED RECORDS
# ------------------------------------------------------------

excluded_data <- data %>%
  filter(
    !Eligible_Step2
  ) %>%
  select(
    -Year_num,
    -Language_check,
    -Document_Type_check
  )


write_csv(
  excluded_data,
  excluded_output
)


# ------------------------------------------------------------
# 14. DATABASE SUMMARY
# ------------------------------------------------------------

database_summary <- data %>%
  count(
    Source_Database,
    Eligible_Step2,
    name = "Records"
  ) %>%
  arrange(
    Source_Database,
    desc(Eligible_Step2)
  )

write_csv(
  database_summary,
  database_summary_file
)


# ------------------------------------------------------------
# 15. YEAR SUMMARY - BEFORE FILTERING
# ------------------------------------------------------------

year_before <- data %>%
  count(
    Year_num,
    name = "Records"
  ) %>%
  arrange(
    Year_num
  )

write_csv(
  year_before,
  year_before_file
)


# ------------------------------------------------------------
# 16. YEAR SUMMARY - AFTER FILTERING
# ------------------------------------------------------------

year_after <- eligible_data %>%
  count(
    Year,
    name = "Records"
  ) %>%
  arrange(
    Year
  )

write_csv(
  year_after,
  year_after_file
)


# ------------------------------------------------------------
# 17. LANGUAGE SUMMARY
# ------------------------------------------------------------

language_summary <- data %>%
  count(
    Language,
    Eligible_Language,
    name = "Records"
  ) %>%
  arrange(
    desc(Records)
  )

write_csv(
  language_summary,
  language_summary_file
)


# ------------------------------------------------------------
# 18. DOCUMENT TYPE SUMMARY
# ------------------------------------------------------------

document_type_summary <- data %>%
  count(
    Source_Database,
    Document_Type,
    Eligible_Document_Type,
    name = "Records"
  ) %>%
  arrange(
    Source_Database,
    desc(Records)
  )

write_csv(
  document_type_summary,
  document_type_summary_file
)


# ------------------------------------------------------------
# 19. EXCLUSION SUMMARY
# ------------------------------------------------------------

exclusion_summary <- data %>%
  count(
    Exclusion_Reason,
    name = "Records"
  ) %>%
  arrange(
    desc(Records)
  )

write_csv(
  exclusion_summary,
  exclusion_summary_file
)


# ------------------------------------------------------------
# 20. BASIC NUMBERS
# ------------------------------------------------------------

total_records <- nrow(data)

eligible_records <- nrow(eligible_data)

excluded_records <- nrow(excluded_data)

eligible_percent <-
  round(
    100 * eligible_records / total_records,
    2
  )

excluded_percent <-
  round(
    100 * excluded_records / total_records,
    2
  )


# ------------------------------------------------------------
# 21. DATABASE COUNTS
# ------------------------------------------------------------

scopus_total <- sum(
  data$Source_Database == "Scopus",
  na.rm = TRUE
)

wos_total <- sum(
  data$Source_Database == "WoS",
  na.rm = TRUE
)

scopus_eligible <- sum(
  data$Source_Database == "Scopus" &
    data$Eligible_Step2,
  na.rm = TRUE
)

wos_eligible <- sum(
  data$Source_Database == "WoS" &
    data$Eligible_Step2,
  na.rm = TRUE
)


# ------------------------------------------------------------
# 22. REPORT
# ------------------------------------------------------------

report_lines <- c(
  
  "============================================================",
  "STEP 2 - UNIFIED ELIGIBILITY FILTER REPORT",
  "============================================================",
  "",
  "Purpose:",
  "Apply the three predefined eligibility criteria:",
  "1. Publication year: 2000-2025",
  "2. Language: English",
  "3. Document type: Article or Review",
  "",
  "Important:",
  "No deduplication was performed at this stage.",
  "",
  "------------------------------------------------------------",
  "INPUT DATA",
  "------------------------------------------------------------",
  "",
  paste("Input file:", input_file),
  paste("Total input records:", total_records),
  paste("Input columns:", ncol(data)),
  "",
  "------------------------------------------------------------",
  "ELIGIBILITY CRITERIA",
  "------------------------------------------------------------",
  "",
  "Year:",
  "2000 <= Year <= 2025",
  "",
  "Language:",
  "English",
  "",
  "Document Type:",
  "Article or Review",
  "",
  "For WoS combined document types, a record is considered",
  "eligible when its document-type field contains ARTICLE",
  "or REVIEW.",
  "",
  "------------------------------------------------------------",
  "RESULTS",
  "------------------------------------------------------------",
  "",
  paste("Eligible records:", eligible_records),
  paste("Eligible percentage:", eligible_percent, "%"),
  "",
  paste("Excluded records:", excluded_records),
  paste("Excluded percentage:", excluded_percent, "%"),
  "",
  "------------------------------------------------------------",
  "DATABASE RESULTS",
  "------------------------------------------------------------",
  "",
  paste("Scopus input:", scopus_total),
  paste("Scopus eligible:", scopus_eligible),
  paste(
    "Scopus excluded:",
    scopus_total - scopus_eligible
  ),
  "",
  paste("WoS input:", wos_total),
  paste("WoS eligible:", wos_eligible),
  paste(
    "WoS excluded:",
    wos_total - wos_eligible
  ),
  "",
  "------------------------------------------------------------",
  "OUTPUT FILES",
  "------------------------------------------------------------",
  "",
  paste("Main eligible dataset:", main_output),
  paste("Excluded records:", excluded_output),
  paste("Database summary:", database_summary_file),
  paste("Year summary BEFORE:", year_before_file),
  paste("Year summary AFTER:", year_after_file),
  paste("Language summary:", language_summary_file),
  paste("Document type summary:", document_type_summary_file),
  paste("Exclusion summary:", exclusion_summary_file),
  "",
  "============================================================",
  "END OF STEP 2",
  "============================================================"
)


writeLines(
  report_lines,
  report_file,
  useBytes = TRUE
)


# ------------------------------------------------------------
# 23. FINAL CONSOLE CHECK
# ------------------------------------------------------------

cat("\n")
cat("============================================================\n")
cat("STEP 2 - UNIFIED ELIGIBILITY FILTER COMPLETED\n")
cat("============================================================\n\n")

cat("Input records:", total_records, "\n")
cat("Eligible records:", eligible_records, "\n")
cat("Excluded records:", excluded_records, "\n")
cat("Eligible percentage:", eligible_percent, "%\n")
cat("Excluded percentage:", excluded_percent, "%\n\n")

cat("DATABASE RESULTS\n")
cat("----------------\n")
cat("Scopus input:", scopus_total, "\n")
cat("Scopus eligible:", scopus_eligible, "\n")
cat("Scopus excluded:",
    scopus_total - scopus_eligible, "\n\n")

cat("WoS input:", wos_total, "\n")
cat("WoS eligible:", wos_eligible, "\n")
cat("WoS excluded:",
    wos_total - wos_eligible, "\n\n")

cat("Main output:\n")
cat(main_output, "\n\n")

cat("Report:\n")
cat(report_file, "\n\n")

cat("============================================================\n")
cat("END\n")
cat("============================================================\n")