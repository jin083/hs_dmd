import gzip,hashlib,json,shutil,zipfile
from datetime import datetime,timezone
import run_step as s
result=json.loads((s.FOLDER/'padded_program_result.json').read_text())
boot=json.loads((s.FOLDER/'flash_boot_result.json').read_text())
assert result['flash_program_verified'] and boot['flash_reload_successful']
root=s.ROOT/'artifacts/dmd-spi-20261028'
dest=root/s.FOLDER.name
dest.mkdir(exist_ok=True)
for f in s.FOLDER.iterdir():
 if f.is_file() and not f.name.startswith('chunk_') and f.suffix in {'.py','.log','.cmd','.svf','.json','.txt','.bin','.exitcode','.md'}:
  if f.name in {'usb32_guest_dir.txt'}:continue
  shutil.copyfile(f,dest/f.name)
with zipfile.ZipFile(dest/'chunk_evidence.zip','w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for f in sorted(s.FOLDER.glob('chunk_*')):
  if f.is_file():z.write(f,f.name)
with zipfile.ZipFile(dest/'chunk_evidence.zip') as z:assert z.testzip() is None
source=s.ROOT/'runs/prom-recovery-20261028T082528Z/offline_svf/default.svf'
with source.open('rb') as i,gzip.open(dest/'offline_default.svf.gz','wb',compresslevel=6) as o:shutil.copyfileobj(i,o)
records=[json.loads(f.read_text()) for f in sorted(s.FOLDER.glob('chunk_*.json'))]
assert len(records)==12 and sum(r['verified_bytes'] for r in records)==result['verified_bytes_including_ff_padding']
summary={'recorded_utc':datetime.now(timezone.utc).isoformat(),'target':'APPS SPI Flash, S25FL032P via JTAG LX50; LX30 unchanged','flash_program_verified':True,'flash_reload_successful':True,'physical_power_cycle_tested':False,'usb_abi_checked':False,'usb_status_execution':'failed','usb_status_error':'D4100 USB device unavailable','original_backup_preserved':True,'image_bytes':result['image_bytes'],'verified_flash_bytes_including_padding':result['verified_bytes_including_ff_padding'],'image_sha256':result['verified_image_sha256'],'total_chunk_elapsed_seconds':round(sum(r['elapsed_seconds'] for r in records),3),'chunk_records':records,'diagnosis':'2160-bit JTAG page scan left WEL set and data erased; padding to 8560 bits preserved SPI address/length/data and enabled successful program/readback. Internal vendor core cause remains unmeasured.','offline_source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'runtime':'ISE 14.7 lin64; Xilinx Platform Cable USB at 1.5MHz; no global driver/security changes','optional_32bit_probe_dependency':{'source':'https://vault.centos.org/6.10/os/i386/Packages/libusb-0.1.12-23.el6.i686.rpm','sha256':'78f979ffbddaa611686e11e0d5309e046962c756cfbf94e8eeb4e9b60b2ee309','installed_globally':False,'required_for_successful_64bit_SVF_path':False}}
(dest/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
assert hashlib.sha256((root/'original_apps_full.bin').read_bytes()).hexdigest()=='7ec0b170de54be4b6b99c8df3fce0f8a713a18230de54478ed0e315f88de660f'
assert hashlib.sha256((root/'original_apps_full.mcs').read_bytes()).hexdigest()=='17ba24929d9cc51c57ea6595a3bb28d42a7d1601cdb626cac0dba45974ee538b'
latest=json.loads((root/'latest_result.json').read_text())
latest.update(updated_utc=summary['recorded_utc'],status='D202_flash_program_verified_and_reloaded',flash_program_verified=True,verify_failed_address=None,initial_failed_program_elapsed_seconds=268,program_elapsed_seconds=summary['total_chunk_elapsed_seconds'],active_fpga_design='D202 loaded from APPS SPI Flash via JPROGRAM',flash_boot_integrity='D202_image_verified_and_software_reload_successful',d202_sram_restored=False,flash_reload_successful=True,physical_power_cycle_tested=False,all_impact_operations_stopped=True,recovery_blocker=None,recovery_program_failure=None,next_tool_candidate=None,recovery_run=s.FOLDER.name,postwrite_read_blank=False,postwrite_read_scope='D202 image 1569584 bytes plus 208 bytes FF padding',postwrite_read_bytes=summary['verified_flash_bytes_including_padding'],postwrite_read_bin_sha256=hashlib.sha256((s.FOLDER/'d202_verified_flash_prefix.bin').read_bytes()).hexdigest(),postwrite_read_non_ff_bytes=sum(b!=255 for b in (s.FOLDER/'d202_verified_flash_prefix.bin').read_bytes()),flash_status_register='0x00',usb_status_execution='failed',usb_status_error='D4100 USB device unavailable')
latest['blank_full_read_elapsed_seconds']=latest.pop('postwrite_read_elapsed_seconds',947)
latest['current_readback_elapsed_separately_measured']=False
latest['initial_flash_status_query_reload_timed_out']=latest.pop('flash_status_query_reload_timed_out',True)
(root/'latest_result.json').write_text(json.dumps(latest,indent=2)+'\n')
manifest={f.relative_to(root).as_posix():hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(root.rglob('*')) if f.is_file() and f!=root/'sha256.json'}
(root/'sha256.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(summary,indent=2))
