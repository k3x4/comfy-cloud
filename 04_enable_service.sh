#!/usr/bin/env bash
set -e

USERNAME="${1:-user}"
SRC="./services/comfy.service"
DEST="/etc/systemd/system/comfy.service"

sudo cp "$SRC" "$DEST"

if sudo grep -qE '^[[:space:]]*User=' "$DEST"; then
  sudo sed -i -E "s/^[[:space:]]*User=.*/User=${USERNAME}/" "$DEST"
else
  sudo sed -i "/^\[Service\]/a User=${USERNAME}" "$DEST"
fi

sudo systemctl daemon-reexec
sleep 1
sudo systemctl daemon-reload
sleep 1
sudo systemctl enable comfy
sleep 1
sudo systemctl start comfyui
sleep 1
sudo systemctl --no-pager status comfy || true

# sudo systemctl daemon-reexec
# sudo systemctl daemon-reload
# sudo systemctl enable comfyui
# sudo systemctl start comfyui
# sudo systemctl status comfyui

# journalctl -u comfyui -f 