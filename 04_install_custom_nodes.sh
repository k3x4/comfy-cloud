#!/usr/bin/env bash
set -euo pipefail

# ---- Ρυθμίσεις ----
COMFY_DIR="${COMFY_DIR:-$HOME/comfy}"
VENV_DIR="${VENV_DIR:-$HOME/comfy/venv}"
CM_DIR="${CM_DIR:-$HOME/comfy/custom_nodes/ComfyUI-Manager}"
NODES_LIST="${NODES_LIST:-nodes.txt}"
CHANNEL="${CHANNEL:-all}"
MODE="${MODE:-remote}"

# ---- Έλεγχοι ----
[ -d "$COMFY_DIR" ] || { echo "❌ COMFY_DIR not found: $COMFY_DIR"; exit 1; }
[ -d "$VENV_DIR" ]  || { echo "❌ VENV_DIR not found:  $VENV_DIR";  exit 1; }
[ -f "$NODES_LIST" ]|| { echo "❌ nodes.txt missing:   $NODES_LIST"; exit 1; }
[ -d "$CM_DIR" ]    || { echo "❌ ComfyUI-Manager not found at $CM_DIR"; exit 1; }

# ---- Venv ----
source "$VENV_DIR/bin/activate"
export COMFYUI_PATH="$COMFY_DIR"

CM_CLI="$CM_DIR/cm-cli.py"

echo "🔎 θα εγκαταστήσω nodes από: $NODES_LIST"
while IFS= read -r LINE; do
  # Αγνόησε κενά/σχόλια
  NAME="${LINE#"${LINE%%[![:space:]]*}"}"
  [[ -z "$NAME" || "$NAME" =~ ^# ]] && continue

  # Αν είναι URL -> πάρε το repo name (basename)
  if [[ "$NAME" =~ github.com ]]; then
    NAME="$(basename "${NAME%.git}")"
  fi

  echo "➡️  cm-cli install: $NAME"
  python "$CM_CLI" install "$NAME" --channel "$CHANNEL" --mode "$MODE"
done < "$NODES_LIST"

echo "🧰 cm-cli fix all (deps)"
python "$CM_CLI" fix all --channel "$CHANNEL" --mode "$MODE"

echo "📦 cm-cli restore-dependencies (αν χρειαστεί)"
python "$CM_CLI" restore-dependencies

echo "✅ Τέλος."
