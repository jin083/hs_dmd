`timescale 1ns/1ps
module review_tb;
reg clk=0, reset=1, ttl=0, error_in=0;
always #2.5 clk=~clk;
reg [7:0] address=0; reg [15:0] value=0; reg write=0; wire [15:0] result;
wire pop; reg valid=0; wire rd_start; wire [14:0] rd_id;
always @(posedge clk) valid<=pop;
memory_playback p(.clk(clk),.reset(reset),.init_active(1'b0),.dmd_type(4'b0001),.update_mode(3'b0),.ttl_trigger(ttl),
 .reg_address(address),.reg_write_data(value),.reg_write(write),.reg_read_data(result),
 .calibrated(1'b1),.upload_active(1'b0),.loaded(1'b1),.memory_ready(1'b1),.upload_ready(1'b1),
 .memory_error(error_in),.usb_overflow(1'b0),.uploaded_patterns(15'd2),
 .read_start(rd_start),.read_pattern(rd_id),.fifo_available(1'b1),.fifo_valid(valid),.fifo_data(128'b0),.fifo_pop(pop));
integer starts=0, commits=0, error_commits_before=0;
always @(negedge clk) begin
 if(rd_start) begin starts=starts+1;$display("EVENT read id=%d at=%t",rd_id,$time);end
 if(p.frame_committed) commits=commits+1;
end
task wr;input[7:0] a;input[15:0] d;begin @(negedge clk);address=a;value=d;write=1;@(negedge clk);write=0;end endtask
task setup;begin
 reset=1;repeat(4)@(negedge clk);reset=0;wait(!p.store_busy);repeat(3)@(negedge clk);
 // Unit-test setup: seed verified directory entries. This bench does not test DDR CRC.
 p.directory.slots[0]={1'b1,2'd2,32'd123};p.directory.slots[1]={1'b1,2'd2,32'd456};p.directory.valid_count=2;
 wr(8'h32,1);wr(8'h63,1);wr(8'h2b,1);wr(8'h2c,0);wr(8'h2d,0);wr(8'h38,2);wr(8'h2a,5);
end endtask
initial begin
 setup;
 wr(8'h2a,13);wait(p.frame_committed);wait(!p.frame_committed);wait(p.frame_committed);
 // Read snapshot exactly when the new interval is ready but min/max pipeline is pending.
 repeat(2) @(negedge clk); address=8'h60;value=1;write=1;
 @(negedge clk);write=0;
 $display("REPRO snapshot frames=%d last=%d min=%d max=%d pending=%d",p.snap_frames,p.snap_last,p.snap_min,p.snap_max,p.interval_pending);
 repeat(3) @(negedge clk);wr(8'h60,1);
 $display("CONTROL settled snapshot frames=%d last=%d min=%d max=%d",p.snap_frames,p.snap_last,p.snap_min,p.snap_max);
 wait(!p.running);
 setup;wr(8'h2a,21);wr(8'h38,7);
 $display("REPRO armed configuration armed=%d repeat_after_write=%d",p.armed,p.repeat_count);
 wr(8'h2a,32);
 // Partial reconfiguration: first table entry is replaced, then simulated USB failure prevents commit 0x2A=5.
 wr(8'h2b,2);wr(8'h2c,1);wr(8'h2d,1);wr(8'h38,1);wr(8'h2a,5);
 wr(8'h2c,0);wr(8'h2d,1);
 wr(8'h2a,13);repeat(25)@(negedge clk);
 $display("REPRO incomplete configuration running=%d table0=%d table1=%d",p.running,p.sequence_table[0],p.sequence_table[1]);
 wait(!p.running);
 setup;wr(8'h38,1);wr(8'h2a,13);wait(p.stream.state==3);error_commits_before=commits;error_in=1;
 wait(!p.running);repeat(4)@(negedge clk);
 $display("REPRO error during frame committed_total=%d commits_after_error=%d reason=%d done=%d sync_done=%d",commits,commits-error_commits_before,p.reason,p.done_q,p.sync_done);
 $display("DONE: review boundary probes");$finish;
end
initial begin #2000000;$display("FAIL: review timeout state=%d",p.state);$finish;end
endmodule
