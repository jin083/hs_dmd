#!/bin/bash
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
cd /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-program-20261028T062757Z
work=$(mktemp -d /tmp/dmd_flash_verify.XXXXXX)
cp original_apps_full.mcs slow_chain.cdf verify_backup.cmd "$work/"
cd "$work"
impact -batch verify_backup.cmd > /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-program-20261028T062757Z/verify_backup.log 2>&1
rc=$?
echo $rc > /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-program-20261028T062757Z/verify_backup.exitcode
exit $rc
