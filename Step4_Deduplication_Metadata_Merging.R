# ============================================================
# STEP 4
# DEDUPLICATION + METADATA MERGING
# ============================================================

library(readr)
library(dplyr)
library(stringr)
library(tidyr)

# ============================================================
# 1. PATHS
# ============================================================

input_file <- "D:/Thesis/data/Step2_Eligibility_2000_2025_English_Article_Review/Scopus_WoS_Eligible_2000_2025_English_Article_Review_PRE_DEDUP.csv"

step4_dir <- "D:/Thesis/data/Step4_Deduplication_Metadata_Merging"

if (!dir.exists(step4_dir)) {
  dir.create(step4_dir, recursive = TRUE)
}

# ============================================================
# 2. READ INPUT
# ============================================================

M <- read_csv(
  input_file,
  show_col_types = FALSE,
  na = c("", "NA", "N/A")
)

cat("Input records:", nrow(M), "\n")
cat("Input columns:", ncol(M), "\n")

# ============================================================
# 3. BASIC VALIDATION
# ============================================================

required_columns <- c(
  "Source_Database",
  "Original_ID",
  "DOI",
  "Title",
  "Year",
  "Authors",
  "Abstract",
  "Author_Keywords_Scopus",
  "Index_Keywords_Scopus",
  "Author_Keywords_WoS",
  "Keywords_Plus_WoS",
  "Cited_By_Scopus",
  "Cited_By_WoS",
  "References_Scopus",
  "References_WoS",
  "Source_Title",
  "Document_Type",
  "Language",
  "UT_WoS"
)

missing_required <- setdiff(required_columns, names(M))

if (length(missing_required) > 0) {
  stop(
    paste(
      "Missing required columns:",
      paste(missing_required, collapse = ", ")
    )
  )
}

# ============================================================
# 4. NORMALIZATION FUNCTIONS
# ============================================================

normalize_doi <- function(x) {
  
  x <- as.character(x)
  
  x <- str_to_lower(x)
  
  x <- str_trim(x)
  
  x <- str_replace(
    x,
    "^https?://(dx\\.)?doi\\.org/",
    ""
  )
  
  x <- str_replace(
    x,
    "^doi:\\s*",
    ""
  )
  
  x <- str_replace_all(
    x,
    "[[:space:]]+",
    ""
  )
  
  x <- str_remove(
    x,
    "[[:punct:]]+$"
  )
  
  x[x %in% c("", "na", "n/a", "null")] <- NA_character_
  
  x
}


normalize_title <- function(x) {
  
  x <- as.character(x)
  
  x <- str_to_lower(x)
  
  x <- str_replace_all(
    x,
    "[^[:alnum:][:space:]]",
    " "
  )
  
  x <- str_squish(x)
  
  x[x == ""] <- NA_character_
  
  x
}


normalize_first_author <- function(x) {
  
  x <- as.character(x)
  
  x <- str_to_lower(x)
  
  x <- str_replace_all(
    x,
    "[^[:alnum:][:space:]]",
    " "
  )
  
  x <- str_squish(x)
  
  x[x == ""] <- NA_character_
  
  x
}

# ============================================================
# 5. CREATE NORMALIZED MATCHING FIELDS
# ============================================================

M <- M %>%
  mutate(
    
    DOI_Normalized = normalize_doi(DOI),
    
    Title_Normalized = normalize_title(Title),
    
    First_Author_Normalized =
      normalize_first_author(
        str_extract(
          coalesce(Authors, ""),
          "^[^;|]+"
        )
      )
    
  )

# ============================================================
# 6. DOI-BASED MATCH GROUPS
# ============================================================

doi_groups <- M %>%
  filter(!is.na(DOI_Normalized)) %>%
  group_by(DOI_Normalized) %>%
  summarise(
    
    Number_of_Records = n(),
    
    Number_of_Databases =
      n_distinct(Source_Database),
    
    Databases =
      paste(
        sort(unique(Source_Database)),
        collapse = " | "
      ),
    
    .groups = "drop"
    
  )

# ============================================================
# 7. CLASSIFY DOI MATCHES
# ============================================================

M <- M %>%
  left_join(
    doi_groups,
    by = "DOI_Normalized"
  ) %>%
  mutate(
    
    DOI_Match_Type = case_when(
      
      is.na(Number_of_Records) ~
        "No DOI",
      
      Number_of_Records == 1 ~
        "Unique DOI",
      
      Number_of_Databases >= 2 ~
        "Cross-database DOI duplicate",
      
      Number_of_Databases == 1 ~
        "Within-database DOI duplicate",
      
      TRUE ~
        "Other"
      
    )
    
  )

# ============================================================
# 8. WO S UT MATCHING FOR RECORDS WITHOUT DOI
# ============================================================

M <- M %>%
  mutate(
    UT_Normalized = str_trim(as.character(UT_WoS)),
    UT_Normalized = na_if(UT_Normalized, ""),
    UT_Normalized = na_if(UT_Normalized, "NA")
  )

ut_groups <- M %>%
  filter(
    is.na(DOI_Normalized),
    !is.na(UT_Normalized)
  ) %>%
  group_by(UT_Normalized) %>%
  summarise(
    
    UT_Number_of_Records = n(),
    
    UT_Number_of_Databases =
      n_distinct(Source_Database),
    
    UT_Databases =
      paste(
        sort(unique(Source_Database)),
        collapse = " | "
      ),
    
    .groups = "drop"
    
  )

M <- M %>%
  left_join(
    ut_groups,
    by = "UT_Normalized"
  ) %>%
  mutate(
    
    UT_Match_Type = case_when(
      
      !is.na(DOI_Normalized) ~
        "DOI already matched",
      
      is.na(UT_Number_of_Records) ~
        "No usable UT",
      
      UT_Number_of_Records == 1 ~
        "Unique UT",
      
      UT_Number_of_Databases >= 2 ~
        "Cross-database UT duplicate",
      
      UT_Number_of_Databases == 1 ~
        "Within-database UT duplicate",
      
      TRUE ~
        "Other"
      
    )
    
  )

# ============================================================
# 9. TITLE + YEAR + FIRST AUTHOR MATCHING
# ============================================================

M <- M %>%
  mutate(
    
    TitleYearAuthor_Key = paste(
      Title_Normalized,
      Year,
      First_Author_Normalized,
      sep = " | "
    )
    
  )

title_groups <- M %>%
  filter(
    is.na(DOI_Normalized),
    is.na(UT_Normalized),
    !is.na(Title_Normalized),
    !is.na(Year),
    !is.na(First_Author_Normalized)
  ) %>%
  group_by(TitleYearAuthor_Key) %>%
  summarise(
    
    TitleYearAuthor_Number_of_Records = n(),
    
    TitleYearAuthor_Number_of_Databases =
      n_distinct(Source_Database),
    
    TitleYearAuthor_Databases =
      paste(
        sort(unique(Source_Database)),
        collapse = " | "
      ),
    
    .groups = "drop"
    
  )

M <- M %>%
  left_join(
    title_groups,
    by = "TitleYearAuthor_Key"
  ) %>%
  mutate(
    
    TitleYearAuthor_Match_Type = case_when(
      
      !is.na(DOI_Normalized) ~
        "DOI already matched",
      
      !is.na(UT_Normalized) ~
        "UT already checked",
      
      is.na(TitleYearAuthor_Number_of_Records) ~
        "No title-year-author match",
      
      TitleYearAuthor_Number_of_Records == 1 ~
        "Unique title-year-author",
      
      TitleYearAuthor_Number_of_Databases >= 2 ~
        "Cross-database title-year-author duplicate",
      
      TitleYearAuthor_Number_of_Databases == 1 ~
        "Within-database title-year-author duplicate",
      
      TRUE ~
        "Other"
      
    )
    
  )

# ============================================================
# 10. DEFINE FINAL MATCH METHOD
# ============================================================

M <- M %>%
  mutate(
    
    Final_Match_Method = case_when(
      
      DOI_Match_Type == "Cross-database DOI duplicate" ~
        "DOI",
      
      DOI_Match_Type == "Within-database DOI duplicate" ~
        "DOI",
      
      !is.na(DOI_Normalized) ~
        "Unique DOI",
      
      UT_Match_Type == "Cross-database UT duplicate" ~
        "WoS UT",
      
      UT_Match_Type == "Within-database UT duplicate" ~
        "WoS UT",
      
      !is.na(UT_Normalized) ~
        "Unique WoS UT",
      
      TitleYearAuthor_Match_Type ==
        "Cross-database title-year-author duplicate" ~
        "Title-Year-FirstAuthor",
      
      TitleYearAuthor_Match_Type ==
        "Within-database title-year-author duplicate" ~
        "Title-Year-FirstAuthor",
      
      !is.na(Title_Normalized) &
        !is.na(Year) &
        !is.na(First_Author_Normalized) ~
        "Unique Title-Year-FirstAuthor",
      
      TRUE ~
        "Unmatched"
      
    )
    
  )

# ============================================================
# 11. DATABASE-LEVEL MATCH DIAGNOSTICS
# ============================================================

cross_database_matches <- M %>%
  filter(
    DOI_Match_Type == "Cross-database DOI duplicate" |
      UT_Match_Type == "Cross-database UT duplicate" |
      TitleYearAuthor_Match_Type ==
      "Cross-database title-year-author duplicate"
  ) %>%
  arrange(
    DOI_Normalized,
    UT_Normalized,
    Title_Normalized
  )

within_database_duplicates <- M %>%
  filter(
    DOI_Match_Type == "Within-database DOI duplicate" |
      UT_Match_Type == "Within-database UT duplicate" |
      TitleYearAuthor_Match_Type ==
      "Within-database title-year-author duplicate"
  )

unmatched_records <- M %>%
  filter(
    Final_Match_Method == "Unmatched"
  )

# ============================================================
# 12. RETRACTION FLAG
# ============================================================

M <- M %>%
  mutate(
    
    Retraction_Flag = case_when(
      
      str_detect(
        str_to_lower(coalesce(Document_Type, "")),
        "retract"
      ) ~ TRUE,
      
      TRUE ~ FALSE
      
    )
    
  )

retraction_flagged <- M %>%
  filter(Retraction_Flag)

# ============================================================
# 13. SUMMARY TABLES
# ============================================================

match_method_summary <- M %>%
  count(
    Final_Match_Method,
    name = "Records"
  ) %>%
  arrange(desc(Records))

database_summary <- M %>%
  count(
    Source_Database,
    name = "Records"
  )

retraction_summary <- M %>%
  count(
    Source_Database,
    Retraction_Flag,
    name = "Records"
  )

# ============================================================
# 14. SAVE DIAGNOSTIC DATA
# ============================================================

write_csv(
  cross_database_matches,
  file.path(
    step4_dir,
    "Step4_CrossDatabase_Matches.csv"
  )
)

write_csv(
  within_database_duplicates,
  file.path(
    step4_dir,
    "Step4_WithinDatabase_Duplicates.csv"
  )
)

write_csv(
  unmatched_records,
  file.path(
    step4_dir,
    "Step4_Unmatched_Records.csv"
  )
)

write_csv(
  retraction_flagged,
  file.path(
    step4_dir,
    "Step4_Retraction_Flagged.csv"
  )
)

write_csv(
  match_method_summary,
  file.path(
    step4_dir,
    "Step4_Match_Method_Summary.csv"
  )
)

# ============================================================
# 15. REPORT
# ============================================================

report_file <- file.path(
  step4_dir,
  "Step4_Deduplication_Metadata_Merging_Report.txt"
)

sink(report_file)

cat("============================================================\n")
cat("STEP 4 - DEDUPLICATION + METADATA MERGING\n")
cat("============================================================\n\n")

cat("Input file:\n")
cat(input_file, "\n\n")

cat("Input records:", nrow(M), "\n")
cat("Input columns:", ncol(M), "\n\n")

cat("------------------------------------------------------------\n")
cat("DATABASE SUMMARY\n")
cat("------------------------------------------------------------\n\n")

print(database_summary)

cat("\n------------------------------------------------------------\n")
cat("MATCH METHOD SUMMARY\n")
cat("------------------------------------------------------------\n\n")

print(match_method_summary)

cat("\n------------------------------------------------------------\n")
cat("DOI DUPLICATE SUMMARY\n")
cat("------------------------------------------------------------\n\n")

cat(
  "Records with DOI:",
  sum(!is.na(M$DOI_Normalized)),
  "\n"
)

cat(
  "Records without DOI:",
  sum(is.na(M$DOI_Normalized)),
  "\n"
)

cat(
  "Cross-database DOI duplicate records:",
  sum(
    M$DOI_Match_Type ==
      "Cross-database DOI duplicate",
    na.rm = TRUE
  ),
  "\n"
)

cat(
  "Within-database DOI duplicate records:",
  sum(
    M$DOI_Match_Type ==
      "Within-database DOI duplicate",
    na.rm = TRUE
  ),
  "\n\n"
)

cat("------------------------------------------------------------\n")
cat("WO S UT SUMMARY\n")
cat("------------------------------------------------------------\n\n")

cat(
  "Records with usable WoS UT:",
  sum(!is.na(M$UT_Normalized)),
  "\n"
)

cat(
  "Cross-database UT duplicate records:",
  sum(
    M$UT_Match_Type ==
      "Cross-database UT duplicate",
    na.rm = TRUE
  ),
  "\n"
)

cat(
  "Within-database UT duplicate records:",
  sum(
    M$UT_Match_Type ==
      "Within-database UT duplicate",
    na.rm = TRUE
  ),
  "\n\n"
)

cat("------------------------------------------------------------\n")
cat("TITLE-YEAR-FIRST AUTHOR SUMMARY\n")
cat("------------------------------------------------------------\n\n")

cat(
  "Cross-database title-year-first-author duplicate records:",
  sum(
    M$TitleYearAuthor_Match_Type ==
      "Cross-database title-year-author duplicate",
    na.rm = TRUE
  ),
  "\n"
)

cat(
  "Within-database title-year-first-author duplicate records:",
  sum(
    M$TitleYearAuthor_Match_Type ==
      "Within-database title-year-author duplicate",
    na.rm = TRUE
  ),
  "\n\n"
)

cat("------------------------------------------------------------\n")
cat("RETRACTION SUMMARY\n")
cat("------------------------------------------------------------\n\n")

cat(
  "Retraction-flagged records:",
  sum(M$Retraction_Flag),
  "\n\n"
)

print(retraction_summary)

cat("\n------------------------------------------------------------\n")
cat("UNMATCHED RECORDS\n")
cat("------------------------------------------------------------\n\n")

cat(
  "Records classified as unmatched:",
  nrow(unmatched_records),
  "\n\n"
)

cat("============================================================\n")
cat("IMPORTANT METHODOLOGICAL NOTE\n")
cat("============================================================\n\n")

cat(
  "Step 4 identifies potential duplicate records using the following hierarchy:\n"
)

cat("1. DOI\n")
cat("2. WoS UT for records without DOI\n")
cat("3. Title + Year + First Author for remaining records\n\n")

cat(
  "No record is deleted automatically in this stage.\n"
)

cat(
  "Scopus and WoS records are retained separately for diagnostic review.\n"
)

cat(
  "Retraction records are flagged but not deleted.\n"
)

sink()

# ============================================================
# 16. SAVE INTERMEDIATE STEP 4 DATA
# ============================================================

write_csv(
  M,
  file.path(
    step4_dir,
    "Step4_Deduplication_Audit_Data.csv"
  )
)

cat("\n============================================================\n")
cat("STEP 4 AUDIT COMPLETED\n")
cat("============================================================\n")

cat("Output folder:\n")
cat(step4_dir, "\n\n")

cat("Input records:", nrow(M), "\n")
cat("Report:", report_file, "\n")