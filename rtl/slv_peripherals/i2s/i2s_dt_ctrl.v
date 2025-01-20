//-----------------------------------------------------------------------------
// Company:         Vicharak Computers PVT LTD
// Engineer:        Tejas Dabhankar <tejasdabhankar123@gmail.com>
// 
// Create Date:     October 08, 2024
// Design Name:     I2S_data_Controller
// Module Name:     i2s_data_ctrl.v
// Project:         PeriPlex
// Target Device:   Trion T120
// Tool Versions:   Efinix Efinity 2023.2 
// 
// Description: 
//    This module access the data from periplex design and transfers
//    it to i2s_interface.
// 
// Dependencies: 
//    i2s_interface.v
// 
// Version:
//    1.0 - 10/08/2024 - TD - Initial release
// 
// Additional Comments: 
// 
// License: 
//    Proprietary © Vicharak Computers PVT LTD - 2024
//-----------------------------------------------------------------------------
module i2s_data_ctrl#(
parameter DATA_WIDTH = 32,
parameter CONFIG_DATA_WIDTH = 40,
parameter PHY_FIFO_WIDTH = 8) (
    /* Clock Signal */
    input                           clk,

    /* WR_FIFO Signals */
    input                           f_empty,
    input                           f_a_empty,
    input [PHY_FIFO_WIDTH-1:0]      fifo_read_data,
    input [CONFIG_DATA_WIDTH-1:0]   config_data,
    input                           config_write,
    output                          fifo_read_en,

    /* I2S Signals */
    output                          write,
    output [DATA_WIDTH-1:0]         audio_data,
    input                           f_full
);

/* Register declaration and instantiations */
reg [DATA_WIDTH-1:0]    r_audio_data = 0;
reg [23:0]              reset_counter = 0;
reg [1:0]               count = 0;
reg                     r_write = 0;
reg                     r_fifo_read_en = 0;
reg                     flag_data_sample = 0;

/* configuration register */
reg [CONFIG_DATA_WIDTH-1:0] r_config_data;
reg [3:0]                   BYTE_SIZE = 4;
reg                         data_collect;

always @(posedge clk) begin
    if (config_write) begin
        r_config_data <= config_data;
        data_collect <= 1'b1;
    end else begin
        r_config_data <= r_config_data;
        data_collect <=1'b0;
    end

    if (data_collect) begin
        BYTE_SIZE <= r_config_data [11:8];
    end else begin
        BYTE_SIZE <= BYTE_SIZE;
    end
 end

always @(posedge clk) begin
    /* Input FIFO read control */
    if (!f_empty && !f_full) begin
        r_fifo_read_en <= 1;
    end

    if ((f_a_empty && r_fifo_read_en) || f_full)begin
        r_fifo_read_en <= 0;
    end

    /* Control for data sample */
    flag_data_sample <= r_fifo_read_en;

    if(flag_data_sample) begin
        if(count == BYTE_SIZE-1) begin
            r_write <= 1;
            count <= 0;
        end else begin
            count <= count + 1;
            r_write <= 0;
        end
    end else begin
        r_write <= 0;
    end

    if(flag_data_sample) begin
        case (count)
            0: r_audio_data[31:24] <= fifo_read_data;  
            1: r_audio_data[23:16] <= fifo_read_data;
            2: r_audio_data[15:8] <= fifo_read_data;
            3: r_audio_data[7:0] <= fifo_read_data;
        endcase
    end

    if (count != 0) begin
        reset_counter <= reset_counter + 1'b1;
    end else begin
        reset_counter <= 0;
    end

    if (reset_counter > 5000000) begin
        count <= 0;
        r_audio_data <= 0;
        reset_counter <= 0;
    end
end

assign audio_data = r_audio_data;
assign write = r_write;
assign fifo_read_en = r_fifo_read_en;

endmodule
