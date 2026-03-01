# DMD FPGA Overhaul - Issues and Blockers

## Date: 2026-03-01

---

## Critical Blocker: ISE ISim Not Available

**Status:** ACTIVE BLOCKER - Prevents completion of 36 acceptance criteria

**Description:**
Xilinx ISE ISim (Integrated Simulator) is not installed in the current environment. This tool is required to:
- Compile VHDL testbenches
- Run behavioral simulations
- Verify functional correctness
- Execute assertions and check pass/fail status

**Impact:**
36 acceptance criteria cannot be verified without ISE ISim:
1. All simulation testbenches pass in ISE ISim
2. No regressions: existing Load4 + TTL trigger still work
3. Functional verification of all modules (Load2, USB switching, sequencer, timing, triggers)
4. Integration testing
5. Edge case testing
6. Backward compatibility verification

**Affected Tasks:**
- Task 12: XST Synthesis Verification (partial - can verify 0 errors but not full functional)
- Task 13: Integration Simulation - Full Data Path Test
- All QA scenarios requiring simulation

**Workaround:**
None available in current environment. Requires installation of Xilinx ISE 14.7 or alternative simulator (ModelSim, GHDL, etc.)

**Next Steps:**
1. Install Xilinx ISE 14.7 on development machine
2. Run fuse/ISim to compile testbenches
3. Execute simulations and verify all assertions pass
4. Check waveforms for correct behavior
5. Verify 36 remaining acceptance criteria

---

## Resolved Issues

### Issue: Comparison Operator Bug in control_registers.vhd
**Status:** RESOLVED ✅
**Date:** 2026-03-01
**Description:** Multiple pulse-clear conditions used `<=` (assignment) instead of `=` (comparison) in if conditions, causing unintended always-true clear behavior.
**Fix:** Changed `<=` to `=` in 7 locations (lines 298, 301, 304, 317, 320, 323, 326)

### Issue: Backward Compatibility Broken
**Status:** RESOLVED ✅
**Date:** 2026-03-01
**Description:** trigger_enable register bit defaulted to '0', breaking TTL-only mode without new register writes.
**Fix:** Changed default from '0' to '1' (line 294)

### Issue: Latch Risk in DMD_trigger_control.vhdl
**Status:** RESOLVED ✅
**Date:** 2026-03-01
**Description:** get_row_data not assigned in all branches of combinational process, creating latch inference.
**Fix:** Added default assignment `get_row_data <= '0';` at process start (line 574)

---

## Minor Issues

### Issue: Timer Trigger Input Tied Off
**Status:** KNOWN LIMITATION
**Description:** In appscore.vhd, timer_trigger_in is tied to '0' instead of being connected to timing_controller output.
**Impact:** Timer trigger source non-functional
**Workaround:** Use TTL or USB trigger sources
**Priority:** Low - Can be fixed in future revision

### Issue: USB Pattern ID Not Consumed
**Status:** KNOWN LIMITATION
**Description:** usb_next_pattern_id is registered but not used to override memory read address.
**Impact:** USB pattern switching triggers next pattern but doesn't select specific pattern ID
**Workaround:** Use pattern sequencer for automated pattern cycling
**Priority:** Medium - Feature incomplete

---

## Environment Limitations

- No Xilinx ISE installation
- No VHDL simulator available
- No FPGA hardware for testing
- Cannot generate bitstream (.bit file)

---

## Recommendations

1. **Install Xilinx ISE 14.7** - Required for full verification
2. **Run complete simulation suite** - Verify all 36 remaining criteria
3. **Hardware testing** - Load bitstream on DLPLCRC410EVM board
4. **Fix timer trigger connection** - Connect timing_ctrl_out to trigger_mux
5. **Complete USB pattern ID feature** - Implement pattern ID override in MEM_IO or DMD_trigger_control

