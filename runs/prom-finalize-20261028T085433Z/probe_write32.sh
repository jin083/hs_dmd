#!/bin/bash
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
cd /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-finalize-20261028T085433Z
source /opt/Xilinx/14.7/ISE_DS/settings32.sh >/dev/null 2>&1
scratch=$(cat usb32_guest_dir.txt)
export LD_LIBRARY_PATH="$scratch/usr/lib:$LD_LIBRARY_PATH"
export XIL_IMPACT_USE_LIBUSB=1
linux32 /opt/Xilinx/14.7/ISE_DS/ISE/bin/lin/impact -batch probe_write32.cmd > probe_write32.log 2>&1
rc=$?
echo $rc > probe_write32.exitcode
cat probe_write32.log
exit $rc
