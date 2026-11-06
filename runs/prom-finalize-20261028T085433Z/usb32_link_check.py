import run_step as s
s.guest('usb32_link_check', '''source /opt/Xilinx/14.7/ISE_DS/settings32.sh >/dev/null 2>&1
scratch=$(cat usb32_guest_dir.txt)
export LD_LIBRARY_PATH="$scratch/usr/lib:$LD_LIBRARY_PATH"
ldd "$scratch/usr/lib/libusb-0.1.so.4.4.4"
ldd /opt/Xilinx/14.7/ISE_DS/ISE/lib/lin/libCseXilCommJtpPortLibUsb.so
strings /opt/Xilinx/14.7/ISE_DS/ISE/lib/lin/libCseXilCommJtpPortLibUsb.so | grep -E 'libusb|\.so|XIL_'
''',timeout=20)
