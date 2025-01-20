//-----------------------------------------------------------------------------
// Company:         Vicharak Computers PVT LTD
// Engineer:        Tejas Dabhankar <tejasdabhankar123@gmail.com>
// 
// Create Date:     August 27, 2024
// Design Name:     One-Wire_Interface
// Module Name:     one_wire_interface.v
// Project:         PeriPlex
// Target Device:   Trion T120
// Tool Versions:   Efinix Efinity 2023.2 
// 
// Description: 
//    This module implements One-Wire protocol to send data to One-Wire Bus.
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

module one_wire_interface (
    input               clk,

    output              ow_busy,
    output              presence_detect,
    input [3:0]         length,
    input [3:0]         command,
    input [7:0]         data,
    input               write,

    output              rd_dt_en,
    output [7:0]        read_data,

    input               data_in,
    output              data_out,
    output              data_oe
);

parameter FIFO_WIDTH = 8;
parameter RESET_COUNT = 24000;

/* counters declaration */
reg [15:0] wait_count = 0; // to add the delay between to successive command
reg [15:0] high_count = 0;
reg [15:0] low_count  = 0;
reg [31:0] presence_count = 0;
reg [15:0] read_count = 0; // to check the received bit.
reg [15:0] read_wait_count = 0; //  wait for the slave to send bit

/* reg for the output */
reg r_data_out = 1'b1;
reg r_data_oe = 1'b1;

reg [7:0] read_counter = 0;
reg [7:0] counter = 0; // bit counter to address bit counter
reg [3:0] r_length = 0;
reg [3:0] r_command = 0;
reg [7:0] r_data = 0;
reg [7:0] r_prev_data = 0;
reg       r_ow_busy = 0;
reg [3:0] depth = 0;

/* data parameters */
reg [7:0] rec_data;
reg       rec_bit;
reg       r_rd_dt_en;
reg       r_presence_detect;
reg [1:0] search_bit = 0;
reg       src_count = 0;

/* search parameters */
reg [63:0] uid_number = 0;
reg [7:0]  last_zero = 8'h00;
reg        rom_byte_mask = 1'b1;
reg        search_direction = 1'b0;
reg [7:0]  uid_count = 0;
reg [7:0]  LastDiscrepancy = 0;

/* Flag Declaration */
reg write_done_flag = 0;
reg read_done_flag  = 0;
reg search_done_flag = 0;
reg search_flag = 0;
reg reset_flag = 0;
reg high_flag = 0;
reg low_flag = 0;
reg read_flag = 0;
reg conflict_flag = 0;
reg search_complete = 0;
reg search_busy = 0;

/* calculation for the counter */
/*
 *clock frequency is 50 MHz which means
 *1 clock cycle = 2o n.sec
 *reset cycle  = 480 micro second
 *reset_count =  480/0.020 = 24000 count
 *
 *for presence detect 410 microsecond
 *presence count = 410/0.020 = 20500 count
 *
 *for high count  of 10 microsecond
 *high_count = 10/0.020 = 500 count
 *
 *for low count of 60 microsecond
 *low count  = 60/0.020 = 3000 count
 */

/* State machine declaration */
reg [3:0] state = 5'b0000;
reg [3:0] post_wait_state = 5'b0000;

localparam IDLE                 = 4'h0;
localparam DETECT               = 4'h1;
localparam RESET                = 4'h2;
localparam WAIT_RESET           = 4'h3;
localparam WAIT_PRESENCE        = 4'hD;
localparam DETECT_PRESENCE      = 4'h4;
localparam WAIT_DETECT_PRESENCE = 4'h5;
localparam WAIT                 = 4'h6;
localparam SEND_DATA            = 4'h7;
localparam WAIT_DATA            = 4'h8;
localparam READ_DATA            = 4'h9;
localparam WAIT_READ            = 4'hA;
localparam SEARCH               = 4'hB;
localparam WAIT_SEARCH          = 4'hC;

/* Write state machine declaration */
reg [2:0] write_state = 3'h0;
localparam [2:0] WRITE_IDLE      = 3'h0;
localparam [2:0] WRITE_CONDITION = 3'h1;
localparam [2:0] WRITE_LOW       = 3'h2;
localparam [2:0] WRITE_HIGH      = 3'h3;
localparam [2:0] WRITE_RESET     = 3'h4;

/* Read state machine declaration */
reg [2:0] read_state = 3'h0;
localparam [2:0] READ_IDLE        = 3'h0;
localparam [2:0] READ_WAIT        = 3'h1;
localparam [2:0] READ_BITS        = 3'h2;
localparam [2:0] DETECT_READ_DATA = 3'h3;
localparam [2:0] DATA_ENABLE      = 3'h4;
localparam [2:0] READ_RESET       = 3'h5;

/* state machine declaration*/ // search state
reg [3:0]  search_state = 4'h0;
localparam [3:0] SEARCH_IDLE   = 4'h0;
localparam [3:0] SEARCH_BIT    = 4'h1;
localparam [3:0] WAIT_BIT      = 4'h2;
localparam [3:0] DETECT_SEARCH = 4'h3;
localparam [3:0] WAIT_WRITE    = 4'h4;
localparam [3:0] SEARCH_RESET  = 4'h5;

always @(posedge clk) begin
/* CONTROL FSM */
    case (state) // FSM begin
        IDLE: begin
            reset_flag <= 1'b0;
            high_flag  <= 1'b0;
            low_flag <= 1'b0;
            counter  <= 0;
            presence_count <= 0;
            r_ow_busy <= 1'b0;
            r_data_oe <= 1'b1;
            r_length <= 0;
            r_data <= 0;
            r_command <= 0;
            r_presence_detect <= 1'b0;
            depth <= 0;
            r_rd_dt_en <= 1'b0;

            if (write) begin
                r_data_oe <= 1'b1;
                r_ow_busy <= 1'b1;
                r_length <= length;
                r_command <= command;
                r_data <= data;
                state <= DETECT;
            end else begin
                state <= IDLE;
            end
        end

        DETECT: begin
            case (r_command)
                4'b0001: begin // reset
                    state <= RESET;
                    post_wait_state <= IDLE;
                end

                4'b0010: begin //write
                    state <= SEND_DATA;
                    post_wait_state <= IDLE;
                end
                4'b0011: begin // read
                    state <= READ_DATA;
                    post_wait_state <= IDLE;
                end

                4'b0100: begin // search
                    state <= SEARCH;
                    post_wait_state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end

        RESET: begin
            reset_flag <= 1;
            state <= WAIT_RESET;
        end

        WAIT_RESET: begin
            if (write_done_flag) begin
                reset_flag <= 1'b0;
                r_data_oe  <= 1'b0;
                state <= WAIT_PRESENCE;
            end else begin
                state <= WAIT_RESET;
            end
        end

        WAIT_PRESENCE: begin
            if (data_in) begin
                state <= WAIT_PRESENCE;
            end else begin
                state <= DETECT_PRESENCE;
            end
        end

        DETECT_PRESENCE: begin
            if (!data_in) begin
                presence_count <= presence_count + 1;
                state <= DETECT_PRESENCE;
            end else begin
                state <= WAIT_DETECT_PRESENCE;
            end
        end

        WAIT_DETECT_PRESENCE: begin
            r_data_oe <= 1'b1;
            state <= WAIT;

            if (presence_count > 4000) begin
                r_presence_detect <= 1'b1;
            end else begin
                r_presence_detect <= 1'b0;
            end
        end

        WAIT: begin
            if (wait_count < 5000) begin
                state <= WAIT;
                r_rd_dt_en <= 0;
                wait_count <= wait_count + 1'b1;
            end else begin
                state <= post_wait_state;
                wait_count <= 0;
            end
        end

        SEND_DATA: begin
            if (!search_busy) begin
                if (r_data[counter]) begin
                    high_flag <= 1'b1;
                    state <= WAIT_DATA;
                end else begin
                    low_flag <= 1'b1;
                    state <= WAIT_DATA;
                end
            end else begin
                post_wait_state <= DETECT;

                if (r_prev_data[counter]) begin
                    high_flag <= 1'b1;
                    state <= WAIT_DATA;
                end else begin
                    low_flag <= 1'b1;
                    state <= WAIT_DATA;
                end
            end
        end

        WAIT_DATA: begin
            if (!write_done_flag) begin
                state <= WAIT_DATA;
            end else begin
                high_flag <= 1'b0;
                low_flag <= 1'b0;

                if (counter < 7) begin
                    counter <= counter + 1'b1;
                    state <= SEND_DATA;
                end else begin
                    counter <= 0;
                    state <= WAIT;

                    if (!search_busy) begin
                        r_prev_data <= r_data;
                    end else begin
                        r_prev_data <= r_prev_data;
                    end
                end
            end
        end

        READ_DATA: begin
            read_flag <= 1'b1;
            high_flag <= 1'b1;
            r_rd_dt_en <= 1'b0;
            state <= WAIT_READ;
        end

        WAIT_READ: begin
            if (!write_done_flag) begin
                state <= WAIT_READ;
                read_flag <= 1'b0;
            end else begin
                r_data_oe <= 1'b1;
                high_flag <= 1'b0;
                rec_data[counter] <= rec_bit;

                if (counter < 7) begin
                    counter <= counter + 1'b1;
                    state <= READ_DATA;
                end else begin
                    counter <= 0;
                    r_rd_dt_en <= 1'b1;

                    if (depth < r_length) begin
                        depth <= depth + 1'b1;
                        state <= READ_DATA;
                    end else begin
                        post_wait_state <= IDLE;
                        state <= IDLE;
                    end
                end
            end
        end

        SEARCH: begin
            search_flag <= 1'b1;
            state <= WAIT_SEARCH;
        end

        WAIT_SEARCH: begin
            if (!search_done_flag) begin
                state <= WAIT_SEARCH;
                search_flag <= 1'b0;
            end else begin
                if (search_complete) begin
                    state <= IDLE;
                    search_complete <= 1'b0;
                    search_busy <= 1'b0;
                end else begin
                    search_busy <= 1'b1;
                    state <= RESET;
                    post_wait_state <= SEND_DATA;
                end
            end
        end
    endcase

    /* write FSM */
    case (write_state)
        WRITE_IDLE: begin
            write_done_flag <= 1'b0;
            write_state <= WRITE_CONDITION;
        end

        WRITE_CONDITION: begin
             if (reset_flag) begin
                 low_count <= RESET_COUNT;
                 high_count <= 1500;
                 write_state <= WRITE_LOW;
             end else if (high_flag) begin
                 low_count <= 500;
                 high_count <= 3000;
                 write_state <= WRITE_LOW;
             end else if (low_flag) begin
                 low_count <= 3000;
                 high_count <= 500;
                 write_state <= WRITE_LOW;
             end else begin
                 write_state <= WRITE_IDLE;
             end
         end

         WRITE_LOW: begin
             r_data_out <= 1'b0;

             if (low_count == 0) begin
                 write_state <= WRITE_HIGH;
             end else begin
                 low_count <= low_count - 1'b1;
                 write_state <= WRITE_LOW;
             end
         end

         WRITE_HIGH: begin
             r_data_out <= 1'b1;

             if (high_count == 0) begin
                write_state <= WRITE_RESET;
             end else begin
                 high_count <= high_count -1'b1;
                 write_state <= WRITE_HIGH;
             end
        end

        WRITE_RESET: begin
             write_done_flag <= 1'b1;
             high_flag <= 1'b0;
             write_state <= WRITE_IDLE;
        end
    endcase

    /* Read FSM */
    case (read_state)
        READ_IDLE: begin
            read_done_flag <= 1'b0;

            if (read_flag) begin
                read_state <= READ_WAIT;
            end
        end

        READ_WAIT: begin
            if (read_wait_count < 490) begin
                read_wait_count <= read_wait_count + 1'b1;
                read_state <= READ_WAIT;
            end else begin
                read_wait_count <= 0;
                r_data_oe <= 1'b0;
                read_state <= READ_BITS;
            end
        end

        READ_BITS: begin
            if (!data_in) begin
                read_count <= read_count + 1'b1;
            end else begin
                read_state <= DETECT_READ_DATA;
            end
        end

        DETECT_READ_DATA: begin
            read_state <= READ_RESET;

            if (read_count > 100) begin
                rec_bit <= 1'b0;
            end else begin
                rec_bit <= 1'b1;
            end
        end

        READ_RESET: begin
            read_done_flag <= 1'b1;
            read_state <= READ_IDLE;
            read_count <= 15'h0000;
        end
    endcase

    /* SEARCH FSM */
    case (search_state)
        SEARCH_IDLE: begin
            search_bit <= 1'b0;
            search_done_flag <= 1'b0;

            if (search_flag) begin
                search_state <= SEARCH_BIT;
            end else begin
                search_state <= SEARCH_IDLE;
            end
        end

        SEARCH_BIT: begin
            high_flag <= 1'b1;
            read_flag <= 1'b1;
            search_state <= WAIT_BIT;
            r_rd_dt_en <= 1'b0;
        end

        WAIT_BIT: begin
            if (!write_done_flag) begin
                search_state <= WAIT_BIT;
                read_flag <= 1'b0;
            end else begin
                high_flag <= 1'b0;
                r_data_oe <= 1'b1;
                search_bit[src_count] <= rec_bit;

                if (src_count == 0) begin
                    src_count <= 1'b1;
                    search_state <= SEARCH_BIT;
                end else begin
                    search_state <= DETECT_SEARCH;
                end
            end
        end

        DETECT_SEARCH: begin
            case (search_bit)
                2'b00: begin
                    if (uid_count < LastDiscrepancy) begin
                        search_direction <=
                                ((uid_number[uid_count] & rom_byte_mask) > 0);
                        conflict_flag <= 1'b1;
                    end else begin
                        search_direction <= (uid_count == LastDiscrepancy);
                        conflict_flag <= 1'b1;
                    end

                    if (conflict_flag == 1'b1) begin
                        conflict_flag <= 1'b0;
                        search_state <= WAIT_WRITE;

                        if (search_direction == 1'b0) last_zero = uid_count;

                        if (search_direction == 1'b1) begin
                            uid_number[uid_count] <=
                                    uid_number[uid_count] | rom_byte_mask;
                            high_flag <= 1'b1;
                        end else begin
                            uid_number[uid_count] <=
                                    uid_number[uid_count] & ~rom_byte_mask;
                            low_flag <= 1'b1;
                        end
                    end
                end

                2'b01: begin
                    high_flag <=1'b1;
                    rec_data[counter] <= 1'b1;
                    uid_number[uid_count] <= 1'b1;
                    search_state <= WAIT_WRITE;
                end

                2'b10: begin
                    low_flag <=1'b1;
                    rec_data[counter] <= 1'b0;
                    uid_number[uid_count] <= 1'b0;
                    search_state <= WAIT_WRITE;
                end

                2'b11: begin
                    state <= IDLE;
                    search_state <= SEARCH_IDLE;
                end
            endcase
        end

        WAIT_WRITE: begin
            if (!write_done_flag) begin
                search_state <= WAIT_WRITE;
                read_flag <= 1'b0;
            end else begin
                uid_count <= uid_count + 1'b1;
                high_flag <= 1'b0;
                low_flag  <= 1'b0;
                src_count <= 1'b0;

                if (counter < 7) begin
                    counter <= counter + 1'b1;
                    search_state <= SEARCH_BIT;
                end else begin
                    counter <= 0;
                    r_rd_dt_en <= 1'b1;

                    if (depth < 4'h7) begin
                        depth <= depth + 1'b1;
                        search_state <= SEARCH_BIT;
                    end else begin
                        uid_count <= 1'b0;
                        depth <= 0;
                        search_state <= SEARCH_RESET;

                        if (LastDiscrepancy == last_zero) begin
                            LastDiscrepancy <= 0;
                        end else begin
                            LastDiscrepancy <= last_zero;
                        end
                    end
                end
            end
        end

       SEARCH_RESET: begin
            r_rd_dt_en <= 1'b0;
            search_done_flag <= 1'b1;
            search_state <= SEARCH_IDLE;

            if (LastDiscrepancy == 0) begin
                uid_number <= 0;
                search_complete <= 1'b1;
            end
        end
    endcase
end

assign data_out  = r_data_out;
assign data_oe   = r_data_oe;
assign rd_dt_en  = r_rd_dt_en;
assign read_data = rec_data;
assign ow_busy   = r_ow_busy;

endmodule
