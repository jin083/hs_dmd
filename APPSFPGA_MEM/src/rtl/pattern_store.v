`timescale 1ns/1ps
// D202 fixed-slot directory and DDR readback CRC. All metadata is in clk domain.
// DDR words are read through the existing asynchronous FIFO, never from USB echo.
module pattern_store # (parameter UPLOAD_TIMEOUT = 32'd2000000000)(
    input clk, reset, control_idle, memory_enable, calibrated,
    input [7:0] reg_address, input [15:0] reg_write_data, input reg_write,
    output reg [15:0] reg_read_data,
    input legacy_start, input [14:0] legacy_count,
    input [14:0] lookup_id, output lookup_valid,
    input upload_active, loaded, upload_ready, memory_ready, memory_error, usb_overflow,
    output reg upload_start, upload_abort, output reg [14:0] upload_base, upload_count,
    output reg read_start, output [14:0] read_id,
    input fifo_available, fifo_valid, input [127:0] fifo_data,
    output reg fifo_pop, output busy, output verifying, output reg fifo_reset,
    output reg [14:0] valid_count, output reg [31:0] generation, session,
    output reg fault
);
    localparam IDLE=0, CLEAR=1, FLUSH=2, FETCH=3, DISPATCH=4, PREPARE=5,
               RESET_FIFO=6, START_WRITE=7, WAIT_WRITE=8, WRITE_DONE=9,
               START_READ=10, POP=11, WAIT_WORD=12, CRC=13, COMMIT=14,
               ABORT_WAIT=15, LEGACY_FILL=16, LEGACY_WAIT=17, LEGACY_START=18,
               FETCH_RAM=19, CRC_CHECK=20;
    reg [4:0] state;
    reg [14:0] selected, target, cursor, legacy_n;
    reg [3:0] operation;
    reg [31:0] expected, expected_q, crc, actual, watchdog;
    reg [127:0] word_q;
    reg [4:0] nibble;
    reg [12:0] words;
    reg [6:0] reset_cycles;
    reg done, initialized, legacy_mode, read_mode, failed, old_valid;
    (* KEEP = "TRUE" *) reg busy_q;
    reg crc_ok;
    reg [15:0] error_code;
    reg [14:0] query_id;
    reg [34:0] query_data;
    // state: 0 empty, 1 writing, 2 valid, 3 error; bit34 CRC verified.
    reg [34:0] slots [0:2542];
    reg [34:0] ram_q, ram_data;
    reg [14:0] ram_write_id;
    reg ram_write;
    // Register the address before the inferred BRAM. Selecting the read port
    // from frame_busy put the stream FSM and address decode on one 5 ns path.
    reg [11:0] ram_read_id;
    assign lookup_valid = ram_q[34] && ram_q[33:32] == 2 && lookup_id < 2543;
    assign busy = busy_q;
    assign verifying = read_mode;
    assign read_id = target;
    always @(posedge clk) begin
        ram_read_id <= state == IDLE ? lookup_id[11:0] : target[11:0];
        if (ram_read_id < 2543) ram_q <= slots[ram_read_id];
        else ram_q <= 0;
        if (ram_write) slots[ram_write_id] <= ram_data;
    end

    // USB_IO reverses bits in each byte and reverses the two bytes of each
    // host word. Undo that transform for zlib/IEEE CRC32 over the packed file.
    function [127:0] host_bytes;
        input [127:0] data;
        integer w,b;
        begin
            for(w=0;w<8;w=w+1)
                for(b=0;b<8;b=b+1) begin
                    host_bytes[127-w*16-b] = data[112-w*16+b];
                    host_bytes[119-w*16-b] = data[120-w*16+b];
                end
        end
    endfunction
    function [31:0] crc4;
        input [31:0] value; input [3:0] data;
        reg [31:0] c; integer b;
        begin
            c=value^{28'b0,data};
            for(b=0;b<4;b=b+1) c=c[0] ? (c>>1)^32'hedb88320 : c>>1;
            crc4=c;
        end
    endfunction
    wire [31:0] crc_next = crc4(crc,nibble[0] ? word_q[127:124] : word_q[123:120]);

    always @(posedge clk) begin
        if(reset) begin
            state<=CLEAR; busy_q<=1; cursor<=0; selected<=0; target<=0; operation<=0;
            expected<=0; expected_q<=0; crc<=32'hffffffff; actual<=0;
            generation<=0; session<=0; valid_count<=0; initialized<=0;
            upload_start<=0; upload_abort<=0; upload_base<=0; upload_count<=0;
            read_start<=0; read_mode<=0; fifo_reset<=0; fifo_pop<=0; reset_cycles<=0;
            done<=0; fault<=0; error_code<=0; watchdog<=0; crc_ok<=0;
            legacy_mode<=0; legacy_n<=0; failed<=0; old_valid<=0;
            ram_write<=0; ram_write_id<=0; ram_data<=0;
            query_id<=0; query_data<=0; words<=0; nibble<=0; word_q<=0;
        end else begin
            upload_start<=0; upload_abort<=0; read_start<=0;
            fifo_reset<=0; fifo_pop<=0; ram_write<=0;
            if(reg_write && state==IDLE && control_idle) begin
                case(reg_address)
                    8'h40: selected<=reg_write_data[14:0];
                    8'h43: expected[15:0]<=reg_write_data;
                    8'h44: expected[31:16]<=reg_write_data;
                    8'h4c: if(valid_count==0) session[15:0]<=reg_write_data;
                    8'h4d: if(valid_count==0) session[31:16]<=reg_write_data;
                    default: ;
                endcase
            end
            case(state)
                CLEAR: begin
                    ram_write<=1; ram_write_id<=cursor; ram_data<=0;
                    if(cursor==2542) begin cursor<=0; state<=FLUSH; end
                    else cursor<=cursor+1'b1;
                end
                FLUSH: begin
                    initialized<=1;
                    if(legacy_mode) state<=LEGACY_START;
                    else begin state<=IDLE; busy_q<=0; done<=1; end
                end
                IDLE: begin
                    read_mode<=0; watchdog<=0;
                    if(legacy_start && control_idle) begin
                        legacy_mode<=1; legacy_n<=legacy_count; valid_count<=0;
                        generation<=generation+1'b1; cursor<=0; state<=CLEAR; busy_q<=1;
                        fault<=0; error_code<=0; done<=0;
                    end else if(reg_write && reg_address==8'h41) begin
                        done<=0; fault<=0; error_code<=0;
                        if(!control_idle) begin fault<=1; error_code<=1; done<=1; end
                        else if(reg_write_data==5) begin
                            cursor<=0; valid_count<=0; legacy_mode<=0;
                            generation<=generation+1'b1; state<=CLEAR; busy_q<=1;
                        end else if(reg_write_data==6) done<=1;
                        else if(selected>=2543 || reg_write_data<1 || reg_write_data>4) begin
                            fault<=1; error_code<=2; done<=1;
                        end else begin
                            target<=selected; expected_q<=expected;
                            operation<=reg_write_data[3:0]; state<=FETCH; busy_q<=1;
                        end
                    end
                end
                FETCH: state<=FETCH_RAM;
                FETCH_RAM: state<=DISPATCH;
                DISPATCH: begin
                    query_id<=target; query_data<=ram_q; old_valid<=ram_q[33:32]==2;
                    if(operation==1) begin actual<=ram_q[31:0]; done<=1; state<=IDLE; busy_q<=0; end
                    else if(operation==4) begin
                        ram_write<=1; ram_write_id<=target; ram_data<=0;
                        query_data<=0; actual<=0;
                        if(ram_q[33:32]==2) valid_count<=valid_count-1'b1;
                        generation<=generation+1'b1; done<=1; state<=IDLE; busy_q<=0;
                    end else if(!memory_enable || !calibrated || !upload_ready) begin
                        fault<=1; error_code<=8; done<=1; state<=IDLE; busy_q<=0;
                    end else if(operation==3 && ram_q[33:32]!=2) begin
                        fault<=1; error_code<=3; done<=1; state<=IDLE; busy_q<=0;
                    end else begin
                        if(operation==3) expected_q<=ram_q[31:0];
                        if(operation==2) begin
                            ram_write<=1; ram_write_id<=target; ram_data<={1'b0,2'd1,expected_q};
                            if(ram_q[33:32]==2) valid_count<=valid_count-1'b1;
                            generation<=generation+1'b1;
                        end
                        failed<=0; actual<=0; reset_cycles<=64; state<=RESET_FIFO;
                    end
                end
                RESET_FIFO: begin
                    fifo_reset<=1;
                    if(reset_cycles!=0) reset_cycles<=reset_cycles-1'b1;
                    else if(operation==2) state<=START_WRITE;
                    else state<=START_READ;
                end
                START_WRITE: begin
                    upload_base<=target; upload_count<=1; upload_start<=1;
                    watchdog<=0; state<=WAIT_WRITE;
                end
                WAIT_WRITE: begin
                    watchdog<=watchdog+1'b1;
                    if(upload_active) state<=WRITE_DONE;
                end
                WRITE_DONE: begin
                    watchdog<=watchdog+1'b1;
                    if(!upload_active && loaded && upload_ready) begin
                        watchdog<=0; state<=START_READ;
                    end
                end
                START_READ: if(memory_ready) begin
                    read_mode<=1; read_start<=1; crc<=32'hffffffff;
                    words<=0; state<=POP;
                end
                // CRC has one outstanding read and owns the FIFO exclusively.
                // Register its request: no other consumer can drain the word
                // between this availability check and the following read edge.
                POP: if(fifo_available) begin fifo_pop<=1; state<=WAIT_WORD; end
                WAIT_WORD: if(fifo_valid) begin
                    word_q<=host_bytes(fifo_data); nibble<=0; state<=CRC;
                end
                CRC: begin
                    crc<=crc_next;
                    if(nibble[0]) word_q<={word_q[119:0],8'b0};
                    if(nibble==31) begin
                        if(words==6143) begin actual<=~crc_next; state<=CRC_CHECK; end
                        else begin words<=words+1'b1; state<=POP; end
                    end else nibble<=nibble+1'b1;
                end
                CRC_CHECK: begin
                    crc_ok<=actual==expected_q && !failed;
                    state<=COMMIT;
                end
                COMMIT: if(upload_ready) begin
                    read_mode<=0; done<=1; state<=IDLE; busy_q<=0;
                    ram_write<=1; ram_write_id<=target;
                    if(crc_ok && !failed && !memory_error && !usb_overflow) begin
                        ram_data<={1'b1,2'd2,expected_q}; query_data<={1'b1,2'd2,expected_q};
                        if(operation==2) valid_count<=valid_count+1'b1;
                    end else begin
                        ram_data<={1'b0,2'd3,expected_q}; query_data<={1'b0,2'd3,expected_q};
                        fault<=1; error_code<=failed ? 7 : 4;
                        if(operation==3) begin
                            valid_count<=valid_count-1'b1; generation<=generation+1'b1;
                        end
                    end
                end
                ABORT_WAIT: if(upload_ready && !upload_active) begin
                    ram_write<=1; ram_write_id<=target; ram_data<={1'b0,2'd3,expected_q};
                    query_data<={1'b0,2'd3,expected_q};
                    fifo_reset<=1; done<=1; state<=IDLE; busy_q<=0;
                end
                LEGACY_START: begin
                    upload_base<=0; upload_count<=legacy_n; upload_start<=1; state<=LEGACY_WAIT;
                end
                LEGACY_WAIT: if(upload_active) begin state<=PREPARE; end
                PREPARE: if(!upload_active && loaded) begin cursor<=0; state<=LEGACY_FILL; end
                LEGACY_FILL: begin
                    ram_write<=1; ram_write_id<=cursor; ram_data<={1'b0,2'd2,32'b0};
                    if(cursor+1'b1==legacy_n) begin
                        valid_count<=legacy_n; legacy_mode<=0; state<=FLUSH;
                    end else cursor<=cursor+1'b1;
                end
                default: begin state<=IDLE; busy_q<=0; fault<=1; error_code<=7; end
            endcase
            if(read_mode && (memory_error || usb_overflow)) failed<=1;
            // Finish any partially submitted MIG burst before flushing USB FIFO.
            if((state==WAIT_WRITE || state==WRITE_DONE) &&
               (watchdog==UPLOAD_TIMEOUT || memory_error || usb_overflow ||
                (reg_write && reg_address==8'h41 && reg_write_data==6))) begin
                upload_abort<=1; state<=ABORT_WAIT; fault<=1;
                error_code<=watchdog==UPLOAD_TIMEOUT ? 5 :
                            (memory_error || usb_overflow) ? 7 : 6;
            end else if(reg_write && reg_address==8'h41 && state!=IDLE) begin
                // Busy commands cannot replace an in-flight operation or payload.
                if(reg_write_data!=6) begin fault<=1; error_code<=1; end
            end
        end
    end
    always @* begin
        case(reg_address)
            8'h40: reg_read_data={1'b0,selected};
            8'h41: reg_read_data={11'b0,initialized,(state==WRITE_DONE),fault,done,busy};
            8'h42: reg_read_data={13'b0,query_data[34:32]};
            8'h43: reg_read_data=expected[15:0];
            8'h44: reg_read_data=expected[31:16];
            8'h45: reg_read_data=actual[15:0];
            8'h46: reg_read_data=actual[31:16];
            8'h47: reg_read_data={1'b0,valid_count};
            8'h48: reg_read_data=2543;
            8'h49: reg_read_data=error_code;
            8'h4a: reg_read_data=generation[15:0];
            8'h4b: reg_read_data=generation[31:16];
            8'h4c: reg_read_data=session[15:0];
            8'h4d: reg_read_data=session[31:16];
            8'h4e: reg_read_data=16'h000f;
            8'h4f: reg_read_data=16'h0201;
            8'h50: reg_read_data={1'b0,query_id};
            8'h51: reg_read_data={3'b0,words};
            default: reg_read_data=16'hdead;
        endcase
    end
endmodule
