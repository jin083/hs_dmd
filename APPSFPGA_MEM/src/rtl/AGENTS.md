# APPSFPGA_MEM/src/rtl/ — Core FPGA Source

## OVERVIEW
42 VHDL/Verilog source files. Mix of TI reference code (~30 unchanged) and custom additions (9 new, 2 modified).

## MODULE HIERARCHY

```
appsfpga_e/appsfpga_load4_a  (top-level entity/architecture)
├── appsfpga_io_e/appsfpga_io_400_a  (IO ring: LVDS, OSERDES, PLLs)
│   ├── PLL_400                       (400MHz DMD clock)
│   ├── PLL_200                       (200MHz system clock)
│   ├── PLL_320                       (320MHz — unused variant)
│   ├── ddr_lvds_io_ea               (LVDS output drivers)
│   └── ddr_se_io_ea                 (single-ended IO)
└── appscore                          (application core — MAIN INTEGRATION POINT)
    ├── USB_IO              [CUSTOM]  (USB interface + FIFO routing)
    │   ├── PLL_mem_150     [CUSTOM]  (150MHz memory clock)
    │   ├── FIFO_RCV2                 (16→128 bit async FIFO)
    │   └── fifo_register             (register CDC FIFO)
    ├── MEM_IO              [CUSTOM]  (DDR2 memory controller)
    │   ├── mig_top                   (Xilinx MIG IP)
    │   ├── read_fifo                 (memory read FIFO AB)
    │   ├── read_fifo                 (memory read FIFO CD)
    │   └── mem_read_enable_fifo      (read enable CDC)
    ├── control_registers   [CUSTOM]  (register interface)
    ├── DMD_trigger_control [CUSTOM]  (trigger FSM + data sequencing)
    ├── DMD_control                   (DMD row/block/data output formatting)
    ├── D4100_registers               (TI register definitions)
    ├── write_counter       [CUSTOM]  (row position counter)
    ├── pgen (pattern gen)            (TI pattern generators)
    │   ├── pgen_pgg_a               (Global: 768 rows)
    │   ├── pgen_pgq_a               (Quad: 192 rows)
    │   ├── pgen_pgd_a               (Dual: 96 rows)
    │   └── pgen_pgs_a               (Single: 48 rows)
    └── cnts_a_1and0clks             (line counter/spacing)
```

## FILE CATEGORIES

### CUSTOM (Core Value — OK to modify)
| File | Lines | Purpose |
|------|-------|---------|
| `appscore.vhd` | 1050 | Top-level integration — instantiates ALL modules |
| `USB_IO.vhd` | 527 | USB data/register decode, dual-path routing to DMD+DDR2 |
| `MEM_IO.vhd` | 503 | DDR2 controller: S0(idle), S1(write), S2(read) state machine |
| `DMD_trigger_control.vhdl` | 419 | Trigger FSM, pattern switching, row sequencing |
| `control_registers.vhd` | 351 | Register read/write, GPIO, memory control signals |
| `DDR2_2GB_150MHZ_pkg.vhd` | — | DDR2 configuration constants |
| `write_counter.vhd` | 90 | Row position counter by DMD type |
| `PLL_mem_150.vhd` | — | 150MHz memory clock PLL |
| `MEM_IO_Verilog.v` | 620 | Verilog version of MEM_IO (VHDL is canonical) |

### TI REFERENCE (Do NOT modify)
Pattern generators: `pgen_*.vhd` (10 files), IO: `appsfpga_io_*.vhd`, `ddr_*_io_ea.vhd`, PLLs: `PLL_200/320/400.vhd`, Counters: `cnts_*.vhd`, `counter_4096.vhd`, FIFOs: `FIFO_RCV2.vhd`, `fifo_register.vhd`, Types: `appsfpga_dmd_types_pkg.vhd`, Top: `appsfpga_e.vhd`, `appsfpga_load4_a.vhd`, Registers: `D4100_registers.vhd`, DMD: `DMD_control.vhd`, USB clock: `usb_dcm.vhd`

## REGISTER MAP (Current: 0x00-0x28)

| Addr | Name | Key Bits |
|------|------|----------|
| 0x00 | VERSION | Read-only: 0xAC02 |
| 0x03 | CONTROL | [0]=dmd_write_block, [1]=global_reset, [4]=fifo_reset |
| 0x10 | DMD_TYPE | [3:0] 0001=XGA |
| 0x16 | DMD_CONTROL | [3]=WDT, [5]=ext_reset, [7]=LOAD4 |
| 0x24 | PATTERN_CTRL | [0]=tpg_en, [1]=switch_en |
| 0x26 | PATTERN_SEL | [2:0] pattern number |
| 0x27 | NUM_PATTERNS | [14:0] pattern count |
| 0x28 | UPDATE_MODE | [2:0] 000=Global,010=Single,011=Dual,100=Quad,101=Phased |

Planned new registers: 0x29-0x34 (see work plan).

## CONVENTIONS
- Signal naming: `snake_case`, `_q` = registered output, `_a` = architecture
- Process naming: unnamed or `p_descriptive_name`
- Port map: positional in TI code, named in custom code
- Reset: active-high `reset`, active-low `arstz` (for IO ring)
- Clock: `clk_g` = system, `ifclk` = USB, `mem_clk0` = memory

## ANTI-PATTERNS
- FIFO_RCV2.vhd is 15,946 lines (auto-generated) — NEVER manually edit
- `appsfpga_load4_a.vhd` is the TOP-LEVEL ARCHITECTURE — changes here affect everything
- When adding modules to `appscore.vhd`: declare signals, instantiate component, map ports — follow existing pattern
- DMD data is byte-swapped in USB_IO: `dmd_single_data <= gpif_from_port(7:0) & gpif_from_port(15:8)`
