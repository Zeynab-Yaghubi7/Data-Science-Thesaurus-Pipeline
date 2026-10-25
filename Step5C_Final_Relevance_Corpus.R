# ============================================================
# STEP 5C
# APPLY MANUAL RELEVANCE DECISIONS
# AND CREATE FINAL RELEVANCE CORPUS
# ============================================================

# ------------------------------------------------------------
# 1. مسیرها
# ------------------------------------------------------------

input_step5a <- paste0(
  "D:/Thesis/data/Step5_Relevance_Eligibility_Audit/",
  "Step5A_Data_Science_Screening/",
  "Step5A_Data_Science_Screening_Audit.csv"
)

manual_file <- paste0(
  "D:/Thesis/data/Step5_Relevance_Eligibility_Audit/",
  "Step5B_Manual_Relevance_Investigation_FINAL/",
  "Step5B_FINAL_Investigation_Review_Table.csv"
)

output_dir <- paste0(
  "D:/Thesis/data/Step5_Relevance_Eligibility_Audit/",
  "Step5C_Final_Relevance_Corpus"
)

if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}


# ------------------------------------------------------------
# 2. خواندن فایل Step5A
# ------------------------------------------------------------

step5a <- read.csv(
  input_step5a,
  stringsAsFactors = FALSE,
  check.names = FALSE,
  na.strings = c("", "NA")
)

cat("Step5A records:", nrow(step5a), "\n")


# ------------------------------------------------------------
# 3. خواندن فایل تصمیم‌های دستی
# ------------------------------------------------------------

manual <- read.csv(
  manual_file,
  stringsAsFactors = FALSE,
  check.names = FALSE,
  na.strings = c("", "NA")
)

cat("Manual investigation records:", nrow(manual), "\n")


# ------------------------------------------------------------
# 4. بررسی ستون‌های ضروری
# ------------------------------------------------------------

required_step5a <- c(
  "Final_Article_ID",
  "Data_Science_Match_Any_Field"
)

required_manual <- c(
  "Final_Article_ID",
  "Manual_Relevance_Decision",
  "Manual_Reason"
)

missing_step5a <- setdiff(
  required_step5a,
  names(step5a)
)

missing_manual <- setdiff(
  required_manual,
  names(manual)
)

if (length(missing_step5a) > 0) {
  stop(
    paste(
      "Missing columns in Step5A:",
      paste(missing_step5a, collapse = ", ")
    )
  )
}

if (length(missing_manual) > 0) {
  stop(
    paste(
      "Missing columns in manual file:",
      paste(missing_manual, collapse = ", ")
    )
  )
}


# ------------------------------------------------------------
# 5. کنترل تعداد رکوردهای بررسی دستی
# ------------------------------------------------------------

if (nrow(manual) != 50) {
  stop(
    paste(
      "Expected 50 manual investigation records, but found:",
      nrow(manual)
    )
  )
}


# ------------------------------------------------------------
# 6. کنترل تصمیم‌های دستی
# ------------------------------------------------------------

manual$Manual_Relevance_Decision <- toupper(
  trimws(manual$Manual_Relevance_Decision)
)

allowed_decisions <- c(
  "RELEVANT",
  "IRRELEVANT",
  "UNCERTAIN"
)

invalid_decisions <- setdiff(
  unique(manual$Manual_Relevance_Decision),
  allowed_decisions
)

if (length(invalid_decisions) > 0) {
  stop(
    paste(
      "Invalid manual decisions found:",
      paste(invalid_decisions, collapse = ", ")
    )
  )
}


# ------------------------------------------------------------
# 7. کنترل تصمیم‌های خالی
# ------------------------------------------------------------

if (any(is.na(manual$Manual_Relevance_Decision)) ||
    any(manual$Manual_Relevance_Decision == "")) {
  
  stop(
    "Some manual relevance decisions are missing."
  )
}


# ------------------------------------------------------------
# 8. کنترل شناسه‌های تکراری در فایل دستی
# ------------------------------------------------------------

if (anyDuplicated(manual$Final_Article_ID) > 0) {
  
  duplicated_ids <- unique(
    manual$Final_Article_ID[
      duplicated(manual$Final_Article_ID)
    ]
  )
  
  stop(
    paste(
      "Duplicate Final_Article_ID values found in manual file:",
      paste(duplicated_ids, collapse = " | ")
    )
  )
}


# ------------------------------------------------------------
# 9. بررسی اینکه هر 50 رکورد واقعاً جزو
#    No Match های Step5A هستند
# ------------------------------------------------------------

step5a_no_match <- step5a[
  step5a$Data_Science_Match_Any_Field == FALSE,
  ,
  drop = FALSE
]

cat(
  "Step5A no-match records:",
  nrow(step5a_no_match),
  "\n"
)

if (nrow(step5a_no_match) != 50) {
  
  stop(
    paste(
      "Step5A no-match count is not 50. Found:",
      nrow(step5a_no_match)
    )
  )
}


# ------------------------------------------------------------
# 10. کنترل تطابق شناسه‌های 50 رکورد
# ------------------------------------------------------------

missing_in_step5a <- setdiff(
  manual$Final_Article_ID,
  step5a_no_match$Final_Article_ID
)

if (length(missing_in_step5a) > 0) {
  
  stop(
    paste(
      "Some manually reviewed IDs are not found among Step5A no-match records:",
      paste(missing_in_step5a, collapse = " | ")
    )
  )
}


# ------------------------------------------------------------
# 11. ایجاد جدول تصمیم‌های دستی برای اتصال
# ------------------------------------------------------------

manual_decisions <- manual[
  ,
  c(
    "Final_Article_ID",
    "Manual_Relevance_Decision",
    "Manual_Reason"
  ),
  drop = FALSE
]


# ------------------------------------------------------------
# 12. اتصال تصمیم‌های دستی به Step5A
# ------------------------------------------------------------

step5c_audit <- merge(
  step5a,
  manual_decisions,
  by = "Final_Article_ID",
  all.x = TRUE,
  sort = FALSE
)


# ------------------------------------------------------------
# 13. تعیین وضعیت نهایی relevance
# ------------------------------------------------------------

step5c_audit$Final_Relevance_Decision <-
  ifelse(
    step5c_audit$Data_Science_Match_Any_Field == TRUE,
    "RELEVANT",
    step5c_audit$Manual_Relevance_Decision
  )


# ------------------------------------------------------------
# 14. تعیین مبنای تصمیم
# ------------------------------------------------------------

step5c_audit$Final_Decision_Basis <-
  ifelse(
    step5c_audit$Data_Science_Match_Any_Field == TRUE,
    "Data Science/Data Sciences detected in screening fields",
    "Manual relevance investigation"
  )


# ------------------------------------------------------------
# 15. کنترل اینکه هیچ رکوردی بلاتکلیف نمانده باشد
# ------------------------------------------------------------

missing_final_decision <- is.na(
  step5c_audit$Final_Relevance_Decision
) |
  step5c_audit$Final_Relevance_Decision == ""

if (any(missing_final_decision)) {
  
  stop(
    paste(
      "Records without final relevance decision:",
      sum(missing_final_decision)
    )
  )
}


# ------------------------------------------------------------
# 16. خلاصه تصمیم‌ها
# ------------------------------------------------------------

final_decision_summary <- as.data.frame(
  table(
    step5c_audit$Final_Relevance_Decision,
    useNA = "ifany"
  )
)

names(final_decision_summary) <- c(
  "Final_Relevance_Decision",
  "Records"
)


# ------------------------------------------------------------
# 17. خلاصه مبنای تصمیم
# ------------------------------------------------------------

decision_basis_summary <- as.data.frame(
  table(
    step5c_audit$Final_Decision_Basis,
    useNA = "ifany"
  )
)

names(decision_basis_summary) <- c(
  "Final_Decision_Basis",
  "Records"
)


# ------------------------------------------------------------
# 18. استخراج Corpus نهایی
# ------------------------------------------------------------

final_corpus <- step5c_audit[
  step5c_audit$Final_Relevance_Decision == "RELEVANT",
  ,
  drop = FALSE
]


# ------------------------------------------------------------
# 19. استخراج رکوردهای حذف‌شده از Corpus
# ------------------------------------------------------------

final_irrelevant <- step5c_audit[
  step5c_audit$Final_Relevance_Decision == "IRRELEVANT",
  ,
  drop = FALSE
]


# ------------------------------------------------------------
# 20. استخراج رکوردهای UNCERTAIN
# ------------------------------------------------------------

final_uncertain <- step5c_audit[
  step5c_audit$Final_Relevance_Decision == "UNCERTAIN",
  ,
  drop = FALSE
]


# ------------------------------------------------------------
# 21. کنترل نهایی مورد انتظار
# ------------------------------------------------------------

input_n <- nrow(step5a)
relevant_n <- nrow(final_corpus)
irrelevant_n <- nrow(final_irrelevant)
uncertain_n <- nrow(final_uncertain)

cat("\n=============================\n")
cat("STEP 5C FINAL COUNTS\n")
cat("=============================\n")

cat("Input records:", input_n, "\n")
cat("RELEVANT:", relevant_n, "\n")
cat("IRRELEVANT:", irrelevant_n, "\n")
cat("UNCERTAIN:", uncertain_n, "\n")

cat(
  "Relevant + Irrelevant + Uncertain:",
  relevant_n + irrelevant_n + uncertain_n,
  "\n"
)


# ------------------------------------------------------------
# 22. کنترل حسابی
# ------------------------------------------------------------

if (
  relevant_n +
  irrelevant_n +
  uncertain_n !=
  input_n
) {
  
  stop(
    "FINAL DECISION ARITHMETIC CHECK FAILED."
  )
}


# ------------------------------------------------------------
# 23. کنترل نتیجه مورد انتظار فعلی
# ------------------------------------------------------------

if (relevant_n != 15172) {
  
  stop(
    paste(
      "Expected 15,172 final relevant records, but found:",
      relevant_n
    )
  )
}

if (irrelevant_n != 50) {
  
  stop(
    paste(
      "Expected 50 final irrelevant records, but found:",
      irrelevant_n
    )
  )
}

if (uncertain_n != 0) {
  
  stop(
    paste(
      "Expected 0 uncertain records, but found:",
      uncertain_n
    )
  )
}


# ------------------------------------------------------------
# 24. ذخیره Corpus نهایی
# ------------------------------------------------------------

write.csv(
  final_corpus,
  file.path(
    output_dir,
    "Step5C_FINAL_RELEVANT_CORPUS.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)


# ------------------------------------------------------------
# 25. ذخیره رکوردهای IRRELEVANT
# ------------------------------------------------------------

write.csv(
  final_irrelevant,
  file.path(
    output_dir,
    "Step5C_FINAL_IRRELEVANT_RECORDS.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)


# ------------------------------------------------------------
# 26. ذخیره رکوردهای UNCERTAIN
# ------------------------------------------------------------

write.csv(
  final_uncertain,
  file.path(
    output_dir,
    "Step5C_FINAL_UNCERTAIN_RECORDS.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)


# ------------------------------------------------------------
# 27. ذخیره کل Audit
# ------------------------------------------------------------

write.csv(
  step5c_audit,
  file.path(
    output_dir,
    "Step5C_FINAL_RELEVANCE_AUDIT.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)


# ------------------------------------------------------------
# 28. ذخیره خلاصه تصمیم‌ها
# ------------------------------------------------------------

write.csv(
  final_decision_summary,
  file.path(
    output_dir,
    "Step5C_Final_Decision_Summary.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)


# ------------------------------------------------------------
# 29. ذخیره خلاصه مبنای تصمیم
# ------------------------------------------------------------

write.csv(
  decision_basis_summary,
  file.path(
    output_dir,
    "Step5C_Decision_Basis_Summary.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)


# ------------------------------------------------------------
# 30. گزارش نهایی
# ------------------------------------------------------------

report <- c(
  "============================================================",
  "STEP 5C – FINAL RELEVANCE CORPUS",
  "============================================================",
  "",
  paste("Input records:", input_n),
  paste("Final RELEVANT records:", relevant_n),
  paste("Final IRRELEVANT records:", irrelevant_n),
  paste("Final UNCERTAIN records:", uncertain_n),
  "",
  "MANUAL INVESTIGATION",
  paste(
    "Records manually investigated:",
    nrow(manual)
  ),
  paste(
    "Manual RELEVANT:",
    sum(manual$Manual_Relevance_Decision == "RELEVANT")
  ),
  paste(
    "Manual IRRELEVANT:",
    sum(manual$Manual_Relevance_Decision == "IRRELEVANT")
  ),
  paste(
    "Manual UNCERTAIN:",
    sum(manual$Manual_Relevance_Decision == "UNCERTAIN")
  ),
  "",
  "FINAL AUDIT",
  paste(
    "RELEVANT + IRRELEVANT + UNCERTAIN =",
    relevant_n + irrelevant_n + uncertain_n
  ),
  paste(
    "Expected total =",
    input_n
  ),
  "Audit status: PASS",
  "",
  "No records were deleted from Step5A.",
  "The final relevance corpus was created as a separate output.",
  "Step5A remains unchanged and immutable.",
  "",
  "============================================================"
)

writeLines(
  report,
  file.path(
    output_dir,
    "Step5C_Final_Relevance_Corpus_Report.txt"
  ),
  useBytes = TRUE
)


# ------------------------------------------------------------
# 31. فهرست فایل‌های خروجی
# ------------------------------------------------------------

cat("\n=============================\n")
cat("STEP 5C COMPLETED SUCCESSFULLY\n")
cat("=============================\n")

cat(
  "Output folder:",
  output_dir,
  "\n\n"
)

print(
  list.files(
    output_dir,
    full.names = FALSE
  )
)

cat("\nFinal corpus records:", nrow(final_corpus), "\n")
cat("Final irrelevant records:", nrow(final_irrelevant), "\n")
cat("Final uncertain records:", nrow(final_uncertain), "\n")
cat("\nSTATUS: PASS\n")