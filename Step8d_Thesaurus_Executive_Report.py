# -*- coding: utf-8 -*-
"""
Step 8d - آمار توصیفی تزاروس نهایی VOSviewer + فراوانی و هم‌رخدادی کلیدواژه‌ها
خروجی‌ها در پوشه step8d ذخیره می‌شوند.

اجرا:
    python step8d_thesaurus_stats.py
یا با مسیر دلخواه:
    python step8d_thesaurus_stats.py --records "D:\\Thesis\\Data\\merged.csv"

نیازمندی‌ها: pandas, numpy, openpyxl, (اختیاری) matplotlib
"""
import os, re, csv, glob, argparse, itertools
from collections import Counter
import numpy as np
import pandas as pd

# ============================== تنظیمات ==============================
THESAURUS_DIR  = r"D:\Thesis\Thesaurus\validation_output"
THESAURUS_NAME = "vosviewer_final_thesaurus_fixed"        # با/بدون پسوند
RECORDS_PATH   = r"D:\Thesis\Data\merged_dataset.csv"     # <<< مسیر فایل رکوردهای ادغام‌شده را اصلاح کنید
OUT_DIR        = os.path.join(THESAURUS_DIR, "step8d")

KEYWORD_COLS   = ["Author Keywords", "Index Keywords", "DE", "ID"]   # هر کدام که در فایل بود استفاده می‌شود
KEYWORD_SEP    = ";"
YEAR_COLS      = ["Year", "PY", "Publication Year"]

MIN_KW_FREQ_FOR_COOC = 2      # فقط کلیدواژه‌هایی با حداقل این فراوانی وارد هم‌رخدادی شوند
MIN_COOC_EDGE        = 2      # حداقل هم‌رخدادی برای ثبت یک جفت
TOP_N_MATRIX         = 50     # ابعاد ماتریس هم‌رخدادی در اکسل
EXCEL_MAX_PAIRS      = 50000  # سقف جفت‌ها در شیت اکسل (کل جفت‌ها در CSV ذخیره می‌شود)
TOP_N_YEAR           = 20     # تعداد کلیدواژه‌های برتر برای جدول سالانه
# ======================================================================


def norm(s):
    """نرمال‌سازی مشابه VOSviewer: حذف فاصله‌های اضافه و کوچک‌سازی حروف"""
    return re.sub(r"\s+", " ", str(s)).strip().lower()


def find_thesaurus(folder, name):
    p = os.path.join(folder, name)
    if os.path.isfile(p):
        return p
    for ext in (".txt", ".tsv", ".csv", ".xlsx"):
        if os.path.isfile(p + ext):
            return p + ext
    hits = glob.glob(os.path.join(folder, name + "*"))
    if hits:
        return hits[0]
    raise FileNotFoundError(f"Thesaurus file not found: {p}[.txt/.csv/.xlsx]")


def read_table(path):
    ext = os.path.splitext(path)[1].lower()
    if ext in (".xlsx", ".xls"):
        return pd.read_excel(path, dtype=str).fillna("")
    last = None
    for enc in ("utf-8-sig", "utf-8", "cp1252", "latin-1"):
        try:
            with open(path, "r", encoding=enc) as f:
                header = f.readline()
            sep = "\t" if "\t" in header else (";" if header.count(";") > header.count(",") else ",")
            kw = dict(quoting=csv.QUOTE_NONE) if sep == "\t" else {}
            return pd.read_csv(path, sep=sep, dtype=str, encoding=enc,
                               keep_default_na=False, **kw)
        except Exception as e:
            last = e
    raise last


def load_thesaurus(path):
    raw = read_table(path)
    cols = {c: str(c).strip().lower() for c in raw.columns}
    lab = next((c for c, l in cols.items() if "label" in l), raw.columns[0])
    rep = next((c for c, l in cols.items() if "replace" in l), None)
    if rep is None:
        rep = raw.columns[1] if raw.shape[1] > 1 else None
    th = pd.DataFrame({"label_raw": raw[lab].astype(str)})
    th["replace_raw"] = raw[rep].astype(str) if rep is not None else ""
    th["label"] = th["label_raw"].map(norm)
    th["replace"] = th["replace_raw"].map(norm)
    th = th[th["label"] != ""].reset_index(drop=True)
    return th


def resolve(k, m):
    """دنبال کردن زنجیره جایگزینی؛ خروجی: (نتیجه نهایی، تعداد گام، وضعیت)"""
    seen, cur, hops = [k], k, 0
    while True:
        nxt = m.get(cur)
        if nxt is None:
            return cur, hops, ("identity" if hops == 0 else ("direct" if hops == 1 else "chain"))
        if nxt == "":
            return "", hops + 1, "deleted"
        if nxt == cur:
            return cur, hops, "identity" if hops == 0 else ("direct" if hops == 1 else "chain")
        if nxt in seen:
            return cur, hops, "cycle"
        seen.append(nxt)
        cur, hops = nxt, hops + 1


def length_stats(series, name):
    s = series[series != ""]
    chars, words = s.str.len(), s.str.split().str.len()
    rows = []
    for lab, x in (("chars", chars), ("words", words)):
        if len(x):
            rows.append([f"{name} - {lab}", len(x), x.min(), x.max(), round(x.mean(), 2),
                         x.median(), round(x.std(ddof=0), 2)])
    return rows


def save_excel(path, sheets):
    with pd.ExcelWriter(path, engine="openpyxl") as xw:
        for name, df in sheets.items():
            df.to_excel(xw, sheet_name=name[:31], index=False)
            ws = xw.sheets[name[:31]]
            ws.freeze_panes = "A2"
            for i, col in enumerate(df.columns, 1):
                vals = df[col].astype(str).head(500)
                w = max([len(str(col))] + [len(v) for v in vals]) + 2
                ws.column_dimensions[ws.cell(1, i).column_letter].width = min(w, 60)


# ============================ آمار تزاروس ============================
def thesaurus_stats(th):
    sheets = {}
    n = len(th)
    exact_dup = int(th.duplicated(["label", "replace"]).sum())
    g = th.groupby("label")["replace"].nunique()
    conflict_labels = g[g > 1].index
    conflicts = th[th["label"].isin(conflict_labels)].sort_values("label")[["label_raw", "replace_raw"]]

    # نگاشت (در صورت تعارض، اولین مورد معتبر است)
    m = {}
    for l, r in zip(th["label"], th["replace"]):
        m.setdefault(l, r)

    res = [(l,) + resolve(l, m) for l in m]
    rdf = pd.DataFrame(res, columns=["label", "final", "hops", "status"])
    final_map = dict(zip(rdf["label"], rdf["final"]))

    # گروه‌بندی بر اساس اصطلاح نهایی
    ok = rdf[rdf["final"] != ""]
    grp = ok[ok["label"] != ok["final"]].groupby("final")["label"].agg(["count", lambda x: "; ".join(list(x)[:8])])
    grp.columns = ["n_variants", "example_variants"]
    grp = grp.sort_values("n_variants", ascending=False).reset_index().rename(columns={"final": "canonical_term"})

    bins = pd.cut(grp["n_variants"], [0, 1, 2, 3, 5, 10, 20, 50, 10**9],
                  labels=["1", "2", "3", "4-5", "6-10", "11-20", "21-50", ">50"])
    dist = bins.value_counts().sort_index().rename_axis("variants_per_canonical").reset_index(name="n_canonical_terms")
    dist["percent"] = (dist["n_canonical_terms"] / max(dist["n_canonical_terms"].sum(), 1) * 100).round(2)

    # مشکلات قالب‌بندی
    fmt = []
    for lab, ser in (("label", th["label_raw"]), ("replace by", th["replace_raw"])):
        fmt += [
            [lab, "leading/trailing space", int((ser != ser.str.strip()).sum())],
            [lab, "double spaces", int(ser.str.contains(r"\s{2,}", regex=True).sum())],
            [lab, "contains uppercase", int(ser.str.contains(r"[A-Z]", regex=True).sum())],
            [lab, "contains non-ASCII", int(ser.map(lambda x: any(ord(c) > 127 for c in x)).sum())],
            [lab, "contains digits", int(ser.str.contains(r"\d", regex=True).sum())],
            [lab, "contains hyphen", int(ser.str.contains("-", regex=False).sum())],
            [lab, "contains parentheses", int(ser.str.contains(r"[()]", regex=True).sum())],
            [lab, "contains other punctuation (, . ; : / & ' \" )", int(ser.str.contains(r"[,.;:/&'\"]", regex=True).sum())],
        ]
    fmt = pd.DataFrame(fmt, columns=["column", "check", "n_rows"])

    lens = pd.DataFrame(length_stats(th["label"], "label") + length_stats(th["replace"], "replace by"),
                        columns=["field", "n", "min", "max", "mean", "median", "std"])

    status_counts = rdf["status"].value_counts()
    summary = pd.DataFrame([
        ["Total rows (thesaurus lines)", n],
        ["Unique labels (normalized)", th["label"].nunique()],
        ["Unique 'replace by' terms (non-empty)", th.loc[th["replace"] != "", "replace"].nunique()],
        ["Unique final canonical terms (after chain resolution)", int((ok["final"]).nunique())],
        ["Exact duplicate rows", exact_dup],
        ["Labels with conflicting replacements", len(conflict_labels)],
        ["Identity rows (label == replace by)", int((th["label"] == th["replace"]).sum())],
        ["Deletion rows (empty 'replace by')", int((th["replace"] == "").sum())],
        ["Direct mappings (1 hop)", int(status_counts.get("direct", 0))],
        ["Chained mappings (>1 hop)", int(status_counts.get("chain", 0))],
        ["Cyclic mappings", int(status_counts.get("cycle", 0))],
        ["Mean variants per canonical term", round(grp["n_variants"].mean(), 2) if len(grp) else 0],
        ["Max variants for one canonical term", int(grp["n_variants"].max()) if len(grp) else 0],
        ["Canonical terms with exactly 1 variant", int((grp["n_variants"] == 1).sum())],
    ], columns=["metric", "value"])

    sheets["Thesaurus_Summary"] = summary
    sheets["Variants_Distribution"] = dist
    sheets["Top_Canonical_Terms"] = grp.head(200)
    sheets["Length_Stats"] = lens
    sheets["Format_Checks"] = fmt
    sheets["Chains_Cycles"] = rdf[rdf["status"].isin(["chain", "cycle"])].sort_values("hops", ascending=False)
    sheets["Conflicts"] = conflicts
    sheets["Deleted_Terms"] = th.loc[th["replace"] == "", ["label_raw"]]
    return sheets, final_map, grp, dist


# ======================= فراوانی و هم‌رخدادی ========================
def load_records(path):
    ext = os.path.splitext(path)[1].lower()
    if ext in (".xlsx", ".xls"):
        return pd.read_excel(path, dtype=str).fillna("")
    return read_table(path)


def parse_keywords(df):
    cols = [c for c in KEYWORD_COLS if c in df.columns]
    if not cols:
        raise ValueError(f"هیچ‌کدام از ستون‌های کلیدواژه {KEYWORD_COLS} در فایل رکوردها نیست. ستون‌ها: {list(df.columns)[:30]}")
    recs = []
    for _, row in df[cols].iterrows():
        kws = []
        for c in cols:
            v = row[c]
            if isinstance(v, str) and v.strip():
                kws += [norm(x) for x in v.split(KEYWORD_SEP)]
        recs.append([k for k in kws if k])
    return recs, cols


def keyword_analysis(df, final_map, th_labels, th_finals, sheets, out_dir):
    raw_recs, used_cols = parse_keywords(df)
    N = len(raw_recs)

    after_recs, deleted_occ, matched_occ = [], 0, 0
    variant_sets = {}
    for kws in raw_recs:
        out = []
        for k in set(kws):
            if k in final_map:
                f = final_map[k]
                matched_occ += 1
            else:
                f = k
            if f == "":
                deleted_occ += 1
                continue
            out.append(f)
            variant_sets.setdefault(f, set()).add(k)
        after_recs.append(sorted(set(out)))

    before_cnt = Counter(k for kws in raw_recs for k in set(kws))
    after_cnt = Counter(k for kws in after_recs for k in kws)
    occ_before, occ_after = sum(before_cnt.values()), sum(after_cnt.values())
    per_before = pd.Series([len(set(k)) for k in raw_recs])
    per_after = pd.Series([len(k) for k in after_recs])

    rs = pd.DataFrame([
        ["Number of records", N],
        ["Keyword columns used", ", ".join(used_cols)],
        ["Records with no keywords (before)", int((per_before == 0).sum())],
        ["Records with no keywords (after thesaurus)", int((per_after == 0).sum())],
        ["Unique keywords BEFORE thesaurus", len(before_cnt)],
        ["Unique keywords AFTER thesaurus", len(after_cnt)],
        ["Reduction in unique keywords (%)", round((1 - len(after_cnt) / max(len(before_cnt), 1)) * 100, 2)],
        ["Keyword occurrences BEFORE", occ_before],
        ["Keyword occurrences AFTER", occ_after],
        ["Occurrences matched by thesaurus labels", matched_occ],
        ["Coverage of occurrences by thesaurus (%)", round(matched_occ / max(occ_before, 1) * 100, 2)],
        ["Occurrences deleted by thesaurus", deleted_occ],
        ["Mean keywords per record (before)", round(per_before.mean(), 2)],
        ["Mean keywords per record (after)", round(per_after.mean(), 2)],
        ["Median keywords per record (after)", per_after.median()],
        ["Max keywords per record (after)", int(per_after.max())],
        ["Keywords with freq = 1 (after)", sum(1 for v in after_cnt.values() if v == 1)],
        ["Keywords with freq >= 5 (after)", sum(1 for v in after_cnt.values() if v >= 5)],
        ["Keywords with freq >= 10 (after)", sum(1 for v in after_cnt.values() if v >= 10)],
        ["Keywords with freq >= 20 (after)", sum(1 for v in after_cnt.values() if v >= 20)],
    ], columns=["metric", "value"])

    freq = pd.DataFrame({"keyword": list(after_cnt), "doc_freq": list(after_cnt.values())})
    freq["percent_of_records"] = (freq["doc_freq"] / N * 100).round(3)
    freq["n_raw_variants_merged"] = freq["keyword"].map(lambda k: len(variant_sets.get(k, ())))
    freq["is_thesaurus_canonical"] = freq["keyword"].isin(th_finals)
    freq = freq.sort_values(["doc_freq", "keyword"], ascending=[False, True]).reset_index(drop=True)
    freq.insert(0, "rank", freq.index + 1)

    unmatched = freq[~freq["keyword"].isin(th_labels) & ~freq["is_thesaurus_canonical"]].head(300)

    pdist = pd.DataFrame({"keywords_per_record": per_after.value_counts().sort_index().index,
                          "n_records": per_after.value_counts().sort_index().values})

    # ---- هم‌رخدادی ----
    keep = {k for k, v in after_cnt.items() if v >= MIN_KW_FREQ_FOR_COOC}
    pc = Counter()
    for kws in after_recs:
        u = [k for k in kws if k in keep]
        if len(u) > 1:
            pc.update(itertools.combinations(u, 2))     # kws از قبل مرتب است

    pairs = pd.DataFrame([(a, b, c) for (a, b), c in pc.items() if c >= MIN_COOC_EDGE],
                         columns=["keyword_1", "keyword_2", "cooccurrence"])
    if len(pairs):
        f1 = pairs["keyword_1"].map(after_cnt)
        f2 = pairs["keyword_2"].map(after_cnt)
        pairs["freq_1"], pairs["freq_2"] = f1, f2
        pairs["jaccard"] = (pairs["cooccurrence"] / (f1 + f2 - pairs["cooccurrence"])).round(4)
        pairs["association_strength"] = (pairs["cooccurrence"] / (f1 * f2)).round(6)   # s_ij = c_ij / (w_i*w_j)
        pairs["lift"] = (pairs["cooccurrence"] * N / (f1 * f2)).round(3)
        pairs = pairs.sort_values("cooccurrence", ascending=False).reset_index(drop=True)

    # ماتریس هم‌رخدادی برای برترین کلیدواژه‌ها
    top = list(freq["keyword"].head(TOP_N_MATRIX))
    mat = pd.DataFrame(0, index=top, columns=top, dtype=int)
    for i, a in enumerate(top):
        mat.loc[a, a] = after_cnt[a]
        for b in top[i + 1:]:
            key = (a, b) if a < b else (b, a)
            v = pc.get(key, 0)
            mat.loc[a, b] = v
            mat.loc[b, a] = v
    mat = mat.reset_index().rename(columns={"index": "keyword"})

    # ---- سال ----
    ycol = next((c for c in YEAR_COLS if c in df.columns), None)
    if ycol:
        years = pd.to_numeric(df[ycol], errors="coerce").values
        yrs = pd.DataFrame({"year": years, "n_kw": per_after.values})
        ytab = yrs.dropna().groupby("year").agg(n_records=("n_kw", "size"), mean_kw_per_record=("n_kw", "mean"))
        ytab["mean_kw_per_record"] = ytab["mean_kw_per_record"].round(2)
        uniq = {}
        for y, kws in zip(years, after_recs):
            if not np.isnan(y):
                uniq.setdefault(int(y), set()).update(kws)
        ytab["unique_keywords"] = [len(uniq.get(int(y), ())) for y in ytab.index]
        ytab = ytab.reset_index()
        ytab["year"] = ytab["year"].astype(int)
        topk = list(freq["keyword"].head(TOP_N_YEAR))
        piv = Counter()
        for y, kws in zip(years, after_recs):
            if not np.isnan(y):
                for k in kws:
                    if k in topk:
                        piv[(k, int(y))] += 1
        pv = pd.DataFrame([(k, y, c) for (k, y), c in piv.items()], columns=["keyword", "year", "n"])
        pv = pv.pivot_table(index="keyword", columns="year", values="n", fill_value=0).reindex(topk).reset_index()
        sheets["Records_per_Year"] = ytab
        sheets["TopKeywords_by_Year"] = pv

    sheets["Records_Keyword_Summary"] = rs
    sheets["Keyword_Freq_Top200"] = freq.head(200)
    sheets["Keywords_per_Record"] = pdist
    sheets["Unmatched_Top300"] = unmatched
    sheets["Cooc_Pairs_Top"] = pairs.head(EXCEL_MAX_PAIRS)
    sheets["Cooc_Matrix_TopN"] = mat

    # ---- فایل‌های CSV (کامل) ----
    freq.to_csv(os.path.join(out_dir, "keyword_frequencies_all.csv"), index=False, encoding="utf-8-sig")
    pairs.to_csv(os.path.join(out_dir, "cooccurrence_pairs_all.csv"), index=False, encoding="utf-8-sig")
    if len(pairs):   # قالب آماده Gephi
        pairs[["keyword_1", "keyword_2", "cooccurrence"]].rename(
            columns={"keyword_1": "Source", "keyword_2": "Target", "cooccurrence": "Weight"}
        ).assign(Type="Undirected").to_csv(os.path.join(out_dir, "gephi_edges.csv"), index=False, encoding="utf-8-sig")
        nodes = freq[freq["keyword"].isin(keep)][["keyword", "doc_freq"]].rename(columns={"keyword": "Id", "doc_freq": "Weight"})
        nodes.assign(Label=nodes["Id"]).to_csv(os.path.join(out_dir, "gephi_nodes.csv"), index=False, encoding="utf-8-sig")
    return freq, pairs, dist_placeholder if False else None


def make_plots(out_dir, grp, dist, freq):
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except Exception:
        print("matplotlib نصب نیست؛ نمودارها ساخته نشد.")
        return
    if len(dist):
        plt.figure(figsize=(8, 4.5))
        plt.bar(dist["variants_per_canonical"].astype(str), dist["n_canonical_terms"], color="#3b6ea5")
        plt.xlabel("Variants per canonical term"); plt.ylabel("Number of canonical terms")
        plt.title("Distribution of thesaurus group sizes"); plt.tight_layout()
        plt.savefig(os.path.join(out_dir, "fig_variants_distribution.png"), dpi=200); plt.close()
    if freq is not None and len(freq):
        t = freq.head(20).iloc[::-1]
        plt.figure(figsize=(8, 7))
        plt.barh(t["keyword"], t["doc_freq"], color="#2e8b57")
        plt.xlabel("Number of records"); plt.title("Top 20 keywords (after thesaurus)")
        plt.tight_layout()
        plt.savefig(os.path.join(out_dir, "fig_top20_keywords.png"), dpi=200); plt.close()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--thesaurus_dir", default=THESAURUS_DIR)
    ap.add_argument("--thesaurus_name", default=THESAURUS_NAME)
    ap.add_argument("--records", default=RECORDS_PATH)
    ap.add_argument("--out", default=None)
    a = ap.parse_args()

    out_dir = a.out or os.path.join(a.thesaurus_dir, "step8d")
    os.makedirs(out_dir, exist_ok=True)

    tpath = find_thesaurus(a.thesaurus_dir, a.thesaurus_name)
    print("Thesaurus:", tpath)
    th = load_thesaurus(tpath)
    sheets, final_map, grp, dist = thesaurus_stats(th)
    th_labels = set(final_map)
    th_finals = {v for v in final_map.values() if v}

    freq = None
    if a.records and os.path.isfile(a.records):
        print("Records  :", a.records)
        df = load_records(a.records)
        freq = keyword_analysis(df, final_map, th_labels, th_finals, sheets, out_dir)[0]
    else:
        print(f"[هشدار] فایل رکوردها پیدا نشد ({a.records}). فقط آمار تزاروس تهیه شد؛ "
              f"برای فراوانی/هم‌رخدادی مسیر RECORDS_PATH را اصلاح کنید.")

    xlsx = os.path.join(out_dir, "step8d_thesaurus_stats_report.xlsx")
    save_excel(xlsx, sheets)
    make_plots(out_dir, grp, dist, freq)
    print("\nDone. Output folder:", out_dir)
    for f in sorted(os.listdir(out_dir)):
        print("  -", f)


if __name__ == "__main__":
    main()