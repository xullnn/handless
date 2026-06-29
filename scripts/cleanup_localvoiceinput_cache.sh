#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

python3 eval/asr_streaming/cleanup_localvoiceinput_cache.py "$@"
