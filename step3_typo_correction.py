# ============================================================
# STEP 3: Typo Correction and Basic Normalization (Final)
# ============================================================

import pandas as pd
import os
import re
from datetime import datetime
from pathlib import Path

# ============================================================
# 1. Path Settings
# ============================================================

INPUT_FILE = r'D:\Thesis\thesaurus\step2\step2_cleaned_keywords.csv'
OUTPUT_DIR = r'D:\Thesis\thesaurus\step3'

Path(OUTPUT_DIR).mkdir(parents=True, exist_ok=True)

# ============================================================
# 2. Helper Functions
# ============================================================

def normalize_text(text):
    """
    Normalize keyword text:
    - Remove zero-width characters
    - Standardize en/em dashes to hyphen
    - Replace underscores with spaces
    - Remove leading/trailing punctuation
    - Standardize spaces around hyphens
    - Remove extra spaces
    """
    
    text = str(text).strip()

    # Remove zero-width characters
    text = re.sub(
        r'[\u200b\u200c\u200d\ufeff\u2060]',
        '',
        text
    )

    # Standardize hyphens
    text = text.replace('–', '-')
    text = text.replace('—', '-')
    text = text.replace('_', ' ')

    # Remove leading punctuation
    text = re.sub(
        r'^[\s\.,;:\'\"\-]+',
        '',
        text
    )

    # Remove trailing punctuation
    text = re.sub(
        r'[\s\.,;:\'\"\-]+$',
        '',
        text
    )

    # Standardize spacing around hyphens
    text = re.sub(
        r'\s*-\s*',
        '-',
        text
    )

    # Remove extra spaces
    text = re.sub(
        r'\s+',
        ' ',
        text
    ).strip()

    return text


# ============================================================
# 3. Main Execution
# ============================================================

print("=" * 70)
print("STEP 3: Typo Correction and Basic Normalization")
print("=" * 70)

print(
    f"Start time: "
    f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
)

# ------------------------------------------------------------
# Check input
# ------------------------------------------------------------

if not os.path.exists(INPUT_FILE):
    raise FileNotFoundError(
        f"Input file not found:\n{INPUT_FILE}"
    )

print("\nReading data...")

df = pd.read_csv(
    INPUT_FILE,
    encoding='utf-8-sig'
)

print(f"Input rows: {len(df):,}")

# ============================================================
# 4. Validate Required Columns
# ============================================================

required_columns = [
    'keyword',
    'co_occurrences',
    'total_link_strength'
]

missing_columns = [
    col for col in required_columns
    if col not in df.columns
]

if missing_columns:
    raise ValueError(
        "\nRequired columns are missing:\n"
        + "\n".join(
            f" - {col}" for col in missing_columns
        )
        + f"\n\nAvailable columns:\n{list(df.columns)}"
    )

print("\nRequired columns verified:")
print(" - keyword")
print(" - co_occurrences")
print(" - total_link_strength")

# ============================================================
# 5. Basic Data Cleaning
# ============================================================

# Make sure keyword is string
df['keyword'] = df['keyword'].astype(str)

# Convert numeric columns safely
df['co_occurrences'] = pd.to_numeric(
    df['co_occurrences'],
    errors='coerce'
).fillna(0)

df['total_link_strength'] = pd.to_numeric(
    df['total_link_strength'],
    errors='coerce'
).fillna(0)

# ============================================================
# 6. Normalization
# ============================================================

print("\nNormalizing keywords...")

# IMPORTANT:
# Normalize the current keyword column
# NOT original_keyword

df['keyword_normalized'] = (
    df['keyword'].apply(normalize_text)
)

# Remove empty keywords
df = df[
    df['keyword_normalized'].ne('')
].copy()

# ------------------------------------------------------------
# Track actual normalization changes
# ------------------------------------------------------------

typo_map = {}

for _, row in df.iterrows():

    original = row['keyword']
    normalized = row['keyword_normalized']

    if original != normalized:
        typo_map[original] = normalized

print(
    f"Normalized keyword forms: "
    f"{len(typo_map):,}"
)

# Replace keyword with normalized version
df['keyword'] = df['keyword_normalized']

df.drop(
    columns=['keyword_normalized'],
    inplace=True
)

# ============================================================
# 7. Deduplication
# ============================================================

print("\nDeduplicating normalized keywords...")

df_before_dedup = len(df)

# ------------------------------------------------------------
# Preserve original keyword information if available
# ------------------------------------------------------------

if 'original_keyword' in df.columns:

    orig_merged = (
        df.groupby('keyword')['original_keyword']
        .apply(
            lambda values:
            ' | '.join(
                sorted(
                    set(
                        str(v)
                        for v in values
                        if pd.notna(v)
                        and str(v).strip()
                    )
                )
            )
        )
        .reset_index()
    )

    orig_merged.rename(
        columns={
            'original_keyword':
            'original_keywords'
        },
        inplace=True
    )

else:

    orig_merged = pd.DataFrame(
        columns=[
            'keyword',
            'original_keywords'
        ]
    )

# ------------------------------------------------------------
# Aggregate duplicate keywords
# ------------------------------------------------------------

df_agg = (
    df.groupby(
        'keyword',
        as_index=False
    )
    .agg({
        'co_occurrences': 'sum',
        'total_link_strength': 'sum'
    })
)

# ------------------------------------------------------------
# Merge original keyword information
# ------------------------------------------------------------

df = df_agg.merge(
    orig_merged,
    on='keyword',
    how='left'
)

df_after_dedup = len(df)

merged_count = (
    df_before_dedup -
    df_after_dedup
)

print(
    f"Before deduplication: "
    f"{df_before_dedup:,}"
)

print(
    f"After deduplication: "
    f"{df_after_dedup:,}"
)

print(
    f"Rows merged: "
    f"{merged_count:,}"
)

# ============================================================
# 8. Sort
# ============================================================

df = (
    df.sort_values(
        'co_occurrences',
        ascending=False
    )
    .reset_index(drop=True)
)

# ============================================================
# 9. Save Cleaned Keywords
# ============================================================

print("\nSaving output files...")

cleaned_file = os.path.join(
    OUTPUT_DIR,
    'step3_cleaned_keywords.csv'
)

df.to_csv(
    cleaned_file,
    index=False,
    encoding='utf-8-sig'
)

print(
    f"[1/6] Cleaned keywords saved: "
    f"{len(df):,}"
)

# ============================================================
# 10. VOSviewer Thesaurus
# ============================================================

thesaurus_records = [
    {
        'Label': original,
        'Replace by': normalized
    }
    for original, normalized
    in typo_map.items()
]

df_thesaurus = pd.DataFrame(
    thesaurus_records,
    columns=[
        'Label',
        'Replace by'
    ]
)

if not df_thesaurus.empty:

    df_thesaurus = (
        df_thesaurus
        .drop_duplicates(
            subset=['Label'],
            keep='first'
        )
    )

else:

    df_thesaurus = pd.DataFrame(
        columns=[
            'Label',
            'Replace by'
        ]
    )

# TXT
thesaurus_txt = os.path.join(
    OUTPUT_DIR,
    'step3_thesaurus_vosviewer.txt'
)

df_thesaurus.to_csv(
    thesaurus_txt,
    sep='\t',
    index=False,
    encoding='utf-8-sig'
)

# CSV
thesaurus_csv = os.path.join(
    OUTPUT_DIR,
    'step3_thesaurus_vosviewer.csv'
)

df_thesaurus.to_csv(
    thesaurus_csv,
    index=False,
    encoding='utf-8-sig'
)

print(
    f"[2/6] VOSviewer thesaurus saved: "
    f"{len(df_thesaurus):,} entries"
)

# ============================================================
# 11. Deduplication Details
# ============================================================

if 'original_keywords' in df.columns:

    dedup_details = df[
        df['original_keywords']
        .str.contains(
            ' \| ',
            na=False
        )
    ].copy()

else:

    dedup_details = pd.DataFrame()

dedup_file = os.path.join(
    OUTPUT_DIR,
    'step3_dedup_details.csv'
)

dedup_details.to_csv(
    dedup_file,
    index=False,
    encoding='utf-8-sig'
)

print(
    f"[3/6] Dedup details saved: "
    f"{len(dedup_details):,}"
)

# ============================================================
# 12. Normalization Details
# ============================================================

df_typo = pd.DataFrame(
    [
        {
            'Original': original,
            'Normalized': normalized
        }
        for original, normalized
        in typo_map.items()
    ]
)

normalization_file = os.path.join(
    OUTPUT_DIR,
    'step3_normalization_details.csv'
)

df_typo.to_csv(
    normalization_file,
    index=False,
    encoding='utf-8-sig'
)

print(
    f"[4/6] Normalization details saved: "
    f"{len(df_typo):,}"
)

# ============================================================
# 13. English Report
# ============================================================

report_path = os.path.join(
    OUTPUT_DIR,
    'step3_report.txt'
)

with open(
    report_path,
    'w',
    encoding='utf-8'
) as f:

    f.write("=" * 70 + "\n")
    f.write(
        "STEP 3 REPORT — "
        "Typo Correction and Basic Normalization\n"
    )
    f.write("=" * 70 + "\n\n")

    f.write(
        "Execution Date: "
        f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n"
    )

    f.write(
        f"Input File: {INPUT_FILE}\n\n"
    )

    # --------------------------------------------------------
    # Processing statistics
    # --------------------------------------------------------

    f.write(
        "PROCESSING STATISTICS\n"
    )

    f.write("-" * 70 + "\n")

    f.write(
        f"Total Input Keywords: "
        f"{df_before_dedup:,}\n"
    )

    f.write(
        f"Keywords Normalized "
        f"(Typo/Hyphen fixes): "
        f"{len(typo_map):,}\n"
    )

    f.write(
        f"Duplicate Keywords Merged: "
        f"{merged_count:,}\n"
    )

    f.write(
        f"Final Cleaned Keywords: "
        f"{len(df):,}\n\n"
    )

    # --------------------------------------------------------
    # Normalization details
    # --------------------------------------------------------

    f.write(
        "NORMALIZATION DETAILS\n"
    )

    f.write("-" * 70 + "\n")

    if typo_map:

        for i, (
            original,
            corrected
        ) in enumerate(
            list(typo_map.items())[:20],
            1
        ):

            f.write(
                f"  {i}. "
                f"'{original}' → "
                f"'{corrected}'\n"
            )

        if len(typo_map) > 20:

            f.write(
                f"  ... and "
                f"{len(typo_map) - 20:,} "
                f"more.\n"
            )

    else:

        f.write(
            "  No normalizations were required.\n"
        )

    f.write("\n")

    # --------------------------------------------------------
    # Deduplication details
    # --------------------------------------------------------

    f.write(
        "DEDUPLICATION DETAILS\n"
    )

    f.write("-" * 70 + "\n")

    if not dedup_details.empty:

        f.write(
            f"Total duplicate keywords "
            f"found and merged: "
            f"{len(dedup_details):,}\n"
        )

        f.write(
            f"Total rows reduced: "
            f"{merged_count:,}\n\n"
        )

        f.write(
            "Sample Merges:\n"
        )

        f.write(
            "-" * 70 + "\n"
        )

        for _, row in (
            dedup_details.head(10)
            .iterrows()
        ):

            f.write(
                f"\n  Keyword: "
                f"'{row['keyword']}'\n"
            )

            f.write(
                f"     - Total co-occurrences: "
                f"{row['co_occurrences']:,}\n"
            )

            f.write(
                f"     - Total link strength: "
                f"{row['total_link_strength']:,}\n"
            )

            f.write(
                f"     - Original keywords: "
                f"{row['original_keywords']}\n"
            )

    else:

        f.write(
            "  No duplicate keywords were found.\n"
        )

    f.write("\n")

    # --------------------------------------------------------
    # Output files
    # --------------------------------------------------------

    f.write(
        "OUTPUT FILES DESCRIPTION\n"
    )

    f.write("-" * 70 + "\n")

    f.write(
        "1. step3_cleaned_keywords.csv: "
        "Valid keywords ready for Step 4.\n"
    )

    f.write(
        "2. step3_thesaurus_vosviewer.txt: "
        "Thesaurus for VOSviewer (TXT).\n"
    )

    f.write(
        "3. step3_thesaurus_vosviewer.csv: "
        "Thesaurus for Excel review (CSV).\n"
    )

    f.write(
        "4. step3_dedup_details.csv: "
        "Details of all merged duplicates.\n"
    )

    f.write(
        "5. step3_normalization_details.csv: "
        "Details of all normalizations.\n"
    )

    f.write(
        "6. step3_report.txt: "
        "This audit trail.\n\n"
    )

    # --------------------------------------------------------
    # Next steps
    # --------------------------------------------------------

    f.write(
        "NEXT STEPS\n"
    )

    f.write("-" * 70 + "\n")

    f.write(
        "1. Review step3_dedup_details.csv "
        "to verify merges.\n"
    )

    f.write(
        "2. Review step3_normalization_details.csv "
        "for normalization changes.\n"
    )

    f.write(
        "3. Load step3_thesaurus_vosviewer.txt "
        "into VOSviewer if required.\n"
    )

    f.write(
        "4. Proceed to Step 4 "
        "(Singular/Plural and Synonym merging).\n"
    )

    f.write("=" * 70 + "\n")

# ============================================================
# 14. Final Validation
# ============================================================

print(
    "[5/6] English report saved."
)

print("\nFinal validation:")

print(
    f"   Keywords: {len(df):,}"
)

print(
    f"   Co-occurrences total: "
    f"{df['co_occurrences'].sum():,.0f}"
)

print(
    f"   Total link strength: "
    f"{df['total_link_strength'].sum():,.0f}"
)

print(
    f"   Thesaurus entries: "
    f"{len(df_thesaurus):,}"
)

print(
    f"   Normalization mappings: "
    f"{len(typo_map):,}"
)

print("\nStep 3 completed successfully.")

print(
    f"End time: "
    f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
)

print("=" * 70)