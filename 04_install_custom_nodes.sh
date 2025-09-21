#!/usr/bin/env bash
set -euo pipefail

COMFY_DIR="${COMFY_DIR:-$HOME/comfy}"
VENV_DIR="${VENV_DIR:-$COMFY_DIR/venv}"
CUSTOM_DIR="$COMFY_DIR/custom_nodes"
NODES_FILE="${NODES_FILE:-nodes.txt}"
CM_CLI="$CUSTOM_DIR/ComfyUI-Manager/cm-cli.py"

[ -f "$NODES_FILE" ] || { echo "❌ Δεν βρέθηκε $NODES_FILE"; exit 1; }
[ -d "$CUSTOM_DIR" ] || { echo "❌ Δεν βρέθηκε $CUSTOM_DIR"; exit 1; }
[ -d "$VENV_DIR" ]  || { echo "❌ Δεν βρέθηκε το venv: $VENV_DIR"; exit 1; }

source "$VENV_DIR/bin/activate"
export COMFYUI_PATH="$COMFY_DIR"

sanitize_name() {
  local url="$1"
  local name="${url##*/}"   # repo tail
  name="${name%.git}"       # χωρίς .git
  # καθάρισμα περίεργων
  name="$(echo "$name" | tr '[:space:]' '_' | tr -cd '[:alnum:]_.-')"
  printf "%s" "$name"
}

clone_or_update() {
  local url="$1"
  local name; name="$(sanitize_name "$url")"
  local dest="$CUSTOM_DIR/$name"

  if [ -d "$dest/.git" ]; then
    echo "==> git pull: $name" >&2
    git -C "$dest" pull --ff-only >&2
  else
    echo "==> git clone: $url → $dest" >&2
    git clone --depth 1 "$url" "$dest" >&2
  fi
  # Προσοχή: stdout ΜΟΝΟ το path!
  printf "%s" "$dest"
}

install_deps() {
  local dir="$1"
  # 1) requirements*.txt
  local req
  req="$(find "$dir" -maxdepth 2 -type f -iname 'requirements*.txt' | head -n1 || true)"
  if [ -n "${req:-}" ]; then
    echo "   ↳ pip install -r $(basename "$req")"
    python -m pip install -r "$req"
    return
  fi
  # 2) pyproject.toml / setup.py
  if [ -f "$dir/pyproject.toml" ] || [ -f "$dir/setup.py" ]; then
    echo "   ↳ pip install (local package) στο $dir"
    python -m pip install "$dir"
    return
  fi
  echo "   ↳ (κανένα requirements/pyproject/setup δεν βρέθηκε)"
}

mapfile -t REPOS < <(grep -vE '^\s*#' "$NODES_FILE" | sed -E 's/^\s+|\s+$//g' | awk 'NF' | uniq)
if [ "${#REPOS[@]}" -eq 0 ]; then
  echo "⚠️  Το $NODES_FILE είναι άδειο."; exit 0
fi

for url in "${REPOS[@]}"; do
  echo -e "\n==== $url ===="
  node_dir="$(clone_or_update "$url")"   # stdout = ΜΟΝΟ path
  install_deps "$node_dir"
  echo "✅ Done: $url"
done

if [ -f "$CM_CLI" ]; then
  echo -e "\n👉 Τελικό Manager fix:"
  python "$CM_CLI" fix all --mode local
fi

echo -e "\n🎉 Όλα ΟΚ."
