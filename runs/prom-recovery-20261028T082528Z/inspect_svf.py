from pathlib import Path
from collections import Counter
p=Path(__file__).resolve().parent/'offline_svf/default.svf'
counts=Counter()
first=[]
with p.open() as stream:
    for n,line in enumerate(stream,1):
        if line.startswith('//'):
            counts[line.strip()]+=1
            if len(first)<10 and ('page' in line.lower() or 'write' in line.lower()): first.append((n,line.strip()))
print(counts.most_common(22))
print(first)
