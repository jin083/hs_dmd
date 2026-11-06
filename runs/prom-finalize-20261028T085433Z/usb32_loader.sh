#!/bin/bash
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
cd /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-finalize-20261028T085433Z
source /opt/Xilinx/14.7/ISE_DS/settings32.sh >/dev/null 2>&1
scratch=$(cat usb32_guest_dir.txt)
export LD_LIBRARY_PATH="$scratch/usr/lib:$LD_LIBRARY_PATH"
export XIL_IMPACT_USE_LIBUSB=1
LD_DEBUG=libs linux32 /opt/Xilinx/14.7/ISE_DS/ISE/bin/lin/impact -batch identify32_usb.cmd > loader_stdout.txt 2> loader_trace.txt
grep -i -E 'libusb|jtpport|not found|error' loader_trace.txt | tail -n 60
strings /opt/Xilinx/14.7/ISE_DS/ISE/lib/lin/libCseXilCommJtpAPI.so | grep -E 'libusb|LIBUSB|/usr/lib'

