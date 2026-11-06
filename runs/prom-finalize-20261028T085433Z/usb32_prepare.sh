#!/bin/bash
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
cd /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-finalize-20261028T085433Z
scratch=$(mktemp -d /tmp/dmd_usb32.XXXXXX)
printf '%s' "$scratch" > usb32_guest_dir.txt
mkdir "$scratch/rpmdb"
rpm --dbpath "$scratch/rpmdb" --initdb
rpm --dbpath "$scratch/rpmdb" --import RPM-GPG-KEY-CentOS-6
rpm --dbpath "$scratch/rpmdb" -K libusb-0.1.12-23.el6.i686.rpm > usb32_signature.txt 2>&1
cat usb32_signature.txt
rpm --dbpath "$scratch/rpmdb" -K libusb-0.1.12-23.el6.i686.rpm || exit 1
rpm2cpio libusb-0.1.12-23.el6.i686.rpm > "$scratch/package.cpio"
cd "$scratch"
cpio -id --no-absolute-filenames < package.cpio
file usr/lib/libusb-0.1.so.4.4.4

