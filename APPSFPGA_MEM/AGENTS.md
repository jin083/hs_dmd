# APPSFPGA_MEM — FPGA Design (ISE Project)

## OVERVIEW
Xilinx ISE project for Virtex-5 LX50 (xc5vlx50-1ff676). Modified TI Discovery 4100 reference design with DDR2 memory controller.

## STRUCTURE
```
APPSFPGA_MEM/
├── src/rtl/              # VHDL/Verilog source (42 files) — SEE src/rtl/AGENTS.md
├── src/sim/              # Testbenches: appsfpga_tb.v, trigger_dmd_control_tb.v, mem_io_tb.v, ddr2_model.v
├── src (copy)/           # ⚠️ STALE BACKUP — identical to src/ except appscore.vhd line 102
├── ipcore_dir/           # Xilinx IP: MIG (DDR2), FIFOs (read_fifo, mem_read_enable_fifo, fifo), ChipScope (VIO, ILA)
├── appsfpga.xst          # XST synthesis script
├── appsfpga_vhdl.prj     # Source file list for synthesis
├── appsfpga.bit          # Current bitstream
├── appsfpga_*.bit        # Variant bitstreams (22kHz, 10kHz, trigger)
└── APPSFPGA_MEM.xise     # ISE project file
```

## BUILD

```bash
# Synthesis
xst -ifn appsfpga.xst -ofn appsfpga.syr
# Map + PAR
ngdbuild -p xc5vlx50-1ff676 appsfpga.ngc
map -p xc5vlx50-1ff676 appsfpga.ngd
par appsfpga_map.ncd appsfpga.ncd
# Bitstream
bitgen appsfpga.ncd appsfpga.bit
```

## IP CORES (ipcore_dir/)

| IP Core | Type | Purpose |
|---------|------|---------|
| `mig_top/` | MIG DDR2 | DDR2 SODIMM controller (150MHz, 64-bit) |
| `fifo/` | FIFO Generator | USB data FIFO (16→128 bit) |
| `read_fifo/` | FIFO Generator | Memory read data FIFO (128-bit, dual-clock) |
| `mem_read_enable_fifo/` | FIFO Generator | Read enable CDC FIFO (1-bit) |
| `VIO/` | ChipScope VIO | Virtual IO for debug |
| `sysmon_wiz_v2_1/` | System Monitor | FPGA temperature/voltage monitoring |

## CONVENTIONS
- Project file: `.xise` (ISE Navigator), `.prj` (source list), `.xst` (synthesis settings)
- When adding new VHDL files: update BOTH `appsfpga_vhdl.prj` and `appscore_vhdl.prj`
- Bitstream naming: `appsfpga_{variant}.bit` (e.g., 22kHz, trigger)
- Simulation: Verilog testbenches (`.v`) in `src/sim/`, use ISim

## ANTI-PATTERNS
- NEVER edit IP core files directly — use CoreGen to regenerate
- NEVER reference `src (copy)/` — it is stale
- When synthesis fails on timing, check PLL settings in PLL_400.vhd and PLL_mem_150.vhd first
