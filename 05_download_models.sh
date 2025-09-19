#!/usr/bin/env bash

INPUT_FILE="${1:-models.txt}"
MODELS_DIR="${MODELS_DIR:-$HOME/comfy/models}"

while read -r url subfolder filename; do
  [ -z "$url" ] && continue
  case "$url" in \#*) continue;; esac

  dest_dir="${MODELS_DIR}/${subfolder}"
  mkdir -p "$dest_dir"

  if [ -n "$filename" ]; then
    wget -c --content-disposition -O "${dest_dir}/${filename}" "$url"
  else
    wget -c --content-disposition -P "$dest_dir" "$url"
  fi
done < "$INPUT_FILE"
