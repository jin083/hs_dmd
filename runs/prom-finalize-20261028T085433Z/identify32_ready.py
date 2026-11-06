import run_step as s
s.guest('usb32_link', '''scratch=$(cat usb32_guest_dir.txt)
ln -s libusb-0.1.so.4.4.4 "$scratch/usr/lib/libusb.so"
''',timeout=15)
import identify32_usb
