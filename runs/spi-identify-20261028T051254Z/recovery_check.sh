#!/bin/bash
cd /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/spi-identify-20261028T051254Z || exit 2
lsusb > guest_usb_recovery.txt
ps -eo pid,comm > guest_processes_recovery.txt
sudo -n -l > guest_sudo_permissions.txt 2>&1
