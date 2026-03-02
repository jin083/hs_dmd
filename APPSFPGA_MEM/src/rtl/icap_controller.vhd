-------------------------------------------------------------------------------
-- ICAP Controller for Virtex-5
-- Enables FPGA reconfiguration via USB
-------------------------------------------------------------------------------
-- File: icap_controller.vhd
-- 
-- Description:
--   This module provides an interface to the ICAP_VIRTEX5 primitive
--   for FPGA reconfiguration via USB. It accepts bitstream data from
--   USB and feeds it to the ICAP interface.
--
-- Usage:
--   1. Send 0xBB USB command to start programming
--   2. Send bitstream data via bulk transfer
--   3. Send 0xBC USB command to verify completion
--
-- Note: Bitstream must be byte-swapped and have header removed
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity icap_controller is
    port (
        -- Clock and Reset
        clk             : in  std_logic;  -- System clock (200MHz max)
        reset           : in  std_logic;  -- Active high reset
        
        -- USB Interface
        usb_data_valid  : in  std_logic;  -- Data valid from USB
        usb_data        : in  std_logic_vector(31 downto 0);  -- 32-bit data from USB
        usb_data_req    : out std_logic;  -- Request more data from USB
        
        -- Control Interface
        program_start   : in  std_logic;  -- Start programming sequence
        program_busy    : out std_logic;  -- Programming in progress
        program_done    : out std_logic;  -- Programming complete
        program_error   : out std_logic   -- Programming error
    );
end icap_controller;

architecture Behavioral of icap_controller is

    -------------------------------------------------------------------------
    -- ICAP_VIRTEX5 Component Declaration
    -------------------------------------------------------------------------
    component ICAP_VIRTEX5
        port (
            O       : out std_logic_vector(31 downto 0);  -- Output data
            CLK     : in  std_logic;                      -- Clock input
            CSB     : in  std_logic;                      -- Chip select (active low)
            RDNB    : in  std_logic;                      -- Read/Write (0=Write, 1=Read)
            I       : in  std_logic_vector(31 downto 0)   -- Input data
        );
    end component;
    
    -------------------------------------------------------------------------
    -- State Machine Definition
    -------------------------------------------------------------------------
    type state_type is (
        IDLE,           -- Waiting for program_start
        SYNC_WAIT,      -- Wait for sync word
        PROGRAMMING,    -- Sending bitstream to ICAP
        COMPLETE,       -- Programming complete
        ERROR_STATE     -- Error occurred
    );
    
    signal state            : state_type := IDLE;
    signal next_state       : state_type;
    
    -------------------------------------------------------------------------
    -- ICAP Signals
    -------------------------------------------------------------------------
    signal icap_o           : std_logic_vector(31 downto 0);
    signal icap_csb         : std_logic := '1';  -- Active low, default disabled
    signal icap_rdnb        : std_logic := '1'; -- Default read mode
    signal icap_i           : std_logic_vector(31 downto 0) := (others => '0');
    
    -------------------------------------------------------------------------
    -- Internal Signals
    -------------------------------------------------------------------------
    signal byte_count       : std_logic_vector(23 downto 0) := (others => '0');
    signal sync_detected    : std_logic := '0';
    signal data_accepted    : std_logic := '0';
    
    -- Sync word for Virtex-5: 0xAA995566 (byte-swapped: 0x665599AA)
    constant SYNC_WORD      : std_logic_vector(31 downto 0) := X"AA995566";
    
begin

    -------------------------------------------------------------------------
    -- ICAP Primitive Instantiation
    -------------------------------------------------------------------------
    ICAP_INST : ICAP_VIRTEX5
        port map (
            O       => icap_o,
            CLK     => clk,
            CSB     => icap_csb,
            RDNB    => icap_rdnb,
            I       => icap_i
        );

    -------------------------------------------------------------------------
    -- State Machine - State Register
    -------------------------------------------------------------------------
    process(clk, reset)
    begin
        if reset = '1' then
            state <= IDLE;
        elsif rising_edge(clk) then
            state <= next_state;
        end if;
    end process;
    
    -------------------------------------------------------------------------
    -- State Machine - Next State Logic
    -------------------------------------------------------------------------
    process(state, program_start, usb_data_valid, usb_data, sync_detected, byte_count)
    begin
        next_state <= state;  -- Default: stay in current state
        
        case state is
            when IDLE =>
                if program_start = '1' then
                    next_state <= SYNC_WAIT;
                end if;
                
            when SYNC_WAIT =>
                -- Wait for sync word from USB data
                if usb_data_valid = '1' and usb_data = SYNC_WORD then
                    next_state <= PROGRAMMING;
                end if;
                
            when PROGRAMMING =>
                -- Continue until we receive end marker or timeout
                -- For now, we rely on USB to signal end
                if program_start = '0' then
                    next_state <= COMPLETE;
                end if;
                
            when COMPLETE =>
                next_state <= IDLE;
                
            when ERROR_STATE =>
                next_state <= IDLE;
                
            when others =>
                next_state <= IDLE;
        end case;
    end process;
    
    -------------------------------------------------------------------------
    -- ICAP Control Signals
    -------------------------------------------------------------------------
    process(clk, reset)
    begin
        if reset = '1' then
            icap_csb <= '1';
            icap_rdnb <= '1';
            icap_i <= (others => '0');
            byte_count <= (others => '0');
            sync_detected <= '0';
        elsif rising_edge(clk) then
            case state is
                when IDLE =>
                    icap_csb <= '1';
                    icap_rdnb <= '1';
                    byte_count <= (others => '0');
                    sync_detected <= '0';
                    
                when SYNC_WAIT =>
                    -- Look for sync word
                    if usb_data_valid = '1' then
                        if usb_data = SYNC_WORD then
                            sync_detected <= '1';
                            icap_i <= usb_data;
                            icap_csb <= '0';  -- Enable ICAP
                            icap_rdnb <= '0'; -- Write mode
                        end if;
                    end if;
                    
                when PROGRAMMING =>
                    -- Write data to ICAP
                    if usb_data_valid = '1' then
                        icap_i <= usb_data;
                        icap_csb <= '0';
                        icap_rdnb <= '0';
                        byte_count <= byte_count + 1;
                    else
                        icap_csb <= '1';  -- Disable between writes
                    end if;
                    
                when COMPLETE =>
                    icap_csb <= '1';
                    icap_rdnb <= '1';
                    
                when others =>
                    icap_csb <= '1';
            end case;
        end if;
    end process;
    
    -------------------------------------------------------------------------
    -- Output Signals
    -------------------------------------------------------------------------
    program_busy <= '1' when state = PROGRAMMING or state = SYNC_WAIT else '0';
    program_done <= '1' when state = COMPLETE else '0';
    program_error <= '1' when state = ERROR_STATE else '0';
    usb_data_req <= '1' when state = PROGRAMMING and usb_data_valid = '0' else '0';

end Behavioral;
