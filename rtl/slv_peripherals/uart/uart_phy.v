//-----------------------------------------------------------------------------
// Company:         Vicharak Computers PVT LTD
// Engineer:        Kaushal Kumar Kumawat <kaushalkumawat1723@gmail.com>
// 
// Create Date:     June 1, 2024
// Design Name:     UART_Physical_Layer
// Module Name:     uart_phy.v
// Project:         PeriPlex
// Target Device:   Trion T120
// Tool Versions:   Efinix Efinity 2023.2 
// 
// Description: 
//    This module integrates all the UART protocol modules, act as 
//    UART interface.
// 
// Dependencies: 
//    uart_ctrl.v, uart_rx.v, uart_tx.v
// 
// Version:
//    1.0 - 06/01/2024 - KKK - Initial release
// 
// Additional Comments: 
//    This module assumes to take data and configuration from FIFOs.
//    It writes back the read data into FIFO.
// 
// License: 
//    Proprietary © Vicharak Computers PVT LTD - 2024
//-----------------------------------------------------------------------------

module uart_phy(
    /* Clock inputs */
    input                           clk,

    /* UART Signals */
    output                          tx_active,
    output                          tx_done,
    output                          tx_serial,
    input                           rx_serial,
    
    /* wr_phy_fifo access */
    input                           wr_phy_fifo_empty,
    output                          wr_phy_fifo_en,
    input [PHY_FIFO_WIDTH-1:0]      wr_phy_fifo_data,
    
    /* Config_fifo access */
    output                          config_fifo_en,
    input [CONFIG_DATA_WIDTH-1:0]   config_fifo_data,
    input                           config_fifo_empty,

    
    /* rd_phy_fifo access */
    output                          rd_phy_fifo_en,
    output [PHY_FIFO_WIDTH-1:0]     rd_phy_fifo_data
);

/* Gloabal parameters */
parameter PHY_FIFO_WIDTH    = 8;
parameter CONFIG_DATA_WIDTH = 40;

/* Connecting Wires */
wire                        w_uart_dv;
wire [PHY_FIFO_WIDTH-1:0]   w_uart_data;
wire [PHY_FIFO_WIDTH-1:0]   w_rx_byte;
wire                        w_rx_dv;

/* Configuration FIFO access */
reg                         flag_data_sample = 0;
reg [CONFIG_DATA_WIDTH-1:0] r_config_data = 0;
reg                         r_config_fifo_en = 0;

assign config_fifo_en = r_config_fifo_en;

always @(posedge clk) begin
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
    end else begin
        r_config_data <= r_config_data;
    end
end

/* Module Instantiation */
/* UART Tx Modules */
uart_ctrl #(
    .PHY_FIFO_WIDTH(PHY_FIFO_WIDTH),
    .UART_DATA_WIDTH(PHY_FIFO_WIDTH)
) uart_write_ctrl(
    .clk            (clk),
    .f_empty        (wr_phy_fifo_empty),
    .fifo_read_en   (wr_phy_fifo_en),
    .fifo_read_data (wr_phy_fifo_data),
    .uart_tx_done   (tx_done),
    .uart_dv        (w_uart_dv),
    .uart_data      (w_uart_data)
);

uart_tx uarttx (
    .i_Clock            (clk),
    .i_Tx_DV            (w_uart_dv),
    .i_Tx_Byte          (w_uart_data),
    .uart_config_data   (r_config_data),
    .o_Tx_Active        (tx_active),
    .o_Tx_Serial        (tx_serial),
    .o_Tx_Done          (tx_done)
);

/* UART Rx Modules */
uart_rx uartrx(
    .i_Clock            (clk),
    .i_Rx_Serial        (rx_serial),
    .uart_config_data   (r_config_data),
    .o_Rx_DV            (rd_phy_fifo_en),
    .o_Rx_Byte          (rd_phy_fifo_data)
);

endmodule