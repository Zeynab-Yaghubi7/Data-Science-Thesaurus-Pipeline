# ============================================================
# STEP 6 – EXPORT FINAL RELEVANT CORPUS TO RIS
# For VOSviewer
# Input: Step5C FINAL RELEVANT CORPUS
# Records expected: 15,172
# ============================================================

# -----------------------------
# 1. مسیرها
# -----------------------------

input_file <- "D:/Thesis/data/Step5_Relevance_Eligibility_Audit/Step5C_Final_Relevance_Corpus/Step5C_FINAL_RELEVANT_CORPUS.csv"

output_dir <- "D:/Thesis/data/Step6_VOSviewer_RIS"

if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

output_ris <- file.path(
  output_dir,
  "Step5C_FINAL_RELEVANT_CORPUS_15172_VOSviewer.ris"
)

report_file <- file.path(
  output_dir,
  "Step6_RIS_Export_Report.txt"
)

# -----------------------------
# 2. خواندن فایل
# -----------------------------

cat("Reading final relevant corpus...\n")

data <- read.csv(
  input_file,
  stringsAsFactors = FALSE,
  check.names = FALSE,
  na.strings = c("", "NA", "N/A")
)

cat("Records read:", nrow(data), "\n")
cat("Columns:", ncol(data), "\n")

# -----------------------------
# 3. بررسی تعداد رکورد
# -----------------------------

expected_records <- 15172

if (nrow(data) != expected_records) {
  stop(
    paste0(
      "ERROR: Expected ", expected_records,
      " records but found ", nrow(data), "."
    )
  )
}

# -----------------------------
# 4. بررسی ستون‌های ضروری
# -----------------------------

required_columns <- c(
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

missing_columns <- setdiff(required_columns, colnames(data))

if (length(missing_columns) > 0) {
  stop(
    paste0(
      "ERROR: Missing required columns: ",
      paste(missing_columns, collapse = ", ")
    )
  )
}

cat("Required columns: PASS\n")

# ============================================================
# ============================================================
# 5. توابع کمکی – نسخه اصلاح‌شده
# ============================================================

clean_text <- function(x) {
  
  x <- as.character(x)
  
  x[is.na(x)] <- ""
  
  # حذف تگ‌های HTML
  x <- gsub("<[^>]+>", " ", x)
  
  # تبدیل چند فاصله به یک فاصله
  x <- gsub("[[:space:]]+", " ", x)
  
  # حذف فاصله ابتدا و انتها
  x <- trimws(x)
  
  x
}


parse_authors <- function(x) {
  
  if (length(x) == 0 || is.na(x) || trimws(x) == "") {
    return(character(0))
  }
  
  x <- clean_text(x)
  
  parts <- unlist(
    strsplit(
      x,
      "\\s*;\\s*|\\s*\\|\\s*"
    )
  )
  
  parts <- trimws(parts)
  
  parts[parts != ""]
}


# این تابع حالا برای کل ستون نیز کار می‌کند
clean_ris_field <- function(x) {
  
  x <- as.character(x)
  
  x[is.na(x)] <- ""
  
  x <- gsub("\r", " ", x)
  x <- gsub("\n", " ", x)
  x <- gsub("\t", " ", x)
  x <- gsub("[[:space:]]+", " ", x)
  
  trimws(x)
}


# ============================================================
# 6. آماده‌سازی داده‌ها
# ============================================================

data$Final_Article_ID <- clean_ris_field(data$Final_Article_ID)
data$DOI <- clean_ris_field(data$DOI)
data$Title <- clean_ris_field(data$Title)
data$Year <- clean_ris_field(data$Year)
data$Authors <- clean_ris_field(data$Authors)
data$Abstract <- clean_ris_field(data$Abstract)
data$Author_Keywords_Combined <- clean_ris_field(
  data$Author_Keywords_Combined
)
data$Source_Title <- clean_ris_field(data$Source_Title)
data$Document_Type <- clean_ris_field(data$Document_Type)
data$Language <- clean_ris_field(data$Language)

cat("Data preparation completed successfully.\n")
# ============================================================
# 7. ساخت RIS
# ============================================================

cat("Creating RIS file...\n")

con <- file(
  output_ris,
  open = "wt",
  encoding = "UTF-8"
)

written_records <- 0
records_without_author <- 0
records_without_doi <- 0
records_without_keywords <- 0
records_without_abstract <- 0

for (i in seq_len(nrow(data))) {
  
  record <- data[i, ]
  
  # ----------------------------------------------------------
  # نوع مدرک
  # ----------------------------------------------------------
  
  doc_type <- toupper(record$Document_Type)
  
  if (grepl("REVIEW", doc_type)) {
    ris_type <- "REV"
  } else {
    ris_type <- "JOUR"
  }
  
  # ----------------------------------------------------------
  # TY
  # ----------------------------------------------------------
  
  writeLines(
    paste0("TY  - ", ris_type),
    con
  )
  
  # ----------------------------------------------------------
  # ID
  # ----------------------------------------------------------
  
  writeLines(
    paste0("ID  - ", record$Final_Article_ID),
    con
  )
  
  # ----------------------------------------------------------
  # عنوان
  # ----------------------------------------------------------
  
  if (record$Title != "") {
    
    writeLines(
      paste0("TI  - ", record$Title),
      con
    )
    
  }
  
  # ----------------------------------------------------------
  # نویسندگان
  # ----------------------------------------------------------
  
  authors <- parse_authors(record$Authors)
  
  if (length(authors) > 0) {
    
    for (author in authors) {
      
      writeLines(
        paste0("AU  - ", author),
        con
      )
      
    }
    
  } else {
    
    records_without_author <- records_without_author + 1
    
  }
  
  # ----------------------------------------------------------
  # سال
  # ----------------------------------------------------------
  
  if (record$Year != "") {
    
    writeLines(
      paste0("PY  - ", record$Year),
      con
    )
    
  }
  
  # ----------------------------------------------------------
  # مجله / منبع
  # ----------------------------------------------------------
  
  if (record$Source_Title != "") {
    
    writeLines(
      paste0("JO  - ", record$Source_Title),
      con
    )
    
  }
  
  # ----------------------------------------------------------
  # DOI
  # ----------------------------------------------------------
  
  if (record$DOI != "") {
    
    writeLines(
      paste0("DO  - ", record$DOI),
      con
    )
    
  } else {
    
    records_without_doi <- records_without_doi + 1
    
  }
  
  # ----------------------------------------------------------
  # Abstract
  # ----------------------------------------------------------
  
  if (record$Abstract != "") {
    
    writeLines(
      paste0("AB  - ", record$Abstract),
      con
      
    )
    
  } else {
    
    records_without_abstract <- records_without_abstract + 1
    
  }
  
  # ----------------------------------------------------------
  # Author Keywords
  # ----------------------------------------------------------
  
  if (record$Author_Keywords_Combined != "") {
    
    keywords <- record$Author_Keywords_Combined
    
    # در صورت وجود جداکننده‌های مختلف
    keywords <- gsub(
      "\\s*;\\s*",
      "; ",
      keywords
    )
    
    writeLines(
      paste0("KW  - ", keywords),
      con
      
    )
    
  } else {
    
    records_without_keywords <- records_without_keywords + 1
    
  }
  
  # ----------------------------------------------------------
  # پایان رکورد
  # ----------------------------------------------------------
  
  writeLines(
    "ER  - ",
    con
  )
  
  writeLines(
    "",
    con
  )
  
  written_records <- written_records + 1
}

close(con)

# ============================================================
# 8. بررسی فایل خروجی
# ============================================================

if (!file.exists(output_ris)) {
  
  stop("ERROR: RIS file was not created.")
  
}

file_size_mb <- file.info(output_ris)$size / (1024^2)

# شمارش TY برای اطمینان از تعداد رکوردهای RIS
ris_lines <- readLines(
  output_ris,
  encoding = "UTF-8",
  warn = FALSE
)

ris_record_count <- sum(
  trimws(ris_lines) == "TY  - JOUR" |
    trimws(ris_lines) == "TY  - REV"
)

# ============================================================
# 9. گزارش
# ============================================================

report <- c(
  
  "============================================================",
  "STEP 6 – RIS EXPORT FOR VOSVIEWER",
  "============================================================",
  "",
  paste0("Export date: ", Sys.time()),
  "",
  "1. INPUT",
  paste0("Input file: ", input_file),
  paste0("Input records: ", nrow(data)),
  paste0("Input columns: ", ncol(data)),
  "",
  "2. OUTPUT",
  paste0("RIS file: ", output_ris),
  paste0("RIS file size (MB): ", round(file_size_mb, 2)),
  "",
  "3. RECORD COUNTS",
  paste0("Expected records: ", expected_records),
  paste0("Input records: ", nrow(data)),
  paste0("Records written: ", written_records),
  paste0("RIS records detected: ", ris_record_count),
  "",
  "4. METADATA",
  paste0("Records without DOI: ", records_without_doi),
  paste0("Records without Authors: ", records_without_author),
  paste0("Records without Abstract: ", records_without_abstract),
  paste0("Records without Author Keywords: ", records_without_keywords),
  "",
  "5. VALIDATION",
  paste0(
    "Input record count PASS: ",
    nrow(data) == expected_records
  ),
  paste0(
    "RIS record count PASS: ",
    ris_record_count == expected_records
  ),
  paste0(
    "Written record count PASS: ",
    written_records == expected_records
  ),
  "",
  "6. RIS FIELDS",
  "TY  - Reference type",
  "ID  - Final Article ID",
  "TI  - Title",
  "AU  - Author",
  "PY  - Publication Year",
  "JO  - Journal/Source Title",
  "DO  - DOI",
  "AB  - Abstract",
  "KW  - Combined Author Keywords",
  "ER  - End of Record",
  "",
  "7. IMPORTANT NOTE",
  "The original Step5C final relevant corpus was not modified.",
  "This RIS file is a separate export created for VOSviewer.",
  "Author Keywords are exported from Author_Keywords_Combined.",
  "Keywords Plus and Scopus Index Keywords are intentionally not",
  "used as the main KW field because the planned co-word analysis",
  "is based on Author Keywords.",
  "",
  "============================================================",
  "END OF REPORT",
  "============================================================"
)

writeLines(
  report,
  report_file,
  useBytes = TRUE
)

# ============================================================
# 10. نتیجه نهایی
# ============================================================

cat("\n")
cat("============================================================\n")
cat("STEP 6 – RIS EXPORT COMPLETED\n")
cat("============================================================\n")
cat("Input records:", nrow(data), "\n")
cat("Records written:", written_records, "\n")
cat("RIS records detected:", ris_record_count, "\n")
cat("RIS file size:", round(file_size_mb, 2), "MB\n")
cat("\n")

if (
  nrow(data) == expected_records &&
  written_records == expected_records &&
  ris_record_count == expected_records
) {
  
  cat("STATUS: PASS\n")
  cat("RIS file is ready for VOSviewer.\n")
  
} else {
  
  cat("STATUS: CHECK REQUIRED\n")
  
}

cat("\n")
cat("RIS file:\n")
cat(output_ris, "\n")
cat("\n")
cat("Report:\n")
cat(report_file, "\n")
cat("============================================================\n")