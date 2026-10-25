# ============================================================
# STEP 7 — Advanced Synonym Suggestions & Merging (Auto-Detect Mode)
# ============================================================

import pandas as pd
import os
from datetime import datetime
from collections import defaultdict
from sentence_transformers import SentenceTransformer, util
import torch

# ================= 1. Path Settings =================
base_dir = r"D:\Thesis\thesaurus"
input_file = os.path.join(base_dir, "step6", "step6_cleaned_keywords.csv")

output_dir = os.path.join(base_dir, "step7")
os.makedirs(output_dir, exist_ok=True)

output_suggestions = os.path.join(output_dir, "step7_synonym_suggestions.csv")
output_cleaned = os.path.join(output_dir, "step7_cleaned_keywords.csv")
output_thesaurus_txt = os.path.join(output_dir, "step7_thesaurus_vosviewer.txt")
output_thesaurus_csv = os.path.join(output_dir, "step7_thesaurus_vosviewer.csv")
output_report = os.path.join(output_dir, "step7_report.txt")

SIMILARITY_THRESHOLD = 0.92

print("=" * 70)
print("STEP 7: Advanced Synonym Suggestions & Merging (Auto-Detect)")
print("=" * 70)
print(f"Start time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

if not os.path.exists(input_file):
    raise FileNotFoundError(f"Input file not found:\n{input_file}")

# ================= 2. Auto-Detect Mode =================
# اگر فایل پیشنهادات وجود دارد و ستون merge_decision پر شده → Apply
# در غیر این صورت → Generate

suggestions_exist = os.path.exists(output_suggestions)
has_decisions = False

if suggestions_exist:
    try:
        df_temp = pd.read_csv(output_suggestions, encoding='utf-8-sig', nrows=5)
        if 'merge_decision' in df_temp.columns:
            # بررسی آیا حداقل یک تصمیم غیرخالی وجود دارد
            df_temp['merge_decision'] = df_temp['merge_decision'].astype(str).str.strip().str.lower()
            has_decisions = (df_temp['merge_decision'] == 'yes').any()
    except Exception:
        pass

if has_decisions:
    MODE = 'apply'
    print(f"\n🔄 Detected existing decisions → APPLY MODE")
else:
    MODE = 'generate'
    print(f"\n🔄 No decisions found → GENERATE MODE")

print(f"   Mode: {MODE.upper()}")

# ================= 3. Load Base Data =================
print("\n📂 Reading base data...")
df_base = pd.read_csv(input_file, encoding='utf-8-sig')

if 'keyword' not in df_base.columns:
    df_base.rename(columns={df_base.columns[0]: 'keyword'}, inplace=True)
if 'co_occurrences' not in df_base.columns:
    df_base.rename(columns={df_base.columns[1]: 'co_occurrences'}, inplace=True)
if 'total_link_strength' not in df_base.columns:
    df_base.rename(columns={df_base.columns[2]: 'total_link_strength'}, inplace=True)

df_base['co_occurrences'] = pd.to_numeric(df_base['co_occurrences'], errors='coerce').fillna(0).astype(int)
df_base['total_link_strength'] = pd.to_numeric(df_base['total_link_strength'], errors='coerce').fillna(0).astype(int)
df_base['keyword'] = df_base['keyword'].astype(str).str.strip()

print(f"   ✅ Total base keywords loaded: {len(df_base):,}")

# ================= MODE: GENERATE =================
if MODE == 'generate':
    print("\n" + "=" * 70)
    print("GENERATE MODE: Finding semantic synonyms...")
    print("=" * 70)
    
    # فقط کلیدواژه‌هایی با فرکانس >= 2
    df_filtered = df_base[df_base['co_occurrences'] >= 2].copy()
    keywords = df_filtered['keyword'].tolist()

    freq_dict = dict(zip(df_filtered['keyword'], df_filtered['co_occurrences']))
    tls_dict = dict(zip(df_filtered['keyword'], df_filtered['total_link_strength']))

    print(f"   ✅ Keywords to analyze (co_occurrences >= 2): {len(keywords):,}")

    # Load Semantic Model
    print("\n🤖 Loading Semantic Model (all-mpnet-base-v2)...")
    print("   (First run will download ~400MB model)")

    try:
        model = SentenceTransformer('all-mpnet-base-v2')
        print("   ✅ Model loaded successfully")
    except Exception as e:
        print(f"   ⚠️ Error loading model: {e}")
        print("   Trying fallback model (paraphrase-MiniLM-L6-v2)...")
        try:
            model = SentenceTransformer('paraphrase-MiniLM-L6-v2')
            print("   ✅ Fallback model loaded")
        except Exception as e2:
            raise RuntimeError(f"Failed to load any model: {e2}")

    # Calculate Embeddings
    print("\n🧠 Computing semantic embeddings...")
    device = 'cuda' if torch.cuda.is_available() else 'cpu'
    print(f"   Using device: {device}")

    embeddings = model.encode(
        keywords, 
        show_progress_bar=True, 
        convert_to_tensor=True,
        device=device
    )
    print(f"   ✅ Embeddings computed: {embeddings.shape}")

    # Calculate Similarity Matrix
    print("\n🔍 Calculating semantic similarity...")
    cosine_scores = util.cos_sim(embeddings, embeddings)

    synonym_pairs = []
    seen_pairs = set()

    for i in range(len(keywords)):
        for j in range(i + 1, len(keywords)):
            score = cosine_scores[i][j].item()
            
            if score >= SIMILARITY_THRESHOLD:
                word1 = keywords[i]
                word2 = keywords[j]
                
                pair_key = tuple(sorted([word1, word2]))
                if pair_key not in seen_pairs:
                    seen_pairs.add(pair_key)
                    
                    if score >= 0.96:
                        suggested_action = 'yes'
                        confidence = 'high'
                    elif score >= 0.94:
                        suggested_action = 'review'
                        confidence = 'medium'
                    else:
                        suggested_action = 'review'
                        confidence = 'low'
                    
                    synonym_pairs.append({
                        'keyword1': word1,
                        'keyword2': word2,
                        'semantic_similarity': round(score, 4),
                        'co_occurrences_1': freq_dict[word1],
                        'co_occurrences_2': freq_dict[word2],
                        'tls_1': tls_dict[word1],
                        'tls_2': tls_dict[word2],
                        'combined_co_occurrences': freq_dict[word1] + freq_dict[word2],
                        'combined_tls': tls_dict[word1] + tls_dict[word2],
                        'suggested_action': suggested_action,
                        'confidence': confidence,
                        'merge_decision': '',
                        'target_keyword': '',
                        'notes': ''
                    })

    df_suggestions = pd.DataFrame(synonym_pairs)
    if not df_suggestions.empty:
        df_suggestions = df_suggestions.sort_values('semantic_similarity', ascending=False)

    print(f"   ✅ Found {len(df_suggestions):,} potential synonym pairs")

    # Save Results
    print("\n💾 Saving suggestions...")
    df_suggestions.to_csv(output_suggestions, index=False, encoding='utf-8-sig')
    print(f"   ✅ Saved: {output_suggestions}")

    # Generate Report
    with open(output_report, 'w', encoding='utf-8') as f:
        f.write("=" * 70 + "\n")
        f.write("STEP 7 REPORT — Advanced Synonym Suggestions (Generate Mode)\n")
        f.write("=" * 70 + "\n\n")
        
        f.write(f"Execution Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"Input File: {input_file}\n")
        f.write(f"Similarity Threshold: {SIMILARITY_THRESHOLD}\n")
        f.write(f"Model Used: all-mpnet-base-v2\n")
        f.write(f"Device: {device}\n\n")
        
        f.write("STATISTICS\n")
        f.write("-" * 70 + "\n")
        f.write(f"Total Input Keywords: {len(df_base):,}\n")
        f.write(f"Keywords Analyzed (co_occurrences >= 2): {len(keywords):,}\n")
        f.write(f"Synonym Pairs Found: {len(df_suggestions):,}\n")
        
        if not df_suggestions.empty:
            high_conf = len(df_suggestions[df_suggestions['confidence'] == 'high'])
            medium_conf = len(df_suggestions[df_suggestions['confidence'] == 'medium'])
            low_conf = len(df_suggestions[df_suggestions['confidence'] == 'low'])
            f.write(f"  - High Confidence (>=0.96): {high_conf:,}\n")
            f.write(f"  - Medium Confidence (0.94-0.96): {medium_conf:,}\n")
            f.write(f"  - Low Confidence (0.92-0.94): {low_conf:,}\n")
        
        f.write("\nTOP 30 SIMILAR PAIRS\n")
        f.write("-" * 70 + "\n")
        if not df_suggestions.empty:
            for idx, row in df_suggestions.head(30).iterrows():
                f.write(f"{row['keyword1']} ↔ {row['keyword2']} "
                       f"(Score: {row['semantic_similarity']}, "
                       f"Confidence: {row['confidence']}, "
                       f"Freq: {row['co_occurrences_1']}+{row['co_occurrences_2']})\n")
        else:
            f.write("No similar pairs found above threshold.\n")
        
        f.write("\n" + "=" * 70 + "\n")
        f.write("NEXT STEPS\n")
        f.write("=" * 70 + "\n")
        f.write("1. Open step7_synonym_suggestions.csv in Excel\n")
        f.write("2. For pairs to merge:\n")
        f.write("   - Set merge_decision = 'yes'\n")
        f.write("   - Set target_keyword = preferred form\n")
        f.write("3. For pairs to keep separate:\n")
        f.write("   - Leave merge_decision empty or set to 'no'\n")
        f.write("4. Save the file (CSV UTF-8)\n")
        f.write("5. Run this script again (it will auto-detect Apply mode)\n")
        f.write("=" * 70 + "\n")

    print(f"\n{'=' * 70}")
    print(f"✅ Step 7 (Generate Mode) Completed Successfully!")
    print(f"{'=' * 70}")
    print(f"\n📁 Output files:")
    print(f"   1. {output_suggestions}")
    print(f"   2. {output_report}")
    print(f"\n⚠️  IMPORTANT: Edit the suggestions file, then run this script again!")


# ================= MODE: APPLY =================
elif MODE == 'apply':
    print("\n" + "=" * 70)
    print("APPLY MODE: Reading decisions and applying merges...")
    print("=" * 70)
    
    df_suggestions = pd.read_csv(output_suggestions, encoding='utf-8-sig')
    
    print(f"   📊 Loaded {len(df_suggestions):,} suggestions from file")
    
    required_cols = ['keyword1', 'keyword2', 'merge_decision', 'target_keyword']
    missing_cols = [c for c in required_cols if c not in df_suggestions.columns]
    if missing_cols:
        raise ValueError(f"Missing columns in suggestions file: {missing_cols}")
        
    df_suggestions['merge_decision'] = df_suggestions['merge_decision'].astype(str).str.strip().str.lower()
    df_suggestions['target_keyword'] = df_suggestions['target_keyword'].astype(str).str.strip()
    
    # فیلتر تصمیمات معتبر
    valid_decisions = df_suggestions[
        (df_suggestions['merge_decision'] == 'yes') &
        (df_suggestions['target_keyword'] != '') &
        (df_suggestions['target_keyword'] != 'nan') &
        (df_suggestions['target_keyword'].notna())
    ].copy()
    
    print(f"   ✅ Found {len(valid_decisions):,} valid merge decisions")
    
    if len(valid_decisions) == 0:
        print("\n⚠️  WARNING: No valid decisions found!")
        print("   Please check your CSV file:")
        print("   - merge_decision should be 'yes' (lowercase)")
        print("   - target_keyword should not be empty")
        print(f"\n   Sample of first 5 rows:")
        print(df_suggestions[['keyword1', 'keyword2', 'merge_decision', 'target_keyword']].head())
        raise ValueError("No valid merge decisions found. Please edit the CSV file correctly.")
    
    # ساخت نقشه ادغام
    merge_map = {}
    for _, row in valid_decisions.iterrows():
        k1 = str(row['keyword1']).strip()
        k2 = str(row['keyword2']).strip()
        target = str(row['target_keyword']).strip()
        
        if target == k1:
            merge_map[k2] = k1
        elif target == k2:
            merge_map[k1] = k2
        else:
            merge_map[k1] = target
            merge_map[k2] = target
            
    print(f"   🗺️ Merge map size: {len(merge_map):,} keywords")
    
    # اعمال ادغام‌ها
    print("\n🔄 Applying merges to dataframe...")
    df_base['original_keyword'] = df_base['keyword']
    df_base['keyword'] = df_base['keyword'].apply(lambda x: merge_map.get(x, x))
    
    # تجمیع مقادیر عددی
    numeric_cols = ['co_occurrences', 'total_link_strength']
    agg_dict = {col: 'sum' for col in numeric_cols}
    
    for col in df_base.columns:
        if col not in ['keyword', 'original_keyword'] + numeric_cols:
            agg_dict[col] = 'first'
            
    df_cleaned = df_base.groupby('keyword', as_index=False).agg(agg_dict)
    df_cleaned = df_cleaned.sort_values('co_occurrences', ascending=False).reset_index(drop=True)
    
    # ذخیره فایل نهایی
    print(f"\n💾 Saving cleaned keywords...")
    df_cleaned.to_csv(output_cleaned, index=False, encoding='utf-8-sig')
    print(f"   ✅ Saved: {output_cleaned} ({len(df_cleaned):,} keywords)")
    
    # ساخت تزاروس
    print(f"💾 Creating VOSviewer thesaurus...")
    df_thesaurus = pd.DataFrame([
        {'Label': original, 'Replace by': target}
        for original, target in merge_map.items()
    ])
    
    if not df_thesaurus.empty:
        df_thesaurus = df_thesaurus.drop_duplicates(subset=['Label'], keep='first')
    else:
        df_thesaurus = pd.DataFrame(columns=['Label', 'Replace by'])
        
    df_thesaurus.to_csv(output_thesaurus_txt, sep='\t', index=False, encoding='utf-8-sig')
    df_thesaurus.to_csv(output_thesaurus_csv, index=False, encoding='utf-8-sig')
    print(f"   ✅ Saved thesaurus: {len(df_thesaurus):,} entries")
    
    # گزارش نهایی
    with open(output_report, 'w', encoding='utf-8') as f:
        f.write("=" * 70 + "\n")
        f.write("STEP 7 REPORT — Synonym Merging (Apply Mode)\n")
        f.write("=" * 70 + "\n\n")
        f.write(f"Execution Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"Input File: {input_file}\n")
        f.write(f"Decisions File: {output_suggestions}\n\n")
        
        f.write("PROCESSING STATISTICS\n")
        f.write("-" * 70 + "\n")
        f.write(f"Total Input Keywords: {len(df_base):,}\n")
        f.write(f"Total Suggestions: {len(df_suggestions):,}\n")
        f.write(f"Valid Merge Decisions: {len(valid_decisions):,}\n")
        f.write(f"Final Cleaned Keywords: {len(df_cleaned):,}\n")
        f.write(f"Keywords Merged: {len(merge_map):,}\n\n")
        
        f.write("APPLIED MERGES (Top 50)\n")
        f.write("-" * 70 + "\n")
        if not df_thesaurus.empty:
            for _, row in df_thesaurus.head(50).iterrows():
                f.write(f"'{row['Label']}' → '{row['Replace by']}'\n")
            if len(df_thesaurus) > 50:
                f.write(f"\n... and {len(df_thesaurus) - 50} more merges.\n")
        else:
            f.write("No merges were applied.\n")
            
        f.write("\nOUTPUT FILES\n")
        f.write("-" * 70 + "\n")
        f.write(f"1. {output_cleaned}\n")
        f.write(f"2. {output_thesaurus_txt}\n")
        f.write(f"3. {output_thesaurus_csv}\n")
        f.write(f"4. {output_report}\n")
        f.write("=" * 70 + "\n")
        
    print(f"\n   ✅ Saved report: {output_report}")
    print(f"\n{'=' * 70}")
    print(f"✅ Step 7 (Apply Mode) Completed Successfully!")
    print(f"{'=' * 70}")
    print(f"\n📁 Output files:")
    print(f"   1. {output_cleaned}")
    print(f"   2. {output_thesaurus_txt}")
    print(f"   3. {output_thesaurus_csv}")
    print(f"   4. {output_report}")

else:
    raise ValueError("Invalid MODE. Please set MODE to 'generate' or 'apply'.")

print(f"\n⏰ End time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")