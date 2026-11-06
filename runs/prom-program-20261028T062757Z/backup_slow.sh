#!/bin/bash
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
cd /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-program-20261028T062757Z
work=$(mktemp -d /tmp/dmd_flash_slow.XXXXXX)
echo "$work" > backup_slow_guest_dir.txt
cp backup_slow.cmd "$work/"
cd "$work"
impact -batch backup_slow.cmd > /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-program-20261028T062757Z/backup_slow.log 2>&1
rc=$?
cp original_apps_full.mcs /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-program-20261028T062757Z/
echo $rc > /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-program-20261028T062757Z/backup_slow.exitcode
exit $rc
