#!/usr/bin/env python3
"""Analyze numeric-format constraints for ASR gate summaries."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


METRIC_EXPLANATIONS_ZH = {
    "numeric_format_passed": "是否满足该 case 的数字格式约束。true 表示 final_text 同时包含所有 must_include，且不包含任何 must_not_include。",
    "must_include_missing": "期望出现但没有出现在 final_text 中的片段，例如 2026、0.6B、3.5%。",
    "must_not_include_present": "不希望出现但仍出现在 final_text 中的片段，例如 二零二六、零点六 B。",
    "pass_rate": "数字格式约束通过率，通过 case 数除以总 case 数。",
}


def load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def load_cases(path: Path) -> list[dict[str, Any]]:
    cases: list[dict[str, Any]] = []
    with path.open("r", encoding="utf-8") as f:
        for lineno, line in enumerate(f, start=1):
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue
            obj = json.loads(stripped)
            obj["_lineno"] = lineno
            cases.append(obj)
    return cases


def summary_cases(summary: dict[str, Any]) -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}
    for item in summary.get("cases", []):
        case_id = str(item.get("case_id", "")).strip()
        if case_id:
            result[case_id] = item
    for item in summary.get("case_summaries", []):
        case_id = str(item.get("case_id", "")).strip()
        if case_id and case_id not in result:
            result[case_id] = item
    return result


def analyze(cases_path: Path, summary_path: Path) -> dict[str, Any]:
    cases = load_cases(cases_path)
    summary = load_json(summary_path)
    by_case = summary_cases(summary)
    rows: list[dict[str, Any]] = []
    scenario_counts: dict[str, dict[str, int]] = {}
    focus_counts: dict[str, dict[str, int]] = {}

    for case in cases:
        case_id = str(case["id"])
        result = by_case.get(case_id, {})
        final_text = str(result.get("final_text", ""))
        must_include = [str(value) for value in case.get("must_include", [])]
        must_not_include = [str(value) for value in case.get("must_not_include", [])]
        missing = [value for value in must_include if value not in final_text]
        forbidden = [value for value in must_not_include if value in final_text]
        passed = not missing and not forbidden and bool(result)
        row = {
            "case_id": case_id,
            "scenario": case.get("scenario"),
            "format_focus": case.get("format_focus"),
            "preferred_text": case.get("preferred_text"),
            "expected_text": case.get("text"),
            "final_text": final_text,
            "numeric_format_passed": passed,
            "must_include": must_include,
            "must_not_include": must_not_include,
            "must_include_missing": missing,
            "must_not_include_present": forbidden,
            "source_summary_case_found": bool(result),
        }
        rows.append(row)
        bump(scenario_counts, str(case.get("scenario", "unknown")), passed)
        bump(focus_counts, str(case.get("format_focus", "unknown")), passed)

    passed_count = sum(1 for row in rows if row["numeric_format_passed"])
    failed_rows = [row for row in rows if not row["numeric_format_passed"]]
    return {
        "schema_version": "1.0",
        "purpose": "Evaluate numeric-format preference constraints separately from CER/WER.",
        "metric_explanations_zh": METRIC_EXPLANATIONS_ZH,
        "cases": str(cases_path),
        "summary": str(summary_path),
        "case_count": len(rows),
        "passed_count": passed_count,
        "failed_count": len(rows) - passed_count,
        "pass_rate": (passed_count / len(rows)) if rows else None,
        "scenario_counts": scenario_counts,
        "format_focus_counts": focus_counts,
        "failed_cases": failed_rows,
        "case_results": rows,
    }


def bump(counts: dict[str, dict[str, int]], key: str, passed: bool) -> None:
    bucket = counts.setdefault(key, {"total": 0, "passed": 0, "failed": 0})
    bucket["total"] += 1
    if passed:
        bucket["passed"] += 1
    else:
        bucket["failed"] += 1


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2, sort_keys=True)
        f.write("\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cases", required=True)
    parser.add_argument("--summary", required=True)
    parser.add_argument("--out", default="")
    args = parser.parse_args()

    report = analyze(Path(args.cases), Path(args.summary))
    if args.out:
        write_json(Path(args.out), report)
    print(json.dumps(report, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
