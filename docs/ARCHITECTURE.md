# DMD FPGA Control System Architecture

## System Overview
This system provides high-speed control for a DLP7000 DMD (Digital Micromirror Device) used in NV center in diamond experiments. It enables precise optical modulation at kHz rates by pre-loading patterns into DDR2 memory and sequencing them via hardware triggers.

The design is based on the Virtex-5 LX50 FPGA on the DLPLCRC410EVM evaluation board.

## Hardware Components
- **FPGA**: Xilinx Virtex-5 LX50 (XC5VLX50-1FFG676)
- **DMD**: DLP7000 (XGA resolution: 1024 x 768 pixels)
- **Memory**: 2GB DDR2 SODIMM (150 MHz)
- **Host Interface**: Cypress FX2 USB 2.0 (48 MHz)
- **DMD Controller**: TI DLPC410

## Module Block Diagram
```text
+---------+      +----------+      +----------+      +----------+
|         | USB  |          |      |          | DDR2 |          |
| Host PC | <--> |  USB_IO  | <--> |  MEM_IO  | <--> |   DDR2   |
|         |      |          |      |          |      |  Memory  |
+---------+      +----------+      +----------+      +----------+
                      |                 ^                 ^
                      v                 |                 |
                 +----------+      +----------+           |
                 | Control  |      |   DMD    |           |
                 | Registers|      | Trigger  | <---------+
                 +----------+      | Control  |
                      |            +----------+
                      |                 |
                      v                 v
                 +----------------------------+      +----------+
                 |        DMD_control         | ---> | DLPC410  |
                 | (LVDS / Row Sequencing)     |      | (DMD Drv)|
                 +----------------------------+      +----------+
```

## Data Flow
### Write Path (Host to Memory)
1. Host sends pattern data via USB (16-bit @ 48MHz).
2. `USB_IO` receives data and performs byte swapping (`[7:0] & [15:8]`).
3. Data is pushed into `FIFO_RCV2` (Async FIFO).
4. `MEM_IO` pulls data from FIFO and writes to DDR2 memory (128-bit @ 150MHz).

### Read Path (Memory to DMD)
1. `DMD_trigger_control` receives a trigger (external or internal).
2. It requests pattern data from `MEM_IO` via `mem_read_enable_fifo`.
3. `MEM_IO` reads 128-bit blocks from DDR2 and pushes them into `read_fifo`.
4. `DMD_trigger_control` sequences the rows and sends data to `DMD_control`.
5. `DMD_control` outputs LVDS data to the DLPC410 at 400MHz.

## Clock Domains
| Clock Name | Frequency | Domain | Primary Modules |
|------------|-----------|--------|-----------------|
| `ifclk` | 48 MHz | USB | USB_IO |
| `mem_clk0` | 150 MHz | DDR2 | MEM_IO, MIG Core |
| `system_clk` | 200 MHz | System | appscore, registers, trigger_control |
| `clk_dmd` | 400 MHz | DMD | appsfpga_io, OSERDES |

## Clock Domain Crossing (CDC)
The system uses asynchronous FIFOs to bridge different clock domains:
- **`FIFO_RCV2`**: Bridges USB (48 MHz) to MEM (150 MHz).
- **`read_fifo`**: Bridges MEM (150 MHz) to System (200 MHz).
- **`mem_read_enable_fifo`**: Bridges System (200 MHz) to MEM (150 MHz).

## Load Modes
The system supports different row loading strategies to balance resolution and speed.

| Mode | Description | Vertical Res | Speed | Memory Usage |
|------|-------------|--------------|-------|--------------|
| **Load1** | Standard full resolution | 768 rows | 1x | 1x |
| **Load2** | 2 rows share same data | 384 rows | 0.5x* | 0.5x (2x capacity) |
| **Load4** | 4 rows share same data | 192 rows | 4x | 1x |

\* *Note: Load2 increases load time because it requires more row address cycles to fill the same physical space, but it doubles the number of patterns that can be stored in memory.*

## Update Modes
The DMD supports several update modes via the DLPC410:
- **Global**: All mirrors update simultaneously.
- **Quad**: DMD divided into 4 blocks, updated sequentially.
- **Dual**: DMD divided into 2 blocks, updated sequentially.
- **Single**: Single block update.
- **Phased (Mode 5)**: Custom phased update mode for reduced latency/jitter.

## New Feature Architecture (Planned)
The upcoming overhaul introduces a programmable sequencer and timing controller:
1. **Trigger Mux**: Selects between external TTL, USB software trigger, or internal timer.
2. **Timing Controller**: Enforces minimum exposure times and handles delays.
3. **Pattern Sequencer**: Automatically cycles through a pre-defined list of pattern IDs stored in memory.
4. **DMD Trigger Control Pipeline**: Integrates the sequencer into the existing data path for autonomous operation.
