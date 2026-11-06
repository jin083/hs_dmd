import re
import run_step as s
source=(s.FOLDER/'page_status_probe.svf').read_text()
write_disable='SIR 10 TDI (3c2);\nRUNTEST 10 TCK;\nSDR 80 TDI (0000002010006a956a95);\nRUNTEST 144 TCK;\n'
source=source.replace('SDR 32 TDI (00000000) SMASK (FFFFFFFF) TDO (02896093) MASK (0FFFFFFF);','SDR 32 TDI (00000000) SMASK (FFFFFFFF) TDO (02896093) MASK (0FFFFFFF);\n'+write_disable)
m=re.search(r'SDR 2160 TDI \((.*?)\)',source,re.S)
original=int(m.group(1).replace('\n',''),16)
# Preserve every transmitted payload/header bit, extend only trailing dummy zero clocks.
replacement=f'SDR 8560 TDI ({original:02140x})'
source=source[:m.start()]+replacement+source[m.end():]
source=source.replace('RUNTEST 2224 TCK;','RUNTEST 8624 TCK;')
assert int(re.search(r'SDR 8560 TDI \((.*?)\)',source,re.S).group(1),16)==original
(s.FOLDER/'padded_page_probe.svf').write_bytes(source.encode())
s.impact('padded_page_probe','setMode -bs\naddDevice -p 1 -file padded_page_probe.svf\nsetCable -p usb21 -baud 1500000\nplay -cont_on_fail -showalltdo\nquit',timeout=60)
