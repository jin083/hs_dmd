// Shared clocks, real FIFO/MIG integration, stimulus and full-frame scoreboard.
// Each test declares MANAGED_REPLACEMENT before including this file.
    reg clk=0, mem_clk=0, reset=1, ttl=0;
    reg [2:0] update_mode=0;
    always #2.5 clk=~clk;
    always #3.333 mem_clk=~mem_clk;
    reg [7:0] address=0;
    reg [15:0] write_data=0;
    reg reg_write=0;
    wire [15:0] read_data;
    wire memory_enable, fifo_reset, upload_start, upload_active, loaded, upload_abort;
    wire [14:0] upload_base;
    wire calibrated, memory_ready, upload_ready, memory_error, read_start;
    wire [14:0] pattern_count, read_pattern, uploaded;
    wire [127:0] fifo_data;
    wire fifo_available, fifo_valid, fifo_pop, usb_pop;
    reg [127:0] usb_data=0;
    reg usb_valid=0;
    wire usb_available;
    integer source_limit=0, source_version=0;
    integer versions [0:2542];
    integer source_word=0, tick=0, frame_count=0, row=0, beat=0, mcp_beat=0;
    integer active_pattern=0, last_commit=0, previous_duration=4000;
    integer requests=0, expected_id, loop_before, frames_before;
    integer order [0:4];
    integer sequence_check=0;
    reg [127:0] expected_word, expected_swapped;
    reg previous_row_valid=0;
    wire [63:0] data_a,data_b;
    wire dvalid;
    wire [1:0] row_mode,block_mode;
    wire [10:0] row_address;
    wire [3:0] block_address;
    wire missed;
    assign usb_available = source_word < source_limit && tick%7 != 0;
    function [127:0] pattern_word;
        input integer pattern, word_number;
        reg [31:0] a,b,c,d;
        begin
            a=32'h98760000^(pattern*65537)^word_number;
            b=32'h13579bdf^(word_number*71);
            c=32'hfedcba98^(pattern*65536)^(word_number*137);
            d=32'h2468ace0^(word_number*313);
            pattern_word={a,b,c,d};
        end
    endfunction
    memory_playback player(
        .clk(clk),.reset(reset),.init_active(1'b0),.dmd_type(4'b0001),
        .update_mode(update_mode),.ttl_trigger(ttl),.reg_address(address),
        .reg_write_data(write_data),.reg_write(reg_write),.reg_read_data(read_data),
        .memory_enable(memory_enable),.fifo_reset(fifo_reset),.upload_start(upload_start),.upload_abort(upload_abort),.upload_base(upload_base),
        .pattern_count(pattern_count),.calibrated(calibrated),.upload_active(upload_active),
        .loaded(loaded),.memory_ready(memory_ready),.upload_ready(upload_ready),
        .memory_error(memory_error),.usb_overflow(1'b0),.uploaded_patterns(uploaded),
        .read_start(read_start),.read_pattern(read_pattern),.fifo_available(fifo_available),
        .fifo_valid(fifo_valid),.fifo_data(fifo_data),.fifo_pop(fifo_pop),
        .data_a(data_a),.data_b(data_b),.dvalid(dvalid),.row_mode(row_mode),
        .row_address(row_address),.block_mode(block_mode),.block_address(block_address),
        .trigger_miss(missed)
    );
    MEM_IO_Verilog memory_io(
        .mem_clk0(mem_clk),.mem_clk2x(mem_clk),.mem_clk2x90(mem_clk),.mem_clk200(clk),
        .pll_mem_locked(1'b1),.system_clk(clk),.system_reset(reset),
        .mem_init_done(calibrated),.mem_preload_done(loaded),.mem_read_enable(read_start),
        .num_patterns(pattern_count),.update_mode(3'b0),.wr_data(usb_data),
        .wr_valid(usb_available),.wr_data_valid(usb_valid),.mem_get_data(usb_pop),
        .rd_ab_fifo_out(fifo_data),.rd_ab_fifo_valid(fifo_available),
        .rd_ab_fifo_data_valid(fifo_valid),.dmd_get_data(fifo_pop),
        .mem_rd_fifo_reset(fifo_reset),.upload_start(upload_start),.upload_abort(upload_abort),.upload_base(upload_base),.selected_pattern(read_pattern),
        .upload_active(upload_active),.memory_ready(memory_ready),.upload_ready(upload_ready),
        .memory_error(memory_error),.uploaded_patterns(uploaded)
    );
    always @(posedge mem_clk) begin
        usb_valid <= usb_pop;
        if (usb_pop) begin
            usb_data <= pattern_word(MANAGED_REPLACEMENT ? source_version : source_word/6144,source_word%6144);
            source_word = source_word+1;
        end
    end
    always @(negedge clk) begin
        tick=tick+1;
        if (!reset) begin
            if (player.store_busy !== (player.directory.state!=0)) begin
                $display("FAIL: registered directory busy does not match state"); $finish;
            end
            if (player.store_fifo_pop && player.stream_fifo_pop) begin
                $display("FAIL: simultaneous CRC/playback FIFO ownership"); $finish;
            end
            if (player.stream_fifo_pop && (!player.stream.busy ||
                player.stream.requested>=8 || player.stream.rows_fetched>=768 ||
                player.stream.bank_ready[player.stream.fill_bank])) begin
                $display("FAIL: stream FIFO request exceeded row/bank credit"); $finish;
            end
            if (memory_error) begin $display("FAIL: memory error"); $finish; end
            if (read_start && !player.store_verify) begin
                active_pattern=read_pattern;
                if (sequence_check) begin
                    expected_id=order[requests%5];
                    if (read_pattern !== expected_id) begin
                        $display("FAIL: sequence request %d got %d expected %d",requests,read_pattern,expected_id); $finish;
                    end
                end
                requests=requests+1;
            end
            if (dvalid && row_mode==2) begin
                if (row_address !== row || (beat!=0 && !previous_row_valid)) begin
                    $display("FAIL: row interrupted/address mismatch row=%d beat=%d addr=%d",row,beat,row_address); $finish;
                end
                expected_word=pattern_word(MANAGED_REPLACEMENT ? versions[active_pattern] : active_pattern,row*8+beat);
                expected_swapped={expected_word[127:112],expected_word[95:80],
                    expected_word[63:48],expected_word[31:16],expected_word[111:96],
                    expected_word[79:64],expected_word[47:32],expected_word[15:0]};
                if ({data_a,data_b} !== expected_swapped) begin
                    $display("FAIL: DDR->DMD data pattern=%d row=%d beat=%d got=%h expected=%h",active_pattern,row,beat,{data_a,data_b},expected_swapped); $finish;
                end
                if (beat==7) begin beat=0; row=row+1; end else beat=beat+1;
            end
            previous_row_valid=dvalid && row_mode==2;
            if (dvalid && block_mode==3) begin
                if (row!=768 || block_address!=8) begin
                    $display("FAIL: MCP before complete frame"); $finish;
                end
                if (mcp_beat==0) begin
                    if (last_commit!=0 && tick-last_commit < previous_duration) begin
                        $display("FAIL: MCP timing interval %d < %d",tick-last_commit,previous_duration); $finish;
                    end
                    if (last_commit!=0 && frame_count<11)
                        $display("MCP interval: %0d cycles (%0d ns)",tick-last_commit,(tick-last_commit)*5);
                    last_commit=tick;
                    previous_duration=(sequence_check && (requests-1)%5==1) ? 20000 : 4000;
                end
                if (mcp_beat==7) begin
                    mcp_beat=0; frame_count=frame_count+1; row=0;
                end else mcp_beat=mcp_beat+1;
            end
        end
    end
    task wr;
        input [7:0] a; input [15:0] d;
        begin
            @(negedge clk); address=a; write_data=d; reg_write=1;
            @(negedge clk); reg_write=0;
        end
    endtask
    task check_reg;
        input [7:0] a; input [15:0] mask,expected;
        begin
            @(negedge clk);address=a;
            repeat(3) @(negedge clk);
            if ((read_data & mask)!==expected) begin
                $display("FAIL: register %h got=%h mask=%h expected=%h",a,read_data,mask,expected); $finish;
            end
        end
    endtask
    function [31:0] expected_crc;
        input integer version;
        begin
            case(version)
                0: expected_crc=32'h337ba80e;
                1: expected_crc=32'hc4c3d736;
                2: expected_crc=32'h48a79792;
                3: expected_crc=32'hbf1fe8aa;
                4: expected_crc=32'h0e95b7c0;
                default: expected_crc=0;
            endcase
        end
    endfunction
