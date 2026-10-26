library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity usb_memory_tb is end;
architecture test of usb_memory_tb is
    signal ifclk, clk, memclk : std_logic := '0';
    signal reset, mem_reset : std_logic := '1';
    signal finished : boolean := false;
    signal bus_data, usb_bus : std_logic_vector(15 downto 0) := (others => '0');
    signal wen, ren, regn : std_logic := '1';
    signal data : std_logic_vector(127 downto 0);
    signal available, valid, overflow, reg_valid : std_logic;
    signal reg_addr : std_logic_vector(7 downto 0);
    signal reg_data : std_logic_vector(15 downto 0);
    signal reg_read_data : std_logic_vector(15 downto 0);
    signal received, register_writes : integer := 0;
    function sample(k : integer) return std_logic_vector is
    begin
        return std_logic_vector(to_unsigned(16#2357#,16) xor to_unsigned(k*197,16));
    end;
    function usb_transform(v : std_logic_vector(15 downto 0)) return std_logic_vector is
        variable swapped, result_v : std_logic_vector(15 downto 0);
    begin
        swapped := v(7 downto 0) & v(15 downto 8);
        for i in 0 to 15 loop result_v(i) := swapped(15-i); end loop;
        return result_v;
    end;
begin
    ifclk <= not ifclk after 10.4165 ns when not finished else '0';
    clk <= not clk after 2.5 ns when not finished else '0';
    memclk <= not memclk after 3.333 ns when not finished else '0';
    usb_bus <= bus_data when ren='1' else (others => 'Z');
    dut : entity work.USB_IO port map(
        ifclk=>ifclk, system_clk=>clk, mem_clk=>memclk, reset_i=>reset,
        system_reset=>reset, bidir=>usb_bus, fifo_wen=>wen, fifo_ren=>ren, fifo_regn=>regn,
        dmd_1080p_connected=>'0', fifo_ab_data_out=>open, fifo_cd_data_out=>open,
        dmd_get_row_data=>'0', dmd_row_fifo_reset=>mem_reset,
        mem_wr_data=>data, mem_wr_data_valid=>valid, mem_wr_valid=>available,
        mem_get_data=>available, mem_fifo_reset=>mem_reset, memory_mode=>'1',
        memory_overflow=>overflow, reg_data_from_usb=>reg_data, reg_data_to_usb=>reg_read_data,
        reg_addra_USB=>reg_addr, reg_data_valid=>reg_valid, update_mode=>"000"
    );
    -- Both real register banks have a registered, one-system-clock read response.
    -- Exercise that latency through the real PLL, CDC FIFOs and bidirectional bus.
    process(clk)
    begin
        if rising_edge(clk) then
            case reg_addr is
                when x"00" => reg_read_data <= x"AC02";
                when x"3E" => reg_read_data <= x"D201";
                when others => reg_read_data <= x"DEAD";
            end case;
        end if;
    end process;
    process(memclk)
        variable expected : std_logic_vector(127 downto 0);
    begin
        if rising_edge(memclk) and valid='1' then
            for j in 0 to 7 loop
                expected(127-j*16 downto 112-j*16) := usb_transform(sample(received*8+j));
            end loop;
            assert data=expected report "FAIL: USB packet boundary/data alignment word " & integer'image(received) severity failure;
            received <= received+1;
        end if;
    end process;
    process(clk)
    begin
        if rising_edge(clk) and reg_valid='1' then
            assert reg_addr=x"2D" and unsigned(reg_data)=16#7000#+register_writes
                report "FAIL: register burst address/data alignment" severity failure;
            register_writes <= register_writes+1;
        end if;
    end process;
    process
        variable transmitted : integer := 0;
        procedure burst(length : integer) is
        begin
            for i in 0 to length-1 loop
                wait until rising_edge(ifclk); wait for 1 ns;
                regn<='1'; wen<='0'; bus_data<=sample(transmitted);
                transmitted := transmitted+1;
            end loop;
            -- TI DLPU045A table 2: the last word of a FIFO burst is not data.
            -- Keep WEN asserted for a distinct trailer so accepting it is visible.
            wait until rising_edge(ifclk); wait for 1 ns; bus_data<=x"A55A";
            wait until rising_edge(ifclk); wait for 1 ns; wen<='1';
            for i in 0 to 3 loop wait until rising_edge(ifclk); end loop;
        end;
        procedure read_register(address : std_logic_vector(7 downto 0);
                                expected : std_logic_vector(15 downto 0);
                                address_cycles : positive) is
        begin
            wait until rising_edge(ifclk); wait for 1 ns;
            regn<='0'; wen<='1'; ren<='1'; bus_data<=x"00" & address;
            for i in 1 to address_cycles loop wait until rising_edge(ifclk); end loop;
            wait for 1 ns; regn<='1';
            -- The FX2 must allow the round trip across the two asynchronous FIFOs.
            for i in 1 to 16 loop wait until rising_edge(ifclk); end loop;
            wait for 1 ns; ren<='0';
            wait until rising_edge(ifclk);
            assert usb_bus=expected report "FAIL: USB register read address " &
                integer'image(to_integer(unsigned(address))) severity failure;
            wait for 1 ns; ren<='1';
        end;
    begin
        wait for 150 ns; reset<='0';
        wait for 4 us; mem_reset<='0'; wait for 1 us;
        burst(1); burst(7); burst(8); burst(64); burst(128);
        burst(256); burst(256); -- consecutive full 512-byte USB packets
        wait for 3 us;
        assert received=90 and overflow='0' report "FAIL: USB transfer count/overflow" severity failure;
        wait until rising_edge(ifclk); wait for 1 ns;
        regn<='0'; wen<='1'; bus_data<=x"002D";
        for n in 0 to 11 loop
            wait until rising_edge(ifclk); wait for 1 ns;
            wen<='0'; bus_data<=std_logic_vector(to_unsigned(16#7000#+n,16));
        end loop;
        wait until rising_edge(ifclk); wait for 1 ns; regn<='1'; wen<='1';
        wait for 3 us;
        assert register_writes=12 report "FAIL: lost register writes" severity failure;
        read_register(x"00", x"AC02", 1);
        read_register(x"3E", x"D201", 1);
        read_register(x"3F", x"DEAD", 8);
        read_register(x"00", x"AC02", 2);
        assert register_writes=12 report "FAIL: register read caused a write" severity failure;
        report "PASS: usb_memory_tb - packet boundaries, consecutive writes and register readback preserved" severity note;
        finished<=true; wait;
    end process;
    process
    begin
        wait for 100 us;
        assert finished report "FAIL: USB watchdog timeout" severity failure;
        wait;
    end process;
end;
