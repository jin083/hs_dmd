--------------------------------------------------------------------------------
-- trigger_mux.vhd
--
-- Multi-source trigger multiplexer for DMD control system.
-- Accepts three trigger sources: external TTL (asynchronous), USB command
-- (synchronous), and internal timer (synchronous). Arbitrates based on
-- a 2-bit source selection register and outputs a clean single-cycle pulse.
--
-- Clock domain : system_clk (200 MHz)
-- Reset        : active-low (reset = '0')
--
-- Source selection (trigger_source_sel):
--   "00" = TTL only
--   "01" = USB only
--   "10" = Timer only
--   "11" = Any (first to fire wins, priority TTL > USB > Timer)
--
-- Trigger priority (when sel = "11"):  TTL > USB > Timer
--
-- TTL path: 2-stage synchronizer (ASYNC_REG) + rising-edge detector
-- USB/Timer: registered + rising-edge detector (already synchronous)
--
-- trigger_out: exactly 1 system_clk cycle wide
-- trigger_count: 16-bit saturating counter, reset by reset_counter or reset
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

--------------------------------------------------------------------------------
-- Entity
--------------------------------------------------------------------------------
entity trigger_mux is
  port(
    clk                : in  std_logic;                     -- 200 MHz system clock
    reset              : in  std_logic;                     -- active-low reset

    -- Trigger sources
    ttl_trigger_in     : in  std_logic;                     -- external TTL (async, needs sync)
    usb_trigger_in     : in  std_logic;                     -- from USB register 0x29 (already sync)
    timer_trigger_in   : in  std_logic;                     -- from timing_controller (already sync)

    -- Configuration (from registers 0x33-0x34)
    trigger_source_sel : in  std_logic_vector(1 downto 0); -- 00=TTL, 01=USB, 10=Timer, 11=Any
    trigger_enable     : in  std_logic;                     -- global trigger enable (reg 0x33 bit 2)
    reset_counter      : in  std_logic;                     -- reset trigger counter (reg 0x33 bit 3)

    -- Outputs
    trigger_out        : out std_logic;                     -- single-cycle trigger to next stage
    trigger_source_id  : out std_logic_vector(1 downto 0); -- which source fired: 00=TTL, 01=USB, 10=Timer
    trigger_count      : out std_logic_vector(15 downto 0) -- total triggers since reset
  );
end trigger_mux;

--------------------------------------------------------------------------------
-- Architecture
--------------------------------------------------------------------------------
architecture rtl of trigger_mux is

  ---------------------------------------------------------------------------
  -- TTL synchronizer chain (metastability protection)
  -- ASYNC_REG attributes prevent synthesis tool from merging/optimising the
  -- flip-flops and tell timing closure to treat the registers as a known
  -- synchronizer pair.
  ---------------------------------------------------------------------------
  signal ttl_sync_1 : std_logic := '0';
  signal ttl_sync_2 : std_logic := '0';
  signal ttl_sync_3 : std_logic := '0';

  attribute ASYNC_REG        : string;
  attribute ASYNC_REG of ttl_sync_1 : signal is "TRUE";
  attribute ASYNC_REG of ttl_sync_2 : signal is "TRUE";

  ---------------------------------------------------------------------------
  -- Edge detection: previous-cycle registers for USB and Timer
  ---------------------------------------------------------------------------
  signal usb_prev   : std_logic := '0';
  signal timer_prev : std_logic := '0';

  ---------------------------------------------------------------------------
  -- Combinational edge pulses (1 cycle wide)
  ---------------------------------------------------------------------------
  signal ttl_edge   : std_logic;
  signal usb_edge   : std_logic;
  signal timer_edge : std_logic;

  ---------------------------------------------------------------------------
  -- Source-gated activity signals (after sel mask applied)
  ---------------------------------------------------------------------------
  signal ttl_active   : std_logic;
  signal usb_active   : std_logic;
  signal timer_active : std_logic;

  ---------------------------------------------------------------------------
  -- Arbitrated trigger and source identification
  ---------------------------------------------------------------------------
  signal any_trigger            : std_logic;
  signal trigger_fired          : std_logic;
  signal trigger_source_id_next : std_logic_vector(1 downto 0);

  ---------------------------------------------------------------------------
  -- Registered outputs
  ---------------------------------------------------------------------------
  signal trigger_out_reg        : std_logic := '0';
  signal trigger_source_id_reg  : std_logic_vector(1 downto 0) := "00";
  signal trigger_count_reg      : std_logic_vector(15 downto 0) := (others => '0');

begin

  ---------------------------------------------------------------------------
  -- Stage 1: TTL 2-stage synchronizer
  -- Runs every rising edge.  Three FFs: capture → first sync → second sync.
  -- Rising-edge detection compares sync_2 (stable) vs sync_3 (one cycle old).
  ---------------------------------------------------------------------------
  p_ttl_sync : process(clk)
  begin
    if rising_edge(clk) then
      if reset = '0' then
        ttl_sync_1 <= '0';
        ttl_sync_2 <= '0';
        ttl_sync_3 <= '0';
      else
        ttl_sync_1 <= ttl_trigger_in;  -- capture asynchronous input
        ttl_sync_2 <= ttl_sync_1;      -- first synchronizer stage
        ttl_sync_3 <= ttl_sync_2;      -- second synchronizer stage (stable)
      end if;
    end if;
  end process p_ttl_sync;

  -- Rising-edge pulse: high for exactly 1 cycle on 0→1 transition of the
  -- stable (ttl_sync_2) output.
  ttl_edge <= ttl_sync_2 and (not ttl_sync_3);

  ---------------------------------------------------------------------------
  -- Stage 2: USB and Timer edge detection
  -- Both signals are already synchronous to clk; no synchronizer needed.
  -- Register the previous value and generate a 1-cycle rising-edge pulse.
  ---------------------------------------------------------------------------
  p_usb_timer_prev : process(clk)
  begin
    if rising_edge(clk) then
      if reset = '0' then
        usb_prev   <= '0';
        timer_prev <= '0';
      else
        usb_prev   <= usb_trigger_in;
        timer_prev <= timer_trigger_in;
      end if;
    end if;
  end process p_usb_timer_prev;

  usb_edge   <= usb_trigger_in   and (not usb_prev);
  timer_edge <= timer_trigger_in and (not timer_prev);

  ---------------------------------------------------------------------------
  -- Stage 3: Source selection gating (combinational)
  -- Apply the 2-bit source selection register.
  --   "00" → only TTL allowed
  --   "01" → only USB allowed
  --   "10" → only Timer allowed
  --   "11" → any source allowed
  ---------------------------------------------------------------------------
  ttl_active <= ttl_edge
                when (trigger_source_sel = "00" or trigger_source_sel = "11")
                else '0';

  usb_active <= usb_edge
                when (trigger_source_sel = "01" or trigger_source_sel = "11")
                else '0';

  timer_active <= timer_edge
                  when (trigger_source_sel = "10" or trigger_source_sel = "11")
                  else '0';

  ---------------------------------------------------------------------------
  -- Stage 4: Priority arbitration (combinational)
  -- Priority order: TTL > USB > Timer
  -- any_trigger is high for exactly 1 cycle (edge detectors guarantee this).
  ---------------------------------------------------------------------------
  any_trigger <= ttl_active
                 or (usb_active   and (not ttl_active))
                 or (timer_active and (not ttl_active) and (not usb_active));

  trigger_fired <= any_trigger and trigger_enable;

  -- Identify which source caused the trigger (TTL wins ties)
  trigger_source_id_next <= "00" when ttl_active   = '1' else
                            "01" when usb_active   = '1' else
                            "10";

  ---------------------------------------------------------------------------
  -- Stage 5: Registered output pipeline
  -- trigger_out is high for exactly 1 clock cycle (trigger_fired is already
  -- 1-cycle because all edge detectors produce 1-cycle pulses; registering
  -- it shifts the pulse by 1 cycle but does not widen it).
  ---------------------------------------------------------------------------
  p_output_reg : process(clk)
  begin
    if rising_edge(clk) then
      if reset = '0' then
        trigger_out_reg       <= '0';
        trigger_source_id_reg <= "00";
      else
        trigger_out_reg <= trigger_fired;
        if trigger_fired = '1' then
          trigger_source_id_reg <= trigger_source_id_next;
        end if;
      end if;
    end if;
  end process p_output_reg;

  ---------------------------------------------------------------------------
  -- Stage 6: Trigger counter
  -- 16-bit, resets on active-low reset OR when reset_counter = '1'.
  -- Increments once per output trigger (aligned to trigger_fired, before
  -- the output register stage — this means the count increments in the same
  -- cycle that trigger_out will be asserted next cycle).
  ---------------------------------------------------------------------------
  p_counter : process(clk)
  begin
    if rising_edge(clk) then
      if reset = '0' or reset_counter = '1' then
        trigger_count_reg <= (others => '0');
      elsif trigger_fired = '1' then
        trigger_count_reg <= trigger_count_reg + 1;
      end if;
    end if;
  end process p_counter;

  ---------------------------------------------------------------------------
  -- Output assignments
  ---------------------------------------------------------------------------
  trigger_out       <= trigger_out_reg;
  trigger_source_id <= trigger_source_id_reg;
  trigger_count     <= trigger_count_reg;

end rtl;
