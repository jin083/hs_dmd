"""Bounded ISE guest commands for this recorded programming attempt."""
import os
import shlex
import sys
from pathlib import Path

FOLDER = Path(__file__).resolve().parent
ROOT = FOLDER.parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import ise_program as p

GUEST = '/home/ise/C_DRIVE/' + FOLDER.as_posix()[3:]

def guest(name, body, timeout=45):
    script = ('#!/bin/bash\nsource /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1\n'
              + 'cd ' + shlex.quote(GUEST) + '\n' + body + '\n')
    (FOLDER / (name + '.sh')).write_bytes(script.encode('utf-8'))
    try:
        output = p.vbox('guestcontrol', p.VM, 'run', '--exe', '/usr/bin/timeout',
                        '--username', 'ise', '--password', os.environ.get('ISE_VM_PASSWORD', 'xilinx'),
                        '--timeout', str((timeout + 10) * 1000), '--wait-stdout', '--wait-stderr',
                        '--', str(timeout) + 's', '/bin/bash', GUEST + '/' + name + '.sh',
                        timeout=timeout + 15)
        if output:
            print(output)
        return True
    except RuntimeError as exc:
        print(str(exc))
        (FOLDER / (name + '.guest_error.txt')).write_text(str(exc), encoding='utf-8')
        return False

def impact(name, commands, timeout=45):
    (FOLDER / (name + '.cmd')).write_bytes((commands.rstrip() + '\n').encode('ascii'))
    ok = guest(name, 'impact -batch ' + name + '.cmd > ' + name + '.log 2>&1\n'
               'rc=$?\necho $rc > ' + name + '.exitcode\nexit $rc', timeout)
    log = FOLDER / (name + '.log')
    if log.exists():
        print(log.read_text(errors='replace'))
    return ok
