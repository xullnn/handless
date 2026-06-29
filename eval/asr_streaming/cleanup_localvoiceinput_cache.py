#!/usr/bin/env python3
"""Safely inspect and clean LocalVoiceInput local ASR cache artifacts.

This tool intentionally does not delete model caches. It targets generated
runtime artifacts such as segmented-cache spool directories, manual smoke logs,
Python caches, and optionally local eval audio recordings.
"""

from __future__ import annotations

import argparse
import json
import shutil
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any


MODEL_CACHE_PARTS = {".external", "models"}


@dataclass(frozen=True)
class Candidate:
    path: Path
    reason: str
    bytes: int
    mtime: float

    def public_dict(self, *, root: Path, selected: bool) -> dict[str, Any]:
        return {
            "path": str(self.path.relative_to(root) if self.path.is_relative_to(root) else self.path),
            "reason": self.reason,
            "bytes": self.bytes,
            "mtime_epoch": int(self.mtime),
            "selected": selected,
        }


def path_size(path: Path) -> int:
    if path.is_file() or path.is_symlink():
        return path.lstat().st_size
    total = 0
    for child in path.rglob("*"):
        if child.is_file() or child.is_symlink():
            total += child.lstat().st_size
    return total


def is_under_model_cache(path: Path, root: Path) -> bool:
    try:
        relative_parts = path.resolve().relative_to(root.resolve()).parts
    except ValueError:
        return False
    return len(relative_parts) >= 2 and relative_parts[0] == ".external" and relative_parts[1] == "models"


def candidate_reason(path: Path, root: Path, *, include_eval_audio: bool) -> str | None:
    if is_under_model_cache(path, root):
        return None
    try:
        relative = path.relative_to(root)
    except ValueError:
        return None
    parts = relative.parts
    name = path.name

    if name == "__pycache__" and path.is_dir():
        return "python_cache"
    if len(parts) >= 4 and parts[:3] == ("eval", "asr_streaming", "results"):
        if name.endswith("-spool") or name == "spool":
            return "asr_spool"
        if name.startswith("manual-use-"):
            return "manual_smoke_runtime"
    if include_eval_audio and len(parts) >= 3 and parts[:3] == ("eval", "asr_streaming", "audio"):
        if path.is_file() and path.suffix.lower() in {".wav", ".m4a", ".aiff", ".caf", ".flac"}:
            return "eval_audio"
    return None


def collect_candidates(root: Path, *, include_eval_audio: bool) -> list[Candidate]:
    candidates: list[Candidate] = []
    scan_roots = [
        root / "eval" / "asr_streaming" / "results",
        root / "eval" / "asr_streaming" / "audio",
        root / "eval" / "asr_streaming",
    ]
    seen: set[Path] = set()
    for scan_root in scan_roots:
        if not scan_root.exists():
            continue
        for path in scan_root.rglob("*"):
            resolved = path.resolve()
            if resolved in seen:
                continue
            reason = candidate_reason(path, root, include_eval_audio=include_eval_audio)
            if reason is None:
                continue
            seen.add(resolved)
            candidates.append(
                Candidate(
                    path=path,
                    reason=reason,
                    bytes=path_size(path),
                    mtime=path.stat().st_mtime,
                )
            )
    return sorted(candidates, key=lambda item: (item.mtime, str(item.path)))


def select_deletions(
    candidates: list[Candidate],
    *,
    now: float,
    max_age_hours: float | None,
    max_bytes: int | None,
) -> set[Path]:
    selected: set[Path] = set()
    if max_age_hours is not None:
        cutoff = now - max_age_hours * 3600.0
        for candidate in candidates:
            if candidate.mtime <= cutoff:
                selected.add(candidate.path)

    if max_bytes is not None:
        remaining = sum(candidate.bytes for candidate in candidates if candidate.path not in selected)
        for candidate in candidates:
            if remaining <= max_bytes:
                break
            if candidate.path in selected:
                continue
            selected.add(candidate.path)
            remaining -= candidate.bytes
    return selected


def apply_deletions(paths: set[Path], *, root: Path) -> list[str]:
    deleted: list[str] = []
    for path in sorted(paths, key=lambda item: len(item.parts), reverse=True):
        if is_under_model_cache(path, root):
            raise RuntimeError(f"refusing to delete model cache path: {path}")
        if not path.exists():
            continue
        if path.is_dir() and not path.is_symlink():
            shutil.rmtree(path)
        else:
            path.unlink()
        deleted.append(str(path.relative_to(root) if path.is_relative_to(root) else path))
    return deleted


def cleanup(
    *,
    root: Path,
    apply: bool,
    max_age_hours: float | None,
    max_bytes: int | None,
    include_eval_audio: bool,
    now: float | None = None,
) -> dict[str, Any]:
    root = root.resolve()
    candidates = collect_candidates(root, include_eval_audio=include_eval_audio)
    selected = select_deletions(
        candidates,
        now=time.time() if now is None else now,
        max_age_hours=max_age_hours,
        max_bytes=max_bytes,
    )
    deleted = apply_deletions(selected, root=root) if apply else []
    selected_bytes = sum(candidate.bytes for candidate in candidates if candidate.path in selected)
    return {
        "schema_version": "1.0",
        "root": str(root),
        "mode": "apply" if apply else "dry-run",
        "include_eval_audio": include_eval_audio,
        "max_age_hours": max_age_hours,
        "max_bytes": max_bytes,
        "candidate_count": len(candidates),
        "selected_count": len(selected),
        "selected_bytes": selected_bytes,
        "deleted_count": len(deleted),
        "deleted": deleted,
        "candidates": [
            candidate.public_dict(root=root, selected=candidate.path in selected)
            for candidate in candidates
        ],
        "model_cache_protected": True,
    }


def command_self_test() -> int:
    with tempfile.TemporaryDirectory(prefix="localvoiceinput-cleanup-test-") as tmp:
        root = Path(tmp)
        spool = root / "eval" / "asr_streaming" / "results" / "case-spool"
        manual = root / "eval" / "asr_streaming" / "results" / "manual-use-test"
        audio = root / "eval" / "asr_streaming" / "audio" / "sample.wav"
        model = root / ".external" / "models" / "must-keep" / "weights.bin"
        pycache = root / "eval" / "asr_streaming" / "__pycache__"
        for directory in [spool, manual, audio.parent, model.parent, pycache]:
            directory.mkdir(parents=True, exist_ok=True)
        (spool / "session.f32le").write_bytes(b"x" * 100)
        (manual / "service.log").write_text("log", encoding="utf-8")
        audio.write_bytes(b"w" * 100)
        model.write_bytes(b"m" * 100)
        (pycache / "cache.pyc").write_bytes(b"p" * 100)

        dry = cleanup(
            root=root,
            apply=False,
            max_age_hours=None,
            max_bytes=50,
            include_eval_audio=False,
            now=time.time(),
        )
        selected_paths = {item["path"] for item in dry["candidates"] if item["selected"]}
        if "eval/asr_streaming/audio/sample.wav" in selected_paths:
            raise AssertionError(f"eval audio should be opt-in: {dry}")
        if any(".external/models" in item["path"] for item in dry["candidates"]):
            raise AssertionError(f"model cache path must not be a cleanup candidate: {dry}")
        if dry["mode"] != "dry-run" or dry["deleted_count"] != 0:
            raise AssertionError(f"dry-run deleted files: {dry}")

        applied = cleanup(
            root=root,
            apply=True,
            max_age_hours=0,
            max_bytes=None,
            include_eval_audio=True,
            now=time.time(),
        )
        if applied["deleted_count"] < 4:
            raise AssertionError(f"apply did not delete expected generated artifacts: {applied}")
        if not model.exists():
            raise AssertionError("model cache file was deleted")
        if spool.exists() or manual.exists() or audio.exists() or pycache.exists():
            raise AssertionError(f"generated artifacts remained after apply: {applied}")

    print("LocalVoiceInput cache cleanup self-test passed.")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".", help="Project root. Defaults to current directory.")
    parser.add_argument("--apply", action="store_true", help="Delete selected candidates. Without this flag, dry-run only.")
    parser.add_argument("--dry-run", action="store_true", help="Explicit dry-run mode; this is the default.")
    parser.add_argument("--max-age-hours", type=float, default=24.0, help="Select candidates older than this many hours. Use -1 to disable age selection.")
    parser.add_argument("--max-bytes", type=int, default=None, help="Select oldest candidates until generated cache is at or under this byte budget.")
    parser.add_argument("--include-eval-audio", action="store_true", help="Also consider eval/asr_streaming/audio recordings. Off by default.")
    parser.add_argument("command", nargs="?", default="run", choices=["run", "self-test"])
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.command == "self-test":
        return command_self_test()
    max_age_hours = None if args.max_age_hours < 0 else args.max_age_hours
    summary = cleanup(
        root=Path(args.root),
        apply=bool(args.apply),
        max_age_hours=max_age_hours,
        max_bytes=args.max_bytes,
        include_eval_audio=bool(args.include_eval_audio),
    )
    print(json.dumps(summary, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
