#!/usr/bin/env bash
set -euo pipefail

# cd "$(dirname "$0")"
# [ -f ".env" ] && set -a && . ./.env && set +a

read -s -p "Passphrase: " PASS; echo; set -a; . <(echo "$PASS" | gpg --batch --passphrase-fd 0 --pinentry-mode loopback -d .env.gpg); set +a

: "${R2_ACCOUNT_ID:?R2_ACCOUNT_ID missing}"
: "${R2_ACCESS_KEY_ID:?R2_ACCESS_KEY_ID missing}"
: "${R2_SECRET_ACCESS_KEY:?R2_SECRET_ACCESS_KEY missing}"
: "${R2_BUCKET:?R2_BUCKET missing}"
COMFY_DIR="${COMFY_DIR:-$HOME/comfy}"
R2_PREFIX="${R2_PREFIX:-backup}"

command -v rclone >/dev/null 2>&1 || { sudo apt update && sudo apt install -y rclone; }

TMPCONF="$(mktemp)"
cat > "$TMPCONF" <<CONF
[r2]
type = s3
provider = Cloudflare
access_key_id = ${R2_ACCESS_KEY_ID}
secret_access_key = ${R2_SECRET_ACCESS_KEY}
endpoint = https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com
no_check_bucket = true
CONF

[ -d "$COMFY_DIR/.git" ] || { echo "run 02_install_comfy.sh first"; exit 1; }

mkdir -p "$COMFY_DIR"/{user,output,input}

for d in user output input; do
  REM="r2:${R2_BUCKET}/${R2_PREFIX}/${d}"
  LOC="${COMFY_DIR}/${d}"
  echo "--> ${d}"
  rclone --config "$TMPCONF" copy "$REM" "$LOC" -P \
    --ignore-existing \
    --exclude ".git/**" --exclude "__pycache__/**" || true
done

rclone --config "$TMPCONF" copy "r2:${R2_BUCKET}/${R2_PREFIX}/extra_model_paths.yaml" \
  "$COMFY_DIR/" -P || true

rm -f "$TMPCONF"
