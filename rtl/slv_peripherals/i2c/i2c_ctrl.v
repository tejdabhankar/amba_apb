//-----------------------------------------------------------------------------
// Company:         Vicharak Computers PVT LTD
// Engineer:        Kaushal Kumar Kumawat <kaushalkumawat1723@gmail.com>
// 
// Create Date:     August 26, 2024
// Design Name:     I2C_Controller
// Module Name:     i2c_ctrl.v
// Project:         PeriPlex
// Target Device:   Trion T120
// Tool Versions:   Efinix Efinity 2023.2 
// 
// Description: 
//    This module access the data from periplex design and transfers 
//    it to i2c_master and reads data from i2c_master to transfers
//    it to periplex.
// 
// Dependencies: 
//    i2c_master.v
// 
// Version:
//    1.0 - 08/26/2024 - KKK - Initial release
//    1.1 - 11/11/2024 - KKK - Added I2C Detect
// 
// Additional Comments: 
// 
// License: 
//    Proprietary © Vicharak Computers PVT LTD - 2024
//-----------------------------------------------------------------------------

module i2c_ctrl(
    /* Clock Signal */
    input                           clk,

    /* Reset Signal */
    input                           reset,

    /* WR_FIFO Signals */
    input                           f_empty,
    input [I2C_FIFO_WIDTH-1:0]      fifo_read_data,
    output                          fifo_read_en,

    /* I2C Signals */
    input                           en_ack,
    input                           i2c_busy,
    input                           write_done,
    input                           data_valid_out,
    input  [I2C_DATA_WIDTH-1:0]     data_out,
    output [I2C_DATA_WIDTH-1:0]     i2c_data,
    output [I2C_DATA_WIDTH-1:0]     i2c_slv_addr,
    output [I2C_NUM_BYTE_WIDTH-1:0] num_byte,
    output                          i2c_detect,
    output                          rw,
    output                          en,
    
    /* RD_FIFO Signals */
    output                          fifo_wr_en,
    output [I2C_FIFO_WIDTH-1:0]     fifo_wr_data
);

/* Global Parameters */
parameter I2C_FIFO_WIDTH = 8;
parameter I2C_DATA_WIDTH = 8;
parameter I2C_ADDR_WIDTH = 7;
parameter I2C_NUM_BYTE_WIDTH = 7;

/* Register declaration and instantiations */
reg                          r_fifo_read_en = 0;
reg [I2C_DATA_WIDTH-1:0]     r_i2c_data = 0;
reg [I2C_ADDR_WIDTH-1:0]     r_i2c_slv_addr = 0;
reg [I2C_NUM_BYTE_WIDTH-1:0] r_num_byte = 0;
reg                          r_i2c_detect = 0;
reg                          r_rw = 0;
reg                          r_enable = 0;
reg [I2C_DATA_WIDTH-1:0]     count = 0;
reg                          r_fifo_wr_en = 0;
reg [I2C_FIFO_WIDTH-1:0]     r_fifo_wr_data = 0;

/* State Machine Parameters */
reg [3:0]  state = 0;
reg [3:0]  post_wait_state = 0;
localparam IDLE                 = 4'b0000;
localparam HOLD                 = 4'b0001;
localparam FIFO_WAIT            = 4'b0010;
localparam FIFO_READ_SLVADDR    = 4'b0011;
localparam FIFO_READ_NUMBYTE    = 4'b0100;
localparam WR_FIFO_DATA         = 4'b0101;
localparam WRITE                = 4'b0110;
localparam WR_CONDITION         = 4'b0111;
localparam RD_ENABLE            = 4'b1000;
localparam RD_CONDITION         = 4'b1001;
localparam DETECT_EN            = 4'b1010;

/* FSM Logic */
always @(posedge clk) begin
    if (reset) begin
        state <= IDLE;
        r_fifo_read_en <= 0;
        r_i2c_slv_addr <= 0;
        r_num_byte <= 0;
        r_i2c_detect <= 0;
        r_i2c_data <= 0;
        r_fifo_wr_en <= 0;
    end else begin
        case (state)
            IDLE: begin // 0
                r_fifo_read_en <= 0;
                r_i2c_slv_addr <= 0;
                r_num_byte <= 0;
                r_i2c_detect <= 0;
                r_i2c_data <= 0;
                r_fifo_wr_en <= 0;

            if(!i2c_busy) begin
                post_wait_state <= FIFO_READ_SLVADDR;
                state <= HOLD;
            end else begin
                state <= IDLE;
            end
            end

            HOLD: begin // 1
                if(!f_empty) begin
                    r_fifo_read_en <= 1;
                    state <= FIFO_WAIT;
                end else begin
                    state <= HOLD;
                end
            end

            FIFO_WAIT: begin // 2
                r_fifo_read_en <= 0;
                state <= post_wait_state;
            end

            FIFO_READ_SLVADDR: begin // 3
                r_i2c_slv_addr <= fifo_read_data[I2C_ADDR_WIDTH:1];
                r_rw <= fifo_read_data[0];
                post_wait_state <= FIFO_READ_NUMBYTE;
                state <= HOLD;
            end

            FIFO_READ_NUMBYTE: begin // 4
                r_i2c_detect <= fifo_read_data[7];
                r_num_byte <= fifo_read_data[6:0];

                if(fifo_read_data[7]) begin
                    r_enable <= 1;
                    state <= DETECT_EN;
                end else if(!r_rw) begin // Write
                    post_wait_state <= WR_FIFO_DATA;
                    state <= HOLD;
                end else begin // Read
                    r_enable <= 1;
                    state <= RD_ENABLE;
                end
            end

            WR_FIFO_DATA: begin // 5
                r_i2c_data <= fifo_read_data;
                state <= WRITE;
            end

            WRITE: begin // 6
                if(count > 0) begin
                        r_enable <= 1;
                        count <= count + 1;
                        state <= WR_CONDITION;
                end else begin
                    r_enable <= 1;
                    count <= count + 1;
                    state <= WR_CONDITION;
                end
            end

            WR_CONDITION: begin // 7
                if(en_ack) begin
                    r_enable <= 0;

                    if(count < r_num_byte) begin
                        post_wait_state <= WR_FIFO_DATA;
                        state <= HOLD;
                    end else begin
                        count <= 0;
                        state <= IDLE;
                    end
                end else begin
                    state <= WR_CONDITION;
                end
            end

            RD_ENABLE: begin // 8
                if(en_ack) begin
                    r_enable <= 0;
                end

                if(data_valid_out) begin
                    count <= count + 1;
                    r_fifo_wr_en <= 1;
                    r_fifo_wr_data <=  data_out;
                    state <= RD_CONDITION;
                end else begin
                    state <= RD_ENABLE;
                end
            end

            RD_CONDITION: begin // 9
                r_fifo_wr_en <= 0;
                
                if(count < r_num_byte) begin
                    state <= RD_ENABLE;
                end else begin
                    count <= 0;
                    state <= IDLE;
                end
            end

            DETECT_EN: begin
                if(en_ack) begin
                    r_enable <= 0;
                end

                if(data_valid_out) begin
                    r_fifo_wr_en <= 1;
                    r_fifo_wr_data <=  data_out;
                    state <= IDLE;
                end
            end
        endcase
    end
end

assign fifo_read_en     = r_fifo_read_en;
assign i2c_data         = r_i2c_data;
assign i2c_slv_addr     = r_i2c_slv_addr;
assign num_byte         = r_num_byte;
assign i2c_detect       = r_i2c_detect;
assign rw               = r_rw;
assign en               = r_enable;
assign fifo_wr_en       = r_fifo_wr_en;
assign fifo_wr_data     = r_fifo_wr_data;
endmodule