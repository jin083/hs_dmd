import hashlib,json,shlex,shutil
from datetime import datetime,timezone
import run_step as s
art=s.ROOT/'artifacts/dmd-spi-20261028'
progress=json.loads((s.FOLDER/'read_progress.json').read_text())
assert progress['complete'] and progress['read_bytes']==4194304 and progress['non_ff_bytes']==0
assert hashlib.sha256((art/'original_apps_full.bin').read_bytes()).hexdigest()=='7ec0b170de54be4b6b99c8df3fce0f8a713a18230de54478ed0e315f88de660f'
assert hashlib.sha256((art/'d202_spi_boot.mcs').read_bytes()).hexdigest()=='249fd0e9ccbc4f8dc12139fa2e11a22a9a3a87f2119ad81952e6e26f56c23938'
assert json.loads((art/'recheck_071935/backup_comparison.json').read_text())['backup_verified']
s.p.require_lx50_chain((s.FOLDER/'chain.cdf').read_text())
commands='''setMode -bs
addDevice -p 1 -part xc5vlx50
addDevice -p 2 -part xc5vlx30
setCable -p usb21 -baud 1500000
attachFlash -p 1 -spi S25FL032P
assignFileToAttachedFlash -p 1 -file d202_spi_boot.mcs
Program -p 1 -dataWidth 1 -spionly -v -loadfpga
ReadStatusRegister -p 1
quit
'''
(s.FOLDER/'program32.cmd').write_text(commands)
latest=json.loads((art/'latest_result.json').read_text())
latest.update(status='programming_d202_with_32bit_impact',updated_utc=datetime.now(timezone.utc).isoformat(),postwrite_read_blank=True,postwrite_read_bytes=4194304,all_impact_operations_stopped=False,active_fpga_design='temporary_spi_access_core',recovery_program_tool='ISE 14.7 lin 32-bit',recovery_program_erase=False)
(art/'latest_result.json').write_text(json.dumps(latest,indent=2)+'\n')
body='''source /opt/Xilinx/14.7/ISE_DS/settings32.sh >/dev/null 2>&1
scratch=$(mktemp -d /tmp/dmd_flash_recovery32.XXXXXX)
cp d202_spi_boot.mcs d202_spi_boot.cfi program32.cmd "$scratch/"
printf '%s' "$scratch" > program32_guest_dir.txt
cd "$scratch"
echo '249fd0e9ccbc4f8dc12139fa2e11a22a9a3a87f2119ad81952e6e26f56c23938  d202_spi_boot.mcs' | sha256sum -c - || exit 1
/opt/Xilinx/14.7/ISE_DS/ISE/bin/lin/impact -batch program32.cmd > '''+shlex.quote(s.GUEST+'/program32.log')+''' 2>&1
rc=$?
echo $rc > '''+shlex.quote(s.GUEST+'/program32.exitcode')+'''
exit $rc'''
print('Programming D202 to confirmed blank APPS Flash with 32-bit iMPACT; erase omitted; verify enabled.',flush=True)
s.guest('program32',body,timeout=1800)
log=(s.FOLDER/'program32.log').read_text(errors='replace')
print(log)
