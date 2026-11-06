"""Validate Intel HEX records and the address coverage of a Flash image."""
import hashlib
import json
from pathlib import Path

CAPACITY = 4 * 1024 * 1024

def decode(path, *, complete=False):
    image = bytearray(b'\xff') * CAPACITY
    present = bytearray(CAPACITY)
    base = 0
    eof = False
    count = 0
    for number, line in enumerate(Path(path).read_text(encoding='ascii').splitlines(), 1):
        if eof or not line.startswith(':'):
            raise ValueError(f'Unexpected record at line {number}')
        record = bytes.fromhex(line[1:])
        if len(record) < 5 or len(record) != record[0] + 5 or sum(record) % 256:
            raise ValueError(f'Invalid record/checksum at line {number}')
        address = int.from_bytes(record[1:3], 'big')
        kind, data = record[3], record[4:-1]
        if kind == 4 and address == 0 and len(data) == 2:
            base = int.from_bytes(data, 'big') << 16
        elif kind == 0:
            start, end = base + address, base + address + len(data)
            if not 0 <= start < end <= CAPACITY or any(present[start:end]):
                raise ValueError(f'Invalid/overlapping address at line {number}')
            image[start:end] = data
            present[start:end] = b'\x01' * len(data)
            count += len(data)
        elif kind == 1 and address == 0 and not data:
            eof = True
        else:
            raise ValueError(f'Unexpected Intel HEX record type {kind}')
    if not eof or (complete and not all(present)):
        raise ValueError('Missing EOF or incomplete full Flash coverage')
    return bytes(image), present, count

def validate_backup(folder):
    folder = Path(folder)
    source = folder / 'original_apps_full.mcs'
    data, _, count = decode(source, complete=True)
    (folder / 'original_apps_full.bin').write_bytes(data)
    result = {
        'bytes': count,
        'address_start': 0,
        'address_end_inclusive': CAPACITY - 1,
        'mcs_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
        'raw_sha256': hashlib.sha256(data).hexdigest(),
        'full_coverage_and_record_checksums_valid': True,
        'hardware_verify_passed': False,
    }
    (folder / 'backup_validation.json').write_text(json.dumps(result, indent=2) + '\n')
    return result

if __name__ == '__main__':
    print(json.dumps(validate_backup(Path(__file__).parent), indent=2))
