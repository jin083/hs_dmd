#!/bin/bash
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
cd /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-finalize-20261028T085433Z
rpm -K libusb-0.1.12-23.el6.i686.rpm
rpm -qpl libusb-0.1.12-23.el6.i686.rpm

