setMode -bs
addDevice -p 1 -file jedec_probe.svf
setCable -p usb21 -baud 1500000
play -cont_on_fail -showalltdo
quit
