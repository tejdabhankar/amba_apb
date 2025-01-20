//-----------------------------------------------------------------------------
// Company:         Vicharak Computers PVT LTD
// Engineer:        Tejas Dabhankar <tejasdabhankar123@gmail.com>
// Create Date:     October 08, 2024
// Design Name:     I2s_Interface
// Module Name:     i2s_interface.v
// Project:         PeriPlex
// Target Device:   Trion T120
// Tool Versions:   Efinix Efinity 2023.2 
// 
// Description: 
//    This module implements i2s protocol to send data to i2s Bus.
// 
// Dependencies: 
// 
// Version:
//    1.0 - 08/27/2024 - TD - Initial release
// 
// Additional Comments: 
// 
// License: 
//    Proprietary © Vicharak Computers PVT LTD - 2024
//-----------------------------------------------------------------------------

module i2s_master #(
parameter DATA_WIDTH = 32,
parameter CONFIG_DATA_WIDTH = 40) (
/* input clk */
    input                           clk,

/* dt_ctrl data */
    input                           f_empty,
    input [DATA_WIDTH-1:0]          audio_data,
    output                          rd_en,

/* output */
    input [CONFIG_DATA_WIDTH-1:0]   config_data,
    input                           config_write,
    
    output [7:0]                    collected_data,
    output                          read_enable,

    input                           i2s_sdi,
    output                          i2s_sclk,
    output                          i2s_lrck,
    output                          i2s_sdo
);

reg [9:0] 	clk_counter = 0;
reg [9:0] 	lrck_counter = 0;
reg	        r_rd_en;
reg [31:0]	r_audio_data = 0;
reg [5:0]	bit_counter = 6'd31;

reg posedge_sclk;
reg negedge_sclk;
reg posedge_lrck;
reg negedge_lrck;

/* output register */
reg r_sclk;
reg r_shifted_sclk1;
reg r_shifted_sclk2;
reg r_shifted_lrck;
reg r_lrck;
reg temp_lrck;
reg r_sdo;

/* configuration register */
reg [CONFIG_DATA_WIDTH-1:0]	 r_config_data;
reg [3:0]                    BYTE_SIZE = 4;
reg [7:0]                    CLOCK_COUNTER = 8'd9;
reg [5:0]                    DATA_COUNTER = 0;
reg [6:0]                    READ_PARAM = 0;
reg                          CLK_EDGE;
reg                          clk_edge;
reg                          r_config_write;
reg                          data_collect;
reg                          i2s_pcm = 0;
wire [7:0]                   FRAME_SIZE;
wire [7:0]                   CLOCK_COUNTER_VAL;

/* read Register */
reg       read_start;
reg [7:0] read_data;
reg [3:0] read_counter = 4'd7;
reg 	  send_data;
reg 	  collect_data_flag;
reg [7:0] transfer_data;

assign CLOCK_COUNTER_VAL = CLOCK_COUNTER - 1'b1;
assign FRAME_SIZE = BYTE_SIZE*8-1;
/* Configuration block*/
always @(posedge clk) begin
    r_config_write <= config_write;

    if (r_config_write) begin
        r_config_data <= config_data;
        data_collect <= 1'b1;
    end else begin
        r_config_data <= r_config_data;
        data_collect <=	1'b0;
    end

    if (data_collect) begin
        CLOCK_COUNTER <= r_config_data [7:0];
        BYTE_SIZE <= r_config_data [11:8];
        i2s_pcm <= r_config_data [20];
        clk_edge <= r_config_data [24];
        read_start <= r_config_data [16];
    end else begin
        CLOCK_COUNTER <=CLOCK_COUNTER;
        BYTE_SIZE <= BYTE_SIZE;
        i2s_pcm <= i2s_pcm;
        clk_edge <= clk_edge;
    end

    case (BYTE_SIZE)
        1 : DATA_COUNTER <= 6'd24;
        2 : DATA_COUNTER <= 6'd16;
        3 : DATA_COUNTER <= 6'd8;
        4 : DATA_COUNTER <= 6'd0;
        default : DATA_COUNTER <= 6'd0;
    endcase

    case (i2s_pcm)
        0 : READ_PARAM <= 0;
        1 : READ_PARAM <= BYTE_SIZE*8-1;
    endcase

    case (clk_edge)
        0 : CLK_EDGE <= posedge_sclk;
        1 : CLK_EDGE <= negedge_sclk;
    endcase

 end

/* sclk calculations */
/*
 *sclk = 2* bitsize* samplingfreq
 *sclk = 2* 32* 44k
 *so lets consider we have our sclk = 2.5 Mhz.
 *for which we will have to make acounter clock for the sclk from the main clk.

 *For sclk required clk is 2.5mHz
 *we will use counter to make it to 2.5 from 50mhz
 */

/* Delayed Clock */
always @(posedge clk) begin
    if (clk_counter >= CLOCK_COUNTER_VAL) begin
        r_shifted_sclk1 <= ~r_shifted_sclk1;
        r_sclk <= r_shifted_sclk1;
        clk_counter <=0;
    end else begin
        clk_counter <= clk_counter + 1'b1;
        r_shifted_sclk1 <= r_shifted_sclk1;
        r_sclk <= r_shifted_sclk1;
    end
end

always @(posedge i2s_sclk) begin
    if (lrck_counter >= FRAME_SIZE) begin
        r_lrck <= ~r_lrck;
        r_shifted_lrck <= r_lrck;
        lrck_counter <= 0;
    end else begin
        lrck_counter <= lrck_counter + 1'b1;
        r_lrck <= r_lrck;
        r_shifted_lrck <= r_lrck;
    end
end

/* State Machine Parameters */
reg [3:0] state = 4'b0000;
localparam IDLE = 4'h0;
localparam READ_WAIT = 4'h1;
localparam READ = 4'h2;
localparam DATA_TRANSFER = 4'h3;
localparam WAIT_DATA = 4'h4;

always @( posedge clk) begin
    if ((~r_sclk && r_shifted_sclk1) == 1) begin
        posedge_sclk <= 1'b1;
    end else begin
        posedge_sclk <= 1'b0;
    end

    if ((r_sclk && ~r_shifted_sclk1) == 1) begin
        negedge_sclk <= 1'b1;
    end else begin
        negedge_sclk <= 1'b0;
    end

    if ((~r_shifted_lrck && r_lrck) == 1) begin
        posedge_lrck <= 1'b1;
    end else begin
        posedge_lrck <= 1'b0;
    end

    if ((r_shifted_lrck && ~r_lrck) == 1) begin
        negedge_lrck <= 1'b1;
    end else begin
        negedge_lrck <= 1'b0;
    end

    case (state)
        IDLE : begin
            r_audio_data <= 0;

            if(!f_empty) begin
                r_rd_en <= 1;
                state <= READ_WAIT;
            end
        end

        READ_WAIT: begin
            r_rd_en <= 0;
            state <= READ;
        end

        READ: begin
            r_audio_data <= audio_data;
            bit_counter <= 6'd31;

            if (lrck_counter == READ_PARAM) begin;
                state <= DATA_TRANSFER;
            end
        end

        DATA_TRANSFER : begin
            if (posedge_sclk) begin
                r_sdo <= r_audio_data[bit_counter];
                state <= WAIT_DATA;
            end
        end

        WAIT_DATA : begin
            if (bit_counter > DATA_COUNTER) begin
                bit_counter <= bit_counter - 1'b1;
                state <= DATA_TRANSFER;
            end else begin
                state <= IDLE;
            end
        end
    endcase

	if (!read_start) begin
		read_data <= 0;
		read_counter <= 4'd7;
	end else begin
		if (lrck_counter == 0) begin
			collect_data_flag <= 1'b1;
		end 
		
		if (collect_data_flag == 1'b1) begin
			if (posedge_sclk) begin
				read_data [read_counter] <= i2s_sdi;
				read_counter <= read_counter - 1'b1;

				if (read_counter == 0) begin
					send_data <= 1'b1;
					transfer_data <= read_data;
					read_counter <= 4'b0111;
				end else begin
					send_data <=   1'b0;
					transfer_data <= transfer_data;
				end
			end else begin
				read_data <= read_data;
				read_counter <= read_counter;
			end
		end
	
	end
end

/* Output Assignment */
assign i2s_sclk = r_sclk;
assign i2s_lrck = r_lrck;
assign i2s_sdo  = r_sdo;
assign rd_en = r_rd_en;
assign collected_data = transfer_data;
assign read_enable = send_data;

endmodule
