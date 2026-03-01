# DMD FPGA Register Map

## Overview
Registers are accessed via the USB interface using 8-bit addresses. Data width is 16 bits.

## Register Table (0x00 - 0x28)

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
| 0x16 | CONTROL_2 | R/W | 0x0018 | [0]: step_vcc, [1]: comp_data, [2]: ns_flip, [3]: wdt_en, [4]: float, [5]: ext_rst, [6]: rst2blkz, [7]: load4_en |
| 0x17 | DMD_BLK_MD | R/W | 0x00 | Block mode (0=Noop, 1=Clear, 2=Reset) |
| 0x18 | DMD_BLK_AD | R/W | 0x0 | Block address (0-15) |
| 0x19 | GPIO | R/W | 0x00 | [2:0]: out, [5:3]: in (RO), [7]: ext_reset_flag (RO) |
| 0x20 | DMD_ROW_LOADS | R/W | 0x0000 | Number of rows to load per pattern |
| 0x21 | RESET_COMPLETE | RO | 0x0000 | [0]: Reset complete flag |
| 0x22 | GPIO_RESET_DONE | WO | - | Write 1 to pulse GPIO reset complete signal |
| 0x24 | TPG_SELECT | R/W | 0x0003 | [0]: tpg_en, [1]: sw_en, [2]: pat_force |
| 0x25 | SW_OVERRIDE | R/W | 0x00 | Software override value for pattern generation |
| 0x26 | PATTERN_SEL | R/W | 0x00 | Current pattern index for TPG |
| 0x27 | NUM_PATTERNS | R/W | 0x0000 | Total number of patterns stored in DDR2 |
| 0x28 | UPDATE_MODE | R/W | 0x00 | DMD update mode (0-5) |

## Key Register Details

### Register 0x16: CONTROL_2
- **Bit 7 (LOAD4_EN)**: Active high. When enabled, the system loads 4 rows with the same data simultaneously. This increases loading speed by 4x but reduces vertical resolution to 1/4.
- **Bit 6 (LOAD2_EN)**: *Reserved for future use*. Will enable 2-row loading mode.
- **Bit 3 (WDT_EN)**: Watchdog timer enable. 0 = Enabled, 1 = Disabled (Reset default is 1).

### Register 0x27: NUM_PATTERNS
Defines the upper bound for pattern sequencing. Max value for XGA full-frame is 2542.

---

## New Registers (Reserved 0x29 - 0x34)

| Address | Name | R/W | Description |
|---------|------|-----|-------------|
| 0x29 | USB_PAT_SWITCH | R/W | [15:1]: next_pattern_id, [0]: trigger (auto-clear) |
| 0x2A | SEQ_CONTROL | R/W | [0]: enable, [1]: one_shot, [2]: reset_index |
| 0x2B | SEQ_LENGTH | R/W | Number of patterns in sequence (0-2542) |
| 0x2C | SEQ_WRITE_ADDR | R/W | Address for writing sequence entry |
| 0x2D | SEQ_WRITE_DATA | R/W | Pattern ID at SEQ_WRITE_ADDR |
| 0x2E | SEQ_STATUS | RO | [14:0]: current_index, [15]: running flag |
| 0x2F | TIMING_CONTROL | R/W | [0]: enable, [1]: auto_trigger |
| 0x30 | TIMING_WRITE_ADDR | R/W | Address for timing entry |
| 0x31 | TIMING_DATA_LO | R/W | Timing value lower 16 bits (clock cycles) |
| 0x32 | TIMING_DATA_HI | R/W | Timing value upper 16 bits |
| 0x33 | TRIGGER_CONTROL | R/W | [1:0]: source_sel, [2]: enable, [3]: reset_counter |
| 0x34 | TRIGGER_STATUS | RO | [1:0]: last_source, [15:0]: trigger_count |

### Timing Constraints
- **Minimum Timer Value**: 4000 cycles (20µs at 200MHz).
- This enforces the 50kHz maximum rate limit of the DLPA200 driver.
