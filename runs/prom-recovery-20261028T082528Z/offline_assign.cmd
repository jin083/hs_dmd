setMode -bs
addDevice -p 1 -part xc5vlx50
addDevice -p 2 -part xc5vlx30
attachFlash -p 1 -spi S25FL032P
assignFileToAttachedFlash -p 1 -file ../d202_spi_boot.mcs
saveCdf -file ../offline_assigned.cdf
quit
