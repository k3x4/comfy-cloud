#!/usr/bin/env bash
set -euo pipefail

COMFY_DIR="${COMFY_DIR:-$HOME/comfy}"
VENV_DIR="${VENV_DIR:-$HOME/comfy/venv}"
CM_DIR="${CM_DIR:-$HOME/comfy/custom_nodes/ComfyUI-Manager}"
NODES_LIST="${NODES_LIST:-nodes.txt}"

CHANNEL="${CHANNEL:-default}"
MODE="${MODE:-remote}"

[ -d "$COMFY_DIR" ] || { echo "❌ COMFY_DIR not found: $COMFY_DIR"; exit 1; }
[ -d "$VENV_DIR" ]  || { echo "❌ VENV_DIR not found:  $VENV_DIR"; exit 1; }
[ -f "$NODES_LIST" ]|| { echo "❌ nodes.txt missing:   $NODES_LIST"; exit 1; }

# venv
source "$VENV_DIR/bin/activate"

CM="$CM_DIR/cm-cli.py"
export COMFYUI_PATH="$COMFY_DIR"

echo "🔧 Εγκατάσταση από $NODES_LIST (channel=$CHANNEL, mode=$MODE)"
while IFS= read -r LINE; do
  ENTRY="${LINE#"${LINE%%[![:space:]]*}"}"
  [[ -z "$ENTRY" || "$ENTRY" =~ ^# ]] && continue

  if [[ "$ENTRY" =~ github.com ]]; then
    echo "➡️  install-url: $ENTRY"
    python "$CM" install-url "$ENTRY" --channel "$CHANNEL" --mode "$MODE"
  else
    echo "➡️  install: $ENTRY"
    python "$CM" install "$ENTRY" --channel "$CHANNEL" --mode "$MODE"
  fi
done < "$NODES_LIST"

echo "🧰 fix deps"
python "$CM" fix all --channel "$CHANNEL" --mode "$MODE" || true

echo "📦 restore-dependencies"
python "$CM" restore-dependencies || true

echo "✅ Τέλος."
