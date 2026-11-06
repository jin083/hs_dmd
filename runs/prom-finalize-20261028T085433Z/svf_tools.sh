#!/bin/bash
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
cd /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-finalize-20261028T085433Z
command -v svf2xsvf
find /opt/Xilinx/14.7/ISE_DS/ISE/bin -maxdepth 2 -iname "*svf*" -print
