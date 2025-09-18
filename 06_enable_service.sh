#!/usr/bin/env bash
set -euo pipefail

USERNAME="${1:-user}"
SRC="./services/comfy.service"
DEST="/etc/systemd/system/comfy.service"
HOME_DIR="$(eval echo "~${USERNAME}")"

sudo cp "$SRC" "$DEST"

if sudo grep -qE '^[[:space:]]*User=' "$DEST"; then
  sudo sed -i -E "s/^[[:space:]]*User=.*/User=${USERNAME}/" "$DEST"
else
  sudo sed -i "/^\[Service\]/a User=${USERNAME}" "$DEST"
fi

sudo sed -i "s#%h#${HOME_DIR}#g" "$DEST"

sudo systemctl daemon-reexec
sleep 1
sudo systemctl daemon-reload
sleep 1
sudo systemctl enable comfy
sleep 1
sudo systemctl start comfy
sleep 1
sudo systemctl --no-pager status comfy || true
journalctl -u comfy -f

# sudo systemctl daemon-reexec
# sudo systemctl daemon-reload
# sudo systemctl enable comfy
# sudo systemctl start comfy
# sudo systemctl status comfy

# journalctl -u comfy -f