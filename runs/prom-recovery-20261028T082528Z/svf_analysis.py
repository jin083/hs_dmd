import run_step as s
s.guest('svf_analysis', '''scratch=$(cat offline_svf_guest_dir.txt)
python - "$scratch" <<'PY'
import hashlib,json,os,sys,itertools
folder=sys.argv[1]
paths=[('default64','offline_svf/default.svf'),('width1_64',folder+'/width1_64.svf'),('width1_32',folder+'/width1_32.svf')]
results={}
for name,path in paths:
    digest=hashlib.sha256(); commands=0; page=0
    with open(path,'rb') as stream:
        for line in stream:
            if 'page program' in line: page+=1
            if line.startswith('//'): continue
            digest.update(line); commands+=1
    results[name]={'noncomment_lines':commands,'command_sha256':digest.hexdigest(),'page_program_commands':page}
print(json.dumps(results,indent=2))
with open('offline_svf_comparison.json','w') as stream: json.dump(results,stream,indent=2)
PY
cp "$scratch/width1_64.log" offline_svf_width1_64.log
cp "$scratch/width1_32.log" offline_svf_width1_32.log
''',timeout=40)
