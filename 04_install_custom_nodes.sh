#!/usr/bin/env bash
set -euo pipefail

### ——— ΡΥΘΜΙΣΕΙΣ ———
COMFY_DIR="${COMFY_DIR:-$HOME/comfy}"
CUSTOM_NODES_DIR="${CUSTOM_NODES_DIR:-$HOME/comfy/custom_nodes}"
VENV_DIR="${VENV_DIR:-$HOME/comfy/venv}"
PORT="${PORT:-8188}"
HOST="${HOST:-127.0.0.1}"
BASE_URL="http://$HOST:$PORT"
NODES_LIST="${NODES_LIST:-./nodes.txt}"   # ένα URL ανά γραμμή (βλ. παράδειγμα πιο κάτω)

### ——— Βοηθητικά ———
die(){ echo "❌ $*" >&2; exit 1; }
curl_ok(){ curl -sS -m 2 -o /dev/null -w "%{http_code}" "$1" 2>/dev/null || true; }

### ——— 0) Venv & έλεγχοι ———
[ -d "$COMFY_DIR" ]       || die "COMFY_DIR δεν βρέθηκε: $COMFY_DIR"
[ -d "$VENV_DIR" ]        || die "VENV_DIR δεν βρέθηκε: $VENV_DIR"
[ -f "$NODES_LIST" ]      || die "Λείπει το nodes.txt: $NODES_LIST"
source "$VENV_DIR/bin/activate"

mkdir -p "$CUSTOM_NODES_DIR"

### ——— 2) Ξεκίνα ComfyUI στο background ———
echo "▶️  Εκκίνηση ComfyUI (port $PORT)…"
cd "$COMFY_DIR"
python main.py --port "$PORT" --listen >/dev/null 2>&1 &
COMFY_PID=$!

cleanup() {
  echo -e "\n⏹️  Τερματισμός ComfyUI (PID $COMFY_PID)…"
  kill "$COMFY_PID" 2>/dev/null || true
  wait "$COMFY_PID" 2>/dev/null || true
}
trap cleanup EXIT

### ——— 3) Περίμενε να γίνει διαθέσιμο το HTTP ———
echo "⏳ Περιμένω να σηκωθεί το ComfyUI…"
for i in {1..120}; do
  code=$(curl_ok "$BASE_URL/")
  if [ "$code" = "200" ]; then
    echo "✅ ComfyUI είναι επάνω."
    break
  fi
  sleep 1
  [ $i -eq 120 ] && die "ComfyUI δεν απάντησε εγκαίρως."
done

### ——— 4) Εγκατάσταση nodes μέσω Manager REST ———
# Προαιρετικός έλεγχος ότι το endpoint υπάρχει (αν όχι, ίσως χρειάζεται 1ο restart)
code=$(curl_ok "$BASE_URL/manager/list")
if [ "$code" != "200" ]; then
  echo "ℹ️  Το /manager δεν απαντά ακόμη. Ίσως ο Manager φορτώνει στο 1ο run. Περιμένω λίγο…"
  sleep 3
fi

echo "🔧 Εγκατάσταση custom nodes από: $NODES_LIST"
while IFS= read -r URL; do
  # Αγνόησε κενές γραμμές & σχόλια
  URL_TRIM="${URL#"${URL%%[![:space:]]*}"}"
  [ -z "$URL_TRIM" ] && continue
  [[ "$URL_TRIM" =~ ^# ]] && continue

  echo "➡️  Installing: $URL_TRIM"
  resp=$(curl -sS -m 120 -X POST "$BASE_URL/manager/install" \
            -H 'Content-Type: application/json' \
            -d "{\"url\":\"$URL_TRIM\"}")
  echo "   ↩︎ $resp"

  # Μικρό wait μεταξύ installs (μερικά repos τραβάνε deps)
  sleep 2
done < "$NODES_LIST"

### ——— 5) Reload κόμβων ———
echo "🔄 /manager/reload"
curl -sS -X GET "$BASE_URL/manager/reload" >/dev/null || true
sleep 2

echo "🎉 Όλα έτοιμα. Θα τερματίσω το ComfyUI."
# (το trap θα καλέσει cleanup)
