#!/bin/bash
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
cd /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-probe-20261028T033858Z || exit 2
timeout 60s impact -batch identify_slow.cmd > identify_slow.log 2>&1
rc=$?
echo "$rc" > identify_slow.exitcode
exit "$rc"
