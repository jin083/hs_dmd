setMode -bs
addDevice -p 1 -part xc5vlx50
addDevice -p 2 -part xc5vlx30
setCable -p usb21 -baud 1500000
assignFile -p 1 -file d202_jtag.bit
Program -p 1
ReadStatusRegister -p 1
quit
