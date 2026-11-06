#!/bin/bash
cd /home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/hs_dmd/runs/prom-probe-20261028T050157Z || exit 2
cp /opt/Xilinx/14.7/ISE_DS/ISE/data/spi.acd reference/ise-spi.acd
cp /opt/Xilinx/14.7/ISE_DS/ISE/doc/usenglish/isehelp/pim_r_supported_spi_bpi_proms.htm reference/
cp /opt/Xilinx/14.7/ISE_DS/ISE/doc/usenglish/isehelp/pim_p_configure_spi_bpi_through_fpga.htm reference/
find /opt/Xilinx/14.7/ISE_DS/ISE/doc/usenglish/isehelp -iname "*readback*" -o -iname "*idcode*" > help_readback_files.txt
