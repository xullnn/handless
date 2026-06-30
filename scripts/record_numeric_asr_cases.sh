#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

template="eval/asr_streaming/cases.numeric.template.jsonl"
pilot_count="$(
  python3 - "$template" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
print(sum(1 for line in path.read_text(encoding="utf-8").splitlines() if line.strip()))
PY
)"

python3 eval/asr_streaming/record_cases.py \
  --cases eval/asr_streaming/cases.numeric.local.jsonl \
  --template "$template" \
  --pilot-count "$pilot_count" \
  --out-dir eval/asr_streaming/audio/numeric \
  "$@"
