# Task 3: Simulation Infrastructure Setup - Learnings

## Completed
- Created `tb_common_pkg.vhd` (188 lines) with shared testbench utilities
- Created `run_all_tests.tcl` (167 lines) as ISim batch test runner
- Generated evidence file documenting creation and verification
- Committed: `test(fpga): add simulation infrastructure and common testbench utilities`

## VHDL Package Design (tb_common_pkg.vhd)

### Clock Constants
- CLK_USB_PERIOD: 20.833 ns (48 MHz)
- CLK_MEM_PERIOD: 6.667 ns (150 MHz)
- CLK_SYS_PERIOD: 5.0 ns (200 MHz)
- CLK_DMD_PERIOD: 2.5 ns (400 MHz)

### Procedures Implemented
1. **clk_gen**: Generates clock cycles for specified period and count
2. **gen_reset**: Generates active-low reset with configurable hold cycles
3. **usb_reg_write**: Simulates USB register write (addr, data, wr_en pulse)
4. **usb_reg_read**: Simulates USB register read (addr, rd_en pulse, captures result)
5. **assert_eq**: Assertion with message and hex value comparison
6. **wait_for_signal**: Waits for signal with timeout detection

### Style Conventions Matched
- VHDL entity/architecture separation pattern (from wiredly.vhd)
- Active-low reset convention (rst = '0' active)
- Procedure-based testbench utilities (common in ISE projects)
- Comprehensive header comments with clock domain documentation

## TCL Test Runner Design (run_all_tests.tcl)

### Features
- Batch execution of all testbenches
- Test result tracking (pass/fail/elapsed time)
- Summary report generation
- Configurable timeout and verbosity
- Placeholder comments for future testbenches (Task 11)

### Testbenches Listed
- appsfpga_tb: Top-level system integration
- trigger_dmd_control_tb: DMD trigger control FSM
- usb_io_tb: USB interface I/O
- mem_io_tb: Memory controller I/O

### Future Testbenches (Task 11)
- load2_tb: Load2 pattern sequencing
- pattern_sequencer_tb: Pattern sequencer FSM
- timing_controller_tb: Timing and synchronization
- trigger_mux_tb: Trigger multiplexer
- integration_tb: Full system integration

## Key Insights
1. Existing testbenches are Verilog (.v), but common utilities are VHDL (.vhd)
   - This is acceptable in mixed-language ISE projects
   - VHDL package provides reusable procedures for all testbenches
2. Clock periods must match actual hardware frequencies for realistic simulation
3. Active-low reset is standard in this project (rst = '0' active)
4. TCL runner provides framework for future test expansion without modification

## Verification
- Both files created successfully in APPSFPGA_MEM/src/sim/
- All procedures have complete implementations (not stubs)
- Evidence file documents creation with grep verification
- Commit message follows project conventions (test(fpga): ...)

# Task 4: Load2 mechanism in DMD_trigger_control.vhdl - Learnings

## FSM state locations (exact lines)
- State type declaration: `APPSFPGA_MEM/src/rtl/DMD_trigger_control.vhdl:135`
- `when S0 =>`: `APPSFPGA_MEM/src/rtl/DMD_trigger_control.vhdl:573`
- `when S1 =>`: `APPSFPGA_MEM/src/rtl/DMD_trigger_control.vhdl:604`
- `when LOAD2_ROW_A =>`: `APPSFPGA_MEM/src/rtl/DMD_trigger_control.vhdl:644`
- `when LOAD2_ROW_B =>`: `APPSFPGA_MEM/src/rtl/DMD_trigger_control.vhdl:672`

## Row addressing/data-valid signals used
- `dmd_rowmd` is driven in row control process at `APPSFPGA_MEM/src/rtl/DMD_trigger_control.vhdl:500`, `APPSFPGA_MEM/src/rtl/DMD_trigger_control.vhdl:503`
- `dmd_rowad` is driven for Load2 at `APPSFPGA_MEM/src/rtl/DMD_trigger_control.vhdl:501`, `APPSFPGA_MEM/src/rtl/DMD_trigger_control.vhdl:504`
- `dmd_dvalid` output is derived from `dmd_dvalid_1q` (`APPSFPGA_MEM/src/rtl/DMD_trigger_control.vhdl:330`), while FSM controls `dmd_dvalid_1` in `S1/LOAD2` states

## Counter behavior notes
- `data_in_count` is a modulo-8 fetch throttle counter (`APPSFPGA_MEM/src/rtl/DMD_trigger_control.vhdl:699-704`) that increments only when `get_row_data='1'`
- `cnts_row_pos_cnt` comes from `write_counter` and advances when `counter_en='1'`; end-of-frame is detected by wrap check `cnts_row_pos_cnt = 0` and delayed previous value `cnts_row_pos_cnt_q1 = active_row_count` (`APPSFPGA_MEM/src/rtl/DMD_trigger_control.vhdl:378`, `APPSFPGA_MEM/src/rtl/DMD_trigger_control.vhdl:645`, `APPSFPGA_MEM/src/rtl/DMD_trigger_control.vhdl:673`)
- Load2 uses `active_row_count` mux (`APPSFPGA_MEM/src/rtl/DMD_trigger_control.vhdl:307`) so row counter wraps at half row count in Load2 mode

## Gotchas discovered
- The requested grep pattern `ROW_MD.*10|"10".*ROW_MD` does not match this file because signal naming here is `dmd_rowmd` (lowercase, no underscore)
- To preserve legacy behavior, S0/S1 logic was left intact for `load2_enable='0'`; Load2 branches only when `load2_enable='1'`
- Build/parse verification for VHDL could not run in this environment because both `ghdl` and `xst` are unavailable

# Task 6: Pattern Sequencer FSM - Learnings

## Sequencer module patterns
- New module added at `APPSFPGA_MEM/src/rtl/pattern_sequencer.vhd` using project-consistent style (`STD_LOGIC_1164`, `STD_LOGIC_ARITH`, `STD_LOGIC_UNSIGNED`).
- FSM split into three processes to match local convention:
  1. synchronous state/datapath register process
  2. combinational next-state process
  3. combinational output process
- State declaration style followed the existing `DMD_trigger_control.vhdl` pattern (`type ... is (...)` with `current_state` / `next_state`).

## Functional notes
- Trigger edge handling is required for deterministic stepping: registered `trigger_in_d_q` with `trigger_rise <= trigger_in and not trigger_in_d_q`.
- Sequence memory implemented as a signal array (2543 x 15 bits), suitable for BRAM inference in synthesis.
- `sequence_length` needs clamping guard logic:
  - zero length coerced to 1
  - lengths above 2543 clamped to 2543
- Sequence writes are accepted only when sequencer is not in RUNNING state, preventing active-cycle table mutation.

## Mode behavior captured
- Continuous mode: end-of-sequence transitions through WRAP to restore index 0.
- One-shot mode: end-of-sequence transitions to DONE and holds `sequence_done='1'`.
- Bypass mode (`seq_enable='0'`): `trigger_out` passes through and `pattern_id_out` is forced to 0.

## Verification constraints
- VHDL LSP diagnostics are unavailable in this environment (`.vhd` LSP not configured).
- No local VHDL toolchain found for compile/synth checks (`xst`, `ghdl`, `xvhdl` absent).

# Task 8: Multi-Trigger Source Mux - Learnings

## Completed
- Created `APPSFPGA_MEM/src/rtl/trigger_mux.vhd` (238 lines)
- Evidence at `.sisyphus/evidence/task-8-trigger-mux.txt`
- Committed: `feat(fpga): add multi-trigger source mux`

## Design Decisions

### Synchronizer chain count (3 FFs, not 2)
Three flip-flops total for TTL: ttl_sync_1, ttl_sync_2, ttl_sync_3.
- ttl_sync_1: raw capture of async input (ASYNC_REG)
- ttl_sync_2: first synchronizer stage (ASYNC_REG)  
- ttl_sync_3: delay register for edge detection only
Rising edge = ttl_sync_2 AND NOT ttl_sync_3

### ASYNC_REG attribute placement
Applied to ttl_sync_1 and ttl_sync_2 (the capture and first sync FFs).
NOT applied to ttl_sync_3 (it's in the stable synchronous domain already).
This matches Xilinx UG900 guidance for 2-stage metastability synchronizers.

### trigger_fired vs trigger_out
- trigger_fired: combinational result of arbitration AND enable (clean 1-cycle pulse from edge detectors)
- trigger_out: registered version of trigger_fired — 1 cycle of added latency, width preserved
- Counter increments on trigger_fired (same cycle as decision, 1 cycle before trigger_out asserts)

### USB/Timer: no synchronizer required
Both inputs stated to be already synchronous to system_clk in the design spec.
Only a previous-value register is needed for rising-edge detection.

### reset_counter behavior
reset_counter is checked inside the synchronous process (not asynchronous).
Effective immediately on next rising_edge(clk); no priority conflict with trigger_fired
because the counter reset takes priority over the increment (reset checked first in if-elsif).

## Signal Naming Conventions (confirmed)
- `_edge` suffix: combinational 1-cycle rising-edge pulse
- `_prev` suffix: one-cycle delayed register for edge detection
- `_active` suffix: gated/masked version after source selection applied
- `_reg` suffix: registered output signal
- `_next` suffix: next-state combinational signal

## Key Architecture Insight
The trigger_out pulse is clean because:
1. Edge detectors (for all 3 sources) guarantee exactly 1-cycle pulses
2. trigger_fired inherits this 1-cycle width
3. Registering trigger_fired to get trigger_out shifts the pulse by 1 cycle, but does NOT widen it
No additional pulse-shaping or one-shot circuit is required.

# Task 7: Variable Timing Controller - Learnings

## File Created
- `APPSFPGA_MEM/src/rtl/timing_controller.vhd` (194 lines)

## VHDL Array as BRAM
- `type timing_table_t is array(0 to 2542) of std_logic_vector(31 downto 0);`
- Xilinx Virtex-5 ISE synthesis automatically infers this as Block RAM
- No CoreGen / IP core needed for simple BRAM - pure VHDL works
- 2543 entries x 32 bits = 81,376 bits (~10 KB, well within Virtex-5 LX50 BRAM budget)

## Variable inside Process (VHDL synthesis)
- Declared before `begin` of process: `variable loaded_time : std_logic_vector(31 downto 0);`
- Used for intermediate calculation (min enforcement) without creating an extra signal
- ISE synthesizes this correctly - variable is not a register, just combinational temp in process

## Minimum Timer Constant
- `constant MIN_TIMER : std_logic_vector(31 downto 0) := X"00000FA0";`
- 4000 decimal = 0xFA0
- 4000 cycles x 5 ns (200 MHz) = 20 µs = 50 kHz maximum trigger rate (MCP hardware limit)
- Minimum enforced both at IDLE->COUNTING transition and in auto_trigger reload

## FSM Bypass Pattern
- timing_enable='0': concurrent assignment `trigger_out <= trigger_in` bypasses FSM completely
- FSM stays in IDLE state harmlessly when bypass active - no side effects
- Single concurrent statement handles both bypass and timed output:
  `trigger_out <= trigger_in when timing_enable = '0' else '1' when (current_state = FIRED) else '0';`

## auto_trigger Feature
- Implemented in FIRED state: if auto_trigger='1', reload timer from table and goto COUNTING
- Creates free-running periodic trigger without external trigger_in after first trigger
- Minimum enforcement applied on auto-reload too (consistent behavior)

## Timer Boundary (COUNTING state check)
- Check `timer_reg = X"00000000" or timer_reg = X"00000001"` before decrement
- Prevents 32-bit underflow edge case if timer somehow starts at 0 (defensive)
- With MIN_TIMER=4000 enforced, normal path always fires at timer_reg=1

## Register Write Protocol Note
- Two-step write: first timing_wr_lo (reg 0x31), then timing_wr_hi (reg 0x32)
- timing_wr_en asserted when reg 0x32 written: `timing_table(addr) <= hi & lo`
- Both low/high registers must be held stable when timing_wr_en pulses
- Host should write lo first, hi second to avoid partial writes

## Timing Analysis at 200 MHz
- IDLE state detects trigger_in: 1 cycle
- COUNTING from MIN_TIMER=4000 to fire at 1: 3999 cycles
- FIRED state (trigger_out='1'): 1 cycle
- Total latency from trigger_in to trigger_out: ~4001 cycles = ~20.005 µs minimum

# Task 5: USB Register-Based Pattern Switching - Learnings

## Files Modified
- `APPSFPGA_MEM/src/rtl/control_registers.vhd` (+20 lines: ports, signals, reg 0x29 case, auto-clear, outputs)
- `APPSFPGA_MEM/src/rtl/DMD_trigger_control.vhdl` (+13 lines: ports, sensitivity list, FSM elsif branch)

## Auto-Clear Pulse Mechanism (existing pattern, reused)
The existing codebase generates single-cycle pulses using a 1q (one-cycle delayed) queue signal:
1. On register write: `trigger_signal_1 <= data_bit` (sets high)
2. Queue process: `trigger_signal_1q <= trigger_signal_1` (delayed by 1 clk)
3. Auto-clear in write process: `if trigger_signal_1q = '1' then trigger_signal_1 <= '0'; end if;`
4. Since auto-clear appears BEFORE the write case in the process, the write assignment wins on write cycle
5. On the NEXT cycle: 1q goes high, auto-clear fires, sets signal back to '0'
Result: exactly 1-cycle pulse on the output (`trigger_signal_1` is high for one clock cycle)

## Register 0x29 Layout
- Bit 0: usb_switch_trigger (write 1 triggers, auto-clears next cycle)
- Bits [15:1]: usb_next_pattern_id (15-bit pattern ID, 0-32767)
- No separate read-back needed (action register, not status)

## FSM Priority Encoding (elsif ordering)
TTL trigger vs USB switch priority is implemented by `if ... elsif ...` ordering in S0:
- `if trigger = '1' ...`       ← TTL first (highest priority)
- `elsif usb_switch_request = '1' ...` ← USB second (lower priority)
- `else next_state <= S0;`     ← stay idle
This is the correct VHDL approach; no arbitration logic needed.

## Sensitivity List (combinational process)
When adding a new condition to the FSM next-state process (combinational), always add the signal
to the process sensitivity list. Missing it causes incorrect simulation behavior (incomplete sensitivity).
The sensitivity list is on line 572 of DMD_trigger_control.vhdl.

## Port Naming Convention (between modules)
The same physical connection has different names in each module:
- `usb_switch_trigger` in control_registers.vhd (the source)
- `usb_switch_request` in DMD_trigger_control.vhdl (the sink)
These are connected via appscore.vhd (Task 10). The asymmetric naming is intentional:
the source names what it outputs; the sink names what it receives.

## usb_pattern_id Port (placeholder for Task 10)
`usb_pattern_id` is added as an input port to DMD_trigger_control.vhdl but not yet used in FSM logic.
It will be wired through appscore.vhd in Task 10 and used to tell MEM_IO which pattern address to fetch.
Unused VHDL input ports are legal and generate no synthesis errors.

## Code Reuse Insight
The existing `rd_pattern_id` is an INPUT from MEM_IO (tells trigger_control what pattern is loaded).
There is no existing mechanism inside DMD_trigger_control to output a desired pattern ID to MEM_IO.
That routing will be added in a future task (Task 10: appscore wiring).

## Existing Bug Note
Lines 202-210 in control_registers.vhd use `<=` (less-than-or-equal) instead of `=` for std_logic comparisons:
`if fifo_reset_1q <= '1' then` — this always evaluates true for std_logic values '0' and '1'.
This is a pre-existing quirk (not introduced by Task 5). Our new auto-clear uses `= '1'` (correct).
