#!/usr/bin/env bash
set -euo pipefail

# -- Ρύθμιση .env (διαβάζει από project root ή από sync/.env) --
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ -f "$PROJECT_ROOT/.env" ]; then
  set -a; . "$PROJECT_ROOT/.env"; set +a
elif [ -f "$PROJECT_ROOT/sync/.env" ]; then
  set -a; . "$PROJECT_ROOT/sync/.env"; set +a
fi

: "${R2_ACCOUNT_ID:?R2_ACCOUNT_ID missing}"
: "${R2_ACCESS_KEY_ID:?R2_ACCESS_KEY_ID missing}"
: "${R2_SECRET_ACCESS_KEY:?R2_SECRET_ACCESS_KEY missing}"
: "${R2_BUCKET:?R2_BUCKET missing}"
R2_PREFIX="${R2_PREFIX:-backup}"
COMFY_DIR="${COMFY_DIR:-$HOME/ComfyUI}"

# -- rclone --
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

# -- Δημιουργία bucket/διαδρομής αν δεν υπάρχουν --
rclone --config "$TMPCONF" mkdir "r2:${R2_BUCKET}" >/dev/null 2>&1 || true

TS="$(date -u +%Y%m%d-%H%M%S)"
DATA_DIRS=(user output input models custom_nodes)

echo "==> Sync ${COMFY_DIR} -> r2:${R2_BUCKET}/${R2_PREFIX} (backup deleted/overwritten -> .trash/${TS})"

for d in "${DATA_DIRS[@]}"; do
  SRC="${COMFY_DIR}/${d}"
  if [ -d "$SRC" ]; then
    echo "--> ${d}"
    rclone --config "$TMPCONF" sync \
      "$SRC" "r2:${R2_BUCKET}/${R2_PREFIX}/${d}" \
      --backup-dir "r2:${R2_BUCKET}/${R2_PREFIX}/.trash/${TS}/${d}" \
      --fast-list --size-only \
      --exclude ".git/**" --exclude "__pycache__/**" \
      --transfers 8 --checkers 8 --progress
  fi
done

# Config αρχείο (αν υπάρχει)
if [ -f "${COMFY_DIR}/extra_model_paths.yaml" ]; then
  rclone --config "$TMPCONF" copy \
    "${COMFY_DIR}/extra_model_paths.yaml" "r2:${R2_BUCKET}/${R2_PREFIX}/" -P
fi

rm -f "$TMPCONF"
echo "✅ Sync ολοκληρώθηκε."
echo "ℹ️ Deleted/overwritten αρχεία μεταφέρθηκαν σε: r2:${R2_BUCKET}/${R2_PREFIX}/.trash/${TS}"
