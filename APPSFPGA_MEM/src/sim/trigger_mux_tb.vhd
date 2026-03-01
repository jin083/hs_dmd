library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

entity trigger_mux_tb is
end trigger_mux_tb;

architecture sim of trigger_mux_tb is

  -- Component declaration
  component trigger_mux is
    port(
      clk                : in  std_logic;
      reset              : in  std_logic;
      ttl_trigger_in     : in  std_logic;
      usb_trigger_in     : in  std_logic;
      timer_trigger_in   : in  std_logic;
      trigger_source_sel : in  std_logic_vector(1 downto 0);
      trigger_enable     : in  std_logic;
      reset_counter      : in  std_logic;
      trigger_out        : out std_logic;
      trigger_source_id  : out std_logic_vector(1 downto 0);
      trigger_count      : out std_logic_vector(15 downto 0)
    );
  end component;

  -- Test signals
  signal clk                : std_logic := '0';
  signal reset              : std_logic := '0';
  signal ttl_trigger_in     : std_logic := '0';
  signal usb_trigger_in     : std_logic := '0';
  signal timer_trigger_in   : std_logic := '0';
  signal trigger_source_sel : std_logic_vector(1 downto 0) := (others => '0');
  signal trigger_enable     : std_logic := '0';
  signal reset_counter      : std_logic := '0';
  signal trigger_out        : std_logic;
  signal trigger_source_id  : std_logic_vector(1 downto 0);
  signal trigger_count      : std_logic_vector(15 downto 0);

  -- Clock period: 200 MHz = 5 ns
  constant CLK_PERIOD : time := 5 ns;

begin

  -- Instantiate trigger_mux
  uut : trigger_mux
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
  begin
    -- Reset: active-low, assert for 20 ns
    reset <= '0';
    wait for 20 ns;
    reset <= '1';
    wait for 10 ns;

    -- Test 1: TTL trigger (sel="00", enable='1')
    trigger_source_sel <= "00";
    trigger_enable     <= '1';
    wait for 10 ns;

    ttl_trigger_in <= '1';
    wait for 2 * CLK_PERIOD;
    ttl_trigger_in <= '0';
    wait for 5 * CLK_PERIOD;
    assert trigger_out = '1' report "trigger_mux_tb: TTL trigger - trigger_out should be '1'" severity error;
    wait for 5 * CLK_PERIOD;

    -- Test 2: USB trigger (sel="01")
    trigger_source_sel <= "01";
    wait for 10 ns;

    usb_trigger_in <= '1';
    wait for CLK_PERIOD;
    usb_trigger_in <= '0';
    wait for 3 * CLK_PERIOD;
    assert trigger_out = '1' report "trigger_mux_tb: USB trigger - trigger_out should be '1'" severity error;
    assert trigger_source_id = "01" report "trigger_mux_tb: USB trigger - source_id should be '01'" severity error;
    wait for 5 * CLK_PERIOD;

    -- Test 3: Timer trigger (sel="10")
    trigger_source_sel <= "10";
    wait for 10 ns;

    timer_trigger_in <= '1';
    wait for CLK_PERIOD;
    timer_trigger_in <= '0';
    wait for 3 * CLK_PERIOD;
    assert trigger_out = '1' report "trigger_mux_tb: Timer trigger - trigger_out should be '1'" severity error;
    assert trigger_source_id = "10" report "trigger_mux_tb: Timer trigger - source_id should be '10'" severity error;
    wait for 5 * CLK_PERIOD;

    -- Test 4: Disabled (trigger_enable='0')
    trigger_source_sel <= "00";
    trigger_enable     <= '0';
    wait for 10 ns;

    ttl_trigger_in <= '1';
    wait for CLK_PERIOD;
    ttl_trigger_in <= '0';
    wait for 5 * CLK_PERIOD;
    assert trigger_out = '0' report "trigger_mux_tb: Disabled - trigger_out should be '0'" severity error;
    wait for 5 * CLK_PERIOD;

    -- Test 5: Counter (set sel="00", enable='1', pulse TTL trigger 3 times)
    trigger_enable <= '1';
    reset_counter  <= '0';
    wait for 10 ns;

    -- Pulse 1
    ttl_trigger_in <= '1';
    wait for CLK_PERIOD;
    ttl_trigger_in <= '0';
    wait for 5 * CLK_PERIOD;

    -- Pulse 2
    ttl_trigger_in <= '1';
    wait for CLK_PERIOD;
    ttl_trigger_in <= '0';
    wait for 5 * CLK_PERIOD;

    -- Pulse 3
    ttl_trigger_in <= '1';
    wait for CLK_PERIOD;
    ttl_trigger_in <= '0';
    wait for 5 * CLK_PERIOD;

    assert trigger_count = X"0003" report "trigger_mux_tb: Counter - trigger_count should be 3" severity error;
    wait for 5 * CLK_PERIOD;

    -- End simulation
    assert false report "trigger_mux_tb: SIMULATION COMPLETE" severity failure;
  end process;

end sim;
