//-----------------------------------------------------------------------------
// Company:         Vicharak Computers PVT LTD
// Engineer:        Kaushal Kumar Kumawat <kaushalkumawat1723@gmail.com>
// 
// Create Date:     May 31, 2024
// Design Name:     UART_Transmitter
// Module Name:     uart_tx.v
// Project:         PeriPlex
// Target Device:   Trion T120
// Tool Versions:   Efinix Efinity 2023.2 
// 
// Description: 
//    This module implements UART protocol to send data to UART_Rx.
// 
// Dependencies: 
// 
// Version:
//    1.0 - 05/31/2024 - KKK - Initial release
// 
// Additional Comments: 
//    The baudrate of this module is dependent on configuration data.
// 
// License: 
//    Proprietary © Vicharak Computers PVT LTD - 2024
//-----------------------------------------------------------------------------

module uart_tx (
    /* Clock Signals */
    input                           i_Clock,
    
    /* Configuration Control Signal */
    input [CONFIG_DATA_WIDTH-1:0]   uart_config_data,
    
    /* UART Tx Signals */
    input                           i_Tx_DV,
    input [UART_DATA_WIDTH-1:0]     i_Tx_Byte,
    output                          o_Tx_Active,
    output reg                      o_Tx_Serial = 1,
    output                          o_Tx_Done
);

/* Global Parameters */
parameter UART_DATA_WIDTH   = 8;
parameter CONFIG_DATA_WIDTH = 32;

/* Register declaration and initialization */
reg [CONFIG_DATA_WIDTH-1:0] r_Clock_Count = 0;
reg [2:0]                   r_Bit_Index = 0;
reg [UART_DATA_WIDTH-1:0]   r_Tx_Data = 0;
reg                         r_Tx_Done = 0;
reg                         r_Tx_Active = 0;
reg [CONFIG_DATA_WIDTH-1:0] r_config_data = 32'd437;

/* State Machine Parameters */
reg [2:0] r_SM_Main = 0;
localparam s_IDLE           = 3'b000;
localparam s_TX_START_BIT   = 3'b001;
localparam s_TX_DATA_BITS   = 3'b010;
localparam s_TX_STOP_BIT    = 3'b011;
localparam s_CLEANUP        = 3'b100;

always @(posedge i_Clock) begin
    case (r_SM_Main)
        s_IDLE: begin
             /* Drive Line High for Idle */
            o_Tx_Serial <= 1'b1;
            r_Tx_Done <= 1'b0;
            r_Clock_Count <= 0;
            r_Bit_Index <= 0;
            r_config_data <= uart_config_data - 1;
            
            if (i_Tx_DV == 1'b1) begin
                r_Tx_Active <= 1'b1;
                r_Tx_Data <= i_Tx_Byte;
                r_SM_Main <= s_TX_START_BIT;
            end else begin
                r_SM_Main <= s_IDLE;
            end
        end // case: s_IDLE

        /* Send out Start Bit. Start bit = 0 */
        s_TX_START_BIT: begin
            o_Tx_Serial <= 1'b0;

            /* Wait CLKS_PER_BIT-1 clock cycles for start bit to finish */
            if (r_Clock_Count < r_config_data) begin
                r_Clock_Count <= r_Clock_Count + 1;
                r_SM_Main <= s_TX_START_BIT;
            end else begin
                r_Clock_Count <= 0;
                r_SM_Main <= s_TX_DATA_BITS;
            end
        end // case: s_TX_START_BIT

        /* Wait CLKS_PER_BIT-1 clock cycles for data bits to finish */
        s_TX_DATA_BITS: begin
            o_Tx_Serial <= r_Tx_Data[r_Bit_Index];

            if (r_Clock_Count < r_config_data) begin
                r_Clock_Count <= r_Clock_Count + 1;
                r_SM_Main <= s_TX_DATA_BITS;
            end else begin
                r_Clock_Count <= 0;

                /* Check if we have sent out all bits */
                if (r_Bit_Index < 7) begin
                    r_Bit_Index <= r_Bit_Index + 1;
                    r_SM_Main <= s_TX_DATA_BITS;
                end else begin
                    r_Bit_Index <= 0;
                    r_SM_Main <= s_TX_STOP_BIT;
                end
            end
        end // case: s_TX_DATA_BITS

        /* Send out Stop bit. Stop bit = 1 */
        s_TX_STOP_BIT: begin
            o_Tx_Serial <= 1'b1;

            /* Wait CLKS_PER_BIT-1 clock cycles for Stop bit to finish */
            if (r_Clock_Count < r_config_data) begin
                r_Clock_Count <= r_Clock_Count + 1;
                r_SM_Main <= s_TX_STOP_BIT;
            end else begin
                r_Tx_Done <= 1'b1;
                r_Clock_Count <= 0;
                r_SM_Main <= s_CLEANUP;
                r_Tx_Active <= 1'b0;
            end
        end // case: s_Tx_STOP_BIT

        /* Stay here 1 clock */
        s_CLEANUP: begin
            r_Tx_Done <= 1'b1;
            r_SM_Main <= s_IDLE;
        end

        default: r_SM_Main <= s_IDLE;
    endcase
end

assign o_Tx_Active = r_Tx_Active;
assign o_Tx_Done = r_Tx_Done;

endmodule