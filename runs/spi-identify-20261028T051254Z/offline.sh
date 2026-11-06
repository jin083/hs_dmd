#!/bin/bash
cd /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/spi-identify-20261028T051254Z || exit 2
cp /opt/Xilinx/14.7/ISE_DS/ISE/doc/usenglish/isehelp/pim_p_readbacks.htm reference/
cp /opt/Xilinx/14.7/ISE_DS/ISE/doc/usenglish/isehelp/pim_c_introduction_indirect_programming.htm reference/
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
timeout 30s impact -batch offline.cmd > offline.log 2>&1
