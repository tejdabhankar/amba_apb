//-----------------------------------------------------------------------------
// Company:         Vicharak Computers PVT LTD
// Engineer:        Kaushal Kumar Kumawat <kaushalkumawat1723@gmail.com>
// 
// Create Date:     June 1, 2024
// Design Name:     I2C_Physical_Layer
// Module Name:     i2c_phy.v
// Project:         PeriPlex
// Target Device:   Trion T120
// Tool Versions:   Efinix Efinity 2023.2 
// 
// Description: 
//    This module integrates I2C protocol modules, act as I2C interface.
// 
// Dependencies: 
//    i2c_ctrl.v, i2c_master.v
// 
// Version:
//    1.0 - 06/01/2024 - KKK - Initial release
//    1.1 - 11/11/2024 - KKK - Added I2C Detect
// 
// Additional Comments: 
//    This module assumes to take data and configuration from FIFOs.
//    It writes back the read data into FIFO.
//
// License: 
//    Proprietary © Vicharak Computers PVT LTD - 2024
//-----------------------------------------------------------------------------

module i2c_phy(
    /* Clock inputs */
    input                           clk,

    /* I2C Master-Slave Interfacing signals */
    input                           scl_in,
    input                           sda_in,
    output                          scl_out,
    output                          sda_out,
    output                          scl_oe,
    output                          sda_oe,

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
parameter CONFIG_DATA_WIDTH = 40;
parameter PHY_FIFO_WIDTH    = 8;
parameter I2C_ADDR_WIDTH    = 7;
parameter FIFO_COUNT_WIDTH = 10;

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
        if(reset && (r_config_data[39:32] == 8'h1)) begin
            r_config_data[0] <= 0;
        end
    end
end

reg [31:0]  config_clk_per_half_bit = 0;
reg         reset = 0;

always @(posedge clk) begin
    if(reset) begin
        reset <= 0;
    end

    case (r_config_data[39:32])
        8'h00: begin
            config_clk_per_half_bit <= r_config_data[31:0];
        end

        8'h01: begin
            reset <= r_config_data[0];
        end
    endcase
end

/* Connecting Wires */
wire                        w_i2c_busy;
wire                        w_write_done;
wire                        w_data_valid_out;
wire [PHY_FIFO_WIDTH-1:0]   w_data_out;
wire [PHY_FIFO_WIDTH-1:0]   w_cmd_byte;
wire [PHY_FIFO_WIDTH-1:0]   w_i2c_data;
wire [PHY_FIFO_WIDTH-1:0]   w_i2c_slv_addr;
wire [I2C_ADDR_WIDTH-1:0]   w_num_byte;
wire                        w_i2c_detect;
wire                        w_rw;
wire                        w_enable;
wire                        w_en_ack;

/* Module Instantiation */
i2c_ctrl i2cctrl(
    .clk            (clk),
    .reset          (reset),
    .f_empty        (wr_phy_fifo_empty),
    .fifo_read_data (wr_phy_fifo_data),
    .fifo_read_en   (wr_phy_fifo_en),
    .en_ack         (w_en_ack),
    .i2c_busy       (w_i2c_busy),
    .write_done     (w_write_done),
    .data_valid_out (w_data_valid_out),
    .data_out       (w_data_out),
    .i2c_data       (w_i2c_data),
    .i2c_slv_addr   (w_i2c_slv_addr),
    .num_byte       (w_num_byte),
    .i2c_detect     (w_i2c_detect),
    .rw             (w_rw),
    .en             (w_enable),
    .fifo_wr_en     (rd_phy_fifo_en),
    .fifo_wr_data   (rd_phy_fifo_data)
);

i2c_master#(
    .DATA_WIDTH (PHY_FIFO_WIDTH),
    .ADDR_WIDTH (I2C_ADDR_WIDTH) 
)i2cmaster(
    .i_clk              (clk),
    .reset              (reset),
    .i_enable           (w_enable),
    .i_rw               (w_rw),
    .i_mosi_data        (w_i2c_data),
    .i_device_addr      (w_i2c_slv_addr),
    .i_num_byte         (w_num_byte),
    .i_i2c_detect       (w_i2c_detect),
    .i_divider          (config_clk_per_half_bit), // value = 124 for 50 MHz clock freq.
    .o_miso_data        (w_data_out),
    .o_en_ack           (w_en_ack),
    .o_data_valid_out   (w_data_valid_out),
    .o_busy             (w_i2c_busy),
    .scl_in             (scl_in),
    .sda_in             (sda_in),
    .scl_out            (scl_out),
    .sda_out            (sda_out),
    .scl_oe             (scl_oe),
    .sda_oe             (sda_oe)
);
endmodule