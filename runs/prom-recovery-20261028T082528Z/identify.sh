#!/bin/bash
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
cd /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-recovery-20261028T082528Z
impact -batch identify.cmd > identify.log 2>&1
rc=$?
echo $rc > identify.exitcode
exit $rc
