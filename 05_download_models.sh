#!/usr/bin/env bash
set -euo pipefail

# 05_download_models.sh
# Χρήση:
#  1) Φτιάξε ένα models.txt (UTF-8) με γραμμές τύπου:
#       https://example.com/juggernautXLv9.safetensors   checkpoints
#       https://civitai.com/api/download/models/12345?filename=union-promax.safetensors  controlnet
#       https://huggingface.co/.../file  loras  MyStyleV1.safetensors
#     - 1η στήλη: URL (υποχρεωτικό)
#     - 2η στήλη: προορισμός (προαιρετικό): checkpoints | controlnet | loras | vae | clip | ipadapter | upscale_models | embeddings | unet | text_encoders
#                  (αν λείπει: χρησιμοποιεί "checkpoints")
#     - 3η στήλη: filename (προαιρετικό). Αν λείπει, θα βρεθεί αυτόματα όπως περιγράφεται.
#
#  2) Τρέξε:
#       chmod +x 05_download_models.sh
#       ./05_download_models.sh models.txt

MODELS_LIST="${1:-models.txt}"

BASE="$HOME/comfy/models"
declare -A DEST_MAP=(
  [checkpoints]="$BASE/checkpoints"
  [controlnet]="$BASE/controlnet"
  [loras]="$BASE/loras"
  [vae]="$BASE/vae"
  [clip]="$BASE/clip"
  [ipadapter]="$BASE/ipadapter"
  [upscale_models]="$BASE/upscale_models"
  [embeddings]="$BASE/embeddings"
  [unet]="$BASE/unet"
  [text_encoders]="$BASE/text_encoders"
)

ARIA2_COMMON=(
  --continue=true           # resume
  -x16 -s16                 # 16 συνδέσεις / 16 splits
  -k1M                      # μέγεθος chunk
  --summary-interval=0
  --console-log-level=warn
  --auto-file-renaming=false
)

ensure_dir() { mkdir -p "$1"; }

# Από headers βγάλε "filename=..."
extract_filename_from_headers() {
  # αφαιρούμε \r για να δουλεύουν sed/grep σωστά
  local headers; headers="$(tr -d '\r' <<<"$1")"

  # 1) filename="...": quoted
  local fn
  fn="$(grep -i -o 'filename="[^"]\+"' <<<"$headers" | head -1 | sed 's/^filename="//; s/"$//')"
  if [[ -n "${fn:-}" ]]; then printf '%s' "$fn"; return 0; fi

  # 2) filename=unquoted
  fn="$(grep -i -o 'filename=[^; ]\+' <<<"$headers" | head -1 | sed 's/^filename=//')"
  if [[ -n "${fn:-}" ]]; then printf '%s' "$fn"; return 0; fi

  # 3) filename*=UTF-8''name.ext  (κρατάμε μόνο το δεξί τμήμα μετά τα δύο ')
  fn="$(grep -i -o "filename\\*=[^; ]\\+" <<<"$headers" | head -1 | sed -E "s/^filename\\*=//; s/^[^']*''//")"
  if [[ -n "${fn:-}" ]]; then
    # best-effort URL-decode για %XX (light)
    printf '%b' "$(sed 's/+/ /g; s/%/\\x/g' <<<"$fn")"
    return 0
  fi

  return 1
}

# Από query string πιάσε ?filename= ή &file= ή &name=
extract_filename_from_query() {
  local url="$1"
  local cand
  cand="$(sed -n 's/.*[?&]\(filename\|file\|name\)=\([^&#]*\).*/\2/p' <<<"$url" | head -1 || true)"
  if [[ -n "${cand:-}" ]]; then
    # URL-decode basic
    printf '%b' "$(sed 's/+/ /g; s/%/\\x/g' <<<"$cand")"
    return 0
  fi
  return 1
}

# Αν λείπει κατάληξη και μοιάζει με hash → πρόσθεσε .safetensors
maybe_append_safetensors() {
  local name="$1"
  if [[ "$name" != *.* ]]; then
    # looks like long hex? (>=32)
    if [[ "$name" =~ ^[0-9a-fA-F]{32,}$ ]]; then
      printf '%s.safetensors' "$name"
      return 0
    fi
  fi
  printf '%s' "$name"
}

resolve_filename() {
  local url="$1"

  # HEAD για headers (ακολουθεί redirects)
  local headers
  if ! headers="$(curl -sI -L "$url" || true)"; then headers=""; fi

  # 1) Από headers
  local cd_name=""
  if [[ -n "$headers" ]]; then
    if cd_name="$(extract_filename_from_headers "$headers" || true)"; then
      :
    else
      cd_name=""
    fi
  fi

  # 2) Από query
  local q_name=""
  if q_name="$(extract_filename_from_query "$url" || true)"; then
    :
  else
    q_name=""
  fi

  # 3) Από path
  local p_name
  p_name="$(basename "${url%%\?*}")"

  # Επιλογή προτεραιότητας: headers > query > path
  local chosen="${cd_name:-}"
  if [[ -z "$chosen" ]]; then chosen="${q_name:-}"; fi
  if [[ -z "$chosen" ]]; then chosen="$p_name"; fi

  # Αν δεν έχει κατάληξη, και μοιάζει με hash → βάλε .safetensors
  # Επιπλέον: αν Content-Type δείχνει octet-stream ΚΑΙ δεν έχει '.', επίσης βάλε .safetensors
  if [[ "$chosen" != *.* ]]; then
    if grep -qi '^Content-Type:.*octet-stream' <<<"$headers"; then
      chosen="${chosen}.safetensors"
    else
      chosen="$(maybe_append_safetensors "$chosen")"
    fi
  fi

  printf '%s' "$chosen"
}

download_one() {
  local url="$1"
  local dest_key="${2:-checkpoints}"
  local filename_override="${3:-}"

  local dest_dir="${DEST_MAP[$dest_key]:-${DEST_MAP[checkpoints]}}"
  ensure_dir "$dest_dir"

  local final_name
  if [[ -n "$filename_override" ]]; then
    final_name="$filename_override"
  else
    final_name="$(resolve_filename "$url")"
  fi

  local dest_path="${dest_dir%/}/${final_name}"

  if [[ -f "$dest_path" ]]; then
    echo "✔ Υπάρχει ήδη: $dest_path — παράλειψη"
    return 0
  fi

  echo "↓ Κατέβασμα:"
  echo "   URL:  $url"
  echo "   Σε:   $dest_dir"
  echo "   Όνομα: $final_name"

  aria2c "${ARIA2_COMMON[@]}" -d "$dest_dir" -o "$final_name" "$url" \
    && echo "✔ ΟΚ: $dest_path" \
    || echo "❌ Αποτυχία: $url"
}

main() {
  if [[ ! -f "$MODELS_LIST" ]]; then
    echo "Δεν βρέθηκε το $MODELS_LIST"
    exit 1
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    # skip κενές ή σχόλια
    [[ -z "${line// /}" ]] && continue
    [[ "$line" =~ ^# ]] && continue

    # Στήλες: url [dest_key] [filename]
    # Χώρισε με whitespace (tab/space)
    url=""; dest=""; fname=""
    read -r url dest fname <<<"$line"

    if [[ -z "${url:-}" ]]; then
      echo "⚠️  Παράλειψη άδειας γραμμής"
      continue
    fi

    # Αν το dest λείπει ή δεν ανήκει στα γνωστά keys → default checkpoints
    if [[ -z "${dest:-}" || -z "${DEST_MAP[$dest]+_}" ]]; then
      dest="checkpoints"
    fi

    # Κατέβασε
    download_one "$url" "$dest" "${fname:-}"
  done < "$MODELS_LIST"
}

main "$@"
