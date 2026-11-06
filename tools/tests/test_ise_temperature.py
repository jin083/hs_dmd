"""Offline telemetry/protocol tests; never connect to a VM or JTAG cable."""
from contextlib import redirect_stdout
import csv
import io
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

TOOLS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS))
import ise_temperature as thermal


def reply(temp="9800", core="5540", aux="D540"):
    return f"vendor message\nDMD_SYSMON\t0\txc5vlx50\t62896093\tOK\t{temp}\t{core}\t{aux}\t\nDMD_SYSMON_DONE\n"


class TemperatureTests(unittest.TestCase):
    def test_virtex5_conversion_uses_upper_ten_bits(self):
        row = thermal.parse_readings(reply())[0]
        self.assertEqual(row["status"], "READ")
        self.assertEqual(row["temperature_c"], "26.09")
        self.assertEqual(row["vccint_v"], "0.999")
        self.assertEqual(row["vccaux_v"], "2.499")
        self.assertEqual(thermal.parse_readings(reply("983F"))[0]["temperature_c"], "26.09")

    def test_invalid_sensor_data_never_becomes_a_temperature(self):
        for values in (("0000", "0000", "0000"), ("FFFF", "5540", "D540"), ("9800", "0000", "D540")):
            row = thermal.parse_readings(reply(*values))[0]
            self.assertEqual(row["status"], "INVALID")
            self.assertEqual(row["temperature_c"], "")
            self.assertEqual(row["raw_temperature"], values[0])
        # High readings are displayed, never clamped into a supposedly safe range.
        self.assertGreater(float(thermal.parse_readings(reply("E000"))[0]["temperature_c"]), 160)

    def test_incomplete_malformed_and_duplicate_results_rejected(self):
        for data in (reply().replace("DMD_SYSMON_DONE", ""), reply("10000"), reply("xyz"),
                     reply() + reply(), "DMD_SYSMON_DONE\n"):
            with self.assertRaises(RuntimeError):
                thermal.parse_readings(data)

    def test_one_chip_error_preserves_the_other_reading(self):
        data = reply() + "DMD_SYSMON\t1\txc5vlx30\t6286E093\tERROR\t\t\t\tread failed\n"
        rows = thermal.parse_readings(data)
        self.assertEqual([row["status"] for row in rows], ["READ", "ERROR"])
        self.assertEqual(rows[1]["temperature_c"], "")

    def test_check_never_attaches_cable_and_does_not_claim_sensor_success(self):
        with tempfile.TemporaryDirectory() as directory:
            run = Path(directory) / "run"
            with patch.object(thermal, "check_vm", return_value={}), \
                    patch.object(thermal, "guest_path", return_value="/test"), \
                    patch.object(thermal, "acquire", return_value="DMD_SYSMON_READY\n"), \
                    patch.object(thermal.ise, "attach_cable") as attach, redirect_stdout(io.StringIO()) as output:
                self.assertEqual(thermal.main(["--check", "--output", str(run)]), 0)
            attach.assert_not_called()
            self.assertIn("sensor availability is not yet verified", output.getvalue())
            self.assertFalse((run / "temperature.csv").exists())

    def test_unavailable_vm_prevents_any_acquisition(self):
        with patch.object(thermal, "check_vm", side_effect=RuntimeError("VM locked")), \
                patch.object(thermal, "acquire") as read, \
                patch.object(thermal.ise, "attach_cable") as attach, redirect_stdout(io.StringIO()):
            self.assertEqual(thermal.main(["--once"]), 1)
        read.assert_not_called()
        attach.assert_not_called()

    def test_once_csv_records_missing_chip_and_returns_incomplete_status(self):
        with tempfile.TemporaryDirectory() as directory:
            run = Path(directory) / "run"
            with patch.object(thermal, "check_vm", return_value={}), \
                    patch.object(thermal, "guest_path", return_value="/test"), \
                    patch.object(thermal, "acquire", return_value=reply()), \
                    patch.object(thermal.ise, "attach_cable"), redirect_stdout(io.StringIO()):
                self.assertEqual(thermal.main(["--once", "--output", str(run)]), 2)
            with (run / "temperature.csv").open(newline="", encoding="utf-8") as stream:
                rows = list(csv.DictReader(stream))
            self.assertEqual([row["status"] for row in rows], ["READ", "MISSING"])
            self.assertEqual(rows[1]["device"], "xc5vlx30")
            self.assertEqual(rows[1]["temperature_c"], "")


JTAG_STUB = r'''
namespace eval ::chipscope {
    variable CSEJTAG_TARGET_PLATFORMUSB usb
    variable CSEJTAG_LOCKED_ME 1
    variable CSEJTAG_SCAN_DEFAULT default
    proc csejtag_session {action args} {
        if {$action eq "create"} { return testhandle }
        if {$action eq "destroy"} { puts CLEAN_DESTROY; return }
        error "unexpected session operation"
    }
    proc csejtag_target {action args} {
        switch -- $action {
            open { return }
            lock { if {$::env(TEST_MODE) eq "busy"} { return 2 }; return 1 }
            unlock { puts CLEAN_UNLOCK }
            close { puts CLEAN_CLOSE }
            default { error "unexpected target operation" }
        }
    }
    proc csejtag_tap {action args} {
        switch -- $action {
            autodetect_chain { return }
            get_device_count { return 2 }
            get_device_idcode { return [lindex $args 1] }
            default { error "unexpected TAP operation" }
        }
    }
    proc csejtag_db {action handle idcode} {
        # Deliberately reverse the historical iMPACT order.
        if {$idcode == 0} { return xc5vlx30 }
        return xc5vlx50
    }
}
'''
FPGA_STUB = r'''
namespace eval ::chipscope {
    proc csefpga_is_sys_mon_supported {handle idcode} { return 1 }
    proc csefpga_get_sys_mon_reg {handle index address} {
        if {$::env(TEST_MODE) eq "partial" && $index == 0} { error "sensor unavailable" }
        switch -- $address {
            00 { return 9800 }
            01 { return 5540 }
            02 { return D540 }
            default { error "unexpected register read" }
        }
    }
}
'''


@unittest.skipUnless(shutil.which("tclsh"), "Local Tcl is required for offline script execution")
class TclProtocolTests(unittest.TestCase):
    def run_tcl(self, mode, argument="USB21"):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            (folder / "csejtag.tcl").write_text(JTAG_STUB, encoding="utf-8")
            (folder / "csefpga.tcl").write_text(FPGA_STUB, encoding="utf-8")
            env = dict(os.environ, XIL_CSE_TCL=str(folder), TEST_MODE=mode)
            return subprocess.run([shutil.which("tclsh"), str(thermal.TCL), argument],
                                  env=env, capture_output=True, text=True, timeout=5)

    def test_reordered_devices_identified_and_lock_released(self):
        result = self.run_tcl("normal")
        self.assertEqual(result.returncode, 0, result.stderr)
        rows = thermal.parse_readings(result.stdout)
        self.assertEqual([row["device"] for row in rows], ["xc5vlx30", "xc5vlx50"])
        self.assertIn("CLEAN_UNLOCK", result.stdout)
        self.assertIn("CLEAN_CLOSE", result.stdout)
        self.assertIn("CLEAN_DESTROY", result.stdout)

    def test_busy_cable_does_not_force_unlock(self):
        result = self.run_tcl("busy")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("busy", result.stderr)
        self.assertNotIn("CLEAN_UNLOCK", result.stdout)
        self.assertIn("CLEAN_DESTROY", result.stdout)

    def test_sensor_failure_still_releases_lock_and_returns_other_chip(self):
        result = self.run_tcl("partial")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([row["status"] for row in thermal.parse_readings(result.stdout)], ["ERROR", "READ"])
        self.assertIn("CLEAN_UNLOCK", result.stdout)

    def test_library_check_never_creates_session(self):
        result = self.run_tcl("normal", "--check")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "DMD_SYSMON_READY")


if __name__ == "__main__":
    unittest.main()
