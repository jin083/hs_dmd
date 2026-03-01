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
