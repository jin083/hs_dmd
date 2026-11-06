#!/bin/bash
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
cd /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-finalize-20261028T085433Z
impact -batch flash_boot_status.cmd > flash_boot_status.log 2>&1
rc=$?
echo $rc > flash_boot_status.exitcode
exit $rc
