"""Extract plot data from archived ISE and test logs (standard library only)."""
import argparse
import csv
import hashlib
import json
import os
from pathlib import Path
import re


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('release', type=Path)
    parser.add_argument('--baseline', type=Path, required=True)
    args = parser.parse_args()
    root = args.release.resolve()
    sources = {}

    def read(path):
        raw = path.read_bytes()
        # Relative paths preserve provenance when the repository is moved.
        sources[Path(os.path.relpath(path, root)).as_posix()] = hashlib.sha256(raw).hexdigest()
        return raw.decode('utf-8', errors='replace')

    def timing(twr, par, label):
        trace, route = read(twr), read(par)
        summary = re.search(r'Timing errors:\s*(\d+)\s+Score:\s*(\d+)', trace)
        if summary:
            errors, score = map(int, summary.groups())
        elif 'All constraints were met' in trace:
            errors, score = 0, 0
        else:
            raise ValueError(f'No complete timing verdict in {twr}')
        slack = re.search(r'TS_i_appsfpga_io_i_PLL_clk_CLKOUT0_BUF_0\s*\|\s*SETUP\s*\|\s*([-\d.]+)ns', route)
        if not slack:
            raise ValueError(f'No system-clock setup slack in {par}')
        return {'label': label, 'timing_errors': errors, 'timing_score': score,
                'system_setup_slack_ns': float(slack[1])}

    history = root / 'reports/history'
    attempts = [timing(p, p.with_suffix('.par'), p.stem.replace('build', '').replace('-retry', ' retry'))
                for p in sorted(history.glob('*.twr'), key=lambda p: p.stem)]
    attempts.append(timing(root/'reports/appsfpga.twr', root/'reports/appsfpga.par', 'Final'))

    def resources(path, label):
        text = read(path)
        result = {'label': label}
        for key, title in [('slice_registers','Slice Registers'), ('slice_luts','Slice LUTs'),
                           ('occupied_slices','occupied Slices'), ('blockram_fifo','BlockRAM/FIFO')]:
            match = re.search(r'Number of '+re.escape(title)+r':\s*([\d,]+) out of\s*([\d,]+)', text)
            if not match:
                raise ValueError(f'No {title} count in {path}')
            result[key] = dict(zip(('used','available'), (int(v.replace(',','')) for v in match.groups())))
        return result

    suites = []
    for name, label in [('dlpc410-tests.log','API (wheel)'), ('DMD-FPGA-Test-tests.log','Test CLI (wheel)'),
                        ('ise-program-tests.log','JTAG parser (offline)')]:
        text = read(root/'tests'/name)
        match = re.search(r'Ran (\d+) tests? in', text)
        if not match or not re.search(r'^OK\s*$', text, re.M):
            raise ValueError(f'No passing unittest verdict in {name}')
        suites.append({'label': label, 'passed': int(match[1])})
    samples = []
    for name in ('memory_playback_tb','usb_memory_tb','pattern_store_tb'):
        text = read(root/'tests'/name/'simulation.log')
        if f'PASS: {name}' not in text or 'FAIL:' in text:
            raise ValueError(f'RTL test did not pass: {name}')
        if name == 'memory_playback_tb':
            samples = [int(ns)/1000 for ns in re.findall(r'MCP interval: \d+ cycles \((\d+) ns\)', text)]
    suites.append({'label': 'RTL / FIFO benches', 'passed': 3})
    data = {'format': 'dmd-validation-plots-v1', 'hardware_measured': False,
            'implementation_attempts': attempts, 'test_suites': suites,
            'simulated_mcp_intervals_us': samples,
            'resources': [resources(args.baseline.resolve()/'reports/appsfpga_map.mrp','D201 Oct26'),
                          resources(root/'reports/appsfpga_map.mrp','D202')],
            'source_sha256': sources}
    (root/'validation_plot_data.json').write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
    with (root/'timing_iterations.csv').open('w',newline='',encoding='utf-8') as stream:
        writer=csv.DictWriter(stream,fieldnames=list(attempts[0]));writer.writeheader();writer.writerows(attempts)
    with (root/'simulated_mcp_intervals.csv').open('w',newline='',encoding='utf-8') as stream:
        writer=csv.writer(stream);writer.writerow(['sample','simulated_interval_us'])
        writer.writerows(enumerate(samples,1))
    print(root/'validation_plot_data.json')


if __name__ == '__main__':
    main()
