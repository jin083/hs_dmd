#!/bin/bash
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
cd /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-finalize-20261028T085433Z
impact -batch chunk_3584_4096.cmd > chunk_3584_4096.log 2>&1
rc=$?
echo $rc > chunk_3584_4096.exitcode
exit $rc
