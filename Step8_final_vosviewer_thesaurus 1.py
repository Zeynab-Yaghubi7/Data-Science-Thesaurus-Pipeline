# ============================================================
# Advanced Consolidated VOSviewer Thesaurus Builder
# Supports: Merges/Replacements AND Removals (Empty replace_by)
# Outputs: .txt (VOSviewer), .csv (Excel), report.txt (Audit Log)
# ============================================================

import os
import pandas as pd
from datetime import datetime

# ================= 1. تنظیمات مسیرها =================
base_dir = r"D:\Thesis\thesaurus"

output_dir = os.path.join(base_dir, "final_vosviewer_thesaurus")
os.makedirs(output_dir, exist_ok=True)

final_txt_path = os.path.join(output_dir, "vosviewer_final_thesaurus.txt")
final_csv_path = os.path.join(output_dir, "vosviewer_final_thesaurus.csv")
report_path = os.path.join(output_dir, "thesaurus_integration_report.txt")

# ================= 2. خواندن هوشمند فایل‌ها =================
print("=" * 70)
print("📂 [گام ۱] در حال خواندن فایل‌ها (شامل ادغام‌ها و حذفیات)...")
print("=" * 70)

stage_audit = []
raw_mappings = {} # نگاشت‌های ادغام (label -> replace_by)
explicit_removals = set() # کلیدواژه‌هایی که باید در VOSviewer حذف شوند (replace_by خالی)

for step_num in range(1, 8):
    step_folder = os.path.join(base_dir, f"step{step_num}")
    found_files = []
    
    total_rows_read = 0
    merges_added = 0
    removals_added = 0
    skipped_rows = 0
    
    if os.path.exists(step_folder):
        for file in os.listdir(step_folder):
            if file.endswith('.txt') and any(k in file.lower() for k in ['thesaurus', 'synonym']):
                file_path = os.path.join(step_folder, file)
                found_files.append(file)
                
                try:
                    df = None
                    for sep in ['\t', ',', r'\s+']:
                        try:
                            temp_df = pd.read_csv(file_path, sep=sep, encoding='utf-8-sig', on_bad_lines='skip')
                            if len(temp_df.columns) >= 2:
                                df = temp_df
                                break
                        except:
                            continue
                    
                    if df is not None:
                        df.columns = df.columns.astype(str).str.strip().str.lower()
                        
                        label_col = next((c for c in df.columns if c in ['label', 'keyword', 'keyword1', 'raw_keyword', 'term']), df.columns[0])
                        replace_col = next((c for c in df.columns if c in ['replace by', 'replace_by', 'merge_with', 'target_keyword', 'replace', 'keyword2', 'split_into', 'destination']), df.columns[1])
                        
                        for _, row in df.iterrows():
                            total_rows_read += 1
                            lbl = str(row[label_col]).strip().lower() if pd.notna(row[label_col]) else ""
                            rep = str(row[replace_col]).strip().lower() if pd.notna(row[replace_col]) else ""
                            
                            if ';' in rep:
                                rep = rep.split(';')[0].strip()
                            
                            if not lbl:
                                skipped_rows += 1
                                continue
                            
                            # تشخیص حالت حذف (اگر replace_by خالی باشد یا کلماتی مانند remove/delete/drop باشد)
                            if not rep or rep in ['nan', 'none', '', 'remove', 'delete', 'drop']:
                                explicit_removals.add(lbl)
                                removals_added += 1
                            elif lbl == rep:
                                skipped_rows += 1
                            else:
                                raw_mappings[lbl] = rep
                                merges_added += 1
                                
                except Exception as e:
                    print(f"   ❌ خطا در پردازش {file}: {e}")

    stage_audit.append({
        'step': f"Step {step_num}",
        'files': ", ".join(found_files) if found_files else "None",
        'total_read': total_rows_read,
        'merges': merges_added,
        'removals': removals_added,
        'skipped': skipped_rows
    })
    
    print(f"  🔹 Step {step_num}: خوانده شده={total_rows_read} | جایگزینی/ادغام={merges_added} | حذفیات={removals_added}")

# ================= 3. حل زنجیره‌ها و حلقه‌ها برای ادغام‌ها =================
print("\n" + "=" * 70)
print("🔄 [گام ۲] در حال برطرف کردن زنجیره‌ها و حلقه‌های تکراری...")
print("=" * 70)

resolved_mappings = {}
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

for label, replace in raw_mappings.items():
    final_target = trace_target(replace, raw_mappings)
    if label != final_target:
        resolved_mappings[label] = final_target

# ================= 4. ترکیب جایگزینی‌ها و حذفیات در جدول نهایی =================
print("\n" + "=" * 70)
print("🛡️ [گام ۳] ترکیب ادغام‌ها و حذفیات جهت ساخت تزاروس نهایی...")
print("=" * 70)

final_thesaurus_dict = {}

# ۱. اولویت با نگاشت‌های جایگزینی و ادغام است
for lbl, rep in resolved_mappings.items():
    final_thesaurus_dict[lbl] = rep

# ۲. اضافه کردن حذفیات (فقط برای کلماتی که ادغام نشده‌اند)
actual_removals_count = 0
for removal_kw in explicit_removals:
    if removal_kw not in final_thesaurus_dict:
        final_thesaurus_dict[removal_kw] = "" # مقدار خالی یعنی حذف در VOSviewer
        actual_removals_count += 1

# پاک‌سازی تداخل احتمالی بین ستون‌ها
labels = set(final_thesaurus_dict.keys())
replaces = set(val for val in final_thesaurus_dict.values() if val != "")
intersection = labels.intersection(replaces)

if intersection:
    for item in list(intersection):
        if item in final_thesaurus_dict:
            del final_thesaurus_dict[item]

# ================= 5. ذخیره‌سازی خروجی‌ها =================
final_df = pd.DataFrame(list(final_thesaurus_dict.items()), columns=['label', 'replace by'])

# ذخیره TXT (برای VOSviewer)
final_df.to_csv(final_txt_path, sep='\t', index=False, encoding='utf-8')

# ذخیره CSV (برای بررسی اکسل)
final_df.to_csv(final_csv_path, index=False, encoding='utf-8-sig')

# ================= 6. تولید گزارش کامل (Audit Log) =================
with open(report_path, 'w', encoding='utf-8') as f:
    f.write("=" * 85 + "\n")
    f.write("COMPLETE THESAURUS INTEGRATION & EXCLUSION AUDIT REPORT\n")
    f.write("=" * 85 + "\n\n")
    f.write(f"Execution Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
    f.write(f"Output TXT (VOSviewer): {final_txt_path}\n")
    f.write(f"Output CSV (Excel)    : {final_csv_path}\n\n")
    
    f.write("1. STAGE-WISE INGESTION AUDIT\n")
    f.write("-" * 85 + "\n")
    f.write(f"{'Stage':<8} | {'Read':<6} | {'Merges Added':<14} | {'Removals Identified':<20} | {'Skipped':<8}\n")
    f.write("-" * 85 + "\n")
    
    grand_read = 0
    grand_merges = 0
    grand_removals = 0
    
    for sa in stage_audit:
        grand_read += sa['total_read']
        grand_merges += sa['merges']
        grand_removals += sa['removals']
        f.write(f"{sa['step']:<8} | {sa['total_read']:<6} | {sa['merges']:<14} | {sa['removals']:<20} | {sa['skipped']:<8}\n")
        
    f.write("-" * 85 + "\n")
    f.write(f"{'TOTAL':<8} | {grand_read:<6} | {grand_merges:<14} | {grand_removals:<20} |\n")
    f.write("=" * 85 + "\n\n")
    
    f.write("2. FINAL THESAURUS COMPOSITION METRICS\n")
    f.write("-" * 85 + "\n")
    f.write(f"Transitive Chains Resolved (A->B->C): {chain_count}\n")
    f.write(f"Circular Loops Broken (A->B->A)   : {cycle_count}\n")
    f.write(f"Overlap Column Fixes              : {len(intersection)}\n")
    f.write(f"Total Merge/Replace Records       : {len(resolved_mappings)}\n")
    f.write(f"Total Removal Records (Empty rep) : {actual_removals_count}\n")
    f.write(f"GRAND TOTAL RECORDS IN THESAURUS  : {len(final_df)}\n")
    f.write("=" * 85 + "\n")

print("\n" + "=" * 70)
print("✨ فایل تزاروس نهایی به همراه تمام حذفیات و ادغام‌ها ساخته شد!")
print(f"📄 فایل VOSviewer (TXT): {final_txt_path}")
print(f"📊 فایل اکسل (CSV)     : {final_csv_path}")
print(f"📝 فایل گزارش (TXT)    : {report_path}")
print("=" * 70)