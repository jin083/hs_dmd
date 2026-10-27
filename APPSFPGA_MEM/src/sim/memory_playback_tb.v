`timescale 1ns/1ps
module memory_playback_tb;
    localparam MANAGED_REPLACEMENT=0;
    `include "playback_harness.vh"
    task load_frames;
        input integer count;
        integer id; reg [31:0] wanted;
        begin
            wr(8'h2a,32);wr(8'h41,5);wait(!player.store_busy);
            source_limit=0;source_word=0;
            for(id=0;id<count;id=id+1) begin
                wanted=expected_crc(id);
                wr(8'h40,id);wr(8'h43,wanted[15:0]);wr(8'h44,wanted[31:16]);wr(8'h41,2);
                wait(upload_active);source_limit=(id+1)*6144;
                wait(!player.store_busy);repeat(8) @(negedge clk);
                check_reg(8'h41,16'h0007,16'h0002);
            end
            wr(8'h2a,5);
        end
    endtask
    integer i;
    initial begin
        order[0]=4;order[1]=1;order[2]=3;order[3]=0;order[4]=2;
        #100;reset=0;
        wait(upload_ready && !player.store_busy); repeat(10) @(negedge clk);
        check_reg(8'h3e,16'hffff,16'hd202);
        if(memory_enable) begin $display("FAIL: TI path changed on reset");$finish;end
        wr(8'h32,1);load_frames(5);
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
        load_frames(2);
        if(source_word!=12288) begin $display("FAIL: second upload size %d",source_word);$finish;end
        check_reg(8'h39,16'hffff,2);
        wr(8'h29,3);wait(player.running);wait(!player.running);
        if(active_pattern!=1 || frame_count!=frames_before+1) begin
            $display("FAIL: playback after second upload");$finish;
        end
        // An armed experiment refuses a concurrent slot mutation. The TTL
        // remains able to start the original, intact configured sequence.
        frames_before=frame_count;source_limit=source_word;
        wr(8'h2a,4);wr(8'h2b,1);wr(8'h2c,0);wr(8'h2d,1);wr(8'h38,1);wr(8'h2a,21);
        wr(8'h40,1);wr(8'h41,4);repeat(8) @(negedge clk);
        check_reg(8'h49,16'hffff,1);
        ttl=1;repeat(5) @(negedge clk);ttl=0;wait(player.running);wait(!player.running);
        if(frame_count!=frames_before+1) begin $display("FAIL: armed slot protection");$finish;end
        wr(8'h2a,32);wr(8'h41,1);wait(!player.store_busy);
        $display("PASS: memory_playback_tb - five stored frames, arbitrary order, full data/row checks, stalls, finite/infinite/TTL/single/direct playback");
        $finish;
    end
    initial begin #30000000;$display("FAIL: test watchdog timeout state=%d loaded=%b active=%b words=%d",player.state,loaded,upload_active,source_word);$finish;end
endmodule
