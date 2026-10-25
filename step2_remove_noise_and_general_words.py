# ============================================================
# STEP 2 — Conceptual Filtering and Researcher Decisions
# ============================================================

import os
import re
from pathlib import Path
from datetime import datetime
from collections import Counter

import pandas as pd

# ============================================================
# 1. مسیرها
# ============================================================

INPUT_FILE = r"D:\Thesis\thesaurus\step1\step1_normalized_keywords.csv"
OUTPUT_DIR = r"D:\Thesis\thesaurus\step2"

REVIEW_FILE = os.path.join(OUTPUT_DIR, "step2_review_flags.csv")
CLEANED_FILE = os.path.join(OUTPUT_DIR, "step2_cleaned_keywords.csv")
THESAURUS_TXT = os.path.join(OUTPUT_DIR, "step2_thesaurus_vosviewer.txt")
THESAURUS_CSV = os.path.join(OUTPUT_DIR, "step2_thesaurus_vosviewer.csv")
INTERMEDIATE_FILE = os.path.join(OUTPUT_DIR, "step2_intermediate.csv")
REPORT_FILE = os.path.join(OUTPUT_DIR, "step2_report.txt")

Path(OUTPUT_DIR).mkdir(parents=True, exist_ok=True)

# ============================================================
# 2. پارامترها
# ============================================================

MAX_WORDS_IN_KEYWORD = 4
MIN_KEYWORD_LENGTH = 2

# ============================================================
# 3. فهرست‌های واژگانی (بدون تغییر)
# ============================================================

SAFE_PHRASES = {
    "data science", "machine learning", "artificial intelligence", "deep learning",
    "big data", "data mining", "natural language processing", "computer vision",
    "internet of things", "reinforcement learning", "supervised learning",
    "unsupervised learning", "transfer learning", "federated learning",
    "long short-term memory", "generative adversarial network",
    "support vector machine", "random forest", "decision tree",
    "convolutional neural network", "recurrent neural network",
    "statistical analysis", "regression analysis", "time series analysis",
    "factor analysis", "cluster analysis", "principal component analysis",
    "bibliometric analysis", "scientometric analysis", "co-word analysis",
    "citation analysis", "co-citation analysis", "co-authorship analysis",
    "science mapping", "research front", "emerging topic", "topic evolution",
    "research trend", "hot topic", "knowledge graph", "text mining",
    "web mining", "sentiment analysis", "opinion mining",
    "recommendation system", "expert system", "decision support system",
}

GENERAL_WORDS = {
    "analysis", "analyses",
    "method", "methods", "methodology", "methodologies",
    "approach", "approaches", "technique", "techniques",
    "framework", "frameworks", "tool", "tools",
    "application", "applications", "process", "processes",
    "procedure", "procedures",
    "article", "articles", "paper", "papers",
    "publication", "publications", "study", "studies",
    "research", "review", "reviews", "survey", "surveys",
    "overview", "overviews", "summary", "summaries",
    "introduction", "conclusion", "conclusions", "discussion", "discussions",
    "finding", "findings", "result", "results",
    "implication", "implications", "recommendation", "recommendations",
    "case", "cases", "example", "examples", "sample", "samples",
    "new", "novel", "proposed", "advanced", "comprehensive",
    "general", "generic", "integrated", "emerging", "potential",
    "current", "recent", "modern", "traditional", "future", "past", "present",
    "perspective", "perspectives", "trend", "trends",
    "challenge", "challenges", "issue", "issues", "problem", "problems",
    "solution", "solutions", "opportunity", "opportunities",
    "global", "international", "national", "regional", "local",
    "information", "knowledge", "technology", "management",
    "administration", "organization", "organizations",
    "organisation", "organisations", "development", "implementation",
    "practice", "practices", "policy", "policies",
    "strategy", "strategies", "planning", "operation", "operations", "support",
    "use", "uses", "using", "based", "via", "through", "toward", "towards",
    "between", "among", "across", "from", "with", "for",
    "dataset", "datasets", "data set", "data sets",
    "record", "records", "observation", "observations",
    "experiment", "experiments", "measurement", "measurements",
    "indicator", "indicators", "metric", "metrics",
    "score", "scores", "label", "labels", "class", "classes",
    "category", "categories", "variable", "variables",
    "parameter", "parameters", "component", "components",
    "element", "elements", "structure", "structures",
    "context", "contexts", "factor", "factors",
    "feature", "features", "theory",
    "human", "humans", "user", "users", "patient", "patients",
    "expert", "experts", "student", "students", "teacher", "teachers",
    "community", "communities", "society",
    "business", "businesses", "industry", "industries",
    "service", "services", "resource", "resources",
    "environment", "environments",
    "outcome", "outcomes", "impact", "impacts", "effect", "effects",
    "value", "values", "cost", "costs", "metadata",
    "china", "india", "workshop", "relationship", "case study",
}

GENERAL_PHRASES = {
    "data and data science", "planning and analysis",
    "policy and organization", "methodologies and tools",
    "applications and case studies", "research challenges",
    "research methods", "research methodology", "research design",
    "review methodology", "review methods", "models and analysis",
    "analysis and statistical methods", "safety performance and analysis",
    "transportation planning analysis and application",
    "transportation planning policy and processes",
    "visualization techniques and methodologies",
}

PROTECTED_SHORT_TERMS = {
    "ai", "ml", "dl", "nlp", "cv", "rl", "ar", "vr", "api", "db", "ui", "ux",
    "qa", "r", "c", "go", "io", "svm", "rf", "dt", "knn", "nn", "cnn", "rnn",
    "lstm", "gru", "gan", "bert", "gpt", "gis", "iot", "mlops", "kdd", "semma",
    "ohdsi", "omop", "wgan-gp", "frbcss", "2d", "3d", "4d", "2g", "3g", "4g",
    "5g", "p53", "xai", "rna", "dna", "h1n1", "h5n1", "h7n9", "k12", "k-12",
    "g20", "g7", "g8", "ipv4", "ipv6", "oauth2", "b2b", "b2c", "t-sne",
    "u-net", "k-means", "k-nn", "x-ray", "e-health", "m-health",
    "e-commerce", "e-learning", "e-science", "covid-19", "sars-cov-2",
}

STRICT_NOISE_PATTERNS = [
    r"^\d+$", r"^figure\s*\d+$", r"^table\s*\d+$", r"^eq\.?\s*\d+$",
    r"^equation\s*\d+$", r"^section\s*\d+$", r"^chapter\s*\d+$",
    r"^appendix\s*[a-z]?$", r"^et\s+al\.?$", r"^ibid\.?$",
    r"^op\.?\s*cit\.?$", r"^vs\.?$", r"^[^a-zA-Z0-9]+$",
]

CODE_LIKE_PATTERNS = [
    r"^[a-z]\d{2,4}$", r"^\d{2,3}[a-z]\d{2,4}$", r"^[a-z]\d{2,3}(?:\.\d{2,4})+$",
]

EMBEDDED_CODE_PATTERNS = [
    r"\[[a-z]\d{2,3}(?:\.\d{2,4})+\]",
    r"(?<!\w)[a-z]\d{2,3}(?:\.\d{2,4})+(?!\w)",
    r"(?<!\w)\d{2,3}[a-z]\d{2,3}(?!\w)",
]

DESCRIPTIVE_PHRASES = {
    "proof-of-concept", "harnessing the", "yearbook", "special feature",
    "state of the art", "review of", "survey of", "study of",
}

# ============================================================
# 4. توابع کمکی
# ============================================================

def normalize_key(value):
    return re.sub(r"\s+", " ", str(value)).strip().lower()

def safe_int(value, default=0):
    try:
        return int(float(value))
    except (TypeError, ValueError):
        return default

def word_count(value):
    key = normalize_key(value)
    if not key:
        return 0
    return len(key.split())

def is_strict_noise(keyword):
    key = normalize_key(keyword)
    return any(re.fullmatch(pattern, key) for pattern in STRICT_NOISE_PATTERNS)

def is_code_like(keyword):
    key = normalize_key(keyword)
    if key in PROTECTED_SHORT_TERMS:
        return False
    return any(re.fullmatch(pattern, key) for pattern in CODE_LIKE_PATTERNS)

def contains_embedded_code(keyword):
    key = normalize_key(keyword)
    return any(re.search(pattern, key) for pattern in EMBEDDED_CODE_PATTERNS)

def contains_descriptive_phrase(keyword):
    key = normalize_key(keyword)
    return any(phrase in key for phrase in DESCRIPTIVE_PHRASES)

def is_exact_general_term(keyword):
    key = normalize_key(keyword)
    return key in GENERAL_WORDS or key in GENERAL_PHRASES

def load_user_decisions():
    decisions = {}
    if not os.path.exists(REVIEW_FILE):
        return decisions
    try:
        df_previous_review = pd.read_csv(
            REVIEW_FILE, encoding="utf-8-sig", dtype=str, keep_default_na=False
        )
    except Exception as error:
        print(f"WARNING: Could not read previous review file: {error}")
        return decisions

    if "keyword" not in df_previous_review.columns or "decision" not in df_previous_review.columns:
        return decisions

    for _, row in df_previous_review.iterrows():
        keyword = normalize_key(row.get("keyword", ""))
        decision = normalize_key(row.get("decision", ""))
        if decision not in {"keep", "remove", "split", "merge"}:
            continue
        decisions[keyword] = {
            "decision": decision,
            "split_into": str(row.get("split_into", "")).strip(),
            "merge_with": str(row.get("merge_with", "")).strip(),
        }
    return decisions

# ============================================================
# 5. شروع اجرا
# ============================================================

print("=" * 74)
print("STEP 2 — Conceptual Filtering and Researcher Decisions")
print("=" * 74)
print(f"Start time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

print("\nProcessing order:")
print("1. SAFE_PHRASES")
print("2. GENERAL_WORDS / GENERAL_PHRASES")
print("3. User Decisions")
print("4. Strict Noise")
print("5. Review Flags")

if not os.path.exists(INPUT_FILE):
    raise FileNotFoundError(f"\nInput file not found:\n{INPUT_FILE}")

user_decisions = load_user_decisions()
print(f"\nLoaded user decisions: {len(user_decisions):,}")

df = pd.read_csv(INPUT_FILE, encoding="utf-8-sig", dtype=str, keep_default_na=False)

if "keyword" not in df.columns:
    raise ValueError(f"Column 'keyword' not found. Available columns: {list(df.columns)}")

# ✅ تغییر کلیدی: استفاده از co_occurrences به جای frequency
if "co_occurrences" not in df.columns:
    df["co_occurrences"] = 1

if "total_link_strength" not in df.columns:
    df["total_link_strength"] = 0

df["keyword"] = df["keyword"].astype(str).map(normalize_key)

df["co_occurrences"] = df["co_occurrences"].map(
    lambda value: safe_int(value, 1)
)

df["total_link_strength"] = df["total_link_strength"].map(
    lambda value: safe_int(value, 0)
)

print(f"Loaded Step 1 keywords: {len(df):,}")

# ============================================================
# 6. پردازش کلیدواژه‌ها
# ============================================================

final_keep_rows = []
review_rows = []
thesaurus_rows = []
stats = Counter()

for _, row in df.iterrows():
    keyword = row["keyword"]
    co_occurrences = row["co_occurrences"]   # ✅ تغییر نام
    tls = row["total_link_strength"]
    key = normalize_key(keyword)
    n_words = word_count(keyword)

    # اولویت 1: SAFE_PHRASES
    if key in SAFE_PHRASES:
        final_keep_rows.append({
            "original_keyword": keyword,
            "keyword": keyword,
            "co_occurrences": co_occurrences,
            "total_link_strength": tls,
            "status": "safe_phrase_keep"
        })
        stats["safe_phrase_keep"] += 1
        continue

    # اولویت 2: GENERAL_WORDS / GENERAL_PHRASES
    if is_exact_general_term(keyword):
        thesaurus_rows.append({
            "Label": keyword,
            "Replace by": "",
            "reason": "exact_general_term"
        })
        stats["exact_general_term_removed"] += 1
        continue

    # اولویت 3: User Decisions
    if key in user_decisions:
        info = user_decisions[key]
        decision = info["decision"]

        if decision == "keep":
            final_keep_rows.append({
                "original_keyword": keyword,
                "keyword": keyword,
                "co_occurrences": co_occurrences,
                "total_link_strength": tls,
                "status": "user_keep"
            })
            stats["user_keep"] += 1
            continue

        if decision == "remove":
            thesaurus_rows.append({
                "Label": keyword,
                "Replace by": "",
                "reason": "user_remove"
            })
            stats["user_remove"] += 1
            continue

        if decision == "merge":
            target = normalize_key(info["merge_with"])
            if target:
                thesaurus_rows.append({
                    "Label": keyword,
                    "Replace by": target,
                    "reason": "user_merge"
                })
                stats["user_merge"] += 1
                continue
            else:
                review_rows.append({
                    "keyword": keyword,
                    "co_occurrences": co_occurrences,
                    "total_link_strength": tls,
                    "category": "invalid_user_decision",
                    "reason": "merge_without_merge_with",
                    "word_count": n_words,
                    "decision": "review",
                    "split_into": "",
                    "merge_with": "",
                })
                stats["invalid_user_merge"] += 1
                continue

        if decision == "split":
            split_into = info["split_into"]
            review_rows.append({
                "keyword": keyword,
                "co_occurrences": co_occurrences,
                "total_link_strength": tls,
                "category": "split_requires_preprocessing",
                "reason": "VOSviewer thesaurus cannot split one label into multiple terms. Apply this decision in a separate preprocessing step.",
                "word_count": n_words,
                "decision": "split",
                "split_into": split_into,
                "merge_with": "",
            })
            final_keep_rows.append({
                "original_keyword": keyword,
                "keyword": keyword,
                "co_occurrences": co_occurrences,
                "total_link_strength": tls,
                "status": "user_split_pending"
            })
            stats["user_split_pending"] += 1
            continue

    # اولویت 4: Strict Noise
    if is_strict_noise(keyword):
        thesaurus_rows.append({
            "Label": keyword,
            "Replace by": "",
            "reason": "strict_noise"
        })
        stats["strict_noise_removed"] += 1
        continue

    # اولویت 5: Keep + Review Flags
    final_keep_rows.append({
        "original_keyword": keyword,
        "keyword": keyword,
        "co_occurrences": co_occurrences,
        "total_link_strength": tls,
        "status": "auto_keep"
    })
    stats["auto_keep"] += 1

    flags = []
    if len(key) < MIN_KEYWORD_LENGTH and key not in PROTECTED_SHORT_TERMS:
        flags.append("too_short_unprotected")
    if n_words > MAX_WORDS_IN_KEYWORD:
        flags.append(f"long_phrase_{n_words}_words")
    if re.search(r"\band\b", key):
        flags.append("contains_and")
    if "&" in keyword:
        flags.append("contains_ampersand")
    if is_code_like(keyword):
        flags.append("code_like_term")
    if contains_embedded_code(keyword):
        flags.append("embedded_code_like_pattern")
    if contains_descriptive_phrase(keyword):
        flags.append("descriptive_phrase")

    if flags:
        review_rows.append({
            "keyword": keyword,
            "co_occurrences": co_occurrences,
            "total_link_strength": tls,
            "category": "review_needed",
            "reason": "; ".join(flags),
            "word_count": n_words,
            "decision": "review",
            "split_into": "",
            "merge_with": "",
        })
        stats["review_flags_created"] += 1

# ============================================================
# 7. تجمیع کلیدواژه‌های باقی‌مانده
# ============================================================

df_keep = pd.DataFrame(final_keep_rows)

if df_keep.empty:
    df_keep = pd.DataFrame(columns=[
        "original_keyword", "keyword", "co_occurrences",
        "total_link_strength", "status"
    ])
else:
    df_keep = (
        df_keep
        .groupby("keyword", as_index=False)
        .agg(
            original_keyword=("original_keyword",
                lambda values: " | ".join(sorted(set(str(v) for v in values if str(v).strip())))),
            co_occurrences=("co_occurrences", "sum"),
            total_link_strength=("total_link_strength", "sum"),
            status=("status", lambda values: " | ".join(sorted(set(values))))
        )
        .sort_values(
            by=["co_occurrences", "total_link_strength"],
            ascending=[False, False]
        )
        .reset_index(drop=True)
    )

# ============================================================
# 8. اعتبارسنجی تزاروس
# ============================================================

df_thesaurus = pd.DataFrame(
    thesaurus_rows, columns=["Label", "Replace by", "reason"]
)

if not df_thesaurus.empty:
    df_thesaurus["Label"] = df_thesaurus["Label"].map(normalize_key)
    df_thesaurus["Replace by"] = df_thesaurus["Replace by"].map(
        lambda value: normalize_key(value) if str(value).strip() else ""
    )
    df_thesaurus = df_thesaurus[df_thesaurus["Label"].ne("")].copy()
    df_thesaurus = df_thesaurus.drop_duplicates(subset=["Label"], keep="first")
    df_thesaurus = df_thesaurus[df_thesaurus["Label"] != df_thesaurus["Replace by"]].copy()
    label_set = set(df_thesaurus["Label"])
    replace_set = set(df_thesaurus.loc[df_thesaurus["Replace by"].ne(""), "Replace by"])
    overlap = label_set.intersection(replace_set)
else:
    overlap = set()

# ============================================================
# 9. ساخت فایل Review پایدار
# ============================================================

review_columns = [
    "keyword", "co_occurrences", "total_link_strength",
    "category", "reason", "word_count",
    "decision", "split_into", "merge_with",
]

df_new_review = pd.DataFrame(review_rows, columns=review_columns)
df_existing_review = pd.DataFrame(columns=review_columns)

if os.path.exists(REVIEW_FILE):
    try:
        df_existing_review = pd.read_csv(
            REVIEW_FILE, encoding="utf-8-sig", dtype=str, keep_default_na=False
        )
        for column in review_columns:
            if column not in df_existing_review.columns:
                df_existing_review[column] = ""
        df_existing_review = df_existing_review[review_columns]
    except Exception as error:
        print(f"WARNING: Could not preserve old review file: {error}")

df_review = pd.concat([df_existing_review, df_new_review], ignore_index=True)

df_review["keyword_key"] = df_review["keyword"].map(normalize_key)

decision_priority = {
    "remove": 4, "keep": 4, "merge": 4, "split": 4, "review": 1, "": 0,
}

df_review["decision_priority"] = df_review["decision"].map(
    lambda value: decision_priority.get(normalize_key(value), 0)
)

df_review["frequency_num"] = df_review["co_occurrences"].map(
    lambda value: safe_int(value, 0)
)

df_review = (
    df_review
    .sort_values(
        by=["keyword_key", "decision_priority", "frequency_num"],
        ascending=[True, False, False]
    )
    .drop_duplicates(subset=["keyword_key"], keep="first")
    .sort_values(by="frequency_num", ascending=False)
    .drop(columns=["keyword_key", "decision_priority", "frequency_num"])
    .reset_index(drop=True)
)

# ============================================================
# 10. ذخیره خروجی‌ها
# ============================================================

df_keep.to_csv(CLEANED_FILE, index=False, encoding="utf-8-sig")
df_review.to_csv(REVIEW_FILE, index=False, encoding="utf-8-sig")

if df_thesaurus.empty:
    df_thesaurus_vos = pd.DataFrame(columns=["Label", "Replace by"])
else:
    df_thesaurus_vos = df_thesaurus[["Label", "Replace by"]].copy()

df_thesaurus_vos.to_csv(THESAURUS_TXT, sep="\t", index=False, encoding="utf-8-sig")
df_thesaurus_vos.to_csv(THESAURUS_CSV, index=False, encoding="utf-8-sig")

df_decisions_applied = pd.DataFrame([
    {
        "keyword": keyword,
        "decision": info["decision"],
        "split_into": info["split_into"],
        "merge_with": info["merge_with"],
    }
    for keyword, info in user_decisions.items()
])

df_decisions_applied.to_csv(INTERMEDIATE_FILE, index=False, encoding="utf-8-sig")

# ============================================================
# 11. گزارش
# ============================================================

with open(REPORT_FILE, "w", encoding="utf-8") as report:
    report.write("=" * 78 + "\n")
    report.write("STEP 2 REPORT — Conceptual Filtering and Researcher Decisions\n")
    report.write("=" * 78 + "\n\n")
    report.write(f"Execution date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
    report.write(f"Input file: {INPUT_FILE}\n")
    report.write(f"Output directory: {OUTPUT_DIR}\n\n")

    report.write("PROCESSING ORDER\n")
    report.write("-" * 78 + "\n")
    report.write("1. SAFE_PHRASES\n")
    report.write("2. GENERAL_WORDS / GENERAL_PHRASES\n")
    report.write("3. User Decisions\n")
    report.write("4. Strict Noise\n")
    report.write("5. Keep + Review Flags\n\n")

    report.write("STATISTICS\n")
    report.write("-" * 78 + "\n")
    report.write(f"Input keywords: {len(df):,}\n")
    report.write(f"Kept keywords: {len(df_keep):,}\n")
    report.write(f"Thesaurus rows: {len(df_thesaurus_vos):,}\n")
    report.write(f"Review rows: {len(df_review):,}\n")
    report.write(f"User decisions loaded: {len(user_decisions):,}\n")
    report.write(f"Label/Replace by overlap count: {len(overlap):,}\n\n")

    report.write("DECISION STATISTICS\n")
    report.write("-" * 78 + "\n")
    for name, count in stats.most_common():
        report.write(f"{name}: {count:,}\n")

    report.write("\nOUTPUT FILES\n")
    report.write("-" * 78 + "\n")
    report.write("1. step2_cleaned_keywords.csv\n")
    report.write("2. step2_review_flags.csv\n")
    report.write("3. step2_thesaurus_vosviewer.txt\n")
    report.write("4. step2_thesaurus_vosviewer.csv\n")
    report.write("5. step2_intermediate.csv\n")
    report.write("6. step2_report.txt\n")

print("=" * 74)
print("STEP 2 completed successfully.")
print("=" * 74)
print(f"Kept keywords: {len(df_keep):,}")
print(f"Thesaurus rows: {len(df_thesaurus_vos):,}")
print(f"Review rows: {len(df_review):,}")
print(f"Report: {REPORT_FILE}")