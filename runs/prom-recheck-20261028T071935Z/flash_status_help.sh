#!/bin/bash
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
cd /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-recheck-20261028T071935Z
impact -batch flash_status_help.cmd > flash_status_help.log 2>&1
rc=$?
echo $rc > flash_status_help.exitcode
exit $rc
