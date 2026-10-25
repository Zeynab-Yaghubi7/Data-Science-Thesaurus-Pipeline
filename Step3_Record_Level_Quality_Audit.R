# ============================================================
# STEP 3
# RECORD-LEVEL QUALITY AUDIT
# ============================================================

library(readr)
library(dplyr)
library(stringr)

# ------------------------------------------------------------
# 1. Paths
# ------------------------------------------------------------

input_file <- paste0(
  "D:/Thesis/data/Step2_Eligibility_2000_2025_English_Article_Review/",
  "Scopus_WoS_Eligible_2000_2025_English_Article_Review_PRE_DEDUP.csv"
)

output_dir <- "D:/Thesis/data/Step3_Record_Level_Quality_Audit"

if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

# ------------------------------------------------------------
# 2. Read data
# ------------------------------------------------------------

M <- read_csv(
  input_file,
  show_col_types = FALSE,
  name_repair = "minimal"
)

# ------------------------------------------------------------
# 3. Basic information
# ------------------------------------------------------------

total_records <- nrow(M)
total_columns <- ncol(M)

# ------------------------------------------------------------
# 4. Helper function for missing values
# ------------------------------------------------------------

is_missing_text <- function(x) {
  is.na(x) | trimws(as.character(x)) == ""
}

# ------------------------------------------------------------
# 5. Missingness audit
# ------------------------------------------------------------

missingness_report <- data.frame(
  Field = character(),
  Missing_Records = integer(),
  Missing_Percent = numeric(),
  stringsAsFactors = FALSE
)

fields_to_check <- c(
  "DOI",
  "Title",
  "Year",
  "Authors",
  "Abstract",
  "Author_Keywords_Scopus",
  "Index_Keywords_Scopus",
  "Author_Keywords_WoS",
  "Keywords_Plus_WoS",
  "Source_Title",
  "Document_Type",
  "Language",
  "UT_WoS"
)

for (field in fields_to_check) {
  
  x <- M[[field]]
  
  missing_n <- sum(is_missing_text(x))
  
  missingness_report <- rbind(
    missingness_report,
    data.frame(
      Field = field,
      Missing_Records = missing_n,
      Missing_Percent = round(
        100 * missing_n / total_records,
        2
      )
    )
  )
}

# ------------------------------------------------------------
# 6. Database-specific missingness
# ------------------------------------------------------------

database_missingness <- M %>%
  group_by(Source_Database) %>%
  summarise(
    Records = n(),
    
    Missing_DOI = sum(is_missing_text(DOI)),
    
    Missing_Title = sum(is_missing_text(Title)),
    
    Missing_Year = sum(is.na(Year)),
    
    Missing_Authors = sum(is_missing_text(Authors)),
    
    Missing_Abstract = sum(is_missing_text(Abstract)),
    
    Missing_Scopus_Author_Keywords =
      sum(is_missing_text(Author_Keywords_Scopus)),
    
    Missing_WoS_Author_Keywords =
      sum(is_missing_text(Author_Keywords_WoS)),
    
    .groups = "drop"
  )

# ------------------------------------------------------------
# 7. DOI normalization
# ------------------------------------------------------------

M <- M %>%
  mutate(
    DOI_Normalized = DOI %>%
      as.character() %>%
      str_trim() %>%
      str_to_lower() %>%
      str_replace("^https?://doi\\.org/", "") %>%
      str_replace("^doi:\\s*", "") %>%
      str_trim()
  )

# ------------------------------------------------------------
# 8. Duplicate DOI diagnostics
# IMPORTANT:
# No records are deleted here.
# ------------------------------------------------------------

doi_duplicate_groups <- M %>%
  filter(
    !is.na(DOI_Normalized),
    DOI_Normalized != ""
  ) %>%
  group_by(DOI_Normalized) %>%
  summarise(
    Number_of_Records = n(),
    Databases = paste(
      sort(unique(Source_Database)),
      collapse = " | "
    ),
    .groups = "drop"
  ) %>%
  filter(Number_of_Records > 1) %>%
  arrange(desc(Number_of_Records))

doi_duplicate_records <- M %>%
  filter(
    !is.na(DOI_Normalized),
    DOI_Normalized != ""
  ) %>%
  inner_join(
    doi_duplicate_groups %>%
      select(DOI_Normalized, Number_of_Records, Databases),
    by = "DOI_Normalized"
  ) %>%
  arrange(DOI_Normalized, Source_Database)

# ------------------------------------------------------------
# 9. Records without DOI
# ------------------------------------------------------------

records_without_doi <- M %>%
  filter(
    is.na(DOI_Normalized) |
      DOI_Normalized == ""
  ) %>%
  select(
    Source_Database,
    Original_ID,
    Title,
    Year,
    Authors,
    DOI,
    UT_WoS
  )

# ------------------------------------------------------------
# 10. Retraction audit
# ------------------------------------------------------------

retraction_records <- M %>%
  filter(
    str_detect(
      str_to_lower(
        coalesce(Document_Type, "")
      ),
      "retract"
    )
  ) %>%
  select(
    Source_Database,
    Original_ID,
    DOI,
    Title,
    Year,
    Authors,
    Document_Type,
    Source_Title,
    UT_WoS
  )

# ------------------------------------------------------------
# 11. Document Type summary
# ------------------------------------------------------------

document_type_summary <- M %>%
  count(
    Source_Database,
    Document_Type,
    name = "Records"
  ) %>%
  arrange(
    Source_Database,
    desc(Records)
  )

# ------------------------------------------------------------
# 12. Language summary
# ------------------------------------------------------------

language_summary <- M %>%
  count(
    Source_Database,
    Language,
    name = "Records"
  ) %>%
  arrange(
    Source_Database,
    desc(Records)
  )

# ------------------------------------------------------------
# 13. Missing title records
# ------------------------------------------------------------

missing_title_records <- M %>%
  filter(is_missing_text(Title))

# ------------------------------------------------------------
# 14. Missing author records
# ------------------------------------------------------------

missing_author_records <- M %>%
  filter(is_missing_text(Authors))

# ------------------------------------------------------------
# 15. Missing abstract records
# ------------------------------------------------------------

missing_abstract_records <- M %>%
  filter(is_missing_text(Abstract))

# ------------------------------------------------------------
# 16. Missing keyword records
# ------------------------------------------------------------

missing_keyword_records <- M %>%
  filter(
    is_missing_text(Author_Keywords_Scopus) &
      is_missing_text(Author_Keywords_WoS)
  ) %>%
  select(
    Source_Database,
    Original_ID,
    DOI,
    Title,
    Year,
    Authors,
    Author_Keywords_Scopus,
    Author_Keywords_WoS
  )

# ------------------------------------------------------------
# 17. Potentially problematic records
# These are flagged only; NOT deleted.
# ------------------------------------------------------------

quality_flags <- M %>%
  mutate(
    
    Flag_Missing_DOI =
      is_missing_text(DOI),
    
    Flag_Missing_Title =
      is_missing_text(Title),
    
    Flag_Missing_Year =
      is.na(Year),
    
    Flag_Missing_Authors =
      is_missing_text(Authors),
    
    Flag_Missing_Abstract =
      is_missing_text(Abstract),
    
    Flag_Missing_Author_Keywords =
      is_missing_text(Author_Keywords_Scopus) &
      is_missing_text(Author_Keywords_WoS),
    
    Flag_Retracted =
      str_detect(
        str_to_lower(
          coalesce(Document_Type, "")
        ),
        "retract"
      )
  )

# ------------------------------------------------------------
# 18. Save reports / diagnostic files
# ------------------------------------------------------------

write_csv(
  missingness_report,
  file.path(
    output_dir,
    "Step3_Missingness_Report.csv"
  ),
  na = ""
)

write_csv(
  database_missingness,
  file.path(
    output_dir,
    "Step3_Database_Missingness.csv"
  ),
  na = ""
)

write_csv(
  doi_duplicate_groups,
  file.path(
    output_dir,
    "Step3_DOI_Duplicate_Groups.csv"
  ),
  na = ""
)

write_csv(
  doi_duplicate_records,
  file.path(
    output_dir,
    "Step3_DOI_Duplicate_Records.csv"
  ),
  na = ""
)

write_csv(
  records_without_doi,
  file.path(
    output_dir,
    "Step3_Records_Without_DOI.csv"
  ),
  na = ""
)

write_csv(
  retraction_records,
  file.path(
    output_dir,
    "Step3_Retraction_Records.csv"
  ),
  na = ""
)

write_csv(
  document_type_summary,
  file.path(
    output_dir,
    "Step3_Document_Type_Summary.csv"
  ),
  na = ""
)

write_csv(
  language_summary,
  file.path(
    output_dir,
    "Step3_Language_Summary.csv"
  ),
  na = ""
)

write_csv(
  missing_title_records,
  file.path(
    output_dir,
    "Step3_Missing_Title_Records.csv"
  ),
  na = ""
)

write_csv(
  missing_author_records,
  file.path(
    output_dir,
    "Step3_Missing_Author_Records.csv"
  ),
  na = ""
)

write_csv(
  missing_abstract_records,
  file.path(
    output_dir,
    "Step3_Missing_Abstract_Records.csv"
  ),
  na = ""
)

write_csv(
  missing_keyword_records,
  file.path(
    output_dir,
    "Step3_Missing_Author_Keyword_Records.csv"
  ),
  na = ""
)

write_csv(
  quality_flags,
  file.path(
    output_dir,
    "Step3_Quality_Flags.csv"
  ),
  na = ""
)

# ------------------------------------------------------------
# 19. Complete TXT report
# ------------------------------------------------------------

report_file <- file.path(
  output_dir,
  "Step3_Record_Level_Quality_Audit_Report.txt"
)

sink(report_file)

cat("============================================================\n")
cat("STEP 3 REPORT\n")
cat("RECORD-LEVEL QUALITY AUDIT\n")
cat("============================================================\n\n")

cat("1. INPUT\n")
cat("------------------------------------------------------------\n")
cat(input_file, "\n\n")

cat("2. DATASET SIZE\n")
cat("------------------------------------------------------------\n")
cat("Records:", total_records, "\n")
cat("Columns:", total_columns, "\n\n")

cat("3. MISSINGNESS REPORT\n")
cat("------------------------------------------------------------\n")
print(missingness_report)

cat("\n4. DATABASE-SPECIFIC MISSINGNESS\n")
cat("------------------------------------------------------------\n")
print(database_missingness)

cat("\n5. DOI DUPLICATE DIAGNOSTICS\n")
cat("------------------------------------------------------------\n")
cat(
  "Number of duplicate DOI groups:",
  nrow(doi_duplicate_groups),
  "\n"
)

cat(
  "Number of records belonging to duplicate DOI groups:",
  nrow(doi_duplicate_records),
  "\n"
)

cat(
  "IMPORTANT: No records were deleted during Step 3.\n"
)

cat("\n6. RECORDS WITHOUT DOI\n")
cat("------------------------------------------------------------\n")
cat(
  "Records without DOI:",
  nrow(records_without_doi),
  "\n"
)

cat("\n7. RETRACTION AUDIT\n")
cat("------------------------------------------------------------\n")
cat(
  "Records containing 'retract' in Document_Type:",
  nrow(retraction_records),
  "\n"
)

if (nrow(retraction_records) > 0) {
  print(
    retraction_records %>%
      count(
        Source_Database,
        Document_Type,
        name = "Records"
      )
  )
}

cat("\n8. DOCUMENT TYPE SUMMARY\n")
cat("------------------------------------------------------------\n")
print(document_type_summary)

cat("\n9. LANGUAGE SUMMARY\n")
cat("------------------------------------------------------------\n")
print(language_summary)

cat("\n10. MISSING TITLE\n")
cat("------------------------------------------------------------\n")
cat(
  "Records:",
  nrow(missing_title_records),
  "\n"
)

cat("\n11. MISSING AUTHORS\n")
cat("------------------------------------------------------------\n")
cat(
  "Records:",
  nrow(missing_author_records),
  "\n"
)

cat("\n12. MISSING ABSTRACT\n")
cat("------------------------------------------------------------\n")
cat(
  "Records:",
  nrow(missing_abstract_records),
  "\n"
)

cat("\n13. MISSING AUTHOR KEYWORDS\n")
cat("------------------------------------------------------------\n")
cat(
  "Records with neither Scopus nor WoS Author Keywords:",
  nrow(missing_keyword_records),
  "\n"
)

cat("\n14. QUALITY FLAGS\n")
cat("------------------------------------------------------------\n")
cat(
  "Missing DOI:",
  sum(quality_flags$Flag_Missing_DOI),
  "\n"
)

cat(
  "Missing Title:",
  sum(quality_flags$Flag_Missing_Title),
  "\n"
)

cat(
  "Missing Year:",
  sum(quality_flags$Flag_Missing_Year),
  "\n"
)

cat(
  "Missing Authors:",
  sum(quality_flags$Flag_Missing_Authors),
  "\n"
)

cat(
  "Missing Abstract:",
  sum(quality_flags$Flag_Missing_Abstract),
  "\n"
)

cat(
  "Missing Author Keywords:",
  sum(quality_flags$Flag_Missing_Author_Keywords),
  "\n"
)

cat(
  "Retracted:",
  sum(quality_flags$Flag_Retracted),
  "\n"
)

cat("\n15. IMPORTANT METHODOLOGICAL NOTE\n")
cat("------------------------------------------------------------\n")
cat(
  "Step 3 is an audit stage only.\n"
)
cat(
  "No records were deleted or merged in this stage.\n"
)
cat(
  "Missing metadata does not automatically constitute a reason\n"
)
cat(
  "for record deletion.\n"
)
cat(
  "Duplicate records and retracted records will be evaluated\n"
)
cat(
  "systematically in subsequent cleaning stages.\n"
)

cat("\n============================================================\n")
cat("END OF STEP 3\n")
cat("============================================================\n")

sink()

# ------------------------------------------------------------
# 20. Console summary
# ------------------------------------------------------------

cat("\n============================================================\n")
cat("STEP 3 COMPLETED\n")
cat("============================================================\n")

cat("Records:", total_records, "\n")
cat("Columns:", total_columns, "\n")

cat(
  "Missing DOI:",
  sum(quality_flags$Flag_Missing_DOI),
  "\n"
)

cat(
  "Missing Title:",
  sum(quality_flags$Flag_Missing_Title),
  "\n"
)

cat(
  "Missing Year:",
  sum(quality_flags$Flag_Missing_Year),
  "\n"
)

cat(
  "Missing Authors:",
  sum(quality_flags$Flag_Missing_Authors),
  "\n"
)

cat(
  "Missing Abstract:",
  sum(quality_flags$Flag_Missing_Abstract),
  "\n"
)

cat(
  "Missing Author Keywords:",
  sum(quality_flags$Flag_Missing_Author_Keywords),
  "\n"
)

cat(
  "Retraction records:",
  sum(quality_flags$Flag_Retracted),
  "\n"
)

cat(
  "Duplicate DOI groups:",
  nrow(doi_duplicate_groups),
  "\n"
)

cat("\nOutput folder:\n")
cat(output_dir, "\n")