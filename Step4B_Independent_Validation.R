# ============================================================
# STEP 4B – INDEPENDENT FINAL VALIDATION
# ============================================================

# -----------------------------
# 1. Paths
# -----------------------------

input_file <- paste0(
  "D:/Thesis/data/Step4_Deduplication_Metadata_Merging/",
  "Step4B_Final_Deduplication_Metadata_Merging/",
  "Scopus_WoS_Eligible_2000_2025_English_Article_Review_FINAL_DEDUP.csv"
)

validation_dir <- paste0(
  "D:/Thesis/data/Step4_Deduplication_Metadata_Merging/",
  "Step4B_Final_Deduplication_Metadata_Merging/",
  "Step4B_Independent_Validation"
)

if (!dir.exists(validation_dir)) {
  dir.create(validation_dir, recursive = TRUE)
}

cat("============================================================\n")
cat("STEP 4B – INDEPENDENT FINAL VALIDATION\n")
cat("============================================================\n\n")


# -----------------------------
# 2. Read final Step4B file
# -----------------------------

step4b <- read.csv(
  input_file,
  stringsAsFactors = FALSE,
  check.names = FALSE,
  fileEncoding = "UTF-8",
  na.strings = c("", "NA")
)

cat("File successfully loaded.\n")
cat("Records:", nrow(step4b), "\n")
cat("Columns:", ncol(step4b), "\n\n")


# -----------------------------
# 3. Expected structure
# -----------------------------

expected_columns <- c(
  "Final_Article_ID",
  "Source_Database",
  "Original_IDs",
  "DOI",
  "UT_WoS",
  "Title",
  "Year",
  "Authors",
  "Abstract",
  "Author_Keywords_Scopus",
  "Author_Keywords_WoS",
  "Author_Keywords_Combined",
  "Index_Keywords_Scopus",
  "Keywords_Plus_WoS",
  "Cited_By_Scopus",
  "Cited_By_WoS",
  "References_Scopus",
  "References_WoS",
  "Source_Title",
  "Document_Type",
  "Language",
  "Retraction_Flag",
  "Input_Records_Merged",
  "Scopus_Records",
  "WoS_Records",
  "Match_Method"
)

missing_columns <- setdiff(expected_columns, names(step4b))
extra_columns <- setdiff(names(step4b), expected_columns)
wrong_order <- !identical(names(step4b), expected_columns)

structure_status <- (
  length(missing_columns) == 0 &&
    length(extra_columns) == 0 &&
    !wrong_order
)


# -----------------------------
# 4. Basic record count
# -----------------------------

expected_records <- 15222
actual_records <- nrow(step4b)

record_count_pass <- actual_records == expected_records


# -----------------------------
# 5. Final Article ID validation
# -----------------------------

id_missing <- sum(
  is.na(step4b$Final_Article_ID) |
    trimws(step4b$Final_Article_ID) == ""
)

id_duplicates <- sum(
  duplicated(step4b$Final_Article_ID) &
    !is.na(step4b$Final_Article_ID)
)

id_unique_pass <- (
  id_missing == 0 &&
    id_duplicates == 0
)


# -----------------------------
# 6. DOI validation
# -----------------------------

doi_clean <- tolower(trimws(step4b$DOI))

doi_nonmissing <- !is.na(doi_clean) &
  doi_clean != ""

doi_duplicate_count <- sum(
  duplicated(doi_clean[doi_nonmissing])
)

doi_duplicate_pass <- doi_duplicate_count == 0


# -----------------------------
# 7. WoS UT validation
# -----------------------------

ut_clean <- toupper(trimws(step4b$UT_WoS))

ut_nonmissing <- !is.na(ut_clean) &
  ut_clean != ""

ut_duplicate_count <- sum(
  duplicated(ut_clean[ut_nonmissing])
)

ut_duplicate_pass <- ut_duplicate_count == 0


# -----------------------------
# 8. Input record reconciliation
# -----------------------------

input_merged <- suppressWarnings(
  as.numeric(step4b$Input_Records_Merged)
)

scopus_records <- suppressWarnings(
  as.numeric(step4b$Scopus_Records)
)

wos_records <- suppressWarnings(
  as.numeric(step4b$WoS_Records)
)

input_missing <- sum(is.na(input_merged))
input_invalid <- sum(
  !is.na(input_merged) &
    (input_merged < 1 | input_merged != floor(input_merged))
)

rowwise_source_sum_error <- sum(
  !is.na(input_merged) &
    !is.na(scopus_records) &
    !is.na(wos_records) &
    (scopus_records + wos_records != input_merged)
)

total_input_records <- sum(
  input_merged,
  na.rm = TRUE
)

total_scopus_records <- sum(
  scopus_records,
  na.rm = TRUE
)

total_wos_records <- sum(
  wos_records,
  na.rm = TRUE
)

input_reconciliation_pass <- (
  input_missing == 0 &&
    input_invalid == 0 &&
    rowwise_source_sum_error == 0 &&
    total_input_records == 24598 &&
    total_scopus_records == 13563 &&
    total_wos_records == 11035
)


# -----------------------------
# 9. Source Database validation
# -----------------------------

source_summary <- as.data.frame(
  table(step4b$Source_Database),
  stringsAsFactors = FALSE
)

names(source_summary) <- c(
  "Source_Database",
  "Count"
)

expected_source <- data.frame(
  Source_Database = c(
    "Scopus|WoS",
    "Scopus",
    "WoS"
  ),
  Expected_Count = c(
    9359,
    4191,
    1672
  ),
  stringsAsFactors = FALSE
)

source_validation <- merge(
  expected_source,
  source_summary,
  by = "Source_Database",
  all = TRUE
)

source_validation$Expected_Count[
  is.na(source_validation$Expected_Count)
] <- 0

source_validation$Count[
  is.na(source_validation$Count)
] <- 0

source_validation$Difference <-
  source_validation$Count -
  source_validation$Expected_Count

source_database_pass <- all(
  source_validation$Difference == 0
)


# -----------------------------
# 10. Source consistency by row
# -----------------------------

source_consistency_errors <- 0

for (i in seq_len(nrow(step4b))) {
  
  source <- step4b$Source_Database[i]
  
  s_count <- scopus_records[i]
  w_count <- wos_records[i]
  
  if (source == "Scopus" &&
      !(s_count > 0 && w_count == 0)) {
    source_consistency_errors <- source_consistency_errors + 1
  }
  
  if (source == "WoS" &&
      !(s_count == 0 && w_count > 0)) {
    source_consistency_errors <- source_consistency_errors + 1
  }
  
  if (source == "Scopus|WoS" &&
      !(s_count > 0 && w_count > 0)) {
    source_consistency_errors <- source_consistency_errors + 1
  }
}

source_consistency_pass <-
  source_consistency_errors == 0


# -----------------------------
# 11. Retraction validation
# -----------------------------

retraction_flag <- toupper(
  trimws(as.character(step4b$Retraction_Flag))
)

retraction_true <- sum(
  retraction_flag == "TRUE",
  na.rm = TRUE
)

retraction_false <- sum(
  retraction_flag == "FALSE",
  na.rm = TRUE
)

retraction_missing <- sum(
  is.na(retraction_flag) |
    retraction_flag == ""
)

retraction_pass <- (
  retraction_true == 22 &&
    retraction_false == 15200 &&
    retraction_missing == 0
)


# -----------------------------
# 12. Year validation
# -----------------------------

year_numeric <- suppressWarnings(
  as.numeric(step4b$Year)
)

year_missing <- sum(is.na(year_numeric))

year_min <- min(
  year_numeric,
  na.rm = TRUE
)

year_max <- max(
  year_numeric,
  na.rm = TRUE
)

year_outside_range <- sum(
  !is.na(year_numeric) &
    (year_numeric < 2000 | year_numeric > 2025)
)

year_pass <- (
  year_missing == 0 &&
    year_min == 2000 &&
    year_max == 2025 &&
    year_outside_range == 0
)


# -----------------------------
# 13. Language validation
# -----------------------------

language_clean <- toupper(
  trimws(as.character(step4b$Language))
)

language_missing <- sum(
  is.na(language_clean) |
    language_clean == ""
)

non_english <- sum(
  !is.na(language_clean) &
    language_clean != "" &
    language_clean != "ENGLISH"
)

language_pass <- (
  language_missing == 0 &&
    non_english == 0
)


# -----------------------------
# 14. Document type validation
# -----------------------------

document_type_clean <- toupper(
  trimws(as.character(step4b$Document_Type))
)

document_type_missing <- sum(
  is.na(document_type_clean) |
    document_type_clean == ""
)

invalid_document_type <- sum(
  !is.na(document_type_clean) &
    document_type_clean != "" &
    !grepl(
      "ARTICLE|REVIEW",
      document_type_clean
    )
)

document_type_pass <- (
  document_type_missing == 0 &&
    invalid_document_type == 0
)


# -----------------------------
# 15. Critical field missingness
# -----------------------------

critical_fields <- c(
  "Final_Article_ID",
  "DOI",
  "Title",
  "Year",
  "Authors",
  "Abstract",
  "Author_Keywords_Combined",
  "Source_Title",
  "Document_Type",
  "Language"
)

missingness_table <- data.frame(
  Field = critical_fields,
  Missing = sapply(
    step4b[critical_fields],
    function(x) {
      sum(
        is.na(x) |
          trimws(as.character(x)) == ""
      )
    }
  ),
  stringsAsFactors = FALSE
)

missingness_table$Available <-
  nrow(step4b) -
  missingness_table$Missing

missingness_table$Available_Percent <-
  round(
    100 *
      missingness_table$Available /
      nrow(step4b),
    2
  )


# -----------------------------
# 16. Match method summary
# -----------------------------

match_method_summary <- as.data.frame(
  table(
    step4b$Match_Method,
    useNA = "ifany"
  ),
  stringsAsFactors = FALSE
)

names(match_method_summary) <- c(
  "Match_Method",
  "Count"
)


# -----------------------------
# 17. Match method missingness
# -----------------------------

match_method_missing <- sum(
  is.na(step4b$Match_Method) |
    trimws(as.character(step4b$Match_Method)) == ""
)

match_method_pass <- match_method_missing == 0


# -----------------------------
# 18. Normalized title duplicates
# -----------------------------

normalize_title <- function(x) {
  
  x <- tolower(as.character(x))
  
  x <- gsub(
    "[[:punct:]]",
    " ",
    x
  )
  
  x <- gsub(
    "[[:space:]]+",
    " ",
    x
  )
  
  x <- trimws(x)
  
  x
}

title_clean <- normalize_title(step4b$Title)

title_valid <- !is.na(title_clean) &
  title_clean != ""

title_duplicate_groups <- length(
  unique(
    title_clean[
      duplicated(title_clean) &
        title_valid
    ]
  )
)

title_duplicate_records <- sum(
  duplicated(title_clean) &
    title_valid
)

# Informational only:
# title duplicates are NOT treated as errors.


# -----------------------------
# 19. Input record distribution
# -----------------------------

input_distribution <- as.data.frame(
  table(input_merged),
  stringsAsFactors = FALSE
)

names(input_distribution) <- c(
  "Input_Records_Merged",
  "Final_Article_Count"
)


# -----------------------------
# 20. Final article origin
# -----------------------------

origin_summary <- source_summary


# -----------------------------
# 21. Overall validation
# -----------------------------

all_pass <- all(
  structure_status,
  record_count_pass,
  id_unique_pass,
  doi_duplicate_pass,
  ut_duplicate_pass,
  input_reconciliation_pass,
  source_database_pass,
  source_consistency_pass,
  retraction_pass,
  year_pass,
  language_pass,
  document_type_pass,
  match_method_pass
)


# -----------------------------
# 22. Save CSV diagnostics
# -----------------------------

write.csv(
  source_validation,
  file.path(
    validation_dir,
    "Step4B_Validation_Source_Database.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

write.csv(
  missingness_table,
  file.path(
    validation_dir,
    "Step4B_Validation_Missingness.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

write.csv(
  match_method_summary,
  file.path(
    validation_dir,
    "Step4B_Validation_Match_Method.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

write.csv(
  input_distribution,
  file.path(
    validation_dir,
    "Step4B_Validation_Input_Record_Distribution.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)


# -----------------------------
# 23. Create validation report
# -----------------------------

report <- c(
  
  "============================================================",
  "STEP 4B – INDEPENDENT FINAL VALIDATION REPORT",
  "============================================================",
  "",
  paste(
    "Validation date:",
    format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  ),
  "",
  "1. INPUT FILE",
  paste("Input:", input_file),
  "",
  "2. BASIC STRUCTURE",
  paste("Expected records:", expected_records),
  paste("Actual records:", actual_records),
  paste("Record count PASS:", record_count_pass),
  paste("Expected columns:", length(expected_columns)),
  paste("Actual columns:", ncol(step4b)),
  paste("Structure PASS:", structure_status),
  "",
  "Missing columns:",
  ifelse(
    length(missing_columns) == 0,
    "None",
    paste(missing_columns, collapse = ", ")
  ),
  "",
  "Extra columns:",
  ifelse(
    length(extra_columns) == 0,
    "None",
    paste(extra_columns, collapse = ", ")
  ),
  "",
  "3. FINAL ARTICLE ID",
  paste("Missing IDs:", id_missing),
  paste("Duplicate IDs:", id_duplicates),
  paste("ID uniqueness PASS:", id_unique_pass),
  "",
  "4. DOI",
  paste("Records with DOI:", sum(doi_nonmissing)),
  paste("Records without DOI:", sum(!doi_nonmissing)),
  paste("Duplicate DOI values:", doi_duplicate_count),
  paste("DOI uniqueness PASS:", doi_duplicate_pass),
  "",
  "5. WoS UT",
  paste("Records with WoS UT:", sum(ut_nonmissing)),
  paste("Duplicate WoS UT values:", ut_duplicate_count),
  paste("WoS UT uniqueness PASS:", ut_duplicate_pass),
  "",
  "6. INPUT RECORD RECONCILIATION",
  paste("Total input records represented:", total_input_records),
  paste("Expected input records:", 24598),
  paste("Scopus records represented:", total_scopus_records),
  paste("Expected Scopus records:", 13563),
  paste("WoS records represented:", total_wos_records),
  paste("Expected WoS records:", 11035),
  paste("Missing Input_Records_Merged:", input_missing),
  paste("Invalid Input_Records_Merged:", input_invalid),
  paste(
    "Rows with Scopus_Records + WoS_Records mismatch:",
    rowwise_source_sum_error
  ),
  paste(
    "Input reconciliation PASS:",
    input_reconciliation_pass
  ),
  "",
  "7. FINAL ARTICLE ORIGIN",
  capture.output(print(source_validation)),
  "",
  paste(
    "Source database PASS:",
    source_database_pass
  ),
  "",
  "8. ROW-LEVEL SOURCE CONSISTENCY",
  paste(
    "Source consistency errors:",
    source_consistency_errors
  ),
  paste(
    "Source consistency PASS:",
    source_consistency_pass
  ),
  "",
  "9. RETRACTION",
  paste("Retraction TRUE:", retraction_true),
  paste("Retraction FALSE:", retraction_false),
  paste("Retraction missing:", retraction_missing),
  paste("Retraction validation PASS:", retraction_pass),
  "",
  "10. YEAR",
  paste("Minimum year:", year_min),
  paste("Maximum year:", year_max),
  paste("Missing year:", year_missing),
  paste("Outside 2000–2025:", year_outside_range),
  paste("Year validation PASS:", year_pass),
  "",
  "11. LANGUAGE",
  paste("Missing language:", language_missing),
  paste("Non-English records:", non_english),
  paste("Language validation PASS:", language_pass),
  "",
  "12. DOCUMENT TYPE",
  paste("Missing document type:", document_type_missing),
  paste("Invalid document type:", invalid_document_type),
  paste(
    "Document type validation PASS:",
    document_type_pass
  ),
  "",
  "13. MATCH METHOD",
  paste("Missing Match_Method:", match_method_missing),
  paste("Match method validation PASS:", match_method_pass),
  "",
  "Match method distribution:",
  capture.output(print(match_method_summary)),
  "",
  "14. TITLE DUPLICATES",
  paste(
    "Duplicate normalized title groups:",
    title_duplicate_groups
  ),
  paste(
    "Duplicate normalized title records:",
    title_duplicate_records
  ),
  "NOTE: Duplicate normalized titles are informational and are not",
  "treated as automatic duplicate-article errors.",
  "",
  "15. CRITICAL FIELD MISSINGNESS",
  capture.output(print(missingness_table)),
  "",
  "16. OVERALL VALIDATION",
  paste("Structure:", structure_status),
  paste("Record count:", record_count_pass),
  paste("Final Article ID uniqueness:", id_unique_pass),
  paste("DOI uniqueness:", doi_duplicate_pass),
  paste("WoS UT uniqueness:", ut_duplicate_pass),
  paste("Input reconciliation:", input_reconciliation_pass),
  paste("Source database:", source_database_pass),
  paste("Source consistency:", source_consistency_pass),
  paste("Retraction:", retraction_pass),
  paste("Year:", year_pass),
  paste("Language:", language_pass),
  paste("Document type:", document_type_pass),
  paste("Match method:", match_method_pass),
  "",
  paste("OVERALL STATUS:", ifelse(all_pass, "PASS", "CHECK REQUIRED")),
  "",
  "IMPORTANT METHODOLOGICAL NOTE:",
  "This validation checks structural integrity, record reconciliation,",
  "deduplication integrity, metadata consistency and preservation of",
  "the verified Step4B final corpus.",
  "",
  "It does NOT calculate machine-learning accuracy, precision, recall,",
  "or statistical confidence intervals, because Step4B is a data",
  "preparation and deduplication procedure rather than a predictive",
  "classification model.",
  "",
  "Original Step4B final file was not modified.",
  "============================================================"
)

writeLines(
  report,
  file.path(
    validation_dir,
    "Step4B_Independent_Final_Validation_Report.txt"
  ),
  useBytes = TRUE
)


# -----------------------------
# 24. Console summary
# -----------------------------

cat("\n============================================================\n")
cat("STEP 4B INDEPENDENT VALIDATION COMPLETED\n")
cat("============================================================\n\n")

cat("Actual records:", actual_records, "\n")
cat("Expected records:", expected_records, "\n")

cat("Duplicate Final_Article_ID:", id_duplicates, "\n")
cat("Duplicate DOI:", doi_duplicate_count, "\n")
cat("Duplicate WoS UT:", ut_duplicate_count, "\n")

cat(
  "Input records represented:",
  total_input_records,
  "/ 24598\n"
)

cat(
  "Scopus records represented:",
  total_scopus_records,
  "/ 13563\n"
)

cat(
  "WoS records represented:",
  total_wos_records,
  "/ 11035\n"
)

cat(
  "Retractions:",
  retraction_true,
  "/ expected 22\n"
)

cat(
  "Normalized title duplicate groups:",
  title_duplicate_groups,
  "(informational)\n"
)

cat("\n--------------------------------------------\n")
cat(
  "OVERALL STATUS:",
  ifelse(all_pass, "PASS", "CHECK REQUIRED"),
  "\n"
)
cat("--------------------------------------------\n")

cat(
  "\nValidation folder:\n",
  validation_dir,
  "\n"
)