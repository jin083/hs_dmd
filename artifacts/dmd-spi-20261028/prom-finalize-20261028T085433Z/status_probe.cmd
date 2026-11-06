setMode -bs
addDevice -p 1 -file status_probe.svf
setCable -p usb21 -baud 1500000
play -cont_on_fail -showalltdo
quit
