#!/usr/bin/env python3
"""Build a raw-vs-ITN numeric-format comparison report."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


def load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def case_map(report: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {str(row["case_id"]): row for row in report.get("case_results", [])}


def build_report(raw_path: Path, itn_path: Path, out_json: Path, out_md: Path) -> dict[str, Any]:
    raw = load_json(raw_path)
    itn = load_json(itn_path)
    raw_cases = case_map(raw)
    itn_cases = case_map(itn)
    ids = sorted(set(raw_cases) & set(itn_cases))

    rows: list[dict[str, Any]] = []
    improved: list[dict[str, Any]] = []
    worsened: list[dict[str, Any]] = []
    unchanged_failed: list[dict[str, Any]] = []

    for case_id in ids:
        before = raw_cases[case_id]
        after = itn_cases[case_id]
        row = {
            "case_id": case_id,
            "scenario": after.get("scenario"),
            "format_focus": after.get("format_focus"),
            "raw_passed": before.get("numeric_format_passed"),
            "itn_passed": after.get("numeric_format_passed"),
            "raw_final_text": before.get("final_text"),
            "itn_final_text": after.get("final_text"),
            "raw_missing": before.get("must_include_missing", []),
            "itn_missing": after.get("must_include_missing", []),
            "raw_forbidden": before.get("must_not_include_present", []),
            "itn_forbidden": after.get("must_not_include_present", []),
        }
        rows.append(row)
        if not row["raw_passed"] and row["itn_passed"]:
            improved.append(row)
        elif row["raw_passed"] and not row["itn_passed"]:
            worsened.append(row)
        elif not row["itn_passed"]:
            unchanged_failed.append(row)

    raw_rate = raw.get("pass_rate")
    itn_rate = itn.get("pass_rate")
    report = {
        "schema_version": "1.0",
        "purpose": "Compare numeric-format pass rate before and after local NumericITN, separate from ASR CER/WER.",
        "raw_analysis": str(raw_path),
        "itn_analysis": str(itn_path),
        "case_count": len(rows),
        "raw_passed_count": raw.get("passed_count"),
        "itn_passed_count": itn.get("passed_count"),
        "raw_pass_rate": raw_rate,
        "itn_pass_rate": itn_rate,
        "delta_pass_rate": (itn_rate - raw_rate) if raw_rate is not None and itn_rate is not None else None,
        "improved_count": len(improved),
        "worsened_count": len(worsened),
        "unchanged_failed_count": len(unchanged_failed),
        "improved_cases": improved,
        "worsened_cases": worsened,
        "unchanged_failed_cases": unchanged_failed,
        "cases": rows,
        "notes": [
            "Numeric-format pass rate is the primary ITN metric.",
            "ASR CER/WER are intentionally not recomputed here because raw references are spoken-form Chinese and can make useful Arabic-digit output look worse."
        ],
    }

    write_json(out_json, report)
    write_markdown(out_md, report)
    return report


def percent(value: float | None) -> str:
    if value is None:
        return "n/a"
    return f"{value * 100:.1f}%"


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2, sort_keys=True)
        f.write("\n")


def write_markdown(path: Path, report: dict[str, Any]) -> None:
    lines = [
        "# Simple Numeric ITN Report",
        "",
        "## Summary",
        "",
        "| Condition | Passed | Total | Pass rate |",
        "|---|---:|---:|---:|",
        f"| Raw ASR final text | {report['raw_passed_count']} | {report['case_count']} | {percent(report['raw_pass_rate'])} |",
        f"| NumericITN final text | {report['itn_passed_count']} | {report['case_count']} | {percent(report['itn_pass_rate'])} |",
        f"| Delta | +{report['itn_passed_count'] - report['raw_passed_count']} | - | {percent(report['delta_pass_rate'])} |",
        "",
        f"- Improved cases: `{report['improved_count']}`",
        f"- Worsened cases: `{report['worsened_count']}`",
        f"- Still failing cases: `{report['unchanged_failed_count']}`",
        "",
        "CER/WER are not recomputed in this report. Numeric-format pass rate is the primary ITN metric because the reference text is spoken-form Chinese.",
    ]

    if report["improved_cases"]:
        lines += [
            "",
            "## Improved Cases",
            "",
            "| Case | Raw final | ITN final |",
            "|---|---|---|",
        ]
        for row in report["improved_cases"]:
            lines.append(f"| `{row['case_id']}` | {row['raw_final_text']} | {row['itn_final_text']} |")

    if report["worsened_cases"]:
        lines += [
            "",
            "## Worsened Cases",
            "",
            "| Case | Raw final | ITN final |",
            "|---|---|---|",
        ]
        for row in report["worsened_cases"]:
            lines.append(f"| `{row['case_id']}` | {row['raw_final_text']} | {row['itn_final_text']} |")

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--raw-analysis", required=True)
    parser.add_argument("--itn-analysis", required=True)
    parser.add_argument("--out-json", required=True)
    parser.add_argument("--out-md", required=True)
    args = parser.parse_args()

    report = build_report(
        raw_path=Path(args.raw_analysis),
        itn_path=Path(args.itn_analysis),
        out_json=Path(args.out_json),
        out_md=Path(args.out_md),
    )
    print(json.dumps(report, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
