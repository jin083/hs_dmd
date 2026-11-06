import hashlib,json
from datetime import datetime,timezone
import run_step as s
art=s.ROOT/'artifacts/dmd-spi-20261028'
raw=(art/'d202_spi_boot.mcs').read_bytes()
assert hashlib.sha256(raw).hexdigest()=='249fd0e9ccbc4f8dc12139fa2e11a22a9a3a87f2119ad81952e6e26f56c23938'
lines=raw.splitlines()[:17]
records=[bytes.fromhex(line[1:].decode()) for line in lines]
assert records[0][3]==4 and records[0][4:6]==b'\x00\x00'
assert all(sum(r)%256==0 for r in records)
assert all(r[3]==0 and int.from_bytes(r[1:3],'big')==i*16 and r[0]==16 for i,r in enumerate(records[1:]))
(s.FOLDER/'d202_first_page.mcs').write_bytes(b'\n'.join(lines+[b':00000001FF'])+b'\n')
(s.FOLDER/'probe_write32.cmd').write_text('''setMode -bs
addDevice -p 1 -part xc5vlx50
addDevice -p 2 -part xc5vlx30
setCable -p usb21 -baud 1500000
attachFlash -p 1 -spi S25FL032P
assignFileToAttachedFlash -p 1 -file d202_first_page.mcs
Program -p 1 -dataWidth 1 -spionly -v
quit
''')
latest=json.loads((art/'latest_result.json').read_text())
latest.update(status='probing_flash_write_with_32bit_lib_usb',updated_utc=datetime.now(timezone.utc).isoformat(),all_impact_operations_stopped=False,active_fpga_design='transitioning_to_spi_access_core',flash_boot_integrity='not_bootable_recovery_in_progress',recovery_blocker=None)
(art/'latest_result.json').write_text(json.dumps(latest,indent=2)+'\n')
s.guest('probe_write32', '''source /opt/Xilinx/14.7/ISE_DS/settings32.sh >/dev/null 2>&1
scratch=$(cat usb32_guest_dir.txt)
export LD_LIBRARY_PATH="$scratch/usr/lib:$LD_LIBRARY_PATH"
export XIL_IMPACT_USE_LIBUSB=1
linux32 /opt/Xilinx/14.7/ISE_DS/ISE/bin/lin/impact -batch probe_write32.cmd > probe_write32.log 2>&1
rc=$?
echo $rc > probe_write32.exitcode
cat probe_write32.log
exit $rc''',timeout=180)
