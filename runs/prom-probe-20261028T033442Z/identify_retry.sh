#!/bin/bash
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
cd /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-probe-20261028T033442Z || exit 2
timeout 60s impact -batch identify_retry.cmd > identify_retry.log 2>&1
rc=$?
echo "$rc" > identify_retry.exitcode
exit "$rc"
