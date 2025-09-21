#!/usr/bin/env bash
set -euo pipefail

COMFY_DIR="${COMFY_DIR:-$HOME/comfy}"
VENV_DIR="${VENV_DIR:-$COMFY_DIR/venv}"
CM="${CM:-$COMFY_DIR/custom_nodes/ComfyUI-Manager/cm-cli.py}"
NODES_FILE="${NODES_FILE:-nodes.txt}"

[ -f "$NODES_FILE" ] || { echo "❌ Δεν βρέθηκε $NODES_FILE"; exit 1; }
[ -f "$CM" ] || { echo "❌ Δεν βρέθηκε το cm-cli: $CM"; exit 1; }
[ -d "$VENV_DIR" ] || { echo "❌ Δεν βρέθηκε το venv: $VENV_DIR"; exit 1; }

source "$VENV_DIR/bin/activate"
export COMFYUI_PATH="$COMFY_DIR"

find_node_dir() {
  local url="$1"
  local base="$(basename "$url" .git)"

  if [ -d "$COMFY_DIR/custom_nodes/$base" ]; then
    echo "$COMFY_DIR/custom_nodes/$base"; return 0
  fi

  local m
  m="$(find "$COMFY_DIR/custom_nodes" -maxdepth 1 -type d -iname "*${base}*" | head -n1 || true)"
  if [ -n "${m:-}" ]; then echo "$m"; return 0; fi

  m="$(find "$COMFY_DIR/custom_nodes" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' \
      | sort -nr | awk 'NR==1{print $2}')"
  echo "$m"
}

install_reqs() {
  local node_dir="$1"

  local req
  req="$(find "$node_dir" -maxdepth 2 -type f -iname 'requirements*.txt' | head -n1 || true)"
  if [ -n "${req:-}" ]; then
    echo "   ↳ pip install -r $(basename "$req")"
    python -m pip install -r "$req"
    return
  fi

  if [ -f "$node_dir/pyproject.toml" ]; then
    echo "   ↳ pip install (pyproject) στο $node_dir"
    python -m pip install "$node_dir"
    return
  fi

  if [ -f "$node_dir/setup.py" ]; then
    echo "   ↳ pip install (setup.py) στο $node_dir"
    python -m pip install "$node_dir"
    return
  fi
}

install_one() {
  local url="$1"
  echo -e "\n==> Installing: $url"

  python "$CM" install "$url" --channel default --mode local

  python "$CM" fix all   --channel default --mode local

  local node_dir; node_dir="$(find_node_dir "$url")"
  if [ -d "$node_dir" ]; then
    install_reqs "$node_dir"
  else
    echo "⚠️  Δεν εντοπίστηκε φάκελος για $url μέσα στα custom_nodes."
  fi

  echo "✅ Done: $url"
}

mapfile -t REPOS < <(grep -vE '^\s*#' "$NODES_FILE" | sed -E 's/^\s+|\s+$//g' | awk 'NF' | uniq)

if [ "${#REPOS[@]}" -eq 0 ]; then
  echo "⚠️  Το $NODES_FILE είναι άδειο."
  exit 0
fi

for repo in "${REPOS[@]}"; do
  install_one "$repo"
done

echo -e "\n🎉 Όλα ΟΚ."
