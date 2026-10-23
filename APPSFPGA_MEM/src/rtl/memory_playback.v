`timescale 1ns / 1ps
// Register-controlled DDR2 -> DLP7000 playback. Reset leaves the TI path selected.
// The host configures tables while stopped, uploads full XGA frames, then starts
// a sequence by USB or arms GPIOA[0]. repeat_count=0 means unlimited repetitions.
module memory_playback(
    input clk, input reset, input init_active, input [3:0] dmd_type,
    input [2:0] update_mode, input ttl_trigger,
    input [7:0] reg_address, input [15:0] reg_write_data, input reg_write,
    output reg [15:0] reg_read_data,
    output reg memory_enable, output fifo_reset,
    output reg upload_start, output reg [14:0] pattern_count,
    input calibrated, input upload_active, input loaded, input memory_ready,
    input upload_ready, input memory_error, input usb_overflow,
    input [14:0] uploaded_patterns,
    output reg read_start, output reg [14:0] read_pattern,
    input fifo_available, input fifo_valid, input [127:0] fifo_data,
    output fifo_pop,
    output [63:0] data_a, output [63:0] data_b, output dvalid,
    output [1:0] row_mode, output [10:0] row_address,
    output [1:0] block_mode, output [3:0] block_address,
    output trigger_miss
);
    localparam STOPPED=0, FETCH=1, CHECK=2, LAUNCH=3, WAIT_FRAME=4, VALIDATE=5,
               STARTING=6;
    reg [2:0] state;
    reg enabled, one_shot, armed, running, done_q, error_q, missed;
    reg timing_enable;
    reg [13:0] sequence_length, seq_address, timing_address, index_q;
    reg [15:0] repeat_count, completed_loops, timing_low;
    reg [13:0] next_index;
    reg [15:0] next_loop;
    reg last_entry, repeat_limit_hit;
    reg [15:0] accepted_triggers;
    reg [31:0] countdown, active_duration;
    reg [6:0] reset_count;
    reg upload_pending, upload_inflight, stop_pending, direct_q;
    reg [14:0] uploaded_count_config;
    reg [14:0] direct_id;
    reg [14:0] sequence_table [0:2542];
    reg [31:0] timing_table [0:2542];
    reg [14:0] table_pattern;
    reg [31:0] table_duration, duration_raw;
    reg seq_write_pending, timing_write_pending;
    reg [13:0] table_write_address;
    reg [31:0] table_write_data;
    (* ASYNC_REG = "TRUE" *) reg ttl_meta, ttl_sync;
    reg ttl_previous;
    wire ttl_rise = ttl_sync && !ttl_previous;
    wire command = reg_write && reg_address == 8'h2a;
    wire usb_start = command && reg_write_data[3];
    wire usb_direct = reg_write && reg_address == 8'h29 && reg_write_data[0];
    wire stop_now = command && (!reg_write_data[0] || reg_write_data[5]);
    wire config_write = reg_write && reg_address >= 8'h2b && reg_address <= 8'h38;
    wire start_request = usb_start || (armed && ttl_rise) || usb_direct;
    wire frame_busy, frame_done, frame_committed;
    wire mode_ok = dmd_type == 4'b0001 && update_mode == 0;
    wire [15:0] status = {6'b0,memory_enable,upload_ready,missed,
                         (error_q || memory_error || usb_overflow),done_q,
                         frame_busy,running,loaded,upload_active,calibrated};
    assign fifo_reset = reset || reset_count != 0;
    assign trigger_miss = missed;
    // Precompute increment/compare on separate cycles. These flags settle long
    // before frame_done; keeping the carry chains out of the frame-completion
    // decision is necessary for the 5 ns system-clock constraint.
    always @(posedge clk) begin
        next_index <= index_q + 14'd1;
        next_loop <= completed_loops + 16'd1;
        last_entry <= next_index >= sequence_length;
        repeat_limit_hit <= repeat_count != 0 && next_loop >= repeat_count;
    end
    dmd_frame_streamer stream(
        .clk(clk), .reset(reset), .start(read_start),
        .commit_allowed(countdown == 0), .fifo_available(fifo_available),
        .fifo_valid(fifo_valid), .fifo_data(fifo_data), .fifo_pop(fifo_pop),
        .busy(frame_busy), .done(frame_done), .committed(frame_committed),
        .data_a(data_a), .data_b(data_b), .dvalid(dvalid),
        .row_mode(row_mode), .row_address(row_address),
        .block_mode(block_mode), .block_address(block_address)
    );
    // Qualify and capture a complete write before driving the BRAM write port.
    // This removes the frame-state/decode path from the RAM's 5 ns setup path.
    // Latched address/data preserve consecutive register writes, including a
    // START immediately after the last table word.
    always @(posedge clk) begin
        seq_write_pending <= 0;
        timing_write_pending <= 0;
        if (!reset && reg_write && !running && !frame_busy &&
            !upload_active && !upload_inflight) begin
            if (reg_address == 8'h2d && seq_address < 2543) begin
                seq_write_pending <= 1;
                table_write_address <= seq_address;
                table_write_data <= {17'b0,reg_write_data[14:0]};
            end
            if (reg_address == 8'h37 && timing_address < 2543) begin
                timing_write_pending <= 1;
                table_write_address <= timing_address;
                table_write_data <= {reg_write_data,timing_low};
            end
        end
    end
    // Separate synchronous read/write ports infer BRAM. No asynchronous table
    // lookup or reset of RAM contents. Host must initialize every used entry.
    always @(posedge clk) begin
        if (index_q < 2543) begin
            table_pattern <= sequence_table[index_q];
            table_duration <= timing_table[index_q];
        end
        if (seq_write_pending)
            sequence_table[table_write_address] <= table_write_data[14:0];
        if (timing_write_pending)
            timing_table[table_write_address] <= table_write_data;
    end
    always @(posedge clk) begin
        if (reset) begin
            ttl_meta <= 0; ttl_sync <= 0; ttl_previous <= 0;
        end else begin
            ttl_meta <= ttl_trigger; ttl_sync <= ttl_meta; ttl_previous <= ttl_sync;
        end
    end
    always @(posedge clk) begin
        if (reset) begin
            state <= STOPPED; memory_enable <= 0; enabled <= 0; one_shot <= 0;
            armed <= 0; running <= 0; done_q <= 0; error_q <= 0; missed <= 0;
            pattern_count <= 0; sequence_length <= 1; seq_address <= 0;
            timing_address <= 0; timing_low <= 0; timing_enable <= 0;
            repeat_count <= 1; completed_loops <= 0; accepted_triggers <= 0;
            countdown <= 0; active_duration <= 4000; duration_raw <= 4000; reset_count <= 0;
            upload_pending <= 0; upload_inflight <= 0; uploaded_count_config <= 0;
            upload_start <= 0; read_start <= 0;
            read_pattern <= 0; index_q <= 0; stop_pending <= 0;
            direct_q <= 0; direct_id <= 0;
        end else begin
            upload_start <= 0; read_start <= 0;
            if (upload_active || memory_error) upload_inflight <= 0;
            if (countdown != 0) countdown <= countdown - 1;
            if (frame_committed) countdown <= active_duration;
            if (reset_count != 0) reset_count <= reset_count - 1;
            else if (upload_pending) begin
                upload_start <= 1; upload_pending <= 0;
            end
            if (reg_write) begin
                // Configuration is immutable during a sequence, including a
                // pending frame. STOP drains the current frame before returning.
                case (reg_address)
                    8'h2a: begin
                        if (stop_now) begin
                            enabled <= reg_write_data[0]; armed <= 0; stop_pending <= 1;
                        end else if (!running) begin
                            enabled <= reg_write_data[0]; one_shot <= reg_write_data[1];
                            armed <= reg_write_data[4];
                            if (reg_write_data[2]) begin
                                index_q <= 0; done_q <= 0; error_q <= 0; missed <= 0;
                            end
                        end else if (!usb_start) error_q <= 1;
                    end
                    8'h29: if (!running && !frame_busy) direct_id <= reg_write_data[15:1];
                    8'h31: if (reg_write_data[1]) begin
                        if (!running && !frame_busy && !upload_active && !upload_pending &&
                            !upload_inflight && reset_count == 0 && upload_ready && memory_enable && mode_ok &&
                            pattern_count > 0 && pattern_count <= 2543) begin
                            reset_count <= 64; upload_pending <= 1;
                            upload_inflight <= 1; uploaded_count_config <= pattern_count;
                            done_q <= 0; error_q <= 0; missed <= 0;
                        end else error_q <= 1;
                    end
                    8'h33: if (!running) armed <= reg_write_data[2];
                    default: if (!running && !frame_busy && !upload_active && !upload_inflight) begin
                        case (reg_address)
                            8'h2b: sequence_length <= reg_write_data[13:0];
                            8'h2c: seq_address <= reg_write_data[13:0];
                            8'h2d: if (seq_address >= 2543) error_q <= 1;
                            8'h2f: timing_enable <= reg_write_data[0];
                            8'h30: pattern_count <= reg_write_data[14:0];
                            8'h32: memory_enable <= reg_write_data[0];
                            8'h35: timing_address <= reg_write_data[13:0];
                            8'h36: timing_low <= reg_write_data;
                            8'h37: if (timing_address >= 2543) error_q <= 1;
                            8'h38: repeat_count <= reg_write_data;
                            default: ;
                        endcase
                    end else if (reg_address >= 8'h2b && reg_address <= 8'h38)
                        error_q <= 1;
                endcase
            end
            if (start_request && !stop_now) begin
                if (!running && !frame_busy && !config_write && memory_enable && loaded && !init_active &&
                    !upload_inflight && !upload_active && reset_count == 0 && mode_ok &&
                    pattern_count == uploaded_count_config &&
                    (enabled || (command && reg_write_data[0]) || usb_direct) &&
                    sequence_length > 0 && sequence_length <= 2543 &&
                    !(error_q || memory_error || usb_overflow)) begin
                    running <= 1; done_q <= 0; completed_loops <= 0;
                    accepted_triggers <= accepted_triggers + 1;
                    stop_pending <= 0; direct_q <= usb_direct;
                    state <= STARTING;
                end else begin
                    missed <= 1;
                    if (!mode_ok || sequence_length == 0 || sequence_length > 2543)
                        error_q <= 1;
                end
            end
            case (state)
                STOPPED: ;
                // Separate start qualification (DMD type, mode and readiness)
                // from the index counter's reset mux to meet the 5 ns period.
                STARTING: begin index_q <= 0; state <= FETCH; end
                FETCH: state <= CHECK; // synchronous BRAM read after index changes
                CHECK: begin
                    read_pattern <= direct_q ? direct_id : table_pattern;
                    // Register the BRAM output before the 32-bit minimum-time
                    // comparison; the combined RAM/compare path misses 5 ns.
                    duration_raw <= table_duration;
                    state <= VALIDATE;
                end
                VALIDATE: begin
                    active_duration <= (!timing_enable || direct_q || duration_raw < 4000)
                                       ? 4000 : duration_raw;
                    if (read_pattern >= pattern_count) begin
                        error_q <= 1; running <= 0; state <= STOPPED;
                    end else state <= LAUNCH;
                end
                LAUNCH: if (memory_ready && !init_active && !stop_pending && !stop_now &&
                            !memory_error && !usb_overflow) begin
                    read_start <= 1; state <= WAIT_FRAME;
                end
                WAIT_FRAME: if (frame_done) begin
                    if (direct_q || last_entry) begin
                        if (completed_loops != 16'hffff) completed_loops <= next_loop;
                        if (direct_q || one_shot || repeat_limit_hit) begin
                            done_q <= 1; running <= 0; state <= STOPPED;
                        end else begin index_q <= 0; state <= FETCH; end
                    end else begin index_q <= next_index; state <= FETCH; end
                end
                default: begin state <= STOPPED; running <= 0; error_q <= 1; end
            endcase
            if ((stop_pending || stop_now || memory_error || usb_overflow) &&
                state != STOPPED && (!frame_busy && !read_start) && state != WAIT_FRAME) begin
                running <= 0; state <= STOPPED; stop_pending <= 0;
            end
            if ((stop_pending || stop_now || memory_error || usb_overflow) && frame_done) begin
                running <= 0; state <= STOPPED; stop_pending <= 0;
            end
        end
    end
    always @(posedge clk) begin
        case (reg_address)
            8'h29: reg_read_data <= {direct_id,1'b0};
            8'h2a: reg_read_data <= {11'b0,armed,2'b0,one_shot,enabled};
            8'h2b: reg_read_data <= {2'b0,sequence_length};
            8'h2e: reg_read_data <= {running,done_q,index_q};
            8'h2f: reg_read_data <= {15'b0,timing_enable};
            8'h30: reg_read_data <= {1'b0,pattern_count};
            8'h31: reg_read_data <= status;
            8'h32: reg_read_data <= {15'b0,memory_enable};
            8'h34: reg_read_data <= accepted_triggers;
            8'h38: reg_read_data <= repeat_count;
            8'h39: reg_read_data <= {1'b0,uploaded_patterns};
            8'h3a: reg_read_data <= completed_loops;
            8'h3b: reg_read_data <= {1'b0,read_pattern};
            8'h3c: reg_read_data <= countdown[15:0];
            8'h3d: reg_read_data <= countdown[31:16];
            8'h3e: reg_read_data <= 16'hd201; // full-frame playback ABI
            default: reg_read_data <= 16'hdead;
        endcase
    end
endmodule
