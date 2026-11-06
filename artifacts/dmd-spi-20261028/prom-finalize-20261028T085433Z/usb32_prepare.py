import urllib.request
import run_step as s
url='https://vault.centos.org/6.10/os/i386/RPM-GPG-KEY-CentOS-6'
with urllib.request.urlopen(url,timeout=20) as r: data=r.read(32768)
assert b'BEGIN PGP PUBLIC KEY BLOCK' in data
(s.FOLDER/'RPM-GPG-KEY-CentOS-6').write_bytes(data)
s.guest('usb32_prepare', '''scratch=$(mktemp -d /tmp/dmd_usb32.XXXXXX)
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
''',timeout=30)
