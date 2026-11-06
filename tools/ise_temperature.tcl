# Read-only Virtex-5 System Monitor acquisition, run with ISE 14.7 xtclsh.
# API: AMD UG029 chapter 5. DRP addresses: UG192 table 3.
# No FPGA configuration, sensor register writes, or forced cable unlocks.

proc cse_constant {name} {
    foreach qualified [list ::$name ::chipscope::$name] {
        if {[uplevel #0 [list info exists $qualified]]} {
            return [uplevel #0 [list set $qualified]]
        }
    }
    error "ISE CSE constant not found: $name"
}

proc emit_row {index device idcode status temp core aux message} {
    set message [string map [list "\t" " " "\r" " " "\n" " "] $message]
    puts [join [list DMD_SYSMON $index $device $idcode $status $temp $core $aux $message] "\t"]
    flush stdout
}

set handle ""
set opened 0
set locked 0
set result [catch {
    if {[info exists env(XIL_CSE_TCL)] && $env(XIL_CSE_TCL) ne ""} {
        set cse_dir $env(XIL_CSE_TCL)
    } elseif {[info exists env(XILINX)]} {
        set cse_dir [file join $env(XILINX) cse tcl]
    } else {
        error "Source ISE_DS/settings64.sh and run this script with xtclsh."
    }
    foreach library {csejtag csefpga} {
        source [file join $cse_dir ${library}.tcl]
    }
    foreach command {csejtag_session csejtag_target csejtag_tap csejtag_db csefpga_is_sys_mon_supported csefpga_get_sys_mon_reg} {
        if {[llength [info commands ::chipscope::$command]] == 0} {
            error "ISE CSE command not found: $command"
        }
    }

    if {[llength $argv] == 1 && [lindex $argv 0] eq "--check"} {
        puts "DMD_SYSMON_READY"
    } else {
        if {[llength $argv] != 1 || ![regexp {^USB[0-9]+$} [lindex $argv 0]]} {
            error "Usage: xtclsh ise_temperature.tcl --check | USB21"
        }
        set port [lindex $argv 0]
        set handle [::chipscope::csejtag_session create 0]
        ::chipscope::csejtag_target open $handle [cse_constant CSEJTAG_TARGET_PLATFORMUSB] 0 \
            "port=$port" "frequency=3000000"
        set opened 1
        set lock_status [::chipscope::csejtag_target lock $handle 2000]
        if {$lock_status != [cse_constant CSEJTAG_LOCKED_ME]} {
            error "JTAG cable is busy. Disconnect iMPACT/Analyzer before monitoring."
        }
        set locked 1
        ::chipscope::csejtag_tap autodetect_chain $handle [cse_constant CSEJTAG_SCAN_DEFAULT]
        set count [::chipscope::csejtag_tap get_device_count $handle]
        set found 0
        for {set index 0} {$index < $count} {incr index} {
            set idcode [::chipscope::csejtag_tap get_device_idcode $handle $index]
            set device [string tolower [::chipscope::csejtag_db get_device_name_for_idcode $handle $idcode]]
            if {$device ne "xc5vlx50" && $device ne "xc5vlx30"} { continue }
            incr found
            set read_error [catch {
                if {![::chipscope::csefpga_is_sys_mon_supported $handle $idcode]} {
                    error "System Monitor is not supported by this device."
                }
                set temp [::chipscope::csefpga_get_sys_mon_reg $handle $index 00]
                set core [::chipscope::csefpga_get_sys_mon_reg $handle $index 01]
                set aux [::chipscope::csefpga_get_sys_mon_reg $handle $index 02]
            } read_message]
            if {$read_error} {
                emit_row $index $device $idcode ERROR "" "" "" $read_message
            } else {
                emit_row $index $device $idcode OK $temp $core $aux ""
            }
        }
        if {$found == 0} { error "No xc5vlx50 or xc5vlx30 found in the JTAG chain." }
        puts "DMD_SYSMON_DONE"
    }
} message]

# Tcl 8.4 has no try/finally; always release only the lock this session owns.
if {$locked} { catch {::chipscope::csejtag_target unlock $handle} }
if {$opened} { catch {::chipscope::csejtag_target close $handle} }
if {$handle ne ""} { catch {::chipscope::csejtag_session destroy $handle} }
if {$result} {
    puts stderr "DMD_SYSMON_ERROR: $message"
    exit 1
}
exit 0
