#!/usr/bin/env python3
"""Sample RSS and CPU for a local process and write structured evidence."""

from __future__ import annotations

import argparse
import json
import signal
import statistics
import subprocess
import sys
import time
from pathlib import Path
from typing import Any


stop_requested = False
stop_reason = "process_exited"


def now_ms() -> int:
    return int(time.time() * 1000)


def handle_stop(signum: int, frame: Any) -> None:
    global stop_requested, stop_reason
    stop_requested = True
    stop_reason = f"signal_{signum}"


def sample_process(pid: int) -> dict[str, Any] | None:
    result = subprocess.run(
        ["ps", "-p", str(pid), "-o", "pid=", "-o", "ppid=", "-o", "rss=", "-o", "%cpu="],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    if result.returncode != 0:
        return None
    fields = result.stdout.strip().split()
    if len(fields) < 4:
        return None
    rss_kb = int(float(fields[2]))
    cpu_percent = float(fields[3])
    if rss_kb <= 0:
        return None
    return {
        "epoch_ms": now_ms(),
        "pid": int(float(fields[0])),
        "ppid": int(float(fields[1])),
        "rss_kb": rss_kb,
        "rss_mb": rss_kb / 1024.0,
        "cpu_percent": cpu_percent,
    }


def child_pids(pid: int) -> list[int]:
    result = subprocess.run(
        ["pgrep", "-P", str(pid)],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    if result.returncode != 0:
        return []
    children: list[int] = []
    for line in result.stdout.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        try:
            child = int(stripped)
        except ValueError:
            continue
        children.append(child)
        children.extend(child_pids(child))
    return children


def sample_process_tree(pid: int) -> dict[str, Any] | None:
    pids = [pid] + child_pids(pid)
    process_samples = [sample for item in pids if (sample := sample_process(item)) is not None]
    if not process_samples:
        return None
    root = next((sample for sample in process_samples if sample["pid"] == pid), None)
    return {
        "epoch_ms": now_ms(),
        "pid": pid,
        "pids": [sample["pid"] for sample in process_samples],
        "process_count": len(process_samples),
        "rss_kb": sum(int(sample["rss_kb"]) for sample in process_samples),
        "rss_mb": sum(float(sample["rss_mb"]) for sample in process_samples),
        "cpu_percent": sum(float(sample["cpu_percent"]) for sample in process_samples),
        "root_rss_mb": root.get("rss_mb") if root else None,
        "root_cpu_percent": root.get("cpu_percent") if root else None,
        "processes": process_samples,
    }


def write_summary(
    path: Path,
    samples: list[dict[str, Any]],
    *,
    pid: int,
    label: str,
    started_epoch_ms: int,
    include_children: bool,
) -> None:
    rss_values = [float(sample["rss_mb"]) for sample in samples]
    cpu_values = [float(sample["cpu_percent"]) for sample in samples]
    finished_epoch_ms = now_ms()
    summary = {
        "schema_version": "1.0",
        "label": label,
        "pid": pid,
        "process_scope": "process_tree" if include_children else "single_process",
        "started_epoch_ms": started_epoch_ms,
        "finished_epoch_ms": finished_epoch_ms,
        "duration_seconds": (finished_epoch_ms - started_epoch_ms) / 1000.0,
        "stop_reason": stop_reason,
        "sample_count": len(samples),
        "rss_mb": {
            "peak": max(rss_values) if rss_values else None,
            "mean": statistics.mean(rss_values) if rss_values else None,
            "last": rss_values[-1] if rss_values else None,
        },
        "cpu_percent": {
            "peak": max(cpu_values) if cpu_values else None,
            "mean": statistics.mean(cpu_values) if cpu_values else None,
            "last": cpu_values[-1] if cpu_values else None,
        },
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(summary, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def command_run(args: argparse.Namespace) -> int:
    signal.signal(signal.SIGTERM, handle_stop)
    signal.signal(signal.SIGINT, handle_stop)

    samples_path = Path(args.samples)
    summary_path = Path(args.summary)
    samples_path.parent.mkdir(parents=True, exist_ok=True)
    summary_path.parent.mkdir(parents=True, exist_ok=True)
    started_epoch_ms = now_ms()
    samples: list[dict[str, Any]] = []

    with samples_path.open("w", encoding="utf-8") as handle:
        while not stop_requested:
            sample = sample_process_tree(args.pid) if args.include_children else sample_process(args.pid)
            if sample is None:
                break
            sample["label"] = args.label
            samples.append(sample)
            handle.write(json.dumps(sample, ensure_ascii=False, sort_keys=True) + "\n")
            handle.flush()
            time.sleep(max(0.1, args.interval_sec))

    write_summary(
        summary_path,
        samples,
        pid=args.pid,
        label=args.label,
        started_epoch_ms=started_epoch_ms,
        include_children=args.include_children,
    )
    print(json.dumps({"summary": str(summary_path), "sample_count": len(samples)}, ensure_ascii=False, sort_keys=True))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pid", type=int, required=True)
    parser.add_argument("--samples", required=True)
    parser.add_argument("--summary", required=True)
    parser.add_argument("--interval-sec", type=float, default=1.0)
    parser.add_argument("--label", default="process")
    parser.add_argument("--include-children", action="store_true", help="Aggregate RSS/CPU for the pid and its child processes.")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return command_run(args)
    except Exception as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
