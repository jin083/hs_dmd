#!/bin/bash
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
cd /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-recovery-20261028T082528Z
mkdir -p offline_svf
cd offline_svf
impact -batch ../offline_default.cmd > ../offline_svf_default.log 2>&1
impact -batch ../offline_width1.cmd > ../offline_svf_width1.log 2>&1
tail -n 22 ../offline_svf_default.log
tail -n 22 ../offline_svf_width1.log
ls -lh *.svf

