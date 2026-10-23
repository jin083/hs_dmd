`timescale 1ns/1ps
module memory_playback_tb;
    reg clk=0, mem_clk=0, reset=1, ttl=0;
    reg [2:0] update_mode=0;
    always #2.5 clk=~clk;
    always #3.333 mem_clk=~mem_clk;
    reg [7:0] address=0;
    reg [15:0] write_data=0;
    reg reg_write=0;
    wire [15:0] read_data;
    wire memory_enable, fifo_reset, upload_start, upload_active, loaded;
    wire calibrated, memory_ready, upload_ready, memory_error, read_start;
    wire [14:0] pattern_count, read_pattern, uploaded;
    wire [127:0] fifo_data;
    wire fifo_available, fifo_valid, fifo_pop, usb_pop;
    reg [127:0] usb_data=0;
    reg usb_valid=0;
    wire usb_available;
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
    assign usb_available = source_word < 30720 && tick%7 != 0;
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
        .memory_enable(memory_enable),.fifo_reset(fifo_reset),.upload_start(upload_start),
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
        .mem_rd_fifo_reset(fifo_reset),.upload_start(upload_start),.selected_pattern(read_pattern),
        .upload_active(upload_active),.memory_ready(memory_ready),.upload_ready(upload_ready),
        .memory_error(memory_error),.uploaded_patterns(uploaded)
    );
    always @(posedge mem_clk) begin
        usb_valid <= usb_pop;
        if (usb_pop) begin
            usb_data <= pattern_word(source_word/6144,source_word%6144);
            source_word = source_word+1;
        end
    end
    always @(negedge clk) begin
        tick=tick+1;
        if (!reset) begin
            if (memory_error) begin $display("FAIL: memory error"); $finish; end
            if (read_start) begin
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
                expected_word=pattern_word(active_pattern,row*8+beat);
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
    integer i;
    initial begin
        order[0]=4;order[1]=1;order[2]=3;order[3]=0;order[4]=2;
        #100;reset=0;
        wait(upload_ready); repeat(10) @(negedge clk);
        check_reg(8'h3e,16'hffff,16'hd201);
        if(memory_enable) begin $display("FAIL: TI path changed on reset");$finish;end
        wr(8'h32,1);wr(8'h30,5);wr(8'h31,2);
        wait(upload_active);wait(loaded);repeat(20) @(negedge clk);
        check_reg(8'h39,16'hffff,5);
        if(source_word!=30720) begin $display("FAIL: extra/missing USB words");$finish;end
        wr(8'h2b,5);wr(8'h38,2);wr(8'h2f,1);
        for(i=0;i<5;i=i+1) begin
            // Entries 0/1 and entry 1's long period are corrected by the
            // consecutive writes below; losing those writes must fail checks.
            wr(8'h2c,i);wr(8'h2d,i<2 ? 0 : order[i]);wr(8'h35,i);
            wr(8'h36,0);wr(8'h37,0);
        end
        // Consecutive address/data writes followed immediately by START exercise
        // the registered BRAM write port, including its address/data ownership.
        sequence_check=1; requests=0;
        @(negedge clk); reg_write=1; address=8'h2c; write_data=0;
        @(negedge clk); address=8'h2d; write_data=4;
        @(negedge clk); address=8'h2c; write_data=1;
        @(negedge clk); address=8'h2d; write_data=1;
        @(negedge clk); address=8'h35; write_data=1;
        @(negedge clk); address=8'h36; write_data=20000;
        @(negedge clk); address=8'h37; write_data=0;
        @(negedge clk); address=8'h2a; write_data=9;
        @(negedge clk); reg_write=0;
        wait(player.running);wait(!player.running);
        if(frame_count!=10) begin $display("FAIL: finite repeat count %d",frame_count);$finish;end
        check_reg(8'h3a,16'hffff,2);check_reg(8'h31,16'h0060,16'h0020);
        // One-entry one-shot must issue and complete exactly one frame.
        sequence_check=0;wr(8'h2b,1);wr(8'h2c,0);wr(8'h2d,3);wr(8'h2a,15);
        wait(player.running);wait(!player.running);
        if(frame_count!=11 || active_pattern!=3) begin $display("FAIL: single-entry one-shot");$finish;end
        // An external trigger starts the complete five-pattern cycle; busy
        // triggers are counted as missed and cannot skip/replace a pattern.
        wr(8'h2b,5);wr(8'h2c,0);wr(8'h2d,4);wr(8'h38,1);wr(8'h2a,21);
        sequence_check=1;requests=0;
        repeat(100) @(negedge clk);
        if(player.running) begin $display("FAIL: armed sequence started early");$finish;end
        ttl=1;repeat(5) @(negedge clk);ttl=0;wait(player.running);
        repeat(100) @(negedge clk);ttl=1;repeat(5) @(negedge clk);ttl=0;
        wait(!player.running);
        if(frame_count!=16 || !missed) begin $display("FAIL: triggered cycle or busy trigger handling");$finish;end
        // Unlimited playback stops only after completing an in-flight frame.
        wr(8'h38,0);wr(8'h2a,13);requests=0;
        wait(frame_count>=23);wr(8'h2a,33);wait(!player.running);
        frames_before=frame_count;repeat(25000) @(negedge clk);
        if(frame_count!=frames_before) begin $display("FAIL: stopped sequence kept playing");$finish;end
        // Direct USB selection must reach the DDR address, independent of table.
        sequence_check=0;wr(8'h2a,4);wr(8'h29,5);wr(8'h29,9);
        wait(player.running);wait(!player.running);
        if(active_pattern!=2 || frame_count!=frames_before+1) begin $display("FAIL: direct selection");$finish;end
        check_reg(8'h31,16'h0040,0);
        // Invalid table IDs and unsupported update modes cannot produce a
        // memory transaction or a partial DMD frame.
        frames_before=frame_count;
        wr(8'h2b,1);wr(8'h2c,0);wr(8'h2d,9);wr(8'h2a,13);
        wait(player.running);wait(!player.running);
        check_reg(8'h31,16'h0040,16'h0040);
        if(frame_count!=frames_before) begin $display("FAIL: invalid ID displayed");$finish;end
        wr(8'h2a,4);wr(8'h2d,1);update_mode=2;wr(8'h2a,9);
        repeat(30) @(negedge clk);
        check_reg(8'h31,16'h0048,16'h0040);
        update_mode=0;wr(8'h2a,4);
        // STOP during the table-read/launch stages must not leave an orphan
        // read request in the DDR/FIFO path.
        wr(8'h2a,9);wr(8'h2a,32);
        repeat(200) @(negedge clk);
        if(frame_count!=frames_before || player.running || player.frame_busy) begin
            $display("FAIL: STOP before launch");$finish;
        end
        // A second upload with a different count restarts at pattern/offset 0.
        source_word=0;wr(8'h30,2);wr(8'h31,2);
        wait(upload_active);wait(loaded);repeat(20) @(negedge clk);
        if(source_word!=12288) begin $display("FAIL: second upload size %d",source_word);$finish;end
        check_reg(8'h39,16'hffff,2);
        wr(8'h29,3);wait(player.running);wait(!player.running);
        if(active_pattern!=1 || frame_count!=frames_before+1) begin
            $display("FAIL: playback after second upload");$finish;
        end
        // Upload configuration and an asynchronous TTL edge may coincide.
        // Upload takes priority; no read may be launched into a reset FIFO.
        frames_before=frame_count;source_word=0;
        wr(8'h38,1);wr(8'h2a,21);
        @(negedge clk);ttl=1;@(negedge clk);wr(8'h31,2);ttl=0;
        wait(upload_active);wait(loaded);repeat(30) @(negedge clk);
        if(frame_count!=frames_before || player.running || player.frame_busy || source_word!=12288) begin
            $display("FAIL: upload/TTL arbitration");$finish;
        end
        check_reg(8'h31,16'h00c0,16'h0080);
        $display("PASS: memory_playback_tb - five stored frames, arbitrary order, full data/row checks, stalls, finite/infinite/TTL/single/direct playback");
        $finish;
    end
    initial begin #10000000;$display("FAIL: test watchdog timeout state=%d loaded=%b active=%b words=%d",player.state,loaded,upload_active,source_word);$finish;end
endmodule
