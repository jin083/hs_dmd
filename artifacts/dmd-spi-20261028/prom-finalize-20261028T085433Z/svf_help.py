import run_step as s
(s.FOLDER/'svf_help.cmd').write_text('help -c play\nhelp -m play\nhelp -m adddevice\nhelp -m setmode\nquit\n')
s.guest('svf_help','mkdir -p offline_help\ncd offline_help\nimpact -batch ../svf_help.cmd > ../svf_help.log 2>&1\ncat ../svf_help.log',timeout=20)
