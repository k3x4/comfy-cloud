#!/usr/bin/env bash
set -e

sudo apt update && sudo apt -y upgrade
sudo apt install -y ubuntu-drivers-common build-essential dkms linux-headers-$(uname -r) \
                    git curl python3-venv python3-dev rclone aria2

sudo ubuntu-drivers autoinstall || true

echo "✅ Nvidia driver OK | REBOOT NEEDED"
