# 5.3 Top Keywords by Occurrences
top_by_occ = df_merged.nlargest(30, 'occurrences')[
    ['label', 'occurrences', 'total link strength', 'links', 'cluster', 'avg. pub. year']
].reset_index(drop=True)

# 5.4 Top Keywords by Link Strength
top_by_tls = df_merged.nlargest(30, 'total link strength')[
    ['label', 'occurrences', 'total link strength', 'links', 'cluster', 'avg. pub. year']
].reset_index(drop=True)

# 5.5 Year Statistics
if 'avg. pub. year' in df_merged.columns and df_merged['avg. pub. year'].sum() > 0:
    year_stats = df_merged.groupby(df_merged['avg. pub. year'].round().astype(int)).agg(
        keyword_count=('label', 'count'),
        total_occurrences=('occurrences', 'sum'),
        avg_occurrences=('occurrences', 'mean')
    ).reset_index()
    year_stats.columns = ['year', 'keyword_count', 'total_occurrences', 'avg_occurrences']
    year_stats = year_stats.sort_values('year')
else:
    year_stats = pd.DataFrame()

# 5.6 Correlation Analysis
correlation_data = {}
if 'occurrences' in df_merged.columns and 'total link strength' in df_merged.columns:
    correlation_data['occurrences_vs_link_strength'] = df_merged['occurrences'].corr(df_merged['total link strength'])
if 'occurrences' in df_merged.columns and 'links' in df_merged.columns:
    correlation_data['occurrences_vs_links'] = df_merged['occurrences'].corr(df_merged['links'])

# ================= 6. Generate Report =================
print("\n📝 Generating comprehensive report...")

report_lines = [
    "=" * 80,
    "STEP 8d: COMPREHENSIVE DESCRIPTIVE STATISTICS REPORT",
    "=" * 80,
    f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
    f"Source Files: {os.path.basename(map_file)}, {os.path.basename(net_file)}",
    "",
    "1. GENERAL STATISTICS",
    "-" * 80,
    f"Total Number of Keywords: {total_keywords:,}",
    f"Total Occurrences (Sum): {total_occurrences:,}",
    f"Total Link Strength (Sum): {total_links:,}",
    f"Total Connections (Links): {total_connections:,}",
    f"Number of Clusters: {num_clusters}",
    f"Average Occurrences per Keyword: {total_occurrences/total_keywords:,.2f}",
    f"Average Link Strength per Keyword: {total_links/total_keywords:,.2f}",
    f"Average Connections per Keyword: {total_connections/total_keywords:,.2f}",
    "",
    "2. CLUSTER DISTRIBUTION",
    "-" * 80,
]

for _, row in cluster_stats.iterrows():
    report_lines.append(
        f"Cluster {int(row['cluster'])}: {int(row['keyword_count'])} keywords | "
        f"Total Occ: {int(row['total_occurrences']):,} | "
        f"Avg Occ: {row['avg_occurrences']:.2f} | "
        f"Year Range: {int(row['min_year'])}-{int(row['max_year'])}"
    )

report_lines.extend([
    "",
    "3. TOP 30 KEYWORDS BY OCCURRENCES",
    "-" * 80,
    f"{'Rank':<5} | {'Keyword':<40} | {'Occ':<8} | {'TLS':<8} | {'Links':<6} | {'Cluster':<8} | {'Year':<6}",
    "-" * 80,
])

for i, row in top_by_occ.iterrows():
    label = str(row['label'])[:38] + ".." if len(str(row['label'])) > 40 else str(row['label'])
    report_lines.append(
        f"{i+1:<5} | {label:<40} | {int(row['occurrences']):<8,} | "
        f"{int(row['total link strength']):<8,} | {int(row['links']):<6} | "
        f"{int(row['cluster']):<8} | {row['avg. pub. year']:.0f}"
    )

report_lines.extend([
    "",
    "4. TOP 30 KEYWORDS BY TOTAL LINK STRENGTH",
    "-" * 80,
    f"{'Rank':<5} | {'Keyword':<40} | {'Occ':<8} | {'TLS':<8} | {'Links':<6} | {'Cluster':<8} | {'Year':<6}",
    "-" * 80,
])

for i, row in top_by_tls.iterrows():
    label = str(row['label'])[:38] + ".." if len(str(row['label'])) > 40 else str(row['label'])
    report_lines.append(
        f"{i+1:<5} | {label:<40} | {int(row['occurrences']):<8,} | "
        f"{int(row['total link strength']):<8,} | {int(row['links']):<6} | "
        f"{int(row['cluster']):<8} | {row['avg. pub. year']:.0f}"
    )

report_lines.extend([
    "",
    "5. PUBLICATION YEAR DISTRIBUTION",
    "-" * 80,
])
if not year_stats.empty:
    report_lines.append(f"{'Year':<6} | {'Keywords':<10} | {'Total Occ':<12} | {'Avg Occ':<10}")
    report_lines.append("-" * 80)
    for _, row in year_stats.iterrows():
        report_lines.append(
            f"{int(row['year']):<6} | {int(row['keyword_count']):<10} | "
            f"{int(row['total_occurrences']):<12,} | {row['avg_occurrences']:.2f}"
        )
else:
    report_lines.append("   No year data available")

report_lines.extend([
    "",
    "6. CORRELATION ANALYSIS",
    "-" * 80,
])

for corr_name, corr_value in correlation_data.items():
    report_lines.append(f"   {corr_name}: {corr_value:.4f}")

report_lines.extend([
    "",
    "7. DESCRIPTIVE STATISTICS SUMMARY",
    "-" * 80,
    f"Occurrences - Mean: {df_merged['occurrences'].mean():.2f}, "
    f"Median: {df_merged['occurrences'].median():.2f}, "
    f"Std: {df_merged['occurrences'].std():.2f}",
    f"Total Link Strength - Mean: {df_merged['total link strength'].mean():.2f}, "
    f"Median: {df_merged['total link strength'].median():.2f}, "
    f"Std: {df_merged['total link strength'].std():.2f}",
    f"Links - Mean: {df_merged['links'].mean():.2f}, "
    f"Median: {df_merged['links'].median():.2f}, "
    f"Std: {df_merged['links'].std():.2f}",
    f"Avg. Pub. Year - Mean: {df_merged['avg. pub. year'].mean():.2f}, "
    f"Median: {df_merged['avg. pub. year'].median():.2f}",
    "",
    "=" * 80,
    "END OF REPORT",
    "=" * 80,
])

# Save report
report_text = "\n".join(report_lines)
with open(output_report, 'w', encoding='utf-8') as f:
    f.write(report_text)

print(f"   ✅ Report saved: {output_report}")

# ================= 7. Save CSV Files =================
print("\n💾 Saving CSV files...")

# Full statistics
df_merged.to_csv(output_summary_csv, index=False, encoding='utf-8-sig')
print(f"   ✅ Full statistics: {output_summary_csv}")

# Top 30 keywords
top_by_occ.to_csv(output_top_keywords_csv, index=False, encoding='utf-8-sig')
print(f"   ✅ Top 30 keywords: {output_top_keywords_csv}")

# Cluster statistics
cluster_stats.to_csv(output_cluster_stats_csv, index=False, encoding='utf-8-sig')
print(f"   ✅ Cluster statistics: {output_cluster_stats_csv}")

# Year statistics
if not year_stats.empty:
    year_stats.to_csv(output_year_stats_csv, index=False, encoding='utf-8-sig')
    print(f"   ✅ Year statistics: {output_year_stats_csv}")

# ================= 8. Summary =================
print("\n" + "=" * 70)
print("✅ STEP 8d COMPLETED SUCCESSFULLY!")
print("=" * 70)
print(f"\n📊 Summary:")
print(f"   - Total keywords: {total_keywords:,}")
print(f"   - Total occurrences: {total_occurrences:,}")
print(f"   - Total link strength: {total_links:,}")
print(f"   - Number of clusters: {num_clusters}")
print(f"\n Output files in: {output_dir}")
print(f"   1. step8d_comprehensive_report.txt")
print(f"   2. step8d_full_statistics.csv")
print(f"   3. step8d_top_30_keywords.csv")
print(f"   4. step8d_cluster_statistics.csv")
print(f"   5. step8d_year_statistics.csv")
print(f"\n End time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
# ============================================================
# Step 8d: Comprehensive Descriptive Statistics for VOSviewer
# Input: map and net files (TXT format)
# Output: Step8d_Descriptive_Statistics_Keywords folder
# ============================================================

import pandas as pd
import os
from datetime import datetime
import numpy as np

# ================= 1. Path Settings =================
base_dir = r"D:\Thesis\Thesaurus"
output_dir = os.path.join(base_dir, "Step8d_Descriptive_Statistics_Keywords")
os.makedirs(output_dir, exist_ok=True)

# File names (TXT format as shown in your screenshot)
map_file = os.path.join(base_dir, "map 15.txt")
net_file = os.path.join(base_dir, "net 15.txt")

output_report = os.path.join(output_dir, "step8d_comprehensive_report.txt")
output_summary_csv = os.path.join(output_dir, "step8d_full_statistics.csv")
output_top_keywords_csv = os.path.join(output_dir, "step8d_top_30_keywords.csv")
output_cluster_stats_csv = os.path.join(output_dir, "step8d_cluster_statistics.csv")
output_year_stats_csv = os.path.join(output_dir, "step8d_year_statistics.csv")

print("=" * 70)
print("STEP 8d: Comprehensive Descriptive Statistics")
print("=" * 70)
print(f"Start time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

# ================= 2. Load Data =================
print("\n Loading VOSviewer files...")

def load_vosviewer_file(filepath):
    """Load VOSviewer TXT file with proper handling."""
    if not os.path.exists(filepath):
        raise FileNotFoundError(f"File not found: {filepath}")
    
    print(f"   Reading: {os.path.basename(filepath)}")
    
    # VOSviewer TXT files are tab-separated
    df = pd.read_csv(filepath, sep='\t', encoding='utf-8-sig')
    
    # Clean column names
    df.columns = [col.strip().lower().replace('<weight<', '').replace('<score<', '') for col in df.columns]
    
    return df

df_map = load_vosviewer_file(map_file)
df_net = load_vosviewer_file(net_file)

print(f"   ✅ Map file: {len(df_map)} rows, {len(df_map.columns)} columns")
print(f"   ✅ Net file: {len(df_net)} rows, {len(df_net.columns)} columns")

# ================= 3. Merge Data =================
print("\n🔗 Merging map and net data...")

# Merge on 'id' and 'label'
df_merged = pd.merge(df_map, df_net, on=['id', 'label'], how='outer', suffixes=('_map', '_net'))

# Keep unique rows
df_merged = df_merged.drop_duplicates(subset=['id'])

print(f"   ✅ Merged dataset: {len(df_merged)} unique keywords")
print(f"   Columns: {list(df_merged.columns)}")

# ================= 4. Data Cleaning =================
print("\n🧹 Cleaning data...")

# Convert numeric columns
numeric_cols = ['occurrences', 'total link strength', 'links', 'cluster', 'avg. pub. year', 'score', 'x', 'y']
for col in numeric_cols:
    if col in df_merged.columns:
        df_merged[col] = pd.to_numeric(df_merged[col], errors='coerce')

# Fill NaN with 0 for numeric columns
df_merged[numeric_cols] = df_merged[numeric_cols].fillna(0)

# Ensure cluster is integer
if 'cluster' in df_merged.columns:
    df_merged['cluster'] = df_merged['cluster'].astype(int)

print("   ✅ Data cleaned")

# ================= 5. Calculate Statistics =================
print("\n Calculating statistics...")

# 5.1 General Statistics
total_keywords = len(df_merged)
total_occurrences = int(df_merged['occurrences'].sum())
total_links = int(df_merged['total link strength'].sum())
total_connections = int(df_merged['links'].sum())
num_clusters = df_merged['cluster'].nunique()

# 5.2 Cluster Distribution
cluster_stats = df_merged.groupby('cluster').agg(
    keyword_count=('label', 'count'),
    total_occurrences=('occurrences', 'sum'),
    total_link_strength=('total link strength', 'sum'),
    avg_occurrences=('occurrences', 'mean'),
    avg_link_strength=('total link strength', 'mean'),
    avg_year=('avg. pub. year', 'mean'),
    min_year=('avg. pub. year', 'min'),
    max_year=('avg. pub. year', 'max')
).reset_index()

cluster_stats = cluster_stats.sort_values('total_occurrences', ascending=False)
