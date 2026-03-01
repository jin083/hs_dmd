library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

entity pattern_sequencer is
    port(
        clk              : in  std_logic;
        reset            : in  std_logic;
        -- Sequence control (from registers 0x2A-0x2E)
        seq_enable       : in  std_logic;
        one_shot         : in  std_logic;
        reset_index      : in  std_logic;
        sequence_length  : in  std_logic_vector(13 downto 0);
        seq_wr_addr      : in  std_logic_vector(13 downto 0);
        seq_wr_data      : in  std_logic_vector(14 downto 0);
        seq_wr_en        : in  std_logic;
        -- Trigger interface
        trigger_in       : in  std_logic;
        -- Outputs
        pattern_id_out   : out std_logic_vector(14 downto 0);
        trigger_out      : out std_logic;
        sequence_done    : out std_logic;
        current_index    : out std_logic_vector(13 downto 0);
        seq_running      : out std_logic
    );
end pattern_sequencer;

architecture Behavioral of pattern_sequencer is
    constant SEQ_DEPTH_C      : integer := 2543;
    constant SEQ_LAST_INDEX_C : std_logic_vector(13 downto 0) := conv_std_logic_vector(2542, 14);
    constant SEQ_MAX_LENGTH_C : std_logic_vector(13 downto 0) := conv_std_logic_vector(2543, 14);

    type seq_table_t is array(0 to 2542) of std_logic_vector(14 downto 0);
    signal sequence_table : seq_table_t;

    type seq_states is (IDLE, RUNNING, WRAP, DONE);
    signal current_state : seq_states;
    signal next_state    : seq_states;

    signal current_index_q   : std_logic_vector(13 downto 0);
    signal pattern_id_q      : std_logic_vector(14 downto 0);
    signal sequence_done_q   : std_logic;
    signal trigger_in_d_q    : std_logic;
    signal trigger_rise      : std_logic;
    signal sequence_length_q : std_logic_vector(13 downto 0);

    function clamp_length(
        length_in : std_logic_vector(13 downto 0)
    ) return std_logic_vector is
        variable result_v : std_logic_vector(13 downto 0);
    begin
        if length_in = "00000000000000" then
            result_v := "00000000000001";
        elsif length_in > SEQ_MAX_LENGTH_C then
            result_v := SEQ_MAX_LENGTH_C;
        else
            result_v := length_in;
        end if;
        return result_v;
    end function;

    function to_seq_index(
        index_in : std_logic_vector(13 downto 0)
    ) return integer is
        variable result_v : integer;
    begin
        if index_in > SEQ_LAST_INDEX_C then
            result_v := 0;
        else
            result_v := conv_integer(index_in);
        end if;
        return result_v;
    end function;

begin
    trigger_rise      <= trigger_in and (not trigger_in_d_q);
    sequence_length_q <= clamp_length(sequence_length);

    -- update current state and registered datapath
    process(clk, reset)
        variable read_index_v  : integer;
        variable write_index_v : integer;
    begin
        if reset = '0' then
            current_state    <= IDLE;
            current_index_q  <= (others => '0');
            pattern_id_q     <= (others => '0');
            sequence_done_q  <= '0';
            trigger_in_d_q   <= '0';
        elsif clk'event and clk = '1' then
            current_state <= next_state;
            trigger_in_d_q <= trigger_in;

            if seq_wr_en = '1' and current_state /= RUNNING then
                write_index_v := to_seq_index(seq_wr_addr);
                sequence_table(write_index_v) <= seq_wr_data;
            end if;

            if reset_index = '1' then
                current_index_q <= (others => '0');
                pattern_id_q    <= (others => '0');
                sequence_done_q <= '0';
            elsif seq_enable = '0' then
                current_index_q <= (others => '0');
                pattern_id_q    <= (others => '0');
                sequence_done_q <= '0';
            else
                case current_state is
                    when IDLE =>
                        sequence_done_q <= '0';
                        if trigger_rise = '1' then
                            read_index_v := to_seq_index(current_index_q);
                            pattern_id_q <= sequence_table(read_index_v);

                            if (current_index_q + "00000000000001") < sequence_length_q then
                                current_index_q <= current_index_q + "00000000000001";
                            elsif one_shot = '1' then
                                sequence_done_q <= '1';
                            end if;
                        end if;

                    when RUNNING =>
                        if trigger_rise = '1' then
                            read_index_v := to_seq_index(current_index_q);
                            pattern_id_q <= sequence_table(read_index_v);

                            if (current_index_q + "00000000000001") < sequence_length_q then
                                current_index_q <= current_index_q + "00000000000001";
                            elsif one_shot = '1' then
                                sequence_done_q <= '1';
                            end if;
                        end if;

                    when WRAP =>
                        current_index_q <= (others => '0');
                        sequence_done_q <= '0';

                    when DONE =>
                        sequence_done_q <= '1';
                end case;
            end if;
        end if;
    end process;

    -- update next state
    process(current_state, seq_enable, one_shot, trigger_rise, current_index_q, sequence_length_q, reset_index)
    begin
        case current_state is
            when IDLE =>
                if seq_enable = '1' and trigger_rise = '1' then
                    if (current_index_q + "00000000000001") >= sequence_length_q then
                        if one_shot = '1' then
                            next_state <= DONE;
                        else
                            next_state <= WRAP;
                        end if;
                    else
                        next_state <= RUNNING;
                    end if;
                else
                    next_state <= IDLE;
                end if;

            when RUNNING =>
                if seq_enable = '0' then
                    next_state <= IDLE;
                elsif trigger_rise = '1' then
                    if (current_index_q + "00000000000001") >= sequence_length_q then
                        if one_shot = '1' then
                            next_state <= DONE;
                        else
                            next_state <= WRAP;
                        end if;
                    else
                        next_state <= RUNNING;
                    end if;
                else
                    next_state <= RUNNING;
                end if;

            when WRAP =>
                if seq_enable = '0' then
                    next_state <= IDLE;
                else
                    next_state <= RUNNING;
                end if;

            when DONE =>
                if seq_enable = '0' or reset_index = '1' then
                    next_state <= IDLE;
                else
                    next_state <= DONE;
                end if;

            when others =>
                next_state <= IDLE;
        end case;
    end process;

    -- output logic
    process(current_state, seq_enable, trigger_in, pattern_id_q, sequence_done_q, current_index_q)
    begin
        pattern_id_out <= pattern_id_q;
        trigger_out    <= '0';
        sequence_done  <= sequence_done_q;
        current_index  <= current_index_q;
        seq_running    <= '0';

        if seq_enable = '0' then
            pattern_id_out <= (others => '0');
            trigger_out    <= trigger_in;
            sequence_done  <= '0';
            seq_running    <= '0';
        else
            case current_state is
                when IDLE =>
                    null;

                when RUNNING =>
                    trigger_out <= trigger_in;
                    seq_running <= '1';

                when WRAP =>
                    seq_running <= '1';

                when DONE =>
                    sequence_done <= '1';
                    seq_running   <= '0';

                when others =>
                    null;
            end case;
        end if;
    end process;
end Behavioral;
