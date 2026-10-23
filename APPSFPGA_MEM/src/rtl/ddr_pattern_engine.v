`timescale 1ns / 1ps
// MIG user-port controller. Addresses retain the original {pattern,offset,00}
// layout. One BL4 command transfers exactly two 128-bit words; no dummy words.
// All ports are in the MIG clk0 (150 MHz) domain.
module ddr_pattern_engine(
    input clk, input reset, input calibrated,
    input begin_upload, input [14:0] pattern_count,
    output reg upload_active, output reg loaded,
    output reg [14:0] uploaded_patterns,
    input read_start, input [14:0] read_pattern,
    output ready, output idle, output reg error,
    input [127:0] usb_data, input usb_available, input usb_valid,
    output usb_pop,
    input af_full, input wdf_full,
    output af_write, output [2:0] af_command, output [30:0] af_address,
    output wdf_write, output [127:0] wdf_data,
    input rd_valid, input [127:0] rd_data,
    input out_almost_full, input out_full,
    output out_write, output [127:0] out_data
);
    localparam IDLE=0, GET0=1, GET1=2, WAIT1=3, DATA0=4, DATA1=5,
               COMMAND=6, READ=7, DRAIN=8;
    reg [3:0] state;
    reg [127:0] word0, word1;
    reg [14:0] count_q, pattern_q;
    reg [13:0] offset_q;
    reg [6:0] pending_words;
    wire issue_read = state == READ && !af_full && !out_almost_full &&
                      pending_words < 32 && calibrated;
    wire issue_write = state == COMMAND && !af_full && calibrated;
    // Read data cannot be stalled at the MIG port. prog_full is asserted at
    // 20/2048 words in the supplied FIFO, leaving room for all 32 outstanding.
    assign out_write = rd_valid && !out_full;
    assign out_data = rd_data;
    assign ready = state == IDLE && !upload_active && loaded && calibrated;
    assign idle = state == IDLE && !upload_active && calibrated;
    assign usb_pop = calibrated && usb_available &&
                     ((state == IDLE && upload_active && !begin_upload) || state == GET1);
    assign af_write = issue_read || issue_write;
    assign af_command = issue_read ? 3'b001 : 3'b000;
    assign af_address = {pattern_q, offset_q, 2'b00};
    assign wdf_write = (state == DATA0 || state == DATA1) && !wdf_full && calibrated;
    assign wdf_data = state == DATA0 ? word0 : word1;
    always @(posedge clk) begin
        if (reset) begin
            state <= IDLE; upload_active <= 0; loaded <= 0; error <= 0;
            uploaded_patterns <= 0; count_q <= 0; pattern_q <= 0;
            offset_q <= 0; pending_words <= 0; word0 <= 0; word1 <= 0;
        end else begin
            if (rd_valid && (out_full || pending_words == 0)) error <= 1;
            case ({issue_read, rd_valid})
                2'b10: pending_words <= pending_words + 2;
                2'b01: pending_words <= pending_words - 1;
                2'b11: pending_words <= pending_words + 1;
                default: ;
            endcase
            if (begin_upload) begin
                // The system interface issues this only while idle. Refuse
                // an unsafe restart rather than abandoning half a MIG burst.
                if (state == IDLE && !upload_active && calibrated &&
                    pattern_count > 0 && pattern_count <= 2543) begin
                    upload_active <= 1; loaded <= 0; error <= 0;
                    uploaded_patterns <= 0; count_q <= pattern_count;
                    pattern_q <= 0; offset_q <= 0;
                end else error <= 1;
            end
            case (state)
                IDLE: begin
                    if (usb_pop) state <= GET0;
                    else if (read_start) begin
                        if (ready && read_pattern < count_q) begin
                            pattern_q <= read_pattern; offset_q <= 0; state <= READ;
                        end else error <= 1;
                    end
                end
                GET0: if (usb_valid) begin word0 <= usb_data; state <= GET1; end
                GET1: if (usb_pop) state <= WAIT1;
                WAIT1: if (usb_valid) begin word1 <= usb_data; state <= DATA0; end
                DATA0: if (wdf_write) state <= DATA1;
                DATA1: if (wdf_write) state <= COMMAND;
                COMMAND: if (issue_write) begin
                    state <= IDLE;
                    if (offset_q == 3071) begin
                        offset_q <= 0;
                        uploaded_patterns <= uploaded_patterns + 1;
                        if (pattern_q + 1 == count_q) begin
                            upload_active <= 0; loaded <= 1;
                        end else pattern_q <= pattern_q + 1;
                    end else offset_q <= offset_q + 1;
                end
                READ: if (issue_read) begin
                    if (offset_q == 3071) state <= DRAIN;
                    else offset_q <= offset_q + 1;
                end
                DRAIN: if (pending_words == 0) state <= IDLE;
                default: begin state <= IDLE; error <= 1; end
            endcase
        end
    end
endmodule
