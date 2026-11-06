help -m adddevice
help -m settargetdevice
help -m info
setMode -bs
addDevice -p 1 -part xc5vlx50
attachFlash -p 1 -spi S25FL032P
saveCdf -file candidate_flash.cdf
quit
