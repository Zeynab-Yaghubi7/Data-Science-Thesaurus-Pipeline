# ============================================================
# STEP 4B – INDEPENDENT FINAL VALIDATION – VERSION 2
# CORRECTED VALIDATION
# ============================================================

# -----------------------------
# 1. Packages
# -----------------------------

library(dplyr)

# -----------------------------
# 2. Paths
# -----------------------------

input_file <- paste0(
  "D:/Thesis/data/Step4_Deduplication_Metadata_Merging/",
  "Step4B_Final_Deduplication_Metadata_Merging/",
  "Scopus_WoS_Eligible_2000_2025_English_Article_Review_FINAL_DEDUP.csv"
)

validation_dir <- paste0(
  "D:/Thesis/data/Step4_Deduplication_Metadata_Merging/",
  "Step4B_Final_Deduplication_Metadata_Merging/",
  "Step4B_Independent_Validation_V2"
)

if (!dir.exists(validation_dir)) {
  dir.create(validation_dir, recursive = TRUE)
}

# -----------------------------
# 3. Read final Step4B file
# -----------------------------

step4b <- read.csv(
  input_file,
  stringsAsFactors = FALSE,
  check.names = FALSE,
  na.strings = c("", "NA")
)

# -----------------------------
# 4. Expected values
# -----------------------------

expected_records <- 15222
expected_columns <- 26

expected_input_records <- 24598
expected_scopus_records <- 13563
expected_wos_records <- 11035

expected_origin <- c(
  "Scopus" = 4191,
  "Scopus|WoS" = 9359,
  "WoS" = 1672
)

expected_retractions <- 22

expected_match_methods <- c(
  "DOI" = 9364,
  "Unique DOI" = 5194,
  "Unique Title-Year-FirstAuthor" = 346,
  "Unique WoS UT" = 316,
  "Unmatched" = 2
)

# -----------------------------
# 5. Basic structure
# -----------------------------

actual_records <- nrow(step4b)
actual_columns <- ncol(step4b)

required_columns <- c(
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

missing_columns <- setdiff(required_columns, names(step4b))
extra_columns <- setdiff(names(step4b), required_columns)

record_count_pass <- actual_records == expected_records
structure_pass <- actual_columns == expected_columns &&
  length(missing_columns) == 0 &&
  length(extra_columns) == 0

# -----------------------------
# 6. Final Article ID
# -----------------------------

missing_ids <- sum(
  is.na(step4b$Final_Article_ID) |
    trimws(step4b$Final_Article_ID) == ""
)

duplicate_ids <- sum(
  duplicated(
    step4b$Final_Article_ID[
      !is.na(step4b$Final_Article_ID) &
        trimws(step4b$Final_Article_ID) != ""
    ]
  )
)

id_pass <- missing_ids == 0 && duplicate_ids == 0

# -----------------------------
# 7. DOI
# -----------------------------

doi_clean <- trimws(as.character(step4b$DOI))

doi_present <- !is.na(doi_clean) &
  doi_clean != ""

doi_values <- doi_clean[doi_present]

duplicate_doi <- sum(duplicated(doi_values))

doi_pass <- duplicate_doi == 0

# -----------------------------
# 8. WoS UT
# -----------------------------

ut_clean <- trimws(as.character(step4b$UT_WoS))

ut_present <- !is.na(ut_clean) &
  ut_clean != ""

ut_values <- ut_clean[ut_present]

duplicate_ut <- sum(duplicated(ut_values))

ut_pass <- duplicate_ut == 0

# -----------------------------
# 9. Input record reconciliation
# -----------------------------

input_records <- suppressWarnings(
  as.numeric(step4b$Input_Records_Merged)
)

scopus_records <- suppressWarnings(
  as.numeric(step4b$Scopus_Records)
)

wos_records <- suppressWarnings(
  as.numeric(step4b$WoS_Records)
)

total_input_records <- sum(
  input_records,
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

missing_input_records <- sum(
  is.na(input_records)
)

invalid_input_records <- sum(
  !is.na(input_records) &
    (input_records < 1 |
       input_records != floor(input_records))
)

source_record_mismatch <- sum(
  !is.na(input_records) &
    !is.na(scopus_records) &
    !is.na(wos_records) &
    input_records != scopus_records + wos_records
)

input_reconciliation_pass <-
  total_input_records == expected_input_records &&
  total_scopus_records == expected_scopus_records &&
  total_wos_records == expected_wos_records &&
  missing_input_records == 0 &&
  invalid_input_records == 0 &&
  source_record_mismatch == 0

# -----------------------------
# 10. FINAL ARTICLE ORIGIN
# -----------------------------

# Normalize spaces around |
source_normalized <- trimws(
  gsub(
    "\\s*\\|\\s*",
    "|",
    as.character(step4b$Source_Database)
  )
)

origin_table <- table(
  source_normalized,
  useNA = "ifany"
)

origin_counts <- c(
  "Scopus" = ifelse(
    "Scopus" %in% names(origin_table),
    as.numeric(origin_table["Scopus"]),
    0
  ),
  "Scopus|WoS" = ifelse(
    "Scopus|WoS" %in% names(origin_table),
    as.numeric(origin_table["Scopus|WoS"]),
    0
  ),
  "WoS" = ifelse(
    "WoS" %in% names(origin_table),
    as.numeric(origin_table["WoS"]),
    0
  )
)

origin_pass <- all(
  origin_counts == expected_origin
)

# -----------------------------
# 11. Row-level source consistency
# -----------------------------

source_consistency_errors <- sum(
  source_normalized == "Scopus" &
    !(scopus_records >= 1 & wos_records == 0)
) +
  sum(
    source_normalized == "WoS" &
      !(scopus_records == 0 & wos_records >= 1)
  ) +
  sum(
    source_normalized == "Scopus|WoS" &
      !(scopus_records >= 1 & wos_records >= 1)
  )

source_consistency_pass <-
  source_consistency_errors == 0

# -----------------------------
# 12. Retraction
# -----------------------------

retraction_clean <- trimws(
  toupper(as.character(step4b$Retraction_Flag))
)

retraction_true <- sum(
  retraction_clean == "TRUE",
  na.rm = TRUE
)

retraction_false <- sum(
  retraction_clean == "FALSE",
  na.rm = TRUE
)

retraction_missing <- sum(
  is.na(step4b$Retraction_Flag) |
    trimws(as.character(step4b$Retraction_Flag)) == ""
)

retraction_pass <-
  retraction_true == expected_retractions &&
  retraction_missing == 0 &&
  retraction_true + retraction_false == actual_records

# -----------------------------
# 13. Year
# -----------------------------

year_numeric <- suppressWarnings(
  as.numeric(step4b$Year)
)

min_year <- min(
  year_numeric,
  na.rm = TRUE
)

max_year <- max(
  year_numeric,
  na.rm = TRUE
)

missing_year <- sum(
  is.na(year_numeric)
)

outside_year <- sum(
  !is.na(year_numeric) &
    (year_numeric < 2000 |
       year_numeric > 2025)
)

year_pass <-
  min_year == 2000 &&
  max_year == 2025 &&
  missing_year == 0 &&
  outside_year == 0

# -----------------------------
# 14. LANGUAGE – CORRECTED
# -----------------------------

language_raw <- trimws(
  as.character(step4b$Language)
)

# Convert all language entries to uppercase
language_upper <- toupper(language_raw)

# Split combined values by |
language_tokens <- unlist(
  strsplit(
    language_upper,
    "\\s*\\|\\s*"
  )
)

language_tokens <- trimws(language_tokens)

# Remove empty tokens
language_tokens <- language_tokens[
  language_tokens != "" &
    !is.na(language_tokens)
]

# Any language token other than ENGLISH?
non_english_tokens <- language_tokens[
  language_tokens != "ENGLISH"
]

non_english_token_count <- length(
  non_english_tokens
)

missing_language <- sum(
  is.na(language_raw) |
    language_raw == ""
)

# A record is valid if every language token is ENGLISH
record_language_valid <- sapply(
  language_upper,
  function(x) {
    if (is.na(x) || trimws(x) == "") {
      return(FALSE)
    }
    
    tokens <- trimws(
      unlist(
        strsplit(
          x,
          "\\s*\\|\\s*"
        )
      )
    )
    
    all(tokens == "ENGLISH")
  }
)

invalid_language_records <- sum(
  !record_language_valid
)

language_pass <-
  missing_language == 0 &&
  invalid_language_records == 0

# -----------------------------
# 15. Document Type
# -----------------------------

document_type <- toupper(
  trimws(
    as.character(step4b$Document_Type)
  )
)

invalid_document_type <- sum(
  !grepl(
    "ARTICLE|REVIEW",
    document_type
  )
)

missing_document_type <- sum(
  is.na(document_type) |
    document_type == ""
)

document_type_pass <-
  missing_document_type == 0 &&
  invalid_document_type == 0

# -----------------------------
# 16. Match Method
# -----------------------------

match_method <- trimws(
  as.character(step4b$Match_Method)
)

missing_match_method <- sum(
  is.na(match_method) |
    match_method == ""
)

match_method_table <- table(
  match_method,
  useNA = "ifany"
)

match_method_counts <- c(
  "DOI" = ifelse(
    "DOI" %in% names(match_method_table),
    as.numeric(match_method_table["DOI"]),
    0
  ),
  "Unique DOI" = ifelse(
    "Unique DOI" %in% names(match_method_table),
    as.numeric(match_method_table["Unique DOI"]),
    0
  ),
  "Unique Title-Year-FirstAuthor" = ifelse(
    "Unique Title-Year-FirstAuthor" %in% names(match_method_table),
    as.numeric(match_method_table["Unique Title-Year-FirstAuthor"]),
    0
  ),
  "Unique WoS UT" = ifelse(
    "Unique WoS UT" %in% names(match_method_table),
    as.numeric(match_method_table["Unique WoS UT"]),
    0
  ),
  "Unmatched" = ifelse(
    "Unmatched" %in% names(match_method_table),
    as.numeric(match_method_table["Unmatched"]),
    0
  )
)

match_method_pass <-
  missing_match_method == 0 &&
  all(
    match_method_counts ==
      expected_match_methods
  )

# -----------------------------
# 17. Critical field missingness
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

missingness_results <- data.frame(
  Field = character(),
  Missing = integer(),
  Available = integer(),
  Available_Percent = numeric(),
  stringsAsFactors = FALSE
)

for (field in critical_fields) {
  
  x <- step4b[[field]]
  
  missing_n <- sum(
    is.na(x) |
      trimws(as.character(x)) == ""
  )
  
  available_n <- actual_records - missing_n
  
  available_pct <- round(
    available_n / actual_records * 100,
    2
  )
  
  missingness_results <- rbind(
    missingness_results,
    data.frame(
      Field = field,
      Missing = missing_n,
      Available = available_n,
      Available_Percent = available_pct,
      stringsAsFactors = FALSE
    )
  )
}

# -----------------------------
# 18. Normalized title duplicates
# Informational only
# -----------------------------

title_clean <- toupper(
  trimws(
    as.character(step4b$Title)
  )
)

title_normalized <- gsub(
  "[^A-Z0-9]+",
  " ",
  title_clean
)

title_normalized <- gsub(
  "\\s+",
  " ",
  title_normalized
)

title_normalized <- trimws(
  title_normalized
)

title_valid <- !is.na(title_normalized) &
  title_normalized != ""

title_table <- table(
  title_normalized[title_valid]
)

duplicate_title_groups <- sum(
  title_table > 1
)

duplicate_title_records <- sum(
  title_table[title_table > 1]
)

# Informational only – not a failure
# -----------------------------
# 19. Overall validation
# -----------------------------

overall_pass <-
  structure_pass &&
  record_count_pass &&
  id_pass &&
  doi_pass &&
  ut_pass &&
  input_reconciliation_pass &&
  origin_pass &&
  source_consistency_pass &&
  retraction_pass &&
  year_pass &&
  language_pass &&
  document_type_pass &&
  match_method_pass

# -----------------------------
# 20. Console summary
# -----------------------------

cat("\n")
cat("============================================================\n")
cat("STEP 4B – INDEPENDENT FINAL VALIDATION – VERSION 2\n")
cat("============================================================\n\n")

cat("Records:", actual_records, "\n")
cat("Columns:", actual_columns, "\n\n")

cat("Record count:", record_count_pass, "\n")
cat("Structure:", structure_pass, "\n")
cat("Duplicate Final_Article_ID:", duplicate_ids, "\n")
cat("Duplicate DOI:", duplicate_doi, "\n")
cat("Duplicate WoS UT:", duplicate_ut, "\n\n")

cat(
  "Input records represented:",
  total_input_records,
  "/",
  expected_input_records,
  "\n"
)

cat(
  "Scopus records represented:",
  total_scopus_records,
  "/",
  expected_scopus_records,
  "\n"
)

cat(
  "WoS records represented:",
  total_wos_records,
  "/",
  expected_wos_records,
  "\n\n"
)

cat("FINAL ARTICLE ORIGIN:\n")
print(
  data.frame(
    Source_Database = names(origin_counts),
    Expected = as.numeric(expected_origin),
    Actual = as.numeric(origin_counts),
    Difference =
      as.numeric(origin_counts) -
      as.numeric(expected_origin)
  )
)

cat(
  "\nSource database validation:",
  origin_pass,
  "\n"
)

cat(
  "Source consistency errors:",
  source_consistency_errors,
  "\n"
)

cat(
  "Source consistency validation:",
  source_consistency_pass,
  "\n\n"
)

cat(
  "Retractions:",
  retraction_true,
  "/ expected",
  expected_retractions,
  "\n"
)

cat(
  "Year range:",
  min_year,
  "-",
  max_year,
  "\n"
)

cat(
  "Invalid/non-English language records:",
  invalid_language_records,
  "\n"
)

cat(
  "Missing language:",
  missing_language,
  "\n"
)

cat(
  "Language validation:",
  language_pass,
  "\n\n"
)

cat("MATCH METHOD:\n")
print(
  data.frame(
    Match_Method = names(match_method_counts),
    Expected = as.numeric(expected_match_methods),
    Actual = as.numeric(match_method_counts),
    Difference =
      as.numeric(match_method_counts) -
      as.numeric(expected_match_methods)
  )
)

cat(
  "\nMatch method validation:",
  match_method_pass,
  "\n"
)

cat(
  "\nNormalized title duplicate groups:",
  duplicate_title_groups,
  "(informational only)\n"
)

cat(
  "Normalized title duplicate records:",
  duplicate_title_records,
  "(informational only)\n"
)

cat("\n============================================================\n")

if (overall_pass) {
  cat("OVERALL STATUS: PASS\n")
} else {
  cat("OVERALL STATUS: CHECK REQUIRED\n")
}

cat("============================================================\n")

# -----------------------------
# 21. Save origin summary
# -----------------------------

origin_summary <- data.frame(
  Source_Database = names(origin_counts),
  Expected_Count = as.numeric(expected_origin),
  Actual_Count = as.numeric(origin_counts),
  Difference =
    as.numeric(origin_counts) -
    as.numeric(expected_origin),
  stringsAsFactors = FALSE
)

write.csv(
  origin_summary,
  file.path(
    validation_dir,
    "Step4B_V2_Source_Database_Validation.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

# -----------------------------
# 22. Save match method summary
# -----------------------------

match_method_summary <- data.frame(
  Match_Method = names(match_method_counts),
  Expected_Count = as.numeric(expected_match_methods),
  Actual_Count = as.numeric(match_method_counts),
  Difference =
    as.numeric(match_method_counts) -
    as.numeric(expected_match_methods),
  stringsAsFactors = FALSE
)

write.csv(
  match_method_summary,
  file.path(
    validation_dir,
    "Step4B_V2_Match_Method_Validation.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

# -----------------------------
# 23. Save missingness
# -----------------------------

write.csv(
  missingness_results,
  file.path(
    validation_dir,
    "Step4B_V2_Critical_Field_Missingness.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

# -----------------------------
# 24. Save language diagnostics
# -----------------------------

language_diagnostic <- data.frame(
  Language_Value = names(
    table(
      language_raw,
      useNA = "ifany"
    )
  ),
  Count = as.numeric(
    table(
      language_raw,
      useNA = "ifany"
    )
  ),
  stringsAsFactors = FALSE
)

write.csv(
  language_diagnostic,
  file.path(
    validation_dir,
    "Step4B_V2_Language_Diagnostics.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

# -----------------------------
# 25. Save validation summary
# -----------------------------

validation_summary <- data.frame(
  Check = c(
    "Record count",
    "Structure",
    "Final Article ID uniqueness",
    "DOI uniqueness",
    "WoS UT uniqueness",
    "Input reconciliation",
    "Source database",
    "Source consistency",
    "Retraction",
    "Year",
    "Language",
    "Document type",
    "Match method",
    "Overall"
  ),
  Status = c(
    record_count_pass,
    structure_pass,
    id_pass,
    doi_pass,
    ut_pass,
    input_reconciliation_pass,
    origin_pass,
    source_consistency_pass,
    retraction_pass,
    year_pass,
    language_pass,
    document_type_pass,
    match_method_pass,
    overall_pass
  ),
  stringsAsFactors = FALSE
)

write.csv(
  validation_summary,
  file.path(
    validation_dir,
    "Step4B_V2_Validation_Summary.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

# -----------------------------
# 26. Full TXT report
# -----------------------------

report_lines <- c(
  "============================================================",
  "STEP 4B – INDEPENDENT FINAL VALIDATION – VERSION 2",
  "============================================================",
  "",
  paste("Validation date:", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  "",
  "1. INPUT FILE",
  paste("Input:", input_file),
  "",
  "2. BASIC STRUCTURE",
  paste("Expected records:", expected_records),
  paste("Actual records:", actual_records),
  paste("Record count PASS:", record_count_pass),
  paste("Expected columns:", expected_columns),
  paste("Actual columns:", actual_columns),
  paste("Structure PASS:", structure_pass),
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
  paste("Missing IDs:", missing_ids),
  paste("Duplicate IDs:", duplicate_ids),
  paste("ID uniqueness PASS:", id_pass),
  "",
  "4. DOI",
  paste("Records with DOI:", sum(doi_present)),
  paste("Records without DOI:", sum(!doi_present)),
  paste("Duplicate DOI values:", duplicate_doi),
  paste("DOI uniqueness PASS:", doi_pass),
  "",
  "5. WoS UT",
  paste("Records with WoS UT:", sum(ut_present)),
  paste("Duplicate WoS UT values:", duplicate_ut),
  paste("WoS UT uniqueness PASS:", ut_pass),
  "",
  "6. INPUT RECORD RECONCILIATION",
  paste("Total input records represented:", total_input_records),
  paste("Expected input records:", expected_input_records),
  paste("Scopus records represented:", total_scopus_records),
  paste("Expected Scopus records:", expected_scopus_records),
  paste("WoS records represented:", total_wos_records),
  paste("Expected WoS records:", expected_wos_records),
  paste("Missing Input_Records_Merged:", missing_input_records),
  paste("Invalid Input_Records_Merged:", invalid_input_records),
  paste("Rows with Scopus_Records + WoS_Records mismatch:",
        source_record_mismatch),
  paste("Input reconciliation PASS:", input_reconciliation_pass),
  "",
  "7. FINAL ARTICLE ORIGIN",
  paste(
    "Scopus:",
    origin_counts["Scopus"],
    "expected:",
    expected_origin["Scopus"]
  ),
  paste(
    "Scopus | WoS:",
    origin_counts["Scopus|WoS"],
    "expected:",
    expected_origin["Scopus|WoS"]
  ),
  paste(
    "WoS:",
    origin_counts["WoS"],
    "expected:",
    expected_origin["WoS"]
  ),
  paste("Source database PASS:", origin_pass),
  "",
  "8. ROW-LEVEL SOURCE CONSISTENCY",
  paste("Source consistency errors:", source_consistency_errors),
  paste("Source consistency PASS:", source_consistency_pass),
  "",
  "9. RETRACTION",
  paste("Retraction TRUE:", retraction_true),
  paste("Retraction FALSE:", retraction_false),
  paste("Retraction missing:", retraction_missing),
  paste("Retraction validation PASS:", retraction_pass),
  "",
  "10. YEAR",
  paste("Minimum year:", min_year),
  paste("Maximum year:", max_year),
  paste("Missing year:", missing_year),
  paste("Outside 2000–2025:", outside_year),
  paste("Year validation PASS:", year_pass),
  "",
  "11. LANGUAGE – CORRECTED",
  paste("Missing language:", missing_language),
  paste("Invalid/non-English language records:",
        invalid_language_records),
  paste("Non-English language tokens:",
        non_english_token_count),
  paste("Language validation PASS:", language_pass),
  "",
  "NOTE: Combined values such as 'English | ENGLISH' are",
  "treated as valid when all language tokens are English.",
  "",
  "12. DOCUMENT TYPE",
  paste("Missing document type:", missing_document_type),
  paste("Invalid document type:", invalid_document_type),
  paste("Document type validation PASS:", document_type_pass),
  "",
  "13. MATCH METHOD",
  paste("Missing Match_Method:", missing_match_method),
  paste("Match method validation PASS:", match_method_pass),
  "",
  "Match method distribution:"
)

for (i in seq_along(match_method_counts)) {
  report_lines <- c(
    report_lines,
    paste(
      names(match_method_counts)[i],
      ":",
      match_method_counts[i],
      "expected:",
      expected_match_methods[i]
    )
  )
}

report_lines <- c(
  report_lines,
  "",
  "14. TITLE DUPLICATES",
  paste("Duplicate normalized title groups:",
        duplicate_title_groups),
  paste("Duplicate normalized title records:",
        duplicate_title_records),
  "NOTE: Duplicate normalized titles are informational only",
  "and are not treated as automatic duplicate-article errors.",
  "",
  "15. CRITICAL FIELD MISSINGNESS"
)

for (i in seq_len(nrow(missingness_results))) {
  report_lines <- c(
    report_lines,
    paste(
      missingness_results$Field[i],
      ": Missing =",
      missingness_results$Missing[i],
      "| Available =",
      missingness_results$Available[i],
      "| Available % =",
      missingness_results$Available_Percent[i]
    )
  )
}

report_lines <- c(
  report_lines,
  "",
  "16. OVERALL VALIDATION",
  paste("Structure:", structure_pass),
  paste("Record count:", record_count_pass),
  paste("Final Article ID uniqueness:", id_pass),
  paste("DOI uniqueness:", doi_pass),
  paste("WoS UT uniqueness:", ut_pass),
  paste("Input reconciliation:", input_reconciliation_pass),
  paste("Source database:", origin_pass),
  paste("Source consistency:", source_consistency_pass),
  paste("Retraction:", retraction_pass),
  paste("Year:", year_pass),
  paste("Language:", language_pass),
  paste("Document type:", document_type_pass),
  paste("Match method:", match_method_pass),
  "",
  paste(
    "OVERALL STATUS:",
    ifelse(
      overall_pass,
      "PASS",
      "CHECK REQUIRED"
    )
  ),
  "",
  "IMPORTANT METHODOLOGICAL NOTE:",
  "This validation checks structural integrity, record reconciliation,",
  "deduplication integrity, metadata consistency and preservation",
  "of the verified Step4B final corpus.",
  "",
  "It does NOT calculate machine-learning accuracy, precision, recall,",
  "or statistical confidence intervals, because Step4B is a data",
  "preparation and deduplication procedure rather than a predictive",
  "classification model.",
  "",
  "The original Step4B final file was not modified.",
  "The previous Validation Version 1 was not modified.",
  "This is an independent corrected validation of the same final file.",
  "============================================================"
)

writeLines(
  report_lines,
  file.path(
    validation_dir,
    "Step4B_Independent_Final_Validation_V2_Report.txt"
  ),
  useBytes = TRUE
)

# -----------------------------
# 27. Final console message
# -----------------------------

cat("\n")
cat("============================================================\n")

if (overall_pass) {
  cat("STEP 4B INDEPENDENT VALIDATION V2: PASS\n")
} else {
  cat("STEP 4B INDEPENDENT VALIDATION V2: CHECK REQUIRED\n")
}

cat("============================================================\n")

cat(
  "\nValidation folder:\n",
  validation_dir,
  "\n"
)

cat("\nGenerated files:\n")
print(
  list.files(
    validation_dir
  )
)