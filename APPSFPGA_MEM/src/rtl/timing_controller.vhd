library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

---- Uncomment the following library declaration if instantiating
---- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;

-- timing_controller.vhd
-- Per-pattern variable timing controller for DLPLCRC410EVM / DLP7000 system.
-- At 200 MHz (5 ns/cycle):
--   Minimum enforced: 4000 cycles = 20 us  (50 kHz MCP rate hard limit)
--   Maximum possible: 2^32-1 cycles ~= 21.5 seconds
-- Clock domain: clk (200 MHz system clock, same as appscore / control_registers)
-- Reset: active-low (reset='0' asserts reset, matching project convention)
--
-- Operation:
--   timing_enable='0' -> bypass: trigger_in passes directly to trigger_out (transparent)
--   timing_enable='1' -> timed: trigger_in starts per-pattern countdown;
--                               trigger_out pulses for 1 cycle on expiry
--   auto_trigger='1'  -> after expiry, automatically reload and restart (free-running)
--
-- Timing table write protocol (host PC via USB registers):
--   1. Write reg 0x30 = address (timing_wr_addr)
--   2. Write reg 0x31 = low 16 bits (timing_wr_lo)
--   3. Write reg 0x32 = high 16 bits (timing_wr_hi) and assert timing_wr_en
-- Result: timing_table(addr) <= {timing_wr_hi, timing_wr_lo}
-- Synthesis: 2543-entry x 32-bit array inferred as Xilinx Block RAM (no CoreGen needed)

entity timing_controller is
    port(
        clk               : in  std_logic;                       -- 200 MHz system clock
        reset             : in  std_logic;                       -- active-low reset (0=reset)

        -- Timing control (driven from control_registers 0x2F-0x32)
        timing_enable     : in  std_logic;                       -- enable timed mode (reg 0x2F bit 0)
        auto_trigger      : in  std_logic;                       -- auto-reload on expiry (reg 0x2F bit 1)
        timing_wr_addr    : in  std_logic_vector(13 downto 0);  -- table write address (reg 0x30)
        timing_wr_lo      : in  std_logic_vector(15 downto 0);  -- timing value bits[15:0] (reg 0x31)
        timing_wr_hi      : in  std_logic_vector(15 downto 0);  -- timing value bits[31:16] (reg 0x32)
        timing_wr_en      : in  std_logic;                       -- write strobe (pulse after hi written)

        -- Pattern index (driven by pattern sequencer)
        current_pattern   : in  std_logic_vector(13 downto 0);  -- selects which timer to load

        -- Trigger interface
        trigger_in        : in  std_logic;                       -- incoming trigger (from trigger_mux)

        -- Outputs
        trigger_out       : out std_logic;                       -- to DMD_trigger_control or next stage
        timer_expired     : out std_logic;                       -- '1' for 1 cycle when countdown hits 0
        current_timer     : out std_logic_vector(31 downto 0)   -- countdown value for debug/monitoring
    );
end timing_controller;

architecture Behavioral of timing_controller is

    -- Timing table: 2543 entries (max XGA frame count) x 32-bit duration
    -- Xilinx ISE synthesis infers this as Block RAM on Virtex-5 LX50
    type timing_table_t is array(0 to 2542) of std_logic_vector(31 downto 0);
    signal timing_table     : timing_table_t;

    -- FSM state encoding
    type state_type is (IDLE, COUNTING, FIRED);
    signal current_state    : state_type;

    -- 32-bit countdown register
    signal timer_reg        : std_logic_vector(31 downto 0);

    -- Minimum timer value: 4000 cycles x 5 ns = 20 us (50 kHz MCP hard limit)
    -- 4000 decimal = 0x00000FA0
    constant MIN_TIMER      : std_logic_vector(31 downto 0) := X"00000FA0";

    -- Internal one-cycle expired pulse (registered to avoid combinational loop)
    signal timer_expired_i  : std_logic;

begin

    -- -------------------------------------------------------------------------
    -- Timing table write process
    -- Synchronous write; host supplies {timing_wr_hi, timing_wr_lo} at timing_wr_addr
    -- timing_wr_en must be a single-cycle pulse (asserted when reg 0x32 is written)
    -- -------------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if timing_wr_en = '1' then
                timing_table(conv_integer(timing_wr_addr)) <= timing_wr_hi & timing_wr_lo;
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    -- Main FSM + timer countdown process
    -- Active-low reset convention (reset='0' is asserted)
    -- -------------------------------------------------------------------------
    process(clk)
        -- Temporary variable for minimum-enforcement: avoids double table lookup
        variable loaded_time : std_logic_vector(31 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '0' then
                -- Synchronous reset: return to IDLE, clear all state
                current_state   <= IDLE;
                timer_reg       <= (others => '0');
                timer_expired_i <= '0';
            else
                -- Default: deassert expired each cycle (only pulses for 1 cycle)
                timer_expired_i <= '0';

                case current_state is

                    -- ---------------------------------------------------------
                    -- IDLE: wait for trigger_in (only when timing_enable='1')
                    -- Bypass case (timing_enable='0') is handled in concurrent
                    -- trigger_out assignment below; FSM stays in IDLE harmlessly.
                    -- ---------------------------------------------------------
                    when IDLE =>
                        timer_reg <= (others => '0');

                        if trigger_in = '1' and timing_enable = '1' then
                            -- Load timer from table with minimum enforcement
                            -- 4000 cycles (20 us) is the 50 kHz MCP rate hard limit
                            loaded_time := timing_table(conv_integer(current_pattern));
                            if loaded_time < MIN_TIMER then
                                timer_reg <= MIN_TIMER;
                            else
                                timer_reg <= loaded_time;
                            end if;
                            current_state <= COUNTING;
                        end if;

                    -- ---------------------------------------------------------
                    -- COUNTING: decrement each cycle; fire when timer <= 1
                    -- Checking both 0 and 1 prevents underflow edge case
                    -- ---------------------------------------------------------
                    when COUNTING =>
                        if timer_reg = X"00000000" or timer_reg = X"00000001" then
                            -- Timer expired: assert flag for 1 cycle, move to FIRED
                            timer_expired_i <= '1';
                            timer_reg       <= (others => '0');
                            current_state   <= FIRED;
                        else
                            timer_reg <= timer_reg - 1;
                        end if;

                    -- ---------------------------------------------------------
                    -- FIRED: trigger_out='1' for exactly this 1 clock cycle
                    -- (driven by concurrent assignment below; state itself just
                    -- routes to next state)
                    -- ---------------------------------------------------------
                    when FIRED =>
                        if auto_trigger = '1' then
                            -- Auto-reload: restart timer without waiting for trigger_in
                            -- Useful for free-running periodic pattern display
                            loaded_time := timing_table(conv_integer(current_pattern));
                            if loaded_time < MIN_TIMER then
                                timer_reg <= MIN_TIMER;
                            else
                                timer_reg <= loaded_time;
                            end if;
                            current_state <= COUNTING;
                        else
                            -- Return to IDLE; wait for next trigger_in
                            current_state <= IDLE;
                        end if;

                    when others =>
                        current_state <= IDLE;

                end case;
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    -- Trigger output mux (concurrent / combinational)
    --   timing_enable='0': bypass - trigger_in passes directly (transparent)
    --   timing_enable='1': trigger_out pulses for exactly 1 cycle in FIRED state
    -- MUST NOT create combinational loop; trigger_out depends only on registered
    -- current_state and timing_enable input.
    -- -------------------------------------------------------------------------
    trigger_out <= trigger_in when timing_enable = '0' else
                   '1' when (current_state = FIRED) else '0';

    -- -------------------------------------------------------------------------
    -- Status outputs (registered internals driven directly to ports)
    -- -------------------------------------------------------------------------
    timer_expired <= timer_expired_i;
    current_timer <= timer_reg;

end Behavioral;
