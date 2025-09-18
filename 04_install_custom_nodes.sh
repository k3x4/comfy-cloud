#!/usr/bin/env bash

COMFY_DIR="${COMFY_DIR:-$HOME/comfy}"
CUSTOM_NODES_DIR="${CUSTOM_NODES_DIR:-$COMFY_DIR/custom_nodes}"
LIST_FILE="${1:-nodes.txt}"

source "$COMFY_DIR/venv/bin/activate"

mkdir -p "$CUSTOM_NODES_DIR"

while IFS= read -r REPO; do
    NAME="$(basename "$REPO" .git)"
    git clone --depth 1 "$REPO" "$CUSTOM_NODES_DIR/$NAME"

    python -m pip install -r "$CUSTOM_NODES_DIR/$NAME/requirements.txt" || exit 1
    for REQ in "$CUSTOM_NODES_DIR/$NAME"/requirements*.txt; do
    [ -f "$REQ" ] && python -m pip install -r "$REQ" || exit 1
    done
done < "$LIST_FILE"
