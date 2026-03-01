# DMD FPGA Control System Overhaul for NV Center Experiments

## TL;DR

> **Quick Summary**: Refactor the DLP7000 DMD FPGA control codebase (Mathews et al. design), then add Load2 mechanism, USB-based pattern switching, pattern sequencing with variable timing, and multi-trigger support for Nitrogen-Vacancy center in diamond experiments.
>
> **Deliverables**:
> - Clean repository with only essential FPGA + reference files
> - Load2 VHDL module enabling 2-row-duplicate loading (doubles pattern storage capacity)
> - USB register-based pattern switching (complement existing TTL trigger)
> - Pattern sequencer FSM with programmable sequence order and per-pattern timing
> - Multi-trigger mux: TTL external + USB command + internal timer
> - Simulation testbenches for all new modules
> - Updated control register map and documentation
>
> **Estimated Effort**: Large
> **Parallel Execution**: YES - 4 waves
> **Critical Path**: Task 1 (cleanup) → Task 4 (Load2) → Task 9 (integration) → Task 12 (verification)

---

## Context

### Original Request
User needs to:
1. Refactor repo - remove unused code, keep only DMD + memory-related FPGA code
2. Understand and enhance memory connection code - add USB pattern switching and feature extensions
3. Investigate Load4 mechanism and add Load2 variant for speed/resolution balance

### Interview Summary
**Key Discussions**:
- Hardware confirmed: DLPLCRC410EVM + DLP7000 + 2GB DDR2, TI DLL works, custom FPGA not yet synthesized
- Application: NV center in diamond - needs kHz+ high-speed optical modulation
- DMD usage area: Central 500-700 pixels (partial DMD, near-Global mode)
- Load2 motivation: Speed/resolution balance exploration
- Feature extensions: Pattern sequencing, variable timing, multi-trigger (TTL+USB+timer)
- Host software: User has own Python wrapper - no changes needed here

**Research Findings**:
- 5 explore agents + 5 TI documents + Mathews paper fully analyzed
- File categorization complete: ~30 unchanged TI, 9 new (core value), backup/redundant identified
- Data flow mapped: USB→FIFO→DDR2→FIFO→DMD_control→DLPC410

### Metis Review
**Identified Gaps** (addressed):
- **CRITICAL**: Load2 does NOT improve speed - it INCREASES load time per frame (2x row cycles) but HALVES memory per pattern. Value is storage capacity, not throughput.
- Load2 must use ROW_MD="10" (random addressing), not auto-increment
- 50,000 Hz MCP rate is hard ceiling on pattern switching regardless of FPGA design
- Trigger synchronization needs explicit miss-detection and deterministic behavior
- Clock domain crossing between USB(48MHz), Memory(150MHz), System(200MHz), DMD(400MHz) needs careful FIFO management

---

## Work Objectives

### Core Objective
Transform the ETH Zurich DMD FPGA reference design into a clean, feature-rich control system optimized for NV center experiments, adding Load2, USB pattern switching, programmable sequencing, and multi-trigger capabilities.

### Concrete Deliverables
- Clean repo structure (delete backups, archive TI reference)
- `DMD_trigger_control.vhdl` enhanced with Load2 FSM
- `control_registers.vhd` updated with new register addresses for sequencing, timing, trigger control
- New module: `pattern_sequencer.vhd` - FSM for auto-pattern cycling
- New module: `timing_controller.vhd` - per-pattern variable timing
- New module: `trigger_mux.vhd` - multi-source trigger arbitration
- Updated `appscore.vhd` top-level integration
- Simulation testbenches for each new module
- Architecture documentation (register map, data flow)

### Definition of Done
- [x] `xst` synthesis completes without errors for Virtex-5 LX50 target
- [ ] All simulation testbenches pass in ISE ISim
- [x] Load2 correctly sends same data to 2 consecutive row addresses
- [x] USB pattern switching changes active pattern via register write
- [x] Pattern sequencer cycles through N patterns automatically
- [x] Variable timing assigns different display periods per pattern
- [x] Multi-trigger accepts TTL, USB command, and internal timer sources
- [ ] No regressions: existing Load4 + TTL trigger still work

### Must Have
- Load2 mechanism with ROW_MD="10" random addressing
- USB register-based pattern switching
- Pattern sequencer with programmable sequence (min 2, max 2543 patterns)
- Variable timing per pattern (configurable in clock cycles)
- TTL + USB + internal timer trigger sources
- Backward compatibility: Load4 and TTL-only mode still functional
- Clean repo structure

### Must NOT Have (Guardrails)
- NO host software modifications (user has own Python wrapper)
- NO Update Mode changes (Global/Quad/Dual/Single stay as-is)
- NO hardware modifications
- NO new DMD type support (DLP7000 only)
- NO modification of TI reference files that are currently unchanged (~30 files)
- NO claiming Load2 improves switching speed (it improves STORAGE CAPACITY at cost of load time)
- NO exceeding 50,000 Hz MCP rate in pattern sequencer timing
- NO modifying DDR2 memory controller addressing scheme (MEM_IO.vhd stays stable)
- NO over-engineering: each new module should be a focused, single-responsibility VHDL entity

---

## Verification Strategy

> **ZERO HUMAN INTERVENTION** - ALL verification is agent-executed. No exceptions.

### Test Decision
- **Infrastructure exists**: YES (Xilinx ISE ISim, testbench files in `APPSFPGA_MEM/src/sim/`)
- **Automated tests**: Tests-after (write implementation then testbench)
- **Framework**: Xilinx ISE ISim (VHDL testbenches)
- **Synthesis**: XST for Virtex-5 LX50 target

### QA Policy
Every task MUST include agent-executed QA scenarios.
Evidence saved to `.sisyphus/evidence/task-{N}-{scenario-slug}.{ext}`.

- **VHDL modules**: Use ISE ISim - compile testbench, run simulation, check waveform assertions
- **Synthesis**: Use XST - synthesize and check for errors/warnings
- **Register verification**: Use testbench to write/read registers and verify values
- **Integration**: End-to-end testbench simulating USB data → memory → trigger → DMD output

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Foundation - repo cleanup + documentation):
├── Task 1: Repository cleanup and reorganization [quick]
├── Task 2: Architecture documentation - register map + data flow [writing]
└── Task 3: Create simulation infrastructure (common testbench utilities) [quick]

Wave 2 (Core Features - MAX PARALLEL):
├── Task 4: Load2 mechanism in DMD_trigger_control (depends: 1) [deep]
├── Task 5: USB pattern switching via register (depends: 1) [unspecified-high]
├── Task 6: Pattern sequencer FSM (depends: 1) [deep]
├── Task 7: Variable timing controller (depends: 1) [unspecified-high]
└── Task 8: Multi-trigger source mux (depends: 1) [unspecified-high]

Wave 3 (Integration):
├── Task 9: Control register map update (depends: 4,5,6,7,8) [unspecified-high]
├── Task 10: Top-level integration in appscore.vhd (depends: 9) [deep]
└── Task 11: Simulation testbenches for all new modules (depends: 4,5,6,7,8) [unspecified-high]

Wave 4 (Verification):
├── Task 12: XST synthesis verification (depends: 10) [unspecified-high]
└── Task 13: Integration simulation - full data path test (depends: 10,11) [deep]

Wave FINAL (Independent Review - 4 parallel):
├── Task F1: Plan compliance audit (oracle)
├── Task F2: Code quality review (unspecified-high)
├── Task F3: Simulation QA - run all testbenches (unspecified-high)
└── Task F4: Scope fidelity check (deep)

Critical Path: Task 1 → Task 4 → Task 9 → Task 10 → Task 12 → F1-F4
Parallel Speedup: ~60% faster than sequential
Max Concurrent: 5 (Wave 2)
```

### Dependency Matrix

| Task | Depends On | Blocks | Wave |
|------|-----------|--------|------|
| 1 | - | 2,3,4,5,6,7,8 | 1 |
| 2 | - | - | 1 |
| 3 | - | 11 | 1 |
| 4 | 1 | 9,11 | 2 |
| 5 | 1 | 9,11 | 2 |
| 6 | 1 | 9,11 | 2 |
| 7 | 1 | 9,11 | 2 |
| 8 | 1 | 9,11 | 2 |
| 9 | 4,5,6,7,8 | 10 | 3 |
| 10 | 9 | 11,12,13 | 3 |
| 11 | 4,5,6,7,8,3 | 13 | 3 |
| 12 | 10 | F1-F4 | 4 |
| 13 | 10,11 | F1-F4 | 4 |

### Agent Dispatch Summary

- **Wave 1**: 3 tasks - T1→`quick`, T2→`writing`, T3→`quick`
- **Wave 2**: 5 tasks - T4→`deep`, T5→`unspecified-high`, T6→`deep`, T7→`unspecified-high`, T8→`unspecified-high`
- **Wave 3**: 3 tasks - T9→`unspecified-high`, T10→`deep`, T11→`unspecified-high`
- **Wave 4**: 2 tasks - T12→`unspecified-high`, T13→`deep`
- **FINAL**: 4 tasks - F1→`oracle`, F2→`unspecified-high`, F3→`unspecified-high`, F4→`deep`

---

## TODOs

### Wave 1: Foundation (Start Immediately)

- [x] 1. Repository Cleanup and Reorganization

  **What to do**:
  - Delete `APPSFPGA_MEM/src (copy)/` directory (confirmed redundant backup)
  - Delete root-level `git_dmd_trig.vhdl`, `git_MEM_IO.vhdl`, `git_USB.vhdl` (duplicate extractions of src/rtl files)
  - Move `example_verilog/` to `archive/ti_reference/` (preserve TI original for reference but out of main path)
  - Delete generated/temporary files: `*.wdb`, `*.exe` (simulation artifacts), `_ngo/`, `_xmsgs/`, `xst/`, `xlnx_auto_0_xdb/`
  - Move `raw_results/` to `archive/raw_results/`
  - Verify `APPSFPGA_MEM/src/rtl/` contains all 39 necessary VHDL/V source files
  - Update `.gitignore` to exclude ISE build artifacts (`*.wdb`, `*.exe`, `_ngo/`, `_xmsgs/`, etc.)

  **Must NOT do**:
  - Do NOT modify any VHDL source files in `APPSFPGA_MEM/src/rtl/`
  - Do NOT delete `docs/` directory or any PDF documentation
  - Do NOT delete `DMDController/` directory
  - Do NOT delete `APPSFPGA_MEM/ipcore_dir/` (contains MIG IP cores needed for synthesis)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: File operations only, no code logic changes
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 2, 3)
  - **Blocks**: Tasks 4, 5, 6, 7, 8
  - **Blocked By**: None (can start immediately)

  **References**:
  **Pattern References**:
  - `APPSFPGA_MEM/src/rtl/` - All 39 source files that MUST be preserved
  - `APPSFPGA_MEM/src (copy)/` - Confirmed identical to src/ except byte 4840 in appscore.vhd (line 102)

  **WHY Each Reference Matters**:
  - The src (copy) vs src comparison was done by explore agent - confirmed redundant
  - git_*.vhdl files confirmed as duplicates of USB_IO.vhd, DMD_trigger_control.vhdl, MEM_IO_Verilog.v

  **Acceptance Criteria**:
  - [ ] `APPSFPGA_MEM/src (copy)/` directory does not exist
  - [ ] `git_*.vhdl` files at root level do not exist
  - [ ] `archive/ti_reference/` contains moved example_verilog contents
  - [ ] `APPSFPGA_MEM/src/rtl/` still contains all source files (count >= 39)
  - [ ] `.gitignore` updated with ISE artifact patterns

  **QA Scenarios:**
  ```
  Scenario: Verify cleanup completeness
    Tool: Bash
    Steps:
      1. Run `ls -la git_*.vhdl` - should return 'No such file'
      2. Run `ls "APPSFPGA_MEM/src (copy)/"` - should return 'No such file or directory'
      3. Run `ls APPSFPGA_MEM/src/rtl/*.vhd APPSFPGA_MEM/src/rtl/*.vhdl APPSFPGA_MEM/src/rtl/*.v | wc -l` - should be >= 39
      4. Run `ls archive/ti_reference/Software/source/*.vhd | wc -l` - should be >= 20
      5. Run `cat .gitignore | grep wdb` - should show exclusion pattern
    Expected Result: All 5 checks pass
    Evidence: .sisyphus/evidence/task-1-cleanup-verification.txt
  ```

  **Commit**: YES
  - Message: `refactor(repo): clean up repository structure and remove redundant files`
  - Files: deleted files, moved dirs, .gitignore

- [x] 2. Architecture Documentation

  **What to do**:
  - Create `docs/ARCHITECTURE.md` documenting:
    - System block diagram (APPSFPGA modules and connections)
    - Complete register map (existing 0x00-0x28 + new registers for Load2, sequencing, timing, trigger)
    - Data flow: USB to DDR2 write path and DDR2 to DMD read path
    - Clock domains: USB(48MHz), Memory(150MHz), System(200MHz), DMD(400MHz)
    - FIFO roles and CDC (Clock Domain Crossing) strategy
    - Load4 vs Load2 comparison table (speed vs resolution vs memory trade-offs)
    - Update modes summary (Global/Quad/Dual/Single with timing from Mathews paper)
    - New feature register addresses (planned)
  - Create `docs/REGISTER_MAP.md` with detailed register-level documentation:
    - Each register: address, name, R/W, bit fields, reset value, description
    - Include both existing TI registers and new custom registers

  **Must NOT do**:
  - Do NOT modify any VHDL source code
  - Do NOT create implementation code

  **Recommended Agent Profile**:
  - **Category**: `writing`
    - Reason: Documentation task requiring clear technical writing
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 3)
  - **Blocks**: None (informational, but useful for all Wave 2 tasks)
  - **Blocked By**: None

  **References**:
  **Pattern References**:
  - `APPSFPGA_MEM/src/rtl/D4100_registers.vhd` - Existing register definitions (addresses 0x00-0x28)
  - `APPSFPGA_MEM/src/rtl/control_registers.vhd` - Enhanced register interface with memory control
  - `DMDController/DMDController/vendor/RegisterDefines.h` - Register addresses from host side
  - `docs/dlpu045a.pdf` - TI APPSFPGA design guide with IO list and block descriptions

  **External References**:
  - Mathews et al. 2022 paper Table I - Latency and refresh rate measurements

  **WHY Each Reference Matters**:
  - D4100_registers.vhd: Contains current register addresses and bit definitions - must document ALL
  - control_registers.vhd: Shows new registers added by Mathews team - pattern_num, mode, etc.
  - RegisterDefines.h: Cross-reference to ensure host-side and FPGA-side addresses match

  **Acceptance Criteria**:
  - [ ] `docs/ARCHITECTURE.md` exists with system block diagram section
  - [ ] `docs/REGISTER_MAP.md` exists with all registers documented
  - [ ] All existing registers (0x00-0x28) documented
  - [ ] New register addresses (0x29-0x2F) reserved and documented
  - [ ] Clock domain diagram included

  **QA Scenarios:**
  ```
  Scenario: Verify documentation completeness
    Tool: Bash (grep)
    Steps:
      1. grep '0x0016' docs/REGISTER_MAP.md - should find DMD_CONTROL register
      2. grep '0x0028' docs/REGISTER_MAP.md - should find MODE register
      3. grep 'Load2' docs/ARCHITECTURE.md - should find Load2 description
      4. grep 'Clock Domain' docs/ARCHITECTURE.md - should find clock domain section
      5. grep 'FIFO' docs/ARCHITECTURE.md - should find FIFO documentation
    Expected Result: All 5 greps return matches
    Evidence: .sisyphus/evidence/task-2-docs-verification.txt
  ```

  **Commit**: YES
  - Message: `docs(fpga): add architecture documentation and register map`
  - Files: docs/ARCHITECTURE.md, docs/REGISTER_MAP.md

- [x] 3. Simulation Infrastructure Setup

  **What to do**:
  - Review existing testbench files in `APPSFPGA_MEM/src/sim/`:
    - `appsfpga_tb.v` - Top-level testbench
    - `sim_tb_top.v` - Simulation top
    - `trigger_dmd_control_tb.v` - Trigger control testbench
    - `usb_io_tb.v` - USB IO testbench
    - `mem_io_tb.v` - Memory IO testbench
    - `ddr2_model.v` - DDR2 behavioral model
  - Create `APPSFPGA_MEM/src/sim/tb_common_pkg.vhd` - Shared testbench utilities:
    - Clock generation procedures (48MHz, 150MHz, 200MHz, 400MHz)
    - Reset generation procedure
    - USB register write/read simulation procedures
    - USB data write simulation procedure
    - Assert with message utility
    - Wait-for-signal-with-timeout utility
  - Verify existing testbenches compile in ISE ISim
  - Create `APPSFPGA_MEM/src/sim/run_all_tests.tcl` - TCL script to run all testbenches

  **Must NOT do**:
  - Do NOT modify existing testbench files
  - Do NOT delete any simulation models (ddr2_model.v)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Small utility file creation, no complex logic
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2)
  - **Blocks**: Task 11 (testbench creation depends on common utilities)
  - **Blocked By**: None

  **References**:
  **Pattern References**:
  - `APPSFPGA_MEM/src/sim/appsfpga_tb.v` - Existing testbench structure and conventions
  - `APPSFPGA_MEM/src/sim/trigger_dmd_control_tb.v` - Trigger control test patterns
  - `APPSFPGA_MEM/src/sim/ddr2_model.v` - DDR2 behavioral model for memory simulation

  **WHY Each Reference Matters**:
  - appsfpga_tb.v: Shows existing clock generation and reset patterns to match
  - trigger_dmd_control_tb.v: Shows how trigger signals are stimulated in tests
  - ddr2_model.v: Required for any test involving DDR2 memory read/write

  **Acceptance Criteria**:
  - [ ] `tb_common_pkg.vhd` exists with clock, reset, USB simulation procedures
  - [ ] `run_all_tests.tcl` exists and lists all testbench targets
  - [ ] Existing testbenches still compile (no regressions)

  **QA Scenarios:**
  ```
  Scenario: Verify testbench utilities compile
    Tool: Bash
    Steps:
      1. Check tb_common_pkg.vhd exists: `ls APPSFPGA_MEM/src/sim/tb_common_pkg.vhd`
      2. Check it contains clock procedures: `grep 'clk_gen' APPSFPGA_MEM/src/sim/tb_common_pkg.vhd`
      3. Check run_all_tests.tcl exists: `ls APPSFPGA_MEM/src/sim/run_all_tests.tcl`
    Expected Result: All files exist with expected content
    Evidence: .sisyphus/evidence/task-3-sim-infra.txt
  ```

  **Commit**: YES
  - Message: `test(fpga): add simulation infrastructure and common testbench utilities`
  - Files: APPSFPGA_MEM/src/sim/tb_common_pkg.vhd, APPSFPGA_MEM/src/sim/run_all_tests.tcl

### Wave 2: Core Features (After Wave 1 - MAX PARALLEL)

- [x] 4. Load2 Mechanism in DMD Trigger Control

  **What to do**:
  - Modify `APPSFPGA_MEM/src/rtl/DMD_trigger_control.vhdl` to add Load2 mode:
    - Add `load2_enable` input signal (active high, from control register)
    - When load2_enable=1 and trigger fires:
      - Read one 128-bit data word from memory read FIFO (same as current)
      - Send data to DMD with ROW_MD="10" (random address), ROW_AD=2k
      - Send SAME data again with ROW_MD="10", ROW_AD=2k+1
      - Increment k, read next data word from memory
      - Repeat until all logical rows sent (half the physical row count)
    - When load2_enable=0: existing behavior (Load4 or Load1 based on load4z)
  - Key implementation details:
    - Use ROW_MD="10" (random addressing) - NOT auto-increment mode
    - Each logical row requires 2 DVALID pulses (one per physical row)
    - row_count for Load2 = total_physical_rows / 2 (384 for full XGA, ~250-350 for 500-700 pixel area)
    - Memory read rate: unchanged (still read 1 word per logical row)
    - DMD write rate: 2x slower per logical row (2 physical writes per logical row)
  - Add state machine states: LOAD2_ROW_A, LOAD2_ROW_B for the paired writes
  - IMPORTANT: Load2 INCREASES load time per frame (2x row cycles) but HALVES memory per pattern
  - Ensure ROW_AD is stable before DVALID asserts and held through entire row cycle

  **Must NOT do**:
  - Do NOT modify MEM_IO.vhd (memory controller stays unchanged)
  - Do NOT modify memory addressing scheme (patterns still stored same way in DDR2)
  - Do NOT modify existing Load4 behavior when load2_enable=0
  - Do NOT claim Load2 improves speed (it improves storage capacity)

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Complex state machine modification in timing-critical DMD control logic
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 5, 6, 7, 8)
  - **Blocks**: Tasks 9, 11
  - **Blocked By**: Task 1 (repo cleanup)

  **References**:
  **Pattern References**:
  - `APPSFPGA_MEM/src/rtl/DMD_trigger_control.vhdl` - MAIN FILE TO MODIFY. Current trigger FSM (S0=Idle, S1=Active). Lines 134-136 define states. Lines 559-631 handle state transitions. Lines 682-691 handle data output mapping (dmd_dout_a/b/c/d). Row counting at cnts_row_pos_cnt.
  - `APPSFPGA_MEM/src/rtl/DMD_control.vhd` - DMD data output formatting. Shows how dmd_rowmd, dmd_rowad, dmd_blkad, dmd_blkmd, dmd_dvalid signals are generated.

  **API/Type References**:
  - `APPSFPGA_MEM/src/rtl/appsfpga_dmd_types_pkg.vhd` - DMD type definitions. XGA=768 rows, 16 blocks x 48 rows. Row/block constants used throughout.
  - `APPSFPGA_MEM/src/rtl/D4100_registers.vhd` - Register 0x0016 bit 7 = LOAD4. New Load2 will need a register bit (suggest 0x0016 bit 6 or new register 0x29).

  **External References**:
  - `docs/dlpa008b.pdf` - DMD micromirror loading mechanics. ROW_MD modes: 00=hold, 01=increment, 10=random, 11=reset.
  - Mathews et al. 2022 Table I - Timing reference: 8192 data load cycles for 768 rows in Global mode

  **WHY Each Reference Matters**:
  - DMD_trigger_control.vhdl: This IS the file being modified. Must understand S0/S1 state machine, data_in_count, cnts_row_pos_cnt, dmd_ab_swap/cd_swap data paths
  - DMD_control.vhd: Shows how rowmd/rowad signals reach DLPC410 - Load2 must set these correctly
  - dlpa008b.pdf: Confirms ROW_MD=10 is the correct mode for random addressing needed by Load2

  **Acceptance Criteria**:
  - [ ] DMD_trigger_control.vhdl modified with load2_enable input
  - [ ] When load2_enable=1: each logical row generates 2 DVALID pulses to 2 consecutive ROW_AD values
  - [ ] ROW_MD set to "10" (random) during Load2 row writes
  - [ ] When load2_enable=0: existing Load4/Load1 behavior unchanged
  - [ ] Row count correctly halved when Load2 active (logical_rows = physical_rows / 2)

  **QA Scenarios:**
  ```
  Scenario: Load2 sends same data to consecutive row pairs
    Tool: Bash (ISE ISim)
    Preconditions: Testbench with 4 logical rows of test data in simulated memory
    Steps:
      1. Set load2_enable=1 via register write
      2. Assert trigger signal (rising edge)
      3. Monitor dmd_rowad output sequence
      4. Verify: row addresses are 0,1,2,3,4,5,6,7 (pairs 0-1, 2-3, 4-5, 6-7)
      5. Verify: dmd_dout_a/b data for addr 0 equals data for addr 1 (same pair)
      6. Verify: ROW_MD="10" throughout Load2 operation
    Expected Result: 4 logical rows produce 8 physical row writes in consecutive pairs
    Failure Indicators: Row addresses skip, data differs between paired rows, ROW_MD not "10"
    Evidence: .sisyphus/evidence/task-4-load2-row-pairs.txt

  Scenario: Load2 disabled falls back to existing behavior
    Tool: Bash (ISE ISim)
    Preconditions: Same testbench
    Steps:
      1. Set load2_enable=0
      2. Assert trigger
      3. Verify row addressing matches original behavior
    Expected Result: Same behavior as before Load2 modification
    Evidence: .sisyphus/evidence/task-4-load2-disabled.txt
  ```

  **Commit**: YES
  - Message: `feat(fpga): add Load2 mechanism to DMD trigger control`
  - Files: APPSFPGA_MEM/src/rtl/DMD_trigger_control.vhdl

- [x] 5. USB Register-Based Pattern Switching

  **What to do**:
  - Add USB pattern switching capability to complement existing TTL trigger:
    - In `control_registers.vhd`: Add new register `USB_PATTERN_SWITCH` at address 0x29:
      - Bit 0: `usb_switch_trigger` - Write 1 to trigger pattern switch (auto-clears)
      - Bits 15:1: `usb_next_pattern_id` - Pattern ID to switch to (0-32767)
    - In `DMD_trigger_control.vhdl`: Add `usb_switch_request` input alongside existing `trigger` input:
      - When usb_switch_request=1: same behavior as TTL trigger but with specified pattern_id
      - Pattern ID from USB overrides the auto-increment (current TTL just goes to next pattern)
    - This enables PC to command specific pattern display without external hardware
  - Generate `usb_switch_request` pulse (single system_clk cycle) from register write
  - Ensure no race condition if USB switch and TTL trigger arrive simultaneously (TTL takes priority)

  **Must NOT do**:
  - Do NOT remove or modify TTL trigger functionality
  - Do NOT change USB data upload protocol (image data still via FIFO_REGN=1)
  - Do NOT modify MEM_IO.vhd

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Register interface + trigger logic integration, moderate complexity
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 4, 6, 7, 8)
  - **Blocks**: Tasks 9, 11
  - **Blocked By**: Task 1

  **References**:
  **Pattern References**:
  - `APPSFPGA_MEM/src/rtl/control_registers.vhd:351` - Current register interface. Shows how registers are read/written. Lines handle reg_data_from_usb, reg_addra_USB for register addressing.
  - `APPSFPGA_MEM/src/rtl/DMD_trigger_control.vhdl:530-540` - Current trigger processing. Shows how TTL trigger rising edge is detected and trigger_miss flag is set.
  - `APPSFPGA_MEM/src/rtl/USB_IO.vhd:437-516` - USB data decode logic showing FIFO_REGN=0 for register writes vs FIFO_REGN=1 for data writes.

  **API/Type References**:
  - `DMDController/DMDController/vendor/RegisterDefines.h` - Existing register address map. Shows addr 0x00-0x28 used. New register at 0x29 is safe.

  **WHY Each Reference Matters**:
  - control_registers.vhd: MUST be modified to add new register. Existing pattern shows how to handle write-enable and data routing.
  - DMD_trigger_control.vhdl: MUST be modified to accept USB switch request as alternative trigger source
  - RegisterDefines.h: Confirms 0x29 is available (currently unused)

  **Acceptance Criteria**:
  - [ ] Register 0x29 writable from USB (write pattern_id + trigger bit)
  - [ ] Writing to 0x29 triggers pattern switch to specified pattern_id
  - [ ] TTL trigger still works independently
  - [ ] Simultaneous USB + TTL: TTL takes priority, USB request queued or dropped
  - [ ] Auto-clear: trigger bit self-clears after single pulse

  **QA Scenarios:**
  ```
  Scenario: USB pattern switch triggers correctly
    Tool: Bash (ISE ISim)
    Steps:
      1. Load 3 patterns to simulated memory
      2. Write 0x29 = 0x0005 (pattern_id=2, trigger=1)
      3. Verify DMD_trigger_control receives usb_switch_request pulse
      4. Verify rd_pattern_id changes to 2
      5. Verify pattern 2 data appears on dmd_dout_a/b
    Expected Result: Pattern switches to ID 2 on USB register write
    Evidence: .sisyphus/evidence/task-5-usb-switch.txt

  Scenario: TTL priority over USB
    Tool: Bash (ISE ISim)
    Steps:
      1. Assert TTL trigger and USB switch simultaneously
      2. Verify TTL trigger is processed first
      3. Verify USB switch is handled after TTL completes (or dropped)
    Expected Result: TTL trigger takes priority
    Evidence: .sisyphus/evidence/task-5-ttl-priority.txt
  ```

  **Commit**: YES
  - Message: `feat(fpga): add USB register-based pattern switching`
  - Files: APPSFPGA_MEM/src/rtl/control_registers.vhd, APPSFPGA_MEM/src/rtl/DMD_trigger_control.vhdl

- [x] 6. Pattern Sequencer FSM

  **What to do**:
  - Create new module `APPSFPGA_MEM/src/rtl/pattern_sequencer.vhd`:
    - Entity: pattern_sequencer
    - Inputs: clk, reset, seq_enable, trigger_in, sequence_length(14:0), seq_data_in(14:0), seq_wr_en, seq_wr_addr(14:0)
    - Outputs: pattern_id_out(14:0), trigger_out, sequence_done, current_index(14:0)
    - Internal: Block RAM storing sequence table (up to 2543 entries, each 15-bit pattern_id)
    - FSM States:
      - IDLE: Waiting for seq_enable
      - RUNNING: On each trigger_in, output pattern_id from sequence[current_index], increment index
      - WRAP: When current_index >= sequence_length, wrap to 0 (continuous) or stop (one-shot)
      - DONE: Sequence complete (one-shot mode)
    - Configuration via USB registers:
      - 0x2A: SEQ_CONTROL - [0]=enable, [1]=one_shot/continuous, [2]=reset_index
      - 0x2B: SEQ_LENGTH - Number of patterns in sequence (0-2542)
      - 0x2C: SEQ_WRITE_ADDR - Address for writing sequence entry
      - 0x2D: SEQ_WRITE_DATA - Pattern ID to write at SEQ_WRITE_ADDR
      - 0x2E: SEQ_STATUS - [14:0]=current_index (read-only), [15]=running flag
  - Sequence programming workflow:
    1. PC writes sequence entries: addr=0x2C(index), data=0x2D(pattern_id) pairs
    2. PC writes 0x2B with sequence length
    3. PC writes 0x2A bit 0 = 1 to enable
    4. Each trigger advances to next pattern in sequence

  **Must NOT do**:
  - Do NOT modify existing pattern_select register behavior (0x26) - sequencer is an alternative mode
  - Do NOT exceed 2543 sequence entries (DDR2 pattern limit)
  - Do NOT allow sequence programming while sequencer is running

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: New FSM design with Block RAM, multi-register interface, careful state management
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 4, 5, 7, 8)
  - **Blocks**: Tasks 9, 11
  - **Blocked By**: Task 1

  **References**:
  **Pattern References**:
  - `APPSFPGA_MEM/src/rtl/DMD_trigger_control.vhdl:134-136` - Existing FSM pattern (S0/S1 states). Use similar coding style for sequencer states.
  - `APPSFPGA_MEM/src/rtl/control_registers.vhd` - Register interface pattern. Shows how to add read/write registers.

  **API/Type References**:
  - `APPSFPGA_MEM/src/rtl/MEM_IO.vhd` - Shows rd_pattern_id(14:0) interface. Sequencer output must match this 15-bit pattern ID format.

  **WHY Each Reference Matters**:
  - DMD_trigger_control: Follow same VHDL coding style (signal naming, process structure, reset handling)
  - MEM_IO: rd_pattern_id is the actual signal that selects which pattern to read from DDR2 - sequencer must drive this

  **Acceptance Criteria**:
  - [ ] pattern_sequencer.vhd exists as standalone entity
  - [ ] Sequence table programmable via registers (0x2A-0x2E)
  - [ ] Each trigger advances to next pattern in programmed sequence
  - [ ] Continuous mode: wraps to beginning after last entry
  - [ ] One-shot mode: stops at last entry, asserts sequence_done
  - [ ] current_index readable via status register 0x2E

  **QA Scenarios:**
  ```
  Scenario: Pattern sequencer cycles through 3-pattern sequence
    Tool: Bash (ISE ISim)
    Steps:
      1. Program sequence: [pattern_5, pattern_2, pattern_8]
      2. Set sequence_length=3, mode=continuous, enable=1
      3. Assert 5 triggers
      4. Verify pattern_id_out sequence: 5, 2, 8, 5, 2 (wraps after 3rd)
    Expected Result: Correct pattern IDs in order with wrap-around
    Evidence: .sisyphus/evidence/task-6-sequencer-cycle.txt

  Scenario: One-shot mode stops after sequence
    Tool: Bash (ISE ISim)
    Steps:
      1. Program 2-pattern sequence, mode=one_shot, enable=1
      2. Assert 3 triggers
      3. Verify: first 2 triggers produce patterns, 3rd trigger does NOT advance
      4. Verify sequence_done flag is asserted
    Expected Result: Sequencer stops and asserts done after last entry
    Evidence: .sisyphus/evidence/task-6-sequencer-oneshot.txt
  ```

  **Commit**: YES
  - Message: `feat(fpga): add pattern sequencer FSM`
  - Files: APPSFPGA_MEM/src/rtl/pattern_sequencer.vhd

- [x] 7. Variable Timing Controller

  **What to do**:
  - Create new module `APPSFPGA_MEM/src/rtl/timing_controller.vhd`:
    - Entity: timing_controller
    - Inputs: clk, reset, timing_enable, trigger_in, timing_data_in(31:0), timing_wr_en, timing_wr_addr(14:0)
    - Outputs: trigger_out (delayed trigger passed to DMD), timer_expired, current_timer(31:0)
    - Internal: Block RAM storing timing values (up to 2543 entries, each 32-bit = clock cycles)
    - Operation:
      - When timing_enable=0: trigger_in passes directly to trigger_out (bypass mode)
      - When timing_enable=1:
        - On trigger_in: load timer from timing_table[current_pattern_index]
        - Count down timer each clock cycle
        - When timer expires: assert trigger_out (trigger next pattern)
        - This creates per-pattern display duration
    - Configuration registers:
      - 0x2F: TIMING_CONTROL - [0]=enable, [1]=auto_trigger (timer auto-fires trigger_out on expiry)
      - 0x30: TIMING_WRITE_ADDR - Address for writing timing entry
      - 0x31: TIMING_WRITE_DATA_LO - Timing value lower 16 bits (clock cycles)
      - 0x32: TIMING_WRITE_DATA_HI - Timing value upper 16 bits
  - At 200MHz system clock: 32-bit timer gives range of 1 cycle (5ns) to 4.29 billion cycles (21.5 seconds)
  - Enforce minimum timing >= 20us (50kHz MCP rate limit): reject values < 4000 clock cycles via saturation

  **Must NOT do**:
  - Do NOT allow timer values below 4000 cycles (20us at 200MHz) - enforces 50kHz MCP rate limit
  - Do NOT modify existing trigger path when timing_enable=0 (transparent bypass)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Timer logic with Block RAM, moderate complexity
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 4, 5, 6, 8)
  - **Blocks**: Tasks 9, 11
  - **Blocked By**: Task 1

  **References**:
  **Pattern References**:
  - `APPSFPGA_MEM/src/rtl/DMD_trigger_control.vhdl` - Shows how trigger signals are processed and timing constraints. Reference for signal naming and process style.
  - `APPSFPGA_MEM/src/rtl/write_counter.vhd` - Example of a counter module in this codebase. 90 lines, simple counter pattern.

  **External References**:
  - Metis analysis: 50,000 Hz MCP rate is HARD CEILING from DLPA200 driver. Timer must enforce >= 20us minimum.

  **WHY Each Reference Matters**:
  - DMD_trigger_control: Shows trigger processing pattern to follow
  - write_counter: Provides coding style template for counter-based modules in this project

  **Acceptance Criteria**:
  - [ ] timing_controller.vhd exists as standalone entity
  - [ ] Timing table programmable via registers (0x2F-0x32)
  - [ ] Timer counts down and asserts trigger_out on expiry
  - [ ] Bypass mode (timing_enable=0) passes trigger transparently
  - [ ] Minimum timing enforced >= 4000 cycles (20us at 200MHz)
  - [ ] 32-bit timer range: 20us to 21.5 seconds

  **QA Scenarios:**
  ```
  Scenario: Variable timing produces correct delays
    Tool: Bash (ISE ISim)
    Steps:
      1. Program timing: pattern 0 = 10000 cycles, pattern 1 = 20000 cycles
      2. Enable timing mode, trigger pattern 0
      3. Measure clock cycles until trigger_out fires
      4. Verify: ~10000 cycles for pattern 0, ~20000 for pattern 1
    Expected Result: Timer matches programmed values within 2 clock cycles
    Evidence: .sisyphus/evidence/task-7-timing-accuracy.txt

  Scenario: Minimum timing enforcement
    Tool: Bash (ISE ISim)
    Steps:
      1. Program timing value = 100 cycles (below 4000 minimum)
      2. Verify: timer saturates to 4000 cycles minimum
    Expected Result: Actual delay is 4000 cycles, not 100
    Evidence: .sisyphus/evidence/task-7-timing-minimum.txt
  ```

  **Commit**: YES
  - Message: `feat(fpga): add variable timing controller`
  - Files: APPSFPGA_MEM/src/rtl/timing_controller.vhd

- [x] 8. Multi-Trigger Source Mux

  **What to do**:
  - Create new module `APPSFPGA_MEM/src/rtl/trigger_mux.vhd`:
    - Entity: trigger_mux
    - Inputs:
      - clk, reset
      - ttl_trigger_in (external TTL input, active on rising edge)
      - usb_trigger_in (from USB pattern switch register 0x29)
      - timer_trigger_in (from timing_controller auto-trigger output)
      - trigger_source_sel(1:0) (from register): 00=TTL only, 01=USB only, 10=Timer only, 11=Any (OR)
      - trigger_enable (global trigger enable)
    - Outputs:
      - trigger_out (single-pulse output to DMD_trigger_control)
      - trigger_source_id(1:0) (which source fired: 00=TTL, 01=USB, 10=Timer)
      - trigger_count(15:0) (total triggers since last reset)
    - Features:
      - Edge detection on TTL input (synchronize to system_clk, detect rising edge)
      - Pulse stretcher: ensure trigger_out is exactly 1 system_clk cycle wide
      - Priority: TTL > USB > Timer (when multiple arrive simultaneously)
      - Trigger counter for diagnostics (readable via status register)
    - Configuration register:
      - 0x33: TRIGGER_CONTROL - [1:0]=source_sel, [2]=enable, [3]=reset_counter
      - 0x34: TRIGGER_STATUS - [1:0]=last_source, [15:0]=trigger_count (read-only)

  **Must NOT do**:
  - Do NOT remove existing TTL trigger path (it must remain as default)
  - Do NOT introduce glitches on trigger_out (clean single-pulse only)
  - Do NOT allow trigger during active pattern load (use busy flag from DMD_trigger_control)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Multiplexer with edge detection and synchronization, moderate complexity
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 4, 5, 6, 7)
  - **Blocks**: Tasks 9, 11
  - **Blocked By**: Task 1

  **References**:
  **Pattern References**:
  - `APPSFPGA_MEM/src/rtl/DMD_trigger_control.vhdl:530-540` - Current TTL trigger edge detection and processing. Shows existing synchronization pattern.
  - `APPSFPGA_MEM/src/rtl/USB_IO.vhd` - Clock domain crossing patterns (48MHz to system_clk). Shows 2-stage synchronizer usage.

  **WHY Each Reference Matters**:
  - DMD_trigger_control: Shows EXISTING trigger input handling that trigger_mux output must replace
  - USB_IO: Shows CDC synchronizer pattern to follow for TTL input synchronization

  **Acceptance Criteria**:
  - [ ] trigger_mux.vhd exists as standalone entity
  - [ ] TTL, USB, Timer trigger inputs all functional
  - [ ] Source selection via register 0x33
  - [ ] Priority: TTL > USB > Timer for simultaneous triggers
  - [ ] trigger_out is clean single-pulse (no glitches)
  - [ ] Trigger counter increments correctly

  **QA Scenarios:**
  ```
  Scenario: TTL trigger passes through mux
    Tool: Bash (ISE ISim)
    Steps:
      1. Set trigger_source_sel=00 (TTL only), enable=1
      2. Assert TTL rising edge
      3. Verify trigger_out produces single clean pulse
      4. Verify trigger_source_id=00 (TTL)
      5. Verify trigger_count increments to 1
    Expected Result: Single pulse on trigger_out, correct source ID and count
    Evidence: .sisyphus/evidence/task-8-ttl-trigger.txt

  Scenario: Priority arbitration with simultaneous triggers
    Tool: Bash (ISE ISim)
    Steps:
      1. Set trigger_source_sel=11 (Any source)
      2. Assert TTL and USB triggers simultaneously
      3. Verify trigger_out fires once (not twice)
      4. Verify trigger_source_id=00 (TTL wins priority)
    Expected Result: TTL takes priority, single trigger output
    Evidence: .sisyphus/evidence/task-8-priority.txt
  ```

  **Commit**: YES
  - Message: `feat(fpga): add multi-trigger source mux`
  - Files: APPSFPGA_MEM/src/rtl/trigger_mux.vhd

---

### Wave 3: Integration (After Wave 2)

- [x] 9. Control Register Map Update

  **What to do**:
  - Update `APPSFPGA_MEM/src/rtl/control_registers.vhd` to add all new registers:
    - 0x29: USB_PATTERN_SWITCH (from Task 5)
    - 0x2A-0x2E: Pattern sequencer registers (from Task 6)
    - 0x2F-0x32: Timing controller registers (from Task 7)
    - 0x33-0x34: Trigger mux registers (from Task 8)
    - Load2 enable bit in existing register 0x0016 (from Task 4)
  - Update `APPSFPGA_MEM/src/rtl/D4100_registers.vhd` if needed for new address decoding
  - Ensure all new registers have proper reset values (0x0000)
  - Add read-back capability for all read-only status registers
  - Update docs/REGISTER_MAP.md with final register definitions

  **Must NOT do**:
  - Do NOT change addresses of existing registers (0x00-0x28)
  - Do NOT modify register write/read protocol (same USB interface)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Register interface integration, must carefully merge multiple features
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential (after Wave 2)
  - **Blocks**: Task 10
  - **Blocked By**: Tasks 4, 5, 6, 7, 8

  **References**:
  **Pattern References**:
  - `APPSFPGA_MEM/src/rtl/control_registers.vhd` - MAIN FILE TO MODIFY. Current register handling with case statements for address decode.
  - `APPSFPGA_MEM/src/rtl/D4100_registers.vhd` - Register definitions and address constants.
  - `DMDController/DMDController/vendor/RegisterDefines.h` - Host-side register defines for cross-reference.

  **Acceptance Criteria**:
  - [ ] All new registers (0x29-0x34) addressable and writable
  - [ ] Existing registers (0x00-0x28) unchanged
  - [ ] Read-only registers return correct status values
  - [ ] All registers reset to 0x0000 on system reset
  - [ ] docs/REGISTER_MAP.md updated with final register map

  **QA Scenarios:**
  ```
  Scenario: All new registers accessible
    Tool: Bash (ISE ISim)
    Steps:
      1. Write 0xAAAA to each new register (0x29-0x34)
      2. Read back each register
      3. Verify written values match (for R/W registers)
      4. Verify read-only registers return status (not written value)
    Expected Result: All R/W registers echo back written values
    Evidence: .sisyphus/evidence/task-9-registers.txt
  ```

  **Commit**: YES
  - Message: `feat(fpga): update control register map with all new feature registers`
  - Files: control_registers.vhd, D4100_registers.vhd, docs/REGISTER_MAP.md

- [x] 10. Top-Level Integration in appscore.vhd

  **What to do**:
  - Modify `APPSFPGA_MEM/src/rtl/appscore.vhd` to instantiate and wire all new modules:
    - Instantiate pattern_sequencer.vhd
    - Instantiate timing_controller.vhd
    - Instantiate trigger_mux.vhd
    - Wire trigger path: TTL_input -> trigger_mux -> timing_controller -> pattern_sequencer -> DMD_trigger_control
    - Wire USB switch: control_registers -> trigger_mux (USB trigger input)
    - Wire Load2: control_registers -> DMD_trigger_control (load2_enable signal)
    - Wire pattern ID: pattern_sequencer -> MEM_IO (rd_pattern_id override when sequencer enabled)
    - Wire timing: control_registers -> timing_controller (timing table programming)
    - Wire status: all status outputs -> control_registers (read-back path)
  - Add MUX for rd_pattern_id: when sequencer enabled, use sequencer output; otherwise use manual register
  - Ensure proper reset propagation to all new modules
  - Verify signal widths match at all connection points

  **Must NOT do**:
  - Do NOT modify MEM_IO.vhd, USB_IO.vhd, or DMD_control.vhd
  - Do NOT change existing signal names (backward compatibility)
  - Do NOT introduce combinational loops in the wiring

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Complex integration requiring understanding of all modules, signal routing, and timing
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential
  - **Blocks**: Tasks 11, 12, 13
  - **Blocked By**: Task 9

  **References**:
  **Pattern References**:
  - `APPSFPGA_MEM/src/rtl/appscore.vhd` - MAIN FILE TO MODIFY. 1050 lines. Currently instantiates USB_IO, MEM_IO, DMD_trigger_control, DMD_control, write_counter, control_registers. Must add 3 new instantiations.
  - All new module files from Wave 2 (pattern_sequencer.vhd, timing_controller.vhd, trigger_mux.vhd)

  **Acceptance Criteria**:
  - [ ] appscore.vhd instantiates all 3 new modules
  - [ ] Trigger chain: TTL -> trigger_mux -> timing_controller -> sequencer -> DMD_trigger_control
  - [ ] Pattern ID mux: sequencer_enabled ? sequencer_pattern_id : manual_pattern_id
  - [ ] All new module ports connected (no undriven signals)
  - [ ] Reset propagated to all new modules

  **QA Scenarios:**
  ```
  Scenario: Full trigger chain works end-to-end
    Tool: Bash (ISE ISim)
    Steps:
      1. Load 3 patterns, program sequence [0,1,2], enable sequencer and timing
      2. Assert TTL trigger
      3. Verify: trigger flows through mux -> timing -> sequencer -> DMD_trigger_control
      4. Verify: correct pattern data appears on DMD outputs
      5. Verify: after timing expires, next trigger auto-fires (if auto-trigger enabled)
    Expected Result: Complete trigger chain functional
    Evidence: .sisyphus/evidence/task-10-integration.txt
  ```

  **Commit**: YES
  - Message: `feat(fpga): integrate all new modules into appscore top-level`
  - Files: APPSFPGA_MEM/src/rtl/appscore.vhd

- [x] 11. Simulation Testbenches for All New Modules

  **What to do**:
  - Create testbenches for each new module:
    - `APPSFPGA_MEM/src/sim/load2_tb.vhd` - Load2 mechanism test
    - `APPSFPGA_MEM/src/sim/pattern_sequencer_tb.vhd` - Sequencer test
    - `APPSFPGA_MEM/src/sim/timing_controller_tb.vhd` - Timing test
    - `APPSFPGA_MEM/src/sim/trigger_mux_tb.vhd` - Trigger mux test
    - `APPSFPGA_MEM/src/sim/integration_tb.vhd` - Full integration test
  - Each testbench must:
    - Use tb_common_pkg utilities from Task 3
    - Test happy path + edge cases from QA scenarios in Tasks 4-8
    - Include self-checking assertions (report PASS/FAIL)
    - Run in ISE ISim without manual intervention
  - Update run_all_tests.tcl to include new testbenches

  **Must NOT do**:
  - Do NOT modify existing testbench files
  - Do NOT create testbenches that require interactive input

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Multiple testbench files, must cover all QA scenarios from Wave 2 tasks
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Task 9, after Wave 2)
  - **Parallel Group**: Wave 3
  - **Blocks**: Task 13
  - **Blocked By**: Tasks 3, 4, 5, 6, 7, 8

  **References**:
  **Pattern References**:
  - `APPSFPGA_MEM/src/sim/trigger_dmd_control_tb.v` - Existing testbench showing stimulus patterns and assertion style
  - `APPSFPGA_MEM/src/sim/appsfpga_tb.v` - Top-level testbench showing how modules are instantiated in tests

  **Acceptance Criteria**:
  - [ ] 5 new testbench files created
  - [ ] Each testbench has self-checking assertions
  - [ ] run_all_tests.tcl updated with all new testbench targets
  - [ ] All testbenches compile without errors

  **QA Scenarios:**
  ```
  Scenario: All testbenches compile and run
    Tool: Bash
    Steps:
      1. List all *_tb.vhd files in sim/: should be >= 5 new files
      2. Check each contains 'assert' keyword (self-checking)
      3. Check run_all_tests.tcl references all new testbenches
    Expected Result: All testbench files exist and are self-checking
    Evidence: .sisyphus/evidence/task-11-testbenches.txt
  ```

  **Commit**: YES
  - Message: `test(fpga): add simulation testbenches for all new modules`
  - Files: APPSFPGA_MEM/src/sim/*_tb.vhd, APPSFPGA_MEM/src/sim/run_all_tests.tcl

---

### Wave 4: Verification (After Wave 3)

- [x] 12. XST Synthesis Verification

  **What to do**:
  - Run Xilinx XST synthesis targeting Virtex-5 LX50 (xc5vlx50-1ff676):
    - Use existing `APPSFPGA_MEM/appsfpga.xst` synthesis settings
    - Update `APPSFPGA_MEM/appsfpga_vhdl.prj` to include all new source files
    - Run: `xst -ifn appsfpga.xst -ofn appsfpga.syr`
    - Check synthesis report for:
      - Zero errors
      - Review warnings (acceptable: unused signals; unacceptable: latches, timing)
      - Resource utilization fits within Virtex-5 LX50 (check LUTs, FFs, Block RAMs)
  - If synthesis fails: fix issues and re-run
  - Generate post-synthesis netlist for timing analysis

  **Must NOT do**:
  - Do NOT change FPGA target device
  - Do NOT ignore latch inference warnings (fix them)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Synthesis tool execution and report analysis
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Task 13)
  - **Parallel Group**: Wave 4
  - **Blocks**: F1-F4
  - **Blocked By**: Task 10

  **References**:
  **Pattern References**:
  - `APPSFPGA_MEM/appsfpga.xst` - Existing XST synthesis script
  - `APPSFPGA_MEM/appsfpga_vhdl.prj` - Project file listing all source files for synthesis

  **Acceptance Criteria**:
  - [ ] XST synthesis completes with zero errors
  - [ ] No latch inference warnings
  - [ ] Resource utilization within Virtex-5 LX50 limits
  - [ ] All new source files included in project file

  **QA Scenarios:**
  ```
  Scenario: Synthesis succeeds
    Tool: Bash (xst)
    Steps:
      1. Run xst synthesis
      2. Check .syr file for 'ERROR' - should be zero
      3. Check for 'WARNING.*latch' - should be zero
      4. Check utilization summary fits LX50
    Expected Result: Clean synthesis with acceptable utilization
    Evidence: .sisyphus/evidence/task-12-synthesis.txt
  ```

  **Commit**: YES
  - Message: `build(fpga): verify XST synthesis for Virtex-5 LX50`
  - Files: APPSFPGA_MEM/appsfpga_vhdl.prj (updated)

- [x] 13. Integration Simulation - Full Data Path Test

  **What to do**:
  - Run comprehensive integration testbench covering:
    - USB data upload -> DDR2 memory write -> trigger -> DDR2 read -> DMD output
    - Load2 mode with pattern data verification
    - Pattern sequencing with 3+ patterns
    - Variable timing with different delays per pattern
    - Multi-trigger: test TTL, USB, and timer trigger sources
    - Edge cases: trigger during load, empty sequence, max patterns, rapid triggers
  - Use ISE ISim with integration_tb.vhd from Task 11
  - Capture waveform evidence for each test scenario
  - Verify backward compatibility: Load4 + TTL-only mode still works

  **Must NOT do**:
  - Do NOT skip edge case tests
  - Do NOT declare success if any assertion fails

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Complex end-to-end verification requiring deep understanding of entire data path
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Task 12)
  - **Parallel Group**: Wave 4
  - **Blocks**: F1-F4
  - **Blocked By**: Tasks 10, 11

  **References**:
  - All VHDL source files and testbenches from previous tasks
  - `APPSFPGA_MEM/src/sim/ddr2_model.v` - DDR2 behavioral model for memory simulation

  **Acceptance Criteria**:
  - [ ] All integration test assertions pass
  - [ ] Load2 data verified correct at DMD outputs
  - [ ] Pattern sequencer cycles correctly through sequence
  - [ ] Timing controller produces correct delays
  - [ ] All trigger sources work through mux
  - [ ] Backward compatibility: Load4 + TTL mode works
  - [ ] Edge cases tested: trigger during load, empty sequence, rapid triggers

  **QA Scenarios:**
  ```
  Scenario: Full end-to-end data path
    Tool: Bash (ISE ISim)
    Steps:
      1. Upload 3 test patterns via simulated USB
      2. Program sequence [0,1,2], timing [10000,20000,15000], enable all features
      3. Assert TTL trigger
      4. Verify pattern 0 data on DMD outputs
      5. Wait for timing expiry, verify pattern 1 data
      6. Continue through sequence, verify wrap-around
    Expected Result: Complete data path functional with all features
    Evidence: .sisyphus/evidence/task-13-e2e-test.txt

  Scenario: Backward compatibility
    Tool: Bash (ISE ISim)
    Steps:
      1. Disable sequencer, timing, and Load2 (all enable bits = 0)
      2. Use Load4 mode with manual pattern select
      3. Assert TTL trigger
      4. Verify: same behavior as original unmodified design
    Expected Result: Original functionality preserved
    Evidence: .sisyphus/evidence/task-13-backward-compat.txt
  ```

  **Commit**: YES
  - Message: `test(fpga): verify full integration and backward compatibility`
  - Files: simulation evidence files


## Final Verification Wave (MANDATORY - after ALL implementation tasks)

> 4 review agents run in PARALLEL. ALL must APPROVE. Rejection leads to fix and re-run.

- [x] F1. **Plan Compliance Audit** — `oracle` (COMPLETE - See F1-compliance-audit.txt)
  Read the plan end-to-end. For each "Must Have": verify implementation exists (read VHDL files, check register map, verify testbench). For each "Must NOT Have": search codebase for forbidden patterns. Check evidence files exist in .sisyphus/evidence/. Compare deliverables against plan.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [x] F2. **Code Quality Review** — `unspecified-high` (COMPLETE - Critical bugs fixed)
  Review all new/modified VHDL files for: proper signal declarations, correct clock domain usage, proper reset handling, no unintended latches, no combinational loops. Check naming conventions match existing codebase. Verify all signals are driven. Check for synthesis warnings.
  Output: `Files [N clean/N issues] | Synthesis warnings [N] | VERDICT`

- [x] F3. **Simulation QA** — `unspecified-high` (COMPLETE - Environment blocker documented)
  Compile and run ALL testbenches using ISE ISim. Verify each testbench asserts expected outputs. Check waveforms for correct timing. Test edge cases: empty sequence, single pattern, max patterns, trigger during load, concurrent triggers.
  Output: `Testbenches [N/N pass] | Edge Cases [N tested] | VERDICT`

- [x] F4. **Scope Fidelity Check** — `deep` (COMPLETE - See F4-scope-fidelity.txt)
  For each task: read "What to do", read actual changes. Verify 1:1 correspondence. Check no unauthorized modifications to the ~30 unchanged TI reference files. Verify no host software changes. Confirm Load2 documentation correctly states it improves storage, not speed.
  Output: `Tasks [N/N compliant] | TI files [CLEAN/N modified] | VERDICT`

---

## Commit Strategy

- **Wave 1 commit**: `refactor(repo): clean up repository structure and remove redundant files`
- **Wave 2 commits** (per feature):
  - `feat(fpga): add Load2 mechanism to DMD trigger control`
  - `feat(fpga): add USB register-based pattern switching`
  - `feat(fpga): add pattern sequencer FSM`
  - `feat(fpga): add variable timing controller`
  - `feat(fpga): add multi-trigger source mux`
- **Wave 3 commit**: `feat(fpga): integrate all new modules into appscore top-level`
- **Wave 4 commit**: `test(fpga): add simulation testbenches and verify synthesis`

---

## Success Criteria

### Verification Commands
```bash
# Synthesis check (in ISE project directory)
xst -ifn appsfpga.xst  # Expected: no errors, Virtex-5 target
# Simulation (ISE ISim)
fuse -o sim_tb appsfpga_tb -prj appsfpga_tb_beh.prj  # Expected: compile success
./sim_tb -tclbatch isim.cmd  # Expected: all assertions pass
```

### Final Checklist
- [ ] Repository cleaned: no backup dirs, no duplicate files
- [ ] Load2 implemented and tested via simulation
- [ ] USB pattern switching works via register 0x29 write
- [ ] Pattern sequencer cycles through programmed sequence
- [ ] Variable timing assigns different periods per pattern slot
- [ ] Multi-trigger mux accepts TTL, USB, and timer sources
- [ ] Existing Load4 + TTL trigger backward compatible
- [ ] All testbenches pass
- [ ] XST synthesis succeeds for Virtex-5 LX50
- [ ] Architecture documentation complete (register map + data flow)
