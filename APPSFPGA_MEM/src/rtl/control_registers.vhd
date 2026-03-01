library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;  
use IEEE.STD_LOGIC_UNSIGNED.all;

entity control_registers is
    port(
        system_clk              :in std_logic;
        system_reset            :in std_logic;

        --USB interface
        pll_speed_info      : in  std_logic_vector(1 downto 0);
        dvalid_space_info   : in  std_logic_vector(3 downto 0);
        BUILD_NUMBER        : in  std_logic_vector(7 downto 0);
        reg_address             :in std_logic_vector(7 downto 0);
        reg_write_data          :in std_logic_vector(15 downto 0);
        write_reg_valid         :in std_logic;
        reg_read_data           :out std_logic_vector(15 downto 0);
        fifo_reset              :out std_logic;
		
        num_patterns            :out std_logic_vector(14 downto 0); --number of patterns
		  mem_rd_fifo_reset		  :out std_logic;
		  mem_wr_fifo_reset		  :out std_logic;
		  mem_en						  :out std_logic;

        gpio_out                :out std_logic_vector(2 downto 0);
        gpio_in                 :in std_logic_vector(2 downto 0);
        gpio_external_reset     :in std_logic;
        external_reset_enable   :out std_logic;
        GPIO_reset_complete     :out std_logic;

        --DDC control
        DMD_type		        : in  std_logic_vector(3 downto 0);
        DDC_version		        : in  std_logic_vector(2 downto 0);
        DMD_blk_md		        : out std_logic_vector(1 downto 0);
        DMD_blk_ad		        : out std_logic_vector(3 downto 0);
        DMD_row_md		        : out std_logic_vector(1 downto 0);
        DMD_row_ad		        : out std_logic_vector(10 downto 0);
        DMD_pwr_float  	        : out std_logic;
        DMD_wdt	                : out std_logic;
        DMD_ns_flip		        : out std_logic;
        DMD_comp_data  	        : out std_logic;
        DMD_step_vcc		    : out std_logic;
        --DMD_ext_reset  	        : out std_logic;
        DMD_rst2blkz	        : out std_logic;
        --
        load4_en               : out std_logic;
        tpg_en                 : out std_logic; 
        pattern_force          : out std_logic;
        switch_en              : out std_logic;
        pattern_nmbr           : out std_logic_vector(2 downto 0);
        swtch_override_val     : out std_logic_vector(7 downto 0);
        --
        
        DMD_RowLoads		    : out std_logic_vector(15 downto 0);
        dmd_write_block	        : out std_logic;
        usb_switch_trigger       : out std_logic;
        usb_next_pattern_id      : out std_logic_vector(14 downto 0);

        -- Load2 enable (reg 0x16 bit 8)
        load2_en               : out std_logic;

        -- Pattern Sequencer outputs (to pattern_sequencer module, regs 0x2A-0x2D)
        seq_enable             : out std_logic;
        one_shot               : out std_logic;
        reset_index            : out std_logic;
        sequence_length        : out std_logic_vector(13 downto 0);
        seq_wr_addr            : out std_logic_vector(13 downto 0);
        seq_wr_data            : out std_logic_vector(14 downto 0);
        seq_wr_en              : out std_logic;

        -- Timing Controller outputs (to timing_controller module, regs 0x2F, 0x35-0x37)
        timing_enable          : out std_logic;
        auto_trigger           : out std_logic;
        timing_wr_addr         : out std_logic_vector(13 downto 0);
        timing_wr_lo           : out std_logic_vector(15 downto 0);
        timing_wr_hi           : out std_logic_vector(15 downto 0);
        timing_wr_en           : out std_logic;

        -- Trigger Mux outputs (to trigger_mux module, reg 0x33)
        trigger_source_sel     : out std_logic_vector(1 downto 0);
        trigger_enable         : out std_logic;
        reset_counter          : out std_logic;

        -- Pattern Sequencer status inputs (from pattern_sequencer, for reg 0x2E read)
        current_index          : in  std_logic_vector(13 downto 0);
        seq_running            : in  std_logic;

        -- Trigger Mux status inputs (from trigger_mux, for reg 0x34 read)
        trigger_count          : in  std_logic_vector(15 downto 0);
        trigger_source_id      : in  std_logic_vector(1 downto 0)
    );
end control_registers;

architecture Behavioral of control_registers is
    signal num_patterns_1           :std_logic_vector(14 downto 0);
	 signal mem_rd_fifo_reset_1		:std_logic;
	 signal mem_wr_fifo_reset_1   	:std_logic;
	 signal mem_rd_fifo_reset_1q		:std_logic;
	 signal mem_wr_fifo_reset_1q   	:std_logic;
	 signal mem_en_1						:std_logic;
	
    signal echo		               : std_logic_vector(15 downto 0);
    signal global_reset	            : std_logic;
    signal block_reset	            : std_logic;
    signal active_block_mem         : std_logic;

    signal DMD_blk_md_1	            : std_logic_vector(1 downto 0);
    signal DMD_blk_ad_1	            : std_logic_vector(3 downto 0);
    signal DMD_row_md_1	            : std_logic_vector(1 downto 0);
    signal DMD_row_ad_1	            : std_logic_vector(10 downto 0);
    signal DMD_pwr_float_1          : std_logic;
    signal DMD_wdt_1	            : std_logic;
    signal DMD_ns_flip_1	        : std_logic;
    signal DMD_comp_data_1          : std_logic;
    signal DMD_step_vcc_1           : std_logic;
    signal DMD_rst2blkz_1	        : std_logic;

    signal DMD_ext_reset_1          : std_logic;

    signal dmd_write_block_1q       : std_logic;
    signal dmd_write_block_1        : std_logic;

    signal DMD_RowLoads_1	        : std_logic_vector(15 downto 0);

    signal fifo_reset_1	            : std_logic;
    signal fifo_reset_1q	        : std_logic;

    signal gpio_out_1	            : std_logic_vector(2 downto 0);

    -- new merged gui/tpg registers
    signal load4_1                 : std_logic;
    signal pat_force_1             : std_logic; 
    signal sw_en_1                 : std_logic; 
    signal tpg_en_1                : std_logic;
    signal sw_override_val_1       : std_logic_vector(7 downto 0);
    signal pattern_sel_1           : std_logic_vector(2 downto 0);

    signal ResetComplete	        : std_logic;
    signal dmd_write_block_2q       : std_logic;
    signal dmd_write_block_3q       : std_logic;
    signal DMD_ext_reset_1q         : std_logic;
    signal gpio_external_reset_1q   : std_logic;

    signal GPIO_reset_complete_1    : std_logic;
    signal GPIO_reset_complete_1q   : std_logic;

    signal reset_complete_count     : std_logic_vector(7 downto 0);
    signal GPIO_reset_complete_f    : std_logic;
    signal APPSFPGA_CODE_VERSION    : std_logic_vector(15 downto 0);
    signal DISCOVERY_VERSION        : std_logic_vector(15 downto 0);
    signal usb_switch_trigger_1  : std_logic;
    signal usb_switch_trigger_1q : std_logic;
    signal usb_next_pattern_id_1 : std_logic_vector(14 downto 0);

    -- Load2 enable (reg 0x16 bit 8)
    signal load2_en_1              : std_logic;

    -- Pattern Sequencer control signals (regs 0x2A-0x2D)
    signal seq_enable_1            : std_logic;
    signal one_shot_1              : std_logic;
    signal reset_index_1           : std_logic;
    signal reset_index_1q          : std_logic;
    signal sequence_length_1       : std_logic_vector(13 downto 0);
    signal seq_wr_addr_1           : std_logic_vector(13 downto 0);
    signal seq_wr_data_1           : std_logic_vector(14 downto 0);
    signal seq_wr_en_1             : std_logic;
    signal seq_wr_en_1q            : std_logic;

    -- Timing Controller control signals (regs 0x2F, 0x35-0x37)
    signal timing_enable_1         : std_logic;
    signal auto_trigger_1          : std_logic;
    signal timing_wr_addr_1        : std_logic_vector(13 downto 0);
    signal timing_wr_lo_1          : std_logic_vector(15 downto 0);
    signal timing_wr_hi_1          : std_logic_vector(15 downto 0);
    signal timing_wr_en_1          : std_logic;
    signal timing_wr_en_1q         : std_logic;

    -- Trigger Mux control signals (reg 0x33)
    signal trigger_source_sel_1    : std_logic_vector(1 downto 0);
    signal trigger_enable_1        : std_logic;
    signal reset_counter_1         : std_logic;
    signal reset_counter_1q        : std_logic;

begin
	 APPSFPGA_CODE_VERSION <= "00" & pll_speed_info & dvalid_space_info & BUILD_NUMBER; 
	 DISCOVERY_VERSION     <= x"AC02";
--	 APPSFPGA_CODE_VERSION <= "0000000100000000";
--	 DISCOVERY_VERSION     <= x"AC01";

    --register read process
    process(system_clk, system_reset)
    begin
        if system_reset = '1' then
            reg_read_data <= x"ABCD";
        elsif system_clk'event and system_clk = '1' then
            case reg_address is
                when x"00"  => reg_read_data <= DISCOVERY_VERSION AFTER 1 PS;
                when x"01"  => reg_read_data <= APPSFPGA_CODE_VERSION AFTER 1 PS;
                when x"02"  => reg_read_data <= echo AFTER 1 PS;
            --  
                when x"10"  => reg_read_data <= "000000000000"   & DMD_type(3 downto 0) AFTER 1 PS;
                when x"11"  => reg_read_data <= "0000000000000"   & DDC_version(2 downto 0) AFTER 1 PS;
            --
                when x"14"  => reg_read_data <= "00000000000000"  & DMD_row_md_1(1 downto 0) AFTER 1 PS;
                when x"15"  => reg_read_data <= "00000"         & DMD_row_ad_1(10 downto 0) AFTER 1 PS;
                when x"16"  => reg_read_data <= "0000000" & load2_en_1 & load4_1 & DMD_rst2blkz_1 & DMD_ext_reset_1 &  DMD_pwr_float_1 & DMD_wdt_1 & DMD_ns_flip_1 & DMD_comp_data_1 & DMD_step_vcc_1 AFTER 1 PS;
                when x"17"  => reg_read_data <= "00000000000000"  & DMD_blk_md_1(1 downto 0) AFTER 1 PS;
                when x"18"  => reg_read_data <= "000000000000"    & DMD_blk_ad_1(3 downto 0) AFTER 1 PS;  
                when x"19"  => reg_read_data <= "00000000"        & gpio_in & gpio_out_1 & '0' & gpio_external_reset AFTER 1 PS;
                when x"20"  => reg_read_data <= DMD_RowLoads_1 AFTER 1 PS;
                when x"21"  => reg_read_data <= "000000000000000" & ResetComplete AFTER 1 PS;
                --when x"22"  => reg_read_data <= "000000000000000" & GPIO_reset_complete_1  AFTER 1 PS;

                when x"24"  => reg_read_data <= "0000000000000"   & pat_force_1 & sw_en_1 & tpg_en_1 AFTER 1 PS;
                when x"25"  => reg_read_data <= "00000000"        & sw_override_val_1 AFTER 1 PS;
                when x"26"  => reg_read_data <= "0000000000000"   & pattern_sel_1 AFTER 1 PS;

                when x"30" => reg_read_data <= "0" & num_patterns_1 AFTER 1 PS;
				 --when x"31" => reg_read_data <= "00000000000000" & mem_rd_fifo_reset_1 & mem_wr_fifo_reset_1 AFTER 1 PS;
				 when x"32" => reg_read_data <= "000000000000000" & mem_en_1;

                -- Pattern Sequencer status (reg 0x2E)
                when x"2E"  => reg_read_data <= seq_running & '0' & current_index AFTER 1 PS;

                -- Trigger Mux status (reg 0x34)
                when x"34"  => reg_read_data <= trigger_count AFTER 1 PS;

                when others => reg_read_data <= x"DEAD" AFTER 1 PS;
            end case;
        end if;
    end process;

    --process the incoming register write commands
    process(system_clk, system_reset)
    begin
        if system_reset = '1' then
            num_patterns_1 <= "000000000000000";
			mem_rd_fifo_reset_1 <= '0';
			mem_wr_fifo_reset_1 <= '0';
			mem_en_1				  <= '0';

            dmd_write_block_1	    <= '0';
            global_reset	    <= '0';
            block_reset 	    <= '0';
            active_block_mem	    <= '0'; 

            DMD_blk_md_1            <= "00";
            DMD_blk_ad_1            <= "0000";
            DMD_row_md_1            <= "00";
            DMD_row_ad_1            <= "00000000000";
            DMD_RowLoads_1          <= x"0000";

            DMD_step_vcc_1          <= '0';
            DMD_comp_data_1         <= '0';
            DMD_ns_flip_1           <= '0';
            DMD_wdt_1		    <= '1';	 -- 0 = WDT on, 1 = WDT off
            DMD_pwr_float_1         <= '1';
            DMD_ext_reset_1         <= '0';				    
            DMD_rst2blkz_1          <= '0';
            fifo_reset_1            <= '0';

            gpio_out_1              <= "000";
            echo                    <= x"EECC";

            -- new registers
            load4_1                 <= '0';  --  STD_LOGIC;
            pat_force_1             <= '0';  --  STD_LOGIC; 
            sw_en_1                 <= '1';  --  STD_LOGIC; 
            tpg_en_1                <= '1';  --  STD_LOGIC;
            sw_override_val_1       <= "00000000";  --  STD_LOGIC_VECTOR(7 DOWNTO 0);
            pattern_sel_1           <= "000";       --  STD_LOGIC_VECTOR(2 DOWNTO 0);
        
            GPIO_reset_complete_1   <= '0';
            usb_switch_trigger_1  <= '0';
            usb_next_pattern_id_1 <= (others => '0');

            -- New feature registers: reset to 0x0000
            load2_en_1              <= '0';
            seq_enable_1            <= '0';
            one_shot_1              <= '0';
            reset_index_1           <= '0';
            sequence_length_1       <= (others => '0');
            seq_wr_addr_1           <= (others => '0');
            seq_wr_data_1           <= (others => '0');
            seq_wr_en_1             <= '0';
            timing_enable_1         <= '0';
            auto_trigger_1          <= '0';
            timing_wr_addr_1        <= (others => '0');
            timing_wr_lo_1          <= (others => '0');
            timing_wr_hi_1          <= (others => '0');
            timing_wr_en_1          <= '0';
            trigger_source_sel_1    <= "00";
            trigger_enable_1        <= '1';
            reset_counter_1         <= '0';

        elsif system_clk'event and system_clk = '1' then
            if fifo_reset_1q = '1' then
                fifo_reset_1 <= '0';
            end if;
			if mem_rd_fifo_reset_1q = '1' then
				 mem_rd_fifo_reset_1 <= '0';
			end if;
			if mem_wr_fifo_reset_1q = '1' then
				 mem_wr_fifo_reset_1 <= '0';
			end if;
            if dmd_write_block_1q = '1' then
                dmd_write_block_1q <= '0';
            end if;
            if GPIO_reset_complete_1q = '1' then
                GPIO_reset_complete_1 <= '0';
            end if;
            if usb_switch_trigger_1q = '1' then
                usb_switch_trigger_1 <= '0';
            end if;
            -- Pulse auto-clear for new registers (follow fifo_reset_1q pattern)
            if reset_index_1q = '1' then
                reset_index_1 <= '0';
            end if;
            if seq_wr_en_1q = '1' then
                seq_wr_en_1 <= '0';
            end if;
            if timing_wr_en_1q = '1' then
                timing_wr_en_1 <= '0';
            end if;
            if reset_counter_1q = '1' then
                reset_counter_1 <= '0';
            end if;

            if write_reg_valid = '1' then
                case reg_address is
                    WHEN x"02" =>  echo <= reg_write_data;
                    WHEN x"03" =>  
                        dmd_write_block_1      <= reg_write_data(0);
                        global_reset           <= reg_write_data(1);
                        block_reset	           <= reg_write_data(2);
                        active_block_mem       <= reg_write_data(3);   -- 0=first, 1=second
                        fifo_reset_1           <= reg_write_data(4); 				        
                    WHEN x"14" =>  DMD_row_md_1 <= reg_write_data(1 downto 0);
                    WHEN x"15" =>  DMD_row_ad_1 <= reg_write_data(10 downto 0);
                    WHEN x"16" =>  
                        DMD_step_vcc_1         <= reg_write_data(0);
                        DMD_comp_data_1        <= reg_write_data(1);
                        DMD_ns_flip_1          <= reg_write_data(2);
                        DMD_wdt_1	           <= reg_write_data(3);
                        DMD_pwr_float_1        <= reg_write_data(4);
                        DMD_ext_reset_1        <= reg_write_data(5);
                        DMD_rst2blkz_1         <= reg_write_data(6);
                        load4_1                <= reg_write_data(7);
                        load2_en_1             <= reg_write_data(8);
                    WHEN x"17" =>  DMD_blk_md_1           <= reg_write_data(1 downto 0);
                    WHEN x"18" =>  DMD_blk_ad_1           <= reg_write_data(3 downto 0);
                    WHEN x"19" =>  gpio_out_1	          <= reg_write_data(2 downto 0);
                    WHEN x"20" =>  DMD_RowLoads_1         <= reg_write_data;
                    -- x"21" Read Only   
                    WHEN x"22" =>  GPIO_reset_complete_1  <= reg_write_data(0);
                    WHEN x"24" =>
                        tpg_en_1               <= reg_write_data(0);
                        sw_en_1                <= reg_write_data(1);
                        pat_force_1            <= reg_write_data(2);
                    WHEN x"25" => sw_override_val_1      <= reg_write_data(7 downto 0);
                    WHEN x"26" => pattern_sel_1          <= reg_write_data(2 downto 0);

                    when x"30" => num_patterns_1 <= reg_write_data(14 downto 0);
					  when x"31" =>
					      mem_rd_fifo_reset_1 <= reg_write_data(0);
							mem_wr_fifo_reset_1 <= reg_write_data(1);
					  when x"32" =>
							mem_en_1 <= reg_write_data(0);
                    when x"29" =>
                        usb_next_pattern_id_1 <= reg_write_data(15 downto 1);
                        usb_switch_trigger_1  <= reg_write_data(0);

                    -- Pattern Sequencer control (regs 0x2A-0x2D)
                    WHEN x"2A" =>
                        seq_enable_1           <= reg_write_data(0);
                        one_shot_1             <= reg_write_data(1);
                        reset_index_1          <= reg_write_data(2);  -- PULSE: auto-clears next cycle
                    WHEN x"2B" => sequence_length_1      <= reg_write_data(13 downto 0);
                    WHEN x"2C" => seq_wr_addr_1          <= reg_write_data(13 downto 0);
                    WHEN x"2D" =>
                        seq_wr_data_1          <= reg_write_data(14 downto 0);
                        seq_wr_en_1            <= '1';  -- PULSE: auto-clears next cycle

                    -- Timing Controller control (regs 0x2F, 0x35-0x37)
                    WHEN x"2F" =>
                        timing_enable_1        <= reg_write_data(0);
                        auto_trigger_1         <= reg_write_data(1);
                    WHEN x"35" => timing_wr_addr_1       <= reg_write_data(13 downto 0);
                    WHEN x"36" => timing_wr_lo_1         <= reg_write_data;
                    WHEN x"37" =>
                        timing_wr_hi_1         <= reg_write_data;
                        timing_wr_en_1         <= '1';  -- PULSE: auto-clears next cycle

                    -- Trigger Mux control (reg 0x33)
                    WHEN x"33" =>
                        trigger_source_sel_1   <= reg_write_data(1 downto 0);
                        trigger_enable_1       <= reg_write_data(2);
                        reset_counter_1        <= reg_write_data(3);  -- PULSE: auto-clears next cycle

                    when others => NULL;
                end case;
            end if;
        end if;
    end process;
    
    --Creates queues needed to pulse signals that need pulsing
    process(system_clk, system_reset)
    begin
        if system_reset = '1' then
            fifo_reset_1q <= '0';
			mem_rd_fifo_reset_1q <= '0';
			mem_wr_fifo_reset_1q <= '0';
            dmd_write_block_1q     <= '0';
            GPIO_reset_complete_1q <= '0';
            usb_switch_trigger_1q <= '0';
            -- Pulse queues for new registers
            reset_index_1q        <= '0';
            seq_wr_en_1q          <= '0';
            timing_wr_en_1q       <= '0';
            reset_counter_1q      <= '0';
        elsif system_clk'event and system_clk = '1' then
            fifo_reset_1q <= fifo_reset_1;
			mem_rd_fifo_reset_1q <= mem_rd_fifo_reset_1;
			mem_wr_fifo_reset_1q <= mem_wr_fifo_reset_1;
            dmd_write_block_1q     <= dmd_write_block_1;
            GPIO_reset_complete_1q <= GPIO_reset_complete_1;
            usb_switch_trigger_1q <= usb_switch_trigger_1;
            -- Pulse queues for new registers
            reset_index_1q        <= reset_index_1;
            seq_wr_en_1q          <= seq_wr_en_1;
            timing_wr_en_1q       <= timing_wr_en_1;
            reset_counter_1q      <= reset_counter_1;
        end if;
    end process;

    --creates a 1us Pulse when GPIO_reset_complete_1 is written to
    process(system_clk, system_reset)
    BEGIN
        if system_reset = '1' then
            reset_complete_count  <= x"00";
            GPIO_reset_complete_f <= '0';
        elsif system_clk'event and system_clk = '1' then
            if GPIO_reset_complete_1 = '1' then
                reset_complete_count    <= x"C8";
            else
                if reset_complete_count > x"00" then
                    GPIO_reset_complete_f <= '1';
                    reset_complete_count  <= reset_complete_count - x"01";
                else
                    GPIO_reset_complete_f <= '0';
                end if;
            end if;
        end if;
    end process;

    --Controls the ResetComplete Register,  when external reset go from disable to enabled
    --the Reset complete register is cleared.  when the external reset trigger is recived. the 
    --reset complete register is set high.
    process(system_clk, system_reset, DMD_ext_reset_1)
    BEGIN
        if system_reset = '1' then
            DMD_ext_reset_1q       <= '0';
            gpio_external_reset_1q <= '0';
            ResetComplete          <= '0';
        elsif system_clk'event and system_clk = '1' then
            DMD_ext_reset_1q       <= DMD_ext_reset_1;
            gpio_external_reset_1q <= gpio_external_reset;
            if DMD_ext_reset_1 = '1' and DMD_ext_reset_1q = '0' then
                ResetComplete <= '0';
            elsif DMD_ext_reset_1 = '1' and gpio_external_reset_1q = '0' and gpio_external_reset = '1' then
                ResetComplete <= '1';
            end if;
        end if;
    end process;

    --renaming section
    num_patterns          <= num_patterns_1;
	 mem_rd_fifo_reset 	  <= mem_rd_fifo_reset_1;
	 mem_wr_fifo_reset 	  <= mem_wr_fifo_reset_1;
	 mem_en					  <= mem_en_1;
    --DMD_ext_reset       <= DMD_ext_reset_1; 
    fifo_reset            <= fifo_reset_1;
    dmd_write_block       <= dmd_write_block_1;
    dmd_write_block       <= dmd_write_block_1;
    external_reset_enable <= DMD_ext_reset_1;
    DMD_blk_md            <= DMD_blk_md_1;
    DMD_blk_ad            <= DMD_blk_ad_1;
    DMD_row_md            <= DMD_row_md_1;
    DMD_row_ad            <= DMD_row_ad_1;
    DMD_pwr_float         <= DMD_pwr_float_1;
    DMD_wdt               <= DMD_wdt_1;
    DMD_ns_flip           <= DMD_ns_flip_1;
    DMD_comp_data         <= DMD_comp_data_1;
    DMD_step_vcc          <= DMD_step_vcc_1;
    DMD_rst2blkz          <= DMD_rst2blkz_1;
    DMD_RowLoads          <= DMD_RowLoads_1;
    gpio_out              <= gpio_out_1;
    GPIO_reset_complete   <= GPIO_reset_complete_f;
    --
    swtch_override_val    <= sw_override_val_1;
    pattern_nmbr          <= pattern_sel_1;
    load4_en              <= load4_1;
    tpg_en                <= tpg_en_1;
    pattern_force         <= pat_force_1;
    switch_en             <= sw_en_1;
    usb_switch_trigger  <= usb_switch_trigger_1;
    usb_next_pattern_id <= usb_next_pattern_id_1;

    -- New feature concurrent output assignments
    load2_en              <= load2_en_1;
    seq_enable            <= seq_enable_1;
    one_shot              <= one_shot_1;
    reset_index           <= reset_index_1;
    sequence_length       <= sequence_length_1;
    seq_wr_addr           <= seq_wr_addr_1;
    seq_wr_data           <= seq_wr_data_1;
    seq_wr_en             <= seq_wr_en_1;
    timing_enable         <= timing_enable_1;
    auto_trigger          <= auto_trigger_1;
    timing_wr_addr        <= timing_wr_addr_1;
    timing_wr_lo          <= timing_wr_lo_1;
    timing_wr_hi          <= timing_wr_hi_1;
    timing_wr_en          <= timing_wr_en_1;
    trigger_source_sel    <= trigger_source_sel_1;
    trigger_enable        <= trigger_enable_1;
    reset_counter         <= reset_counter_1;

end Behavioral;
