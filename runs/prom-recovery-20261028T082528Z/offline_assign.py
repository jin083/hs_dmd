import shutil
import run_step as s
for ext in ('mcs','cfi'):
    shutil.copyfile(s.ROOT/('artifacts/dmd-spi-20261028/d202_spi_boot.'+ext),s.FOLDER/('d202_spi_boot.'+ext))
(s.FOLDER/'offline_assign.cmd').write_text('setMode -bs\naddDevice -p 1 -part xc5vlx50\naddDevice -p 2 -part xc5vlx30\nattachFlash -p 1 -spi S25FL032P\nassignFileToAttachedFlash -p 1 -file ../d202_spi_boot.mcs\nsaveCdf -file ../offline_assigned.cdf\nquit\n')
s.guest('offline_assign', '''mkdir -p offline_assign
cd offline_assign
impact -batch ../offline_assign.cmd > ../offline_assign.log 2>&1
cat ../offline_assign.log
cat ../offline_assigned.cdf
source /opt/Xilinx/14.7/ISE_DS/settings32.sh >/dev/null 2>&1
/opt/Xilinx/14.7/ISE_DS/ISE/bin/lin/impact -batch ../offline_help.cmd > ../offline_32bit.log 2>&1
head -n 6 ../offline_32bit.log
''',timeout=30)
