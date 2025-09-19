#!/usr/bin/env bash

INPUT_FILE="${1:-models.txt}"
MODELS_DIR="${MODELS_DIR:-$HOME/comfy/models}"

while read -r url subfolder filename; do
  [ -z "$url" ] && continue
  case "$url" in \#*) continue;; esac

  dest_dir="${MODELS_DIR}/${subfolder}"
  mkdir -p "$dest_dir"

  if [ -n "$filename" ]; then
    dest_path="${dest_dir}/${filename}"
    if [ -f "$dest_path" ]; then
      echo "✔ Υπάρχει ήδη: $dest_path — παράλειψη"
      continue
    fi
    # Κατέβασμα με συγκεκριμένο όνομα
    curl -C - -L --fail --retry 3 -o "$dest_path" "$url" || {
      echo "❌ Αποτυχία: $url"
      continue
    }
  else
    # Όταν δεν δίνεται όνομα, προσπαθώ να ελέγξω με βάση το basename του URL (χωρίς query)
    base="$(basename "${url%%\?*}")"
    [ -z "$base" ] && base="download"
    if [ -f "${dest_dir}/${base}" ]; then
      echo "✔ Υπάρχει ήδη: ${dest_dir}/${base} — παράλειψη"
      continue
    fi
    # Κατέβασμα χρησιμοποιώντας Content-Disposition αν υπάρχει (-J) και αποθήκευση στον dest_dir
    ( cd "$dest_dir" && curl -C - -L -J -O --fail --retry 3 "$url" ) || {
      echo "❌ Αποτυχία: $url"
      continue
    }
  fi
done < "$INPUT_FILE"
