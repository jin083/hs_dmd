import run_step as s
s.guest('offline_summary', '''scratch=$(cat offline_svf_guest_dir.txt)
tail -n 12 "$scratch/width1_64.log"
tail -n 12 "$scratch/width1_32.log"
ls -lh "$scratch/"*.svf
''',timeout=15)
