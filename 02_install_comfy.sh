#!/usr/bin/env bash
set -e

COMFY_DIR="${COMFY_DIR:-$HOME/comfy}"
REPO_URL="${REPO_URL:-https://github.com/comfyanonymous/ComfyUI.git}"
PORT="${COMFY_PORT:-8188}"

nvidia-smi || true

if [ ! -d "$COMFY_DIR/.git" ]; then
  git clone --depth=1 "$REPO_URL" "$COMFY_DIR"
fi

# venv
python3 -m venv "$COMFY_DIR/venv"
source "$COMFY_DIR/venv/bin/activate"
python -m pip install -U pip wheel setuptools

python -m pip install -r "$COMFY_DIR/requirements.txt"

if [ ! -d "$COMFY_DIR/custom_nodes/ComfyUI-Manager/.git" ]; then
  git clone https://github.com/ltdrdata/ComfyUI-Manager "$COMFY_DIR/custom_nodes/ComfyUI-Manager"
fi
if [ -f "$COMFY_DIR/custom_nodes/ComfyUI-Manager/requirements.txt" ]; then
  python -m pip install -r "$COMFY_DIR/custom_nodes/ComfyUI-Manager/requirements.txt"
fi