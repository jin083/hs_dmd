# DMD FPGA Register Map

## Overview
Registers are accessed via the USB interface using 8-bit addresses. Data width is 16 bits.

---

## Core Registers (0x00 - 0x26)

| Address | Name | R/W | Reset | Description |
|---------|------|-----|-------|-------------|
| 0x00 | DISCOVERY_VERSION | RO | 0xAC02 | TI Discovery hardware version |
| 0x01 | APPSFPGA_VERSION | RO | - | FPGA code version (Build, Speed, Space info) |
| 0x02 | ECHO | R/W | 0xEECC | Scratchpad register for communication testing |
| 0x03 | CONTROL_1 | R/W | 0x0000 | [0]: write_block, [1]: global_rst, [2]: blk_rst, [3]: active_mem, [4]: fifo_rst |
| 0x10 | DMD_TYPE | RO | - | Detected DMD type (0=XGA, 1=1080p, etc.) |
| 0x11 | DDC_VERSION | RO | - | DLPC410 DDC version |
| 0x14 | DMD_ROW_MD | R/W | 0x00 | Row address mode (0=Noop, 1=Inc, 2=Set, 3=SetPnt) |
| 0x15 | DMD_ROW_AD | R/W | 0x000 | Row address value (0-1079) |
| 0x16 | CONTROL_2 | R/W | 0x0018 | [0]: step_vcc, [1]: comp_data, [2]: ns_flip, [3]: wdt_en, [4]: float, [5]: ext_rst, [6]: rst2blkz, [7]: load4_en, [8]: load2_en |
| 0x17 | DMD_BLK_MD | R/W | 0x00 | Block mode (0=Noop, 1=Clear, 2=Reset) |
| 0x18 | DMD_BLK_AD | R/W | 0x0 | Block address (0-15) |
| 0x19 | GPIO | R/W | 0x00 | [2:0]: out, [5:3]: in (RO), [7]: ext_reset_flag (RO) |
| 0x20 | DMD_ROW_LOADS | R/W | 0x0000 | Number of rows to load per pattern |
| 0x21 | RESET_COMPLETE | RO | 0x0000 | [0]: Reset complete flag |
| 0x22 | GPIO_RESET_DONE | WO | - | Write 1 to pulse GPIO reset complete signal |
| 0x24 | TPG_SELECT | R/W | 0x0003 | [0]: tpg_en, [1]: sw_en, [2]: pat_force |
| 0x25 | SW_OVERRIDE | R/W | 0x00 | Software override value for pattern generation |
| 0x26 | PATTERN_SEL | R/W | 0x00 | Current pattern index for TPG |

---

## Memory Control Registers (0x29 - 0x32)

| Address | Name | R/W | Reset | Description |
|---------|------|-----|-------|-------------|
| 0x29 | USB_PAT_SWITCH | R/W | 0x0000 | [15:1]: next_pattern_id, [0]: usb_switch_trigger (PULSE auto-clear) |
| 0x30 | NUM_PATTERNS | R/W | 0x0000 | Total number of patterns stored in DDR2 (14:0) |
| 0x31 | MEM_FIFO_RESET | WO | 0x0000 | [0]: mem_rd_fifo_reset (PULSE), [1]: mem_wr_fifo_reset (PULSE) |
| 0x32 | MEM_EN | R/W | 0x0000 | [0]: mem_en — enable DDR2 memory access |

> **Note:** Addresses 0x30-0x32 are **already in use** for memory control. They are NOT available for new feature registers.

---

## New Feature Registers (0x2A - 0x37)

### Pattern Sequencer (0x2A - 0x2E)

| Address | Name | R/W | Reset | Description |
|---------|------|-----|-------|-------------|
| 0x2A | SEQ_CONTROL | R/W | 0x0000 | [0]: seq_enable (persistent), [1]: one_shot (persistent), [2]: reset_index (PULSE auto-clear) |
| 0x2B | SEQ_LENGTH | R/W | 0x0000 | [13:0]: sequence_length — number of entries in sequence (0–2542) |
| 0x2C | SEQ_WRITE_ADDR | R/W | 0x0000 | [13:0]: seq_wr_addr — write address into sequence table |
| 0x2D | SEQ_WRITE_DATA | R/W | 0x0000 | [14:0]: seq_wr_data — pattern ID to store; write to this reg also pulses seq_wr_en |
| 0x2E | SEQ_STATUS | RO | - | [15]: seq_running, [14]: reserved, [13:0]: current_index |

### Timing Control (0x2F, 0x35 - 0x37)

| Address | Name | R/W | Reset | Description |
|---------|------|-----|-------|-------------|
| 0x2F | TIMING_CONTROL | R/W | 0x0000 | [0]: timing_enable, [1]: auto_trigger |
| 0x35 | TIMING_WRITE_ADDR | R/W | 0x0000 | [13:0]: timing_wr_addr — address into timing table |
| 0x36 | TIMING_DATA_LO | R/W | 0x0000 | timing_wr_lo[15:0] — lower 16 bits of 32-bit cycle count |
| 0x37 | TIMING_DATA_HI | R/W | 0x0000 | timing_wr_hi[15:0] — upper 16 bits; write to this reg also pulses timing_wr_en |

### Trigger Mux (0x33 - 0x34)

| Address | Name | R/W | Reset | Description |
|---------|------|-----|-------|-------------|
| 0x33 | TRIGGER_CONTROL | R/W | 0x0000 | [1:0]: trigger_source_sel (00=TTL, 01=USB, 10=Timer, 11=Any), [2]: trigger_enable, [3]: reset_counter (PULSE auto-clear) |
| 0x34 | TRIGGER_STATUS | RO | - | [15:0]: trigger_count — total triggers since reset (saturating at 0xFFFF) |

---

## Key Register Details

### Register 0x16: CONTROL_2
- **Bit 8 (LOAD2_EN)**: Active high. When enabled, loads 2 rows with same data, doubling DDR2 storage capacity (~5000+ patterns). Does NOT increase load speed.
- **Bit 7 (LOAD4_EN)**: Active high. When enabled, loads 4 rows with same data simultaneously — 4x faster load but 1/4 vertical resolution.
- **Bit 3 (WDT_EN)**: Watchdog timer enable. 0 = Enabled, 1 = Disabled (Reset default is 1).

### Register 0x2A: SEQ_CONTROL — Pulse vs Persistent Bits
- Bits [1:0] (`one_shot`, `seq_enable`) are **persistent** — they hold their written value until overwritten.
- Bit [2] (`reset_index`) is a **PULSE** — it auto-clears one cycle after being set. This resets the pattern sequencer's current_index to 0.

### Register 0x2D: SEQ_WRITE_DATA — Implicit Write Enable
Writing to this register simultaneously stores the pattern ID in `seq_wr_data` AND pulses `seq_wr_en` for one cycle. The host must:
1. Write 0x2C (seq_wr_addr) with the target address
2. Write 0x2D (seq_wr_data) with the pattern ID → seq_wr_en auto-pulses

### Registers 0x35-0x37: Timing Table Write Protocol
The 32-bit timing value is written as two 16-bit halves. The host must:
1. Write 0x35 (timing_wr_addr) with the target address
2. Write 0x36 (timing_wr_lo) with bits [15:0] of the cycle count
3. Write 0x37 (timing_wr_hi) with bits [31:16] → timing_wr_en auto-pulses
   - Timing table entry = {timing_wr_hi, timing_wr_lo} (32-bit cycle count at 200 MHz)

### Register 0x33: TRIGGER_CONTROL — Source Selection
| trigger_source_sel | Active Source |
|-------------------|---------------|
| "00" (0) | TTL external only |
| "01" (1) | USB command only |
| "10" (2) | Timer (timing_controller) only |
| "11" (3) | Any source (priority: TTL > USB > Timer) |

### Timing Constraints
- **Minimum Timer Value**: 4000 cycles = 20 µs at 200 MHz.
- This enforces the 50 kHz maximum rate limit of the DLPA200 driver.
- Values below 4000 cycles are clamped to 4000 by the timing_controller.

---

## Address Map Summary (all allocated addresses)

| Range | Usage |
|-------|-------|
| 0x00-0x03 | System / USB control |
| 0x10-0x11 | DMD type / DDC version (RO) |
| 0x14-0x1A | DMD row/block control |
| 0x20-0x22 | DMD row loads / reset complete |
| 0x24-0x26 | TPG / pattern select |
| 0x29 | USB pattern switch |
| 0x2A-0x2E | **Pattern sequencer** (NEW) |
| 0x2F | **Timing control enable** (NEW) |
| 0x30-0x32 | Memory control (num_patterns, fifo_reset, mem_en) |
| 0x33-0x34 | **Trigger mux control/status** (NEW) |
| 0x35-0x37 | **Timing table write** (NEW) |
