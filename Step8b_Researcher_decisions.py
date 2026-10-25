# ============================================================
# Apply Researcher Decisions & Re-Resolve Thesaurus Chains/Loops
# Inputs: Existing Thesaurus + Researcher_decisions (.txt / .csv)
# Outputs: Updated .txt (VOSviewer), .csv (Excel), report.txt
# ============================================================

import os
import pandas as pd
from datetime import datetime

# ================= 1. تنظیمات مسیرها =================
base_dir = r"D:\Thesis\thesaurus"
output_dir = os.path.join(base_dir, "final_vosviewer_thesaurus")

previous_txt_path = os.path.join(output_dir, "vosviewer_final_thesaurus.txt")

final_txt_path = os.path.join(output_dir, "vosviewer_final_thesaurus.txt")
final_csv_path = os.path.join(output_dir, "vosviewer_final_thesaurus.csv")
report_path = os.path.join(output_dir, "updated_integration_report.txt")

# ================= 2. خواندن تزاروس قبلی =================
print("=" * 70)
print("📂 [گام ۱] در حال خواندن تزاروس قبلی...")
print("=" * 70)

combined_mappings = {}

if os.path.exists(previous_txt_path):
    prev_df = pd.read_csv(previous_txt_path, sep='\t', encoding='utf-8', keep_default_na=False)
    prev_df.columns = prev_df.columns.astype(str).str.strip().str.lower()
    
    lbl_col = prev_df.columns[0]
    rep_col = prev_df.columns[1]
    
    for _, row in prev_df.iterrows():
        lbl = str(row[lbl_col]).strip().lower()
        rep = str(row[rep_col]).strip().lower()
        if lbl:
            combined_mappings[lbl] = rep
    print(f"  🔹 تعداد {len(combined_mappings)} رکورد از تزاروس قبلی بارگذاری شد.")
else:
    print("  ❌ فایل تزاروس قبلی یافت نشد! لطفاً مسیر را بررسی کنید.")

# ================= 3. خواندن فایل تصمیمات پژوهشگر =================
print("\n" + "=" * 70)
print("🔍 [گام ۲] در حال خواندن فایل Researcher_decisions...")
print("=" * 70)

decisions_file = None
for fname in ["Researcher_decisions.txt", "Researcher_decisions.csv"]:
    fpath = os.path.join(output_dir, fname)
    if os.path.exists(fpath):
        decisions_file = fpath
        break

decisions_added_count = 0
decisions_overwritten_count = 0

if decisions_file:
    print(f"  📄 فایل تصمیمات یافت شد: {os.path.basename(decisions_file)}")
    
    sep = '\t' if decisions_file.endswith('.txt') else ','
    try:
        dec_df = pd.read_csv(decisions_file, sep=sep, encoding='utf-8-sig', keep_default_na=False)
    except:
        dec_df = pd.read_csv(decisions_file, sep=None, engine='python', encoding='utf-8-sig', keep_default_na=False)
        
    dec_df.columns = dec_df.columns.astype(str).str.strip().str.lower()
    
    lbl_c = dec_df.columns[0]
    rep_c = dec_df.columns[1] if len(dec_df.columns) > 1 else dec_df.columns[0]
    
    for _, row in dec_df.iterrows():
        lbl = str(row[lbl_c]).strip().lower()
        rep = str(row[rep_c]).strip().lower() if len(dec_df.columns) > 1 else ""
        
        if ';' in rep:
            rep = rep.split(';')[0].strip()
            
        if rep in ['nan', 'none', 'remove', 'delete', 'drop']:
            rep = ""
            
        if lbl:
            if lbl in combined_mappings:
                decisions_overwritten_count += 1
            else:
                decisions_added_count += 1
            
            # تصمیم جدید پژوهشگر جایگزین نگاشت قبلی می‌شود
            combined_mappings[lbl] = rep

    print(f"  🔹 نگاشت‌های جدید اضافه شده: {decisions_added_count}")
    print(f"  🔹 نگاشت‌های قبلی به‌روزرسانی شده: {decisions_overwritten_count}")
else:
    print("  ⚠️ فایل Researcher_decisions.txt یا Researcher_decisions.csv در پوشه پیدا نشد!")

# ================= 4. حل مجدد زنجیره‌ها و حلقه‌ها =================
print("\n" + "=" * 70)
print("🔄 [گام ۳] حل مجدد زنجیره‌ها و حلقه‌های تکراری پس از اعمال تصمیمات...")
print("=" * 70)

# جداسازی حذفیات و ادغام‌ها برای الگوریتم زنجیره
merges_dict = {k: v for k, v in combined_mappings.items() if v != ""}
removals_set = {k for k, v in combined_mappings.items() if v == ""}

resolved_merges = {}
chain_count = 0
cycle_count = 0

def trace_target(node, mapping_dict, visited=None):
    global chain_count, cycle_count
    if visited is None:
        visited = []
    
    if node in visited:
        cycle_count += 1
        return node
    
    visited.append(node)
    
    if node in mapping_dict:
        chain_count += 1
        return trace_target(mapping_dict[node], mapping_dict, visited)
    else:
        return node

for label, replace in merges_dict.items():
    final_target = trace_target(replace, merges_dict)
    if label != final_target:
        resolved_merges[label] = final_target
    else:
        resolved_merges[label] = replace

# ترکیب نهایی ادغام‌های حل‌شده و حذفیات
final_thesaurus_dict = {}

for lbl, rep in resolved_merges.items():
    final_thesaurus_dict[lbl] = rep

actual_removals_count = 0
for removal_kw in removals_set:
    if removal_kw not in final_thesaurus_dict:
        final_thesaurus_dict[removal_kw] = ""
        actual_removals_count += 1

# پاک‌سازی تداخل احتمالی بین ستون‌ها
labels = set(final_thesaurus_dict.keys())
replaces = set(val for val in final_thesaurus_dict.values() if val != "")
intersection = labels.intersection(replaces)

if intersection:
    for item in list(intersection):
        if item in final_thesaurus_dict:
            del final_thesaurus_dict[item]

# ================= 5. ذخیره خروجی‌های نهایی =================
final_df = pd.DataFrame(list(final_thesaurus_dict.items()), columns=['label', 'replace by'])

# ذخیره TXT (برای VOSviewer)
final_df.to_csv(final_txt_path, sep='\t', index=False, encoding='utf-8')

# ذخیره CSV (برای بررسی اکسل)
final_df.to_csv(final_csv_path, index=False, encoding='utf-8-sig')

# ================= 6. تولید فایل گزارش به‌روزرسانی =================
with open(report_path, 'w', encoding='utf-8') as f:
    f.write("=" * 85 + "\n")
    f.write("UPDATED THESAURUS AUDIT REPORT (AFTER RESEARCHER DECISIONS)\n")
    f.write("=" * 85 + "\n\n")
    f.write(f"Execution Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
    f.write(f"Applied Decisions File: {decisions_file if decisions_file else 'None'}\n\n")
    
    f.write("1. RESEARCHER DECISIONS IMPACT\n")
    f.write("-" * 85 + "\n")
    f.write(f"New Mappings Added            : {decisions_added_count}\n")
    f.write(f"Existing Mappings Overwritten : {decisions_overwritten_count}\n")
    f.write("-" * 85 + "\n\n")
    
    f.write("2. RE-RESOLUTION METRICS\n")
    f.write("-" * 85 + "\n")
    f.write(f"Transitive Chains Resolved (A->B->C): {chain_count}\n")
    f.write(f"Circular Loops Broken (A->B->A)   : {cycle_count}\n")
    f.write(f"Overlap Column Fixes              : {len(intersection)}\n")
    f.write(f"Total Merge/Replace Records       : {len([v for v in final_thesaurus_dict.values() if v != ''])}\n")
    f.write(f"Total Removal Records (Empty rep) : {actual_removals_count}\n")
    f.write(f"GRAND TOTAL RECORDS IN THESAURUS  : {len(final_df)}\n")
    f.write("=" * 85 + "\n")

print("\n" + "=" * 70)
print("✨ فایل‌های تزاروس با تصمیمات جدید پژوهشگر بروزرسانی شدند!")
print(f"📄 فایل VOSviewer (TXT): {final_txt_path}")
print(f"📊 فایل اکسل (CSV)     : {final_csv_path}")
print(f"📝 فایل گزارش جدید     : {report_path}")
print("=" * 70)