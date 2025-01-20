//-----------------------------------------------------------------------------
// Company:         Vicharak Computers PVT LTD
// Engineer:        Tejas Dabhankar <tejasdabhankar123@gmail.com>
// 
// Create Date:     August 27, 2024
// Design Name:     One-Wire_data_Controller
// Module Name:     one_wire_data_ctrl.v
// Project:         PeriPlex
// Target Device:   Trion T120
// Tool Versions:   Efinix Efinity 2023.2 
// 
// Description: 
//    This module access the data from periplex design and transfers
//    it to one_wire_interface, and reads data from one_wire_interface
//    and transfers it to periplex.
// 
// Dependencies: 
//    one_wire_interface.v
// 
// Version:
//    1.0 - 08/27/2024 - TD - Initial release
// 
// Additional Comments: 
// 
// License: 
//    Proprietary © Vicharak Computers PVT LTD - 2024
//-----------------------------------------------------------------------------

module one_wire_data_ctrl (
    input                     clk,

/* fifo signal */
    input                     fifo_empty,
    input [(FIFO_WIDTH-1):0]  fifo_read_data,
    output                    fifo_read_enable,

/* Interface signal */
    input                     presence_detect,
    input                     ow_busy,
    output [3:0]              length,
    output [3:0]              command,
    output [7:0]              data,

/* output to start the interface */
    output                    write
);

parameter FIFO_WIDTH = 8;

reg [FIFO_WIDTH-1:0]    r_data = 0;
reg                     r_fifo_read_enable = 0;
reg [3:0]               r_command = 0;
reg [3:0]               r_length = 0;
reg                     r_write = 0;

/* STATE MACHINE PARAMETERS */
reg [3:0] state = 4'b000;
reg [3:0] post_wait_state;

localparam IDLE              = 4'd0;
localparam HOLD              = 4'd1;
localparam FIFO_WAIT         = 4'd2;
localparam FIFO_READ_COMMAND = 4'd3;
localparam FIFO_DETECT       = 4'd4;
localparam FIFO_READ_DATA    = 4'd5;
localparam WRITE             = 4'd6;
localparam WRITE_CONDITION   = 4'd7;
localparam CHECK_BUSY        = 4'd8;

always @(posedge clk) begin
    case (state)
        IDLE: begin
            r_command <= 0;
            r_length <= 0;
            r_data <= 0;
            state <= HOLD;
            post_wait_state <= FIFO_READ_COMMAND;
        end

        HOLD: begin // 1
            if (!fifo_empty) begin
                r_fifo_read_enable <= 1;
                state <= FIFO_WAIT;
            end else begin
                state <= HOLD;
            end
        end

        FIFO_WAIT: begin // 2
            r_fifo_read_enable <= 0;
            state <= post_wait_state;
        end

        FIFO_READ_COMMAND: begin
            r_length <= fifo_read_data[7:4];
            r_command <= fifo_read_data[3:0];
            state <= FIFO_DETECT;
        end

        FIFO_DETECT: begin
             case (r_command)
                4'b0001: begin // reset
                    state <= WRITE;
                    post_wait_state <= FIFO_READ_COMMAND;
                end

                4'b0010: begin // write
                    state <= HOLD;
                    post_wait_state <= FIFO_READ_DATA;
                end

                4'b0011: begin // read
                    state <= WRITE;
                    post_wait_state <= FIFO_READ_COMMAND;
                end

                4'b0100: begin // search
                    state <= WRITE;
                    post_wait_state <= FIFO_READ_COMMAND;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end

        FIFO_READ_DATA: begin
            r_data <= fifo_read_data;
            state <= WRITE;
        end

        WRITE: begin
            r_write <= 1'b1;
            state <= WRITE_CONDITION;
        end

        WRITE_CONDITION: begin
            r_write <= 1'b0;
            state <= CHECK_BUSY;

            if (r_length == 0) begin
                post_wait_state <= FIFO_READ_COMMAND;
            end else begin
                post_wait_state <= FIFO_READ_DATA;
                r_length <= r_length - 1'b1;
            end
        end

        CHECK_BUSY: begin
            if (!ow_busy) begin
                state <= IDLE;
            end else begin
                state <= CHECK_BUSY;
            end
        end
    endcase
end

/* ASSIGNING OUTPUT SIGNALS */
assign fifo_read_enable = r_fifo_read_enable;
assign write            = r_write;
assign data             = r_data;
assign length           = r_length;
assign command          = r_command;

endmodule
