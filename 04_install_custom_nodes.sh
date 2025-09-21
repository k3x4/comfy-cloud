#!/usr/bin/env bash
set -euo pipefail

COMFY_DIR="${COMFY_DIR:-$HOME/comfy}"
VENV_DIR="${VENV_DIR:-$HOME/comfy/venv}"
CM_DIR="${CM_DIR:-$HOME/comfy/custom_nodes/ComfyUI-Manager}"
NODES_LIST="${NODES_LIST:-nodes.txt}"

source "$VENV_DIR/bin/activate"
export COMFYUI_PATH="$COMFY_DIR"

CM="$CM_DIR/cm-cli.py"

# 1) PRIME CACHE (1 φορά)
python "$CM" simple-show all --channel default --mode remote || true

# 2) Μάζεψε τα ονόματα σε array (αγνόησε κενά/#)
mapfile -t NODES < <(grep -vE '^\s*#' "$NODES_LIST" | sed -E 's/^\s+|\s+$//g' | awk 'NF')

# 3) Εγκατάσταση σε ΜΙΑ κλήση, από cache (ελάχιστο fetch)
python "$CM" install "${NODES[@]}" --channel default --mode cache 2> >(grep -v 'install_node exit on fail' >&2)

# 4) Προαιρετικά: fix deps
# python "$CM" fix all --channel default --mode cache 2> >(grep -v 'install_node exit on fail' >&2)

echo "✅ Done"

