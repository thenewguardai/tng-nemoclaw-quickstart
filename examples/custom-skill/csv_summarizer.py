# ============================================================================
# TNG NemoClaw — Example: Writing a Safe Custom Skill
#
# This shows the pattern for writing OpenClaw skills that work correctly
# inside a NemoClaw sandbox. The key differences from unsandboxed skills:
#
#   1. All file I/O goes through /sandbox/ paths
#   2. Network requests will be blocked unless your policy allows them
#   3. No access to host filesystem, env vars, or credentials outside sandbox
#
# This example: a simple CSV summarizer that reads a file, generates stats,
# and writes the output — all within sandbox boundaries.
# ============================================================================

"""
CSV Summarizer Skill
Reads a CSV from /sandbox/input/, generates summary statistics,
and writes the report to /sandbox/output/.
"""

import csv
import json
import os
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path

# Sandbox-safe paths only
INPUT_DIR = Path("/sandbox/input")
OUTPUT_DIR = Path("/sandbox/output")
WORKSPACE = Path("/sandbox/workspace")


def validate_paths():
    """Ensure we're operating within sandbox boundaries."""
    for d in [INPUT_DIR, OUTPUT_DIR, WORKSPACE]:
        d.mkdir(parents=True, exist_ok=True)


def find_csv_files():
    """Find all CSV files in the input directory."""
    csvs = list(INPUT_DIR.glob("*.csv"))
    if not csvs:
        print(f"No CSV files found in {INPUT_DIR}")
        print("Place your CSV files in /sandbox/input/ and try again.")
        sys.exit(0)
    return csvs


def analyze_csv(filepath: Path) -> dict:
    """Generate summary statistics for a CSV file."""
    stats = {
        "filename": filepath.name,
        "analyzed_at": datetime.now().isoformat(),
        "row_count": 0,
        "column_count": 0,
        "columns": {},
        "data_quality": {},
    }

    with open(filepath, "r", newline="") as f:
        reader = csv.DictReader(f)
        if not reader.fieldnames:
            stats["error"] = "No headers found"
            return stats

        stats["column_count"] = len(reader.fieldnames)
        col_values = defaultdict(list)
        null_counts = defaultdict(int)

        for row in reader:
            stats["row_count"] += 1
            for col in reader.fieldnames:
                val = row.get(col, "").strip()
                if val:
                    col_values[col].append(val)
                else:
                    null_counts[col] += 1

    # Per-column analysis
    for col in reader.fieldnames:
        values = col_values[col]
        col_stats = {
            "total_values": len(values),
            "null_count": null_counts[col],
            "unique_count": len(set(values)),
        }

        # Try numeric analysis
        numeric_vals = []
        for v in values:
            try:
                numeric_vals.append(float(v))
            except (ValueError, TypeError):
                pass

        if numeric_vals:
            col_stats["type"] = "numeric"
            col_stats["min"] = min(numeric_vals)
            col_stats["max"] = max(numeric_vals)
            col_stats["mean"] = sum(numeric_vals) / len(numeric_vals)
        else:
            col_stats["type"] = "text"
            col_stats["sample_values"] = list(set(values))[:5]

        stats["columns"][col] = col_stats

    # Data quality summary
    total_cells = stats["row_count"] * stats["column_count"]
    total_nulls = sum(null_counts.values())
    stats["data_quality"] = {
        "completeness_pct": round(
            (1 - total_nulls / max(total_cells, 1)) * 100, 1
        ),
        "total_null_cells": total_nulls,
    }

    return stats


def write_report(all_stats: list):
    """Write the summary report to the output directory."""
    report_path = OUTPUT_DIR / f"csv-summary-{datetime.now().strftime('%Y%m%d-%H%M%S')}.json"

    with open(report_path, "w") as f:
        json.dump(all_stats, f, indent=2)

    print(f"Report written to: {report_path}")

    # Also write a human-readable summary
    txt_path = report_path.with_suffix(".txt")
    with open(txt_path, "w") as f:
        for stats in all_stats:
            f.write(f"File: {stats['filename']}\n")
            f.write(f"Rows: {stats['row_count']} | Columns: {stats['column_count']}\n")
            f.write(
                f"Data completeness: {stats['data_quality']['completeness_pct']}%\n"
            )
            f.write("-" * 40 + "\n")
            for col, cs in stats["columns"].items():
                f.write(f"  {col} ({cs['type']}): {cs['unique_count']} unique values")
                if cs["type"] == "numeric":
                    f.write(f", range [{cs['min']} — {cs['max']}]")
                f.write("\n")
            f.write("\n")

    print(f"Text summary: {txt_path}")


def main():
    validate_paths()
    csv_files = find_csv_files()

    print(f"Found {len(csv_files)} CSV file(s) to analyze.")

    all_stats = []
    for csv_file in csv_files:
        print(f"Analyzing: {csv_file.name}")
        stats = analyze_csv(csv_file)
        all_stats.append(stats)

    write_report(all_stats)
    print("Done.")


if __name__ == "__main__":
    main()
