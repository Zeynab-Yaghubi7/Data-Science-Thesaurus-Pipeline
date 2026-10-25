# ============================================================
# Step 4: Singular/Plural Merging (Strictly to Singular)
# Version: Ultimate Fix (Protects Scientific Terms Ending in S)
# ============================================================
import pandas as pd
import os
from datetime import datetime
from collections import defaultdict

# ================= 1. Path Settings =================
base_dir = r"D:\Thesis\thesaurus"
input_file = os.path.join(base_dir, "step3", "step3_cleaned_keywords.csv")
output_dir = os.path.join(base_dir, "step4")
os.makedirs(output_dir, exist_ok=True)
output_cleaned = os.path.join(output_dir, "step4_cleaned_keywords.csv")
output_thesaurus_txt = os.path.join(output_dir, "step4_thesaurus_vosviewer.txt")
output_thesaurus_csv = os.path.join(output_dir, "step4_thesaurus_vosviewer.csv")
output_report = os.path.join(output_dir, "step4_report.txt")

print("=" * 70)
print("STEP 4: Singular/Plural Merging (Strictly to Singular)")
print("=" * 70)
print(f"Start time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

if not os.path.exists(input_file):
    raise FileNotFoundError(f"Input file not found:\n{input_file}")

# ============================================================
# 2. Load Data
# ============================================================
print("\nReading data...")
df = pd.read_csv(input_file, encoding='utf-8-sig')
print(f"Input keywords: {len(df):,}")

required_columns = ['keyword', 'co_occurrences', 'total_link_strength']
missing_columns = [col for col in required_columns if col not in df.columns]
if missing_columns:
    raise ValueError("\nRequired columns are missing:\n" + "\n".join(f" - {col}" for col in missing_columns))

df['co_occurrences'] = pd.to_numeric(df['co_occurrences'], errors='coerce').fillna(0)
df['total_link_strength'] = pd.to_numeric(df['total_link_strength'], errors='coerce').fillna(0)
df['keyword'] = df['keyword'].astype(str).str.strip()

# ============================================================
# 3. Protected & Irregular Words
# ============================================================
PROTECTED_WORDS = {
    # رشته‌ها و حوزه‌های علمی
    'statistics', 'ethics', 'physics', 'mathematics', 'informatics', 'humanities', 
    'news', 'economics', 'politics', 'linguistics', 'genetics', 'robotics',
    'aerodynamics', 'thermodynamics', 'pharmaceutics', 'metabolomics', 
    'proteomics', 'genomics', 'bioinformatics', 'cheminformatics', 'neuroscience',
    'analytics', 'diagnostics', 'prognostics', 'kinetics', 
    'pediatrics', 'geriatrics', 'orthopedics', 'obstetrics', 'gynecology',
    # کلمات لاتین/یونانی که ذاتاً به s ختم می‌شوند
    'analysis', 'basis', 'crisis', 'thesis', 'diagnosis', 'prognosis', 'parenthesis', 'oasis',
    'metastasis', 'sepsis', 'focus', 'status', 'nexus', 'complex', 'apex', 'vertex',
    # نام‌های خانوادگی علمی (ذاتاً به s ختم می‌شوند)
    'bayes', 'lewis', 'birnbaum-saunders', 'gauss', 'maxwell', 'jones', 'davies',
    # اصطلاحات علمی چندکلمه‌ای که ذاتاً به s ختم می‌شوند
    'first-principles', 'k-means', 'mixed-effects', 'least-squares', 'two-sigma',
    # کلمات با شکل مفرد/جمع یکسان
    'series', 'species', 'data', 'metadata', 'media', 'criteria', 'phenomena', 
    'means', 'crossroads', 'sheep', 'deer', 'fish',
    # کلمات بی‌قاعده
    'children', 'men', 'women', 'people', 'mice', 'lice', 'teeth', 'feet', 
    'geese', 'oxen', 'cacti', 'fungi', 'nuclei', 'syllabi', 'alumni',
    # مخفف‌ها
    'gis', 'svm', 'ann', 'cnn', 'rnn', 'gan', 'dnn', 'llm', 'llms', 'iot', 'api', 'ehr', 'ehrs',
    # صفت‌های رایج که به s ختم می‌شوند
    'heterogeneous', 'homogeneous', 'conscious', 'nervous', 'various', 'curious', 'serious',
    'obvious', 'generous', 'dangerous', 'famous', 'enormous', 'marvelous',
    # اصطلاحات ثابت
    'internet of things', 'special needs education', 'mixed methods',
    'random forests', 'decision trees', 'neural networks', 'large language models',
    'generative adversarial networks', 'support vector machines', 'artificial neural networks',
    'convolutional neural networks', 'recurrent neural networks', 'graph neural networks',
    'deep neural networks', 'hidden markov models', 'gaussian mixture models',
    'bayesian networks', 'principal components', 'time series',
    'health disparities', 'older adults', 'digital therapeutics', 'sports analytics',
    'patient-reported outcomes', 'adverse drug reactions', 'operations management',
    'operations research', 'google trends', 'wearables', 'electronics', 'materials', 
    'systems', 'dynamics', 'mechanics', 'optics', 'acoustics', 'aesthetics', 'human factors',
    'fair principles', 'sustainable development goals', 'smart cities', 'digital twins',
    'electronic health records', 'electronic medical records', 'clinical trials',
    'randomized controlled trials', 'observational studies', 'longitudinal studies',
    'cohort studies', 'molecular dynamics', 'computational fluid dynamics',
    'nonlinear dynamics', 'population dynamics', 'network dynamics', 'social networks',
    'complex networks', 'complex systems', 'intelligent systems', 'expert systems',
    'cyber-physical systems', 'multi-agent systems', 'distributed systems',
    'intelligent transportation systems', 'wireless sensor networks', 'sensor networks',
    'recommendation systems', 'recommender systems', 'decision support systems',
    'clinical decision support systems', 'health information systems',
    'hospital information systems', 'geographic information systems',
    'geographical information systems', 'learning management systems', 'information systems',
    'materials science', 'materials informatics', 'systems biology', 'systems medicine',
    'health sciences', 'life sciences', 'social sciences', 'computational sciences',
    'statistical sciences', 'data sciences', 'health data sciences',
    'environmental systems', 'energy systems', 'power systems', 'smart grids',
    'smart buildings', 'smart factories', 'smart environments', 'smart sensors',
    'soft sensors', 'wearable devices', 'wearable sensors', 'autonomous vehicles',
    'electric vehicles', 'connected vehicles', 'automated vehicles', 'unmanned aerial vehicles',
    'generative models', 'predictive models', 'mathematical models', 'statistical models',
    'regression models', 'classification models', 'ensemble models', 'hybrid models',
    'foundation models', 'language models', 'transformer models', 'vision transformers',
    'graphical models', 'causal models', 'compartmental models',
    'stochastic models', 'mixed models', 'agent-based models', 'topic models', 'mixture models',
}

IRREGULAR_PLURALS = {
    'analyses': 'analysis', 'hypotheses': 'hypothesis', 'syntheses': 'synthesis',
    'oases': 'oasis', 'crises': 'crisis', 'theses': 'thesis', 'diagnoses': 'diagnosis',
    'prognoses': 'prognosis', 'parentheses': 'parenthesis', 'antitheses': 'antithesis',
    'matrices': 'matrix', 'vertices': 'vertex', 'indices': 'index', 'appendices': 'appendix',
    'phenomena': 'phenomenon', 'criteria': 'criterion', 'automata': 'automaton',
    'people': 'person', 'children': 'child', 'men': 'man', 'women': 'woman',
    'geese': 'goose', 'mice': 'mouse', 'lice': 'louse', 'teeth': 'tooth', 'feet': 'foot',
    'metastases': 'metastasis', 
}

NEVER_MERGE = {
    'logistic', 'logistics', 'semantic', 'semantics', 'psychometric', 'psychometrics',
    'econometric', 'econometrics', 'biostatistic', 'biostatistics', 'transcriptomic', 'transcriptomics',
    'metagenomic', 'metagenomics', 'scientometric', 'scientometrics', 'bibliometric', 'bibliometrics',
    'multiomic', 'multiomics', 'proteomic', 'proteomics', 'genomic', 'genomics',
    'pragmatic', 'pragmatics', 'statistic', 'statistics', 'analytic', 'analytics',
    'ethic', 'ethics', 'mechanic', 'mechanics', 'dynamic', 'dynamics', 'informatic', 'informatics',
    'neuromorphic', 'neuromorphics', 'photonic', 'photonics', 'robotic', 'robotics',
    'genetic', 'genetics', 'numeric', 'numerics', 'theoretic', 'theoretics',
    'electronic', 'electronics', 'cybernetic', 'cybernetics',
    'communication', 'communications', 'instruction', 'instructions', 'damage', 'damages',
    'content', 'contents', 'manner', 'manners', 'custom', 'customs', 'arm', 'arms',
    'force', 'forces', 'effect', 'effects', 'return', 'returns', 'saving', 'savings',
    'finding', 'findings', 'work', 'works', 'mean', 'means', 'premise', 'premises',
    'authority', 'authorities', 'liability', 'liabilities', 'asset', 'assets',
    'equity', 'equities', 'security', 'securities', 'facility', 'facilities',
    'utility', 'utilities', 'capability', 'capabilities', 'activity', 'activities',
    'vulnerability', 'vulnerabilities', 'inequality', 'inequalities', 'interaction', 'interactions',
    'motivation', 'motivations', 'emotion', 'emotions', 'intervention', 'interventions',
    'prediction', 'predictions', 'simulation', 'simulations', 'visualization', 'visualizations',
    'classification', 'classifications', 'serious game', 'serious games',
    'plastic waste', 'plastic wastes', 'policy recommendation', 'policy recommendations',
}

FORCE_SINGULAR_TARGETS = {
    'data science applications in education': 'data science application in education',
    'data science applications': 'data science application',
    'sports science': 'sport science',
    'sports sciences': 'sport science',
}

# ============================================================
# 4. Improved Singular Detection (ULTIMATE FIX)
# ============================================================
def get_singular_form(keyword):
    kw_lower = keyword.lower().strip()
    
    if kw_lower in FORCE_SINGULAR_TARGETS:
        target_form = FORCE_SINGULAR_TARGETS[kw_lower]
        is_plural = (kw_lower != target_form)
        return target_form, is_plural 
    
    if kw_lower in PROTECTED_WORDS:
        return kw_lower, False
    if kw_lower in NEVER_MERGE:
        return kw_lower, False
    if kw_lower in IRREGULAR_PLURALS:
        return IRREGULAR_PLURALS[kw_lower], True

    words = kw_lower.split()
    base_words = []
    is_plural = False

    for i, word in enumerate(words):
        if word.startswith('(') and word.endswith(')'):
            base_words.append(word)
            continue
        if word in PROTECTED_WORDS or word in NEVER_MERGE:
            base_words.append(word)
            continue
        
        if i > 0:
            two_word = f"{words[i-1]} {word}"
            if two_word in PROTECTED_WORDS or two_word in NEVER_MERGE:
                base_words.append(word)
                continue

        base_word = word
        word_is_plural = False

        # --- ULTIMATE FIX: Safe Plural Detection ---
        
        # Rule 1: ies -> y (policies -> policy)
        if word.endswith('ies') and len(word) > 4:
            base_word = word[:-3] + 'y'
            word_is_plural = True
            
        # Rule 2: ves -> f (knives -> knife)
        elif word.endswith('ves') and len(word) > 4:
            base_word = word[:-3] + 'f'
            word_is_plural = True
            
        # Rule 3: xes / ches / shes -> remove es (boxes -> box)
        elif word.endswith('xes') or word.endswith('ches') or word.endswith('shes'):
            base_word = word[:-2]
            word_is_plural = True
            
        # Rule 4: Ordinary plural ending in s
        # CRITICAL: Do NOT strip 's' if word ends in us, ss, is, as, os, es (Latin/Greek/Names)
        elif word.endswith('s') and len(word) > 3:
            
            # EXCEPTIONS: Words that naturally end in these letters (NOT plurals)
            safe_endings = ('us', 'ss', 'is', 'as', 'os', 'es', 'ys')
            
            if word.endswith(safe_endings):
                # These are NOT plurals, keep as is
                pass
            else:
                # Additional check: Common adjectives ending in s that are singular
                singular_adjectives = {'heterogeneous', 'homogeneous', 'conscious', 'nervous', 'various', 'curious', 'serious'}
                if word not in singular_adjectives:
                    base_word = word[:-1]
                    word_is_plural = True

        if word_is_plural:
            is_plural = True
        base_words.append(base_word)

    return ' '.join(base_words), is_plural

# ============================================================
# 5. Grouping & Merging Logic
# ============================================================
print("\nGrouping similar keywords...")
groups = defaultdict(list)
for _, row in df.iterrows():
    keyword = str(row['keyword']).strip()
    if keyword == '': continue
    co_occurrences = int(row['co_occurrences'])
    tls = int(row['total_link_strength'])
    
    base, is_plural = get_singular_form(keyword)
    groups[base].append((keyword, co_occurrences, tls, is_plural))

print(f"Groups containing multiple forms: {sum(1 for m in groups.values() if len(m) > 1):,}")

print("\nIdentifying singular/plural merges...")
merge_map = {}
merge_details = []

for base, members in groups.items():
    if len(members) < 2: continue
    if base in NEVER_MERGE: continue

    singular_members = [m for m in members if not m[3]]
    plural_members = [m for m in members if m[3]]

    if singular_members:
        exact_match = [m for m in singular_members if m[0] == base]
        if exact_match:
            target = max(exact_match, key=lambda x: x[1])
        else:
            target = max(singular_members, key=lambda x: x[1])
    else:
        if base not in NEVER_MERGE and base not in PROTECTED_WORDS:
            target = (base, 0, 0, False) 
        else:
            target = max(members, key=lambda x: x[1])

    main_keyword = target[0]
    main_co_occurrences = target[1]

    for keyword, co_occurrences, tls, is_plural in members:
        if keyword != main_keyword:
            merge_map[keyword] = main_keyword
            merge_details.append({
                'Label': keyword,
                'Replace by': main_keyword,
                'Original Co-occurrences': co_occurrences,
                'Target Co-occurrences': main_co_occurrences,
            })

print(f"Merges identified: {len(merge_map):,}")

# ============================================================
# 6. Apply Merges & Save
# ============================================================
print("\nApplying merges...")
df['keyword'] = df['keyword'].apply(lambda x: merge_map.get(x, x))

print("\nRemoving duplicates and aggregating...")
df_before_dedup = len(df)
numeric_cols = ['co_occurrences', 'total_link_strength']
agg_dict = {col: 'sum' if col in numeric_cols else 'first' for col in df.columns if col != 'keyword'}

df = df.groupby('keyword', as_index=False).agg(agg_dict)
df_after_dedup = len(df)
removed_count = df_before_dedup - df_after_dedup
print(f"Rows removed/merged: {removed_count:,}")
df = df.sort_values('co_occurrences', ascending=False).reset_index(drop=True)

print("\nSaving output files...")
df.to_csv(output_cleaned, index=False, encoding='utf-8-sig')

df_thesaurus = pd.DataFrame([{'Label': k, 'Replace by': v} for k, v in merge_map.items()])
if not df_thesaurus.empty:
    df_thesaurus = df_thesaurus.drop_duplicates(subset=['Label'], keep='first')
else:
    df_thesaurus = pd.DataFrame(columns=['Label', 'Replace by'])

df_thesaurus.to_csv(output_thesaurus_txt, sep='\t', index=False, encoding='utf-8-sig')
df_thesaurus.to_csv(output_thesaurus_csv, index=False, encoding='utf-8-sig')

with open(output_report, 'w', encoding='utf-8') as f:
    f.write("=" * 70 + "\n")
    f.write("STEP 4 REPORT — Singular/Plural Merging (Strictly to Singular)\n")
    f.write("=" * 70 + "\n\n")
    f.write(f"Execution Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
    f.write(f"Input File: {input_file}\n\n")
    f.write("PROCESSING STATISTICS\n")
    f.write("-" * 70 + "\n")
    f.write(f"Total Input Keywords: {df_before_dedup:,}\n")
    f.write(f"Plural/Singular Groups Detected: {sum(1 for m in groups.values() if len(m) > 1):,}\n")
    f.write(f"Total Merges Performed: {len(merge_map):,}\n")
    f.write(f"Duplicate Rows Removed: {removed_count:,}\n")
    f.write(f"Final Cleaned Keywords: {len(df):,}\n\n")
    
    f.write("MERGE DETAILS (Top 50 Groups)\n")
    f.write("-" * 70 + "\n")
    if merge_details:
        by_target = defaultdict(list)
        for item in merge_details:
            by_target[item['Replace by']].append(item)
        count = 0
        for target, items in sorted(by_target.items(), key=lambda x: -len(x[1])):
            count += 1
            if count > 50:
                f.write(f"\n... and {len(by_target) - 50} more groups.\n")
                break
            f.write(f"\n  Group {count}: Target = '{target}'\n")
            for item in items:
                f.write(f"     '{item['Label']}' (co-occurrences={item['Original Co-occurrences']}) → '{item['Replace by']}'\n")
    else:
        f.write("  No merges were performed.\n")

print("[4/4] Report saved.")
print("\nStep 4 completed successfully with ULTIMATE FIX.")
print("=" * 70)