#!/bin/bash
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
cd /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-program-20261028T062757Z
for image_dir in /tmp/dmd_prom_image.*; do
 if cmp -s "$image_dir/d202_spi_boot.bit" d202_spi_boot.bit; then cp "$image_dir/d202_spi_boot.cfi" d202_spi_boot.cfi; fi
done
cat d202_spi_boot.cfi
