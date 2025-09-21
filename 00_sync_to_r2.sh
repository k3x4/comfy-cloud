#!/usr/bin/env bash
set -euo pipefail

read -s -p "Passphrase: " PASS; echo; set -a; . <(echo "$PASS" | gpg --batch --passphrase-fd 0 --pinentry-mode loopback -d .env.gpg); set +a

# SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# [ -f "$SCRIPT_DIR/.env" ] && { set -a; . "$SCRIPT_DIR/.env"; set +a; }

: "${R2_ACCOUNT_ID:?R2_ACCOUNT_ID missing}"
: "${R2_ACCESS_KEY_ID:?R2_ACCESS_KEY_ID missing}"
: "${R2_SECRET_ACCESS_KEY:?R2_SECRET_ACCESS_KEY missing}"
: "${R2_BUCKET:?R2_BUCKET missing}"
R2_PREFIX="${R2_PREFIX:-backup}"
COMFY_DIR="${COMFY_DIR:-$HOME/comfy}"

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

rclone --config "$TMPCONF" mkdir "r2:${R2_BUCKET}" >/dev/null 2>&1 || true

DATA_DIRS=(user output input)

echo "==> Mirror ${COMFY_DIR} -> r2:${R2_BUCKET}/${R2_PREFIX}"
for d in "${DATA_DIRS[@]}"; do
  SRC="${COMFY_DIR}/${d}"
  if [ -d "$SRC" ]; then
    echo "--> ${d}"
    rclone --config "$TMPCONF" sync \
      "$SRC" "r2:${R2_BUCKET}/${R2_PREFIX}/${d}" \
      --fast-list --size-only \
      --exclude ".git/**" --exclude "__pycache__/**" \
      --transfers 8 --checkers 8 --progress
  fi
done

[ -f "${COMFY_DIR}/extra_model_paths.yaml" ] && \
  rclone --config "$TMPCONF" copy "${COMFY_DIR}/extra_model_paths.yaml" \
    "r2:${R2_BUCKET}/${R2_PREFIX}/" -P

rm -f "$TMPCONF"
echo "✅ Sync OK"

