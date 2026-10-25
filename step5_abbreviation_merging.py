# ============================================================
# Step 5: Abbreviation and Parenthetical Merging (Final Correct)
# Version: Conservative & Accurate
# ============================================================
import pandas as pd
import json
import os
import re
from datetime import datetime

# ================= 1. Path Settings =================
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DICT_DIR = os.path.join(SCRIPT_DIR, "dictionaries")

base_dir = r"D:\Thesis\thesaurus"
input_file = os.path.join(base_dir, "step4", "step4_cleaned_keywords.csv")
output_dir = os.path.join(base_dir, "step5")
os.makedirs(output_dir, exist_ok=True)

output_cleaned = os.path.join(output_dir, "step5_cleaned_keywords.csv")
output_thesaurus_txt = os.path.join(output_dir, "step5_thesaurus_vosviewer.txt")
output_thesaurus_csv = os.path.join(output_dir, "step5_thesaurus_vosviewer.csv")
output_report = os.path.join(output_dir, "step5_report.txt")

print("=" * 70)
print("STEP 5: Abbreviation and Parenthetical Merging (Final)")
print("=" * 70)
print(f"Start time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

if not os.path.exists(input_file):
    raise FileNotFoundError(f"Input file not found:\n{input_file}")

# ================= 2. Load Abbreviation Dictionary =================
print("\nLoading abbreviation dictionary...")
abbr_file = os.path.join(DICT_DIR, "abbreviations.json")

if os.path.exists(abbr_file):
    with open(abbr_file, encoding="utf-8") as f:
        KNOWN_ABBREVIATIONS = json.load(f)
    print(f"   ✅ Loaded {len(KNOWN_ABBREVIATIONS)} abbreviations")
else:
    print(f"   ⚠️ Abbreviation file not found: {abbr_file}")
    KNOWN_ABBREVIATIONS = {}

# ================= 3. Special Cases for Parenthetical Expressions =================
# موارد خاص که نیاز به نگاشت دستی دارند
PARENTHETICAL_EXCEPTIONS = {
    # وقتی بیرون پرانتز مخفف است و داخل پرانتز شکل کامل
    "qos(quality of service)": "quality of service",
    "qos (quality of service)": "quality of service",
    "quality of services (qos)": "quality of service",
    
    # مخفف‌های واقعی که به شکل کامل تبدیل می‌شوند
    "error (rmse)": "root mean squared error",
    "informatics (ohdsi)": "observational health data sciences and informatics",
    "partnership (omop)": "observational medical outcomes partnership",
    "mcdm (multi-criteria decision making)": "multi-criteria decision making",
    
    # اصلاح اشتباهات تایپی واضح
    "nlp (natural language programming)": "natural language processing",
    "learning (artificial intelligence)": "artificial intelligence",
    
    # پرانتزهای خالی (بی‌خطر)
    "data analysis ()": "data analysis",
    "data collection ()": "data collection",
    "expert systems ()": "expert systems",
    
    # موارد دیگر از گزارش که نیاز به اصلاح دارند
    "neural networks (rnn)": "recurrent neural networks",
}

# ================= 4. Load Data =================
print("\nReading data...")
df = pd.read_csv(input_file, encoding="utf-8-sig")
print(f"   Input keywords: {len(df):,}")

# Standardize column names
if "keyword" not in df.columns:
    df.rename(columns={df.columns[0]: "keyword"}, inplace=True)
if "co_occurrences" not in df.columns:
    df.rename(columns={df.columns[1]: "co_occurrences"}, inplace=True)
if "total_link_strength" not in df.columns:
    df.rename(columns={df.columns[2]: "total_link_strength"}, inplace=True)

df["co_occurrences"] = pd.to_numeric(df["co_occurrences"], errors="coerce").fillna(0).astype(int)
df["total_link_strength"] = pd.to_numeric(df["total_link_strength"], errors="coerce").fillna(0).astype(int)
df["keyword"] = df["keyword"].astype(str).str.strip()

# Preserve original_keywords column if it exists
if "original_keywords" not in df.columns:
    df["original_keywords"] = df["keyword"].copy()

# ================= 5. Build Frequency Dictionary =================
print("\nBuilding frequency dictionary...")
frequency_dict = {}
for _, row in df.iterrows():
    keyword = str(row["keyword"]).strip()
    freq = int(row.get("co_occurrences", 1))
    tls = int(row.get("total_link_strength", 0))
    frequency_dict[keyword.lower()] = (keyword, freq, tls)

print(f"   Loaded {len(frequency_dict)} keywords")

# ================= 6. Apply Mappings =================
print("\nApplying abbreviation and parenthetical mappings...")

merge_map = {}
merge_details = []

# --- PART A: Process Abbreviations (ALWAYS to Full Form) ---
for abbr, full_form in KNOWN_ABBREVIATIONS.items():
    abbr_lower = abbr.lower()
    full_lower = full_form.lower()
    
    abbr_info = frequency_dict.get(abbr_lower)
    
    if abbr_info:
        abbr_keyword, abbr_freq, abbr_tls = abbr_info
        target = full_form
            
        if abbr_keyword.lower() != target.lower():
            merge_map[abbr_keyword] = target
            merge_details.append({
                "Label": abbr_keyword,
                "Replace by": target,
                "Original Co-occurrences": abbr_freq,
                "Type": "abbreviation",
            })

# --- PART B: Process Parenthetical Exceptions (Special Cases) ---
for keyword_lower, (keyword_orig, freq, tls) in frequency_dict.items():
    if keyword_lower in PARENTHETICAL_EXCEPTIONS:
        target = PARENTHETICAL_EXCEPTIONS[keyword_lower]
        if keyword_orig.lower() != target.lower():
            merge_map[keyword_orig] = target
            merge_details.append({
                "Label": keyword_orig,
                "Replace by": target,
                "Original Co-occurrences": freq,
                "Type": "parenthetical_exception",
            })

# --- PART C: Process Regular Parenthetical Expressions (CONSERVATIVE) ---
# ONLY remove parentheses if they contain a known abbreviation
for keyword_lower, (keyword_orig, freq, tls) in frequency_dict.items():
    # اگر قبلاً پردازش شده، رد شو
    if keyword_orig in merge_map:
        continue
    
    # بررسی آیا پرانتز دارد
    if '(' in keyword_orig and ')' in keyword_orig:
        # استخراج متن بیرون و داخل پرانتز
        match = re.match(r'^(.*?)\s*\(([^)]*)\)\s*$', keyword_orig)
        if match:
            outside = match.group(1).strip()
            inside = match.group(2).strip()
            
            # منطق محافظه‌کارانه:
            # فقط اگر داخل پرانتز یک مخفف شناخته‌شده باشد، آن را حذف کن
            if inside.lower() in KNOWN_ABBREVIATIONS:
                # داخل پرانتز مخفف است، پس بیرون پرانتز شکل کامل است
                cleaned = outside
                
                # حذف فاصله‌های اضافی
                cleaned = re.sub(r'\s+', ' ', cleaned).strip()
                
                if cleaned and cleaned.lower() != keyword_lower:
                    # بررسی آیا شکل تمیز شده در داده‌ها وجود دارد
                    if cleaned.lower() in frequency_dict:
                        merge_map[keyword_orig] = cleaned
                        merge_details.append({
                            "Label": keyword_orig,
                            "Replace by": cleaned,
                            "Original Co-occurrences": freq,
                            "Type": "parenthetical",
                        })

print(f"   Total abbreviation merges: {sum(1 for d in merge_details if d['Type'] == 'abbreviation')}")
print(f"   Total parenthetical exception merges: {sum(1 for d in merge_details if d['Type'] == 'parenthetical_exception')}")
print(f"   Total regular parenthetical merges: {sum(1 for d in merge_details if d['Type'] == 'parenthetical')}")
print(f"   Total mappings: {len(merge_map)}")

# ================= 7. Apply Merges to DataFrame =================
print("\nApplying merges to dataframe...")
df["keyword"] = df["keyword"].apply(lambda x: merge_map.get(x, x))

# ================= 8. Remove Duplicates =================
print("\nRemoving duplicates...")
df_before_dedup = len(df)

agg_dict = {
    "co_occurrences": "sum",
    "total_link_strength": "sum",
}

# Preserve original_keywords by joining unique values
if "original_keywords" in df.columns:
    agg_dict["original_keywords"] = lambda x: " | ".join(sorted(set(str(v) for v in x if pd.notna(v))))

df = df.groupby("keyword", as_index=False).agg(agg_dict)
df_after_dedup = len(df)
removed_count = df_before_dedup - df_after_dedup
print(f"   Before dedup: {df_before_dedup}")
print(f"   After dedup: {df_after_dedup}")
print(f"   Removed: {removed_count}")

df = df.sort_values("co_occurrences", ascending=False).reset_index(drop=True)

# ================= 9. Save Output Files =================
print("\nSaving output files...")

# 1. Cleaned Keywords
df.to_csv(output_cleaned, index=False, encoding="utf-8-sig")
print(f"[1/4] Saved cleaned keywords: {len(df)}")

# 2. VOSviewer Thesaurus (TXT)
df_thesaurus = pd.DataFrame(
    [{"Label": orig, "Replace by": target} for orig, target in merge_map.items()]
)
if not df_thesaurus.empty:
    df_thesaurus = df_thesaurus.drop_duplicates(subset=["Label"], keep="first")
else:
    df_thesaurus = pd.DataFrame(columns=["Label", "Replace by"])

df_thesaurus.to_csv(output_thesaurus_txt, sep="\t", index=False, encoding="utf-8-sig")
print(f"[2/4] Saved VOSviewer Thesaurus (TXT): {len(df_thesaurus)} entries")

# 3. VOSviewer Thesaurus (CSV)
df_thesaurus.to_csv(output_thesaurus_csv, index=False, encoding="utf-8-sig")
print(f"[3/4] Saved VOSviewer Thesaurus (CSV): {len(df_thesaurus)} entries")

# 4. Report
with open(output_report, "w", encoding="utf-8") as f:
    f.write("=" * 70 + "\n")
    f.write("STEP 5 REPORT — Abbreviation and Parenthetical Merging (Final)\n")
    f.write("=" * 70 + "\n\n")
    f.write(f"Execution Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
    f.write(f"Input File: {input_file}\n\n")
    
    f.write("PROCESSING STATISTICS\n")
    f.write("-" * 70 + "\n")
    f.write(f"Total Input Keywords: {df_before_dedup:,}\n")
    f.write(f"Total Abbreviation Merges: {sum(1 for d in merge_details if d['Type'] == 'abbreviation'):,}\n")
    f.write(f"Total Parenthetical Exception Merges: {sum(1 for d in merge_details if d['Type'] == 'parenthetical_exception'):,}\n")
    f.write(f"Total Regular Parenthetical Merges: {sum(1 for d in merge_details if d['Type'] == 'parenthetical'):,}\n")
    f.write(f"Total Mappings Applied: {len(merge_map):,}\n")
    f.write(f"Duplicate Rows Removed: {removed_count:,}\n")
    f.write(f"Final Cleaned Keywords: {len(df):,}\n\n")
    
    f.write("SAMPLE MERGES (First 50)\n")
    f.write("-" * 70 + "\n")
    count = 0
    for item in sorted(merge_details, key=lambda x: x["Original Co-occurrences"], reverse=True):
        if count >= 50:
            f.write(f"   ... and {len(merge_details) - 50} more.\n")
            break
        f.write(f"   '{item['Label']}' -> '{item['Replace by']}' (Type: {item['Type']})\n")
        count += 1
    f.write("\n")
    
    f.write("OUTPUT FILES DESCRIPTION\n")
    f.write("-" * 70 + "\n")
    f.write("1. step5_cleaned_keywords.csv: Final keywords ready for VOSviewer.\n")
    f.write("2. step5_thesaurus_vosviewer.txt: Thesaurus for VOSviewer (TXT).\n")
    f.write("3. step5_thesaurus_vosviewer.csv: Thesaurus for Excel review (CSV).\n")
    f.write("4. step5_report.txt: This audit trail.\n\n")
    
    f.write("NEXT STEPS\n")
    f.write("-" * 70 + "\n")
    f.write("1. Review step5_thesaurus_vosviewer.csv to verify merges.\n")
    f.write("2. Load step5_thesaurus_vosviewer.txt into VOSviewer.\n")
    f.write("3. Proceed to Step 7 (Synonym merging).\n")
    f.write("=" * 70 + "\n")

print(f"[4/4] Saved Report")
print(f"\n✨ Step 5 Completed Successfully!")
print(f" End time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")