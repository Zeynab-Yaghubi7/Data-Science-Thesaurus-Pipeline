# ==========================================================
# STEP 1
# SCOPUS + WoS MASTER CREATION AND RAW MERGE
# ==========================================================
#
# هدف:
# 1. خواندن فایل خام Scopus
# 2. خواندن تمام فایل‌های خام WoS
# 3. استانداردسازی ساختار دو پایگاه
# 4. ساخت Scopus_Master
# 5. ساخت WoS_Master
# 6. ادغام دو Master بدون حذف Duplicate
# 7. ایجاد گزارش کامل مرحله 1
#
# IMPORTANT:
# در این مرحله هیچ Deduplication انجام نمی‌شود.
# تمام رکوردها حفظ می‌شوند.
#
# ==========================================================


# ==========================================================
# 0. پاک کردن محیط و بارگذاری بسته‌ها
# ==========================================================

rm(list = ls())

library(readr)
library(dplyr)
library(stringr)
library(purrr)
library(bibliometrix)


# ==========================================================
# 1. تعریف مسیرها
# ==========================================================

# -------------------------
# Input files
# -------------------------

scopus_file <- "D:/Thesis/data/Scopus_Data/Scopus_Data.csv"

wos_dir <- "D:/Thesis/data/WOS_Data"


# -------------------------
# Step 1 output directory
# -------------------------

step1_dir <- "D:/Thesis/data/Step1_Scopus_WoS_Merged_RAW"

if (!dir.exists(step1_dir)) {
  dir.create(step1_dir, recursive = TRUE)
}


# ==========================================================
# 2. تعریف فایل‌های خروجی
# ==========================================================

scopus_master_file <- file.path(
  step1_dir,
  "Scopus_Master.csv"
)

wos_master_file <- file.path(
  step1_dir,
  "WoS_Master.csv"
)

merged_raw_file <- file.path(
  step1_dir,
  "Scopus_WoS_Merged_RAW.csv"
)

report_txt_file <- file.path(
  step1_dir,
  "Step1_Scopus_WoS_Merged_RAW_Report.txt"
)

record_count_file <- file.path(
  step1_dir,
  "Step1_Record_Counts.csv"
)

column_structure_file <- file.path(
  step1_dir,
  "Step1_Column_Structure.csv"
)

missingness_file <- file.path(
  step1_dir,
  "Step1_Missingness_Report.csv"
)


# ==========================================================
# 3. شروع گزارش متنی
# ==========================================================

report_lines <- c(
  "==========================================================",
  "STEP 1 - SCOPUS + WoS MASTER CREATION AND RAW MERGE",
  "==========================================================",
  "",
  paste("Date:", format(Sys.time(), "%Y-%m-%d")),
  paste("Time:", format(Sys.time(), "%H:%M:%S")),
  "",
  "IMPORTANT:",
  "No deduplication was performed in Step 1.",
  "All records imported from Scopus and WoS were retained.",
  "",
  "----------------------------------------------------------",
  "INPUT FILES",
  "----------------------------------------------------------",
  paste("Scopus input:", scopus_file),
  paste("WoS input directory:", wos_dir),
  ""
)


# ==========================================================
# 4. بررسی وجود فایل‌های ورودی
# ==========================================================

if (!file.exists(scopus_file)) {
  stop(
    paste(
      "Scopus file not found:",
      scopus_file
    )
  )
}

if (!dir.exists(wos_dir)) {
  stop(
    paste(
      "WoS directory not found:",
      wos_dir
    )
  )
}


# ==========================================================
# 5. خواندن Scopus
# ==========================================================

cat("\n==========================================\n")
cat("READING SCOPUS\n")
cat("==========================================\n")

scopus_raw <- read_csv(
  scopus_file,
  show_col_types = FALSE
)

scopus_initial_n <- nrow(scopus_raw)
scopus_initial_cols <- ncol(scopus_raw)

cat(
  "Scopus records:",
  scopus_initial_n,
  "\n"
)

cat(
  "Scopus columns:",
  scopus_initial_cols,
  "\n"
)


# ==========================================================
# 6. بررسی ستون‌های ضروری Scopus
# ==========================================================

required_scopus_columns <- c(
  "Authors",
  "Author full names",
  "Author(s) ID",
  "Title",
  "Year",
  "Source title",
  "Cited by",
  "DOI",
  "Abstract",
  "Author Keywords",
  "Index Keywords",
  "References",
  "Document Type",
  "Language of Original Document",
  "EID"
)

missing_scopus_columns <- setdiff(
  required_scopus_columns,
  names(scopus_raw)
)

if (length(missing_scopus_columns) > 0) {
  
  stop(
    paste(
      "The following required Scopus columns are missing:",
      paste(missing_scopus_columns, collapse = ", ")
    )
  )
  
}


# ==========================================================
# 7. ساخت Scopus Master
# ==========================================================

scopus_master <- scopus_raw %>%
  transmute(
    Source_Database = "Scopus",
    
    Original_ID = as.character(EID),
    
    DOI = as.character(DOI),
    
    Title = as.character(Title),
    
    Year = suppressWarnings(
      as.numeric(Year)
    ),
    
    Authors = as.character(Authors),
    
    Abstract = as.character(Abstract),
    
    Author_Keywords_Scopus =
      as.character(`Author Keywords`),
    
    Index_Keywords_Scopus =
      as.character(`Index Keywords`),
    
    Author_Keywords_WoS =
      NA_character_,
    
    Keywords_Plus_WoS =
      NA_character_,
    
    Cited_By_Scopus =
      suppressWarnings(
        as.numeric(`Cited by`)
      ),
    
    Cited_By_WoS =
      NA_real_,
    
    References_Scopus =
      as.character(References),
    
    References_WoS =
      NA_character_,
    
    Source_Title =
      as.character(`Source title`),
    
    Document_Type =
      as.character(`Document Type`),
    
    Language =
      as.character(`Language of Original Document`),
    
    UT_WoS =
      NA_character_
  )


# ==========================================================
# 8. بررسی فایل‌های WoS
# ==========================================================

wos_files <- list.files(
  wos_dir,
  pattern = "\\.txt$",
  full.names = TRUE,
  ignore.case = TRUE
)

wos_files <- sort(wos_files)

wos_file_count <- length(wos_files)

cat("\n==========================================\n")
cat("READING WoS\n")
cat("==========================================\n")

cat(
  "WoS files found:",
  wos_file_count,
  "\n"
)


if (wos_file_count == 0) {
  
  stop(
    "No WoS plaintext .txt files were found."
  )
  
}


# ==========================================================
# 9. خواندن تمام فایل‌های WoS
# ==========================================================

wos_list <- vector(
  "list",
  length(wos_files)
)

for (i in seq_along(wos_files)) {
  
  cat(
    "Reading WoS file",
    i,
    "of",
    wos_file_count,
    ":",
    basename(wos_files[i]),
    "\n"
  )
  
  wos_list[[i]] <- convert2df(
    wos_files[i],
    dbsource = "wos",
    format = "plaintext"
  )
  
}


# ==========================================================
# 10. ادغام رکوردهای WoS
# ==========================================================

wos_raw <- bind_rows(
  wos_list
)

wos_initial_n <- nrow(wos_raw)
wos_initial_cols <- ncol(wos_raw)

cat(
  "\nWoS records:",
  wos_initial_n,
  "\n"
)

cat(
  "WoS columns:",
  wos_initial_cols,
  "\n"
)


# ==========================================================
# 11. بررسی ستون‌های ضروری WoS
# ==========================================================

required_wos_columns <- c(
  "AU",
  "AB",
  "DE",
  "ID",
  "DI",
  "PY",
  "TC",
  "CR",
  "SO",
  "DT",
  "LA",
  "UT"
)

missing_wos_columns <- setdiff(
  required_wos_columns,
  names(wos_raw)
)

if (length(missing_wos_columns) > 0) {
  
  stop(
    paste(
      "The following required WoS columns are missing:",
      paste(missing_wos_columns, collapse = ", ")
    )
  )
  
}


# ==========================================================
# 12. ساخت WoS Master
# ==========================================================

wos_master <- wos_raw %>%
  transmute(
    
    Source_Database = "WoS",
    
    Original_ID =
      as.character(UT),
    
    DOI =
      as.character(DI),
    
    Title =
      as.character(TI),
    
    Year =
      suppressWarnings(
        as.numeric(PY)
      ),
    
    Authors =
      as.character(AU),
    
    Abstract =
      as.character(AB),
    
    Author_Keywords_Scopus =
      NA_character_,
    
    Index_Keywords_Scopus =
      NA_character_,
    
    Author_Keywords_WoS =
      as.character(DE),
    
    Keywords_Plus_WoS =
      as.character(ID),
    
    Cited_By_Scopus =
      NA_real_,
    
    Cited_By_WoS =
      suppressWarnings(
        as.numeric(TC)
      ),
    
    References_Scopus =
      NA_character_,
    
    References_WoS =
      as.character(CR),
    
    Source_Title =
      as.character(SO),
    
    Document_Type =
      as.character(DT),
    
    Language =
      as.character(LA),
    
    UT_WoS =
      as.character(UT)
  )


# ==========================================================
# 13. کنترل تعداد رکوردهای Master
# ==========================================================

scopus_master_n <- nrow(scopus_master)
wos_master_n <- nrow(wos_master)

if (scopus_master_n != scopus_initial_n) {
  
  stop(
    "Scopus record count changed during Master creation."
  )
  
}

if (wos_master_n != wos_initial_n) {
  
  stop(
    "WoS record count changed during Master creation."
  )
  
}


# ==========================================================
# 14. ادغام RAW
# ==========================================================

merged_raw <- bind_rows(
  scopus_master,
  wos_master
)

merged_raw_n <- nrow(merged_raw)
merged_raw_cols <- ncol(merged_raw)


# ==========================================================
# 15. کنترل تعداد رکوردهای RAW
# ==========================================================

expected_merged_n <-
  scopus_master_n +
  wos_master_n

if (merged_raw_n != expected_merged_n) {
  
  stop(
    "Merged RAW record count does not equal Scopus + WoS."
  )
  
}


# ==========================================================
# 16. کنترل ساختار ستون‌ها
# ==========================================================

expected_columns <- c(
  
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


if (!identical(
  names(scopus_master),
  expected_columns
)) {
  
  stop(
    "Scopus Master column structure is incorrect."
  )
  
}

if (!identical(
  names(wos_master),
  expected_columns
)) {
  
  stop(
    "WoS Master column structure is incorrect."
  )
  
}

if (!identical(
  names(merged_raw),
  expected_columns
)) {
  
  stop(
    "Merged RAW column structure is incorrect."
  )
  
}


# ==========================================================
# 17. ذخیره سه فایل اصلی
# ==========================================================

cat("\n==========================================\n")
cat("SAVING OUTPUT FILES\n")
cat("==========================================\n")


write_csv(
  scopus_master,
  scopus_master_file,
  na = ""
)

cat(
  "Scopus Master saved:",
  scopus_master_file,
  "\n"
)


write_csv(
  wos_master,
  wos_master_file,
  na = ""
)

cat(
  "WoS Master saved:",
  wos_master_file,
  "\n"
)


write_csv(
  merged_raw,
  merged_raw_file,
  na = ""
)

cat(
  "Merged RAW saved:",
  merged_raw_file,
  "\n"
)


# ==========================================================
# 18. آمار رکوردها
# ==========================================================

record_counts <- tibble(
  
  Dataset = c(
    "Scopus raw input",
    "Scopus Master",
    "WoS raw input",
    "WoS Master",
    "Merged RAW"
  ),
  
  Records = c(
    scopus_initial_n,
    scopus_master_n,
    wos_initial_n,
    wos_master_n,
    merged_raw_n
  ),
  
  Columns = c(
    scopus_initial_cols,
    ncol(scopus_master),
    wos_initial_cols,
    ncol(wos_master),
    ncol(merged_raw)
  )
)


write_csv(
  record_counts,
  record_count_file,
  na = ""
)


# ==========================================================
# 19. ساخت گزارش ساختار ستون‌ها
# ==========================================================

column_structure <- tibble(
  
  Column_Number =
    seq_along(expected_columns),
  
  Column_Name =
    expected_columns,
  
  Scopus_Master_Source =
    c(
      "Created",
      "Scopus EID",
      "DOI",
      "Title",
      "Year",
      "Authors",
      "Abstract",
      "Author Keywords",
      "Index Keywords",
      "Not applicable",
      "Not applicable",
      "Cited by",
      "Not applicable",
      "References",
      "Not applicable",
      "Source title",
      "Document Type",
      "Language",
      "Not applicable"
    ),
  
  WoS_Master_Source =
    c(
      "Created",
      "UT",
      "DI",
      "TI",
      "PY",
      "AU",
      "AB",
      "Not applicable",
      "Not applicable",
      "DE",
      "ID",
      "Not applicable",
      "TC",
      "Not applicable",
      "CR",
      "SO",
      "DT",
      "LA",
      "UT"
    )
)


write_csv(
  column_structure,
  column_structure_file,
  na = ""
)


# ==========================================================
# 20. Missingness report
# ==========================================================

missingness_report <- tibble(
  
  Dataset = c(
    "Scopus Master",
    "WoS Master",
    "Merged RAW"
  ),
  
  Total_Records = c(
    nrow(scopus_master),
    nrow(wos_master),
    nrow(merged_raw)
  ),
  
  Missing_DOI = c(
    sum(is.na(scopus_master$DOI) |
          str_trim(scopus_master$DOI) == ""),
    sum(is.na(wos_master$DOI) |
          str_trim(wos_master$DOI) == ""),
    sum(is.na(merged_raw$DOI) |
          str_trim(merged_raw$DOI) == "")
  ),
  
  Missing_Title = c(
    sum(is.na(scopus_master$Title) |
          str_trim(scopus_master$Title) == ""),
    sum(is.na(wos_master$Title) |
          str_trim(wos_master$Title) == ""),
    sum(is.na(merged_raw$Title) |
          str_trim(merged_raw$Title) == "")
  ),
  
  Missing_Year = c(
    sum(is.na(scopus_master$Year)),
    sum(is.na(wos_master$Year)),
    sum(is.na(merged_raw$Year))
  ),
  
  Missing_Authors = c(
    sum(is.na(scopus_master$Authors) |
          str_trim(scopus_master$Authors) == ""),
    sum(is.na(wos_master$Authors) |
          str_trim(wos_master$Authors) == ""),
    sum(is.na(merged_raw$Authors) |
          str_trim(merged_raw$Authors) == "")
  ),
  
  Missing_Abstract = c(
    sum(is.na(scopus_master$Abstract) |
          str_trim(scopus_master$Abstract) == ""),
    sum(is.na(wos_master$Abstract) |
          str_trim(wos_master$Abstract) == ""),
    sum(is.na(merged_raw$Abstract) |
          str_trim(merged_raw$Abstract) == "")
  ),
  
  Missing_Author_Keywords = c(
    sum(is.na(scopus_master$Author_Keywords_Scopus) |
          str_trim(scopus_master$Author_Keywords_Scopus) == ""),
    sum(is.na(wos_master$Author_Keywords_WoS) |
          str_trim(wos_master$Author_Keywords_WoS) == ""),
    sum(
      (merged_raw$Source_Database == "Scopus" &
         (is.na(merged_raw$Author_Keywords_Scopus) |
            str_trim(merged_raw$Author_Keywords_Scopus) == "")) |
        (merged_raw$Source_Database == "WoS" &
           (is.na(merged_raw$Author_Keywords_WoS) |
              str_trim(merged_raw$Author_Keywords_WoS) == ""))
    )
  )
)


write_csv(
  missingness_report,
  missingness_file,
  na = ""
)


# ==========================================================
# 21. آمار سال
# ==========================================================

year_summary <- merged_raw %>%
  group_by(Source_Database) %>%
  summarise(
    Min_Year = min(Year, na.rm = TRUE),
    Max_Year = max(Year, na.rm = TRUE),
    Missing_Year = sum(is.na(Year)),
    .groups = "drop"
  )


# ==========================================================
# 22. آمار Document Type
# ==========================================================

document_type_summary <- merged_raw %>%
  count(
    Source_Database,
    Document_Type,
    name = "Records"
  ) %>%
  arrange(
    Source_Database,
    desc(Records)
  )


# ==========================================================
# 23. آمار Language
# ==========================================================

language_summary <- merged_raw %>%
  count(
    Source_Database,
    Language,
    name = "Records"
  ) %>%
  arrange(
    Source_Database,
    desc(Records)
  )


# ==========================================================
# 24. DOI duplicate diagnostics
# ==========================================================
#
# فقط گزارش می‌شود.
# هیچ Duplicate حذف نمی‌شود.
#

doi_diagnostics <- merged_raw %>%
  filter(
    !is.na(DOI),
    str_trim(DOI) != ""
  ) %>%
  mutate(
    DOI_Normalized = str_to_lower(
      str_trim(DOI)
    )
  ) %>%
  count(
    DOI_Normalized,
    name = "Occurrences"
  ) %>%
  filter(
    Occurrences > 1
  ) %>%
  arrange(
    desc(Occurrences)
  )


# ==========================================================
# 25. ذخیره خلاصه‌های آماری اضافی
# ==========================================================

write_csv(
  year_summary,
  file.path(
    step1_dir,
    "Step1_Year_Summary.csv"
  ),
  na = ""
)


write_csv(
  document_type_summary,
  file.path(
    step1_dir,
    "Step1_Document_Type_Summary.csv"
  ),
  na = ""
)


write_csv(
  language_summary,
  file.path(
    step1_dir,
    "Step1_Language_Summary.csv"
  ),
  na = ""
)


write_csv(
  doi_diagnostics,
  file.path(
    step1_dir,
    "Step1_DOI_Duplicate_Diagnostics.csv"
  ),
  na = ""
)


# ==========================================================
# 26. تکمیل گزارش TXT
# ==========================================================

report_lines <- c(
  
  report_lines,
  
  "----------------------------------------------------------",
  "RECORD COUNTS",
  "----------------------------------------------------------",
  
  paste(
    "Scopus raw input records:",
    scopus_initial_n
  ),
  
  paste(
    "Scopus Master records:",
    scopus_master_n
  ),
  
  paste(
    "WoS raw input records:",
    wos_initial_n
  ),
  
  paste(
    "WoS Master records:",
    wos_master_n
  ),
  
  paste(
    "Merged RAW records:",
    merged_raw_n
  ),
  
  "",
  
  "----------------------------------------------------------",
  "COLUMN COUNTS",
  "----------------------------------------------------------",
  
  paste(
    "Scopus raw columns:",
    scopus_initial_cols
  ),
  
  paste(
    "WoS raw columns:",
    wos_initial_cols
  ),
  
  paste(
    "Standard Master columns:",
    ncol(scopus_master)
  ),
  
  paste(
    "Merged RAW columns:",
    ncol(merged_raw)
  ),
  
  "",
  
  "----------------------------------------------------------",
  "EXPECTED STRUCTURE",
  "----------------------------------------------------------",
  
  "Both Scopus Master and WoS Master contain the same 19 standardized columns.",
  
  "",
  
  "Columns:",
  
  paste(
    paste0(
      seq_along(expected_columns),
      ". ",
      expected_columns
    ),
    collapse = "\n"
  ),
  
  "",
  
  "----------------------------------------------------------",
  "YEAR COVERAGE",
  "----------------------------------------------------------",
  
  paste(
    "Scopus minimum year:",
    min(scopus_master$Year, na.rm = TRUE)
  ),
  
  paste(
    "Scopus maximum year:",
    max(scopus_master$Year, na.rm = TRUE)
  ),
  
  paste(
    "WoS minimum year:",
    min(wos_master$Year, na.rm = TRUE)
  ),
  
  paste(
    "WoS maximum year:",
    max(wos_master$Year, na.rm = TRUE)
  ),
  
  "",
  
  "----------------------------------------------------------",
  "MISSING METADATA",
  "----------------------------------------------------------",
  
  paste(
    "Scopus missing DOI:",
    sum(is.na(scopus_master$DOI) |
          str_trim(scopus_master$DOI) == "")
  ),
  
  paste(
    "WoS missing DOI:",
    sum(is.na(wos_master$DOI) |
          str_trim(wos_master$DOI) == "")
  ),
  
  paste(
    "Scopus missing Title:",
    sum(is.na(scopus_master$Title) |
          str_trim(scopus_master$Title) == "")
  ),
  
  paste(
    "WoS missing Title:",
    sum(is.na(wos_master$Title) |
          str_trim(wos_master$Title) == "")
  ),
  
  paste(
    "Scopus missing Authors:",
    sum(is.na(scopus_master$Authors) |
          str_trim(scopus_master$Authors) == "")
  ),
  
  paste(
    "WoS missing Authors:",
    sum(is.na(wos_master$Authors) |
          str_trim(wos_master$Authors) == "")
  ),
  
  paste(
    "Scopus missing Abstract:",
    sum(is.na(scopus_master$Abstract) |
          str_trim(scopus_master$Abstract) == "")
  ),
  
  paste(
    "WoS missing Abstract:",
    sum(is.na(wos_master$Abstract) |
          str_trim(wos_master$Abstract) == "")
  ),
  
  "",
  
  "----------------------------------------------------------",
  "DOI DUPLICATE DIAGNOSTICS",
  "----------------------------------------------------------",
  
  paste(
    "Number of normalized DOI values occurring more than once:",
    nrow(doi_diagnostics)
  ),
  
  "IMPORTANT: These duplicates were NOT removed in Step 1.",
  
  "",
  
  "----------------------------------------------------------",
  "DEDUPLICATION STATUS",
  "----------------------------------------------------------",
  
  "No cross-database deduplication was performed.",
  "No DOI-based deletion was performed.",
  "No title-based deletion was performed.",
  "No author-based deletion was performed.",
  "The purpose of this step is to preserve the complete RAW corpus.",
  
  "",
  
  "----------------------------------------------------------",
  "OUTPUT FILES",
  "----------------------------------------------------------",
  
  paste(
    "Scopus Master:",
    scopus_master_file
  ),
  
  paste(
    "WoS Master:",
    wos_master_file
  ),
  
  paste(
    "Merged RAW:",
    merged_raw_file
  ),
  
  paste(
    "Main report:",
    report_txt_file
  ),
  
  paste(
    "Record counts:",
    record_count_file
  ),
  
  paste(
    "Column structure:",
    column_structure_file
  ),
  
  paste(
    "Missingness report:",
    missingness_file
  ),
  
  "",
  
  "==========================================================",
  "END OF STEP 1 REPORT",
  "=========================================================="
)


# ==========================================================
# 27. ذخیره گزارش TXT
# ==========================================================

writeLines(
  report_lines,
  report_txt_file,
  useBytes = TRUE
)


# ==========================================================
# 28. پایان
# ==========================================================

cat("\n")
cat("==========================================================\n")
cat("STEP 1 COMPLETED SUCCESSFULLY\n")
cat("==========================================================\n")

cat(
  "Scopus records:",
  scopus_master_n,
  "\n"
)

cat(
  "WoS records:",
  wos_master_n,
  "\n"
)

cat(
  "Merged RAW records:",
  merged_raw_n,
  "\n"
)

cat(
  "Output directory:\n",
  step1_dir,
  "\n"
)

cat(
  "Report:\n",
  report_txt_file,
  "\n"
)

cat("==========================================================\n")