library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

-- trigger_mux_tb.vhd
-- Self-checking testbench for trigger_mux.vhd
--
-- Trigger path delays (200 MHz clock, 5 ns/cycle):
--   TTL path:   3 cycles from assertion to trigger_out
--               (sync_1 at cycle 1, sync_2+ttl_edge at cycle 2, trigger_out_reg at cycle 3)
--   USB path:   1 cycle from assertion to trigger_out
--               (usb_edge combinational, trigger_out_reg at cycle 1)
--   Timer path: 1 cycle from assertion to trigger_out (same as USB)
--
-- CRITICAL: trigger_out is exactly 1 clock cycle wide.
-- Use "wait until trigger_out = '1'" to capture it, NOT a fixed wait.
--
-- Priority (sel="11"): TTL > USB > Timer
-- Priority test: TTL asserted at cycle 0, USB asserted at cycle 2 (same cycle
-- ttl_edge fires through sync chain). Both fire simultaneously; TTL wins.
--
-- trigger_count increments on trigger_fired (1 cycle before trigger_out).
-- Reset trigger_count between tests using reset_counter='1'.
--
-- Clock: 200 MHz (5 ns period)
-- Reset: active-low (reset='0' asserts reset)

entity trigger_mux_tb is
end trigger_mux_tb;

architecture sim of trigger_mux_tb is

  constant CLK_PERIOD : time := 5 ns;  -- 200 MHz

  signal clk                : std_logic := '0';
  signal reset              : std_logic := '0';
  signal ttl_trigger_in     : std_logic := '0';
  signal usb_trigger_in     : std_logic := '0';
  signal timer_trigger_in   : std_logic := '0';
  signal trigger_source_sel : std_logic_vector(1 downto 0) := "00";
  signal trigger_enable     : std_logic := '0';
  signal reset_counter      : std_logic := '0';
  signal trigger_out        : std_logic;
  signal trigger_source_id  : std_logic_vector(1 downto 0);
  signal trigger_count      : std_logic_vector(15 downto 0);

begin

  -- 200 MHz clock generation
  clk <= not clk after CLK_PERIOD / 2;

  -- Device Under Test (entity instantiation - all ports connected)
  DUT: entity work.trigger_mux
    port map(
      clk                => clk,
      reset              => reset,
      ttl_trigger_in     => ttl_trigger_in,
      usb_trigger_in     => usb_trigger_in,
      timer_trigger_in   => timer_trigger_in,
      trigger_source_sel => trigger_source_sel,
      trigger_enable     => trigger_enable,
      reset_counter      => reset_counter,
      trigger_out        => trigger_out,
      trigger_source_id  => trigger_source_id,
      trigger_count      => trigger_count
    );

  process
  begin

    ---------------------------------------------------------------------------
    -- Apply active-low reset for 10 clock cycles
    ---------------------------------------------------------------------------
    reset <= '0';
    wait for 10 * CLK_PERIOD;
    reset <= '1';
    wait for 5 * CLK_PERIOD;

    ---------------------------------------------------------------------------
    -- Test 1: TTL trigger (sel="00")
    -- TTL path: 3-FF synchronizer + 1 output register = 3 cycles total
    --   Cycle 0: ttl_trigger_in=1
    --   Cycle 1 edge: sync_1=1
    --   Cycle 2 edge: sync_2=1, sync_3=0, ttl_edge=1, trigger_fired=1
    --   Cycle 3 edge: trigger_out_reg=1 -> trigger_out='1'
    -- Use "wait until trigger_out='1'" to capture the 1-cycle pulse.
    ---------------------------------------------------------------------------
    trigger_source_sel <= "00";
    trigger_enable     <= '1';

    wait until rising_edge(clk);   -- cycle 0: assert TTL for 1 cycle
    ttl_trigger_in <= '1';
    wait until rising_edge(clk);   -- cycle 1: sync_1 captures 1
    ttl_trigger_in <= '0';

    -- Wait for trigger_out to fire (expected at cycle 3, timeout = 8 cycles)
    wait until trigger_out = '1' for 8 * CLK_PERIOD;

    assert trigger_out = '1'
      report "FAIL Test1a: TTL trigger - trigger_out did not fire within 8 cycles"
      severity error;
    assert trigger_source_id = "00"
      report "FAIL Test1b: TTL trigger - trigger_source_id should be '00'"
      severity error;

    -- Verify trigger_out is exactly 1 cycle wide
    wait until rising_edge(clk);
    wait for CLK_PERIOD / 4;
    assert trigger_out = '0'
      report "FAIL Test1c: TTL trigger - trigger_out should be 1-cycle wide"
      severity error;

    wait for 5 * CLK_PERIOD;

    ---------------------------------------------------------------------------
    -- Test 2: USB trigger (sel="01")
    -- USB path: 1 output register = 1 cycle from assertion to trigger_out
    --   Cycle 0: usb_trigger_in=1, usb_prev=0, usb_edge=1, trigger_fired=1
    --   Cycle 1 edge: trigger_out_reg=1 -> trigger_out='1'
    ---------------------------------------------------------------------------
    trigger_source_sel <= "01";
    reset_counter      <= '1';  -- reset counter between tests
    wait until rising_edge(clk);
    reset_counter      <= '0';

    wait until rising_edge(clk);   -- assert USB for 1 cycle
    usb_trigger_in <= '1';
    wait until rising_edge(clk);   -- trigger_out_reg captures trigger_fired=1
    usb_trigger_in <= '0';
    wait for CLK_PERIOD / 4;       -- settle combinational output

    assert trigger_out = '1'
      report "FAIL Test2a: USB trigger - trigger_out should be '1' after 1 clock cycle"
      severity error;
    assert trigger_source_id = "01"
      report "FAIL Test2b: USB trigger - trigger_source_id should be '01'"
      severity error;

    -- Verify 1-cycle width
    wait until rising_edge(clk);
    wait for CLK_PERIOD / 4;
    assert trigger_out = '0'
      report "FAIL Test2c: USB trigger - trigger_out should be 1-cycle wide"
      severity error;

    wait for 5 * CLK_PERIOD;

    ---------------------------------------------------------------------------
    -- Test 3: Timer trigger (sel="10")
    -- Timer path: same delay as USB (1 cycle)
    ---------------------------------------------------------------------------
    trigger_source_sel <= "10";
    reset_counter      <= '1';
    wait until rising_edge(clk);
    reset_counter      <= '0';

    wait until rising_edge(clk);
    timer_trigger_in <= '1';
    wait until rising_edge(clk);
    timer_trigger_in <= '0';
    wait for CLK_PERIOD / 4;

    assert trigger_out = '1'
      report "FAIL Test3a: Timer trigger - trigger_out should be '1'"
      severity error;
    assert trigger_source_id = "10"
      report "FAIL Test3b: Timer trigger - trigger_source_id should be '10'"
      severity error;

    wait until rising_edge(clk);
    wait for CLK_PERIOD / 4;
    assert trigger_out = '0'
      report "FAIL Test3c: Timer trigger - trigger_out should be 1-cycle wide"
      severity error;

    wait for 5 * CLK_PERIOD;

    ---------------------------------------------------------------------------
    -- Test 4: Any source mode (sel="11") - TTL fires
    -- With sel="11", any source can trigger. TTL fires with source_id="00".
    ---------------------------------------------------------------------------
    trigger_source_sel <= "11";
    reset_counter      <= '1';
    wait until rising_edge(clk);
    reset_counter      <= '0';

    wait until rising_edge(clk);
    ttl_trigger_in <= '1';
    wait until rising_edge(clk);
    ttl_trigger_in <= '0';

    wait until trigger_out = '1' for 8 * CLK_PERIOD;

    assert trigger_out = '1'
      report "FAIL Test4a: Any source - TTL trigger_out should fire with sel='11'"
      severity error;
    assert trigger_source_id = "00"
      report "FAIL Test4b: Any source - TTL source_id should be '00'"
      severity error;

    wait for 5 * CLK_PERIOD;

    ---------------------------------------------------------------------------
    -- Test 5: Priority arbitration (sel="11") - TTL wins over USB
    --
    -- Setup: Assert TTL at cycle 0, release at cycle 1.
    --   Cycle 1 edge: sync_1=1 (TTL captured)
    --   Cycle 2 edge: sync_2=1, ttl_edge fires (combinational)
    -- At cycle 2 (after rising edge), also assert USB:
    --   usb_prev=0 (captured 0 at cycle 2 edge), usb_trigger_in=1 -> usb_edge=1
    -- Both ttl_edge=1 and usb_edge=1 simultaneously -> TTL wins (priority)
    -- trigger_source_id_next = "00" (TTL)
    -- Cycle 3 edge: trigger_out_reg=1, trigger_source_id_reg="00"
    ---------------------------------------------------------------------------
    trigger_source_sel <= "11";
    reset_counter      <= '1';
    wait until rising_edge(clk);
    reset_counter      <= '0';

    wait until rising_edge(clk);   -- cycle 0: assert TTL for 1 cycle
    ttl_trigger_in <= '1';
    wait until rising_edge(clk);   -- cycle 1: sync_1=1, release TTL
    ttl_trigger_in <= '0';
    wait until rising_edge(clk);   -- cycle 2: sync_2=1, ttl_edge fires
    usb_trigger_in <= '1';         -- USB asserted same cycle ttl_edge fires
    wait until rising_edge(clk);   -- cycle 3: trigger_out_reg registered
    usb_trigger_in <= '0';
    wait for CLK_PERIOD / 4;       -- settle

    assert trigger_out = '1'
      report "FAIL Test5a: Priority - trigger_out should be '1'"
      severity error;
    assert trigger_source_id = "00"
      report "FAIL Test5b: Priority - TTL should win over USB (source_id='00')"
      severity error;

    wait for 5 * CLK_PERIOD;

    ---------------------------------------------------------------------------
    -- Test 6: Disabled trigger (trigger_enable='0')
    -- Even with TTL asserted, trigger_out must remain '0'.
    -- trigger_fired = any_trigger AND trigger_enable = 0 when trigger_enable='0'
    ---------------------------------------------------------------------------
    trigger_enable     <= '0';
    trigger_source_sel <= "00";

    wait until rising_edge(clk);
    ttl_trigger_in <= '1';
    wait until rising_edge(clk);
    ttl_trigger_in <= '0';

    -- Wait enough cycles for TTL to propagate through sync chain
    wait for 6 * CLK_PERIOD;

    assert trigger_out = '0'
      report "FAIL Test6: Disabled trigger - trigger_out should be '0' when trigger_enable='0'"
      severity error;

    wait for 5 * CLK_PERIOD;

    ---------------------------------------------------------------------------
    -- Test 7: Trigger counter
    -- Pulse USB trigger 3 times, verify trigger_count = 3.
    -- USB chosen for simplicity (1-cycle delay, no sync chain).
    -- Reset counter before test to isolate from previous tests.
    -- trigger_count increments on trigger_fired (1 cycle before trigger_out).
    ---------------------------------------------------------------------------
    trigger_enable     <= '1';
    trigger_source_sel <= "01";  -- USB
    reset_counter      <= '1';
    wait until rising_edge(clk);
    reset_counter      <= '0';

    -- Verify counter starts at 0
    wait for CLK_PERIOD / 4;
    assert trigger_count = X"0000"
      report "FAIL Test7a: Counter - trigger_count should be 0 after reset"
      severity error;

    -- Pulse USB 3 times with gaps between pulses
    for i in 0 to 2 loop
      wait until rising_edge(clk);
      usb_trigger_in <= '1';
      wait until rising_edge(clk);
      usb_trigger_in <= '0';
      wait for 4 * CLK_PERIOD;  -- allow trigger to complete before next pulse
    end loop;

    -- trigger_count increments on trigger_fired (at the clock edge when usb_edge=1)
    -- After 3 pulses + settling, count should be 3
    wait for 3 * CLK_PERIOD;

    assert trigger_count = X"0003"
      report "FAIL Test7b: Counter - trigger_count should be 3 after 3 USB triggers"
      severity error;

    wait for 5 * CLK_PERIOD;

    ---------------------------------------------------------------------------
    -- All tests passed
    ---------------------------------------------------------------------------
    assert false
      report "trigger_mux_tb: SIMULATION COMPLETE"
      severity failure;

  end process;

end sim;
