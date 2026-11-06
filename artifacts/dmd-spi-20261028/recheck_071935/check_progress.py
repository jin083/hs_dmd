"""Compare complete records already written by iMPACT; never modifies hardware."""
import hashlib
import json
from pathlib import Path

FOLDER = Path(__file__).resolve().parent
ROOT = FOLDER.parents[1]
original = (ROOT / 'artifacts/dmd-spi-20261028/original_apps_full.bin').read_bytes()
assert hashlib.sha256(original).hexdigest() == '7ec0b170de54be4b6b99c8df3fce0f8a713a18230de54478ed0e315f88de660f'
lines = (FOLDER / 'reread.mcs').read_bytes().splitlines()
base = 0
count = 0
eof = False
differences = []
for index, line in enumerate(lines):
    try:
        if not line.startswith(b':'):
            raise ValueError('Invalid Intel HEX marker')
        record = bytes.fromhex(line[1:].decode('ascii'))
        if len(record) < 5 or len(record) != record[0] + 5 or sum(record) % 256:
            raise ValueError('Invalid Intel HEX record/checksum')
    except (ValueError, UnicodeError):
        if index == len(lines) - 1:
            break  # Writer may still be completing its final record.
        raise
    if eof:
        raise ValueError('Data after EOF')
    address = int.from_bytes(record[1:3], 'big')
    kind, data = record[3], record[4:-1]
    if kind == 4:
        assert address == 0 and len(data) == 2
        base = int.from_bytes(data, 'big') << 16
    elif kind == 0:
        start = base + address
        assert start == count and start + len(data) <= len(original)
        expected = original[start:start + len(data)]
        if expected != data:
            differences.extend(hex(start + i) for i, (a, b) in enumerate(zip(expected, data)) if a != b)
        count += len(data)
    elif kind == 1:
        assert address == 0 and len(data) == 0
        eof = True
    else:
        raise ValueError('Unexpected Intel HEX type')
result = {
    'compared_bytes': count,
    'percent': round(count / len(original) * 100, 1),
    'complete': eof and count == len(original),
    'different_bytes': len(differences),
    'first_differing_addresses': differences[:16],
}
(FOLDER / 'comparison_progress.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result))
