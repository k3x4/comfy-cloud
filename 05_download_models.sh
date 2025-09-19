#!/usr/bin/env bash
# Κατεβάζει αρχεία από models.txt στον φάκελο models/<subfolder>/ με προαιρετική μετονομασία.

INPUT_FILE="${1:-models.txt}"

while read -r url subfolder filename; do
  # Αγνόησε άδειες γραμμές ή σχόλια
  [ -z "$url" ] && continue
  case "$url" in \#*) continue;; esac

  dest_dir="models/${subfolder}"
  mkdir -p "$dest_dir"

  if [ -n "$filename" ]; then
    # Με συγκεκριμένο όνομα αρχείου
    wget -c --content-disposition -O "${dest_dir}/${filename}" "$url"
  else
    # Χωρίς όνομα -> ό,τι δώσει ο server ή το basename του URL
    wget -c --content-disposition -P "$dest_dir" "$url"
  fi
done < "$INPUT_FILE"
