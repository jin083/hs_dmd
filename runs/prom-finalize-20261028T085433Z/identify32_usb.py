import run_step as s
(s.FOLDER/'identify32_usb.cmd').write_text('setMode -bs\nsetCable -p usb21 -baud 1500000\nIdentify\nsaveCdf -file chain32_usb.cdf\nquit\n')
s.guest('identify32_usb', '''source /opt/Xilinx/14.7/ISE_DS/settings32.sh >/dev/null 2>&1
scratch=$(cat usb32_guest_dir.txt)
export LD_LIBRARY_PATH="$scratch/usr/lib:$LD_LIBRARY_PATH"
export XIL_IMPACT_USE_LIBUSB=1
linux32 /opt/Xilinx/14.7/ISE_DS/ISE/bin/lin/impact -batch identify32_usb.cmd > identify32_usb.log 2>&1
rc=$?
echo $rc > identify32_usb.exitcode
cat identify32_usb.log
exit $rc''',timeout=60)
s.p.require_lx50_chain((s.FOLDER/'chain32_usb.cdf').read_text())
print('32BIT_USB_CHAIN_CONFIRMED')
