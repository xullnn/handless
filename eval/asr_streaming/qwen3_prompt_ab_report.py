#!/usr/bin/env python3
"""Generate a Qwen3 0.6B prompt-vs-no-prompt ASR A/B report."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


def load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2, sort_keys=True)
        f.write("\n")


def pct(value: float | None) -> str:
    if value is None:
        return "n/a"
    return f"{value * 100:.1f}%"


def num(value: float | None, digits: int = 4) -> str:
    if value is None:
        return "n/a"
    return f"{value:.{digits}f}"


def ms(value: float | None) -> str:
    if value is None:
        return "n/a"
    return f"{value:.1f} ms"


def aggregate(summary_path: Path) -> dict[str, Any]:
    data = load_json(summary_path)
    return data.get("aggregate_metrics", {})


def changed_numeric_cases(no_prompt: dict[str, Any], prompt: dict[str, Any]) -> list[dict[str, Any]]:
    base = {row["case_id"]: row for row in no_prompt.get("case_results", [])}
    rows: list[dict[str, Any]] = []
    for row in prompt.get("case_results", []):
        before = base.get(row["case_id"])
        if not before:
            continue
        if before.get("numeric_format_passed") != row.get("numeric_format_passed"):
            rows.append(
                {
                    "case_id": row["case_id"],
                    "scenario": row.get("scenario"),
                    "no_prompt_passed": before.get("numeric_format_passed"),
                    "prompt_passed": row.get("numeric_format_passed"),
                    "no_prompt_text": before.get("final_text"),
                    "prompt_text": row.get("final_text"),
                    "must_include_missing_after_prompt": row.get("must_include_missing", []),
                    "must_not_include_present_after_prompt": row.get("must_not_include_present", []),
                }
            )
    return rows


def build_report(args: argparse.Namespace) -> dict[str, Any]:
    no_prompt_numeric = load_json(Path(args.no_prompt_numeric_analysis))
    prompt_numeric = load_json(Path(args.prompt_numeric_analysis))
    numeric_compare = load_json(Path(args.numeric_comparison))
    base_compare = load_json(Path(args.base_comparison))
    no_prompt_numeric_summary = aggregate(Path(args.no_prompt_numeric_summary))
    prompt_numeric_summary = aggregate(Path(args.prompt_numeric_summary))
    no_prompt_base_summary = aggregate(Path(args.no_prompt_base_summary))
    prompt_base_summary = aggregate(Path(args.prompt_base_summary))

    changed_cases = changed_numeric_cases(no_prompt_numeric, prompt_numeric)
    improved_cases = [row for row in changed_cases if row["prompt_passed"] and not row["no_prompt_passed"]]
    worsened_cases = [row for row in changed_cases if row["no_prompt_passed"] and not row["prompt_passed"]]

    numeric_pass_delta = prompt_numeric["pass_rate"] - no_prompt_numeric["pass_rate"]
    base_delta_cer = base_compare["aggregate"].get("delta_mean_cer")
    base_delta_wer = base_compare["aggregate"].get("delta_mean_wer")
    base_delta_first_partial = (
        prompt_base_summary.get("mean_first_partial_latency_ms")
        - no_prompt_base_summary.get("mean_first_partial_latency_ms")
        if prompt_base_summary.get("mean_first_partial_latency_ms") is not None
        and no_prompt_base_summary.get("mean_first_partial_latency_ms") is not None
        else None
    )
    numeric_delta_first_partial = (
        prompt_numeric_summary.get("mean_first_partial_latency_ms")
        - no_prompt_numeric_summary.get("mean_first_partial_latency_ms")
        if prompt_numeric_summary.get("mean_first_partial_latency_ms") is not None
        and no_prompt_numeric_summary.get("mean_first_partial_latency_ms") is not None
        else None
    )

    recommendation = "do_not_enable_prompt_by_default"
    rationale = [
        "数字格式通过率有提升，但绝对通过率仍然偏低。",
        "提示词明显增加 numeric 和 base 两个 suite 的首个 partial 延迟。",
        "基础 suite 的 CER/WER 没有回退，因此提示词可以保留为实验依据，但不适合作为默认产品路径。",
    ]
    if prompt_numeric["pass_rate"] >= 0.8 and base_delta_first_partial is not None and base_delta_first_partial < 300:
        recommendation = "candidate_for_default_prompt"
        rationale = ["数字格式通过率足够高，且基础识别延迟影响可控。"]

    return {
        "schema_version": "1.0",
        "purpose": "Qwen3 0.6B segmented system-prompt versus no-prompt A/B comparison.",
        "model_id": "qwen3-asr-0.6b-mlx-8bit",
        "prompt_file": args.prompt_file,
        "inputs": {
            "no_prompt_numeric_summary": args.no_prompt_numeric_summary,
            "prompt_numeric_summary": args.prompt_numeric_summary,
            "no_prompt_base_summary": args.no_prompt_base_summary,
            "prompt_base_summary": args.prompt_base_summary,
            "no_prompt_numeric_analysis": args.no_prompt_numeric_analysis,
            "prompt_numeric_analysis": args.prompt_numeric_analysis,
            "numeric_comparison": args.numeric_comparison,
            "base_comparison": args.base_comparison,
        },
        "numeric_format": {
            "case_count": no_prompt_numeric["case_count"],
            "no_prompt_passed": no_prompt_numeric["passed_count"],
            "prompt_passed": prompt_numeric["passed_count"],
            "no_prompt_pass_rate": no_prompt_numeric["pass_rate"],
            "prompt_pass_rate": prompt_numeric["pass_rate"],
            "delta_pass_rate": numeric_pass_delta,
            "improved_case_count": len(improved_cases),
            "worsened_case_count": len(worsened_cases),
            "improved_cases": improved_cases,
            "worsened_cases": worsened_cases,
        },
        "numeric_suite_quality_notes": {
            "note": "Numeric-suite CER/WER are computed against spoken-form references, so desired Arabic-number formatting can increase CER/WER. Use numeric pass rate as the primary numeric-suite metric.",
            "no_prompt_mean_cer": no_prompt_numeric_summary.get("mean_cer"),
            "prompt_mean_cer": prompt_numeric_summary.get("mean_cer"),
            "no_prompt_mean_wer": no_prompt_numeric_summary.get("mean_wer"),
            "prompt_mean_wer": prompt_numeric_summary.get("mean_wer"),
            "no_prompt_first_partial_ms": no_prompt_numeric_summary.get("mean_first_partial_latency_ms"),
            "prompt_first_partial_ms": prompt_numeric_summary.get("mean_first_partial_latency_ms"),
            "delta_first_partial_ms": numeric_delta_first_partial,
        },
        "base_regression_guard": {
            "case_count": base_compare["aggregate"].get("case_count"),
            "regression_count": base_compare.get("regression_count"),
            "no_prompt_mean_cer": no_prompt_base_summary.get("mean_cer"),
            "prompt_mean_cer": prompt_base_summary.get("mean_cer"),
            "delta_mean_cer": base_delta_cer,
            "no_prompt_mean_wer": no_prompt_base_summary.get("mean_wer"),
            "prompt_mean_wer": prompt_base_summary.get("mean_wer"),
            "delta_mean_wer": base_delta_wer,
            "no_prompt_first_partial_ms": no_prompt_base_summary.get("mean_first_partial_latency_ms"),
            "prompt_first_partial_ms": prompt_base_summary.get("mean_first_partial_latency_ms"),
            "delta_first_partial_ms": base_delta_first_partial,
        },
        "recommendation": {
            "status": recommendation,
            "rationale": rationale,
            "next_step": "先实现保守的本地数字 ITN / 后处理层，再考虑是否需要默认提示词。",
        },
    }


def write_markdown(path: Path, report: dict[str, Any]) -> None:
    numeric = report["numeric_format"]
    numeric_notes = report["numeric_suite_quality_notes"]
    base = report["base_regression_guard"]
    rec = report["recommendation"]
    improved = numeric["improved_cases"][:10]
    worsened = numeric["worsened_cases"][:10]

    lines = [
        "# Qwen3 0.6B Prompt vs No-Prompt A/B Report",
        "",
        "## 结论",
        "",
        "- 不建议把当前数字风格系统提示词默认开启。",
        "- 提示词确实改善了一部分数字格式，但绝对通过率仍然很低。",
        "- 基础识别没有明显质量回退，但首个 partial 延迟明显增加。",
        "- 数字格式问题仍应优先进入本地 ITN / 数字规整后处理路线。",
        "",
        "## 测试对象",
        "",
        "- 模型：`qwen3-asr-0.6b-mlx-8bit`",
        "- 路线：segmented simulated realtime",
        f"- 提示词文件：`{report['prompt_file']}`",
        "- 主测试：`cases.numeric.local.jsonl` 37 条",
        "- 回归护栏：`cases.local.jsonl` 10 条",
        "",
        "## 数字格式结果",
        "",
        "| 条件 | 通过数 | 总数 | 通过率 |",
        "|---|---:|---:|---:|",
        f"| no-prompt | {numeric['no_prompt_passed']} | {numeric['case_count']} | {pct(numeric['no_prompt_pass_rate'])} |",
        f"| prompt | {numeric['prompt_passed']} | {numeric['case_count']} | {pct(numeric['prompt_pass_rate'])} |",
        f"| delta | +{numeric['prompt_passed'] - numeric['no_prompt_passed']} | - | {pct(numeric['delta_pass_rate'])} |",
        "",
        f"- 改善 case 数：`{numeric['improved_case_count']}`",
        f"- 变差 case 数：`{numeric['worsened_case_count']}`",
        "",
        "注意：numeric suite 的 CER/WER 是按口语参考文本计算的，所以当提示词把“零点二零八”改成 `0.208` 时，CER/WER 可能上升。这里数字格式通过率是主指标。",
        "",
        "## 数字 Suite 延迟与质量信号",
        "",
        "| 条件 | CER | WER | first partial |",
        "|---|---:|---:|---:|",
        f"| no-prompt | {num(numeric_notes['no_prompt_mean_cer'])} | {num(numeric_notes['no_prompt_mean_wer'])} | {ms(numeric_notes['no_prompt_first_partial_ms'])} |",
        f"| prompt | {num(numeric_notes['prompt_mean_cer'])} | {num(numeric_notes['prompt_mean_wer'])} | {ms(numeric_notes['prompt_first_partial_ms'])} |",
        f"| delta | {num((numeric_notes['prompt_mean_cer'] or 0) - (numeric_notes['no_prompt_mean_cer'] or 0))} | {num((numeric_notes['prompt_mean_wer'] or 0) - (numeric_notes['no_prompt_mean_wer'] or 0))} | {ms(numeric_notes['delta_first_partial_ms'])} |",
        "",
        "## 基础识别回归护栏",
        "",
        "| 条件 | CER | WER | first partial |",
        "|---|---:|---:|---:|",
        f"| no-prompt | {num(base['no_prompt_mean_cer'])} | {num(base['no_prompt_mean_wer'])} | {ms(base['no_prompt_first_partial_ms'])} |",
        f"| prompt | {num(base['prompt_mean_cer'])} | {num(base['prompt_mean_wer'])} | {ms(base['prompt_first_partial_ms'])} |",
        f"| delta | {num(base['delta_mean_cer'])} | {num(base['delta_mean_wer'])} | {ms(base['delta_first_partial_ms'])} |",
        "",
        f"- 基础 suite 回归数：`{base['regression_count']}`",
        "",
        "## 改善样例",
        "",
    ]
    if improved:
        lines.extend(["| case | no-prompt | prompt |", "|---|---|---|"])
        for row in improved:
            lines.append(f"| `{row['case_id']}` | {row['no_prompt_text']} | {row['prompt_text']} |")
    else:
        lines.append("- 无")
    lines.extend(["", "## 变差样例", ""])
    if worsened:
        lines.extend(["| case | no-prompt | prompt |", "|---|---|---|"])
        for row in worsened:
            lines.append(f"| `{row['case_id']}` | {row['no_prompt_text']} | {row['prompt_text']} |")
    else:
        lines.append("- 无")
    lines.extend(
        [
            "",
            "## 推荐",
            "",
            f"- 状态：`{rec['status']}`",
            *[f"- {item}" for item in rec["rationale"]],
            f"- 下一步：{rec['next_step']}",
            "",
        ]
    )
    path.write_text("\n".join(lines), encoding="utf-8")


def write_recommendation(path: Path, report: dict[str, Any]) -> None:
    numeric = report["numeric_format"]
    base = report["base_regression_guard"]
    rec = report["recommendation"]
    lines = [
        "# Qwen3 0.6B Prompt A/B Recommendation",
        "",
        "## 最终建议",
        "",
        "- 当前数字风格系统提示词不建议默认开启。",
        "- 保持 no-prompt 作为当前默认实时 ASR 路线。",
        "- 数字格式问题继续走本地 ITN / 数字规整后处理方向。",
        "",
        "## 依据",
        "",
        f"- 数字格式通过率从 `{pct(numeric['no_prompt_pass_rate'])}` 提升到 `{pct(numeric['prompt_pass_rate'])}`，但仍只有 `{numeric['prompt_passed']}/{numeric['case_count']}` 通过。",
        f"- 基础 suite 回归数为 `{base['regression_count']}`，说明普通识别质量没有明显被破坏。",
        f"- 基础 suite 首个 partial 延迟增加 `{ms(base['delta_first_partial_ms'])}`，对实时浮窗体验不利。",
        "",
        "## 后续",
        "",
        f"- 状态：`{rec['status']}`",
        *[f"- {item}" for item in rec["rationale"]],
        f"- 下一步：{rec['next_step']}",
        "",
    ]
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--prompt-file", required=True)
    parser.add_argument("--no-prompt-numeric-summary", required=True)
    parser.add_argument("--prompt-numeric-summary", required=True)
    parser.add_argument("--no-prompt-base-summary", required=True)
    parser.add_argument("--prompt-base-summary", required=True)
    parser.add_argument("--no-prompt-numeric-analysis", required=True)
    parser.add_argument("--prompt-numeric-analysis", required=True)
    parser.add_argument("--numeric-comparison", required=True)
    parser.add_argument("--base-comparison", required=True)
    args = parser.parse_args()

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    report = build_report(args)
    write_json(out_dir / "comparison.json", report)
    write_markdown(out_dir / "comparison.md", report)
    write_recommendation(out_dir / "recommendation.md", report)
    print(json.dumps(report, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
