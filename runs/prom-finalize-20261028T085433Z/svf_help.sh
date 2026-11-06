#!/bin/bash
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
cd /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-finalize-20261028T085433Z
mkdir -p offline_help
cd offline_help
impact -batch ../svf_help.cmd > ../svf_help.log 2>&1
cat ../svf_help.log
