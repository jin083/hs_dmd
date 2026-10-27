"""Render a saved validation evidence JSON as standalone PNG and SVG figures.

Uses Matplotlib only for reports; firmware build/control does not depend on it.
python tools/reports/plot_validation.py artifacts/<release>/validation_plot_data.json
"""
import argparse
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('evidence', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    data = json.loads(args.evidence.read_text(encoding='utf-8'))
    if data.get('format') != 'dmd-validation-plots-v1':
        parser.error('Unsupported evidence format')
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt

    output = args.output or args.evidence.parent / 'plots'
    output.mkdir(parents=True, exist_ok=True)
    plt.rcParams.update({'font.size': 10, 'axes.spines.top': False,
                         'axes.spines.right': False, 'figure.facecolor': '#f7f9fc',
                         'axes.facecolor': '#ffffff', 'svg.fonttype': 'none'})

    def save(fig, name):
        for extension in ('png', 'svg'):
            fig.savefig(output / (name + '.' + extension), dpi=170, bbox_inches='tight')
        plt.close(fig)

    attempts = data['implementation_attempts']
    labels = [row['label'] for row in attempts]
    colors = ['#16846b' if row['timing_errors'] == 0 else '#cf644a' for row in attempts]
    fig, axes = plt.subplots(2, 1, figsize=(12, 7.5), layout='constrained', sharex=True)
    bars = axes[0].bar(labels, [row['timing_errors'] for row in attempts], color=colors)
    axes[0].bar_label(bars, padding=4)
    axes[0].set(title='ISE timing violations', ylabel='Reported timing errors')
    axes[0].margins(y=0.15)
    values = [row['system_setup_slack_ns'] for row in attempts]
    axes[1].plot(labels, values, marker='o', linewidth=2, color='#31688e')
    axes[1].axhline(0, color='#16846b', linestyle='--', label='Timing boundary')
    for i, value in enumerate(values):
        axes[1].annotate(f'{value:+.3f}', (i, value), xytext=(0, 9),
                         textcoords='offset points', ha='center')
    axes[1].set(title='200 MHz system-clock setup slack', ylabel='Slack (ns)')
    axes[1].margins(y=0.25)
    for ax in axes:
        ax.tick_params(axis='x', rotation=25)
        ax.grid(axis='y', alpha=0.18)
        ax.set_axisbelow(True)
    fig.suptitle('D202 implementation iterations | ISE reports, not board measurements', fontsize=13)
    save(fig, 'implementation')

    fig, axes = plt.subplots(1, 2, figsize=(12, 4.7), layout='constrained')
    suites = data['test_suites']
    bars = axes[0].barh([s['label'] for s in suites], [s['passed'] for s in suites], color='#31688e')
    axes[0].bar_label(bars, padding=4)
    axes[0].set(title='Passing test cases / RTL benches', xlabel='Count (different test scopes)')
    axes[0].margins(x=0.15)
    periods = data['simulated_mcp_intervals_us']
    axes[1].plot(range(1, len(periods)+1), periods, marker='o', color='#31688e')
    axes[1].axhline(20, color='#cf644a', linestyle='--', label='20 us minimum request')
    axes[1].axhline(100, color='#16846b', linestyle=':', label='100 us request in fixture')
    axes[1].set(title='SIMULATION: MCP-command intervals', xlabel='Logged interval sample', ylabel='Interval (us)')
    axes[1].legend(fontsize=8, loc='lower right')
    axes[1].grid(alpha=0.18)
    fig.suptitle('Automated checks | optical, electrical DDR2 and temperature validation pending', fontsize=12)
    save(fig, 'tests_and_simulation')

    fig, ax = plt.subplots(figsize=(8, 4.5), layout='constrained')
    resources = data['resources']
    metrics = [('slice_registers', 'Slice registers'), ('slice_luts', 'Slice LUTs'),
               ('occupied_slices', 'Occupied slices'), ('blockram_fifo', 'BlockRAM/FIFO')]
    for i, row in enumerate(resources):
        positions = [x + (i-(len(resources)-1)/2)*0.35 for x in range(len(metrics))]
        values = [row[key]['used']/row[key]['available']*100 for key, _ in metrics]
        bars = ax.bar(positions, values, width=0.33, label=row['label'], color=['#8496ac','#31688e'][i % 2])
        ax.bar_label(bars, labels=[f'{v:.1f}%' for v in values], padding=3)
    ax.set_xticks(range(len(metrics)), [label for _, label in metrics])
    ax.set(ylabel='Device resource utilization (%)', title='Mapped resource use | resource counts do not predict temperature')
    ax.set_ylim(0, 100); ax.legend(); ax.grid(axis='y', alpha=0.18); ax.set_axisbelow(True)
    save(fig, 'resources')
    print(output.resolve())


if __name__ == '__main__':
    main()
