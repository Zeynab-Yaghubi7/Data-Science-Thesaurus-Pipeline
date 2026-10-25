# ============================================================
# STEP 5B – MANUAL RELEVANCE INVESTIGATION
# Records without explicit "data science / data sciences"
# ============================================================

library(readr)
library(dplyr)
library(stringr)

# ------------------------------------------------------------
# 1. Paths
# ------------------------------------------------------------

input_file <- paste0(
  "D:/Thesis/data/Step5_Relevance_Eligibility_Audit/",
  "Step5A_Data_Science_Screening/",
  "Step5A_Data_Science_Screening_Audit.csv"
)

output_dir <- paste0(
  "D:/Thesis/data/Step5_Relevance_Eligibility_Audit/",
  "Step5B_Manual_Relevance_Investigation"
)

if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

# ------------------------------------------------------------
# 2. Read official Step5A
# ------------------------------------------------------------

df <- read_csv(
  input_file,
  show_col_types = FALSE
)

input_records <- nrow(df)
input_columns <- ncol(df)

# ------------------------------------------------------------
# 3. Safe text function
# ------------------------------------------------------------

safe_text <- function(x) {
  
  x <- as.character(x)
  x[is.na(x)] <- ""
  
  x
}

# ------------------------------------------------------------
# 4. Select only records without explicit
#    Data Science / Data Sciences phrase
# ------------------------------------------------------------

investigation <- df %>%
  filter(
    Data_Science_Match_Any_Field == FALSE
  )

investigation_records <- nrow(investigation)

# ------------------------------------------------------------
# 5. Additional contextual indicators
# ------------------------------------------------------------

additional_patterns <- c(
  
  "data scientist",
  "data scientists",
  "data analytics",
  "data analysis",
  "data mining",
  "big data",
  "data engineering",
  "data management",
  "data visualization",
  "data processing",
  "data modeling",
  "data modelling",
  
  "machine learning",
  "deep learning",
  "artificial intelligence",
  "predictive analytics",
  "statistical learning",
  
  "knowledge discovery",
  "knowledge discovery in databases",
  
  "data driven",
  "data-driven",
  "data intensive",
  "data-intensive",
  "computational data"
)

# ------------------------------------------------------------
# 6. Fields used for contextual investigation
# ------------------------------------------------------------

search_fields <- c(
  "Title",
  "Abstract",
  "Author_Keywords_Scopus",
  "Index_Keywords_Scopus",
  "Author_Keywords_WoS",
  "Keywords_Plus_WoS"
)

missing_fields <- setdiff(
  search_fields,
  names(investigation)
)

if (length(missing_fields) > 0) {
  
  stop(
    paste(
      "These required fields are missing:",
      paste(
        missing_fields,
        collapse = ", "
      )
    )
  )
}

# ------------------------------------------------------------
# 7. Build searchable text
# ------------------------------------------------------------

investigation$Search_Text <- apply(
  investigation[, search_fields, drop = FALSE],
  1,
  function(row) {
    
    paste(
      safe_text(row),
      collapse = " "
    )
    
  }
)

# ------------------------------------------------------------
# 8. Normalize searchable text
# ------------------------------------------------------------

investigation$Search_Text_Normalized <- investigation$Search_Text

investigation$Search_Text_Normalized <-
  str_to_lower(
    investigation$Search_Text_Normalized
  )

investigation$Search_Text_Normalized <-
  str_replace_all(
    investigation$Search_Text_Normalized,
    "[[:punct:]]+",
    " "
  )

investigation$Search_Text_Normalized <-
  str_squish(
    investigation$Search_Text_Normalized
  )

# ------------------------------------------------------------
# 9. Detect contextual indicators
# ------------------------------------------------------------

for (term in additional_patterns) {
  
  safe_name <- term %>%
    str_to_lower() %>%
    str_replace_all(
      "[^a-z0-9]+",
      "_"
    ) %>%
    str_replace_all(
      "^_|_$",
      ""
    )
  
  column_name <- paste0(
    "Context_",
    safe_name
  )
  
  term_pattern <- paste0(
    "\\b",
    str_replace_all(
      term,
      "[- ]",
      "[- ]+"
    ),
    "\\b"
  )
  
  investigation[[column_name]] <-
    str_detect(
      investigation$Search_Text_Normalized,
      regex(
        term_pattern,
        ignore_case = TRUE
      )
    )
}

# ------------------------------------------------------------
# 10. Controlled DS / D.S. abbreviation check
# ------------------------------------------------------------
# IMPORTANT:
# DS is NOT a relevance criterion.
# It is only flagged for manual inspection.
# ------------------------------------------------------------

investigation$Possible_DS_Abbreviation <-
  str_detect(
    investigation$Search_Text_Normalized,
    regex(
      "\\b(d\\s*\\.\\s*s\\.?|ds)\\b",
      ignore_case = TRUE
    )
  )

# ------------------------------------------------------------
# 11. Context indicator columns
# ------------------------------------------------------------

context_columns <- grep(
  "^Context_",
  names(investigation),
  value = TRUE
)

# ------------------------------------------------------------
# 12. Number of contextual indicators
# ------------------------------------------------------------

investigation$Number_of_Context_Indicators <-
  rowSums(
    as.data.frame(
      lapply(
        investigation[, context_columns, drop = FALSE],
        as.logical
      )
    ),
    na.rm = TRUE
  )

# ------------------------------------------------------------
# 13. Investigation category
# ------------------------------------------------------------

investigation$Investigation_Category <- "Needs manual review"

investigation$Investigation_Category[
  investigation$Number_of_Context_Indicators == 0 &
    investigation$Possible_DS_Abbreviation == FALSE
] <- "No additional indicator detected"

investigation$Investigation_Category[
  investigation$Number_of_Context_Indicators > 0 &
    investigation$Possible_DS_Abbreviation == FALSE
] <- "Additional data/AI/ML indicators detected"

investigation$Investigation_Category[
  investigation$Number_of_Context_Indicators == 0 &
    investigation$Possible_DS_Abbreviation == TRUE
] <- "Possible DS abbreviation only"

investigation$Investigation_Category[
  investigation$Number_of_Context_Indicators > 0 &
    investigation$Possible_DS_Abbreviation == TRUE
] <- "Additional indicators + possible DS abbreviation"

# ------------------------------------------------------------
# 14. Manual decision fields
# ------------------------------------------------------------

investigation$Manual_Relevance_Decision <- ""

investigation$Manual_Reason <- ""

# ------------------------------------------------------------
# 15. Create concise review table
# ------------------------------------------------------------

review_table <- investigation %>%
  select(
    Final_Article_ID,
    Source_Database,
    DOI,
    Title,
    Year,
    Authors,
    Abstract,
    Author_Keywords_Scopus,
    Author_Keywords_WoS,
    Author_Keywords_Combined,
    Document_Type,
    Retraction_Flag,
    Number_of_Context_Indicators,
    Possible_DS_Abbreviation,
    Investigation_Category,
    Manual_Relevance_Decision,
    Manual_Reason
  )

# ------------------------------------------------------------
# 16. Save full investigation file
# ------------------------------------------------------------

full_output <- file.path(
  output_dir,
  "Step5B_Investigation_50_Records_FULL.csv"
)

write_csv(
  investigation,
  full_output,
  na = ""
)

# ------------------------------------------------------------
# 17. Save review table
# ------------------------------------------------------------

review_output <- file.path(
  output_dir,
  "Step5B_Investigation_Review_Table.csv"
)

write_csv(
  review_table,
  review_output,
  na = ""
)

# ------------------------------------------------------------
# 18. Category summary
# ------------------------------------------------------------

category_summary <- investigation %>%
  count(
    Investigation_Category,
    name = "Records"
  ) %>%
  mutate(
    Percentage = round(
      Records /
        investigation_records *
        100,
      2
    )
  ) %>%
  arrange(
    desc(Records)
  )

write_csv(
  category_summary,
  file.path(
    output_dir,
    "Step5B_Investigation_Category_Summary.csv"
  )
)

# ------------------------------------------------------------
# 19. Context indicator summary
# ------------------------------------------------------------

context_summary <- data.frame(
  Indicator = context_columns,
  Records = sapply(
    context_columns,
    function(x) {
      sum(
        investigation[[x]],
        na.rm = TRUE
      )
    }
  )
)

context_summary$Percentage <- round(
  context_summary$Records /
    investigation_records *
    100,
  2
)

context_summary <- context_summary %>%
  arrange(
    desc(Records)
  )

write_csv(
  context_summary,
  file.path(
    output_dir,
    "Step5B_Context_Indicator_Summary.csv"
  )
)

# ------------------------------------------------------------
# 20. Retraction summary
# ------------------------------------------------------------

retraction_summary <- investigation %>%
  count(
    Retraction_Flag,
    name = "Records"
  ) %>%
  mutate(
    Percentage = round(
      Records /
        investigation_records *
        100,
      2
    )
  )

write_csv(
  retraction_summary,
  file.path(
    output_dir,
    "Step5B_Retraction_Summary.csv"
  )
)

# ------------------------------------------------------------
# 21. Audit
# ------------------------------------------------------------

matched_n <- sum(
  df$Data_Science_Match_Any_Field,
  na.rm = TRUE
)

unmatched_n <- sum(
  !df$Data_Science_Match_Any_Field,
  na.rm = TRUE
)

audit_status <- ifelse(
  matched_n +
    unmatched_n ==
    input_records,
  "PASS",
  "FAIL"
)

# ------------------------------------------------------------
# 22. Report
# ------------------------------------------------------------

report_file <- file.path(
  output_dir,
  "Step5B_Manual_Relevance_Investigation_Report.txt"
)

report_lines <- c(
  
  "============================================================",
  "STEP 5B – MANUAL RELEVANCE INVESTIGATION",
  "============================================================",
  "",
  
  paste(
    "Report generated:",
    format(
      Sys.time(),
      "%Y-%m-%d %H:%M:%S"
    )
  ),
  
  "",
  "INPUT",
  "------------------------------------------------------------",
  
  paste(
    "Input file:",
    input_file
  ),
  
  paste(
    "Input records:",
    input_records
  ),
  
  paste(
    "Input columns:",
    input_columns
  ),
  
  "",
  "INVESTIGATION SET",
  "------------------------------------------------------------",
  
  paste(
    "Records without explicit Data Science / Data Sciences:",
    investigation_records
  ),
  
  "",
  "PURPOSE",
  "------------------------------------------------------------",
  
  "This stage investigates records that did not contain",
  "the explicit phrases 'data science' or 'data sciences'",
  "in the six Step5A screening fields.",
  
  "",
  "No records were deleted.",
  "No final relevance decision was automatically assigned.",
  "Manual review remains required.",
  
  "",
  "ADDITIONAL INDICATORS",
  "------------------------------------------------------------",
  
  "Additional data, analytics, AI, machine learning,",
  "knowledge discovery, and related indicators were",
  "searched only as contextual evidence.",
  
  "",
  "IMPORTANT:",
  "These contextual indicators do NOT automatically",
  "classify a record as relevant to the Data Science field.",
  
  "",
  "DS ABBREVIATION",
  "------------------------------------------------------------",
  
  "Possible DS / D.S. abbreviations were flagged only",
  "for manual inspection.",
  
  "The abbreviation DS was NOT used as an automatic",
  "relevance criterion.",
  
  "",
  "CATEGORY SUMMARY",
  "------------------------------------------------------------",
  
  paste(
    capture.output(
      print(category_summary)
    ),
    collapse = "\n"
  ),
  
  "",
  "AUDIT",
  "------------------------------------------------------------",
  
  paste(
    "Original Step5A records:",
    input_records
  ),
  
  paste(
    "Step5A matched records:",
    matched_n
  ),
  
  paste(
    "Step5B investigation records:",
    investigation_records
  ),
  
  paste(
    "Matched + investigation:",
    matched_n +
      investigation_records
  ),
  
  paste(
    "Audit status:",
    audit_status
  ),
  
  "",
  "RETRACTIONS",
  "------------------------------------------------------------",
  
  paste(
    "Retraction records in investigation set:",
    sum(
      investigation$Retraction_Flag,
      na.rm = TRUE
    )
  ),
  
  "",
  "OUTPUT",
  "------------------------------------------------------------",
  
  paste(
    "Full investigation:",
    full_output
  ),
  
  paste(
    "Review table:",
    review_output
  ),
  
  "",
  "============================================================",
  "END OF REPORT",
  "============================================================"
)

writeLines(
  report_lines,
  report_file,
  useBytes = TRUE
)

# ------------------------------------------------------------
# 23. Console summary
# ------------------------------------------------------------

cat("\n")
cat("============================================================\n")
cat("STEP 5B COMPLETED\n")
cat("============================================================\n")

cat(
  "Step5A input records:",
  input_records,
  "\n"
)

cat(
  "Records for Step5B investigation:",
  investigation_records,
  "\n"
)

cat(
  "Possible DS abbreviation:",
  sum(
    investigation$Possible_DS_Abbreviation,
    na.rm = TRUE
  ),
  "\n"
)

cat(
  "Audit status:",
  audit_status,
  "\n"
)

cat(
  "Output folder:",
  output_dir,
  "\n"
)

cat("============================================================\n")