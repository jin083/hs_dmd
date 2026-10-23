"""Uncompressed BMP -> 98,304-byte DLP7000 rows, with no imaging dependencies."""

from dataclasses import dataclass
import hashlib
import json
from pathlib import Path
import struct

WIDTH, HEIGHT = 1024, 768
FRAME_BYTES = WIDTH * HEIGHT // 8


def digest(data):
    return hashlib.sha256(data).hexdigest()


def read_bmp(path, *, threshold=128, invert=False, flip_x=False, flip_y=False):
    """Return top-to-bottom rows, left-to-right pixels, MSB first; white is 1.

    Accepts Windows BI_RGB 1/24/32-bit BMP at exactly 1024x768. Palette polarity,
    signed BMP height and row padding are decoded. No BMP header reaches the FPGA.
    Optical orientation/polarity still requires a physical commissioning check.
    """
    if type(threshold) is not int or not 1 <= threshold <= 255:
        raise ValueError("threshold must be an integer in 1..255")
    data = Path(path).read_bytes()
    if len(data) < 54 or data[:2] != b"BM":
        raise ValueError("Expected a Windows BMP file")
    offset, dib_size = struct.unpack_from("<II", data, 10)
    if dib_size < 40 or 14 + dib_size > len(data):
        raise ValueError("Unsupported or truncated BMP header")
    width, height, planes, bits, compression = struct.unpack_from("<iiHHI", data, 18)
    if (width, abs(height), planes) != (WIDTH, HEIGHT, 1):
        raise ValueError("BMP must be exactly 1024x768 with one plane")
    if bits not in (1, 24, 32) or compression != 0:
        raise ValueError("Only uncompressed 1-, 24-, and 32-bit BMP is supported")
    palette_start = 14 + dib_size
    if offset < palette_start + (8 if bits == 1 else 0):
        raise ValueError("BMP pixel offset overlaps its header/palette")
    stride = ((width * bits + 31) // 32) * 4
    if offset + stride * abs(height) > len(data):
        raise ValueError("Truncated BMP pixel data")

    def bright(b, g, r):
        return (299 * r + 587 * g + 114 * b) >= threshold * 1000

    palette = [bright(*data[palette_start+i*4:palette_start+i*4+3]) for i in range(2)] if bits == 1 else []
    result = bytearray(FRAME_BYTES)
    for y in range(HEIGHT):
        source_y = HEIGHT - 1 - y if flip_y else y
        row = source_y if height < 0 else HEIGHT - 1 - source_y
        start = offset + row * stride
        for x in range(WIDTH):
            source_x = WIDTH - 1 - x if flip_x else x
            if bits == 1:
                white = palette[(data[start + source_x // 8] >> (7-source_x % 8)) & 1]
            else:
                p = start + source_x * (bits // 8)
                white = bright(*data[p:p+3])  # Ignore BMP alpha, never premultiply.
            if white != invert:
                result[y * 128 + x // 8] |= 1 << (7-x % 8)
    return bytes(result)


def write_bmp(path, packed):
    """Write a normal bottom-up 1-bit BMP from canonical packed rows."""
    if len(packed) != FRAME_BYTES:
        raise ValueError("Expected 98,304 packed pixel bytes")
    header = struct.pack("<2sIHHI", b"BM", 62 + FRAME_BYTES, 0, 0, 62)
    dib = struct.pack("<IiiHHIIiiII", 40, WIDTH, HEIGHT, 1, 1, 0, FRAME_BYTES, 2835, 2835, 2, 2)
    pixels = b"".join(packed[y*128:(y+1)*128] for y in reversed(range(HEIGHT)))
    with Path(path).open("xb") as stream:
        stream.write(header + dib + b"\0\0\0\0\xff\xff\xff\0" + pixels)


@dataclass(frozen=True)
class PatternLibrary:
    manifest: Path
    patterns: tuple[Path, ...]
    sha256: tuple[str, ...]

    @classmethod
    def create(cls, bmp_files, output, **conversion):
        sources = [Path(p).resolve() for p in bmp_files]
        if not 1 <= len(sources) <= 2543:
            raise ValueError("Expected 1..2543 BMP files")
        # Validate every source before writing a partial library or touching any device.
        frames = [read_bmp(p, **conversion) for p in sources]
        output = Path(output).resolve()
        output.mkdir(parents=True, exist_ok=False)
        records = []
        for index, (source, frame) in enumerate(zip(sources, frames)):
            filename = f"pattern_{index:04d}.bin"
            (output / filename).write_bytes(frame)
            records.append({"id": index, "source_bmp_name": source.name,
                            "source_sha256": digest(source.read_bytes()), "file": filename,
                            "sha256": digest(frame)})
        manifest = output / "library.json"
        manifest.write_text(json.dumps({"format": "dlp7000-packed-msb-top-v1",
                            "conversion": conversion, "patterns": records}, indent=2)+"\n", encoding="utf-8")
        return cls.load(manifest)

    @classmethod
    def load(cls, manifest):
        manifest = Path(manifest).resolve()
        info = json.loads(manifest.read_text(encoding="utf-8"))
        if info.get("format") != "dlp7000-packed-msb-top-v1":
            raise ValueError("Unsupported library format")
        records = info["patterns"]
        if not 1 <= len(records) <= 2543 or [p["id"] for p in records] != list(range(len(records))):
            raise ValueError("Pattern IDs must be contiguous from zero")
        library = cls(manifest, tuple((manifest.parent / p["file"]).resolve() for p in records),
                      tuple(p["sha256"] for p in records))
        library.validate()
        return library

    def validate(self):
        if not 1 <= len(self.patterns) <= 2543 or len(self.sha256) != len(self.patterns):
            raise ValueError("Invalid pattern library")
        for path, expected in zip(self.patterns, self.sha256):
            data = path.read_bytes()
            if len(data) != FRAME_BYTES or digest(data) != expected:
                raise ValueError(f"Pattern size/hash mismatch: {path}")
