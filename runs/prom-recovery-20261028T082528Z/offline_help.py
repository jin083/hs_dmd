import run_step as s
(s.FOLDER/'offline_help.cmd').write_text('help -m attachflash\nhelp -m assignfiletoattachedflash\nhelp -m program\nhelp -m setcable\nquit\n')
s.guest('offline_help', '''mkdir -p offline_help
cd offline_help
impact -batch ../offline_help.cmd > ../offline_help.log 2>&1
cat ../offline_help.log''',timeout=30)
