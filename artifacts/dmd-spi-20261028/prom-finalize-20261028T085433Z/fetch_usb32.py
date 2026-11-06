import hashlib,urllib.request
from pathlib import Path
folder=Path(__file__).resolve().parent
url='https://vault.centos.org/6.10/os/i386/Packages/libusb-0.1.12-23.el6.i686.rpm'
try:
    with urllib.request.urlopen(url,timeout=25) as r:
        data=r.read(1024*1024)
        assert data[:4]==b'\xed\xab\xee\xdb'
    (folder/'libusb-0.1.12-23.el6.i686.rpm').write_bytes(data)
    print({'source':url,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()})
except Exception as exc:
    print(type(exc).__name__+': '+str(exc))
    raise SystemExit(1)
