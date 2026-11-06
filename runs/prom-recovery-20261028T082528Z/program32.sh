#!/bin/bash
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
cd /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-recovery-20261028T082528Z
source /opt/Xilinx/14.7/ISE_DS/settings32.sh >/dev/null 2>&1
scratch=$(mktemp -d /tmp/dmd_flash_recovery32.XXXXXX)
cp d202_spi_boot.mcs d202_spi_boot.cfi program32.cmd "$scratch/"
printf '%s' "$scratch" > program32_guest_dir.txt
cd "$scratch"
echo '249fd0e9ccbc4f8dc12139fa2e11a22a9a3a87f2119ad81952e6e26f56c23938  d202_spi_boot.mcs' | sha256sum -c - || exit 1
/opt/Xilinx/14.7/ISE_DS/ISE/bin/lin/impact -batch program32.cmd > /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-recovery-20261028T082528Z/program32.log 2>&1
rc=$?
echo $rc > /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-recovery-20261028T082528Z/program32.exitcode
exit $rc
