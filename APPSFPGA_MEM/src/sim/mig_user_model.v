`timescale 1ns/1ps
// Test double for the MIG *user port*, not an electrical DDR2 model. It accepts
// independent command/data FIFO writes, delays reads and injects backpressure.
module mig_top(
    inout [63:0] ddr2_dq, output [13:0] ddr2_a, output [2:0] ddr2_ba,
    output ddr2_ras_n, ddr2_cas_n, ddr2_we_n,
    output [1:0] ddr2_cs_n, ddr2_odt, ddr2_cke, output [7:0] ddr2_dm,
    input sys_rst_n, output reg phy_init_done, output rst0_tb, output clk0_tb,
    input locked, clk0, clk90, clkdiv0, clk200,
    output app_wdf_afull, app_af_afull, output reg rd_data_valid,
    input app_wdf_wren, app_af_wren, input [30:0] app_af_addr,
    input [2:0] app_af_cmd, output reg [127:0] rd_data_fifo_out,
    input [127:0] app_wdf_data, input [15:0] app_wdf_mask_data,
    inout [7:0] ddr2_dqs, ddr2_dqs_n, output [1:0] ddr2_ck, ddr2_ck_n
);
    reg [127:0] memory [0:30719];
    reg [127:0] write_queue [0:63];
    integer read_queue [0:63];
    integer write_head, write_tail, read_head, read_tail, cycle, address;
    integer burst_address;
    reg second_word;
    reg [31:0] random_q;
    assign rst0_tb = !sys_rst_n;
    assign clk0_tb = clk0;
    assign app_af_afull = random_q[3:0] < 4 || read_tail-read_head > 48;
    assign app_wdf_afull = random_q[7:4] < 5;
    always @(posedge clk0) begin
        if (!sys_rst_n) begin
            phy_init_done <= 0; rd_data_valid <= 0; rd_data_fifo_out <= 0;
            write_head = 0; write_tail = 0; read_head = 0; read_tail = 0;
            cycle = 0; second_word = 0; burst_address = 0;
            random_q <= 32'h12345678;
        end else begin
            cycle = cycle + 1;
            if (cycle > 30) phy_init_done <= 1;
            random_q <= {random_q[30:0],random_q[31]^random_q[21]^random_q[1]^random_q[0]};
            rd_data_valid <= 0;
            if (app_wdf_wren) begin
                if (app_wdf_afull || app_wdf_mask_data != 0) begin
                    $display("FAIL: invalid MIG write-data handshake"); $finish;
                end
                write_queue[write_tail%64] = app_wdf_data; write_tail = write_tail+1;
            end
            if (app_af_wren) begin
                if (app_af_afull || app_af_addr[1:0] != 0 ||
                    app_af_addr[15:2] >= 3072 || app_af_addr[30:16] >= 5) begin
                    $display("FAIL: invalid/extra MIG command %h",app_af_addr); $finish;
                end
                address = app_af_addr[30:16]*6144 + app_af_addr[15:2]*2;
                if (app_af_cmd == 0) begin
                    if (write_tail-write_head < 2) begin
                        $display("FAIL: incomplete MIG write burst"); $finish;
                    end
                    memory[address] = write_queue[write_head%64];
                    memory[address+1] = write_queue[(write_head+1)%64];
                    write_head = write_head+2;
                end else if (app_af_cmd == 1) begin
                    read_queue[read_tail%64] = address; read_tail = read_tail+1;
                end else begin $display("FAIL: unknown MIG command"); $finish; end
            end
            if (random_q[11:8] > 2) begin
                if (second_word) begin
                    rd_data_fifo_out <= memory[burst_address+1]; rd_data_valid <= 1;
                    second_word = 0;
                end else if (read_head < read_tail && cycle%13 != 0) begin
                    burst_address = read_queue[read_head%64]; read_head = read_head+1;
                    rd_data_fifo_out <= memory[burst_address]; rd_data_valid <= 1;
                    second_word = 1;
                end
            end
        end
    end
endmodule
