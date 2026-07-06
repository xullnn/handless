#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG_DIR="${CONFIG_DIR:-$HOME/Library/Application Support/LocalVoiceInput}"
CONFIG_PATH="${CONFIG_PATH:-$CONFIG_DIR/config.json}"
TEMPLATE="${TEMPLATE:-configs/alpha.local-qwen3.json}"

if [ ! -f "$TEMPLATE" ]; then
  echo "Missing alpha config template: $TEMPLATE" >&2
  exit 2
fi

mkdir -p "$CONFIG_DIR"
cp "$TEMPLATE" "$CONFIG_PATH"
echo "Wrote alpha config to $CONFIG_PATH"
