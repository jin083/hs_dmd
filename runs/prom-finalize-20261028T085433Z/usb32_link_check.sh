#!/bin/bash
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
cd /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-finalize-20261028T085433Z
source /opt/Xilinx/14.7/ISE_DS/settings32.sh >/dev/null 2>&1
scratch=$(cat usb32_guest_dir.txt)
export LD_LIBRARY_PATH="$scratch/usr/lib:$LD_LIBRARY_PATH"
ldd "$scratch/usr/lib/libusb-0.1.so.4.4.4"
ldd /opt/Xilinx/14.7/ISE_DS/ISE/lib/lin/libCseXilCommJtpPortLibUsb.so
strings /opt/Xilinx/14.7/ISE_DS/ISE/lib/lin/libCseXilCommJtpPortLibUsb.so | grep -E 'libusb|\.so|XIL_'

