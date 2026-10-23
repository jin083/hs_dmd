#!/bin/bash
set -eo pipefail
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
if [ "$(ps -o comm= -p "$PPID")" = VBoxService ]; then renice 19 -p "$PPID" >/dev/null 2>&1 || true; fi
cd /home/ise/C_DRIVE/Temp/dmd-program-20261023
lsusb > guest_usb.txt
impact -batch identify.cmd > impact_identify.log 2>&1
tail -n 70 impact_identify.log
