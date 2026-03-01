library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

-- pattern_sequencer_tb.vhd
-- Self-checking testbench for pattern_sequencer.vhd
--
-- CRITICAL BEHAVIORAL NOTE - "First Trigger Wasted":
--   The pattern_sequencer starts in IDLE state after reset.
--   The FIRST trigger_in rising edge transitions IDLE -> RUNNING and loads
--   table[0] into pattern_id_q, but trigger_out is NOT asserted (IDLE state
--   output logic has null case for trigger_out).
--   Only in RUNNING state does trigger_in pass through to trigger_out.
--
--   Trigger sequence for seq_len=3, table=[5,2,8]:
--     Trigger 1 (IDLE->RUNNING): trigger_out='0', loads table[0]=5
--     Trigger 2 (RUNNING):       trigger_out='1', pattern_id_out=5, loads table[1]=2
--     Trigger 3 (RUNNING->WRAP): trigger_out='1', pattern_id_out=2, loads table[2]=8
--     Trigger 4 (RUNNING):       trigger_out='1', pattern_id_out=8 (after wrap)
--
-- Clock: 200 MHz (5 ns period)
-- Reset: active-low (reset='0' asserts reset)

entity pattern_sequencer_tb is
end pattern_sequencer_tb;

architecture sim of pattern_sequencer_tb is

  constant CLK_PERIOD : time := 5 ns;  -- 200 MHz system clock

  signal clk             : std_logic := '0';
  signal reset           : std_logic := '0';
  signal seq_enable      : std_logic := '0';
  signal one_shot        : std_logic := '0';
  signal reset_index     : std_logic := '0';
  signal sequence_length : std_logic_vector(13 downto 0) := (others => '0');
  signal seq_wr_addr     : std_logic_vector(13 downto 0) := (others => '0');
  signal seq_wr_data     : std_logic_vector(14 downto 0) := (others => '0');
  signal seq_wr_en       : std_logic := '0';
  signal trigger_in      : std_logic := '0';
  signal pattern_id_out  : std_logic_vector(14 downto 0);
  signal trigger_out     : std_logic;
  signal sequence_done   : std_logic;
  signal current_index   : std_logic_vector(13 downto 0);
  signal seq_running     : std_logic;

begin

  -- 200 MHz clock generation
  clk <= not clk after CLK_PERIOD / 2;

  -- Device Under Test
  DUT: entity work.pattern_sequencer
    port map(
      clk             => clk,
      reset           => reset,
      seq_enable      => seq_enable,
      one_shot        => one_shot,
      reset_index     => reset_index,
      sequence_length => sequence_length,
      seq_wr_addr     => seq_wr_addr,
      seq_wr_data     => seq_wr_data,
      seq_wr_en       => seq_wr_en,
      trigger_in      => trigger_in,
      pattern_id_out  => pattern_id_out,
      trigger_out     => trigger_out,
      sequence_done   => sequence_done,
      current_index   => current_index,
      seq_running     => seq_running
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
    -- Test 1: Bypass mode (seq_enable='0')
    -- When seq_enable='0', trigger_in passes directly to trigger_out
    -- (combinational path in output logic, regardless of FSM state)
    ---------------------------------------------------------------------------
    seq_enable      <= '0';
    sequence_length <= "00000000000011";  -- 3 (not used in bypass)
    one_shot        <= '0';

    wait until rising_edge(clk);
    trigger_in <= '1';
    wait for CLK_PERIOD / 4;  -- allow combinational path to settle

    assert trigger_out = '1'
      report "FAIL Test1a: Bypass mode - trigger_out should be '1' when seq_enable='0' and trigger_in='1'"
      severity error;
    assert pattern_id_out = "000000000000000"
      report "FAIL Test1b: Bypass mode - pattern_id_out should be '0' when seq_enable='0'"
      severity error;

    wait until rising_edge(clk);
    trigger_in <= '0';
    wait for CLK_PERIOD / 4;

    assert trigger_out = '0'
      report "FAIL Test1c: Bypass mode - trigger_out should return to '0' after trigger_in falls"
      severity error;

    wait for 3 * CLK_PERIOD;

    ---------------------------------------------------------------------------
    -- Test 2: Program sequence table
    -- Write: addr 0 -> data 5, addr 1 -> data 2, addr 2 -> data 8
    -- seq_enable must be '0' during writes (write blocked in RUNNING state)
    ---------------------------------------------------------------------------
    seq_enable <= '0';

    -- Write entry 0: data = 5 = "000000000000101"
    wait until rising_edge(clk);
    seq_wr_addr <= "00000000000000";
    seq_wr_data <= "000000000000101";
    seq_wr_en   <= '1';
    wait until rising_edge(clk);
    seq_wr_en   <= '0';

    -- Write entry 1: data = 2 = "000000000000010"
    wait until rising_edge(clk);
    seq_wr_addr <= "00000000000001";
    seq_wr_data <= "000000000000010";
    seq_wr_en   <= '1';
    wait until rising_edge(clk);
    seq_wr_en   <= '0';

    -- Write entry 2: data = 8 = "000000000001000"
    wait until rising_edge(clk);
    seq_wr_addr <= "00000000000010";
    seq_wr_data <= "000000000001000";
    seq_wr_en   <= '1';
    wait until rising_edge(clk);
    seq_wr_en   <= '0';

    wait for 3 * CLK_PERIOD;

    ---------------------------------------------------------------------------
    -- Test 3: Continuous sequencing mode (one_shot='0', seq_len=3)
    --
    -- Trigger 1: "wasted" - IDLE -> RUNNING transition
    --   trigger_out must be '0' (IDLE state does not pass trigger_in)
    --   After clock edge: state=RUNNING, pattern_id_q=table[0]=5, index=1
    ---------------------------------------------------------------------------
    seq_enable      <= '1';
    sequence_length <= "00000000000011";  -- length = 3
    one_shot        <= '0';

    -- Trigger 1 (wasted - IDLE state)
    wait until rising_edge(clk);
    trigger_in <= '1';
    wait for CLK_PERIOD / 4;

    assert trigger_out = '0'
      report "FAIL Test3a: First trigger in IDLE - trigger_out must be '0' (IDLE does not pass trigger)"
      severity error;
    assert seq_running = '0'
      report "FAIL Test3b: First trigger in IDLE - seq_running should be '0' (still in IDLE)"
      severity error;

    wait until rising_edge(clk);  -- clock edge: state -> RUNNING, pattern_id_q=5, index=1
    trigger_in <= '0';

    -- Allow state transition to settle (now in RUNNING)
    wait for 2 * CLK_PERIOD;

    assert seq_running = '1'
      report "FAIL Test3c: After first trigger - seq_running should be '1' (now in RUNNING)"
      severity error;

    ---------------------------------------------------------------------------
    -- Trigger 2: first real output
    --   State = RUNNING -> trigger_out = trigger_in = '1'
    --   pattern_id_out = pattern_id_q = table[0] = 5
    --   After clock edge: pattern_id_q=table[1]=2, index=2
    ---------------------------------------------------------------------------
    wait until rising_edge(clk);
    trigger_in <= '1';
    wait for CLK_PERIOD / 4;

    assert trigger_out = '1'
      report "FAIL Test3d: Trigger 2 - trigger_out should be '1' (in RUNNING state)"
      severity error;
    assert pattern_id_out = "000000000000101"
      report "FAIL Test3e: Trigger 2 - pattern_id_out should be 5 (table[0])"
      severity error;

    wait until rising_edge(clk);  -- clock edge: pattern_id_q=2, index=2
    trigger_in <= '0';
    wait for 2 * CLK_PERIOD;

    ---------------------------------------------------------------------------
    -- Trigger 3: second real output, causes WRAP (continuous mode)
    --   State = RUNNING -> trigger_out = '1'
    --   pattern_id_out = pattern_id_q = table[1] = 2
    --   (2+1) >= 3 and one_shot=0 -> next_state = WRAP
    --   After clock edge: state=WRAP, pattern_id_q=table[2]=8, index=2
    ---------------------------------------------------------------------------
    wait until rising_edge(clk);
    trigger_in <= '1';
    wait for CLK_PERIOD / 4;

    assert trigger_out = '1'
      report "FAIL Test3f: Trigger 3 - trigger_out should be '1'"
      severity error;
    assert pattern_id_out = "000000000000010"
      report "FAIL Test3g: Trigger 3 - pattern_id_out should be 2 (table[1])"
      severity error;

    wait until rising_edge(clk);  -- clock edge: state=WRAP, pattern_id_q=8
    trigger_in <= '0';

    -- WRAP state lasts 1 clock cycle: index resets to 0, state -> RUNNING
    -- Wait 2 cycles to ensure WRAP completes and RUNNING is stable
    wait for 2 * CLK_PERIOD;

    ---------------------------------------------------------------------------
    -- Trigger 4: after wrap-around
    --   State = RUNNING (after WRAP), index=0
    --   pattern_id_out = pattern_id_q = table[2] = 8 (loaded before wrap)
    --   trigger_out = '1'
    ---------------------------------------------------------------------------
    wait until rising_edge(clk);
    trigger_in <= '1';
    wait for CLK_PERIOD / 4;

    assert trigger_out = '1'
      report "FAIL Test3h: Trigger 4 (after wrap) - trigger_out should be '1'"
      severity error;
    assert pattern_id_out = "000000000001000"
      report "FAIL Test3i: Trigger 4 - pattern_id_out should be 8 (table[2], loaded before wrap)"
      severity error;

    wait until rising_edge(clk);
    trigger_in <= '0';
    wait for 3 * CLK_PERIOD;

    ---------------------------------------------------------------------------
    -- Test 4: One-shot mode (one_shot='1', seq_len=3)
    -- Reset DUT and re-program table with same values
    -- Expected: 3 triggers total (1 wasted + 2 real), then sequence_done='1'
    ---------------------------------------------------------------------------
    reset <= '0';
    wait for 5 * CLK_PERIOD;
    reset <= '1';
    wait for 3 * CLK_PERIOD;

    -- Re-program table (seq_enable='0' after reset)
    wait until rising_edge(clk);
    seq_wr_addr <= "00000000000000";
    seq_wr_data <= "000000000000101";  -- 5
    seq_wr_en   <= '1';
    wait until rising_edge(clk);
    seq_wr_en   <= '0';

    wait until rising_edge(clk);
    seq_wr_addr <= "00000000000001";
    seq_wr_data <= "000000000000010";  -- 2
    seq_wr_en   <= '1';
    wait until rising_edge(clk);
    seq_wr_en   <= '0';

    wait until rising_edge(clk);
    seq_wr_addr <= "00000000000010";
    seq_wr_data <= "000000000001000";  -- 8
    seq_wr_en   <= '1';
    wait until rising_edge(clk);
    seq_wr_en   <= '0';

    wait for 2 * CLK_PERIOD;

    seq_enable      <= '1';
    one_shot        <= '1';
    sequence_length <= "00000000000011";  -- 3

    -- Trigger 1: wasted (IDLE -> RUNNING)
    wait until rising_edge(clk);
    trigger_in <= '1';
    wait until rising_edge(clk);
    trigger_in <= '0';
    wait for 2 * CLK_PERIOD;

    assert sequence_done = '0'
      report "FAIL Test4a: One-shot - sequence_done should be '0' after first (wasted) trigger"
      severity error;

    -- Trigger 2: first real output (RUNNING, index=1)
    wait until rising_edge(clk);
    trigger_in <= '1';
    wait for CLK_PERIOD / 4;

    assert trigger_out = '1'
      report "FAIL Test4b: One-shot trigger 2 - trigger_out should be '1'"
      severity error;
    assert pattern_id_out = "000000000000101"
      report "FAIL Test4c: One-shot trigger 2 - pattern_id_out should be 5 (table[0])"
      severity error;

    wait until rising_edge(clk);
    trigger_in <= '0';
    wait for 2 * CLK_PERIOD;

    assert sequence_done = '0'
      report "FAIL Test4d: One-shot - sequence_done should still be '0' after trigger 2"
      severity error;

    -- Trigger 3: second real output (RUNNING, index=2 -> DONE)
    -- (2+1) >= 3 and one_shot=1 -> next_state = DONE
    wait until rising_edge(clk);
    trigger_in <= '1';
    wait for CLK_PERIOD / 4;

    assert trigger_out = '1'
      report "FAIL Test4e: One-shot trigger 3 - trigger_out should be '1'"
      severity error;
    assert pattern_id_out = "000000000000010"
      report "FAIL Test4f: One-shot trigger 3 - pattern_id_out should be 2 (table[1])"
      severity error;

    wait until rising_edge(clk);  -- clock edge: state -> DONE, sequence_done_q=1
    trigger_in <= '0';

    -- After DONE state: sequence_done='1', seq_running='0'
    wait for 2 * CLK_PERIOD;

    assert sequence_done = '1'
      report "FAIL Test4g: One-shot - sequence_done should be '1' after sequence completes"
      severity error;
    assert seq_running = '0'
      report "FAIL Test4h: One-shot - seq_running should be '0' in DONE state"
      severity error;

    wait for 5 * CLK_PERIOD;

    ---------------------------------------------------------------------------
    -- All tests passed
    ---------------------------------------------------------------------------
    assert false
      report "pattern_sequencer_tb: SIMULATION COMPLETE"
      severity failure;

  end process;

end sim;
