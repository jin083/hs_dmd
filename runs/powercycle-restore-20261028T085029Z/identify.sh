#!/bin/bash
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
cd /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/powercycle-restore-20261028T085029Z
impact -batch identify.cmd > identify.log 2>&1
rc=$?
echo $rc > identify.exitcode
exit $rc
