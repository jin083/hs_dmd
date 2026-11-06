#!/bin/bash
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
cd /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-recovery-20261028T082528Z
mkdir -p offline_assign
cd offline_assign
impact -batch ../offline_assign.cmd > ../offline_assign.log 2>&1
cat ../offline_assign.log
cat ../offline_assigned.cdf
source /opt/Xilinx/14.7/ISE_DS/settings32.sh >/dev/null 2>&1
/opt/Xilinx/14.7/ISE_DS/ISE/bin/lin/impact -batch ../offline_help.cmd > ../offline_32bit.log 2>&1
head -n 6 ../offline_32bit.log

