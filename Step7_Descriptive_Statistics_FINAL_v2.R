# ============================================================
# STEP 7 FINAL v2 - DESCRIPTIVE STATISTICS
# Final Relevant Corpus: 15,172 records
# ============================================================

# ------------------------------------------------------------
# 1. مسیرها
# ------------------------------------------------------------

input_file <- "D:/Thesis/data/Step5_Relevance_Eligibility_Audit/Step5C_Final_Relevance_Corpus/Step5C_FINAL_RELEVANT_CORPUS.csv"

output_dir <- "D:/Thesis/data/Step7_Descriptive_Statistics_FINAL_v2"

if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

# ------------------------------------------------------------
# 2. خواندن داده
# ------------------------------------------------------------

data <- read.csv(
  input_file,
  stringsAsFactors = FALSE,
  check.names = FALSE,
  na.strings = c("", "NA", "N/A", "NULL")
)

original_n <- nrow(data)
original_p <- ncol(data)

cat("============================================\n")
cat("STEP 7 FINAL v2 - DESCRIPTIVE STATISTICS\n")
cat("============================================\n")
cat("Records:", original_n, "\n")
cat("Original columns:", original_p, "\n\n")

# ------------------------------------------------------------
# 3. توابع کمکی
# ------------------------------------------------------------

is_missing <- function(x) {
  is.na(x) | trimws(as.character(x)) == ""
}

count_items <- function(x) {
  
  x <- x[!is_missing(x)]
  
  if (length(x) == 0) {
    return(character(0))
  }
  
  items <- unlist(
    strsplit(x, ";", fixed = TRUE)
  )
  
  items <- trimws(items)
  
  items <- items[
    items != "" & !is.na(items)
  ]
  
  items
}

# ------------------------------------------------------------
# 4. بررسی ستون‌های ضروری
# ------------------------------------------------------------

required_cols <- c(
  "Final_Article_ID",
  "Source_Database",
  "DOI",
  "Title",
  "Year",
  "Authors",
  "Abstract",
  "Author_Keywords_Combined",
  "Source_Title",
  "Document_Type",
  "Language",
  "Retraction_Flag"
)

missing_cols <- setdiff(
  required_cols,
  names(data)
)

if (length(missing_cols) > 0) {
  
  stop(
    paste(
      "ERROR: Missing required columns:",
      paste(missing_cols, collapse = ", ")
    )
  )
}

# ------------------------------------------------------------
# 5. استانداردسازی Source Database
# فقط برای آمار توصیفی
# ------------------------------------------------------------

data$Source_Standard <- trimws(
  data$Source_Database
)

data$Source_Standard[
  grepl(
    "Scopus",
    data$Source_Standard,
    ignore.case = TRUE
  ) &
    grepl(
      "WoS",
      data$Source_Standard,
      ignore.case = TRUE
    )
] <- "Scopus + WoS"

data$Source_Standard[
  grepl(
    "^Scopus$",
    data$Source_Standard,
    ignore.case = TRUE
  )
] <- "Scopus"

data$Source_Standard[
  grepl(
    "^WoS$",
    data$Source_Standard,
    ignore.case = TRUE
  )
] <- "WoS"

# ------------------------------------------------------------
# 6. استانداردسازی زبان
# ------------------------------------------------------------

data$Language_Standard <- ifelse(
  grepl(
    "ENGLISH",
    data$Language,
    ignore.case = TRUE
  ),
  "English",
  trimws(data$Language)
)

# ------------------------------------------------------------
# 7. استانداردسازی نوع مدرک
#
# Article فقط
# Review فقط
# Article + Review = اختلاف/ترکیب متادیتای منابع
# ------------------------------------------------------------

doc_upper <- toupper(
  data$Document_Type
)

data$Document_Type_Standard <- ifelse(
  
  grepl(
    "ARTICLE",
    doc_upper
  ) &
    grepl(
      "REVIEW",
      doc_upper
    ),
  
  "Article + Review",
  
  ifelse(
    
    grepl(
      "ARTICLE",
      doc_upper
    ),
    
    "Article",
    
    ifelse(
      
      grepl(
        "REVIEW",
        doc_upper
      ),
      
      "Review",
      
      "Other"
    )
  )
)

# ------------------------------------------------------------
# 8. تعداد نویسندگان
# ------------------------------------------------------------

data$Author_Count <- sapply(
  
  data$Authors,
  
  function(x) {
    
    if (is_missing(x)) {
      return(0)
    }
    
    authors <- unlist(
      strsplit(
        x,
        ";",
        fixed = TRUE
      )
    )
    
    authors <- trimws(
      authors
    )
    
    authors <- authors[
      authors != ""
    ]
    
    length(authors)
  }
)

# ------------------------------------------------------------
# 9. تعداد Author Keywords
# ------------------------------------------------------------

data$Keyword_Count <- sapply(
  
  data$Author_Keywords_Combined,
  
  function(x) {
    
    if (is_missing(x)) {
      return(0)
    }
    
    keywords <- unlist(
      strsplit(
        x,
        ";",
        fixed = TRUE
      )
    )
    
    keywords <- trimws(
      keywords
    )
    
    keywords <- keywords[
      keywords != ""
    ]
    
    length(keywords)
  }
)

# ------------------------------------------------------------
# 10. Source Database
# ------------------------------------------------------------

source_table <- as.data.frame(
  table(
    data$Source_Standard
  ),
  stringsAsFactors = FALSE
)

names(source_table) <- c(
  "Source_Database",
  "Records"
)

source_table$Percentage <- round(
  source_table$Records /
    original_n * 100,
  2
)

source_table <- source_table[
  order(
    -source_table$Records
  ),
]

# ------------------------------------------------------------
# 11. Language
# ------------------------------------------------------------

language_table <- as.data.frame(
  table(
    data$Language_Standard
  ),
  stringsAsFactors = FALSE
)

names(language_table) <- c(
  "Language",
  "Records"
)

language_table$Percentage <- round(
  language_table$Records /
    original_n * 100,
  2
)

language_table <- language_table[
  order(
    -language_table$Records
  ),
]

# ------------------------------------------------------------
# 12. Document Type
# ------------------------------------------------------------

document_table <- as.data.frame(
  table(
    data$Document_Type_Standard
  ),
  stringsAsFactors = FALSE
)

names(document_table) <- c(
  "Document_Type",
  "Records"
)

document_table$Percentage <- round(
  document_table$Records /
    original_n * 100,
  2
)

document_table <- document_table[
  order(
    -document_table$Records
  ),
]

# ------------------------------------------------------------
# 13. Annual Production
# 2000 تا 2025 = 26 سال تقویمی
# ------------------------------------------------------------

year_table <- data.frame(
  Year = 2000:2025,
  Records = 0
)

year_counts <- table(
  data$Year
)

for (i in seq_along(year_table$Year)) {
  
  y <- as.character(
    year_table$Year[i]
  )
  
  if (y %in% names(year_counts)) {
    
    year_table$Records[i] <-
      as.integer(
        year_counts[y]
      )
  }
}

year_table$Percentage <- round(
  year_table$Records /
    original_n * 100,
  2
)

# تعداد سال‌های تقویمی
calendar_years <- length(
  2000:2025
)

# تعداد سال‌هایی که حداقل یک رکورد دارند
years_with_records <- sum(
  year_table$Records > 0
)

# سال‌هایی با صفر رکورد
years_without_records <- sum(
  year_table$Records == 0
)

# ------------------------------------------------------------
# 14. DOI Availability
# ------------------------------------------------------------

doi_available <- sum(
  !is_missing(data$DOI)
)

doi_missing <- sum(
  is_missing(data$DOI)
)

doi_table <- data.frame(
  DOI_Status = c(
    "Available",
    "Missing"
  ),
  Records = c(
    doi_available,
    doi_missing
  )
)

doi_table$Percentage <- round(
  doi_table$Records /
    original_n * 100,
  2
)

# ------------------------------------------------------------
# 15. Abstract Availability
# ------------------------------------------------------------

abstract_available <- sum(
  !is_missing(data$Abstract)
)

abstract_missing <- sum(
  is_missing(data$Abstract)
)

abstract_table <- data.frame(
  Abstract_Status = c(
    "Available",
    "Missing"
  ),
  Records = c(
    abstract_available,
    abstract_missing
  )
)

abstract_table$Percentage <- round(
  abstract_table$Records /
    original_n * 100,
  2
)

# ------------------------------------------------------------
# 16. Author Keyword Availability
# ------------------------------------------------------------

keywords_available <- sum(
  !is_missing(
    data$Author_Keywords_Combined
  )
)

keywords_missing <- sum(
  is_missing(
    data$Author_Keywords_Combined
  )
)

keyword_availability_table <- data.frame(
  Author_Keyword_Status = c(
    "Available",
    "Missing"
  ),
  Records = c(
    keywords_available,
    keywords_missing
  )
)

keyword_availability_table$Percentage <- round(
  keyword_availability_table$Records /
    original_n * 100,
  2
)

# ------------------------------------------------------------
# 17. Retraction Status
# ------------------------------------------------------------

retraction_table <- as.data.frame(
  table(
    data$Retraction_Flag
  ),
  stringsAsFactors = FALSE
)

names(retraction_table) <- c(
  "Retraction_Flag",
  "Records"
)

retraction_table$Percentage <- round(
  retraction_table$Records /
    original_n * 100,
  2
)

# ------------------------------------------------------------
# 18. Author Statistics
# ------------------------------------------------------------

author_stats <- data.frame(
  Variable = "Authors per article",
  N = original_n,
  Minimum = min(
    data$Author_Count
  ),
  Maximum = max(
    data$Author_Count
  ),
  Mean = round(
    mean(data$Author_Count),
    2
  ),
  Median = round(
    median(data$Author_Count),
    2
  ),
  SD = round(
    sd(data$Author_Count),
    2
  )
)

# ------------------------------------------------------------
# 19. Author Keyword Statistics
# ------------------------------------------------------------

keyword_stats <- data.frame(
  Variable = "Author keywords per article",
  N = original_n,
  Minimum = min(
    data$Keyword_Count
  ),
  Maximum = max(
    data$Keyword_Count
  ),
  Mean = round(
    mean(data$Keyword_Count),
    2
  ),
  Median = round(
    median(data$Keyword_Count),
    2
  ),
  SD = round(
    sd(data$Keyword_Count),
    2
  )
)

# ------------------------------------------------------------
# 20. Top 20 Sources
# ------------------------------------------------------------

source_counts <- sort(
  table(
    trimws(data$Source_Title)
  ),
  decreasing = TRUE
)

source_counts <- source_counts[
  names(source_counts) != ""
]

top20_sources <- data.frame(
  
  Rank = seq_len(
    min(
      20,
      length(source_counts)
    )
  ),
  
  Source_Title = names(
    source_counts[
      seq_len(
        min(
          20,
          length(source_counts)
        )
      )
    ]
  ),
  
  Records = as.integer(
    source_counts[
      seq_len(
        min(
          20,
          length(source_counts)
        )
      )
    ]
  ),
  
  stringsAsFactors = FALSE
)

# ------------------------------------------------------------
# 21. Top 20 Authors
# ------------------------------------------------------------

author_items <- count_items(
  data$Authors
)

author_counts <- sort(
  table(author_items),
  decreasing = TRUE
)

top20_authors <- data.frame(
  
  Rank = seq_len(
    min(
      20,
      length(author_counts)
    )
  ),
  
  Author = names(
    author_counts[
      seq_len(
        min(
          20,
          length(author_counts)
        )
      )
    ]
  ),
  
  Records = as.integer(
    author_counts[
      seq_len(
        min(
          20,
          length(author_counts)
        )
      )
    ]
  ),
  
  stringsAsFactors = FALSE
)

# ------------------------------------------------------------
# 22. Top 20 Raw Author Keywords
#
# توجه:
# این جدول خام است و هنوز synonym / case normalization
# روی آن انجام نشده است.
# ------------------------------------------------------------

keyword_items <- count_items(
  data$Author_Keywords_Combined
)

keyword_items <- trimws(
  keyword_items
)

keyword_items <- keyword_items[
  keyword_items != ""
]

keyword_counts <- sort(
  table(keyword_items),
  decreasing = TRUE
)

top20_keywords <- data.frame(
  
  Rank = seq_len(
    min(
      20,
      length(keyword_counts)
    )
  ),
  
  Author_Keyword = names(
    keyword_counts[
      seq_len(
        min(
          20,
          length(keyword_counts)
        )
      )
    ]
  ),
  
  Frequency = as.integer(
    keyword_counts[
      seq_len(
        min(
          20,
          length(keyword_counts)
        )
      )
    ]
  ),
  
  stringsAsFactors = FALSE
)

# ------------------------------------------------------------
# 23. Overall Summary
# ------------------------------------------------------------

overall_summary <- data.frame(
  
  Indicator = c(
    
    "Total records",
    
    "Study period start",
    
    "Study period end",
    
    "Calendar years in study period",
    
    "Years with at least one record",
    
    "Years with zero records",
    
    "Records with DOI",
    
    "Records without DOI",
    
    "Records with Abstract",
    
    "Records without Abstract",
    
    "Records with Author Keywords",
    
    "Records without Author Keywords",
    
    "Records with retraction flag",
    
    "Original input columns",
    
    "Analysis variables added",
    
    "Final in-memory columns"
  ),
  
  Value = c(
    
    original_n,
    
    min(data$Year),
    
    max(data$Year),
    
    calendar_years,
    
    years_with_records,
    
    years_without_records,
    
    doi_available,
    
    doi_missing,
    
    abstract_available,
    
    abstract_missing,
    
    keywords_available,
    
    keywords_missing,
    
    sum(
      data$Retraction_Flag == TRUE,
      na.rm = TRUE
    ),
    
    original_p,
    
    5,
    
    ncol(data)
  ),
  
  stringsAsFactors = FALSE
)

# ------------------------------------------------------------
# 24. Validation Checks
# ------------------------------------------------------------

checks <- data.frame(
  
  Check = c(
    
    "Record count",
    
    "Year range",
    
    "Calendar year count",
    
    "Years with/without records",
    
    "Source total",
    
    "Language total",
    
    "Document type total",
    
    "DOI total",
    
    "Abstract total",
    
    "Keyword availability total",
    
    "Analysis columns",
    
    "Original corpus unchanged"
  ),
  
  Result = c(
    
    ifelse(
      original_n == 15172,
      "PASS",
      "CHECK"
    ),
    
    ifelse(
      min(data$Year) >= 2000 &
        max(data$Year) <= 2025,
      "PASS",
      "CHECK"
    ),
    
    ifelse(
      calendar_years == 26,
      "PASS",
      "CHECK"
    ),
    
    ifelse(
      years_with_records +
        years_without_records ==
        calendar_years,
      "PASS",
      "CHECK"
    ),
    
    ifelse(
      sum(source_table$Records) ==
        original_n,
      "PASS",
      "CHECK"
    ),
    
    ifelse(
      sum(language_table$Records) ==
        original_n,
      "PASS",
      "CHECK"
    ),
    
    ifelse(
      sum(document_table$Records) ==
        original_n,
      "PASS",
      "CHECK"
    ),
    
    ifelse(
      sum(doi_table$Records) ==
        original_n,
      "PASS",
      "CHECK"
    ),
    
    ifelse(
      sum(abstract_table$Records) ==
        original_n,
      "PASS",
      "CHECK"
    ),
    
    ifelse(
      sum(
        keyword_availability_table$Records
      ) ==
        original_n,
      "PASS",
      "CHECK"
    ),
    
    ifelse(
      ncol(data) ==
        original_p + 5,
      "PASS",
      "CHECK"
    ),
    
    ifelse(
      original_n == 15172 &
        original_p == 40,
      "PASS",
      "CHECK"
    )
  ),
  
  stringsAsFactors = FALSE
)

# ------------------------------------------------------------
# 25. ذخیره CSV ها
# ------------------------------------------------------------

write.csv(
  overall_summary,
  file.path(
    output_dir,
    "Step7_Final_Overall_Summary.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

write.csv(
  source_table,
  file.path(
    output_dir,
    "Step7_Final_Source_Database.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

write.csv(
  language_table,
  file.path(
    output_dir,
    "Step7_Final_Language.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

write.csv(
  document_table,
  file.path(
    output_dir,
    "Step7_Final_Document_Type.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

write.csv(
  year_table,
  file.path(
    output_dir,
    "Step7_Final_Annual_Production.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

write.csv(
  doi_table,
  file.path(
    output_dir,
    "Step7_Final_DOI_Availability.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

write.csv(
  abstract_table,
  file.path(
    output_dir,
    "Step7_Final_Abstract_Availability.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

write.csv(
  keyword_availability_table,
  file.path(
    output_dir,
    "Step7_Final_Author_Keyword_Availability.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

write.csv(
  retraction_table,
  file.path(
    output_dir,
    "Step7_Final_Retraction_Status.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

write.csv(
  author_stats,
  file.path(
    output_dir,
    "Step7_Final_Author_Statistics.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

write.csv(
  keyword_stats,
  file.path(
    output_dir,
    "Step7_Final_Keyword_Statistics.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

write.csv(
  top20_sources,
  file.path(
    output_dir,
    "Step7_Final_Top20_Sources.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

write.csv(
  top20_authors,
  file.path(
    output_dir,
    "Step7_Final_Top20_Authors.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

write.csv(
  top20_keywords,
  file.path(
    output_dir,
    "Step7_Final_Top20_Author_Keywords_RAW.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

write.csv(
  checks,
  file.path(
    output_dir,
    "Step7_Final_Validation_Checks.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

# ------------------------------------------------------------
# 26. ذخیره Dataset تحلیلی
# ------------------------------------------------------------

write.csv(
  data,
  file.path(
    output_dir,
    "Step7_Final_Descriptive_Analysis_Dataset.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

# ------------------------------------------------------------
# 27. گزارش متنی کامل
# ------------------------------------------------------------

report_file <- file.path(
  output_dir,
  "Step7_Final_Descriptive_Statistics_Report.txt"
)

sink(report_file)

cat("============================================================\n")
cat("STEP 7 FINAL v2 - DESCRIPTIVE STATISTICS REPORT\n")
cat("============================================================\n\n")

cat("Input file:\n")
cat(input_file, "\n\n")

cat("Original records:", original_n, "\n")
cat("Original columns:", original_p, "\n")
cat("Analysis variables added: 5\n")
cat("Final in-memory columns:", ncol(data), "\n\n")

cat("NOTE:\n")
cat("The original final corpus was read-only and was NOT modified.\n")
cat("Five analysis variables were added only in memory/output dataset:\n")
cat("1. Source_Standard\n")
cat("2. Language_Standard\n")
cat("3. Document_Type_Standard\n")
cat("4. Author_Count\n")
cat("5. Keyword_Count\n\n")

cat("------------------------------------------------------------\n")
cat("1. OVERALL SUMMARY\n")
cat("------------------------------------------------------------\n\n")
print(
  overall_summary,
  row.names = FALSE
)

cat("\n------------------------------------------------------------\n")
cat("2. SOURCE DATABASE\n")
cat("------------------------------------------------------------\n\n")
print(
  source_table,
  row.names = FALSE
)

cat("\n------------------------------------------------------------\n")
cat("3. LANGUAGE\n")
cat("------------------------------------------------------------\n\n")
print(
  language_table,
  row.names = FALSE
)

cat("\n------------------------------------------------------------\n")
cat("4. DOCUMENT TYPE\n")
cat("------------------------------------------------------------\n\n")
print(
  document_table,
  row.names = FALSE
)

cat("\n------------------------------------------------------------\n")
cat("5. ANNUAL PRODUCTION\n")
cat("------------------------------------------------------------\n\n")
print(
  year_table,
  row.names = FALSE
)

cat("\nCalendar years in study period:",
    calendar_years, "\n")

cat("Years with at least one record:",
    years_with_records, "\n")

cat("Years with zero records:",
    years_without_records, "\n")

cat("\n------------------------------------------------------------\n")
cat("6. DOI AVAILABILITY\n")
cat("------------------------------------------------------------\n\n")
print(
  doi_table,
  row.names = FALSE
)

cat("\n------------------------------------------------------------\n")
cat("7. ABSTRACT AVAILABILITY\n")
cat("------------------------------------------------------------\n\n")
print(
  abstract_table,
  row.names = FALSE
)

cat("\n------------------------------------------------------------\n")
cat("8. AUTHOR KEYWORD AVAILABILITY\n")
cat("------------------------------------------------------------\n\n")
print(
  keyword_availability_table,
  row.names = FALSE
)

cat("\n------------------------------------------------------------\n")
cat("9. RETRACTION STATUS\n")
cat("------------------------------------------------------------\n\n")
print(
  retraction_table,
  row.names = FALSE
)

cat("\n------------------------------------------------------------\n")
cat("10. AUTHOR STATISTICS\n")
cat("------------------------------------------------------------\n\n")
print(
  author_stats,
  row.names = FALSE
)

cat("\n------------------------------------------------------------\n")
cat("11. AUTHOR KEYWORD STATISTICS\n")
cat("------------------------------------------------------------\n\n")
print(
  keyword_stats,
  row.names = FALSE
)

cat("\n------------------------------------------------------------\n")
cat("12. TOP 20 SOURCES\n")
cat("------------------------------------------------------------\n\n")
print(
  top20_sources,
  row.names = FALSE
)

cat("\n------------------------------------------------------------\n")
cat("13. TOP 20 AUTHORS\n")
cat("------------------------------------------------------------\n\n")
print(
  top20_authors,
  row.names = FALSE
)

cat("\n------------------------------------------------------------\n")
cat("14. TOP 20 RAW AUTHOR KEYWORDS\n")
cat("------------------------------------------------------------\n\n")

cat(
  "IMPORTANT: This is a raw frequency table.\n"
)

cat(
  "Case normalization and synonym normalization are NOT yet applied.\n\n"
)

print(
  top20_keywords,
  row.names = FALSE
)

cat("\n------------------------------------------------------------\n")
cat("15. VALIDATION CHECKS\n")
cat("------------------------------------------------------------\n\n")
print(
  checks,
  row.names = FALSE
)

cat("\n============================================================\n")
cat("END OF REPORT\n")
cat("============================================================\n")

sink()

# ------------------------------------------------------------
# 28. نمایش نتیجه در Console
# ------------------------------------------------------------

cat("\n============================================\n")
cat("STEP 7 FINAL v2 COMPLETED\n")
cat("============================================\n")

cat("Records:", original_n, "\n")
cat("Original columns:", original_p, "\n")
cat("Analysis variables added: 5\n")
cat("Final in-memory columns:", ncol(data), "\n")

cat("Calendar years:", calendar_years, "\n")
cat("Years with records:", years_with_records, "\n")
cat("Years without records:", years_without_records, "\n\n")

cat("Output folder:\n")
cat(output_dir, "\n\n")

cat("Validation results:\n")
print(
  checks,
  row.names = FALSE
)

cat("\nAll output files were created successfully.\n")
cat("The original final corpus was NOT modified.\n")
