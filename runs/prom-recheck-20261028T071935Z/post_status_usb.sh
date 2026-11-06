#!/bin/bash
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
cd /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-recheck-20261028T071935Z
lsusb > post_status_usb.txt
ps -eo pid,stat,comm > post_status_processes.txt
