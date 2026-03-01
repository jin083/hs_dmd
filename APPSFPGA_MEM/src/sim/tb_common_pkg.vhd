--*****************************************************************************
-- Testbench Common Package
--
-- Description: Shared utilities for FPGA simulation testbenches
--   - Clock generation procedures for all clock domains
--   - Reset generation
--   - USB register read/write simulation procedures
--   - Assertion and signal wait utilities
--
-- Clock Domains:
--   - ifclk: 48 MHz (USB interface)
--   - mem_clk0: 150 MHz (DDR2 memory)
--   - system_clk: 200 MHz (system logic)
--   - dmd_clk: 400 MHz (DMD output)
--*****************************************************************************

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package tb_common_pkg is

  -- Clock periods for all domains
  constant CLK_USB_PERIOD   : time := 20.833 ns;  -- 48 MHz
  constant CLK_MEM_PERIOD   : time := 6.667 ns;   -- 150 MHz
  constant CLK_SYS_PERIOD   : time := 5.0 ns;     -- 200 MHz
  constant CLK_DMD_PERIOD   : time := 2.5 ns;     -- 400 MHz

  -- Reset timing
  constant RESET_HOLD_CYCLES : integer := 10;     -- cycles to hold reset active

  -- USB simulation timing
  constant USB_SETUP_TIME   : time := 2.0 ns;
  constant USB_HOLD_TIME    : time := 2.0 ns;

  -- Procedures for clock generation
  procedure clk_gen(
    signal clk : inout std_logic;
    constant period : time;
    constant cycles : integer
  );

  -- Procedure for reset generation (active low)
  procedure gen_reset(
    signal rst : out std_logic;
    constant hold_cycles : integer;
    signal clk : in std_logic
  );

  -- USB register write simulation
  procedure usb_reg_write(
    signal ifclk : in std_logic;
    signal addr : out std_logic_vector(15 downto 0);
    signal data : out std_logic_vector(15 downto 0);
    signal wr_en : out std_logic;
    constant reg_addr : std_logic_vector(15 downto 0);
    constant reg_data : std_logic_vector(15 downto 0)
  );

  -- USB register read simulation
  procedure usb_reg_read(
    signal ifclk : in std_logic;
    signal addr : out std_logic_vector(15 downto 0);
    signal rd_en : out std_logic;
    signal data_in : in std_logic_vector(15 downto 0);
    variable result : out std_logic_vector(15 downto 0)
  );

  -- Assertion with message
  procedure assert_eq(
    constant actual : std_logic_vector;
    constant expected : std_logic_vector;
    constant msg : string
  );

  -- Wait for signal to reach expected value with timeout
  procedure wait_for_signal(
    signal sig : in std_logic;
    constant expected_val : std_logic;
    constant timeout_ns : integer;
    variable timed_out : out boolean
  );

end package tb_common_pkg;

package body tb_common_pkg is

  -- Clock generation: toggles clock for specified number of cycles
  procedure clk_gen(
    signal clk : inout std_logic;
    constant period : time;
    constant cycles : integer
  ) is
  begin
    for i in 0 to cycles - 1 loop
      clk <= '0';
      wait for period / 2;
      clk <= '1';
      wait for period / 2;
    end loop;
  end procedure clk_gen;

  -- Reset generation: holds reset active for specified cycles, then releases
  procedure gen_reset(
    signal rst : out std_logic;
    constant hold_cycles : integer;
    signal clk : in std_logic
  ) is
  begin
    rst <= '0';  -- Active low reset
    for i in 0 to hold_cycles - 1 loop
      wait until rising_edge(clk);
    end loop;
    rst <= '1';  -- Release reset
    wait until rising_edge(clk);
  end procedure gen_reset;

  -- USB register write: sets address and data, pulses write enable
  procedure usb_reg_write(
    signal ifclk : in std_logic;
    signal addr : out std_logic_vector(15 downto 0);
    signal data : out std_logic_vector(15 downto 0);
    signal wr_en : out std_logic;
    constant reg_addr : std_logic_vector(15 downto 0);
    constant reg_data : std_logic_vector(15 downto 0)
  ) is
  begin
    wait until rising_edge(ifclk);
    addr <= reg_addr;
    data <= reg_data;
    wr_en <= '1';
    wait until rising_edge(ifclk);
    wr_en <= '0';
    addr <= (others => '0');
    data <= (others => '0');
  end procedure usb_reg_write;

  -- USB register read: sets address, pulses read enable, captures result
  procedure usb_reg_read(
    signal ifclk : in std_logic;
    signal addr : out std_logic_vector(15 downto 0);
    signal rd_en : out std_logic;
    signal data_in : in std_logic_vector(15 downto 0);
    variable result : out std_logic_vector(15 downto 0)
  ) is
  begin
    wait until rising_edge(ifclk);
    addr <= addr;  -- Address already set by caller
    rd_en <= '1';
    wait until rising_edge(ifclk);
    result := data_in;
    rd_en <= '0';
    addr <= (others => '0');
  end procedure usb_reg_read;

  -- Assertion: compare actual vs expected, print message if mismatch
  procedure assert_eq(
    constant actual : std_logic_vector;
    constant expected : std_logic_vector;
    constant msg : string
  ) is
  begin
    if actual /= expected then
      report msg & " - Expected: " & to_string(expected) & 
              " Got: " & to_string(actual) severity ERROR;
    else
      report msg & " - PASS" severity NOTE;
    end if;
  end procedure assert_eq;

  -- Wait for signal: waits for signal to reach expected value or timeout
  procedure wait_for_signal(
    signal sig : in std_logic;
    constant expected_val : std_logic;
    constant timeout_ns : integer;
    variable timed_out : out boolean
  ) is
  begin
    timed_out := false;
    wait until sig = expected_val for timeout_ns * 1 ns;
    if sig /= expected_val then
      timed_out := true;
      report "Signal timeout: expected " & std_logic'image(expected_val) & 
              " within " & integer'image(timeout_ns) & " ns" severity WARNING;
    end if;
  end procedure wait_for_signal;

end package body tb_common_pkg;
