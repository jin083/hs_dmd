#!/bin/bash
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
cd /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-recovery-20261028T082528Z
scratch=$(cat offline_svf_guest_dir.txt)
tail -n 12 "$scratch/width1_64.log"
tail -n 12 "$scratch/width1_32.log"
ls -lh "$scratch/"*.svf

