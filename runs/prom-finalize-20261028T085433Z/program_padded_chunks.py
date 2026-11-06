"""Program only validated D202 bytes through ISE-generated SVF with padded JTAG scans."""
import hashlib,json,re,time
from datetime import datetime,timezone
import run_step as s
rev=lambda x,n:int(f'{x:0{n}b}'[::-1],2)
lines=(s.ROOT/'runs/prom-recovery-20261028T082528Z/offline_svf/default.svf').read_text().splitlines()
image=(s.ROOT/'artifacts/dmd-20261027-d202/appsfpga_repaired.bin').read_bytes()
assert hashlib.sha256(image).hexdigest()=='ea90d7e62c49b016e2c9f755ebebb6b1d42174383be13dc0cf8c05cbf8f6999c'
padded=image+b'\xff'*((-len(image))%256)
base=(s.FOLDER/'id_clean.svf').read_text().splitlines()
head='\n'.join(base[:11])+'\n'
footer='\n'.join(base[11:])+'\n'
def status(value=0):
 return f'SIR 10 TDI (3c2);\nRUNTEST 10 TCK;\nSDR 80 TDI (000000a008006a956a95);\nRUNTEST 144 TCK;\nSDR 80 TDI (00000000000000a00800) SMASK (ffffffffffffffffffff) TDO ({value << 24:020x}) MASK (000000000000ff000000);\n'
jedec='SIR 10 TDI (3c2);\nRUNTEST 10 TCK;\nSDR 80 TDI (000000f904006a956a95);\nRUNTEST 144 TCK;\nSDR 80 TDI (00000000000000f90400) SMASK (ffffffffffffffffffff) TDO (00000000a84080000000) MASK (00000000ffffff000000);\n'
wrdi='SIR 10 TDI (3c2);\nRUNTEST 10 TCK;\nSDR 80 TDI (0000002010006a956a95);\nRUNTEST 144 TCK;\n'
clean=lambda t:t.replace('SIR 10 TDI (03c2)','SIR 10 TDI (3c2)').replace('SIR 10 TDI (03c3)','SIR 10 TDI (3c3)')
marker="//Loading device with 'write enable' instruction."
blocks=('\n'.join(lines[392945:515585])).split(marker)[1:]
assert len(blocks)==len(padded)//256==6132
programs=[]
for index,block in enumerate(blocks):
 m=re.search(r'SDR 2160 TDI \((.*?)\)',block,re.S)
 value=int(''.join(m.group(1).split()),16)
 raw=value.to_bytes(270,'little')
 assert raw[:4]==bytes.fromhex('956a956a') and rev(int.from_bytes(raw[4:6],'little'),16)==2080
 assert rev(raw[6],8)==2
 address=int.from_bytes(bytes(rev(b,8) for b in raw[7:10]),'big')
 assert address==index*256
 assert bytes(rev(b,8) for b in raw[10:266])==padded[address:address+256]
 assert raw[266:]==b'\0'*4
 modified=block[:m.start()]+f'SDR 8560 TDI ({value:02140x})'+block[m.end():]
 modified=modified.replace('RUNTEST 2224 TCK;','RUNTEST 8624 TCK;').replace('RUNTEST 6000 TCK;','RUNTEST 15000 TCK;')
 programs.append(clean(modified)+'\n'+status())
readbody='\n'.join(lines[515585:816058])
readmarker="//Loading device with 'read ' instruction."
read_parts=readbody.split(readmarker)
read_setup=clean(read_parts[0])+'\n'
reads=read_parts[1:]
assert len(reads)==len(programs)
for index,block in enumerate(reads):
 scans=re.findall(r'SDR 8560 TDI \((.*?)\)(.*?);',block,re.S)
 assert len(scans)==2
 raw=int(''.join(scans[0][0].split()),16).to_bytes(1070,'little')
 assert raw[:4]==bytes.fromhex('956a956a') and rev(int.from_bytes(raw[4:6],'little'),16)==2080
 assert rev(raw[6],8)==3
 assert int.from_bytes(bytes(rev(b,8) for b in raw[7:10]),'big')==index*256
 tail=scans[1][1]
 mask=int(''.join(re.search(r'\bMASK \((.*?)\)',tail,re.S).group(1).split()),16)
 expected=int(''.join(re.search(r'TDO \((.*?)\)',tail,re.S).group(1).split()),16)
 assert mask==((1<<2048)-1)<<48
 assert bytes(rev(b,8) for b in ((expected&mask)>>48).to_bytes(256,'little'))==padded[index*256:(index+1)*256]
reads=list(map(clean,reads))
plan={'time_utc':datetime.now(timezone.utc).isoformat(),'image_sha256':hashlib.sha256(image).hexdigest(),'image_bytes':len(image),'pages':len(programs),'write_sdr_bits_original':2160,'write_sdr_bits_padded':8560,'payload_and_address_unchanged':True,'erases':0,'first_page_independent_read_verified':True,'chunk_pages':512,'verify_abort_on_first_mismatch':True}
(s.FOLDER/'padded_program_plan.json').write_text(json.dumps(plan,indent=2)+'\n')
print('Validated all 6132 page addresses, payloads and independent verify masks.',flush=True)
all_data=bytearray()
for start in range(0,len(programs),512):
 end=min(start+512,len(programs));name=f'chunk_{start:04d}_{end:04d}'
 # The first page was already programmed and independently verified.
 body=head+jedec+wrdi+status()+''.join(programs[max(start,1):end])+wrdi+read_setup+'\n'.join(reads[start:end])+'\n'+footer
 (s.FOLDER/(name+'.svf')).write_bytes(body.encode())
 (s.FOLDER/(name+'.cmd')).write_bytes(('setMode -bs\naddDevice -p 1 -file '+name+'.svf\nsetCable -p usb21 -baud 1500000\nplay -showalltdo\nquit\n').encode())
 print(f'Writing/verifying pages {start}..{end-1}',flush=True)
 begin=time.monotonic()
 ok=s.guest(name,'impact -batch '+name+'.cmd > '+name+'.log 2>&1\nrc=$?\necho $rc > '+name+'.exitcode\nexit $rc',timeout=600)
 log=(s.FOLDER/(name+'.log')).read_text(errors='replace')
 assert ok and 'Play svf succeeded.' in log and 'ERROR:' not in log and 'Failed ScanDR' not in log,name+' failed; stopped before next chunk'
 captures=re.findall(r'ScanDR\s+TDO\(([0-9a-fA-F\s]+)\)',log)
 captures=[''.join(x.split()) for x in captures]
 captures=[x for x in captures if len(x)==2140]
 assert len(captures)==end-start,(name,len(captures))
 data=b''.join(bytes(rev(b,8) for b in ((int(x,16)>>48)&((1<<2048)-1)).to_bytes(256,'little')) for x in captures)
 assert data==padded[start*256:end*256],name+' independent decode mismatch'
 (s.FOLDER/(name+'.bin')).write_bytes(data)
 all_data.extend(data)
 result={'time_utc':datetime.now(timezone.utc).isoformat(),'start_address':start*256,'end_address_exclusive':end*256,'verified_bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),'elapsed_seconds':round(time.monotonic()-begin,3)}
 (s.FOLDER/(name+'.json')).write_text(json.dumps(result,indent=2)+'\n')
 print('VERIFIED '+json.dumps(result),flush=True)
assert bytes(all_data)==padded
(s.FOLDER/'d202_verified_flash_prefix.bin').write_bytes(all_data)
result={**plan,'completed_utc':datetime.now(timezone.utc).isoformat(),'flash_program_verified':True,'verified_bytes_including_ff_padding':len(all_data),'verified_image_sha256':hashlib.sha256(all_data[:len(image)]).hexdigest(),'cold_boot_verified':False,'active_fpga_design':'ISE temporary SPI access core'}
(s.FOLDER/'padded_program_result.json').write_text(json.dumps(result,indent=2)+'\n')
print('FULL D202 FLASH PROGRAM AND BYTE COMPARISON PASSED',flush=True)
