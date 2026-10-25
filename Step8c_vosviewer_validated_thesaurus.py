# -*- coding: utf-8 -*-
"""
اصلاح خودکار + اعتبارسنجی تزاروس VOSviewer (یک اسکریپت، یک بار اجرا)
- فایل اصلی فقط خوانده می‌شود و هرگز تغییر نمی‌کند.
- همه خروجی‌ها فقط در D:\Thesis\Thesaurus\validation_output ساخته می‌شود:
    vosviewer_final_thesaurus_fixed.txt   (نسخه اصلاح‌شده تزاروس)
    thesaurus_validation_report.txt       (گزارش)
    thesaurus_review_sample.xlsx          (شیت issues + نمونه‌ها)
    error_log.txt                         (فقط در صورت خطا)
نصب لازم:  pip install pandas openpyxl
"""
import re
import random
import difflib
import traceback
from pathlib import Path
from collections import defaultdict, Counter

# ====================== تنظیمات ======================
BASE = Path(r"D:\Thesis\Thesaurus")
SRC = BASE / "final_vosviewer_thesaurus" / "vosviewer_final_thesaurus.txt"   # فایل اصلی (فقط خوانده می‌شود)
OUT_DIR = BASE / "validation_output"                                         # همه خروجی‌ها اینجا
DST = OUT_DIR / "vosviewer_final_thesaurus_fixed.txt"                        # نسخه اصلاح‌شده
SAMPLE_SIZE = 300
DELETE_SAMPLE_SIZE = 300
BIG_GROUP_MIN = 10
SIM_THRESHOLD = 0.5
SEED = 42

# --- قواعد اصلاح (می‌توانید ویرایششان کنید) ---
DELETE_TARGETS = {"and electric vehicles", "msc 2010: primary",
                  "pattern (behavior choices etc.)"}          # مقصدهای بی‌معنا -> حذف

RETARGET = {                                                  # مقصد قدیمی -> مقصد درست
    "and data-driven decision-making": "data-driven decision-making",
    "and non-governmental organizations": "non-governmental organizations",
    "author-keywordprobabilities and stochastic processes": "probabilities and stochastic processes",
    "data science mesh": "data science",
    "h(2)o(2 )production": "h2o2 production",
    "deepconvolutional neural networks": "deep convolutional neural network",
    "voting classier": "voting classifier",
    "cr yo-em": "cryo-em",
    "trusted research environment tre": "trusted research environment",
    "tumor microenvironment-tme": "tumor microenvironment",
    "immune related adverse event -irae": "immune related adverse event",
    "total petroleum hydrocarbons-tph": "total petroleum hydrocarbons",
    "behavior-change": "behavior change",
    "workflow ()": "workflow",
    "l-1-norm": "l1-norm",
    "big data/ machine learning": "big data/machine learning",
    "dataflow": "data flow",
    "multicriteria decision-making": "multi-criteria decision making",
    "recurrent neural networks": "recurrent neural network",
    "digital twins": "digital twin",
    "changepoints": "change point",
    "artificial neural networks": "artificial neural network",
}
# برای این شکل‌ها (اگر خودشان label نیستند) یک سطر label جدید ساخته می‌شود
ADD_LABEL = {"behavior-change", "l-1-norm", "big data/ machine learning", "dataflow",
             "multicriteria decision-making", "recurrent neural networks",
             "digital twins", "changepoints", "artificial neural networks"}

# ادغام‌های افراطی که از تزاروس برداشته می‌شوند (سطرشان حذف می‌شود).
# اگر نمی‌خواهید، این را خالی بگذارید:  DROP_LABELS = set()
DROP_LABELS = {"standards organization", "earnings management", "materials science",
               "arts", "arts education", "cads"}
# ======================================================

OUT_DIR.mkdir(parents=True, exist_ok=True)
print("پوشه خروجی:", OUT_DIR.resolve())
random.seed(SEED)
report_lines = []

HTML_DEL_KEY = "حذف با تگ HTML (نماد ریاضی؛ فقط بررسی کنید)"

INVISIBLE = re.compile(r"[\u200b-\u200f\u2060\ufeff\u202a-\u202e]")
MESH_CODE = re.compile(r"\[[a-z]\d[\d.]*\]?|\b[a-z]\d{2}(\.\d+)*\b", re.I)
HTML_ENTITY = re.compile(r"&#?\w*\d+;?|&(amp|nbsp|lt|gt|quot)\b;?", re.I)
HTML_TAG = re.compile(r"<\s*/?\s*[a-z][^>]*>?", re.I)
BAD_ENTITY = re.compile(r"&#?\d+|&(amp|nbsp|lt|gt|quot)\b", re.I)
BAD_TARGET = re.compile(
    r"&#?\d+|&(amp|nbsp|lt|gt|quot)\b|[<>\[\]]|^\s*(and|or|of)\b|^\s*[:,.)]|\b(msc|author-keyword)\b", re.I)

WARN_KEYS = {
    "وجود کوتیشن", "فاصله اضافه ابتدا/انتها", "فاصله دوتایی داخل عبارت",
    "label دارای نویسه نامرئی (اطلاع)", "label دارای HTML entity (اطلاع)",
    "مقصدهای هم‌خانواده (باید یکی شوند)",
    "حذف‌های دارای «and» (ممکن است معتبر باشند)",
    HTML_DEL_KEY,
}


def log(msg=""):
    print(msg)
    report_lines.append(str(msg))


def save_report():
    (OUT_DIR / "thesaurus_validation_report.txt").write_text(
        "\n".join(report_lines), encoding="utf-8")


def norm(s):
    return " ".join(s.lower().split())


def is_acronym(l, r):
    return l.replace(" ", "").replace("-", "") == "".join(w[0] for w in r.split() if w)


def fam_key(s):
    k = re.sub(r"[^a-z0-9]", "", s.lower())
    return re.sub(r"ies$", "y", k).rstrip("s")


def read_text(path):
    raw = path.read_bytes()
    for enc in ("utf-8-sig", "utf-16", "cp1252"):
        try:
            return raw.decode(enc), enc
        except UnicodeError:
            continue
    return None, None


# ---------------------------------------------------------------
# مرحله ۱: ساخت نسخه اصلاح‌شده (فایل اصلی دست نمی‌خورد)
# ---------------------------------------------------------------
def apply_fixes():
    text, enc = read_text(SRC)
    if text is None:
        raise RuntimeError(f"فایل اصلی خوانده نشد: {SRC}")
    lines = text.splitlines()
    out, labels, changes = [lines[0]], set(), []
    for line in lines[1:]:
        parts = line.split("\t")
        if len(parts) < 2:
            out.append(line)
            continue
        lab, rep = parts[0], parts[1].strip()
        if norm(lab) in DROP_LABELS:
            changes.append((lab, rep, "(سطر حذف شد)"))
            continue
        new = rep
        if re.search(r"q\s*</italic>\s*-learning", lab, re.I):
            new = "q-learning"
        elif rep:
            n = norm(rep)
            if BAD_ENTITY.search(rep) or n in DELETE_TARGETS:
                new = ""
            elif n in RETARGET:
                new = RETARGET[n]
        # سطری که بعد از اصلاح به خودش اشاره می‌کند بی‌معنی است
        if new and norm(new) == norm(lab):
            changes.append((lab[:60], rep, "(سطر خودارجاع حذف شد)"))
            continue
        if new != rep:
            changes.append((lab[:60], rep, new))
        labels.add(norm(lab))
        out.append(f"{lab}\t{new}")
    for old in sorted(ADD_LABEL):
        if old not in labels:
            out.append(f"{old}\t{RETARGET[old]}")
            changes.append((old, "(label جدید)", RETARGET[old]))
    DST.write_text("\n".join(out) + "\n", encoding="utf-8-sig")
    log(f"مرحله ۱: نسخه اصلاح‌شده ساخته شد ({len(changes)} تغییر): {DST}")
    for c in changes:
        log(f"     {c}")
    log("")


# ---------------------------------------------------------------
# مرحله ۲: اعتبارسنجی نسخه اصلاح‌شده
# ---------------------------------------------------------------
def validate():
    import pandas as pd
    path = DST
    text, enc_used = read_text(path)
    log(f"مرحله ۲: اعتبارسنجی فایل: {path}")
    log(f"encoding: {enc_used}")
    lines = text.splitlines()
    header = [h.strip() for h in lines[0].split("\t")]
    log(f"هدر: {header}")
    if [h.lower() for h in header[:2]] != ["label", "replace by"]:
        log("⚠ هدر باید دقیقاً 'label<TAB>replace by' باشد.")

    issues = defaultdict(list)
    pairs, deletions = [], []
    for i, line in enumerate(lines[1:], start=2):
        if not line.strip():
            issues["خط خالی"].append(i)
            continue
        parts = line.split("\t")
        if len(parts) < 2:
            issues["بدون تب / کمتر از ۲ ستون"].append((i, line))
            continue
        if len(parts) > 2:
            issues["بیش از ۲ ستون"].append((i, line))
        lab, rep = parts[0].strip(), parts[1].strip()
        if not lab:
            issues["label خالی"].append((i, line))
            continue
        if parts[0] != lab or parts[1] != rep:
            issues["فاصله اضافه ابتدا/انتها"].append((i, line))
        if "  " in lab or "  " in rep:
            issues["فاصله دوتایی داخل عبارت"].append((i, line))
        if '"' in lab or '"' in rep:
            issues["وجود کوتیشن"].append((i, line))
        if INVISIBLE.search(lab):
            issues["label دارای نویسه نامرئی (اطلاع)"].append((i, repr(lab)))
        if HTML_ENTITY.search(lab):
            issues["label دارای HTML entity (اطلاع)"].append((i, lab))
        if not rep:
            deletions.append((i, lab))
            continue
        if INVISIBLE.search(rep):
            issues["مقصد دارای نویسه نامرئی"].append((i, repr(rep)))
        if MESH_CODE.search(rep):
            issues["مقصد دارای کد (مثل MeSH)"].append((i, rep))
        if HTML_ENTITY.search(rep):
            issues["مقصد دارای HTML entity"].append((i, rep))
        if HTML_TAG.search(rep):
            issues["مقصد دارای تگ HTML"].append((i, rep))
        pairs.append((i, lab, rep))

    mapping, original, label_counts = defaultdict(set), {}, Counter()
    for i, lab, rep in pairs:
        nl, nr = norm(lab), norm(rep)
        mapping[nl].add(nr)
        label_counts[nl] += 1
        original.setdefault(nl, (lab, rep))
    for nl, reps in mapping.items():
        if len(reps) > 1:
            issues["یک label با چند مقصد متفاوت"].append((nl, sorted(reps)))
    dups = [k for k, c in label_counts.items() if c > 1 and len(mapping[k]) == 1]
    if dups:
        issues["label تکراری (با مقصد یکسان)"] = dups

    single = {k: next(iter(v)) for k, v in mapping.items() if len(v) == 1}
    targets = set(single.values())
    issues["خودارجاع (A→A)"] = [k for k, v in single.items() if k == v]

    chains, cycles, seen = [], [], set()
    for k in single:
        nodes, cur = [k], single[k]
        while cur in single and single[cur] != cur:
            if cur in nodes:
                key = frozenset(nodes)
                if key not in seen:
                    seen.add(key)
                    cycles.append(nodes + [cur])
                break
            nodes.append(cur)
            cur = single[cur]
        else:
            if len(nodes) > 1:
                chains.append(nodes + [cur])
    issues["زنجیره (مقصد خودش label است)"] = chains
    issues["حلقه"] = cycles

    del_norm = [norm(l) for _, l in deletions]
    del_set = set(del_norm)
    issues["ورودی حذف تکراری"] = [k for k, c in Counter(del_norm).items() if c > 1]
    issues["label هم حذف شده هم جایگزین"] = sorted(del_set & set(single))
    issues["مقصد جایگزینی در فهرست حذف است (کل گروه حذف می‌شود)"] = sorted(targets & del_set)
    issues[HTML_DEL_KEY] = [l for _, l in deletions if HTML_TAG.search(l)]
    issues["حذف‌های دارای «and» (ممکن است معتبر باشند)"] = [
        l for _, l in deletions if re.search(r"\band\b", l, re.I) and len(l.split()) >= 3]

    for nl in single:
        t = original[nl][1]
        if BAD_TARGET.search(t) or t.count("(") != t.count(")"):
            issues["مقصد مشکوک (قطعه/کد/entity/پرانتز ناقص)"].append((nl, t))
    fam = defaultdict(set)
    for t in targets:
        fam[fam_key(t)].add(t)
    issues["مقصدهای هم‌خانواده (باید یکی شوند)"] = [sorted(v) for v in fam.values() if len(v) > 1]

    log("")
    log(f"جایگزینی‌ها: {len(pairs)} | label یکتا: {len(single)} | مقصد یکتا: {len(targets)}")
    log(f"ورودی‌های حذف: {len(deletions)} | یکتا: {len(del_set)}")
    log("=" * 60)
    has_error = False
    for k, v in issues.items():
        if not v:
            continue
        warn = k in WARN_KEYS
        has_error = has_error or not warn
        log(f"{'⚠' if warn else '❌'} {k}: {len(v)} مورد")
        for item in v[:10]:
            log(f"     {item}")
        if len(v) > 10:
            log(f"     ... و {len(v) - 10} مورد دیگر (همه در شیت issues فایل Excel)")
    log("✅ هیچ خطای فنی پیدا نشد (هشدارها را بررسی کنید)." if not has_error
        else "\n❌ موارد بالا باقی مانده‌اند؛ گزارش را بفرستید.")
    save_report()

    # ---------- Excel ----------
    issue_rows = [{"category": k, "severity": "warning" if k in WARN_KEYS else "error",
                   "detail": str(it), "fixed": ""} for k, v in issues.items() for it in v]
    rows = []
    for nl, nr in single.items():
        if nl != nr:
            lab, rep = original[nl]
            rows.append({"label": lab, "replace_by": rep, "_nl": nl, "_nr": nr})
    df = pd.DataFrame(rows)
    out = OUT_DIR / "thesaurus_review_sample.xlsx"
    with pd.ExcelWriter(out, engine="openpyxl") as w:
        pd.DataFrame({
            "item": ["file checked", "replacements", "unique labels", "unique targets", "deletions"],
            "value": [str(path), len(pairs), len(single), len(targets), len(deletions)],
        }).to_excel(w, sheet_name="summary", index=False)
        if issue_rows:
            pd.DataFrame(issue_rows).to_excel(w, sheet_name="issues", index=False)
        if not df.empty:
            df["group_size"] = df.groupby("_nr")["label"].transform("count")
            df["similarity"] = [round(difflib.SequenceMatcher(None, a, b).ratio(), 2)
                                for a, b in zip(df["_nl"], df["_nr"])]
            df["is_acronym"] = [is_acronym(a, b) for a, b in zip(df["_nl"], df["_nr"])]
            big = df[df.group_size >= BIG_GROUP_MIN].sort_values(
                ["group_size", "replace_by"], ascending=[False, True])
            sus = df[(df.similarity < SIM_THRESHOLD) & (~df.is_acronym)].sort_values("similarity")
            rest = df[~df.index.isin(big.index) & ~df.index.isin(sus.index)]
            rnd = rest.sample(min(SAMPLE_SIZE, len(rest)), random_state=SEED)
            drop = ["_nl", "_nr"]
            big.drop(columns=drop).assign(judgement="").to_excel(w, sheet_name="big_groups", index=False)
            sus.drop(columns=drop).assign(judgement="").to_excel(w, sheet_name="low_similarity", index=False)
            rnd.drop(columns=drop).assign(judgement="").to_excel(w, sheet_name="random_sample", index=False)
        if deletions:
            ddf = pd.DataFrame({"deleted_label": [l for _, l in deletions]})
            ddf["has_and"] = ddf.deleted_label.str.contains(r"\band\b", case=False, regex=True)
            ddf[["deleted_label"]].sample(min(DELETE_SAMPLE_SIZE, len(ddf)), random_state=SEED) \
                .assign(judgement="").to_excel(w, sheet_name="deleted_sample", index=False)
            ddf.to_excel(w, sheet_name="deleted_all", index=False)
    print("\nهمه خروجی‌ها در این پوشه ذخیره شد:", OUT_DIR.resolve())


try:
    apply_fixes()
    validate()
except Exception:
    err = traceback.format_exc()
    print("\n❌ خطا رخ داد:\n", err)
    (OUT_DIR / "error_log.txt").write_text(err, encoding="utf-8")