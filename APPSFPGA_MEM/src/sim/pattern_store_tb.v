`timescale 1ns/1ps
module pattern_store_tb;
    localparam MANAGED_REPLACEMENT=1;
    `include "playback_harness.vh"
    task wait_store;
        begin
            wait(!player.store_busy); repeat(8) @(negedge clk);
        end
    endtask
    task query;
        input integer id;
        begin wr(8'h40,id);wr(8'h41,1);wait_store;end
    endtask
    task put;
        input integer id,version;
        reg [31:0] crc_value;
        begin
            source_limit=0;source_word=0;source_version=version;
            crc_value=expected_crc(version);
            wr(8'h40,id);wr(8'h43,crc_value[15:0]);wr(8'h44,crc_value[31:16]);wr(8'h41,2);
            wait(upload_active);repeat(5) @(negedge clk);
            check_reg(8'h41,16'h0008,16'h0008);
            source_limit=6144;wait_store;
            check_reg(8'h41,16'h0007,16'h0002);
            check_reg(8'h45,16'hffff,crc_value[15:0]);check_reg(8'h46,16'hffff,crc_value[31:16]);
            if(source_word!=6144) begin $display("FAIL: managed USB frame length");$finish;end
            versions[id]=version;
            query(id);check_reg(8'h42,16'hffff,6);
        end
    endtask
    integer before_requests, before_frames, pulse_starts=0, pulse_frames=0, pulse_done=0;
    reg ps=0,pf=0,pd=0;
    always @(negedge clk) begin
        if(player.sync_start && !ps) pulse_starts=pulse_starts+1;
        if(player.sync_frame && !pf) pulse_frames=pulse_frames+1;
        if(player.sync_done && !pd) pulse_done=pulse_done+1;
        ps=player.sync_start;pf=player.sync_frame;pd=player.sync_done;
    end
    initial begin
        #100;reset=0;
        wait(upload_ready && !player.store_busy);
        check_reg(8'h3e,16'hffff,16'hd202);
        check_reg(8'h47,16'hffff,0);
        wr(8'h32,1);wr(8'h4c,16'h1234);wr(8'h4d,16'h5678);
        put(0,0);put(3,3);put(1,1);
        check_reg(8'h47,16'hffff,3);
        // Only ID 1 changes; other complete frames remain intact.
        put(1,4);
        if(memory_io.u_mig_top.memory[7]!==pattern_word(0,7) ||
           memory_io.u_mig_top.memory[3*6144+6139]!==pattern_word(3,6139)) begin
            $display("FAIL: partial replacement damaged neighbor");$finish;
        end
        // Non-contiguous ID playback uses slot validity, not uploaded count.
        wr(8'h2b,1);wr(8'h2c,0);wr(8'h2d,3);wr(8'h38,1);wr(8'h2a,13);
        wait(player.running);wait(!player.running);
        if(frame_count!=1) begin $display("FAIL: sparse ID playback");$finish;end
        // Deletion preserves other IDs; full-list preflight emits no frame.
        wr(8'h40,1);wr(8'h41,4);wait_store;
        check_reg(8'h47,16'hffff,2);
        wr(8'h2b,2);wr(8'h2c,0);wr(8'h2d,0);wr(8'h2c,1);wr(8'h2d,1);
        before_requests=requests;wr(8'h2a,13);wait(player.running);wait(!player.running);
        if(requests!=before_requests) begin $display("FAIL: invalid sequence partially played");$finish;end
        check_reg(8'h31,16'h0040,16'h0040);
        wr(8'h2a,5);
        // Corrupt actual DDR contents: verification must fail and invalidate ID.
        memory_io.u_mig_top.memory[3*6144+7]=memory_io.u_mig_top.memory[3*6144+7]^128'b1;
        wr(8'h40,3);wr(8'h41,3);wait_store;
        check_reg(8'h49,16'hffff,4);check_reg(8'h47,16'hffff,1);
        query(3);check_reg(8'h42,16'hffff,3);
        put(3,3);
        // Interrupt an empty upload; other valid frames survive, slot reusable.
        source_limit=0;source_word=0;wr(8'h40,1);wr(8'h41,2);
        wait(upload_active);wr(8'h41,6);wait_store;
        check_reg(8'h49,16'hffff,6);check_reg(8'h47,16'hffff,2);
        // Abort after submitting part of a MIG burst, then prove the next put
        // has no orphan write-data words left in the MIG input queue.
        source_word=0;source_version=1;source_limit=0;
        wr(8'h41,2);wait(upload_active);source_limit=16;
        wait(memory_io.engine.state==4);wr(8'h41,6);source_limit=source_word;
        wait_store;check_reg(8'h49,16'hffff,6);
        if(memory_io.u_mig_top.write_head!=memory_io.u_mig_top.write_tail) begin
            $display("FAIL: aborted upload left an incomplete MIG write burst");$finish;
        end
        put(1,2);check_reg(8'h47,16'hffff,3);
        // Normal sequence ends with designated pattern without counting an extra loop.
        wr(8'h2b,1);wr(8'h2c,0);wr(8'h2d,1);wr(8'h61,1);wr(8'h62,0);
        before_frames=frame_count;wr(8'h2a,13);wait(player.running);wait(!player.running);
        if(frame_count!=before_frames+2) begin $display("FAIL: end pattern");$finish;end
        check_reg(8'h3a,16'hffff,1);wr(8'h61,0);
        repeat(150) @(negedge clk);wr(8'h60,1);
        check_reg(8'h64,16'hffff,2);check_reg(8'h6e,16'hffff,1);
        if(player.snap_last<4000 || player.snap_min>player.snap_max || pulse_frames!=frame_count || pulse_done<2) begin
            $display("FAIL: timing snapshot or synchronization pulses");$finish;
        end
        // A slot mutation makes a previously configured sequence stale.
        wr(8'h2a,5);put(1,2);before_requests=requests;wr(8'h2a,9);
        repeat(100) @(negedge clk);
        if(player.running || requests!=before_requests) begin $display("FAIL: stale generation started");$finish;end
        check_reg(8'h31,16'h0040,16'h0040);wr(8'h2a,5);
        // The last slot must retain its full physical ID through both CDC paths.
        put(2542,4);before_frames=frame_count;
        wr(8'h2b,1);wr(8'h2c,0);wr(8'h2d,2542);wr(8'h2a,13);
        wait(player.running);wait(!player.running);
        if(frame_count!=before_frames+1 || active_pattern!=2542) begin
            $display("FAIL: last-slot physical address/playback");$finish;
        end
        wr(8'h41,5);wait_store;check_reg(8'h47,16'hffff,0);
        query(0);check_reg(8'h42,16'hffff,0);
        check_reg(8'h4c,16'hffff,16'h1234);
        reset=1;#100;reset=0;wait_store;
        check_reg(8'h4c,16'hffff,0);check_reg(8'h47,16'hffff,0);
        $display("PASS: pattern_store_tb sparse replacement, DDR CRC corruption, deletion, abort, preflight, end pattern, snapshot/sync, stale generation, reset");$finish;
    end
    initial begin #18000000;$display("FAIL: pattern_store_tb timeout state=%d",player.directory.state);$finish;end
endmodule
