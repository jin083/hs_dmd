#!/bin/bash
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
cd /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-recovery-20261028T082528Z
pgrep -x impact > final_impact_pids.txt || true
cat final_impact_pids.txt
