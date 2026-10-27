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
    output upload_start, upload_abort, output [14:0] upload_base, pattern_count,
    input calibrated, input upload_active, input loaded, input memory_ready,
    input upload_ready, input memory_error, input usb_overflow,
    input [14:0] uploaded_patterns,
    output read_start, output [14:0] read_pattern,
    input fifo_available, input fifo_valid, input [127:0] fifo_data,
    output fifo_pop,
    output [63:0] data_a, output [63:0] data_b, output dvalid,
    output [1:0] row_mode, output [10:0] row_address,
    output [1:0] block_mode, output [3:0] block_address,
    output trigger_miss, output reg sync_start, sync_frame, sync_done, output reg sync_enable
);
    localparam STOPPED=0, FETCH=1, CHECK=2, LAUNCH=3, WAIT_FRAME=4, VALIDATE=5,
               STARTING=6, SLOT_WAIT=7, SLOT_RAM=8, SLOT_VALID=9;
    reg [3:0] state;
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
    wire config_write = reg_write && ((reg_address >= 8'h2b && reg_address <= 8'h38) ||
                                     (reg_address >= 8'h61 && reg_address <= 8'h63));
    wire start_request = usb_start || (armed && ttl_rise) || usb_direct;
    wire frame_busy, frame_done, frame_committed;
    wire mode_ok = dmd_type == 4'b0001 && update_mode == 0;
    reg legacy_upload_start, stream_read_start;
    reg [14:0] configured_count, stream_read_pattern;
    wire stream_fifo_pop;
    wire store_busy, store_verify, store_fifo_pop, store_fifo_reset, store_fault, slot_valid;
    wire store_read_start;
    wire [14:0] store_read_id, stored_count;
    wire [15:0] store_reg_data;
    wire [31:0] store_generation, store_session;
    reg preflight, validating_end, ending;
    reg slot_valid_q;
    reg end_enable;
    reg rejected_start;
    reg [31:0] configured_generation;
    reg [14:0] end_id;
    wire [14:0] lookup_id = (validating_end || ending) ? end_id : direct_q ? direct_id : table_pattern;
    wire management_write = reg_write && reg_address >= 8'h40 && reg_address <= 8'h51;
    assign read_start = store_read_start || stream_read_start;
    assign read_pattern = store_verify ? store_read_id : stream_read_pattern;
    // Ownership is exclusive: management requires a stopped/idle streamer,
    // and playback cannot start while the store is busy. Keep that admission
    // check out of the FIFO BRAM read-enable path (5 ns system clock).
    assign fifo_pop = store_fifo_pop || stream_fifo_pop;
    pattern_store directory(
        .clk(clk), .reset(reset), .control_idle(!running && !frame_busy && !armed),
        .memory_enable(memory_enable), .calibrated(calibrated),
        .reg_address(reg_address), .reg_write_data(reg_write_data),
        .reg_write(reg_write && !upload_pending && !upload_inflight), .reg_read_data(store_reg_data),
        .legacy_start(1'b0), .legacy_count(15'b0),
        .lookup_id(stream_read_pattern), .lookup_valid(slot_valid),
        .upload_active(upload_active), .loaded(loaded), .upload_ready(upload_ready),
        .memory_ready(memory_ready), .memory_error(memory_error), .usb_overflow(usb_overflow),
        .upload_start(upload_start), .upload_abort(upload_abort), .upload_base(upload_base),
        .upload_count(pattern_count), .read_start(store_read_start), .read_id(store_read_id),
        .fifo_available(fifo_available), .fifo_valid(fifo_valid), .fifo_data(fifo_data),
        .fifo_pop(store_fifo_pop), .busy(store_busy), .verifying(store_verify),
        .fifo_reset(store_fifo_reset), .valid_count(stored_count),
        .generation(store_generation), .session(store_session), .fault(store_fault)
    );
    wire [15:0] status = {6'b0,memory_enable,upload_ready,missed,
                         (error_q || memory_error || usb_overflow || store_fault),done_q,
                         frame_busy,running,(stored_count!=0),upload_active,calibrated};
    assign fifo_reset = reset || reset_count != 0 || store_fifo_reset;
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
        .clk(clk), .reset(reset), .start(stream_read_start),
        .commit_allowed(countdown == 0), .fifo_available(fifo_available),
        .fifo_valid(fifo_valid && !store_verify), .fifo_data(fifo_data), .fifo_pop(stream_fifo_pop),
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
            !upload_active && !upload_inflight && !store_busy) begin
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
            configured_count <= 0; sequence_length <= 1; seq_address <= 0;
            timing_address <= 0; timing_low <= 0; timing_enable <= 0;
            repeat_count <= 1; completed_loops <= 0; accepted_triggers <= 0;
            countdown <= 0; active_duration <= 4000; duration_raw <= 4000; reset_count <= 0;
            upload_pending <= 0; upload_inflight <= 0; uploaded_count_config <= 0;
            legacy_upload_start <= 0; stream_read_start <= 0;
            stream_read_pattern <= 0; index_q <= 0; stop_pending <= 0;
            direct_q <= 0; direct_id <= 0; preflight<=0; validating_end<=0; ending<=0; end_enable<=0; end_id<=0;
            sync_enable<=0; rejected_start<=0; configured_generation<=0; slot_valid_q<=0;
        end else begin
            rejected_start<=0;
            if(reg_write && !running && !frame_busy && !store_busy &&
               (config_write || (reg_address==8'h2a && reg_write_data==5)))
                configured_generation<=store_generation;
            legacy_upload_start <= 0; stream_read_start <= 0;
            if (upload_active || memory_error) upload_inflight <= 0;
            if (countdown != 0) countdown <= countdown - 1;
            if (frame_committed) countdown <= active_duration;
            if (reset_count != 0) reset_count <= reset_count - 1;
            else if (upload_pending) begin
                legacy_upload_start <= 1; upload_pending <= 0;
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
                    8'h31: if (reg_write_data[1]) error_q<=1; // D201 bulk upload retired
                    8'h33: if (!running) armed <= reg_write_data[2];
                    default: if (!running && !frame_busy && !upload_active && !upload_inflight && !store_busy) begin
                        case (reg_address)
                            8'h2b: sequence_length <= reg_write_data[13:0];
                            8'h2c: seq_address <= reg_write_data[13:0];
                            8'h2d: if (seq_address >= 2543) error_q <= 1;
                            8'h2f: timing_enable <= reg_write_data[0];
                            8'h30: configured_count <= reg_write_data[14:0];
                            8'h32: memory_enable <= reg_write_data[0];
                            8'h35: timing_address <= reg_write_data[13:0];
                            8'h36: timing_low <= reg_write_data;
                            8'h37: if (timing_address >= 2543) error_q <= 1;
                            8'h38: repeat_count <= reg_write_data;
                            8'h61: end_enable <= reg_write_data[0];
                            8'h62: end_id <= reg_write_data[14:0];
                            8'h63: sync_enable <= reg_write_data[0];
                            default: ;
                        endcase
                    end else if (reg_address >= 8'h2b && reg_address <= 8'h38)
                        error_q <= 1;
                endcase
            end
            if (start_request && !stop_now) begin
                if (!running && !frame_busy && !config_write && !management_write && !store_busy && configured_generation==store_generation && memory_enable && stored_count!=0 && !init_active &&
                    !upload_inflight && !upload_active && reset_count == 0 && mode_ok &&
                    (enabled || (command && reg_write_data[0]) || usb_direct) &&
                    sequence_length > 0 && sequence_length <= 2543 &&
                    !(error_q || memory_error || usb_overflow)) begin
                    running <= 1; done_q <= 0;
                    stop_pending <= 0; direct_q <= usb_direct;
                    state <= STARTING; preflight<=1; validating_end<=0; ending<=0;
                end else begin
                    missed <= 1; rejected_start<=1;
                    if (!mode_ok || sequence_length == 0 || sequence_length > 2543 || configured_generation!=store_generation || stored_count==0)
                        error_q <= 1;
                end
            end
            case (state)
                STOPPED: ;
                // Separate start qualification (DMD type, mode and readiness)
                // from the index counter's reset mux to meet the 5 ns period.
                STARTING: begin
                    index_q <= 0; completed_loops <= 0;
                    accepted_triggers <= accepted_triggers + 1'b1;
                    state <= FETCH;
                end
                FETCH: state <= CHECK; // synchronous BRAM read after index changes
                CHECK: begin
                    stream_read_pattern <= lookup_id;
                    // Register the BRAM output before the 32-bit minimum-time
                    // comparison; the combined RAM/compare path misses 5 ns.
                    duration_raw <= table_duration;
                    state <= SLOT_WAIT;
                end
                SLOT_WAIT: state<=SLOT_RAM; // register slot BRAM address
                SLOT_RAM: state<=SLOT_VALID; // synchronous slot BRAM read
                SLOT_VALID: begin slot_valid_q<=slot_valid; state<=VALIDATE; end
                VALIDATE: begin
                    active_duration <= (!timing_enable || direct_q || duration_raw < 4000)
                                       ? 4000 : duration_raw;
                    if (stream_read_pattern >= 2543 || !slot_valid_q) begin
                        error_q <= 1; running <= 0; state <= STOPPED;
                    end else if(preflight) begin
                        if(validating_end || direct_q || last_entry) begin
                            if(end_enable && !validating_end) begin validating_end<=1; state<=FETCH; end
                            else begin preflight<=0; validating_end<=0; index_q<=0; state<=FETCH; end
                        end else begin index_q<=next_index; state<=FETCH; end
                    end else state <= LAUNCH;
                end
                LAUNCH: if (memory_ready && !init_active && !stop_pending && !stop_now &&
                            !memory_error && !usb_overflow) begin
                    stream_read_start <= 1; state <= WAIT_FRAME;
                end
                WAIT_FRAME: if (frame_done) begin
                    if (ending || direct_q || last_entry) begin
                        if (!ending && completed_loops != 16'hffff) completed_loops <= next_loop;
                        if (ending || direct_q || one_shot || repeat_limit_hit) begin
                            if(end_enable && !ending) begin ending<=1; state<=FETCH; end
                            else begin done_q <= 1; running <= 0; state <= STOPPED; end
                        end else begin index_q <= 0; state <= FETCH; end
                    end else begin index_q <= next_index; state <= FETCH; end
                end
                default: begin state <= STOPPED; running <= 0; error_q <= 1; end
            endcase
            if ((stop_pending || stop_now || memory_error || usb_overflow) &&
                state != STOPPED && (!frame_busy && !stream_read_start) && state != WAIT_FRAME) begin
                running <= 0; state <= STOPPED; stop_pending <= 0;
            end
            if ((stop_pending || stop_now || memory_error || usb_overflow) && frame_done) begin
                running <= 0; state <= STOPPED; stop_pending <= 0;
            end
        end
    end
    // Atomic host snapshot; 5 ns ticks describe FPGA MCP-command events, not
    // measured optical settling. GPIO pulses last 100 clocks (500 ns).
    reg [31:0] ticks, frame_counter, missed_counter, last_tick, interval_q, min_interval, max_interval;
    reg interval_pending, have_frame, running_q, done_previous, launched;
    reg [6:0] start_pulse, frame_pulse, done_pulse;
    reg [15:0] reason, snapshot_id;
    reg [31:0] snap_frames, snap_missed, snap_last, snap_min, snap_max, snap_generation, snap_session;
    reg [15:0] snap_reason;
    always @(posedge clk) begin
        if(reset) begin
            ticks<=0; frame_counter<=0; missed_counter<=0; last_tick<=0;
            interval_q<=0; min_interval<=32'hffffffff; max_interval<=0;
            interval_pending<=0; have_frame<=0; running_q<=0; done_previous<=0; launched<=0;
            start_pulse<=0; frame_pulse<=0; done_pulse<=0;
            sync_start<=0; sync_frame<=0; sync_done<=0; reason<=0; snapshot_id<=0;
            snap_frames<=0; snap_missed<=0; snap_last<=0; snap_min<=0; snap_max<=0;
            snap_generation<=0; snap_session<=0; snap_reason<=0;
        end else begin
            ticks<=ticks+1'b1; running_q<=running; done_previous<=done_q;
            interval_pending<=0;
            if(start_pulse!=0) start_pulse<=start_pulse-1'b1;
            if(frame_pulse!=0) frame_pulse<=frame_pulse-1'b1;
            if(done_pulse!=0) done_pulse<=done_pulse-1'b1;
            sync_start<=start_pulse!=0; sync_frame<=frame_pulse!=0; sync_done<=done_pulse!=0;
            if(running && !running_q) begin
                launched<=0; have_frame<=0; frame_counter<=0;
                interval_q<=0; min_interval<=32'hffffffff; max_interval<=0; reason<=0;
            end
            if(stream_read_start && !launched) begin start_pulse<=100; launched<=1; end
            if(frame_committed) begin
                frame_pulse<=100; frame_counter<=frame_counter+1'b1;
                last_tick<=ticks; have_frame<=1;
                if(have_frame) begin interval_q<=ticks-last_tick; interval_pending<=1; end
            end
            if(interval_pending) begin
                if(interval_q<min_interval) min_interval<=interval_q;
                if(interval_q>max_interval) max_interval<=interval_q;
            end
            if(rejected_start && missed_counter!=32'hffffffff) missed_counter<=missed_counter+1'b1;
            if(done_q && !done_previous) done_pulse<=100;
            if(!running && running_q) reason <= error_q || memory_error || usb_overflow ? 3 : done_q ? 1 : 2;
            if(reg_write && reg_address==8'h60 && reg_write_data[0]) begin
                snapshot_id<=snapshot_id+1'b1;
                snap_frames<=frame_counter; snap_missed<=missed_counter; snap_last<=interval_q;
                snap_min<=min_interval==32'hffffffff ? 0 : min_interval; snap_max<=max_interval;
                snap_generation<=store_generation; snap_session<=store_session; snap_reason<=reason;
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
            8'h30: reg_read_data <= {1'b0,configured_count};
            8'h31: reg_read_data <= status;
            8'h32: reg_read_data <= {15'b0,memory_enable};
            8'h34: reg_read_data <= accepted_triggers;
            8'h38: reg_read_data <= repeat_count;
            8'h39: reg_read_data <= {1'b0,stored_count};
            8'h3a: reg_read_data <= completed_loops;
            8'h3b: reg_read_data <= {1'b0,stream_read_pattern};
            8'h3c: reg_read_data <= countdown[15:0];
            8'h3d: reg_read_data <= countdown[31:16];
            8'h3e: reg_read_data <= 16'hd202; // managed fixed-slot playback ABI
            8'h60: reg_read_data <= snapshot_id;
            8'h61: reg_read_data <= {15'b0,end_enable};
            8'h62: reg_read_data <= {1'b0,end_id};
            8'h63: reg_read_data <= {15'b0,sync_enable};
            8'h64: reg_read_data <= snap_frames[15:0];
            8'h65: reg_read_data <= snap_frames[31:16];
            8'h66: reg_read_data <= snap_last[15:0];
            8'h67: reg_read_data <= snap_last[31:16];
            8'h68: reg_read_data <= snap_min[15:0];
            8'h69: reg_read_data <= snap_min[31:16];
            8'h6a: reg_read_data <= snap_max[15:0];
            8'h6b: reg_read_data <= snap_max[31:16];
            8'h6c: reg_read_data <= snap_missed[15:0];
            8'h6d: reg_read_data <= snap_missed[31:16];
            8'h6e: reg_read_data <= snap_reason;
            8'h70: reg_read_data <= snap_generation[15:0];
            8'h71: reg_read_data <= snap_generation[31:16];
            8'h72: reg_read_data <= snap_session[15:0];
            8'h73: reg_read_data <= snap_session[31:16];
            default: reg_read_data <= store_reg_data;
        endcase
    end
endmodule
