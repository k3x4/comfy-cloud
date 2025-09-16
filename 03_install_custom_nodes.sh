#!/usr/bin/env bash

# Ρύθμισε (ή άφησε default)
COMFY_DIR="${COMFY_DIR:-$HOME/comfy}"
CUSTOM_NODES_DIR="${CUSTOM_NODES_DIR:-$COMFY_DIR/custom_nodes}"
LIST_FILE="${1:-nodes.txt}"

# Να φαίνεται ρητά ότι μπαίνουμε στο venv
source "$COMFY_DIR/venv/bin/activate"

mkdir -p "$CUSTOM_NODES_DIR"

# Κάθε γραμμή στο LIST_FILE είναι git repo URL
while IFS= read -r REPO; do
  NAME="$(basename "$REPO" .git)"
  git clone --depth 1 "$REPO" "$CUSTOM_NODES_DIR/$NAME"

  # Προσπάθησε να εγκαταστήσεις requirements (αν δεν υπάρχουν/σκάσει, προχώρα)
  python -m pip install -r "$CUSTOM_NODES_DIR/$NAME/requirements.txt" 2>/dev/null || true
  for REQ in "$CUSTOM_NODES_DIR/$NAME"/requirements*.txt; do
    python -m pip install -r "$REQ" 2>/dev/null || true
  done
done < "$LIST_FILE"
