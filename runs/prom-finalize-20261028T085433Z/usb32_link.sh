#!/bin/bash
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
cd /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-finalize-20261028T085433Z
scratch=$(cat usb32_guest_dir.txt)
ln -s libusb-0.1.so.4.4.4 "$scratch/usr/lib/libusb.so"

