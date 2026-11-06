#!/bin/bash
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
cd /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-program-20261028T062757Z
impact -batch flash_cfi.cmd > flash_cfi.log 2>&1
rc=$?
echo $rc > flash_cfi.exitcode
exit $rc
