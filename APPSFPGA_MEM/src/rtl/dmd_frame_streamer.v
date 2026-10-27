`timescale 1ns / 1ps
// DLP7000 global-update output at a 200 MHz application clock. Each row is
// buffered completely before its eight consecutive 128-bit transfers.
// Two row banks permit DDR prefetch while the preceding row is transmitted.
module dmd_frame_streamer(
    input clk, input reset, input start, input commit_allowed,
    input fifo_available, input fifo_valid, input [127:0] fifo_data,
    output fifo_pop, output busy, output reg done, output reg committed,
    output reg [63:0] data_a, output reg [63:0] data_b,
    output reg dvalid, output reg [1:0] row_mode,
    output reg [10:0] row_address,
    output reg [1:0] block_mode, output reg [3:0] block_address
);
    localparam IDLE=0, WAIT_ROW=1, SEND_ROW=2, ROW_GAP=3,
               WAIT_COMMIT=4, MCP=5, SETTLE=6;
    reg [2:0] state;
    reg [127:0] row_buffer [0:15];
    reg [1:0] bank_ready;
    reg fill_bank, send_bank;
    reg fetch_active;
    reg [3:0] requested;
    reg [2:0] received, beat;
    reg [9:0] rows_fetched, row;
    reg [11:0] settle_count;
    reg [1:0] gap_count;
    wire [127:0] word = row_buffer[{send_bank,beat}];
    // Same AB lane permutation as the original memory path.
    wire [127:0] swapped = {word[127:112],word[95:80],word[63:48],word[31:16],
                            word[111:96],word[79:64],word[47:32],word[15:0]};
    assign busy = state != IDLE;
    // Register row ownership/credit before the shared FIFO enable. The eighth
    // accepted request clears this flag immediately; the next row is admitted
    // only after all eight responses arrive and its buffer bank is available.
    // Reads still accept one word per clock and never reserve an empty FIFO.
    assign fifo_pop = fetch_active && fifo_available;
    always @(posedge clk) begin
        if (reset) begin
            state <= IDLE; bank_ready <= 0; fill_bank <= 0; send_bank <= 0; fetch_active <= 0;
            requested <= 0; received <= 0; rows_fetched <= 0; row <= 0;
            beat <= 0; settle_count <= 0; gap_count <= 0;
            data_a <= 0; data_b <= 0; dvalid <= 0; row_mode <= 0;
            row_address <= 0; block_mode <= 0; block_address <= 0;
            done <= 0; committed <= 0;
        end else begin
            done <= 0; committed <= 0; dvalid <= 0;
            row_mode <= 0; block_mode <= 0; block_address <= 0;
            if (!busy) fetch_active <= 0;
            else if (!fetch_active && requested == 0 && rows_fetched < 768 && !bank_ready[fill_bank])
                fetch_active <= 1;
            if (fifo_pop) begin
                requested <= requested + 1;
                if (requested == 7) fetch_active <= 0;
            end
            if (fifo_valid && busy) begin
                row_buffer[{fill_bank,received}] <= fifo_data;
                if (received == 7) begin
                    bank_ready[fill_bank] <= 1;
                    fill_bank <= !fill_bank; received <= 0; requested <= 0;
                    rows_fetched <= rows_fetched + 1;
                    fetch_active <= rows_fetched < 767 && !bank_ready[!fill_bank];
                end else received <= received + 1;
            end
            case (state)
                IDLE: if (start) begin
                    bank_ready <= 0; fill_bank <= 0; send_bank <= 0;
                    requested <= 0; received <= 0; rows_fetched <= 0;
                    row <= 0; beat <= 0; state <= WAIT_ROW; fetch_active <= 1;
                end
                WAIT_ROW: if (bank_ready[send_bank]) begin
                    beat <= 0; state <= SEND_ROW;
                end
                SEND_ROW: begin
                    dvalid <= 1; row_mode <= 2'b10; row_address <= {1'b0,row};
                    data_a <= swapped[127:64]; data_b <= swapped[63:0];
                    if (beat == 7) begin
                        bank_ready[send_bank] <= 0; send_bank <= !send_bank;
                        gap_count <= 0; state <= ROW_GAP;
                    end else beat <= beat + 1;
                end
                ROW_GAP: begin
                    // Two 200 MHz clocks between rows/commands (four DMD clocks).
                    if (gap_count == 1) begin
                        if (row == 767) state <= WAIT_COMMIT;
                        else begin row <= row + 1; state <= WAIT_ROW; end
                    end else gap_count <= gap_count + 1;
                end
                WAIT_COMMIT: if (commit_allowed) begin beat <= 0; state <= MCP; end
                MCP: begin
                    dvalid <= 1; block_mode <= 2'b11; block_address <= 4'b1000;
                    if (beat == 0) committed <= 1;
                    if (beat == 7) begin settle_count <= 2500; state <= SETTLE; end
                    else beat <= beat + 1;
                end
                SETTLE: begin
                    // 12.5 us after the *end* of MCP, before rewriting this block.
                    if (settle_count == 0) begin done <= 1; state <= IDLE; end
                    else settle_count <= settle_count - 1;
                end
                default: begin state <= IDLE; fetch_active <= 0; end
            endcase
        end
    end
endmodule
