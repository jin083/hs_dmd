#!/bin/bash
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
cd /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-finalize-20261028T085433Z
impact -batch page_status_probe.cmd > page_status_probe.log 2>&1
rc=$?
echo $rc > page_status_probe.exitcode
exit $rc
