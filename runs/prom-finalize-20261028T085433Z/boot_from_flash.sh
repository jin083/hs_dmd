#!/bin/bash
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
cd /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-finalize-20261028T085433Z
impact -batch boot_from_flash.cmd > boot_from_flash.log 2>&1
rc=$?
echo $rc > boot_from_flash.exitcode
exit $rc
