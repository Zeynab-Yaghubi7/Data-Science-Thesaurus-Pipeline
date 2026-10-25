# ============================================================
# STEP 5A – DATA SCIENCE RELEVANCE SCREENING / AUDIT
# Final version – singular + plural
# ============================================================

library(readr)
library(dplyr)
library(stringr)
library(tidyr)

# ------------------------------------------------------------
# 1. Paths
# ------------------------------------------------------------

input_file <- "D:/Thesis/data/Step4_Deduplication_Metadata_Merging/Step4B_Final_Deduplication_Metadata_Merging/Scopus_WoS_Eligible_2000_2025_English_Article_Review_FINAL_DEDUP.csv"

output_dir <- "D:/Thesis/data/Step5_Relevance_Eligibility_Audit/Step5A_Data_Science_Screening"

if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

# ------------------------------------------------------------
# 2. Read official Step4B
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
# 4. Normalize search text
# ------------------------------------------------------------
# هدف:
# یکسان‌سازی حالت‌هایی مانند:
#
# data science
# data sciences
# data-science
# data-sciences
# data/science
# data/sciences
# data   science
# data   sciences
#
# بدون تغییر معنای عبارت جست‌وجو
# ------------------------------------------------------------

normalize_search_text <- function(x) {
  
  x <- safe_text(x)
  
  x <- str_to_lower(x)
  
  # تبدیل punctuation به فاصله
  x <- str_replace_all(
    x,
    "[[:punct:]]+",
    " "
  )
  
  # حذف فاصله‌های اضافی
  x <- str_squish(x)
  
  x
}

# ------------------------------------------------------------
# 5. Search pattern
# ------------------------------------------------------------
# این الگو هر دو شکل زیر را شناسایی می‌کند:
#
# data science
# data sciences
#
# علامت ? باعث می‌شود حرف s اختیاری باشد.
# ------------------------------------------------------------

pattern <- "\\bdata\\s+sciences?\\b"

# ------------------------------------------------------------
# 6. Fields used for screening
# ------------------------------------------------------------

fields <- c(
  "Title",
  "Abstract",
  "Author_Keywords_Scopus",
  "Index_Keywords_Scopus",
  "Author_Keywords_WoS",
  "Keywords_Plus_WoS"
)

# ------------------------------------------------------------
# 7. Check required fields
# ------------------------------------------------------------

missing_fields <- setdiff(
  fields,
  names(df)
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
# 8. Detect Data Science / Data Sciences in each field
# ------------------------------------------------------------

for (f in fields) {
  
  new_name <- paste0(
    "DS_Match_",
    f
  )
  
  df[[new_name]] <- str_detect(
    normalize_search_text(df[[f]]),
    regex(
      pattern,
      ignore_case = TRUE
    )
  )
}

# ------------------------------------------------------------
# 9. Overall match
# ------------------------------------------------------------

match_columns <- paste0(
  "DS_Match_",
  fields
)

df$Data_Science_Match_Any_Field <- apply(
  df[, match_columns, drop = FALSE],
  1,
  any
)

# ------------------------------------------------------------
# 10. Number of matched fields
# ------------------------------------------------------------

df$Number_of_Matched_Fields <- rowSums(
  df[, match_columns, drop = FALSE]
)

# ------------------------------------------------------------
# 11. Match location
# ------------------------------------------------------------

df$Match_Location <- apply(
  df[, match_columns, drop = FALSE],
  1,
  function(x) {
    
    matched <- fields[
      as.logical(x)
    ]
    
    if (length(matched) == 0) {
      return("No detected match")
    }
    
    if (length(matched) == 1) {
      return(matched)
    }
    
    return("Multiple fields")
  }
)

# ------------------------------------------------------------
# 12. Initial screening status
# ------------------------------------------------------------

df$Initial_Screening_Status <- ifelse(
  df$Data_Science_Match_Any_Field,
  "Data Science / Data Sciences phrase detected",
  "No Data Science / Data Sciences phrase detected"
)

# ------------------------------------------------------------
# 13. Retraction status
# ------------------------------------------------------------

if ("Retraction_Flag" %in% names(df)) {
  
  df$Retraction_Flag <- as.logical(
    df$Retraction_Flag
  )
  
} else {
  
  df$Retraction_Flag <- FALSE
}

# ------------------------------------------------------------
# 14. Main output
# ------------------------------------------------------------

main_output <- file.path(
  output_dir,
  "Step5A_Data_Science_Screening_Audit.csv"
)

write_csv(
  df,
  main_output,
  na = ""
)

# ------------------------------------------------------------
# 15. Potentially eligible records
# ------------------------------------------------------------

potentially_eligible <- df %>%
  filter(
    Data_Science_Match_Any_Field == TRUE
  )

write_csv(
  potentially_eligible,
  file.path(
    output_dir,
    "Step5A_Potentially_Eligible_Data_Science.csv"
  ),
  na = ""
)

# ------------------------------------------------------------
# 16. Investigation queue
# ------------------------------------------------------------

investigation_queue <- df %>%
  filter(
    Data_Science_Match_Any_Field == FALSE
  )

write_csv(
  investigation_queue,
  file.path(
    output_dir,
    "Step5A_Investigation_Queue_No_Data_Science_Match.csv"
  ),
  na = ""
)

# ------------------------------------------------------------
# 17. Field-level summary
# ------------------------------------------------------------

field_summary <- data.frame(
  Field = fields,
  Records_With_Data_Science = sapply(
    fields,
    function(f) {
      
      sum(
        df[[paste0("DS_Match_", f)]],
        na.rm = TRUE
      )
      
    }
  )
)

field_summary$Percentage_of_All_Records <-
  round(
    field_summary$Records_With_Data_Science /
      input_records * 100,
    2
  )

write_csv(
  field_summary,
  file.path(
    output_dir,
    "Step5A_Field_Level_Summary.csv"
  )
)

# ------------------------------------------------------------
# 18. Match-location summary
# ------------------------------------------------------------

match_location_summary <- df %>%
  count(
    Match_Location,
    name = "Records"
  ) %>%
  mutate(
    Percentage = round(
      Records /
        input_records *
        100,
      2
    )
  ) %>%
  arrange(
    desc(Records)
  )

write_csv(
  match_location_summary,
  file.path(
    output_dir,
    "Step5A_Match_Location_Summary.csv"
  )
)

# ------------------------------------------------------------
# 19. Database summary
# ------------------------------------------------------------

if ("Source_Database" %in% names(df)) {
  
  database_summary <- df %>%
    group_by(
      Source_Database
    ) %>%
    summarise(
      Total_Records = n(),
      
      Data_Science_Match = sum(
        Data_Science_Match_Any_Field
      ),
      
      No_Data_Science_Match = sum(
        !Data_Science_Match_Any_Field
      ),
      
      Match_Percentage = round(
        Data_Science_Match /
          Total_Records *
          100,
        2
      ),
      
      .groups = "drop"
    )
  
  write_csv(
    database_summary,
    file.path(
      output_dir,
      "Step5A_Database_Summary.csv"
    )
  )
}

# ------------------------------------------------------------
# 20. Year summary
# ------------------------------------------------------------

if ("Year" %in% names(df)) {
  
  year_summary <- df %>%
    group_by(
      Year
    ) %>%
    summarise(
      Total_Records = n(),
      
      Data_Science_Match = sum(
        Data_Science_Match_Any_Field
      ),
      
      No_Data_Science_Match = sum(
        !Data_Science_Match_Any_Field
      ),
      
      Match_Percentage = round(
        Data_Science_Match /
          Total_Records *
          100,
        2
      ),
      
      .groups = "drop"
    ) %>%
    arrange(
      Year
    )
  
  write_csv(
    year_summary,
    file.path(
      output_dir,
      "Step5A_Year_Summary.csv"
    )
  )
}

# ------------------------------------------------------------
# 21. Basic audit checks
# ------------------------------------------------------------

matched_n <- sum(
  df$Data_Science_Match_Any_Field
)

unmatched_n <- sum(
  !df$Data_Science_Match_Any_Field
)

# ------------------------------------------------------------
# 22. Additional singular/plural diagnostic
# ------------------------------------------------------------
# این بخش فقط برای گزارش است و در تصمیم‌گیری نهایی استفاده نمی‌شود.
# ------------------------------------------------------------

singular_pattern <- "\\bdata\\s+science\\b"

plural_pattern <- "\\bdata\\s+sciences\\b"

all_search_text <- apply(
  df[, fields, drop = FALSE],
  1,
  function(row) {
    
    paste(
      normalize_search_text(row),
      collapse = " "
    )
    
  }
)

singular_only_n <- sum(
  str_detect(
    all_search_text,
    regex(
      singular_pattern,
      ignore_case = TRUE
    )
  ) &
    !str_detect(
      all_search_text,
      regex(
        plural_pattern,
        ignore_case = TRUE
      )
    )
)

plural_only_n <- sum(
  str_detect(
    all_search_text,
    regex(
      plural_pattern,
      ignore_case = TRUE
    )
  ) &
    !str_detect(
      all_search_text,
      regex(
        singular_pattern,
        ignore_case = TRUE
      )
    )
)

both_n <- sum(
  str_detect(
    all_search_text,
    regex(
      singular_pattern,
      ignore_case = TRUE
    )
  ) &
    str_detect(
      all_search_text,
      regex(
        plural_pattern,
        ignore_case = TRUE
      )
    )
)

# ------------------------------------------------------------
# 23. Report
# ------------------------------------------------------------

report_file <- file.path(
  output_dir,
  "Step5A_Data_Science_Screening_Report.txt"
)

report_lines <- c(
  
  "============================================================",
  "STEP 5A – DATA SCIENCE RELEVANCE SCREENING / AUDIT",
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
  "SCREENING LOGIC",
  "------------------------------------------------------------",
  
  "Search concepts:",
  "data science",
  "data sciences",
  "",
  
  "Search pattern: data + whitespace + science(s)",
  "Case-insensitive: YES",
  "Text normalization: YES",
  "Punctuation normalization: YES",
  "",
  
  "Fields searched:",
  paste(
    fields,
    collapse = ", "
  ),
  
  "",
  "IMPORTANT:",
  "This is an audit/screening stage.",
  "No records were deleted.",
  "Records without a detected Data Science / Data Sciences phrase",
  "were flagged for investigation and were NOT automatically",
  "classified as irrelevant.",
  "",
  
  "RESULTS",
  "------------------------------------------------------------",
  
  paste(
    "Data Science / Data Sciences detected:",
    matched_n
  ),
  
  paste(
    "No Data Science / Data Sciences match:",
    unmatched_n
  ),
  
  paste(
    "Match percentage:",
    round(
      matched_n /
        input_records *
        100,
      2
    ),
    "%"
  ),
  
  paste(
    "No-match percentage:",
    round(
      unmatched_n /
        input_records *
        100,
      2
    ),
    "%"
  ),
  
  "",
  "SINGULAR / PLURAL DIAGNOSTIC",
  "------------------------------------------------------------",
  
  paste(
    "Singular only (data science):",
    singular_only_n
  ),
  
  paste(
    "Plural only (data sciences):",
    plural_only_n
  ),
  
  paste(
    "Both singular and plural:",
    both_n
  ),
  
  "",
  "AUDIT CHECK",
  "------------------------------------------------------------",
  
  paste(
    "Matched + unmatched:",
    matched_n +
      unmatched_n
  ),
  
  paste(
    "Input records:",
    input_records
  ),
  
  paste(
    "Audit status:",
    ifelse(
      matched_n +
        unmatched_n ==
        input_records,
      "PASS",
      "FAIL"
    )
  ),
  
  "",
  "RETRACTIONS",
  "------------------------------------------------------------",
  
  paste(
    "Retraction records retained:",
    sum(
      df$Retraction_Flag,
      na.rm = TRUE
    )
  ),
  
  "",
  "OUTPUT",
  "------------------------------------------------------------",
  
  paste(
    "Main audit:",
    main_output
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
# 24. Console summary
# ------------------------------------------------------------

cat("\n")
cat("============================================================\n")
cat("STEP 5A COMPLETED\n")
cat("============================================================\n")

cat(
  "Input records:",
  input_records,
  "\n"
)

cat(
  "Input columns:",
  input_columns,
  "\n"
)

cat(
  "Data Science / Data Sciences detected:",
  matched_n,
  "\n"
)

cat(
  "No match:",
  unmatched_n,
  "\n"
)

cat(
  "Match percentage:",
  round(
    matched_n /
      input_records *
      100,
    2
  ),
  "%\n"
)

cat(
  "Singular only:",
  singular_only_n,
  "\n"
)

cat(
  "Plural only:",
  plural_only_n,
  "\n"
)

cat(
  "Both singular and plural:",
  both_n,
  "\n"
)

cat(
  "Audit check:",
  ifelse(
    matched_n +
      unmatched_n ==
      input_records,
    "PASS",
    "FAIL"
  ),
  "\n"
)

cat(
  "Output folder:",
  output_dir,
  "\n"
)

cat("============================================================\n")