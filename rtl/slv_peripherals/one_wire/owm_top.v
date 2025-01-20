//-----------------------------------------------------------------------------
// Company:         Vicharak Computers PVT LTD
// Engineer:        Tejas Dabhankar <tejasdabhankar123@gmail.com>
// 
// Create Date:     August 27, 2024
// Design Name:     One-wire_Physical_Layer
// Module Name:     owm_top.v
// Project:         PeriPlex
// Target Device:   Trion T120
// Tool Versions:   Efinix Efinity 2023.2 
// 
// Description: 
//    This module integrates all the One-Wire protocol modules, act as 
//    One-Wire interface.
// 
// Dependencies: 
//    one_wire_data_ctrl.v, one_wire_interface.v
// 
// Version:
//    1.0 - 08/27/2024 - TD - Initial release
// 
// Additional Comments: 
//    This module assumes to take data and configuration from FIFOs.
//    It writes back the read data into FIFO.
// 
// License: 
//    Proprietary © Vicharak Computers PVT LTD - 2024
//-----------------------------------------------------------------------------

module OW_phy (
/* clock input */
    input                       clk,

/* one wire data pins */
    input                       data_in,
    output                      data_out,
    output                      data_oe,

/* wr_phy_fifo access */
    input                       wr_phy_fifo_empty,
    output                      wr_phy_fifo_en,
    input [PHY_FIFO_WIDTH-1:0]  wr_phy_fifo_data,

    output                      rd_phy_fifo_en,
    output [PHY_FIFO_WIDTH-1:0] rd_phy_fifo_data
);

/* Gloabal parameters */
parameter PHY_FIFO_WIDTH    = 8;
parameter CONFIG_DATA_WIDTH = 40;
parameter FIFO_WIDTH = 8;

/* data control wires */
wire [3:0] w_length;
wire [7:0] w_data;
wire [3:0] w_command;
wire w_write;
wire [7:0] w_data_out;
wire w_ow_busy;

/* one wire data control */
one_wire_data_ctrl owm_dt_ctrl(
    .clk(clk),

    /* fifo signal */
    .fifo_empty(wr_phy_fifo_empty),
    .fifo_read_data(wr_phy_fifo_data),
    .fifo_read_enable(wr_phy_fifo_en),

    /* Interface signal */
    .presence_detect (w_presence_detect),
    .length(w_length),
    .command(w_command),
    .ow_busy(w_ow_busy),
    .data(w_data),

    /* output to start the interface */
    .write(w_write)
);

/* one wire interface */
one_wire_interface #(
    .FIFO_WIDTH(FIFO_WIDTH)
) owm_interface (
    .clk(clk),

    /* input from the Controller */
    .presence_detect (w_presence_detect),
    .length(w_length),
    .command(w_command),
    .ow_busy(w_ow_busy),
    .data(w_data),
    .write(w_write),

    .rd_dt_en(rd_phy_fifo_en),
    .read_data(rd_phy_fifo_data),

    /* output signals */
    .data_in(data_in),
    .data_out(data_out),
    .data_oe(data_oe)
);

endmodule
