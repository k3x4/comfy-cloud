#!/usr/bin/env bash
set -e

sudo apt update && sudo apt -y upgrade
sudo apt install -y ubuntu-drivers-common build-essential dkms linux-headers-$(uname -r) \
                    git curl python3-venv python3-dev zram-tools

sudo ubuntu-drivers autoinstall || true

echo -e "ALGO=lz4\nPERCENT=25" | sudo tee /etc/default/zramswap
sudo systemctl enable --now zramswap
sleep 1
sudo systemctl is-enabled zramswap

echo "✅ Nvidia driver OK | REBOOT NEEDED"