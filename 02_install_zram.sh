#!/usr/bin/env bash
set -e

KVER="$(uname -r)"
sudo apt-get update
sudo apt-get install -y "linux-modules-extra-$KVER" zram-tools
echo -e "ALGO=lz4\nPERCENT=25\nPRIORITY=100" | sudo tee /etc/default/zramswap >/dev/null
sudo modprobe zram
sudo systemctl enable --now zramswap
swapon --show; echo; zramctl
