#!/usr/bin/env bash

bash ./02_install_zram.sh
sleep 3
bash ./03_install_comfy.sh
bash ./04_install_custom_nodes.sh
sleep 3
bash ./05_download_models.sh
bash ./06_restore_from_r2.sh
bash ./07_enable_service.sh
