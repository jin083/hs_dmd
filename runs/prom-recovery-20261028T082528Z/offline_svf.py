import run_step as s
for label,option in [('default',''),('width1',' -dataWidth 1')]:
    (s.FOLDER/('offline_'+label+'.cmd')).write_text('setMode -bs\naddDevice -p 1 -part xc5vlx50\naddDevice -p 2 -part xc5vlx30\nsetCable -p svf -file '+label+'.svf\nattachFlash -p 1 -spi S25FL032P\nassignFileToAttachedFlash -p 1 -file ../d202_spi_boot.mcs\nProgram -p 1 -spionly -e -v'+option+'\nquit\n')
s.guest('offline_svf', '''mkdir -p offline_svf
cd offline_svf
impact -batch ../offline_default.cmd > ../offline_svf_default.log 2>&1
impact -batch ../offline_width1.cmd > ../offline_svf_width1.log 2>&1
tail -n 22 ../offline_svf_default.log
tail -n 22 ../offline_svf_width1.log
ls -lh *.svf
''',timeout=100)
