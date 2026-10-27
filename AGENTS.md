# PROJECT KNOWLEDGE BASE

**D202 work (2026-10-27):** `feature/managed-pattern-memory` adds `pattern_store.v`, fixed-slot CRC-verified writes, logical deletion, sequence preflight, end-pattern and snapshot/sync support. Read `docs/D202_MANAGED_MEMORY.md`, `docs/TESTING.md`, and `docs/reports/D202_2026-10-27.md` for the current implementation and verification status. Hardware/optical/thermal validation of D202 is pending. Python API and CLI are the sibling `dlpc410` and `DMD-FPGA-Test` 0.3.0 packages on the same feature branch. The historical D201 notes below are retained; generated IP and TI reference restrictions still apply.

**Generated:** 2026-03-01
**Commit:** 1f91eb4
**Branch:** main

## OVERVIEW

**Current implementation (2026-10-23):** Read `README.md`, `docs/REGISTER_MAP.md`, and `docs/UPDATES_2026-10-23.md` first. Historical paths and plans below may be stale. The active project uses `MEM_IO_Verilog.v`, `ddr_pattern_engine.v`, `memory_playback.v`, and `dmd_frame_streamer.v`; `MEM_IO.vhd` and the older sequencer modules are inactive. The target is **xc5vlx50-1-ff1153**. MIG user clock is `mem_clk2x` (150 MHz); `mem_clk0` is 75 MHz. ABI D201 occupies 0x29–0x3E. Current memory playback supports full XGA Global mode only. Synthesis, timing, simulation and JTAG programming passed; DDR2/optical hardware validation is still pending. Preserve the existing TI reference/IP and DDR2 address layout restrictions below.

FPGA-based DMD (DLP7000) control system for NV center in diamond experiments. Xilinx Virtex-5 LX50 on DLPLCRC410EVM board, DDR2 memory for high-speed pattern storage, Cypress FX2 USB for host communication. Based on Mathews et al. 2022 (ETH Zurich) with custom extensions.

Python host APIs are maintained in the sibling `../dlpc410` repository (`dmd_ctrl.memory`, branch `feature/ddr2-memory-api`), not as a Python package in this firmware repository. `../DMD-FPGA-Test` uses pyproject metadata and the existing Python interpreter without a project virtual environment. `tools/dmd_playback.ps1` remains a standalone firmware diagnostic. Read `docs/CHIPSCOPE_TEMPERATURE.md` for the unmeasured System Monitor workflow.

## STRUCTURE

```
hs_dmd/
├── APPSFPGA_MEM/          # FPGA design (ISE project + RTL + sim + IP cores)
│   ├── src/rtl/           # Core VHDL/Verilog source (42 files) ← PRIMARY CODE
│   ├── src/sim/           # Testbenches + DDR2 model (7 files)
│   ├── src (copy)/        # ⚠️ REDUNDANT BACKUP — delete candidate
│   ├── ipcore_dir/        # Xilinx MIG, FIFOs, ChipScope IP cores
│   └── *.bit              # Pre-built bitstreams (various configs)
├── DMDController/          # Host software (C++ DLL wrapper + Python utils)
│   ├── DMDController/     # C++ project (main.cpp, control.cpp, vendor DLLs)
│   └── PythonUtilities/   # Python scripts (pattern gen, instrument control)
├── example_verilog/        # TI reference design (UNCHANGED) — archive candidate
├── docs/                   # TI datasheets (DLP7000, DLPC410) + Mathews paper
├── raw_results/            # Experimental data (oscilloscope, imaging)
├── git_*.vhdl              # ⚠️ DUPLICATES of src/rtl files — delete candidate
└── .sisyphus/plans/        # Work plan: dmd-fpga-overhaul.md
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Modify DMD data loading | `APPSFPGA_MEM/src/rtl/DMD_trigger_control.vhdl` | Trigger FSM, row sequencing, data output |
| Add new registers | `APPSFPGA_MEM/src/rtl/control_registers.vhd` | Register decode, addr 0x00-0x28 |
| Change top-level wiring | `APPSFPGA_MEM/src/rtl/appscore.vhd` | Instantiates all modules (1050 lines) |
| Modify memory controller | `APPSFPGA_MEM/src/rtl/MEM_IO.vhd` | DDR2 read/write state machine |
| Modify USB interface | `APPSFPGA_MEM/src/rtl/USB_IO.vhd` | USB decode, FIFO routing |
| DMD type definitions | `APPSFPGA_MEM/src/rtl/appsfpga_dmd_types_pkg.vhd` | Row counts, DMD type constants |
| Host-side register map | `DMDController/DMDController/vendor/RegisterDefines.h` | Must match FPGA registers |
| Pattern loading (host) | `DMDController/DMDController/src/control.cpp` | USB data transfer functions |
| Build FPGA | `APPSFPGA_MEM/appsfpga.xst` | XST synthesis settings |
| Simulate | `APPSFPGA_MEM/src/sim/appsfpga_tb.v` | Top-level testbench |

## DATA FLOW

```
PC ─USB(16bit@48MHz)─→ USB_IO ─FIFO(16→128bit)─→ MEM_IO ─→ DDR2(2GB@150MHz)
                                                              ↓ (TTL trigger)
DMD ←─LVDS(4ch@400MHz)── DMD_control ←── DMD_trigger_control ←── MEM_IO
```

## CLOCK DOMAINS

| Clock | Freq | Domain | Modules |
|-------|------|--------|---------|
| `ifclk` | 48 MHz | USB | USB_IO |
| `mem_clk0` | 150 MHz | DDR2 | MEM_IO, MIG |
| `clk_g` / `system_clk` | 200 MHz | System | appscore, registers, trigger_control |
| DDR output | 400 MHz | DMD | appsfpga_io, OSERDES |

CDC via async FIFOs: FIFO_RCV2 (USB→MEM), read_fifo (MEM→SYS), mem_read_enable_fifo (SYS→MEM).

## CONVENTIONS

- VHDL style: snake_case signals, `_q` suffix for registered, `_a` suffix for architecture
- Entity/Arch separation: `*_e.vhd` (entity), `*_a.vhd` (architecture) — TI convention
- Active-low signals: `*z` suffix (e.g., `load4z`, `arstz`)
- Port directions: `_i` input, `_o` output in appsfpga_e.vhd IO pins
- IP cores: Generated by Xilinx CoreGen, stored in `ipcore_dir/` — do NOT manually edit
- Bitstreams: `appsfpga_*.bit` — pre-built for various configurations

## ANTI-PATTERNS (THIS PROJECT)

- NEVER edit files in `ipcore_dir/` — regenerate via CoreGen if changes needed
- NEVER modify the ~30 unchanged TI reference files (pgen_*, cnts_*, ddr_*io*, counter_4096, etc.)
- NEVER modify `MEM_IO.vhd` memory addressing — DDR2 controller is proven stable
- NEVER use `ROW_MD="01"` (auto-increment) for Load2 — must use `ROW_MD="10"` (random)
- NEVER set pattern timing < 20µs (50kHz MCP rate hard limit from DLPA200 driver)
- `src (copy)/` is a stale backup — do NOT reference it for current state
- `git_*.vhdl` at root are stale extractions — canonical source is `src/rtl/`

## UNIQUE STYLES

- Dual VHDL+Verilog: MEM_IO exists in both `.vhd` and `_Verilog.v` — VHDL is canonical
- Phased mode: Custom update_mode=5 added by Mathews team (not in TI reference)
- Register 0x0016 bit 7: Controls LOAD4Z — active low to DLPC410
- Data byte swap: USB data is byte-swapped in USB_IO (`[7:0] & [15:8]`)

## COMMANDS

```bash
# Synthesize (from APPSFPGA_MEM/)
xst -ifn appsfpga.xst -ofn appsfpga.syr
# Simulate (ISE ISim)
fuse -o sim_tb appsfpga_tb -prj appsfpga_tb_beh.prj
./sim_tb -tclbatch isim.cmd
# Program FPGA (via USB DLL from host)
DMDController.exe Init
```

## NOTES

- Hardware: DLPLCRC410EVM + DLP7000 (768x1024) + 2GB DDR2 SODIMM
- TI DLL works with pre-built bitstream; custom FPGA code not yet synthesized
- Load4: 4 rows same data = 4x faster load, 1/4 vertical resolution
- Load2 (planned): 2 rows same data = doubles storage capacity, NOT faster
- Max images in DDR2: ~2543 (XGA full-frame) or ~5000+ with Load2
- Active work plan: `.sisyphus/plans/dmd-fpga-overhaul.md`
