#!/usr/bin/env bash
set -euo pipefail

# === ΡΥΘΜΙΣΕΙΣ ===
COMFY_DIR="${COMFY_DIR:-$HOME/comfy}"
VENV_DIR="${VENV_DIR:-$COMFY_DIR/venv}"
CUSTOM_DIR="$COMFY_DIR/custom_nodes"
NODES_FILE="${NODES_FILE:-nodes.txt}"

# Αν υπάρχει Manager θα κάνουμε ένα "fix all" στο τέλος (offline)
CM_CLI="$CUSTOM_DIR/ComfyUI-Manager/cm-cli.py"

# === ΕΛΕΓΧΟΙ ===
[ -f "$NODES_FILE" ] || { echo "❌ Δεν βρέθηκε $NODES_FILE"; exit 1; }
[ -d "$CUSTOM_DIR" ] || { echo "❌ Δεν βρέθηκε $CUSTOM_DIR"; exit 1; }
[ -d "$VENV_DIR" ]  || { echo "❌ Δεν βρέθηκε το venv: $VENV_DIR"; exit 1; }

# Ενεργοποίηση venv & Comfy path
source "$VENV_DIR/bin/activate"
export COMFYUI_PATH="$COMFY_DIR"

# === HELPERS ===
sanitize_name() {
  # Παίρνει repo URL και δίνει ασφαλές όνομα φακέλου
  local url="$1"
  local name="${url##*/}"            # tail μετά το τελευταίο /
  name="${name%.git}"                # βγάλε .git
  # αντικατάσταση περίεργων χαρακτήρων
  name="$(echo "$name" | tr '[:space:]' '_' | tr -cd '[:alnum:]_.-')"
  printf "%s" "$name"
}

clone_or_update() {
  local url="$1"
  local name; name="$(sanitize_name "$url")"
  local dest="$CUSTOM_DIR/$name"

  if [ -d "$dest/.git" ]; then
    echo "==> git pull: $name"
    git -C "$dest" pull --ff-only
  else
    echo "==> git clone: $url → $dest"
    git clone --depth 1 "$url" "$dest"
  fi
  echo "$dest"
}

install_deps() {
  local dir="$1"

  # 1) requirements*.txt (πιο συνηθισμένο)
  local req
  req="$(find "$dir" -maxdepth 2 -type f -iname 'requirements*.txt' | head -n1 || true)"
  if [ -n "${req:-}" ]; then
    echo "   ↳ pip install -r $(basename "$req")"
    python -m pip install -r "$req"
    return
  fi

  # 2) PEP 517 / setup
  if [ -f "$dir/pyproject.toml" ] || [ -f "$dir/setup.py" ]; then
    echo "   ↳ pip install (local package) στο $dir"
    python -m pip install "$dir"
    return
  fi

  echo "   ↳ (κανένα requirements/pyproject/setup δεν βρέθηκε)"
}

# === MAIN ===
mapfile -t REPOS < <(grep -vE '^\s*#' "$NODES_FILE" | sed -E 's/^\s+|\s+$//g' | awk 'NF' | uniq)
if [ "${#REPOS[@]}" -eq 0 ]; then
  echo "⚠️  Το $NODES_FILE είναι άδειο."; exit 0
fi

for url in "${REPOS[@]}"; do
  echo -e "\n==== $url ===="
  node_dir="$(clone_or_update "$url")"
  install_deps "$node_dir"
  echo "✅ Done: $url"
done

if [ -f "$CM_CLI" ]; then
  echo -e "\n👉 Τελικό Manager fix:"
  python "$CM_CLI" fix all --mode local
fi

echo -e "\n🎉 Όλα ΟΚ."
