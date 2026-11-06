import re,json
import run_step as s
base=(s.FOLDER/'id_clean.svf').read_text().splitlines()
lines=(s.ROOT/'runs/prom-recovery-20261028T082528Z/offline_svf/default.svf').read_text().splitlines()
body='\n'.join(lines[515585:515639]).replace('SIR 10 TDI (03c2)','SIR 10 TDI (3c2)').replace('SIR 10 TDI (03c3)','SIR 10 TDI (3c3)')
(s.FOLDER/'confirm_page.svf').write_bytes(('\n'.join(base[:11])+'\n'+body+'\n'+'\n'.join(base[11:])+'\n').encode())
s.impact('confirm_page','setMode -bs\naddDevice -p 1 -file confirm_page.svf\nsetCable -p usb21 -baud 1500000\nplay -showalltdo\nquit',timeout=60)
log=(s.FOLDER/'confirm_page.log').read_text()
assert 'Play svf succeeded.' in log and 'ERROR:' not in log and 'Failed ScanDR' not in log
captures=re.findall(r'ScanDR\s+TDO\(([0-9a-fA-F\s]+)\)',log)
actual=max((int(''.join(x.split()),16) for x in captures),key=lambda x:x.bit_length())
mask=int(re.search(r'\bMASK \((.*?)\)',body,re.S).group(1).replace('\n',''),16)
shift=(mask&-mask).bit_length()-1
raw=((actual&mask)>>shift).to_bytes(256,'little')
decoded=bytes(int(f'{b:08b}'[::-1],2) for b in raw)
expected=(s.ROOT/'artifacts/dmd-20261027-d202/appsfpga_repaired.bin').read_bytes()[:256]
assert decoded==expected
(s.FOLDER/'confirmed_first_page.bin').write_bytes(decoded)
print('INDEPENDENT READ: all 256 bytes match D202')
