# ============================================================
# STEP 4B
# FINAL DEDUPLICATION + METADATA MERGING
# FINAL VERSION BASED ON VERIFIED STEP 4 LOGIC
#
# IMPORTANT:
# This version uses the matching fields already created
# and verified in Step 4.
#
# Priority:
# 1. DOI
# 2. WoS UT
# 3. Title + Year + First Author
#
# No new matching logic is invented here.
# ============================================================

library(readr)
library(dplyr)
library(stringr)

# ============================================================
# 1. PATHS
# ============================================================

input_file <- paste0(
  "D:/Thesis/data/Step4_Deduplication_Metadata_Merging/",
  "Step4_Deduplication_Audit_Data.csv"
)

output_dir <- paste0(
  "D:/Thesis/data/Step4_Deduplication_Metadata_Merging/",
  "Step4B_FINAL"
)

if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

# ============================================================
# 2. READ STEP 4 AUDIT DATA
# ============================================================

audit <- read_csv(
  input_file,
  show_col_types = FALSE
)

cat("============================================================\n")
cat("STEP 4B - FINAL VERSION\n")
cat("============================================================\n\n")

cat("Input records :", nrow(audit), "\n")
cat("Input columns :", ncol(audit), "\n\n")


# ============================================================
# 3. HELPER FUNCTIONS
# ============================================================

first_nonempty <- function(x) {
  
  x <- as.character(x)
  x <- x[!is.na(x)]
  x <- str_trim(x)
  x <- x[x != ""]
  
  if (length(x) == 0) {
    return(NA_character_)
  }
  
  x[1]
}


combine_unique <- function(x) {
  
  x <- as.character(x)
  x <- x[!is.na(x)]
  x <- str_trim(x)
  x <- x[x != ""]
  
  if (length(x) == 0) {
    return(NA_character_)
  }
  
  x <- unique(x)
  
  paste(x, collapse = "; ")
}


# ============================================================
# 4. CONTROLLED KEYWORD CLEANING
# ============================================================

clean_keyword_text <- function(x) {
  
  x <- as.character(x)
  x[is.na(x)] <- ""
  
  # HTML entities
  x <- str_replace_all(x, "&nbsp;", " ")
  
  x <- str_replace_all(x, "&#8208;", "-")
  x <- str_replace_all(x, "&#8209;", "-")
  x <- str_replace_all(x, "&#8210;", "-")
  x <- str_replace_all(x, "&#8211;", "-")
  x <- str_replace_all(x, "&#8212;", "-")
  
  # HTML tags
  x <- str_replace_all(x, "<sub>", "")
  x <- str_replace_all(x, "</sub>", "")
  
  x <- str_replace_all(x, "<sup>", "")
  x <- str_replace_all(x, "</sup>", "")
  
  x <- str_replace_all(x, "<ITALIC>", "")
  x <- str_replace_all(x, "</ITALIC>", "")
  
  # Remaining HTML tags
  x <- str_replace_all(x, "<[^>]+>", "")
  
  # Whitespace
  x <- str_replace_all(x, "\\s+", " ")
  x <- str_trim(x)
  
  x[x == ""] <- NA_character_
  
  x
}


# ============================================================
# 5. COMBINE AUTHOR KEYWORDS
# ============================================================

combine_keywords <- function(...) {
  
  x <- c(...)
  
  x <- as.character(x)
  
  x <- x[!is.na(x)]
  x <- str_trim(x)
  x <- x[x != ""]
  
  if (length(x) == 0) {
    return(NA_character_)
  }
  
  # Split keywords by ; or |
  x <- unlist(
    str_split(
      x,
      "\\s*;\\s*|\\s*\\|\\s*"
    )
  )
  
  x <- str_trim(x)
  x <- x[x != ""]
  
  # Case-insensitive duplicate removal
  x_normalized <- str_to_lower(x)
  
  keep <- !duplicated(x_normalized)
  
  x <- x[keep]
  
  paste(x, collapse = "; ")
}


# ============================================================
# 6. CLEAN KEYWORD FIELDS
# ============================================================

audit <- audit %>%
  mutate(
    
    Author_Keywords_Scopus =
      clean_keyword_text(
        Author_Keywords_Scopus
      ),
    
    Author_Keywords_WoS =
      clean_keyword_text(
        Author_Keywords_WoS
      )
    
  )


# ============================================================
# 7. CREATE VERIFIED FINAL GROUP ID
#
# IMPORTANT:
# We use the fields already generated in Step 4.
#
# DOI has highest priority.
# Then UT.
# Then Title-Year-FirstAuthor.
# ============================================================

audit <- audit %>%
  mutate(
    
    Verified_Final_Group_ID =
      case_when(
        
        !is.na(DOI_Normalized) &
          str_trim(DOI_Normalized) != "" ~
          paste0(
            "DOI:",
            str_to_lower(
              str_trim(DOI_Normalized)
            )
          ),
        
        !is.na(UT_Normalized) &
          str_trim(UT_Normalized) != "" ~
          paste0(
            "UT:",
            str_trim(UT_Normalized)
          ),
        
        !is.na(TitleYearAuthor_Key) &
          str_trim(TitleYearAuthor_Key) != "" ~
          paste0(
            "TYA:",
            str_to_lower(
              str_trim(TitleYearAuthor_Key)
            )
          ),
        
        TRUE ~
          paste0(
            "UNMATCHED:",
            row_number()
          )
      )
  )


# ============================================================
# 8. VERIFY GROUPING BEFORE COLLAPSING
# ============================================================

cat("\n============================================================\n")
cat("GROUPING VERIFICATION\n")
cat("============================================================\n\n")

group_check <- audit %>%
  count(
    Verified_Final_Group_ID,
    name = "Input_Records"
  )

cat(
  "Unique final groups:",
  nrow(group_check),
  "\n"
)

cat(
  "Input records represented:",
  sum(group_check$Input_Records),
  "\n\n"
)


# ============================================================
# 9. CREATE FINAL DATASET
# ============================================================

final_data <- audit %>%
  group_by(Verified_Final_Group_ID) %>%
  summarise(
    
    # --------------------------------------------------------
    # Identification
    # --------------------------------------------------------
    
    Final_Group_ID =
      first_nonempty(
        Verified_Final_Group_ID
      ),
    
    # --------------------------------------------------------
    # DATABASE COUNTS
    # Calculate BEFORE collapsing Source_Database
    # --------------------------------------------------------
    
    Scopus_Records =
      sum(
        Source_Database == "Scopus",
        na.rm = TRUE
      ),
    
    WoS_Records =
      sum(
        Source_Database == "WoS",
        na.rm = TRUE
      ),
    
    Source_Database =
      paste(
        sort(
          unique(
            na.omit(Source_Database)
          )
        ),
        collapse = " | "
      ),
    
    # --------------------------------------------------------
    # ORIGINAL IDS
    # --------------------------------------------------------
    
    Original_IDs =
      combine_unique(
        Original_ID
      ),
    
    # --------------------------------------------------------
    # BIBLIOGRAPHIC METADATA
    # --------------------------------------------------------
    
    DOI =
      first_nonempty(
        DOI
      ),
    
    UT_WoS =
      first_nonempty(
        UT_WoS
      ),
    
    Title =
      first_nonempty(
        Title
      ),
    
    Year =
      suppressWarnings(
        as.integer(
          first_nonempty(
            Year
          )
        )
      ),
    
    Authors =
      first_nonempty(
        Authors
      ),
    
    Abstract =
      first_nonempty(
        Abstract
      ),
    
    # --------------------------------------------------------
    # AUTHOR KEYWORDS
    # --------------------------------------------------------
    
    Author_Keywords_Scopus =
      combine_unique(
        Author_Keywords_Scopus
      ),
    
    Author_Keywords_WoS =
      combine_unique(
        Author_Keywords_WoS
      ),
    
    Author_Keywords_Combined =
      combine_keywords(
        combine_unique(
          Author_Keywords_Scopus
        ),
        combine_unique(
          Author_Keywords_WoS
        )
      ),
    
    # --------------------------------------------------------
    # OTHER KEYWORD FIELDS
    # --------------------------------------------------------
    
    Index_Keywords_Scopus =
      combine_unique(
        Index_Keywords_Scopus
      ),
    
    Keywords_Plus_WoS =
      combine_unique(
        Keywords_Plus_WoS
      ),
    
    # --------------------------------------------------------
    # CITATION / REFERENCE FIELDS
    # --------------------------------------------------------
    
    Cited_By_Scopus =
      first_nonempty(
        Cited_By_Scopus
      ),
    
    Cited_By_WoS =
      first_nonempty(
        Cited_By_WoS
      ),
    
    References_Scopus =
      first_nonempty(
        References_Scopus
      ),
    
    References_WoS =
      first_nonempty(
        References_WoS
      ),
    
    # --------------------------------------------------------
    # SOURCE INFORMATION
    # --------------------------------------------------------
    
    Source_Title =
      first_nonempty(
        Source_Title
      ),
    
    Document_Type =
      combine_unique(
        Document_Type
      ),
    
    Language =
      first_nonempty(
        Language
      ),
    
    # --------------------------------------------------------
    # RETRACTION
    # --------------------------------------------------------
    
    Retraction_Flag =
      any(
        Retraction_Flag == TRUE,
        na.rm = TRUE
      ),
    
    # --------------------------------------------------------
    # GROUP INFORMATION
    # --------------------------------------------------------
    
    Input_Records_Merged =
      n(),
    
    Final_Match_Method =
      combine_unique(
        Final_Match_Method
      ),
    
    .groups = "drop"
  )


# ============================================================
# 10. CREATE FINAL ARTICLE ID
# ============================================================

final_data <- final_data %>%
  arrange(
    Final_Group_ID
  ) %>%
  mutate(
    Final_Article_ID =
      sprintf(
        "ARTICLE_%05d",
        row_number()
      )
  ) %>%
  select(
    Final_Article_ID,
    everything()
  )


# ============================================================
# 11. BASIC VALIDATION
# ============================================================

input_n <-
  nrow(audit)

final_n <-
  nrow(final_data)

records_removed <-
  input_n - final_n

reduction_percent <-
  round(
    records_removed /
      input_n *
      100,
    2
  )

cat("\n============================================================\n")
cat("FINAL VALIDATION\n")
cat("============================================================\n\n")

cat(
  "Input records        :",
  input_n,
  "\n"
)

cat(
  "Final unique articles:",
  final_n,
  "\n"
)

cat(
  "Records removed      :",
  records_removed,
  "\n"
)

cat(
  "Reduction (%)        :",
  reduction_percent,
  "\n\n"
)


# ============================================================
# 12. GROUP SIZE SUMMARY
# ============================================================

group_size_summary <- final_data %>%
  count(
    Input_Records_Merged,
    name = "Number_of_Articles"
  ) %>%
  arrange(
    Input_Records_Merged
  )

cat("GROUP SIZE SUMMARY\n")
print(group_size_summary)

write_csv(
  group_size_summary,
  file.path(
    output_dir,
    "Step4B_FINAL_Group_Size_Summary.csv"
  )
)


# ============================================================
# 13. DATABASE SUMMARY
# ============================================================

database_summary <- final_data %>%
  count(
    Source_Database,
    name = "Number_of_Articles"
  ) %>%
  arrange(
    desc(Number_of_Articles)
  )

cat("\nDATABASE ORIGIN\n")
print(database_summary)

write_csv(
  database_summary,
  file.path(
    output_dir,
    "Step4B_FINAL_Database_Summary.csv"
  )
)


# ============================================================
# 14. RETRACTION SUMMARY
# ============================================================

retraction_summary <- final_data %>%
  count(
    Retraction_Flag,
    name = "Number_of_Articles"
  )

cat("\nRETRACTION SUMMARY\n")
print(retraction_summary)

write_csv(
  retraction_summary,
  file.path(
    output_dir,
    "Step4B_FINAL_Retraction_Summary.csv"
  )
)


# ============================================================
# 15. MATCH METHOD SUMMARY
# ============================================================

match_method_summary <- final_data %>%
  count(
    Final_Match_Method,
    name = "Number_of_Articles"
  ) %>%
  arrange(
    desc(Number_of_Articles)
  )

cat("\nFINAL MATCH METHOD SUMMARY\n")
print(match_method_summary)

write_csv(
  match_method_summary,
  file.path(
    output_dir,
    "Step4B_FINAL_Match_Method_Summary.csv"
  )
)


# ============================================================
# 16. DUPLICATE DOI CHECK
# ============================================================

doi_check <- final_data %>%
  filter(
    !is.na(DOI),
    str_trim(DOI) != ""
  ) %>%
  mutate(
    DOI_Clean =
      str_to_lower(
        str_trim(DOI)
      )
  ) %>%
  count(
    DOI_Clean,
    name = "Frequency"
  ) %>%
  filter(
    Frequency > 1
  )

cat(
  "\nDuplicate DOI values:",
  nrow(doi_check),
  "\n"
)

write_csv(
  doi_check,
  file.path(
    output_dir,
    "Step4B_FINAL_Duplicate_DOI_Check.csv"
  )
)


# ============================================================
# 17. KEYWORD HTML / ENTITY CHECK
# ============================================================

keyword_html_check <- tibble(
  
  Field = c(
    "Author_Keywords_Scopus",
    "Author_Keywords_WoS",
    "Author_Keywords_Combined"
  ),
  
  Records_with_HTML_or_Entity =
    c(
      
      sum(
        str_detect(
          coalesce(
            final_data$Author_Keywords_Scopus,
            ""
          ),
          "<[^>]+>|&[A-Za-z0-9#]+;"
        )
      ),
      
      sum(
        str_detect(
          coalesce(
            final_data$Author_Keywords_WoS,
            ""
          ),
          "<[^>]+>|&[A-Za-z0-9#]+;"
        )
      ),
      
      sum(
        str_detect(
          coalesce(
            final_data$Author_Keywords_Combined,
            ""
          ),
          "<[^>]+>|&[A-Za-z0-9#]+;"
        )
      )
    )
)

cat("\nKEYWORD HTML / ENTITY CHECK\n")
print(keyword_html_check)

write_csv(
  keyword_html_check,
  file.path(
    output_dir,
    "Step4B_FINAL_Keyword_HTML_Check.csv"
  )
)


# ============================================================
# 18. FINAL DIMENSIONS
# ============================================================

final_dimensions <- tibble(
  
  Metric = c(
    "Input_Records",
    "Final_Unique_Articles",
    "Records_Removed",
    "Reduction_Percent",
    "Final_Columns"
  ),
  
  Value = c(
    input_n,
    final_n,
    records_removed,
    reduction_percent,
    ncol(final_data)
  )
)

write_csv(
  final_dimensions,
  file.path(
    output_dir,
    "Step4B_FINAL_Dimensions.csv"
  )
)


# ============================================================
# 19. SAVE FINAL DATASET
# ============================================================

final_file <- file.path(
  output_dir,
  "Scopus_WoS_2000_2025_FINAL_DEDUP.csv"
)

write_csv(
  final_data,
  final_file
)


# ============================================================
# 20. FINAL REPORT
# ============================================================

report_file <- file.path(
  output_dir,
  "Step4B_FINAL_Report.txt"
)

sink(report_file)

cat("============================================================\n")
cat("STEP 4B - FINAL DEDUPLICATION + METADATA MERGING\n")
cat("============================================================\n\n")

cat("Input records:", input_n, "\n")
cat("Final unique articles:", final_n, "\n")
cat("Records removed:", records_removed, "\n")
cat("Reduction:", reduction_percent, "%\n\n")

cat("Step 4 group fields used:\n")
cat("DOI_Normalized\n")
cat("UT_Normalized\n")
cat("TitleYearAuthor_Key\n\n")

cat("GROUP SIZE SUMMARY\n")
print(group_size_summary)

cat("\nDATABASE ORIGIN\n")
print(database_summary)

cat("\nRETRACTION SUMMARY\n")
print(retraction_summary)

cat("\nFINAL MATCH METHOD\n")
print(match_method_summary)

cat("\nDUPLICATE DOI VALUES\n")
cat(nrow(doi_check), "\n")

cat("\nKEYWORD HTML / ENTITY CHECK\n")
print(keyword_html_check)

cat("\nFINAL DIMENSIONS\n")
cat(
  "Rows:",
  nrow(final_data),
  "\n"
)

cat(
  "Columns:",
  ncol(final_data),
  "\n"
)

cat("\nFINAL COLUMN NAMES\n")
print(names(final_data))

cat("\n============================================================\n")
cat("END OF STEP 4B\n")
cat("============================================================\n")

sink()


# ============================================================
# 21. FINAL CONSOLE SUMMARY
# ============================================================

cat("\n============================================================\n")
cat("STEP 4B COMPLETED\n")
cat("============================================================\n\n")

cat(
  "Input records        :",
  input_n,
  "\n"
)

cat(
  "Final unique articles:",
  final_n,
  "\n"
)

cat(
  "Records removed      :",
  records_removed,
  "\n"
)

cat(
  "Reduction (%)        :",
  reduction_percent,
  "\n\n"
)

cat("Database origin:\n")
print(database_summary)

cat("\nGroup sizes:\n")
print(group_size_summary)

cat("\nRetraction:\n")
print(retraction_summary)

cat("\nMatch methods:\n")
print(match_method_summary)

cat(
  "\nDuplicate DOI values:",
  nrow(doi_check),
  "\n"
)

cat(
  "\nFinal dimensions:",
  nrow(final_data),
  "x",
  ncol(final_data),
  "\n"
)

cat(
  "\nFinal file:\n",
  final_file,
  "\n"
)

cat("\n============================================================\n")