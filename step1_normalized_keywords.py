# ============================================================
# STEP 1 — Normalization + OpenRefine Integration
# ============================================================
import pandas as pd
import os
import re
from datetime import datetime
from collections import Counter

# =============== ۱. تنظیمات مسیرها =================
input_dir = r"D:\Thesis\Data\Step6_VOSviewer_RIS"
output_dir = r"D:\Thesis\Thesaurus\step1"

input_file = os.path.join(input_dir, "co_occurrences 1 keywords.txt")
OPENREFINE_THESAURUS_PATH = os.path.join(input_dir, "OpenRefine_Thesaurus.txt")

output_cleaned = os.path.join(output_dir, "step1_normalized_keywords.csv")
output_thesaurus_txt = os.path.join(output_dir, "step1_thesaurus_vosviewer.txt")
output_thesaurus_csv = os.path.join(output_dir, "step1_thesaurus_vosviewer.csv")
output_review_flags = os.path.join(output_dir, "step1_review_flags.csv")
output_report = os.path.join(output_dir, "step1_report.txt")

os.makedirs(output_dir, exist_ok=True)

# =============== ۲. تنظیمات =================
REVIEW_FREQUENCY_THRESHOLD = 10

KNOWN_SHORT_OR_ALPHANUMERIC_TERMS = {
    "r", "c", "go", "io", "db", "ui", "ux", "ai", "ml", "ar", "vr", "qa", "ci", "cd",
    "2d", "3d", "4d", "5g", "4g", "3g", "2g",
    "k12", "k-12", "g20", "g7", "g8",
    "h1n1", "h5n1", "h7n9", "covid-19", "sars-cov-2",
    "ipv4", "ipv6", "oauth2",
    "industry 4.0", "industry 5.0", "society 5.0", "pharma 4.0", "quality 4.0",
    "p53", "xai", "b2b", "b2c", "m10", "g11",
    "t-sne", "u-net", "k-means", "k-nn", "x-ray",
    "e-health", "m-health", "e-commerce", "e-learning", "e-science",
    "c++", "c#",
}

MANDATORY_HYPHENS = {
    "state-of-the-art", "co-occurrence", "data-driven decision-making", "cross-validation", "fine-tuning",
    "peer-to-peer", "real-world", "long-term", "short-term", "large-scale",
    "high-dimensional", "low-dimensional", "high-throughput", "multi-agent",
    "self-organizing", "data-driven", "evidence-based", "open-source",
    "time-series", "spatio-temporal", "decision-making", "problem-solving",
    "mixed-methods", "pre-processing", "post-processing", "top-down",
    "bottom-up", "zero-shot", "few-shot", "model-free", "model-based",
    "domain-specific", "next-generation", "single-cell", "high-resolution",
    "high-performance", "real-time", "in-vivo", "in-vitro", "non-linear",
    "non-parametric", "agent-based", "cross-sectional", "case-control",
    "randomized-controlled", "privacy-preserving", "differential-privacy",
    "knowledge-distillation", "meta-learning", "cross-lingual", "cross-modal",
    "cross-domain", "actor-critic", "q-learning", "chain-of-thought",
    "retrieval-augmented", "text-to-speech", "speech-to-text",
    "vision-language", "graph-of-thought", "k-nearest-neighbor", "k-fold",
    "leave-one-out", "root-mean-squared", "mean-squared", "mean-absolute",
    "area-under", "receiver-operating", "precision-recall", "f1-score",
    "term-frequency", "inverse-document", "bidirectional-encoder",
    "generative-pre-trained", "field-programmable", "gradient-penalty",
    "neuro-fuzzy", "adaptive-neuro-fuzzy", "decision-support",
    "human-computer", "computer-aided", "machine-learning", "deep-learning",
    "big-data", "data-science", "data-mining", "natural-language-processing",
    "computer-vision", "reinforcement-learning", "supervised-learning",
    "unsupervised-learning", "semi-supervised-learning", "self-supervised-learning",
    "transfer-learning", "ensemble-learning", "federated-learning",
    "explainable-ai", "interpretable-machine-learning",
    "random-forest", "support-vector-machine", "decision-tree",
    "gradient-boosting", "neural-network", "convolutional-neural-network",
    "recurrent-neural-network", "long-short-term-memory", "gated-recurrent-unit",
    "generative-adversarial-network", "variational-autoencoder",
    "transformer-model", "attention-mechanism", "bert-model", "gpt-model",
    "large-language-model", "knowledge-graph", "semantic-web",
    "linked-data", "open-data", "open-science", "open-access",
    "fair-principles", "fair-data", "reproducible-research",
    "replicability", "reproducibility", "research-data-management",
    "data-management-plan", "metadata-standard", "data-standard",
    "data-harmonization", "data-interoperability", "data-provenance",
    "data-stewardship", "data-ownership", "data-sharing", "data-reuse",
    "h-index", "g-index", "impact-factor", "citation-count",
    "journal-impact", "research-impact", "altmetric-score",
    "normalized-citation", "field-weighted-citation-impact",
    "collaboration-network", "co-authorship-network",
    "keyword-co-occurrence", "co-authorship", "co-citation",
    "bibliometric-analysis", "scientometric-analysis", "co-word-analysis",
    "science-mapping", "research-front", "emerging-topic", "topic-evolution",
    "research-trend", "hot-topic", "research-hotspot", "co-word",
    "multi-objective", "multi-modal", "multi-task", "multi-label", "multi-class",
    "multi-scale", "multi-layer", "multi-variate", "self-attention",
    "model-driven", "knowledge-driven", "rule-based", "case-based",
    "user-centered", "human-centered", "human-in-the-loop", "computer-assisted",
    "cloud-based", "web-based", "edge-based", "end-to-end",
    "in-silico", "first-principles", "high-entropy", "non-negative",
    "non-convex", "non-stationary", "non-invasive", "sub-optimal",
    "re-identification", "re-sampling", "pre-trained", "pre-defined", "follow-up",
    "double-blind", "placebo-controlled", "dose-response", "risk-factor",
    "protein-protein", "crispr-cas9", "high-accuracy", "low-latency",
    "multi-resolution", "multi-spectral", "privacy-enhancing",
    "low-rank", "multi-task-learning", "cross-lingual-transfer",
    "zero-shot-transfer", "few-shot-transfer", "continual-learning",
    "lifelong-learning", "incremental-learning",
    "self-supervised", "semi-supervised", "unsupervised", "supervised",
    "weakly-supervised", "noisy-supervised", "active-learning",
    "imitation-learning", "inverse-reinforcement",
    "offline-rl", "online-rl", "model-based-rl", "model-free-rl",
    "value-based", "policy-based", "sarsa", "dqn", "ddpg", "td3", "sac", "ppo",
    "maml", "reptile", "proto-net", "matching-net", "relation-net",
    "meta-opt", "snail", "r2-d2", "mt-net", "l2l", "anil",
    "first-order-maml", "higher-order-maml", "implicit-maml", "online-maml",
    "almost-no-inner-loop", "task-agnostic", "task-specific",
    "domain-agnostic", "domain-specific", "language-agnostic",
    "language-specific", "modality-agnostic", "modality-specific",
}

TYPO_CORRECTIONS = {
    "machien learning": "machine learning",
    "artifical intelligence": "artificial intelligence",
    "artifical": "artificial",
    "learing": "learning",
    "algoritm": "algorithm",
    "algoritms": "algorithms",
    "datamining": "data mining",
    "bigdata": "big data",
    "deeplearning": "deep learning",
    "machinelearning": "machine learning",
    "neuralnetwork": "neural network",
    "neuralnetworks": "neural networks",
    "covid19": "covid-19",
    "covid 19": "covid-19",
    "sars-cov2": "sars-cov-2",
    "sarscov2": "sars-cov-2",
    "behaviour": "behavior",
    "behaviours": "behaviors",
    "behavioural": "behavioral",
    "modelling": "modeling",
    "visualisation": "visualization",
    "visualisations": "visualizations",
    "optimisation": "optimization",
    "optimisations": "optimizations",
    "personalised": "personalized",
    "personalisation": "personalization",
    "recognise": "recognize",
    "recognised": "recognized",
    "analyse": "analyze",
    "analysed": "analyzed",
    "categorisation": "categorization",
    "standardisation": "standardization",
    "generalisation": "generalization",
    "specialisation": "specialization",
    "organisation": "organization",
    "organisations": "organizations",
    "digitisation": "digitization",
    "centre": "center",
    "colour": "color",
    "favour": "favor",
    "labour": "labor",
    "catalogue": "catalog",
    "programme": "program",
    "defence": "defense",
    "licence": "license",
    "practise": "practice",
    "aluminium": "aluminum",
    "data driven decision making": "data-driven decision-making",
    "data driven decision-making": "data-driven decision-making",
    "data-driven decision making": "data-driven decision-making",
    "data driven modelling": "data-driven modeling",
}
TYPO_CORRECTIONS_SORTED = sorted(TYPO_CORRECTIONS.items(), key=lambda x: -len(x[0]))

STRICT_NOISE_PATTERNS = [
    r"^\d+$",
    r"^[^a-zA-Z\u0600-\u06FF0-9\s./()&+#@!?'\":-]+$",
]

CODE_LIKE_REVIEW_PATTERNS = [
    r"^[a-z]\d{2,3}$",
    r"^\d{2}[a-z]\d{2}$",
]

EMBEDDED_NOISE_PATTERNS = [
    r"\[[a-z]\d{2,3}(?:\.\d{2,4})+\]",
    r"(?<!\w)[a-z]\d{2,3}(?:\.\d{2,4})+(?!\w)",
    r"(?<!\w)\d{2,3}[a-z]\d{2,3}(?!\w)",
]

# =============== ۳. توابع کمکی =================
def clean_spaces(text):
    return re.sub(r"\s+", " ", str(text)).strip()

def comparison_key(value):
    return clean_spaces(value).lower()

def is_code_like(value):
    key = comparison_key(value)
    if key in KNOWN_SHORT_OR_ALPHANUMERIC_TERMS:
        return False
    return any(re.fullmatch(pattern, key) for pattern in CODE_LIKE_REVIEW_PATTERNS)

def load_openrefine_thesaurus(filepath):
    or_map = {}
    if not os.path.exists(filepath):
        print(f"⚠️ OpenRefine Thesaurus file not found at: {filepath}")
        print("   Proceeding with automated rules only.\n")
        return or_map

    df_or = None
    used_encoding = None
    used_sep = None
    for encoding in ['utf-16', 'utf-8-sig', 'utf-8', 'latin1', 'cp1252']:
        for sep in ['\t', ',']:
            try:
                df_or = pd.read_csv(filepath, sep=sep, encoding=encoding, dtype=str, keep_default_na=False)
                if df_or.shape[1] >= 2:
                    used_encoding = encoding
                    used_sep = 'Tab' if sep == '\t' else 'Comma'
                    break
            except Exception:
                continue
        if df_or is not None and df_or.shape[1] >= 2:
            break

    if df_or is None or df_or.shape[1] < 2:
        print(f"❌ Could not read OpenRefine Thesaurus with any encoding/separator.")
        return or_map

    print(f"✅ Read OpenRefine file (encoding={used_encoding}, sep={used_sep})")

    df_or.columns = df_or.columns.str.strip().str.lower()
    print(f"✅ Columns detected: {df_or.columns.tolist()}")

    label_col = None
    replace_col = None
    for col in df_or.columns:
        if col in ['label', 'original', 'keyword_original', 'keuword_original']:
            label_col = col
        if col in ['replace by', 'replace_by', 'keyword', 'normalized']:
            replace_col = col

    if label_col is None or replace_col is None:
        print(f"⚠️ Could not detect columns. Available: {df_or.columns.tolist()}")
        return or_map

    for _, row in df_or.iterrows():
        label = str(row[label_col]).strip()
        replace_by = str(row[replace_col]).strip()
        if label and label.lower() != replace_by.lower():
            or_map[label.lower()] = replace_by

    print(f"✅ Loaded {len(or_map)} manual mapping rules from OpenRefine.")
    return or_map

def normalize_keyword(keyword, or_map):
    if pd.isna(keyword) or str(keyword).strip() == "":
        return "", ["Empty keyword"], [], "empty_keyword"

    original = str(keyword).strip()
    current = original.lower()
    rules = []
    review_reasons = []

    new = re.sub(r"<[^>]+>", "", current)
    if new != current:
        current = new
        rules.append("HTML tag removal")

    new = current.replace("–", "-").replace("—", "-").replace("−", "-")
    if new != current:
        current = new
        rules.append("Unicode dash normalized to hyphen")

    new = current.replace("\u2019", "'").replace("\u2018", "'").replace("`", "'")
    if new != current:
        current = new
        rules.append("Apostrophe standardization")

    new = re.sub(r"[^\w\s\-\/\(\)\.\,\&\+\#\@\!\?\'\":]", "", current)
    if new != current:
        current = new
        rules.append("Unsupported special character removal")

    new = clean_spaces(current)
    if new != current:
        current = new
        rules.append("Whitespace normalization")

    new = current.strip("-").strip()
    if new != current:
        current = new
        rules.append("Leading/trailing hyphen removal")

    new = re.sub(r"\(\s*\)", "", current)
    if new != current:
        current = new
        rules.append("Empty parenthesis removal")

    current = clean_spaces(current)
    current_key = comparison_key(current)
    original_key = comparison_key(original)

    or_target = None
    if original_key in or_map:
        or_target = or_map[original_key]
        rules.append("OpenRefine manual override (on original)")
    elif current_key in or_map:
        or_target = or_map[current_key]
        rules.append("OpenRefine manual override (on normalized)")

    if or_target is not None:
        if or_target == "":
            return "", rules, ["Removed by OpenRefine manual decision"], "openrefine_removal"
        else:
            return or_target, rules, [], ""

    if current_key not in KNOWN_SHORT_OR_ALPHANUMERIC_TERMS:
        for pattern in STRICT_NOISE_PATTERNS:
            if re.fullmatch(pattern, current_key):
                rules.append("Strict noise removal")
                return "", rules, [], "strict_noise"

    for pattern in EMBEDDED_NOISE_PATTERNS:
        new = re.sub(pattern, "", current)
        if new != current:
            current = new
            rules.append("Embedded noise code removal")

    current = clean_spaces(current)
    current_key = comparison_key(current)
    if current_key == "":
        rules.append("Keyword empty after normalization")
        return "", rules, [], "empty_after_normalization"

    for typo, correction in TYPO_CORRECTIONS_SORTED:
        pattern = r"\b" + re.escape(typo) + r"\b"
        new = re.sub(pattern, correction, current)
        if new != current:
            current = new
            rules.append(f"Typo correction: {typo} -> {correction}")

    current = clean_spaces(current)
    current_key = comparison_key(current)

    if is_code_like(current_key):
        review_reasons.append("Code-like short term")

    if "-" in current_key and current_key not in KNOWN_SHORT_OR_ALPHANUMERIC_TERMS and current_key not in MANDATORY_HYPHENS:
        review_reasons.append("Hyphenated term: verify if standard")

    if len(current_key) <= 1 and current_key not in KNOWN_SHORT_OR_ALPHANUMERIC_TERMS:
        rules.append("Single-character non-whitelisted term removal")
        return "", rules, [], "single_character_non_whitelisted"

    return current_key, rules, review_reasons, ""

def build_thesaurus(all_rows, review_flags):
    mapping = {}
    for row in all_rows:
        label_original = clean_spaces(row["original_keyword"])
        label_key = comparison_key(label_original)
        target_key = comparison_key(row["normalized_keyword"])
        frequency = int(row["co_occurrences"])
        removal_reason = row["removal_reason"]
        if label_original == "":
            continue
        candidate = {
            "label_original": label_original,
            "target_key": target_key,
            "frequency": frequency,
            "removal_reason": removal_reason,
        }
        if label_key not in mapping or frequency > mapping[label_key]["frequency"]:
            mapping[label_key] = candidate

    def resolve_target(start_key):
        seen = set()
        current_key = start_key
        while current_key in mapping and mapping[current_key]["target_key"] != "":
            if current_key in seen:
                return None
            seen.add(current_key)
            next_key = mapping[current_key]["target_key"]
            if next_key == current_key:
                return current_key
            current_key = next_key
        return current_key

    resolved_rows = []
    for label_key, info in mapping.items():
        label_original = info["label_original"]
        target_key = info["target_key"]
        frequency = info["frequency"]
        removal_reason = info["removal_reason"]

        if removal_reason != "":
            resolved_rows.append({"Label": label_original, "Replace by": ""})
            continue

        if label_key == target_key:
            continue

        final_target = resolve_target(target_key)
        if final_target is None:
            review_flags.append({
                "original": label_original,
                "normalized": target_key,
                "frequency": frequency,
                "reason": "Replacement cycle detected; excluded",
            })
            continue
        if label_key == final_target:
            continue
        resolved_rows.append({"Label": label_original, "Replace by": final_target})

    df_th = pd.DataFrame(resolved_rows, columns=["Label", "Replace by"])
    if df_th.empty:
        return df_th
    df_th["Label"] = df_th["Label"].fillna("").astype(str).map(clean_spaces)
    df_th["Replace by"] = df_th["Replace by"].fillna("").astype(str).map(clean_spaces)
    df_th = df_th[df_th["Label"] != ""].copy()
    df_th["_label_key"] = df_th["Label"].map(comparison_key)
    df_th = df_th.drop_duplicates(subset=["_label_key"], keep="first").copy()
    df_th = df_th[df_th["_label_key"] != df_th["Replace by"].map(comparison_key)].copy()
    return df_th[["Label", "Replace by"]].sort_values(by=["Label", "Replace by"]).reset_index(drop=True)

# =============== ۴. اجرای اصلی =================
print("=" * 72)
print("STEP 1 — Normalization + OpenRefine Integration")
print("=" * 72)
print(f"Start time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

if not os.path.exists(input_file):
    raise FileNotFoundError(f"\n❌ Input file not found:\n{input_file}")

print("\nLoading OpenRefine Thesaurus...")
openrefine_map = load_openrefine_thesaurus(OPENREFINE_THESAURUS_PATH)

try:
    df_raw = pd.read_csv(input_file, sep="\t", encoding="utf-8-sig", dtype=str, keep_default_na=False)
except UnicodeDecodeError:
    df_raw = pd.read_csv(input_file, sep="\t", encoding="latin1", dtype=str, keep_default_na=False)

initial_count = len(df_raw)
print(f"Raw input rows: {initial_count:,}")

column_mapping = {}
for column in df_raw.columns:
    column_name = column.lower().strip()
    if column_name in {"items", "keyword", "keywords", "label", "term", "terms", "word", "words"}:
        column_mapping[column] = "keyword"
    elif column_name in {"count", "occurrences", "occurrence", "frequency", "freq", "co_occurrences"}:
        column_mapping[column] = "co_occurrences"
    elif column_name in {"total link strength", "tls", "link strength"}:
        column_mapping[column] = "total_link_strength"

df = df_raw.rename(columns=column_mapping).copy()

if "keyword" not in df.columns:
    raise ValueError(f"\n❌ Keyword column not found. Available: {list(df_raw.columns)}")
if "co_occurrences" not in df.columns:
    df["co_occurrences"] = 1
if "total_link_strength" not in df.columns:
    df["total_link_strength"] = 1

df = df[["keyword", "co_occurrences", "total_link_strength"]].copy()
df["keyword"] = df["keyword"].fillna("").astype(str)
df["co_occurrences"] = pd.to_numeric(df["co_occurrences"], errors="coerce").fillna(1).astype(int)
df["total_link_strength"] = pd.to_numeric(df["total_link_strength"], errors="coerce").fillna(1).astype(int)

print("\nNormalizing keywords...")
all_rows = []
normalized_values = []
review_flags = []
openrefine_applied_count = 0

for _, row in df.iterrows():
    original_keyword = row["keyword"]
    co_occurrences = int(row["co_occurrences"])
    tls = int(row["total_link_strength"])
    normalized, rules, review_reasons, removal_reason = normalize_keyword(original_keyword, openrefine_map)
    normalized_values.append(normalized)
    if "OpenRefine manual override" in "; ".join(rules):
        openrefine_applied_count += 1
    original_key = comparison_key(original_keyword)
    normalized_key = comparison_key(normalized)
    automatic_change = (normalized_key != original_key)
    priority_review = (
        automatic_change or
        removal_reason != "" or
        (len(review_reasons) > 0 and co_occurrences >= REVIEW_FREQUENCY_THRESHOLD)
    )
    review_reason_parts = []
    if automatic_change:
        review_reason_parts.append("Automatic normalization/replacement")
    if removal_reason != "":
        review_reason_parts.append(f"Automatic removal: {removal_reason}")
    review_reason_parts.extend(review_reasons)
    all_rows.append({
        "original_keyword": original_keyword,
        "normalized_keyword": normalized,
        "co_occurrences": co_occurrences,
        "total_link_strength": tls,
        "automatic_change": automatic_change,
        "priority_review": priority_review,
        "rules_applied": "; ".join(rules),
        "review_reason": "; ".join(review_reason_parts),
        "removal_reason": removal_reason
    })
    if priority_review:
        review_flags.append({
            "original": original_keyword,
            "normalized": normalized,
            "frequency": co_occurrences,
            "tls": tls,
            "automatic_change": automatic_change,
            "removal_reason": removal_reason,
            "reason": "; ".join(review_reason_parts)
        })

df["keyword_normalized"] = normalized_values
df_all = pd.DataFrame(all_rows)

print("Removing strict noise and merging duplicates...")
df_valid = df[df["keyword_normalized"].fillna("").astype(str).str.strip().ne("")].copy()
removed_count = len(df) - len(df_valid)

df_sorted = df_valid.sort_values(by=["co_occurrences", "total_link_strength"], ascending=[False, False]).copy()
df_grouped = (
    df_sorted.groupby("keyword_normalized", as_index=False)
    .agg(
        co_occurrences=("co_occurrences", "sum"),
        total_link_strength=("total_link_strength", "sum"),
        original_keyword=("keyword", "first")
    )
    .rename(columns={"keyword_normalized": "keyword"})
    .sort_values(by=["co_occurrences", "total_link_strength"], ascending=[False, False])
    .reset_index(drop=True)
)

unique_keywords = len(df_grouped)
total_co_occurrences = int(df_grouped["co_occurrences"].sum())
total_tls = int(df_grouped["total_link_strength"].sum())
merged_duplicates = len(df_valid) - unique_keywords

print("Building VOSviewer thesaurus...")
df_thesaurus = build_thesaurus(all_rows, review_flags)
thesaurus_count = len(df_thesaurus)

duplicate_label_count = int(df_thesaurus["Label"].map(comparison_key).duplicated().sum()) if not df_thesaurus.empty else 0
identity_mapping_count = int((df_thesaurus["Label"].map(comparison_key) == df_thesaurus["Replace by"].map(comparison_key)).sum()) if not df_thesaurus.empty else 0

review_columns = ["original", "normalized", "frequency", "tls", "automatic_change", "removal_reason", "reason"]
if review_flags:
    df_review = pd.DataFrame(review_flags)
    for col in review_columns:
        if col not in df_review.columns:
            df_review[col] = ""
    df_review = df_review[review_columns]
else:
    df_review = pd.DataFrame(columns=review_columns)

if not df_review.empty:
    df_review["frequency"] = pd.to_numeric(df_review["frequency"], errors="coerce")
    df_review["tls"] = pd.to_numeric(df_review["tls"], errors="coerce")
    df_review = (
        df_review.drop_duplicates(subset=["original", "normalized", "reason"], keep="first")
        .sort_values(by=["automatic_change", "frequency", "tls"], ascending=[False, False, False], na_position="last")
        .reset_index(drop=True)
    )

print("\nSaving output files...")
df_thesaurus.to_csv(output_thesaurus_txt, sep="\t", index=False, encoding="utf-8-sig")
df_thesaurus.to_csv(output_thesaurus_csv, index=False, encoding="utf-8-sig")
df_grouped[["original_keyword", "keyword", "co_occurrences", "total_link_strength"]].to_csv(output_cleaned, index=False, encoding="utf-8-sig")
df_review.to_csv(output_review_flags, index=False, encoding="utf-8-sig")

rule_counter = Counter()
for row in all_rows:
    rules_text = row["rules_applied"]
    if rules_text:
        for rule in rules_text.split("; "):
            rule_counter[rule] += 1

automatic_change_count = int(df_all["automatic_change"].sum())
automatic_removal_count = int(df_all["removal_reason"].ne("").sum())
review_count = len(df_review)

with open(output_report, "w", encoding="utf-8") as report:
    report.write("=" * 78 + "\n")
    report.write("STEP 1 REPORT — Normalization + OpenRefine Integration\n")
    report.write("=" * 78 + "\n\n")
    report.write(f"Execution date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
    report.write(f"Input file: {input_file}\n")
    report.write(f"OpenRefine Thesaurus: {OPENREFINE_THESAURUS_PATH}\n")
    report.write(f"Output directory: {output_dir}\n\n")
    report.write("OPENREFINE INTEGRATION STATS\n")
    report.write("-" * 78 + "\n")
    report.write(f"Manual rules loaded from OpenRefine: {len(openrefine_map):,}\n")
    report.write(f"Manual rules successfully applied: {openrefine_applied_count:,}\n\n")
    report.write("PROCESSING STATISTICS\n")
    report.write("-" * 78 + "\n")
    report.write(f"Raw input rows: {initial_count:,}\n")
    report.write(f"Automatic normalization/replacements (Python): {automatic_change_count:,}\n")
    report.write(f"Automatic removals: {automatic_removal_count:,}\n")
    report.write(f"Rows removed from normalized list: {removed_count:,}\n")
    report.write(f"Valid rows before duplicate merging: {len(df_valid):,}\n")
    report.write(f"Duplicate normalized rows merged: {merged_duplicates:,}\n")
    report.write(f"Unique normalized keywords: {unique_keywords:,}\n")
    report.write(f"Total co-occurrences after merging: {total_co_occurrences:,}\n")
    report.write(f"Final thesaurus rows: {thesaurus_count:,}\n")
    report.write(f"Review-file rows: {review_count:,}\n")
    report.write(f"Duplicate logical Labels: {duplicate_label_count:,}\n")
    report.write(f"Identity mappings: {identity_mapping_count:,}\n\n")
    report.write("APPLIED RULES\n")
    report.write("-" * 78 + "\n")
    if rule_counter:
        for rule, count in rule_counter.most_common():
            report.write(f"{rule}: {count:,}\n")
    else:
        report.write("No normalization rules were applied.\n")

print(f"✅ [5/5] Report saved: {output_report}")
print("\n" + "= " * 72)
print("STEP 1 completed successfully with OpenRefine integration.")
print("= " * 72)
print(f"Raw input rows: {initial_count:,}")
print(f"Unique normalized keywords: {unique_keywords:,}")
print(f"Thesaurus rows: {thesaurus_count:,}")
print(f"OpenRefine rules applied: {openrefine_applied_count:,}")
print(f"\nFiles created in:\n{output_dir}")