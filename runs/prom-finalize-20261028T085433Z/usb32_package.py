import run_step as s
s.guest('usb32_package', '''rpm -K libusb-0.1.12-23.el6.i686.rpm
rpm -qpl libusb-0.1.12-23.el6.i686.rpm
''',timeout=20)
