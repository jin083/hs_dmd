import run_step as s
s.guest('offline_compare', '''scratch=$(mktemp -d /tmp/dmd_offline_svf.XXXXXX)
cp d202_spi_boot.mcs d202_spi_boot.cfi "$scratch/"
printf '%s' "$scratch" > offline_svf_guest_dir.txt
cd "$scratch"
cat > width1.cmd <<'EOF'
setMode -bs
addDevice -p 1 -part xc5vlx50
addDevice -p 2 -part xc5vlx30
setCable -p svf -file width1.svf
attachFlash -p 1 -spi S25FL032P
assignFileToAttachedFlash -p 1 -file d202_spi_boot.mcs
Program -p 1 -dataWidth 1 -spionly -e -v
quit
EOF
impact -batch width1.cmd > width1_64.log 2>&1
mv width1.svf width1_64.svf
source /opt/Xilinx/14.7/ISE_DS/settings32.sh >/dev/null 2>&1
/opt/Xilinx/14.7/ISE_DS/ISE/bin/lin/impact -batch width1.cmd > width1_32.log 2>&1
mv width1.svf width1_32.svf
tail -n 8 width1_64.log
tail -n 8 width1_32.log
ls -lh *.svf
''',timeout=240)
