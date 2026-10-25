# ============================================================
# STEP 5B – FINAL MANUAL RELEVANCE INVESTIGATION
# ============================================================
# Purpose:
# Investigate records that did not contain
# "data science" or "data sciences" in Step5A.
#
# IMPORTANT:
# - No records are deleted.
# - No final relevance decision is assigned automatically.
# - This stage is an investigation/audit stage.
# ============================================================


# ============================================================
# 1. PACKAGES
# ============================================================

library(dplyr)
library(stringr)


# ============================================================
# 2. PATHS
# ============================================================

input_file <- paste0(
  "D:/Thesis/data/Step5_Relevance_Eligibility_Audit/",
  "Step5A_Data_Science_Screening/",
  "Step5A_Data_Science_Screening_Audit.csv"
)

output_dir <- paste0(
  "D:/Thesis/data/Step5_Relevance_Eligibility_Audit/",
  "Step5B_Manual_Relevance_Investigation_FINAL"
)

if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}


# ============================================================
# 3. READ STEP5A
# ============================================================

df <- read.csv(
  input_file,
  stringsAsFactors = FALSE,
  check.names = FALSE
)

input_records <- nrow(df)


# ============================================================
# 4. CHECK REQUIRED FIELDS
# ============================================================

required_fields <- c(
  "Final_Article_ID",
  "Source_Database",
  "DOI",
  "Title",
  "Year",
  "Authors",
  "Abstract",
  "Author_Keywords_Scopus",
  "Author_Keywords_WoS",
  "Author_Keywords_Combined",
  "Index_Keywords_Scopus",
  "Keywords_Plus_WoS",
  "Document_Type",
  "Retraction_Flag",
  "Data_Science_Match_Any_Field"
)

missing_fields <- setdiff(
  required_fields,
  names(df)
)

if (length(missing_fields) > 0) {
  stop(
    paste(
      "Required fields are missing:",
      paste(missing_fields, collapse = ", ")
    )
  )
}


# ============================================================
# 5. SAFE TEXT FUNCTION
# ============================================================

safe_text <- function(x) {
  
  x <- as.character(x)
  
  x[is.na(x)] <- ""
  
  x
}


# ============================================================
# 6. SELECT 50 INVESTIGATION RECORDS
# ============================================================

investigation <- df %>%
  filter(
    Data_Science_Match_Any_Field == FALSE
  )

investigation_records <- nrow(investigation)


# ============================================================
# 7. ADDITIONAL CONTEXTUAL INDICATORS
# ============================================================

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


# ============================================================
# 8. SEARCH FIELDS
# ============================================================

search_fields <- c(
  "Title",
  "Abstract",
  "Author_Keywords_Scopus",
  "Index_Keywords_Scopus",
  "Author_Keywords_WoS",
  "Keywords_Plus_WoS"
)


# ============================================================
# 9. BUILD SEARCH TEXT
# ============================================================

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


# ============================================================
# 10. NORMALIZE SEARCH TEXT
# ============================================================

investigation$Search_Text_Normalized <-
  investigation$Search_Text %>%
  str_to_lower() %>%
  str_replace_all(
    "[[:punct:]]+",
    " "
  ) %>%
  str_squish()


# ============================================================
# 11. DETECT CONTEXTUAL INDICATORS
# ============================================================

context_columns <- character(0)

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
  
  context_columns <- c(
    context_columns,
    column_name
  )
}


# ============================================================
# 12. COUNT CONTEXTUAL INDICATORS
# ============================================================

investigation$Number_of_Context_Indicators <-
  rowSums(
    investigation[, context_columns, drop = FALSE],
    na.rm = TRUE
  )


# ============================================================
# 13. POSSIBLE DS / D.S. ABBREVIATION
# ============================================================

investigation$Possible_DS_Abbreviation <-
  str_detect(
    investigation$Search_Text_Normalized,
    regex(
      "\\b(d\\s*\\.\\s*s\\.?|ds)\\b",
      ignore_case = TRUE
    )
  )


# ============================================================
# 14. INVESTIGATION CATEGORY
# ============================================================

investigation$Investigation_Category <-
  "No additional indicator detected"

investigation$Investigation_Category[
  investigation$Number_of_Context_Indicators > 0
] <-
  "Additional data/AI/ML indicators detected"

investigation$Investigation_Category[
  investigation$Possible_DS_Abbreviation == TRUE
] <-
  "Possible DS abbreviation"

investigation$Investigation_Category[
  investigation$Number_of_Context_Indicators > 0 &
    investigation$Possible_DS_Abbreviation == TRUE
] <-
  "Additional indicators + possible DS abbreviation"


# ============================================================
# 15. METADATA COMPLETENESS
# ============================================================

investigation$Has_Scopus_Author_Keywords <-
  str_squish(
    safe_text(
      investigation$Author_Keywords_Scopus
    )
  ) != ""

investigation$Has_WoS_Author_Keywords <-
  str_squish(
    safe_text(
      investigation$Author_Keywords_WoS
    )
  ) != ""

investigation$Has_Combined_Author_Keywords <-
  str_squish(
    safe_text(
      investigation$Author_Keywords_Combined
    )
  ) != ""

investigation$Has_Scopus_Index_Keywords <-
  str_squish(
    safe_text(
      investigation$Index_Keywords_Scopus
    )
  ) != ""

investigation$Has_WoS_Keywords_Plus <-
  str_squish(
    safe_text(
      investigation$Keywords_Plus_WoS
    )
  ) != ""

investigation$Has_Abstract <-
  str_squish(
    safe_text(
      investigation$Abstract
    )
  ) != ""


# ============================================================
# 16. KEYWORD METADATA STATUS
# ============================================================

investigation$Keyword_Metadata_Status <-
  case_when(
    
    investigation$Has_Scopus_Author_Keywords &
      investigation$Has_WoS_Author_Keywords ~
      "Scopus + WoS Author Keywords available",
    
    investigation$Has_Scopus_Author_Keywords &
      !investigation$Has_WoS_Author_Keywords ~
      "Scopus Author Keywords only",
    
    !investigation$Has_Scopus_Author_Keywords &
      investigation$Has_WoS_Author_Keywords ~
      "WoS Author Keywords only",
    
    TRUE ~
      "No Author Keywords available"
  )


# ============================================================
# 17. MANUAL DECISION FIELDS
# ============================================================

investigation$Manual_Relevance_Decision <- ""

investigation$Manual_Reason <- ""


# ============================================================
# 18. REVIEW TABLE
# ============================================================

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
    
    Index_Keywords_Scopus,
    Keywords_Plus_WoS,
    
    Has_Scopus_Author_Keywords,
    Has_WoS_Author_Keywords,
    Has_Combined_Author_Keywords,
    Has_Scopus_Index_Keywords,
    Has_WoS_Keywords_Plus,
    Has_Abstract,
    
    Keyword_Metadata_Status,
    
    Document_Type,
    Retraction_Flag,
    
    Number_of_Context_Indicators,
    Possible_DS_Abbreviation,
    Investigation_Category,
    
    Manual_Relevance_Decision,
    Manual_Reason
  )


# ============================================================
# 19. SAVE MAIN FILES
# ============================================================

write.csv(
  investigation,
  file.path(
    output_dir,
    "Step5B_FINAL_Investigation_50_Records_FULL.csv"
  ),
  row.names = FALSE,
  na = ""
)

write.csv(
  review_table,
  file.path(
    output_dir,
    "Step5B_FINAL_Investigation_Review_Table.csv"
  ),
  row.names = FALSE,
  na = ""
)


# ============================================================
# 20. KEYWORD COMPLETENESS SUMMARY
# ============================================================

keyword_completeness <- data.frame(
  
  Field = c(
    "Scopus Author Keywords",
    "WoS Author Keywords",
    "Combined Author Keywords",
    "Scopus Index Keywords",
    "WoS Keywords Plus",
    "Abstract"
  ),
  
  Available_Records = c(
    
    sum(investigation$Has_Scopus_Author_Keywords),
    
    sum(investigation$Has_WoS_Author_Keywords),
    
    sum(investigation$Has_Combined_Author_Keywords),
    
    sum(investigation$Has_Scopus_Index_Keywords),
    
    sum(investigation$Has_WoS_Keywords_Plus),
    
    sum(investigation$Has_Abstract)
  ),
  
  Missing_Records = c(
    
    sum(!investigation$Has_Scopus_Author_Keywords),
    
    sum(!investigation$Has_WoS_Author_Keywords),
    
    sum(!investigation$Has_Combined_Author_Keywords),
    
    sum(!investigation$Has_Scopus_Index_Keywords),
    
    sum(!investigation$Has_WoS_Keywords_Plus),
    
    sum(!investigation$Has_Abstract)
  )
)

keyword_completeness$Available_Percentage <-
  round(
    keyword_completeness$Available_Records /
      investigation_records * 100,
    2
  )

keyword_completeness$Missing_Percentage <-
  round(
    keyword_completeness$Missing_Records /
      investigation_records * 100,
    2
  )

write.csv(
  keyword_completeness,
  file.path(
    output_dir,
    "Step5B_FINAL_Keyword_Metadata_Completeness.csv"
  ),
  row.names = FALSE
)


# ============================================================
# 21. KEYWORD STATUS SUMMARY
# ============================================================

keyword_status_summary <-
  investigation %>%
  count(
    Keyword_Metadata_Status,
    name = "Records"
  ) %>%
  mutate(
    Percentage =
      round(
        Records /
          investigation_records *
          100,
        2
      )
  ) %>%
  arrange(
    desc(Records)
  )

write.csv(
  keyword_status_summary,
  file.path(
    output_dir,
    "Step5B_FINAL_Keyword_Metadata_Status_Summary.csv"
  ),
  row.names = FALSE
)


# ============================================================
# 22. CONTEXT INDICATOR SUMMARY
# ============================================================

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

context_summary$Percentage <-
  round(
    context_summary$Records /
      investigation_records * 100,
    2
  )

context_summary <-
  context_summary %>%
  arrange(
    desc(Records)
  )

write.csv(
  context_summary,
  file.path(
    output_dir,
    "Step5B_FINAL_Context_Indicator_Summary.csv"
  ),
  row.names = FALSE
)


# ============================================================
# 23. INVESTIGATION CATEGORY SUMMARY
# ============================================================

category_summary <-
  investigation %>%
  count(
    Investigation_Category,
    name = "Records"
  ) %>%
  mutate(
    Percentage =
      round(
        Records /
          investigation_records *
          100,
        2
      )
  ) %>%
  arrange(
    desc(Records)
  )

write.csv(
  category_summary,
  file.path(
    output_dir,
    "Step5B_FINAL_Investigation_Category_Summary.csv"
  ),
  row.names = FALSE
)


# ============================================================
# 24. RETRACTION SUMMARY
# ============================================================

retraction_summary <-
  investigation %>%
  count(
    Retraction_Flag,
    name = "Records"
  )

write.csv(
  retraction_summary,
  file.path(
    output_dir,
    "Step5B_FINAL_Retraction_Summary.csv"
  ),
  row.names = FALSE
)


# ============================================================
# 25. AUDIT CHECK
# ============================================================

matched_n <-
  sum(
    df$Data_Science_Match_Any_Field,
    na.rm = TRUE
  )

audit_total <-
  matched_n +
  investigation_records

audit_status <-
  ifelse(
    audit_total == input_records,
    "PASS",
    "FAIL"
  )


# ============================================================
# 26. CREATE REPORT USING BASE R ONLY
# ============================================================

report_file <- file.path(
  output_dir,
  "Step5B_FINAL_Manual_Relevance_Investigation_Report.txt"
)

report_lines <- c(
  
  "============================================================",
  "STEP 5B – FINAL MANUAL RELEVANCE INVESTIGATION",
  "============================================================",
  "",
  
  paste("Report generated:", format(Sys.time())),
  paste("Input file:", input_file),
  paste("Output folder:", output_dir),
  "",
  
  "1. PURPOSE",
  "------------------------------------------------------------",
  "This stage investigates records that did not contain the",
  "explicit phrases 'data science' or 'data sciences' in",
  "the Step5A screening fields.",
  "",
  
  "No records were deleted.",
  "No automatic final relevance decision was assigned.",
  "Manual relevance classification remains a separate stage.",
  "",
  
  "2. RECORD COUNTS",
  "------------------------------------------------------------",
  paste("Input records:", input_records),
  paste("Records with Data Science/Data Sciences detected:", matched_n),
  paste("Records requiring investigation:", investigation_records),
  paste("Matched + investigation:", audit_total),
  paste("Audit status:", audit_status),
  "",
  
  "3. SEARCH FIELDS",
  "------------------------------------------------------------",
  "Title",
  "Abstract",
  "Scopus Author Keywords",
  "Scopus Index Keywords",
  "WoS Author Keywords",
  "WoS Keywords Plus",
  "",
  
  "4. METADATA COMPLETENESS",
  "------------------------------------------------------------"
)


# Add keyword completeness rows manually
for (i in seq_len(nrow(keyword_completeness))) {
  
  report_lines <- c(
    report_lines,
    
    paste0(
      keyword_completeness$Field[i],
      ": ",
      keyword_completeness$Available_Records[i],
      " available; ",
      keyword_completeness$Missing_Records[i],
      " missing; ",
      keyword_completeness$Available_Percentage[i],
      "% available"
    )
  )
}


report_lines <- c(
  report_lines,
  
  "",
  "5. KEYWORD METADATA STATUS",
  "------------------------------------------------------------"
)


for (i in seq_len(nrow(keyword_status_summary))) {
  
  report_lines <- c(
    report_lines,
    
    paste0(
      keyword_status_summary$Keyword_Metadata_Status[i],
      ": ",
      keyword_status_summary$Records[i],
      " records (",
      keyword_status_summary$Percentage[i],
      "%)"
    )
  )
}


report_lines <- c(
  report_lines,
  
  "",
  "6. INVESTIGATION CATEGORIES",
  "------------------------------------------------------------"
)


for (i in seq_len(nrow(category_summary))) {
  
  report_lines <- c(
    report_lines,
    
    paste0(
      category_summary$Investigation_Category[i],
      ": ",
      category_summary$Records[i],
      " records (",
      category_summary$Percentage[i],
      "%)"
    )
  )
}


report_lines <- c(
  report_lines,
  
  "",
  "7. CONTEXTUAL INDICATORS",
  "------------------------------------------------------------"
)


for (i in seq_len(nrow(context_summary))) {
  
  report_lines <- c(
    report_lines,
    
    paste0(
      context_summary$Indicator[i],
      ": ",
      context_summary$Records[i],
      " records (",
      context_summary$Percentage[i],
      "%)"
    )
  )
}


report_lines <- c(
  report_lines,
  
  "",
  "8. RETRACTIONS",
  "------------------------------------------------------------"
)


for (i in seq_len(nrow(retraction_summary))) {
  
  report_lines <- c(
    report_lines,
    
    paste0(
      "Retraction_Flag = ",
      retraction_summary$Retraction_Flag[i],
      ": ",
      retraction_summary$Records[i],
      " records"
    )
  )
}


report_lines <- c(
  report_lines,
  
  "",
  "9. METHODOLOGICAL NOTE",
  "------------------------------------------------------------",
  "Contextual indicators such as machine learning, data mining,",
  "big data, artificial intelligence, data analytics and related",
  "terms are used only as contextual evidence.",
  "",
  "They do NOT automatically classify a record as relevant",
  "to the Data Science research field.",
  "",
  "The purpose of this stage is investigation, not automatic",
  "final relevance classification.",
  "",
  "10. AUDIT",
  "------------------------------------------------------------",
  paste("Input records:", input_records),
  paste("Matched records:", matched_n),
  paste("Investigation records:", investigation_records),
  paste("Matched + investigation:", audit_total),
  paste("Audit status:", audit_status),
  "",
  "============================================================",
  "END OF REPORT",
  "============================================================"
)


# ============================================================
# 27. WRITE REPORT
# ============================================================

writeLines(
  report_lines,
  con = report_file,
  useBytes = TRUE
)


# ============================================================
# 28. FINAL FILE INVENTORY
# ============================================================

cat("\n============================================================\n")
cat("STEP 5B FINAL COMPLETED\n")
cat("============================================================\n\n")

cat("Input records:", input_records, "\n")
cat("Matched records:", matched_n, "\n")
cat("Investigation records:", investigation_records, "\n")
cat("Audit total:", audit_total, "\n")
cat("Audit status:", audit_status, "\n\n")

cat("Output folder:\n")
cat(output_dir, "\n\n")

cat("Files created:\n\n")

print(
  list.files(
    output_dir
  )
)

cat("\n============================================================\n")
cat("REPORT FILE:\n")
cat(report_file, "\n")
cat("============================================================\n")