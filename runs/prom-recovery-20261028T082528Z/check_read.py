import hashlib,json
from datetime import datetime,timezone
from pathlib import Path
F=Path(__file__).resolve().parent
R=F.parents[1]
original=(R/'artifacts/dmd-spi-20261028/original_apps_full.bin').read_bytes()
assert hashlib.sha256(original).hexdigest()=='7ec0b170de54be4b6b99c8df3fce0f8a713a18230de54478ed0e315f88de660f'
new=(R/'artifacts/dmd-20261027-d202/appsfpga_repaired.bin').read_bytes()
assert hashlib.sha256(new).hexdigest()=='ea90d7e62c49b016e2c9f755ebebb6b1d42174383be13dc0cf8c05cbf8f6999c'
expected=new+b'\xff'*(len(original)-len(new))
raw=(F/'postwrite_read.mcs').read_bytes()
lines=raw.splitlines(); base=0; out=bytearray(); eof=False
for i,line in enumerate(lines):
    try:
        assert line.startswith(b':')
        r=bytes.fromhex(line[1:].decode('ascii'))
        assert len(r)>=5 and len(r)==r[0]+5 and sum(r)%256==0
    except (AssertionError,ValueError,UnicodeError):
        if i==len(lines)-1 and not raw.endswith(b'\n'): break
        raise
    assert not eof
    addr=int.from_bytes(r[1:3],'big'); kind=r[3]; data=r[4:-1]
    if kind==4:
        assert len(data)==2 and addr==0
        base=int.from_bytes(data,'big')<<16
    elif kind==0:
        assert base+addr==len(out) and len(out)+len(data)<=len(original)
        out.extend(data)
    elif kind==1:
        assert addr==0 and not data
        eof=True
    else: raise ValueError(kind)
n=len(out)
result={'time_utc':datetime.now(timezone.utc).isoformat(),'read_bytes':n,'total_bytes':len(original),'percent':round(n/len(original)*100,1),'complete':eof and n==len(original),'non_ff_bytes':n-out.count(255),'different_from_original_bytes':sum(a!=b for a,b in zip(out,original)),'different_from_d202_bytes':sum(a!=b for a,b in zip(out,expected)),'first64_hex':out[:64].hex(),'last64_hex':out[-64:].hex(),'nonblank_sectors':[hex(a) for a in range(0,n,65536) if out[a:a+65536].count(255)!=len(out[a:a+65536])]}
if result['complete']:
    (F/'postwrite_read.bin').write_bytes(out)
    result['bin_sha256']=hashlib.sha256(out).hexdigest()
(F/'read_progress.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result))
