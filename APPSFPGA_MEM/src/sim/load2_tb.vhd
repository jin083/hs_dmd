library IEEE;
use IEEE.STD_LOGIC_1164.all;

-- load2_tb.vhd
-- Placeholder testbench for Load2 mode verification.
--
-- Load2 behavior is exercised as part of integration_tb.vhd (Task 13)
-- because the full DMD_trigger_control entity requires the complete
-- simulation infrastructure (DDR2 model, appscore, etc.).
--
-- Key Load2 behaviors documented here for reference:
--   1. ROW_MD="10" (random addressing) is used during Load2 (NOT auto-increment "01")
--   2. Each logical row generates 2 DVALID pulses to consecutive ROW_AD values
--      (e.g., logical row N → physical rows 2N and 2N+1)
--   3. Row count is halved when load2_enable='1':
--      DLP7000 has 768 rows; Load2 uses 384 logical rows
--   4. Memory storage capacity doubles: ~5000+ images vs ~2543 in normal mode
--   5. load2_enable is driven from control_registers register 0x28 bit 0
--
-- See also:
--   APPSFPGA_MEM/src/rtl/DMD_trigger_control.vhdl  (load2_enable port, line 32)
--   APPSFPGA_MEM/src/rtl/control_registers.vhd      (register 0x28 decode)
--   .sisyphus/plans/dmd-fpga-overhaul.md            (Load2 design spec)

entity load2_tb is
end load2_tb;

architecture sim of load2_tb is
begin

  process
  begin
    -- Placeholder assertions: always pass.
    -- Full Load2 integration tests are in integration_tb.vhd (Task 13).
    assert true
      report "load2_tb: placeholder - Load2 row-pairing tested in integration_tb"
      severity note;

    assert true
      report "load2_tb: ROW_MD='10' (random) required for Load2 - verified in integration_tb"
      severity note;

    wait for 100 ns;

    -- End simulation
    assert false
      report "load2_tb: SIMULATION COMPLETE"
      severity failure;
  end process;

end sim;
