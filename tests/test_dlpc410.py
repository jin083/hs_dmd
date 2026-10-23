import hashlib
import math
from pathlib import Path
import struct
import tempfile
import unittest

from dlpc410 import DLPC410, MockTransport, PatternLibrary, PlaybackPlan, read_bmp, write_bmp


class BmpTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / "corners.bmp"
        self.frame = bytearray(98304)
        self.frame[0] = 0x80  # top-left
        self.frame[127] = 1  # top-right
        self.frame[-128] = 0x40  # second pixel of last row
        write_bmp(self.path, self.frame)

    def test_bottom_up_bmp_is_decoded_without_headers(self):
        self.assertEqual(len(self.path.read_bytes()), 98304 + 62)
        self.assertEqual(read_bmp(self.path), bytes(self.frame))

    def test_top_down_and_inverted_palette(self):
        data = bytearray(self.path.read_bytes())
        struct.pack_into("<i", data, 22, -768)
        data[54:62] = b"\xff\xff\xff\0\0\0\0\0"
        data[62:] = bytes(x ^ 255 for x in self.frame)
        self.path.write_bytes(data)
        self.assertEqual(read_bmp(self.path), bytes(self.frame))

    def test_flip_and_invert(self):
        expected = bytearray(98304)
        expected[-128] = 0x80
        expected[-1] = 1
        expected[127] = 2
        self.assertEqual(read_bmp(self.path, flip_x=True, flip_y=True), bytes(expected))
        self.assertEqual(read_bmp(self.path, invert=True), bytes(x ^ 255 for x in self.frame))

    def test_truecolor_24_and_32(self):
        for bits in (24, 32):
            with self.subTest(bits=bits):
                stride = 1024 * bits // 8
                pixels = bytearray(stride * 768)
                # Top-down red at (0,0) is below threshold 128; green at (1,0) is above.
                pixels[2] = 255
                pixels[bits//8+1] = 255
                header = struct.pack("<2sIHHI", b"BM", 54+len(pixels), 0, 0, 54)
                dib = struct.pack("<IiiHHIIiiII", 40, 1024, -768, 1, bits, 0, len(pixels), 0, 0, 0, 0)
                self.path.write_bytes(header+dib+pixels)
                result = read_bmp(self.path)
                self.assertEqual(result[0], 0x40)
                self.assertEqual(sum(result[1:]), 0)

    def test_reject_truncation_compression_and_wrong_dimensions(self):
        original = self.path.read_bytes()
        variants = [original[:-1]]
        for offset, value in ((18, 512), (30, 1), (10, 10)):
            data = bytearray(original)
            struct.pack_into("<I", data, offset, value)
            variants.append(data)
        for data in variants:
            self.path.write_bytes(data)
            with self.assertRaises(ValueError):
                read_bmp(self.path)


class ControlTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        folder = Path(self.temp.name)
        paths = tuple(folder / f"{i}.bin" for i in range(5))
        for i, path in enumerate(paths):
            path.write_bytes(bytes([i]) * 98304)
        self.library = PatternLibrary(folder / "library.json", paths,
                                      tuple(hashlib.sha256(p.read_bytes()).hexdigest() for p in paths))
        self.transport = MockTransport()
        self.dmd = DLPC410(self.library, self.transport)

    def test_upload_show_finite_external_and_infinite(self):
        self.dmd.upload()
        self.assertEqual(self.dmd.status()["UploadedPatterns"], 5)
        result = self.dmd.show(4)
        self.assertTrue(result["Done"])
        self.dmd.play(PlaybackPlan((4,1,3,0,2), (20,), 2), trigger=True)
        self.assertEqual(self.dmd.wait_done()["CompletedLoops"], 2)
        self.assertEqual(self.transport.calls[-2]["action"], "Arm")
        self.dmd.play(PlaybackPlan.at_rate((1,2), 10, 0))
        self.assertTrue(self.dmd.status()["Running"])
        self.dmd.stop()
        self.assertFalse(self.dmd.status()["Running"])

    def test_bad_plans_do_not_touch_device(self):
        bad = [PlaybackPlan((5,)), PlaybackPlan((-1,)), PlaybackPlan((True,)),
               PlaybackPlan((0,), (19,)), PlaybackPlan((0,), (math.nan,)),
               PlaybackPlan((0,1), (20,30,40)), PlaybackPlan((0,), (20,), -1),
               PlaybackPlan((), (20,)), PlaybackPlan((0,), (math.inf,))]
        for plan in bad:
            with self.subTest(plan=plan), self.assertRaises(ValueError):
                self.dmd.configure(plan)
        self.assertEqual(self.transport.calls, [])

    def test_corrupted_pattern_does_not_touch_device(self):
        self.library.patterns[0].write_bytes(b"wrong")
        with self.assertRaisesRegex(ValueError, "size/hash"):
            self.dmd.upload()
        self.assertEqual(self.transport.calls, [])

    def test_failed_start_requests_stop(self):
        class FailedStart(MockTransport):
            def invoke(self, action, plan=None):
                if action == "Start":
                    raise RuntimeError("USB start failed")
                return super().invoke(action, plan)
        transport = FailedStart()
        dmd = DLPC410(self.library, transport)
        dmd.upload()
        with self.assertRaisesRegex(RuntimeError, "USB start failed"):
            dmd.play(PlaybackPlan((0,)))
        self.assertEqual(transport.calls[-1]["action"], "Stop")

    def test_infinite_wait_times_out_and_user_can_stop(self):
        self.dmd.upload()
        self.dmd.play(PlaybackPlan((0,), (20,), 0))
        with self.assertRaises(TimeoutError):
            self.dmd.wait_done(0.01)
        self.dmd.stop()
        self.assertFalse(self.dmd.status()["Running"])


if __name__ == "__main__":
    unittest.main()
