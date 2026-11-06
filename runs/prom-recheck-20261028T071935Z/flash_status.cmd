setMode -bs
addDevice -p 1 -part xc5vlx50
addDevice -p 2 -part xc5vlx30
setCable -p usb21 -baud 1500000
attachFlash -p 1 -spi S25FL032P
ReadStatusRegister -p 1 -flash -spionly
quit
