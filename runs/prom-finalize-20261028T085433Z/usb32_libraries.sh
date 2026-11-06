#!/bin/bash
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
cd /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-finalize-20261028T085433Z
find /usr/lib /lib /opt/Xilinx/14.7/ISE_DS/common/lib/lin /opt/Xilinx/14.7/ISE_DS/ISE/lib/lin -maxdepth 3 -iname '*usb*so*' -print
ldd /opt/Xilinx/14.7/ISE_DS/ISE/lib/lin/libCseJtag.so

