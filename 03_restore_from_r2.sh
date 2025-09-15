#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
[ -f ".env" ] && set -a && . ./.env && set +a

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

mkdir -p "$COMFY_DIR"/{user,output,input,models,custom_nodes}

for d in user output input models custom_nodes; do
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

###############

VENV_PY="$COMFY_DIR/venv/bin/python"

if [ -x "$VENV_PY" ]; then
  CONSTRAINTS="$(mktemp)"
  for PKG in torch torchvision torchaudio xformers onnxruntime onnxruntime-gpu; do
    VER="$($VENV_PY -m pip show "$PKG" 2>/dev/null | awk -F': ' '/^Version/{print $2}')"
    [ -n "$VER" ] && echo "${PKG}==${VER}" >> "$CONSTRAINTS"
  done

  PIP_NO_INPUT=1 "$VENV_PY" -m pip install -U pip wheel setuptools

  echo "== Scanning requirements in: $COMFY_DIR/custom_nodes" | tee -a "$COMFY_DIR/user/install_requirements.log"

  mapfile -t REQS < <(find "$COMFY_DIR/custom_nodes" -maxdepth 2 -type f -iname 'requirements*.txt' | sort)

  if [ "${#REQS[@]}" -eq 0 ]; then
    echo "[INFO] No requirements*.txt found under custom_nodes (maxdepth=2)." | tee -a "$COMFY_DIR/user/install_requirements.log"
  else
    for REQ in "${REQS[@]}"; do
      echo "-> Installing from: $REQ" | tee -a "$COMFY_DIR/user/install_requirements.log"
      if [ -s "$CONSTRAINTS" ]; then
        PIP_NO_INPUT=1 "$VENV_PY" -m pip install -r "$REQ" -c "$CONSTRAINTS" 2>&1 | tee -a "$COMFY_DIR/user/install_requirements.log"
      else
        PIP_NO_INPUT=1 "$VENV_PY" -m pip install -r "$REQ" 2>&1 | tee -a "$COMFY_DIR/user/install_requirements.log"
      fi
    done
  fi

  while IFS= read -r -d '' PYP; do
    NODE_DIR="$(dirname "$PYP")"
    if ! find "$NODE_DIR" -maxdepth 1 -type f -iname 'requirements*.txt' | grep -q . ; then
      echo "-> Editable install (pyproject.toml): $NODE_DIR" | tee -a "$COMFY_DIR/user/install_requirements.log"
      PIP_NO_INPUT=1 "$VENV_PY" -m pip install -e "$NODE_DIR" 2>&1 | tee -a "$COMFY_DIR/user/install_requirements.log" || \
        echo "[WARN] pyproject install failed for $NODE_DIR (ignored)" | tee -a "$COMFY_DIR/user/install_requirements.log"
    fi
  done < <(find "$COMFY_DIR/custom_nodes" -maxdepth 2 -type f -name 'pyproject.toml' -print0)

  rm -f "$CONSTRAINTS"
else
  echo "[WARN] Δεν βρέθηκε venv στο $COMFY_DIR/venv — παράλειψη εγκατάστασης requirements custom nodes."
fi
