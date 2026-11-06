#!/bin/bash
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
cd /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-finalize-20261028T085433Z
source /opt/Xilinx/14.7/ISE_DS/settings32.sh >/dev/null 2>&1
command -v linux32
linux32 /opt/Xilinx/14.7/ISE_DS/ISE/bin/lin/impact -batch identify32.cmd > identify32.log 2>&1
rc=$?
echo $rc > identify32.exitcode
cat identify32.log
exit $rc
