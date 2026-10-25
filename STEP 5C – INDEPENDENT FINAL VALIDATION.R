# ============================================================
# STEP 5C – INDEPENDENT FINAL VALIDATION
# ============================================================

# -----------------------------
# 1. مسیرها
# -----------------------------

step5c_dir <- "D:/Thesis/data/Step5_Relevance_Eligibility_Audit/Step5C_Final_Relevance_Corpus"

validation_dir <- file.path(
  step5c_dir,
  "Step5C_Independent_Validation"
)

if (!dir.exists(validation_dir)) {
  dir.create(validation_dir, recursive = TRUE)
}

# فایل‌های Step5C
relevant_file <- file.path(
  step5c_dir,
  "Step5C_FINAL_RELEVANT_CORPUS.csv"
)

irrelevant_file <- file.path(
  step5c_dir,
  "Step5C_FINAL_IRRELEVANT_RECORDS.csv"
)

uncertain_file <- file.path(
  step5c_dir,
  "Step5C_FINAL_UNCERTAIN_RECORDS.csv"
)

audit_file <- file.path(
  step5c_dir,
  "Step5C_FINAL_RELEVANCE_AUDIT.csv"
)

decision_summary_file <- file.path(
  step5c_dir,
  "Step5C_Final_Decision_Summary.csv"
)

# Step5A
step5a_file <- paste0(
  "D:/Thesis/data/Step5_Relevance_Eligibility_Audit/",
  "Step5A_Data_Science_Screening/",
  "Step5A_Data_Science_Screening_Audit.csv"
)

# Step4B
step4b_file <- paste0(
  "D:/Thesis/data/Step4_Deduplication_Metadata_Merging/",
  "Step4B_Final_Deduplication_Metadata_Merging/",
  "Scopus_WoS_Eligible_2000_2025_English_Article_Review_FINAL_DEDUP.csv"
)


# -----------------------------
# 2. بررسی وجود فایل‌ها
# -----------------------------

required_files <- c(
  relevant_file,
  irrelevant_file,
  uncertain_file,
  audit_file,
  step5a_file,
  step4b_file
)

if (any(!file.exists(required_files))) {
  
  missing_files <- required_files[!file.exists(required_files)]
  
  stop(
    paste(
      "ERROR: فایل‌های زیر پیدا نشدند:\n",
      paste(missing_files, collapse = "\n")
    )
  )
}


# -----------------------------
# 3. خواندن فایل‌ها
# -----------------------------

relevant <- read.csv(
  relevant_file,
  stringsAsFactors = FALSE,
  check.names = FALSE
)

irrelevant <- read.csv(
  irrelevant_file,
  stringsAsFactors = FALSE,
  check.names = FALSE
)

uncertain <- read.csv(
  uncertain_file,
  stringsAsFactors = FALSE,
  check.names = FALSE
)

audit <- read.csv(
  audit_file,
  stringsAsFactors = FALSE,
  check.names = FALSE
)

step5a <- read.csv(
  step5a_file,
  stringsAsFactors = FALSE,
  check.names = FALSE
)

step4b <- read.csv(
  step4b_file,
  stringsAsFactors = FALSE,
  check.names = FALSE
)


# -----------------------------
# 4. تعداد رکوردها
# -----------------------------

n_relevant <- nrow(relevant)
n_irrelevant <- nrow(irrelevant)
n_uncertain <- nrow(uncertain)
n_audit <- nrow(audit)
n_step5a <- nrow(step5a)
n_step4b <- nrow(step4b)


# -----------------------------
# 5. بررسی ستون‌های ضروری
# -----------------------------

required_audit_cols <- c(
  "Final_Article_ID",
  "Final_Relevance_Decision",
  "Final_Decision_Basis",
  "Data_Science_Match_Any_Field"
)

missing_audit_cols <- setdiff(
  required_audit_cols,
  names(audit)
)

audit_structure_pass <- length(missing_audit_cols) == 0


required_relevant_cols <- c(
  "Final_Article_ID"
)

missing_relevant_cols <- setdiff(
  required_relevant_cols,
  names(relevant)
)

relevant_structure_pass <- length(missing_relevant_cols) == 0


required_step5a_cols <- c(
  "Final_Article_ID",
  "Data_Science_Match_Any_Field"
)

missing_step5a_cols <- setdiff(
  required_step5a_cols,
  names(step5a)
)

step5a_structure_pass <- length(missing_step5a_cols) == 0


required_step4b_cols <- c(
  "Final_Article_ID"
)

missing_step4b_cols <- setdiff(
  required_step4b_cols,
  names(step4b)
)

step4b_structure_pass <- length(missing_step4b_cols) == 0


# -----------------------------
# 6. اگر ستون‌های اصلی وجود ندارند، توقف
# -----------------------------

if (!audit_structure_pass) {
  stop(
    paste(
      "ERROR: ستون‌های ضروری Step5C Audit وجود ندارند:",
      paste(missing_audit_cols, collapse = ", ")
    )
  )
}

if (!relevant_structure_pass) {
  stop(
    paste(
      "ERROR: ستون Final_Article_ID در فایل Relevant وجود ندارد."
    )
  )
}

if (!step5a_structure_pass) {
  stop(
    paste(
      "ERROR: ستون‌های ضروری Step5A وجود ندارند:",
      paste(missing_step5a_cols, collapse = ", ")
    )
  )
}

if (!step4b_structure_pass) {
  stop(
    paste(
      "ERROR: ستون Final_Article_ID در Step4B وجود ندارد."
    )
  )
}


# -----------------------------
# 7. بررسی تعداد اصلی Step5C
# -----------------------------

record_count_pass <- (
  n_audit == 15222 &&
    n_relevant == 15172 &&
    n_irrelevant == 50 &&
    n_uncertain == 0 &&
    n_relevant + n_irrelevant + n_uncertain == n_audit
)


# -----------------------------
# 8. بررسی Final_Article_ID
# -----------------------------

audit_missing_id <- sum(
  is.na(audit$Final_Article_ID) |
    trimws(audit$Final_Article_ID) == ""
)

audit_duplicate_id <- sum(
  duplicated(audit$Final_Article_ID)
)

relevant_missing_id <- sum(
  is.na(relevant$Final_Article_ID) |
    trimws(relevant$Final_Article_ID) == ""
)

relevant_duplicate_id <- sum(
  duplicated(relevant$Final_Article_ID)
)

id_integrity_pass <- (
  audit_missing_id == 0 &&
    audit_duplicate_id == 0 &&
    relevant_missing_id == 0 &&
    relevant_duplicate_id == 0
)


# -----------------------------
# 9. بررسی تصمیم‌های نهایی
# -----------------------------

decision_values <- unique(
  trimws(audit$Final_Relevance_Decision)
)

allowed_decisions <- c(
  "RELEVANT",
  "IRRELEVANT",
  "UNCERTAIN"
)

invalid_decisions <- setdiff(
  decision_values,
  allowed_decisions
)

missing_decisions <- sum(
  is.na(audit$Final_Relevance_Decision) |
    trimws(audit$Final_Relevance_Decision) == ""
)

decision_structure_pass <- (
  length(invalid_decisions) == 0 &&
    missing_decisions == 0
)


# -----------------------------
# 10. بررسی تعداد هر تصمیم
# -----------------------------

decision_table <- table(
  audit$Final_Relevance_Decision,
  useNA = "ifany"
)

relevant_decision_count <- sum(
  audit$Final_Relevance_Decision == "RELEVANT",
  na.rm = TRUE
)

irrelevant_decision_count <- sum(
  audit$Final_Relevance_Decision == "IRRELEVANT",
  na.rm = TRUE
)

uncertain_decision_count <- sum(
  audit$Final_Relevance_Decision == "UNCERTAIN",
  na.rm = TRUE
)

decision_count_pass <- (
  relevant_decision_count == 15172 &&
    irrelevant_decision_count == 50 &&
    uncertain_decision_count == 0
)


# -----------------------------
# 11. تطابق Relevant با Audit
# -----------------------------

audit_relevant_ids <- audit$Final_Article_ID[
  audit$Final_Relevance_Decision == "RELEVANT"
]

relevant_ids <- relevant$Final_Article_ID

missing_from_relevant <- setdiff(
  audit_relevant_ids,
  relevant_ids
)

extra_in_relevant <- setdiff(
  relevant_ids,
  audit_relevant_ids
)

relevant_set_match_pass <- (
  length(missing_from_relevant) == 0 &&
    length(extra_in_relevant) == 0
)


# -----------------------------
# 12. تطابق Irrelevant با Audit
# -----------------------------

audit_irrelevant_ids <- audit$Final_Article_ID[
  audit$Final_Relevance_Decision == "IRRELEVANT"
]

irrelevant_ids <- irrelevant$Final_Article_ID

missing_from_irrelevant <- setdiff(
  audit_irrelevant_ids,
  irrelevant_ids
)

extra_in_irrelevant <- setdiff(
  irrelevant_ids,
  audit_irrelevant_ids
)

irrelevant_set_match_pass <- (
  length(missing_from_irrelevant) == 0 &&
    length(extra_in_irrelevant) == 0
)


# -----------------------------
# 13. تطابق Uncertain با Audit
# -----------------------------

audit_uncertain_ids <- audit$Final_Article_ID[
  audit$Final_Relevance_Decision == "UNCERTAIN"
]

if ("Final_Article_ID" %in% names(uncertain)) {
  
  uncertain_ids <- uncertain$Final_Article_ID
  
} else {
  
  uncertain_ids <- character(0)
}

missing_from_uncertain <- setdiff(
  audit_uncertain_ids,
  uncertain_ids
)

extra_in_uncertain <- setdiff(
  uncertain_ids,
  audit_uncertain_ids
)

uncertain_set_match_pass <- (
  length(missing_from_uncertain) == 0 &&
    length(extra_in_uncertain) == 0
)


# -----------------------------
# 14. بررسی Step5A → Step5C
# -----------------------------

step5a_ids <- step5a$Final_Article_ID
audit_ids <- audit$Final_Article_ID

missing_from_audit <- setdiff(
  step5a_ids,
  audit_ids
)

extra_in_audit <- setdiff(
  audit_ids,
  step5a_ids
)

step5a_to_step5c_pass <- (
  length(missing_from_audit) == 0 &&
    length(extra_in_audit) == 0 &&
    length(step5a_ids) == length(audit_ids)
)


# -----------------------------
# 15. بررسی Data Science Match
# -----------------------------

ds_match_true <- sum(
  step5a$Data_Science_Match_Any_Field == TRUE,
  na.rm = TRUE
)

ds_match_false <- sum(
  step5a$Data_Science_Match_Any_Field == FALSE,
  na.rm = TRUE
)

ds_match_na <- sum(
  is.na(step5a$Data_Science_Match_Any_Field)
)

ds_match_count_pass <- (
  ds_match_true == 15172 &&
    ds_match_false == 50 &&
    ds_match_na == 0
)


# -----------------------------
# 16. بررسی اینکه تمام Matchها RELEVANT هستند
# -----------------------------

matched_step5a_ids <- step5a$Final_Article_ID[
  step5a$Data_Science_Match_Any_Field == TRUE
]

matched_audit_decisions <- audit$Final_Relevance_Decision[
  match(matched_step5a_ids, audit$Final_Article_ID)
]

matched_not_relevant <- sum(
  matched_audit_decisions != "RELEVANT",
  na.rm = TRUE
)

matched_relevance_pass <- (
  length(matched_step5a_ids) == 15172 &&
    matched_not_relevant == 0
)


# -----------------------------
# 17. بررسی اینکه تمام No-Match ها
#     همان 50 رکورد دستی هستند
# -----------------------------

no_match_step5a_ids <- step5a$Final_Article_ID[
  step5a$Data_Science_Match_Any_Field == FALSE
]

no_match_decisions <- audit$Final_Relevance_Decision[
  match(no_match_step5a_ids, audit$Final_Article_ID)
]

no_match_not_irrelevant <- sum(
  no_match_decisions != "IRRELEVANT",
  na.rm = TRUE
)

no_match_manual_pass <- (
  length(no_match_step5a_ids) == 50 &&
    no_match_not_irrelevant == 0
)


# -----------------------------
# 18. بررسی ارتباط Step5C با Step4B
# -----------------------------

step4b_ids <- step4b$Final_Article_ID

step5c_not_in_step4b <- setdiff(
  audit$Final_Article_ID,
  step4b_ids
)

step4b_missing_from_step5c <- setdiff(
  step4b_ids,
  audit$Final_Article_ID
)

step4b_linkage_pass <- (
  length(step5c_not_in_step4b) == 0 &&
    length(step4b_missing_from_step5c) == 0 &&
    length(step4b_ids) == length(audit$Final_Article_ID)
)


# -----------------------------
# 19. بررسی بازه سال
# -----------------------------

if ("Year" %in% names(audit)) {
  
  year_numeric <- suppressWarnings(
    as.numeric(audit$Year)
  )
  
  missing_year <- sum(
    is.na(year_numeric)
  )
  
  outside_year <- sum(
    !is.na(year_numeric) &
      (year_numeric < 2000 | year_numeric > 2025)
  )
  
  year_pass <- (
    missing_year == 0 &&
      outside_year == 0
  )
  
} else {
  
  missing_year <- NA
  outside_year <- NA
  year_pass <- FALSE
}


# -----------------------------
# 20. بررسی زبان
# -----------------------------

if ("Language" %in% names(audit)) {
  
  language_text <- toupper(
    trimws(as.character(audit$Language))
  )
  
  language_text[is.na(language_text)] <- ""
  
  language_tokens <- unlist(
    strsplit(
      language_text,
      "\\s*\\|\\s*"
    )
  )
  
  language_tokens <- trimws(language_tokens)
  
  invalid_language_tokens <- unique(
    language_tokens[
      language_tokens != "" &
        language_tokens != "ENGLISH"
    ]
  )
  
  missing_language <- sum(
    language_text == ""
  )
  
  non_english_records <- sum(
    sapply(
      language_text,
      function(x) {
        if (x == "") return(FALSE)
        
        tokens <- trimws(
          unlist(
            strsplit(
              x,
              "\\s*\\|\\s*"
            )
          )
        )
        
        any(tokens != "ENGLISH")
      }
    )
  )
  
  language_pass <- (
    missing_language == 0 &&
      non_english_records == 0
  )
  
} else {
  
  missing_language <- NA
  non_english_records <- NA
  invalid_language_tokens <- NA
  language_pass <- FALSE
}


# -----------------------------
# 21. بررسی Retraction
# -----------------------------

if ("Retraction_Flag" %in% names(audit)) {
  
  retraction_true <- sum(
    audit$Retraction_Flag == TRUE,
    na.rm = TRUE
  )
  
  retraction_false <- sum(
    audit$Retraction_Flag == FALSE,
    na.rm = TRUE
  )
  
  retraction_missing <- sum(
    is.na(audit$Retraction_Flag)
  )
  
  retraction_pass <- (
    retraction_true == 22 &&
      retraction_false == 15200 &&
      retraction_missing == 0
  )
  
} else {
  
  retraction_true <- NA
  retraction_false <- NA
  retraction_missing <- NA
  retraction_pass <- FALSE
}


# -----------------------------
# 22. بررسی نوع مدرک
# -----------------------------

if ("Document_Type" %in% names(audit)) {
  
  document_type_missing <- sum(
    is.na(audit$Document_Type) |
      trimws(as.character(audit$Document_Type)) == ""
  )
  
  document_type_pass <- (
    document_type_missing == 0
  )
  
} else {
  
  document_type_missing <- NA
  document_type_pass <- FALSE
}


# -----------------------------
# 23. بررسی Basis تصمیم نهایی
# -----------------------------

basis_table <- table(
  audit$Final_Decision_Basis,
  useNA = "ifany"
)


# -----------------------------
# 24. بررسی متادیتای مهم
# -----------------------------

metadata_fields <- intersect(
  c(
    "DOI",
    "Title",
    "Year",
    "Authors",
    "Abstract",
    "Author_Keywords_Combined",
    "Source_Title",
    "Document_Type",
    "Language"
  ),
  names(audit)
)

metadata_missing_summary <- data.frame(
  Field = character(0),
  Missing = integer(0),
  Available = integer(0),
  Available_Percent = numeric(0),
  stringsAsFactors = FALSE
)

for (field in metadata_fields) {
  
  x <- audit[[field]]
  
  missing <- sum(
    is.na(x) |
      trimws(as.character(x)) == ""
  )
  
  available <- nrow(audit) - missing
  
  percentage <- round(
    100 * available / nrow(audit),
    2
  )
  
  metadata_missing_summary <- rbind(
    metadata_missing_summary,
    data.frame(
      Field = field,
      Missing = missing,
      Available = available,
      Available_Percent = percentage,
      stringsAsFactors = FALSE
    )
  )
}


# -----------------------------
# 25. ساخت خلاصه Validation
# -----------------------------

validation_summary <- data.frame(
  
  Check = c(
    "Record count",
    "ID integrity",
    "Decision structure",
    "Decision counts",
    "Relevant set match",
    "Irrelevant set match",
    "Uncertain set match",
    "Step5A to Step5C reconciliation",
    "Data Science match count",
    "Matched records are relevant",
    "No-match records manually classified",
    "Step4B to Step5C linkage",
    "Year",
    "Language",
    "Retraction",
    "Document type"
  ),
  
  PASS = c(
    record_count_pass,
    id_integrity_pass,
    decision_structure_pass,
    decision_count_pass,
    relevant_set_match_pass,
    irrelevant_set_match_pass,
    uncertain_set_match_pass,
    step5a_to_step5c_pass,
    ds_match_count_pass,
    matched_relevance_pass,
    no_match_manual_pass,
    step4b_linkage_pass,
    year_pass,
    language_pass,
    retraction_pass,
    document_type_pass
  ),
  
  stringsAsFactors = FALSE
)


overall_pass <- all(
  validation_summary$PASS
)


# -----------------------------
# 26. ذخیره فایل‌های Validation
# -----------------------------

write.csv(
  validation_summary,
  file.path(
    validation_dir,
    "Step5C_Independent_Validation_Summary.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

write.csv(
  metadata_missing_summary,
  file.path(
    validation_dir,
    "Step5C_Critical_Metadata_Missingness.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

write.csv(
  data.frame(
    Decision = c(
      "RELEVANT",
      "IRRELEVANT",
      "UNCERTAIN"
    ),
    Count = c(
      relevant_decision_count,
      irrelevant_decision_count,
      uncertain_decision_count
    )
  ),
  file.path(
    validation_dir,
    "Step5C_Decision_Counts.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

write.csv(
  data.frame(
    Data_Science_Match = c(
      TRUE,
      FALSE,
      NA
    ),
    Count = c(
      ds_match_true,
      ds_match_false,
      ds_match_na
    )
  ),
  file.path(
    validation_dir,
    "Step5C_Data_Science_Match_Validation.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

write.csv(
  data.frame(
    Step4B_Record_Count = n_step4b,
    Step5C_Audit_Record_Count = n_audit,
    Step5C_ID_Not_in_Step4B = length(step5c_not_in_step4b),
    Step4B_ID_Not_in_Step5C = length(step4b_missing_from_step5c)
  ),
  file.path(
    validation_dir,
    "Step5C_Step4B_Linkage_Validation.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)


# -----------------------------
# 27. گزارش متنی نهایی
# -----------------------------

report_lines <- c(
  
  "============================================================",
  "STEP 5C – INDEPENDENT FINAL VALIDATION",
  "============================================================",
  "",
  paste(
    "Validation date:",
    format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  ),
  "",
  
  "1. INPUT FILES",
  paste("Step5C Relevant:", relevant_file),
  paste("Step5C Irrelevant:", irrelevant_file),
  paste("Step5C Uncertain:", uncertain_file),
  paste("Step5C Audit:", audit_file),
  paste("Step5A:", step5a_file),
  paste("Step4B:", step4b_file),
  "",
  
  "2. RECORD COUNTS",
  paste("Step5A records:", n_step5a),
  paste("Step4B records:", n_step4b),
  paste("Step5C Audit records:", n_audit),
  paste("Final RELEVANT:", n_relevant),
  paste("Final IRRELEVANT:", n_irrelevant),
  paste("Final UNCERTAIN:", n_uncertain),
  paste(
    "Relevant + Irrelevant + Uncertain:",
    n_relevant + n_irrelevant + n_uncertain
  ),
  paste("Record count PASS:", record_count_pass),
  "",
  
  "3. FINAL ARTICLE ID",
  paste("Missing IDs in Audit:", audit_missing_id),
  paste("Duplicate IDs in Audit:", audit_duplicate_id),
  paste("Missing IDs in Relevant:", relevant_missing_id),
  paste("Duplicate IDs in Relevant:", relevant_duplicate_id),
  paste("ID integrity PASS:", id_integrity_pass),
  "",
  
  "4. FINAL DECISIONS",
  paste("Missing decisions:", missing_decisions),
  paste(
    "Invalid decision values:",
    ifelse(
      length(invalid_decisions) == 0,
      "None",
      paste(invalid_decisions, collapse = " | ")
    )
  ),
  paste("Decision structure PASS:", decision_structure_pass),
  "",
  
  "Decision counts:",
  paste("RELEVANT:", relevant_decision_count),
  paste("IRRELEVANT:", irrelevant_decision_count),
  paste("UNCERTAIN:", uncertain_decision_count),
  paste("Decision count PASS:", decision_count_pass),
  "",
  
  "5. RELEVANT SET RECONCILIATION",
  paste(
    "Relevant IDs missing from final Relevant file:",
    length(missing_from_relevant)
  ),
  paste(
    "Extra IDs in final Relevant file:",
    length(extra_in_relevant)
  ),
  paste("Relevant set match PASS:", relevant_set_match_pass),
  "",
  
  "6. IRRELEVANT SET RECONCILIATION",
  paste(
    "Irrelevant IDs missing from final Irrelevant file:",
    length(missing_from_irrelevant)
  ),
  paste(
    "Extra IDs in final Irrelevant file:",
    length(extra_in_irrelevant)
  ),
  paste("Irrelevant set match PASS:", irrelevant_set_match_pass),
  "",
  
  "7. UNCERTAIN SET RECONCILIATION",
  paste(
    "Uncertain IDs missing from final Uncertain file:",
    length(missing_from_uncertain)
  ),
  paste(
    "Extra IDs in final Uncertain file:",
    length(extra_in_uncertain)
  ),
  paste("Uncertain set match PASS:", uncertain_set_match_pass),
  "",
  
  "8. STEP5A → STEP5C RECONCILIATION",
  paste("Step5A records:", n_step5a),
  paste("Step5C Audit records:", n_audit),
  paste(
    "Step5A IDs missing from Step5C:",
    length(missing_from_audit)
  ),
  paste(
    "Step5C IDs not present in Step5A:",
    length(extra_in_audit)
  ),
  paste(
    "Step5A → Step5C reconciliation PASS:",
    step5a_to_step5c_pass
  ),
  "",
  
  "9. DATA SCIENCE MATCH VALIDATION",
  paste(
    "Data_Science_Match_Any_Field = TRUE:",
    ds_match_true
  ),
  paste(
    "Data_Science_Match_Any_Field = FALSE:",
    ds_match_false
  ),
  paste(
    "Data_Science_Match_Any_Field = NA:",
    ds_match_na
  ),
  paste(
    "Expected TRUE = 15172 and FALSE = 50"
  ),
  paste(
    "Data Science match count PASS:",
    ds_match_count_pass
  ),
  "",
  
  "10. MATCHED RECORD RELEVANCE",
  paste(
    "Matched records:",
    length(matched_step5a_ids)
  ),
  paste(
    "Matched records not classified RELEVANT:",
    matched_not_relevant
  ),
  paste(
    "Matched records are RELEVANT PASS:",
    matched_relevance_pass
  ),
  "",
  
  "11. NO-MATCH MANUAL REVIEW",
  paste(
    "No-match records:",
    length(no_match_step5a_ids)
  ),
  paste(
    "No-match records not classified IRRELEVANT:",
    no_match_not_irrelevant
  ),
  paste(
    "No-match manual classification PASS:",
    no_match_manual_pass
  ),
  "",
  
  "12. STEP4B → STEP5C LINKAGE",
  paste("Step4B records:", n_step4b),
  paste("Step5C Audit records:", n_audit),
  paste(
    "Step5C IDs not found in Step4B:",
    length(step5c_not_in_step4b)
  ),
  paste(
    "Step4B IDs not found in Step5C:",
    length(step4b_missing_from_step5c)
  ),
  paste(
    "Step4B → Step5C linkage PASS:",
    step4b_linkage_pass
  ),
  "",
  
  "13. YEAR",
  paste("Minimum year:", ifelse("Year" %in% names(audit), min(year_numeric, na.rm = TRUE), NA)),
  paste("Maximum year:", ifelse("Year" %in% names(audit), max(year_numeric, na.rm = TRUE), NA)),
  paste("Missing year:", missing_year),
  paste("Outside 2000–2025:", outside_year),
  paste("Year validation PASS:", year_pass),
  "",
  
  "14. LANGUAGE",
  paste("Missing language:", missing_language),
  paste("Invalid/non-English records:", non_english_records),
  paste(
    "Invalid language tokens:",
    ifelse(
      length(invalid_language_tokens) == 0,
      "None",
      paste(invalid_language_tokens, collapse = " | ")
    )
  ),
  paste("Language validation PASS:", language_pass),
  "",
  
  "15. RETRACTION",
  paste("Retraction TRUE:", retraction_true),
  paste("Retraction FALSE:", retraction_false),
  paste("Retraction missing:", retraction_missing),
  paste("Retraction validation PASS:", retraction_pass),
  "",
  
  "16. DOCUMENT TYPE",
  paste("Missing document type:", document_type_missing),
  paste("Document type validation PASS:", document_type_pass),
  "",
  
  "17. OVERALL VALIDATION"
)

# اضافه کردن چک‌های نهایی
for (i in seq_len(nrow(validation_summary))) {
  
  report_lines <- c(
    report_lines,
    paste(
      validation_summary$Check[i],
      ":",
      validation_summary$PASS[i]
    )
  )
}

report_lines <- c(
  report_lines,
  "",
  paste(
    "OVERALL STATUS:",
    ifelse(overall_pass, "PASS", "CHECK REQUIRED")
  ),
  "",
  "IMPORTANT METHODOLOGICAL NOTE:",
  "This validation checks structural integrity, record reconciliation,",
  "relevance-decision consistency, linkage to Step5A and Step4B,",
  "and preservation of the final Step5C corpus.",
  "",
  "It does NOT calculate Accuracy, Precision, Recall, F1,",
  "or confidence intervals, because Step5C is a corpus construction",
  "and manual relevance-audit stage rather than a predictive model.",
  "",
  "The original Step5C files were not modified.",
  "Step5A remains unchanged.",
  "Step4B remains unchanged.",
  "",
  "============================================================"
)

writeLines(
  report_lines,
  con = file.path(
    validation_dir,
    "Step5C_Independent_Final_Validation_Report.txt"
  ),
  useBytes = TRUE
)


# -----------------------------
# 28. نمایش نتیجه در Console
# -----------------------------

cat("\n")
cat("============================================================\n")
cat("STEP 5C INDEPENDENT VALIDATION\n")
cat("============================================================\n\n")

cat("Step5A records:", n_step5a, "\n")
cat("Step4B records:", n_step4b, "\n")
cat("Step5C Audit records:", n_audit, "\n")
cat("Final RELEVANT:", n_relevant, "\n")
cat("Final IRRELEVANT:", n_irrelevant, "\n")
cat("Final UNCERTAIN:", n_uncertain, "\n\n")

cat("Data Science Match TRUE:", ds_match_true, "\n")
cat("Data Science Match FALSE:", ds_match_false, "\n")
cat("Data Science Match NA:", ds_match_na, "\n\n")

cat("Duplicate IDs:", audit_duplicate_id, "\n")
cat("Duplicate DOI check: handled in Step4B\n")
cat("Step4B → Step5C linkage missing IDs:",
    length(step5c_not_in_step4b), "\n\n")

cat("------------------------------------------------------------\n")
cat("VALIDATION RESULTS\n")
cat("------------------------------------------------------------\n")

for (i in seq_len(nrow(validation_summary))) {
  
  cat(
    validation_summary$Check[i],
    ":",
    ifelse(
      validation_summary$PASS[i],
      "PASS",
      "FAIL"
    ),
    "\n"
  )
}

cat("------------------------------------------------------------\n")

if (overall_pass) {
  
  cat("\n")
  cat("STEP 5C INDEPENDENT VALIDATION: PASS\n")
  cat("\n")
  cat("Step5C final corpus is structurally and logically consistent.\n")
  cat("No Step5C source file was modified.\n")
  
} else {
  
  cat("\n")
  cat("STEP 5C INDEPENDENT VALIDATION: CHECK REQUIRED\n")
  cat("\n")
  cat("At least one validation criterion requires inspection.\n")
}

cat("\nValidation folder:\n")
cat(validation_dir, "\n")

cat("\n============================================================\n")