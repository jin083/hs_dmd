`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    20:57:58 05/11/2021 
// Design Name: 
// Module Name:    mig 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module MEM_IO_Verilog#(
	parameter BANK_WIDTH              = 3,       
										// # of memory bank addr bits.
	parameter CKE_WIDTH               = 2,       
										// # of memory clock enable outputs.
	parameter CLK_WIDTH               = 2,       
										// # of clock outputs.
	parameter COL_WIDTH               = 10,       
										// # of memory column bits.
	parameter CS_NUM                  = 2,       
										// # of separate memory chip selects.
	parameter CS_WIDTH                = 2,       
										// # of total memory chip selects.
	parameter CS_BITS                 = 1,       
										// set to log2(CS_NUM) (rounded up).
	parameter DM_WIDTH                = 8,       
										// # of data mask bits.
	parameter DQ_WIDTH                = 64,       
										// # of data width.
	parameter DQ_PER_DQS              = 8,       
										// # of DQ data bits per strobe.
	parameter DQS_WIDTH               = 8,       
										// # of DQS strobes.
	parameter DQ_BITS                 = 6,       
										// set to log2(DQS_WIDTH*DQ_PER_DQS).
	parameter DQS_BITS                = 3,       
										// set to log2(DQS_WIDTH).
	parameter ODT_WIDTH               = 2,       
										// # of memory on-die term enables.
	parameter ROW_WIDTH               = 14,       
										// # of memory row and # of addr bits.
	parameter ADDITIVE_LAT            = 0,       
										// additive write latency.
	parameter BURST_LEN               = 4,       
										// burst length (in double words).
	parameter BURST_TYPE              = 0,       
										// burst type (=0 seq; =1 interleaved).
	parameter CAS_LAT                 = 3,       
										// CAS latency.
	parameter ECC_ENABLE              = 0,       
										// enable ECC (=1 enable).
	parameter APPDATA_WIDTH           = 128,       
										// # of usr read/write data bus bits.
	parameter MULTI_BANK_EN           = 1,       
										// Keeps multiple banks open. (= 1 enable).
	parameter TWO_T_TIME_EN           = 1,       
										// 2t timing for unbuffered dimms.
	parameter ODT_TYPE                = 1,       
										// ODT (=0(none),=1(75),=2(150),=3(50)).
	parameter REDUCE_DRV              = 0,       
										// reduced strength mem I/O (=1 yes).
	parameter REG_ENABLE              = 0,       
										// registered addr/ctrl (=1 yes).
	parameter TREFI_NS                = 7800,       
										// auto refresh interval (ns).
	parameter TRAS                    = 40000,       
										// active->precharge delay.
	parameter TRCD                    = 15000,       
										// active->read/write delay.
	parameter TRFC                    = 127500,       
										// refresh->refresh, refresh->active delay.
	parameter TRP                     = 15000,       
										// precharge->command delay.
	parameter TRTP                    = 7500,       
										// read->precharge delay.
	parameter TWR                     = 15000,       
										// used to determine write->precharge.
	parameter TWTR                    = 7500,       
										// write->read delay.
	parameter HIGH_PERFORMANCE_MODE   = "TRUE",       
								// # = TRUE, the IODELAY performance mode is set
								// to high.
								// # = FALSE, the IODELAY performance mode is set
								// to low.
	parameter SIM_ONLY                = 0,       
										// = 1 to skip SDRAM power up delay.
	parameter DEBUG_EN                = 0,       
										// Enable debug signals/controls.
										// When this parameter is changed from 0 to 1,
										// make sure to uncomment the coregen commands
										// in ise_flow.bat or create_ise.bat files in
										// par folder.
	parameter CLK_PERIOD              = 6666,       
										// Core/Memory clock period (in ps).
	parameter RST_ACT_LOW             = 1        
										// =1 for active low reset, =0 for active high.
   )
(
	inout  [DQ_WIDTH-1:0]              ddr2_dq,
	output [ROW_WIDTH-1:0]             ddr2_a,
	output [BANK_WIDTH-1:0]            ddr2_ba,
	output                             ddr2_ras_n,
	output                             ddr2_cas_n,
	output                             ddr2_we_n,
	output [CS_WIDTH-1:0]              ddr2_cs_n,
	output [ODT_WIDTH-1:0]             ddr2_odt,
	output [CKE_WIDTH-1:0]             ddr2_cke,
	output [DM_WIDTH-1:0]              ddr2_dm,
	output                             mem_init_done,
	inout  [DQS_WIDTH-1:0]             ddr2_dqs,
	inout  [DQS_WIDTH-1:0]             ddr2_dqs_n,
	output [CLK_WIDTH-1:0]             ddr2_ck,
	output [CLK_WIDTH-1:0]             ddr2_ck_n,
	
	input mem_clk0,
	input mem_clk2x,
	input mem_clk2x90,
	input mem_clk200,
	input pll_mem_locked,
	input system_clk,
	input system_reset,
	output mem_preload_done,
	output[14:0] rd_pattern_id,
	input mem_read_enable,
	input[14:0] num_patterns,
	input[2:0] update_mode,
//	input dmd_1080p_connected,
	input [127:0] wr_data,
	input wr_valid,
	input wr_data_valid,
	output mem_get_data,
	output[127:0] rd_ab_fifo_out,
	output[127:0] rd_cd_fifo_out,
	input dmd_get_data,
	output rd_ab_fifo_valid,
	output rd_cd_fifo_valid,
	output rd_ab_fifo_data_valid,
	output rd_cd_fifo_data_valid,
	input mem_rd_fifo_reset,
    input upload_start,
    input [14:0] selected_pattern,
    output upload_active, output memory_ready, output upload_ready,
    output memory_error, output [14:0] uploaded_patterns
    );


    wire rst0, phy_init_done;
    wire system_reset_n = ~system_reset;
    wire app_af_afull, app_wdf_afull, rd_data_valid;
    wire [127:0] rd_data_fifo_out;
    wire app_af_wren, app_wdf_wren;
    wire [2:0] app_af_cmd;
    wire [30:0] app_af_addr;
    wire [127:0] app_wdf_data;
    wire [15:0] app_wdf_mask_data = 16'b0;
    wire fifo_write, fifo_full, fifo_prog_full, fifo_empty;
    wire [127:0] fifo_data;
    wire loaded_m, active_m, ready_m, idle_m, error_m;
    wire [14:0] uploaded_m;
    reg read_toggle, upload_toggle;
    reg [14:0] read_id_hold, count_hold;
    (* ASYNC_REG = "TRUE" *) reg read_meta, read_sync, upload_meta, upload_sync;
    reg read_previous, upload_previous;
    (* ASYNC_REG = "TRUE" *) reg [5:0] status_meta, status_sync;
    reg [14:0] uploaded_gray;
    (* ASYNC_REG = "TRUE" *) reg [14:0] uploaded_meta, uploaded_sync;
    wire [14:0] uploaded_binary;
    // Bundled data remains stable from before the synchronized toggle arrives
    // until after the transaction finishes. There is only one request in flight.
    always @(posedge system_clk) begin
        if (system_reset) begin
            read_toggle <= 0; upload_toggle <= 0; read_id_hold <= 0; count_hold <= 0;
            status_meta <= 0; status_sync <= 0;
            uploaded_meta <= 0; uploaded_sync <= 0;
        end else begin
            if (mem_read_enable) begin
                read_id_hold <= selected_pattern; read_toggle <= !read_toggle;
            end
            if (upload_start) begin
                count_hold <= num_patterns; upload_toggle <= !upload_toggle;
            end
            status_meta <= {error_m,idle_m,ready_m,active_m,loaded_m,phy_init_done};
            status_sync <= status_meta;
            uploaded_meta <= uploaded_gray; uploaded_sync <= uploaded_meta;
        end
    end
    always @(posedge mem_clk2x) begin
        if (rst0) begin
            read_meta <= 0; read_sync <= 0; read_previous <= 0;
            upload_meta <= 0; upload_sync <= 0; upload_previous <= 0;
            uploaded_gray <= 0;
        end else begin
            read_meta <= read_toggle; read_sync <= read_meta; read_previous <= read_sync;
            upload_meta <= upload_toggle; upload_sync <= upload_meta;
            upload_previous <= upload_sync;
            uploaded_gray <= uploaded_m ^ (uploaded_m >> 1);
        end
    end
    genvar n;
    generate for (n=0;n<15;n=n+1) begin: gray_decode
        assign uploaded_binary[n] = ^uploaded_sync[14:n];
    end endgenerate
    assign uploaded_patterns = uploaded_binary;
    assign mem_init_done = status_sync[0];
    assign mem_preload_done = status_sync[1];
    assign upload_active = status_sync[2];
    assign memory_ready = status_sync[3];
    assign upload_ready = status_sync[4];
    assign memory_error = status_sync[5];
    assign rd_pattern_id = read_id_hold;
    assign rd_cd_fifo_out = 0;
    assign rd_cd_fifo_valid = 0;
    assign rd_cd_fifo_data_valid = 0;
    assign rd_ab_fifo_valid = !fifo_empty;
    ddr_pattern_engine engine(
        .clk(mem_clk2x), .reset(rst0), .calibrated(phy_init_done),
        .begin_upload(upload_sync ^ upload_previous), .pattern_count(count_hold),
        .upload_active(active_m), .loaded(loaded_m), .uploaded_patterns(uploaded_m),
        .read_start(read_sync ^ read_previous), .read_pattern(read_id_hold),
        .ready(ready_m), .idle(idle_m), .error(error_m),
        .usb_data(wr_data), .usb_available(wr_valid), .usb_valid(wr_data_valid),
        .usb_pop(mem_get_data), .af_full(app_af_afull), .wdf_full(app_wdf_afull),
        .af_write(app_af_wren), .af_command(app_af_cmd), .af_address(app_af_addr),
        .wdf_write(app_wdf_wren), .wdf_data(app_wdf_data),
        .rd_valid(rd_data_valid), .rd_data(rd_data_fifo_out),
        .out_almost_full(fifo_prog_full), .out_full(fifo_full),
        .out_write(fifo_write), .out_data(fifo_data)
    );
    read_fifo rd_ab_fifo (
        .wr_clk(mem_clk2x), .rd_clk(system_clk), .rst(rst0 | mem_rd_fifo_reset),
        .wr_en(fifo_write), .rd_en(dmd_get_data), .din(fifo_data),
        .dout(rd_ab_fifo_out), .valid(rd_ab_fifo_data_valid),
        .full(fifo_full), .prog_full(fifo_prog_full), .prog_empty(),
        .almost_full(), .empty(fifo_empty)
    );

	mig_top u_mig_top (
	.ddr2_dq(ddr2_dq),
   .ddr2_a(ddr2_a),
   .ddr2_ba(ddr2_ba),
   .ddr2_ras_n(ddr2_ras_n),
   .ddr2_cas_n(ddr2_cas_n),
   .ddr2_we_n(ddr2_we_n),
   .ddr2_cs_n(ddr2_cs_n),
   .ddr2_odt(ddr2_odt),
   .ddr2_cke(ddr2_cke),
   .ddr2_dm(ddr2_dm),
   .sys_rst_n(system_reset_n),
   .phy_init_done(phy_init_done),
   .rst0_tb(rst0),
   .clk0_tb(),
   .locked(pll_mem_locked),
   .clk0(mem_clk2x),
   .clk90(mem_clk2x90),
   .clkdiv0(mem_clk0),
   .clk200(mem_clk200),
   .app_wdf_afull(app_wdf_afull),
   .app_af_afull(app_af_afull),
   .rd_data_valid(rd_data_valid),
   .app_wdf_wren(app_wdf_wren),
   .app_af_wren(app_af_wren),
   .app_af_addr(app_af_addr),
   .app_af_cmd(app_af_cmd),
   .rd_data_fifo_out(rd_data_fifo_out),
   .app_wdf_data(app_wdf_data),
   .app_wdf_mask_data(app_wdf_mask_data),
   .ddr2_dqs(ddr2_dqs),
   .ddr2_dqs_n(ddr2_dqs_n),
   .ddr2_ck(ddr2_ck),
   .ddr2_ck_n(ddr2_ck_n)
	);
	
endmodule
