#!/usr/bin/env bash
set -euo pipefail

INPUT_FILE="${1:-models.txt}"
MODELS_DIR="${MODELS_DIR:-$HOME/comfy/models}"

need_aria2() { ! command -v aria2c >/dev/null 2>&1; }

install_aria2() {
  echo "ℹ️  Εγκατάσταση aria2..."
  if command -v apt-get >/dev/null 2>&1; then
    if sudo -n true 2>/dev/null; then
      sudo apt-get update -y && sudo apt-get install -y aria2
    else
      if [ "$(id -u)" -eq 0 ]; then
        apt-get update -y && apt-get install -y aria2
      else
        echo "❌ Δεν έχω sudo. Τρέξε: sudo apt-get update && sudo apt-get install -y aria2"
        exit 1
      fi
    fi
  else
    echo "❌ Δεν βρέθηκε apt-get. Εγκατέστησε χειροκίνητα το aria2."
    exit 1
  fi
}

need_aria2 && install_aria2

mkdir -p "$MODELS_DIR"

ARIA2_COMMON=( -x4 -s4 -c -k1M --auto-file-renaming=false --continue=true --remote-time=true )

while read -r url subfolder filename; do
  # Αγνόησε άδειες γραμμές / σχόλια
  [ -z "${url:-}" ] && continue
  case "$url" in \#*) continue;; esac

  dest_dir="${MODELS_DIR}/${subfolder}"
  mkdir -p "$dest_dir"

  if [ -n "${filename:-}" ]; then
    dest_path="${dest_dir}/${filename}"

    if [ -f "$dest_path" ]; then
      echo "✔ Υπάρχει ήδη: $dest_path — παράλειψη"
      continue
    fi

    aria2c "${ARIA2_COMMON[@]}" -d "$dest_dir" -o "$filename" "$url" \
      || { echo "❌ Αποτυχία: $url"; continue; }

  else
    base="$(basename "${url%%\?*}")"
    [ -n "$base" ] && [ -f "${dest_dir}/${base}" ] && { echo "✔ Υπάρχει ήδη: ${dest_dir}/${base} — παράλειψη"; continue; }

    aria2c "${ARIA2_COMMON[@]}" -d "$dest_dir" "$url" \
      || { echo "❌ Αποτυχία: $url"; continue; }
  fi
done < "$INPUT_FILE"
