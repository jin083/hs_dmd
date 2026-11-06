import re
import run_step as s
lines=(s.ROOT/'runs/prom-recovery-20261028T082528Z/offline_svf/default.svf').read_text().splitlines()
head=(s.FOLDER/'id_clean.svf').read_text().splitlines()[:11]
footer=(s.FOLDER/'id_clean.svf').read_text().splitlines()[11:]
body='\n'.join(lines[392945:392965]+lines[515585:515639])
body=body.replace('SIR 10 TDI (03c2)','SIR 10 TDI (3c2)').replace('SIR 10 TDI (03c3)','SIR 10 TDI (3c3)')
page=int(re.search(r'SDR 2160 TDI \((.*?)\)',body,re.S).group(1).replace('\n',''),16).to_bytes(270,'little')
reverse=lambda b: int(f'{b:08b}'[::-1],2)
expected=(s.ROOT/'artifacts/dmd-20261027-d202/appsfpga_repaired.bin').read_bytes()[:256]
assert bytes(reverse(b) for b in page[10:266])==expected
mask=int(re.search(r'\bMASK \((.*?)\)',body,re.S).group(1).replace('\n',''),16)
tdo=int(re.search(r'TDO \((.*?)\)',body,re.S).group(1).replace('\n',''),16)
assert mask.bit_count()==2048
shift=(mask & -mask).bit_length()-1
assert mask>>shift==(1<<2048)-1
assert bytes(reverse(b) for b in ((tdo&mask)>>shift).to_bytes(256,'little'))==expected
(s.FOLDER/'probe_vectors_clean.svf').write_bytes(('\n'.join(head)+'\n'+body+'\n'+'\n'.join(footer)+'\n').encode())
s.impact('play_probe','setMode -bs\naddDevice -p 1 -file probe_vectors_clean.svf\nsetCable -p usb21 -baud 1500000\nplay -showalltdo\nquit',timeout=60)
