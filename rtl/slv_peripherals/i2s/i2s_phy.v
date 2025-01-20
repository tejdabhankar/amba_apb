//-----------------------------------------------------------------------------
// Company:         Vicharak Computers PVT LTD
// Engineer:        Tejas Dabhankar <tejasdabhankar123@gmail.com>
// 
// Create Date:     October 08, 2024
// Design Name:     I2S_Physical_Layer
// Module Name:     i2s_phy.v
// Project:         PeriPlex
// Target Device:   Trion T120
// Tool Versions:   Efinix Efinity 2023.2 
// 
// Description: 
//    This module integrates all the I2S protocol modules, act as 
//    I2S interface.
// 
// Dependencies: 
//    i2s_dt_ctrl.v, i2s_interface.v
// 
// Version:
//    1.0 - 10/08/2024 - TD - Initial release
// 
// Additional Comments: 
//    This module assumes to take data and configuration from FIFOs.
// 
// License: 
//    Proprietary © Vicharak Computers PVT LTD - 2024
//-----------------------------------------------------------------------------
module i2s_phy (
    /* CLK Signals */
    input                          clk1,
    input                          clk2,

    /* wr_phy_fifo access */
    input                          wr_phy_fifo_empty,
    input                          wr_phy_fifo_a_empty,
    output                         wr_phy_fifo_en,
    input [PHY_FIFO_WIDTH-1:0]     wr_phy_fifo_data,

	/* peripherals signal */
    input                          i2s_sdi,
    output                         i2s_sdo,
    output                         i2s_lrck,
    output                         i2s_sclk,

    /* Config_fifo access */
    input [CONFIG_DATA_WIDTH-1:0]  config_fifo_data,
    input                          config_fifo_empty,
    output                         config_fifo_en,
    
    output                          rd_phy_fifo_en,
    output [PHY_FIFO_WIDTH-1:0] 	rd_phy_fifo_data
);

/* Gloabal parameters */
parameter PHY_FIFO_WIDTH = 8;
parameter CONFIG_DATA_WIDTH = 40;
parameter FIFO_WIDTH = 8;

/* Configuration FIFO access */
reg                         flag_data_sample = 0;
reg [CONFIG_DATA_WIDTH-1:0] r_config_data = 0;
reg                         r_config_fifo_en = 0;
reg                         r_config_write = 0;
reg [CONFIG_DATA_WIDTH-1:0] r_config_data_out;
reg                         r_config_write_out;
reg                         rd_fifo_en;

/* Output Assignment */
assign config_fifo_en = r_config_fifo_en;
assign config_write = r_config_write_out;
assign config_data_out = r_config_data_out;
assign w_rd_fifo_en = rd_fifo_en;
assign rd_phy_fifo_en = rd_fifo_en;

always @(posedge clk2) begin
    if(!config_fifo_empty) begin
        r_config_fifo_en <= 1;
    end else begin
        r_config_fifo_en <= 0;
    end

    if (r_config_fifo_en) begin
        flag_data_sample <= 1;
    end else begin
        flag_data_sample <= 0;
    end

    if(flag_data_sample) begin
        r_config_data <= config_fifo_data;
        r_config_write <= 1'b1;
    end else begin
        r_config_data <= r_config_data;
        r_config_write <= 1'b0;
    end
end

always @(posedge clk1) begin
    r_config_data_out <= r_config_data;
    r_config_write_out <= r_config_write;
    
    if (!w_r_f_empty) begin
        rd_fifo_en <= 1'b1;
    end else begin
        rd_fifo_en <= 1'b0;
    end 
end

/* wire Instatiation */
wire [31:0] w_wr_audio_data;
wire [31:0] w_rd_audio_data;

wire [7:0] w_wr_read_data;
wire [7:0] w_rd_read_data;
/* Module Instantiations */
i2s_data_ctrl i2s_dt_ctrl (
    /* Clock Signal */
    .clk            (clk2), 
    .f_empty        (wr_phy_fifo_empty),
    .f_a_empty      (wr_phy_fifo_a_empty),
    .fifo_read_data (wr_phy_fifo_data),
    .fifo_read_en   (wr_phy_fifo_en),
    .write          (w_write),
    .config_data    (r_config_data_out),
    .config_write   (r_config_write_out),
    .f_full         (w_f_full),
    .audio_data     (w_wr_audio_data)
);

i2s_write_fifo i2s_write_fifo(
    .wr_clk_i       (clk2),
    .rd_clk_i       (clk1),
    .wr_en_i        (w_write),
    .wdata          (w_wr_audio_data),
    .rd_en_i        (w_rd_en),
    .rdata          (w_rd_audio_data),
    .empty_o        (w_f_empty),
    .almost_full_o  (w_f_full)
);

i2s_read_fifo i2s_rd_fifo(
    .wr_clk_i       (clk1),
    .rd_clk_i       (clk1),
    .wr_en_i        (w_r_write),
    .wdata          (w_wr_read_data),
    .rd_en_i        (w_rd_fifo_en),
    .rdata          (rd_phy_fifo_data),
    .empty_o        (w_r_f_empty)

);

i2s_master interface(
    .clk            (clk1),
    .f_empty        (w_f_empty),
    .rd_en          (w_rd_en),
    .config_data    (r_config_data_out),
    .config_write   (r_config_write_out),
    .audio_data     (w_rd_audio_data),
    .i2s_sclk       (i2s_sclk),
    .i2s_lrck       (i2s_lrck),
    .i2s_sdo        (i2s_sdo),
    .i2s_sdi        (i2s_sdi),
    .collected_data (w_wr_read_data),
	.read_enable    (w_r_write)
);

endmodule
