#!/usr/bin/env python3
"""Compare two ASR gate summary.json files by case id."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


METRIC_EXPLANATIONS_ZH = {
    "delta_cer": "候选结果 CER 减去基准结果 CER。大于 0 表示候选更差，小于 0 表示候选更好。",
    "delta_wer": "候选结果 WER 减去基准结果 WER。大于 0 表示候选更差，小于 0 表示候选更好。",
    "delta_rtf": "候选结果 RTF 减去基准结果 RTF。该值只有在两次测试的输入节奏相同时才适合直接比较。",
    "delta_final_coverage_ratio": "候选最终文本覆盖率减去基准覆盖率。显著下降可能表示漏字或漏段。",
    "regression": "是否触发回归规则。默认规则关注 CER/WER 上升和覆盖率下降。",
}


def load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


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


def number(value: Any) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def delta(candidate: Any, baseline: Any) -> float | None:
    c = number(candidate)
    b = number(baseline)
    if c is None or b is None:
        return None
    return c - b


def mean(values: list[float | None]) -> float | None:
    nums = [value for value in values if value is not None]
    if not nums:
        return None
    return sum(nums) / len(nums)


def compare(args: argparse.Namespace) -> dict[str, Any]:
    baseline_path = Path(args.baseline)
    candidate_path = Path(args.candidate)
    baseline_summary = load_json(baseline_path)
    candidate_summary = load_json(candidate_path)
    baseline_cases = summary_cases(baseline_summary)
    candidate_cases = summary_cases(candidate_summary)
    ids = sorted(set(baseline_cases) & set(candidate_cases))
    rows: list[dict[str, Any]] = []
    regressions: list[dict[str, Any]] = []
    improvements: list[dict[str, Any]] = []

    for case_id in ids:
        base = baseline_cases[case_id]
        cand = candidate_cases[case_id]
        row = {
            "case_id": case_id,
            "scenario": cand.get("scenario", base.get("scenario")),
            "duration_seconds": cand.get("duration_seconds", base.get("duration_seconds")),
            "baseline_cer": number(base.get("cer")),
            "candidate_cer": number(cand.get("cer")),
            "delta_cer": delta(cand.get("cer"), base.get("cer")),
            "baseline_wer": number(base.get("wer")),
            "candidate_wer": number(cand.get("wer")),
            "delta_wer": delta(cand.get("wer"), base.get("wer")),
            "baseline_rtf": number(base.get("rtf")),
            "candidate_rtf": number(cand.get("rtf")),
            "delta_rtf": delta(cand.get("rtf"), base.get("rtf")),
            "baseline_final_latency_ms": number(base.get("final_latency_ms")),
            "candidate_final_latency_ms": number(cand.get("final_latency_ms")),
            "delta_final_latency_ms": delta(cand.get("final_latency_ms"), base.get("final_latency_ms")),
            "baseline_final_coverage_ratio": number(base.get("final_coverage_ratio")),
            "candidate_final_coverage_ratio": number(cand.get("final_coverage_ratio")),
            "delta_final_coverage_ratio": delta(cand.get("final_coverage_ratio"), base.get("final_coverage_ratio")),
            "baseline_gate_passed": bool(base.get("incremental_ux_gate_passed")),
            "candidate_gate_passed": bool(cand.get("incremental_ux_gate_passed")),
            "baseline_final_text": base.get("final_text"),
            "candidate_final_text": cand.get("final_text"),
        }
        reasons: list[str] = []
        if row["delta_cer"] is not None and row["delta_cer"] > args.max_cer_regression:
            reasons.append("cer_regression")
        if row["delta_wer"] is not None and row["delta_wer"] > args.max_wer_regression:
            reasons.append("wer_regression")
        if (
            row["delta_final_coverage_ratio"] is not None
            and row["delta_final_coverage_ratio"] < -args.max_coverage_drop
        ):
            reasons.append("coverage_drop")
        row["regression_reasons"] = reasons
        row["regression"] = bool(reasons)
        rows.append(row)
        if reasons:
            regressions.append(row)
        elif improvement(row):
            improvements.append(row)

    aggregate = {
        "case_count": len(rows),
        "baseline_mean_cer": mean([row["baseline_cer"] for row in rows]),
        "candidate_mean_cer": mean([row["candidate_cer"] for row in rows]),
        "delta_mean_cer": delta(
            mean([row["candidate_cer"] for row in rows]),
            mean([row["baseline_cer"] for row in rows]),
        ),
        "baseline_mean_wer": mean([row["baseline_wer"] for row in rows]),
        "candidate_mean_wer": mean([row["candidate_wer"] for row in rows]),
        "delta_mean_wer": delta(
            mean([row["candidate_wer"] for row in rows]),
            mean([row["baseline_wer"] for row in rows]),
        ),
        "baseline_mean_rtf": mean([row["baseline_rtf"] for row in rows]),
        "candidate_mean_rtf": mean([row["candidate_rtf"] for row in rows]),
        "delta_mean_rtf": delta(
            mean([row["candidate_rtf"] for row in rows]),
            mean([row["baseline_rtf"] for row in rows]),
        ),
        "baseline_mean_final_coverage_ratio": mean([row["baseline_final_coverage_ratio"] for row in rows]),
        "candidate_mean_final_coverage_ratio": mean([row["candidate_final_coverage_ratio"] for row in rows]),
        "delta_mean_final_coverage_ratio": delta(
            mean([row["candidate_final_coverage_ratio"] for row in rows]),
            mean([row["baseline_final_coverage_ratio"] for row in rows]),
        ),
        "baseline_gate_passed_count": sum(1 for row in rows if row["baseline_gate_passed"]),
        "candidate_gate_passed_count": sum(1 for row in rows if row["candidate_gate_passed"]),
    }
    return {
        "schema_version": "1.0",
        "purpose": "Compare ASR summaries case by case.",
        "metric_explanations_zh": METRIC_EXPLANATIONS_ZH,
        "baseline_summary": str(baseline_path),
        "candidate_summary": str(candidate_path),
        "regression_rule": {
            "max_cer_regression": args.max_cer_regression,
            "max_wer_regression": args.max_wer_regression,
            "max_coverage_drop": args.max_coverage_drop,
        },
        "aggregate": aggregate,
        "regression_count": len(regressions),
        "regressions": regressions,
        "improvements": improvements,
        "cases": rows,
    }


def improvement(row: dict[str, Any]) -> bool:
    return any(
        value is not None and value < 0
        for value in (row.get("delta_cer"), row.get("delta_wer"))
    )


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2, sort_keys=True)
        f.write("\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", required=True)
    parser.add_argument("--candidate", required=True)
    parser.add_argument("--out", default="")
    parser.add_argument("--max-cer-regression", type=float, default=0.02)
    parser.add_argument("--max-wer-regression", type=float, default=0.05)
    parser.add_argument("--max-coverage-drop", type=float, default=0.05)
    parser.add_argument("--fail-on-regression", action="store_true")
    args = parser.parse_args()

    report = compare(args)
    if args.out:
        write_json(Path(args.out), report)
    print(json.dumps(report, ensure_ascii=False, sort_keys=True))
    return 1 if args.fail_on_regression and report["regression_count"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
