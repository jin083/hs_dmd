library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

entity timing_controller_tb is
end timing_controller_tb;

architecture sim of timing_controller_tb is

  -- Component declaration
  component timing_controller is
    port(
      clk               : in  std_logic;
      reset             : in  std_logic;
      timing_enable     : in  std_logic;
      auto_trigger      : in  std_logic;
      timing_wr_addr    : in  std_logic_vector(13 downto 0);
      timing_wr_lo      : in  std_logic_vector(15 downto 0);
      timing_wr_hi      : in  std_logic_vector(15 downto 0);
      timing_wr_en      : in  std_logic;
      current_pattern   : in  std_logic_vector(13 downto 0);
      trigger_in        : in  std_logic;
      trigger_out       : out std_logic;
      timer_expired     : out std_logic;
      current_timer     : out std_logic_vector(31 downto 0)
    );
  end component;

  -- Test signals
  signal clk               : std_logic := '0';
  signal reset             : std_logic := '0';
  signal timing_enable     : std_logic := '0';
  signal auto_trigger      : std_logic := '0';
  signal timing_wr_addr    : std_logic_vector(13 downto 0) := (others => '0');
  signal timing_wr_lo      : std_logic_vector(15 downto 0) := (others => '0');
  signal timing_wr_hi      : std_logic_vector(15 downto 0) := (others => '0');
  signal timing_wr_en      : std_logic := '0';
  signal current_pattern   : std_logic_vector(13 downto 0) := (others => '0');
  signal trigger_in        : std_logic := '0';
  signal trigger_out       : std_logic;
  signal timer_expired     : std_logic;
  signal current_timer     : std_logic_vector(31 downto 0);

  -- Clock period: 200 MHz = 5 ns
  constant CLK_PERIOD : time := 5 ns;

begin

  -- Instantiate timing_controller
  uut : timing_controller
    port map(
      clk               => clk,
      reset             => reset,
      timing_enable     => timing_enable,
      auto_trigger      => auto_trigger,
      timing_wr_addr    => timing_wr_addr,
      timing_wr_lo      => timing_wr_lo,
      timing_wr_hi      => timing_wr_hi,
      timing_wr_en      => timing_wr_en,
      current_pattern   => current_pattern,
      trigger_in        => trigger_in,
      trigger_out       => trigger_out,
      timer_expired     => timer_expired,
      current_timer     => current_timer
    );

  -- Clock generation
  process
  begin
    clk <= '0';
    wait for CLK_PERIOD / 2;
    clk <= '1';
    wait for CLK_PERIOD / 2;
  end process;

  -- Test stimulus
  process
    variable cycle_count : integer;
  begin
    -- Reset: active-low, assert for 20 ns
    reset <= '0';
    wait for 20 ns;
    reset <= '1';
    wait for 10 ns;

    -- Test 1: Bypass mode (timing_enable='0')
    -- trigger_in should pass directly to trigger_out (combinational)
    timing_enable <= '0';
    wait for 10 ns;

    trigger_in <= '1';
    wait for CLK_PERIOD / 4;
    assert trigger_out = '1' report "timing_controller_tb: bypass mode - trigger_out should be '1' immediately" severity error;
    wait for CLK_PERIOD;

    trigger_in <= '0';
    wait for CLK_PERIOD / 4;
    assert trigger_out = '0' report "timing_controller_tb: bypass mode - trigger_out should be '0' after trigger_in falls" severity error;
    wait for 5 * CLK_PERIOD;

    -- Test 2: Timed mode
    -- Program timing entry: addr=0, lo=0x0032 (50 decimal), hi=0x0000
    -- Note: MIN_TIMER is 4000 cycles (0x00000FA0), so actual timer will be 4000
    timing_enable <= '1';
    wait for 10 ns;

    -- Write timing entry
    timing_wr_addr <= "00000000000000";  -- addr = 0
    timing_wr_lo   <= X"0032";            -- lo = 50 (will be clamped to MIN=4000)
    timing_wr_hi   <= X"0000";            -- hi = 0
    timing_wr_en   <= '1';
    wait for CLK_PERIOD;
    timing_wr_en   <= '0';
    wait for 10 ns;

    -- Set current_pattern to 0 (to select the timing entry we just wrote)
    current_pattern <= "00000000000000";
    wait for 10 ns;

    -- Pulse trigger_in
    trigger_in <= '1';
    wait for CLK_PERIOD;
    trigger_in <= '0';

    -- In timed mode, trigger_out should NOT be '1' immediately
    wait for CLK_PERIOD / 4;
    assert trigger_out = '0' report "timing_controller_tb: timed mode - trigger_out should NOT be '1' immediately" severity error;

    -- Wait for timer to expire (MIN_TIMER = 4000 cycles = 20 us)
    -- We'll wait 5000 cycles to be safe
    cycle_count := 0;
    while cycle_count < 5000 loop
      wait for CLK_PERIOD;
      cycle_count := cycle_count + 1;
    end loop;

    -- After 5000 cycles, trigger_out should have been asserted at some point
    -- (timer_expired should pulse for 1 cycle when countdown hits 0)
    assert trigger_out = '1' or timer_expired = '1'
      report "timing_controller_tb: timed mode - trigger_out or timer_expired should be '1' after 5000 cycles"
      severity error;

    wait for 5 * CLK_PERIOD;

    -- End simulation
    assert false report "timing_controller_tb: SIMULATION COMPLETE" severity failure;
  end process;

end sim;
