"""Offline guard checks. No VM/device calls are made by these tests."""
import importlib.util
from contextlib import redirect_stdout
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("ise_program", ROOT / "tools/ise_program.py")
programmer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(programmer)


class ProgrammerTests(unittest.TestCase):
    def test_real_chain_and_reject_reordered_or_extra_devices(self):
        cdf = (ROOT / "artifacts/dmd-program-20261026/program_chain.cdf").read_text()
        self.assertEqual(programmer.require_lx50_chain(cdf), ["xc5vlx50", "xc5vlx30"])
        for bad in ("PartName(xc5vlx30) PartName(xc5vlx50)", cdf + "PartName(xcf16p)", ""):
            with self.assertRaises(RuntimeError):
                programmer.require_lx50_chain(bad)

    def test_real_program_log_and_reject_failed_final_status(self):
        log = (ROOT / "artifacts/dmd-program-20261026/impact_program.log").read_text()
        self.assertEqual(programmer.verify_program_log(log)["Value of DONE pin"], 1)
        for bad in (log + "\nValue of DONE pin : 0\n", log + "\nCRC error : 1\n",
                    "Programmed successfully"):
            with self.assertRaises(RuntimeError):
                programmer.verify_program_log(bad)

    def test_check_never_invokes_programming(self):
        with patch.object(programmer, "vbox", return_value='VMState="running"\n') as call, \
                patch.object(programmer, "program") as hardware:
            self.assertEqual(programmer.main(["--check"]), 0)
        hardware.assert_not_called()
        call.assert_called_once_with("showvminfo", programmer.VM, "--machinereadable")

    def test_program_requires_running_vm_and_correct_shared_folder(self):
        info = ('VMState="running"\nSharedFolderNameMachineMapping1="C_DRIVE"\n'
                'SharedFolderPathMachineMapping1="c:\\\\"\n')
        with patch.object(programmer, "vbox", return_value=info), \
                patch.object(programmer, "program") as hardware:
            self.assertEqual(programmer.main(["--program"]), 0)
            hardware.assert_called_once()
        for bad in (info.replace('"running"', '"poweroff"'), info.replace('c:', 'd:')):
            with patch.object(programmer, "vbox", return_value=bad), \
                    patch.object(programmer, "program") as hardware:
                self.assertEqual(programmer.main(["--program"]), 1)
            hardware.assert_not_called()

    def test_wrong_chain_stops_before_program_command(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)

            def identify_only(path, name, commands, sha256):
                self.assertEqual(name, "identify")
                self.assertNotIn("Program -p", commands)
                (path / "chain.cdf").write_text("PartName(xc5vlx30) PartName(xc5vlx50)")

            with patch.object(programmer.tempfile, "mkdtemp", return_value=directory), \
                    patch.object(programmer, "attach_cable"), \
                    patch.object(programmer, "run_impact", side_effect=identify_only) as impact:
                with self.assertRaisesRegex(RuntimeError, "Unexpected JTAG chain"):
                    programmer.program({})
            self.assertEqual(impact.call_count, 1)
            self.assertFalse((folder / "program.cmd").exists())

    def test_d4100_usb_is_never_attached(self):
        fx2 = "UUID: 11111111-1111-1111-1111-111111111111\nVendorId: 0x0451\nProductId: 0xaf33\n"
        with patch.object(programmer, "vbox", return_value=fx2) as call:
            with self.assertRaises(RuntimeError):
                programmer.attach_cable({})
        call.assert_called_once_with("list", "usbhost")

    def test_existing_cable_is_not_reattached(self):
        info = {"USBAttachVendorId1": "0x03fd", "USBAttachProductId1": "0x0008"}
        with patch.object(programmer, "vbox") as call:
            programmer.attach_cable(info)
        call.assert_not_called()

    def test_one_xilinx_cable_is_selected(self):
        usb = "UUID: 11111111-1111-1111-1111-111111111111\nVendorId: 0x03fd\nProductId: 0x0008\n"
        with patch.object(programmer, "vbox", return_value=usb) as call:
            programmer.attach_cable({})
        self.assertEqual(call.call_args.args, ("controlvm", programmer.VM, "usbattach",
                                              "11111111-1111-1111-1111-111111111111"))

    def test_timeout_does_not_print_login_password(self):
        with patch.object(programmer.subprocess, "run",
                          side_effect=subprocess.TimeoutExpired(["--password", "private"], 1)):
            with self.assertRaises(RuntimeError) as error:
                programmer.vbox("guestcontrol", "--password", "private")
        self.assertNotIn("private", str(error.exception))

    def test_release_selection_and_reject_cclk_or_wrong_hash(self):
        old = ROOT / "artifacts/dmd-20261023/appsfpga_repaired_jtag.bit"
        path, digest, part = programmer.select_bitstream(old)
        self.assertEqual(path, old)
        self.assertEqual(digest, "d6e4b40456b90445aa84cf1a2360d2cdee895f4bbc3964dd9364387f5a534a39")
        self.assertEqual(part, "5vlx50ff1153")
        with self.assertRaisesRegex(RuntimeError, "non-JTAG"):
            programmer.select_bitstream(old.with_name("appsfpga_repaired.bit"))
        with self.assertRaisesRegex(RuntimeError, "hash mismatch"):
            programmer.select_bitstream(old, "0" * 64)

    def test_external_path_with_spaces_and_wrong_device(self):
        with tempfile.TemporaryDirectory(prefix="dmd chosen bit ") as directory:
            chosen = Path(directory) / "custom image.bit"
            raw = programmer.BIT.read_bytes()
            chosen.write_bytes(raw)
            with self.assertRaisesRegex(RuntimeError, "No valid recorded"):
                programmer.select_bitstream(chosen)
            self.assertEqual(programmer.select_bitstream(chosen, programmer.EXPECTED_SHA256)[0], chosen)
            wrong_device = raw.replace(b"5vlx50ff1153", b"5vlx30ff1153", 1)
            chosen.write_bytes(wrong_device)
            with self.assertRaisesRegex(RuntimeError, "Wrong FPGA target"):
                programmer.select_bitstream(chosen, hashlib.sha256(wrong_device).hexdigest())
            chosen.write_bytes(raw[:50])
            with self.assertRaisesRegex(RuntimeError, "Truncated"):
                programmer.select_bitstream(chosen, hashlib.sha256(raw[:50]).hexdigest())

    def test_check_lists_releases_and_originals_even_if_vm_query_fails(self):
        old = ROOT / "artifacts/dmd-20261023/appsfpga_repaired_jtag.bit"
        rows = programmer.list_bitstreams(old)
        self.assertEqual(rows[0]["path"], old)
        self.assertTrue(rows[0]["selected"])
        self.assertEqual(rows[0]["startup_clock"], "JtagClk")
        by_path = {row["path"]: row for row in rows}
        self.assertEqual(by_path[old.with_name("appsfpga_repaired.bit")]["startup_clock"], "Cclk")
        self.assertEqual(by_path[ROOT / "APPSFPGA_MEM/appsfpga.bit"]["hash_reference"], "missing")
        output = io.StringIO()
        with redirect_stdout(output), patch.object(programmer, "vbox", side_effect=RuntimeError("VM unavailable")), \
                patch.object(programmer, "program") as hardware:
            self.assertEqual(programmer.main(["--check", "--bitstream", str(old)]), 1)
        self.assertIn("artifacts/dmd-20261026/appsfpga_repaired_jtag.bit", output.getvalue())
        self.assertIn("APPSFPGA_MEM/appsfpga.bit", output.getvalue())
        hardware.assert_not_called()

    def test_selected_bytes_and_hash_reach_programming_script(self):
        old, digest, _ = programmer.select_bitstream(ROOT / "artifacts/dmd-20261023/appsfpga_repaired_jtag.bit")
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)

            def fake_impact(path, name, commands, sha256):
                self.assertEqual(sha256, digest)
                self.assertEqual((path / programmer.STAGED_BIT_NAME).read_bytes(), old.read_bytes())
                if name == "identify":
                    (path / "chain.cdf").write_text("PartName(xc5vlx50) PartName(xc5vlx30)")
                else:
                    self.assertIn("assignFile -p 1 -file selected_jtag.bit", commands)
                    (path / "program.log").write_bytes((ROOT / "artifacts/dmd-program-20261026/impact_program.log").read_bytes())

            with patch.object(programmer.tempfile, "mkdtemp", return_value=directory), \
                    patch.object(programmer, "attach_cable"), \
                    patch.object(programmer, "run_impact", side_effect=fake_impact):
                programmer.program({}, old, digest)
            record = json.loads((folder / "result.json").read_text())
            self.assertEqual(record["bitstream"], str(old))
            self.assertEqual(record["bitstream_sha256"], digest)
            self.assertTrue(record["program_verified"])


if __name__ == "__main__":
    unittest.main()
