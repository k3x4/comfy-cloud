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

sudo systemctl daemon-reload
sudo systemctl enable --now comfy.service