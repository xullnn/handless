#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="LocalVoiceInput"
PRODUCT="LocalVoiceInputMac"
VERSION="${VERSION:-0.1.0-alpha}"
DIST_DIR="$PWD/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
STAGE_ROOT="${STAGE_ROOT:-$DIST_DIR/closed-alpha-runtime-staging}"
DMG_ROOT="$DIST_DIR/closed-alpha-dmg-root"
DMG_PATH="${DMG_PATH:-$DIST_DIR/$APP_NAME-$VERSION-closed-alpha-unnotarized.dmg}"
VOLNAME="${VOLNAME:-$APP_NAME Closed Alpha}"
VERIFY_HOST="${VERIFY_HOST:-127.0.0.1}"
VERIFY_PORT="${VERIFY_PORT:-18196}"
MODE="preflight"

MODEL_SRC="$PWD/.external/models/mlx-community__Qwen3-ASR-0.6B-8bit"
RUNTIME_SRC="$PWD/.venv-mimo"
MLX_AUDIO_SRC="$PWD/.external/repos/mlx-audio"
CONFIG_SRC="$PWD/configs/alpha.local-qwen3.json"
SERVICE_SRC_DIR="$PWD/eval/asr_streaming"

PYTHON_STAGE="$STAGE_ROOT/python"
MODEL_STAGE="$STAGE_ROOT/models/qwen3-asr-0.6b-mlx-8bit"
MLX_AUDIO_STAGE="$STAGE_ROOT/repos/mlx-audio"
SERVICE_STAGE="$STAGE_ROOT/services/asr_streaming"
CONFIG_STAGE="$STAGE_ROOT/config/alpha.local-qwen3.json"
NOTICE_STAGE="$STAGE_ROOT/NOTICE"
MANIFEST_STAGE="$STAGE_ROOT/MANIFEST.txt"
CHECKSUM_STAGE="$STAGE_ROOT/SHA256SUMS.txt"
VAR_STAGE="$STAGE_ROOT/var"

usage() {
  cat <<'EOF'
Usage: bash scripts/package_macos_alpha.sh [mode]

Closed-alpha modes:
  --preflight              Report local closed-alpha inputs and tools.
  --dry-run                Print the closed-alpha packaging sequence.
  --stage-runtime          Copy the allowlisted runtime/model/service assets.
  --verify-staged-runtime  Start the staged Qwen3 service outside the repo.
  --closed-alpha           Build the self-contained unnotarized closed-alpha DMG.

Future formal distribution mode:
  --developer-id           Reserved for Developer ID signed/notarized distribution.

This Phase 1 artifact is intentionally unnotarized. It is only for trusted
closed-alpha testers who can manually approve first launch in macOS Privacy &
Security. It must not be described as a public or Apple-notarized build.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --preflight) MODE="preflight" ;;
    --dry-run) MODE="dry-run" ;;
    --stage-runtime) MODE="stage-runtime" ;;
    --verify-staged-runtime) MODE="verify-staged-runtime" ;;
    --closed-alpha) MODE="closed-alpha" ;;
    --developer-id) MODE="developer-id" ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

tool_status() {
  local tool="$1"
  if command -v "$tool" >/dev/null 2>&1; then
    printf '%s: ok %s\n' "$tool" "$(command -v "$tool")"
  else
    printf '%s: missing\n' "$tool"
  fi
}

require_tool() {
  local tool="$1"
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Missing required tool: $tool" >&2
    exit 2
  fi
}

copy_tree() {
  local src="$1"
  local dst="$2"
  rm -rf "$dst"
  mkdir -p "$(dirname "$dst")"
  if command -v ditto >/dev/null 2>&1; then
    ditto "$src" "$dst"
  else
    cp -R "$src" "$dst"
  fi
}

ensure_inputs() {
  local missing=0
  for path in "$MODEL_SRC" "$RUNTIME_SRC" "$MLX_AUDIO_SRC" "$CONFIG_SRC"; do
    if [ ! -e "$path" ]; then
      echo "Missing required alpha input: $path" >&2
      missing=1
    fi
  done
  for path in \
    "$SERVICE_SRC_DIR/qwen3_mlx_segmented_cache_service.py" \
    "$SERVICE_SRC_DIR/qwen3_mlx_service_common.py" \
    "$SERVICE_SRC_DIR/qwen3_mlx_realtime_probe.py" \
    "$SERVICE_SRC_DIR/run_eval.py" \
    "$SERVICE_SRC_DIR/model_registry.json"; do
    if [ ! -f "$path" ]; then
      echo "Missing required service file: $path" >&2
      missing=1
    fi
  done
  if [ "$missing" != "0" ]; then
    exit 2
  fi
}

print_size() {
  local label="$1"
  local path="$2"
  du -sh "$path" 2>/dev/null | awk -v label="$label" '{print label ": " $1}' || echo "$label: missing"
}

print_status() {
  echo "== Tools =="
  tool_status swift
  tool_status codesign
  tool_status security
  tool_status hdiutil
  tool_status shasum
  tool_status ditto

  echo
  echo "== Closed Alpha Inputs =="
  print_size "app_size" "$APP_DIR"
  print_size "qwen3_0_6b_model_size" "$MODEL_SRC"
  print_size "python_runtime_size" "$RUNTIME_SRC"
  print_size "mlx_audio_source_size" "$MLX_AUDIO_SRC"
  print_size "all_model_cache_size_not_bundled" "$PWD/.external/models"
  print_size "asr_logs_not_bundled" "$PWD/asr_logs"

  echo
  echo "== Signing =="
  if command -v security >/dev/null 2>&1; then
    security find-identity -p codesigning -v | sed 's/^/  /' || true
  else
    echo "  security tool missing"
  fi

  echo
  echo "== Phase =="
  echo "artifact_kind: unnotarized closed alpha DMG"
  echo "developer_id_required: no"
  echo "notarization_required: no"
  echo "gatekeeper_open_anyway_expected: yes"
}

write_notice_files() {
  rm -rf "$NOTICE_STAGE"
  mkdir -p "$NOTICE_STAGE"
  {
    echo "LocalVoiceInput Closed Alpha Notices"
    echo
    echo "This closed-alpha package bundles LocalVoiceInput, Qwen3-ASR MLX 0.6B"
    echo "runtime assets, mlx-audio source, and local service code for trusted"
    echo "tester evaluation. It is not notarized and is not a public release."
    echo
    echo "Before broader distribution, review upstream model/runtime licenses and"
    echo "notices with the intended distribution channel."
  } > "$NOTICE_STAGE/NOTICE.txt"

  [ -f "$MODEL_SRC/README.md" ] && cp "$MODEL_SRC/README.md" "$NOTICE_STAGE/QWEN3_MODEL_README.md"
  [ -f "$MLX_AUDIO_SRC/LICENSE" ] && cp "$MLX_AUDIO_SRC/LICENSE" "$NOTICE_STAGE/MLX_AUDIO_LICENSE"
  [ -f "$MLX_AUDIO_SRC/README.md" ] && cp "$MLX_AUDIO_SRC/README.md" "$NOTICE_STAGE/MLX_AUDIO_README.md"
}

write_manifest_and_checksums() {
  mkdir -p "$STAGE_ROOT"
  local app_size model_size python_size mlx_audio_size service_size
  app_size="$(du -sh "$APP_DIR" 2>/dev/null | awk '{print $1}' || true)"
  model_size="$(du -sh "$MODEL_STAGE" 2>/dev/null | awk '{print $1}' || true)"
  python_size="$(du -sh "$PYTHON_STAGE" 2>/dev/null | awk '{print $1}' || true)"
  mlx_audio_size="$(du -sh "$MLX_AUDIO_STAGE" 2>/dev/null | awk '{print $1}' || true)"
  service_size="$(du -sh "$SERVICE_STAGE" 2>/dev/null | awk '{print $1}' || true)"
  {
    echo "LocalVoiceInput closed alpha manifest"
    echo "version=$VERSION"
    echo "created_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    echo "artifact_kind=unnotarized-closed-alpha"
    echo "bundle_model=qwen3-asr-0.6b-mlx-8bit"
    echo "developer_id_required=false"
    echo "notarization_required=false"
    echo
    echo "[sizes]"
    echo "app=${app_size:-missing}"
    echo "models/qwen3-asr-0.6b-mlx-8bit=${model_size:-missing}"
    echo "python=${python_size:-missing}"
    echo "repos/mlx-audio=${mlx_audio_size:-missing}"
    echo "services/asr_streaming=${service_size:-missing}"
  } > "$MANIFEST_STAGE"

  (
    cd "$STAGE_ROOT"
    find config models repos services NOTICE -type f -print 2>/dev/null | sort | xargs shasum -a 256
  ) > "$CHECKSUM_STAGE"
}

stage_runtime() {
  require_tool shasum
  ensure_inputs
  rm -rf "$STAGE_ROOT"
  mkdir -p "$SERVICE_STAGE" "$VAR_STAGE/spool" "$VAR_STAGE/cache" "$VAR_STAGE/logs"
  copy_tree "$RUNTIME_SRC" "$PYTHON_STAGE"
  copy_tree "$MODEL_SRC" "$MODEL_STAGE"
  copy_tree "$MLX_AUDIO_SRC" "$MLX_AUDIO_STAGE"
  cp "$SERVICE_SRC_DIR/qwen3_mlx_segmented_cache_service.py" "$SERVICE_STAGE/"
  cp "$SERVICE_SRC_DIR/qwen3_mlx_service_common.py" "$SERVICE_STAGE/"
  cp "$SERVICE_SRC_DIR/qwen3_mlx_realtime_probe.py" "$SERVICE_STAGE/"
  cp "$SERVICE_SRC_DIR/run_eval.py" "$SERVICE_STAGE/"
  cp "$SERVICE_SRC_DIR/model_registry.json" "$SERVICE_STAGE/"
  mkdir -p "$(dirname "$CONFIG_STAGE")"
  cp "$CONFIG_SRC" "$CONFIG_STAGE"
  write_notice_files
  write_manifest_and_checksums
  echo "Staged closed-alpha runtime: $STAGE_ROOT"
}

wait_for_metadata() {
  local url="$1"
  local attempts="${2:-120}"
  local i
  for ((i = 1; i <= attempts; i++)); do
    if "$PYTHON_STAGE/bin/python" - "$url" <<'PY' >/dev/null 2>&1
import json
import sys
import urllib.request

url = sys.argv[1]
with urllib.request.urlopen(url, timeout=2) as response:
    obj = json.loads(response.read().decode("utf-8"))
if obj.get("ok") is not True:
    raise SystemExit(1)
if obj.get("service") != "qwen3-mlx-segmented-cache-service":
    raise SystemExit(1)
PY
    then
      return 0
    fi
    sleep 1
  done
  return 1
}

verify_staged_runtime() {
  [ -x "$PYTHON_STAGE/bin/python" ] || {
    echo "Staged Python is missing. Run --stage-runtime first." >&2
    exit 2
  }
  mkdir -p "$VAR_STAGE/spool" "$VAR_STAGE/logs"
  local log="$VAR_STAGE/logs/verify-staged-runtime.log"
  local pid_file="$VAR_STAGE/verify-staged-runtime.pid"
  rm -f "$log" "$pid_file"
  "$PYTHON_STAGE/bin/python" -u "$SERVICE_STAGE/qwen3_mlx_segmented_cache_service.py" serve \
    --host "$VERIFY_HOST" \
    --port "$VERIFY_PORT" \
    --model-id qwen3-asr-0.6b-mlx-8bit \
    --model "$MODEL_STAGE" \
    --mlx-audio-source "$MLX_AUDIO_STAGE" \
    --registry "$SERVICE_STAGE/model_registry.json" \
    --spool-dir "$VAR_STAGE/spool" \
    >"$log" 2>&1 &
  local service_pid=$!
  echo "$service_pid" > "$pid_file"
  trap 'kill "$service_pid" >/dev/null 2>&1 || true' EXIT
  if ! wait_for_metadata "http://$VERIFY_HOST:$VERIFY_PORT/metadata" 180; then
    echo "Staged runtime did not become healthy. Log: $log" >&2
    sed -n '1,120p' "$log" >&2 || true
    exit 1
  fi
  "$PYTHON_STAGE/bin/python" - "$VERIFY_HOST" "$VERIFY_PORT" <<'PY'
import json
import sys
import urllib.request

host, port = sys.argv[1], sys.argv[2]
with urllib.request.urlopen(f"http://{host}:{port}/metadata", timeout=5) as response:
    obj = json.loads(response.read().decode("utf-8"))
print(json.dumps({
    "ok": obj.get("ok"),
    "service": obj.get("service"),
    "model_id": (obj.get("model_info") or {}).get("id"),
    "fake_backend": obj.get("fake_backend"),
    "model_load_wall_ms": obj.get("model_load_wall_ms"),
}, ensure_ascii=False, sort_keys=True))
PY
  kill "$service_pid" >/dev/null 2>&1 || true
  wait "$service_pid" >/dev/null 2>&1 || true
  trap - EXIT
  echo "Verified staged runtime on http://$VERIFY_HOST:$VERIFY_PORT"
}

resolve_sign_identity() {
  if [ -n "${LOCALVOICEINPUT_CODESIGN_IDENTITY:-}" ]; then
    printf '%s\n' "$LOCALVOICEINPUT_CODESIGN_IDENTITY"
    return 0
  fi
  if command -v security >/dev/null 2>&1; then
    local identities
    identities="$(security find-identity -p codesigning -v | sed -n 's/.*"\(.*\)".*/\1/p' | sed '/^$/d' || true)"
    local count
    count="$(printf '%s\n' "$identities" | sed '/^$/d' | wc -l | tr -d ' ')"
    if [ "$count" = "1" ]; then
      printf '%s\n' "$identities"
      return 0
    fi
  fi
  printf '%s\n' "-"
}

sign_macho_files_and_app() {
  command -v codesign >/dev/null 2>&1 || return 0
  local identity
  identity="$(resolve_sign_identity)"
  if [ "$identity" = "-" ]; then
    echo "Signing closed-alpha app ad-hoc. Set LOCALVOICEINPUT_CODESIGN_IDENTITY for more stable TCC identity."
  else
    echo "Signing closed-alpha app with identity: $identity"
  fi
  while IFS= read -r path; do
    if file "$path" 2>/dev/null | grep -q 'Mach-O'; then
      codesign --force --sign "$identity" "$path" >/dev/null 2>&1 || true
    fi
  done < <(find "$APP_DIR" -type f \( -perm -111 -o -name '*.dylib' -o -name '*.so' \) | awk '{ print length, $0 }' | sort -rn | cut -d' ' -f2-)
  codesign --force --deep --sign "$identity" "$APP_DIR"
  codesign --verify --deep --strict --verbose=2 "$APP_DIR"
}

stage_app_resources() {
  [ -d "$STAGE_ROOT" ] || stage_runtime
  local resources="$APP_DIR/Contents/Resources"
  local alpha_runtime="$resources/AlphaRuntime"
  rm -rf "$alpha_runtime"
  mkdir -p "$alpha_runtime"
  copy_tree "$PYTHON_STAGE" "$alpha_runtime/python"
  copy_tree "$MODEL_STAGE" "$alpha_runtime/models/qwen3-asr-0.6b-mlx-8bit"
  copy_tree "$MLX_AUDIO_STAGE" "$alpha_runtime/repos/mlx-audio"
  copy_tree "$SERVICE_STAGE" "$alpha_runtime/services/asr_streaming"
  copy_tree "$NOTICE_STAGE" "$alpha_runtime/NOTICE"
  mkdir -p "$alpha_runtime/config"
  cp "$CONFIG_STAGE" "$alpha_runtime/config/alpha.local-qwen3.json"
  cp "$MANIFEST_STAGE" "$alpha_runtime/MANIFEST.txt"
  cp "$CHECKSUM_STAGE" "$alpha_runtime/SHA256SUMS.txt"
  cp "$CONFIG_STAGE" "$resources/alpha.local-qwen3.json"
}

write_alpha_readme() {
  local readme_path="$1"
  cat > "$readme_path" <<'EOF'
LocalVoiceInput Closed Alpha
============================

This is an unnotarized closed-alpha build for trusted testers.

Expected first launch:
1. Drag LocalVoiceInput.app to Applications.
2. Open it once. macOS may block it because it is not notarized.
3. Open System Settings > Privacy & Security and choose Open Anyway / Still Open.
4. Grant Microphone, Accessibility, and Input Monitoring when prompted.

The package bundles the Qwen3-ASR MLX 0.6B runtime path for local-only testing.
It does not upload audio or text by default and does not use cloud ASR fallback.

Target: Apple Silicon macOS 13+, 16 GB+ memory recommended.
EOF
}

create_dmg() {
  rm -rf "$DMG_ROOT"
  mkdir -p "$DMG_ROOT"
  copy_tree "$APP_DIR" "$DMG_ROOT/$APP_NAME.app"
  ln -s /Applications "$DMG_ROOT/Applications"
  write_alpha_readme "$DMG_ROOT/README-FIRST-RUN.txt"
  cp "$MANIFEST_STAGE" "$DMG_ROOT/MANIFEST.txt"
  cp "$CHECKSUM_STAGE" "$DMG_ROOT/SHA256SUMS.txt"
  copy_tree "$NOTICE_STAGE" "$DMG_ROOT/NOTICE"
  rm -f "$DMG_PATH"
  hdiutil create -volname "$VOLNAME" -srcfolder "$DMG_ROOT" -ov -format UDZO "$DMG_PATH"
  echo "Built unnotarized closed-alpha DMG: $DMG_PATH"
  du -sh "$DMG_PATH" || true
}

build_closed_alpha() {
  require_tool swift
  require_tool hdiutil
  stage_runtime
  bash scripts/build_macos_app.sh
  stage_app_resources
  sign_macho_files_and_app
  create_dmg
  echo "Reminder: this Phase 1 DMG is intentionally unnotarized and may require Open Anyway."
}

dry_run() {
  print_status
  echo
  echo "== Dry Run Steps =="
  echo "1. Stage allowlisted runtime/model/service assets into $STAGE_ROOT."
  echo "2. Verify staged Qwen3 service on http://$VERIFY_HOST:$VERIFY_PORT."
  echo "3. Build release app with scripts/build_macos_app.sh."
  echo "4. Copy staged assets into LocalVoiceInput.app/Contents/Resources/AlphaRuntime."
  echo "5. Re-sign nested Mach-O code and the app with the best available local identity or ad-hoc fallback."
  echo "6. Create unnotarized closed-alpha DMG at $DMG_PATH."
}

developer_id_placeholder() {
  cat >&2 <<'EOF'
Developer ID distribution is intentionally not Phase 1.
Create a separate follow-up or use a future --developer-id implementation after
closed-alpha stability is proven and Apple Developer Program credentials exist.
EOF
  exit 2
}

case "$MODE" in
  preflight)
    print_status
    ;;
  dry-run)
    dry_run
    ;;
  stage-runtime)
    stage_runtime
    ;;
  verify-staged-runtime)
    verify_staged_runtime
    ;;
  closed-alpha)
    build_closed_alpha
    ;;
  developer-id)
    developer_id_placeholder
    ;;
esac
