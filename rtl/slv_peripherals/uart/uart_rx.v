//-----------------------------------------------------------------------------
// Company:         Vicharak Computers PVT LTD
// Engineer:        Kaushal Kumar Kumawat <kaushalkumawat1723@gmail.com>
// 
// Create Date:     May 31, 2024
// Design Name:     UART_Receiver
// Module Name:     uart_rx.v
// Project:         PeriPlex
// Target Device:   Trion T120
// Tool Versions:   Efinix Efinity 2023.2 
// 
// Description: 
//    This module implements UART protocol to recieve data from UART_Tx.
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

module uart_rx (
 /* Clock Signals */
 input                          i_Clock,
 
 /* Configuration Control Signals */
 input [CONFIG_DATA_WIDTH-1:0]  uart_config_data,
 
 /* UART Rx Signals */
 input                          i_Rx_Serial,
 output                         o_Rx_DV,
 output [UART_DATA_WIDTH-1:0]   o_Rx_Byte
);

/* Global parameters */
parameter UART_DATA_WIDTH   = 8;
parameter CONFIG_DATA_WIDTH = 32;

/* Register declaration and Initialization */
reg [CONFIG_DATA_WIDTH-1:0] r_Clock_Count = 0;
reg [2:0]                   r_Bit_Index   = 0;
reg [UART_DATA_WIDTH:0]     r_Rx_Byte     = 0;
reg                         r_Rx_DV       = 0;
reg [CONFIG_DATA_WIDTH-1:0] r_config_data = 32'd437;


/* State Machine Parameters */ 
reg [2:0]  r_SM_Main      = 0; 
localparam s_IDLE         = 3'b000;
localparam s_RX_START_BIT = 3'b001;
localparam s_RX_DATA_BITS = 3'b010;
localparam s_RX_STOP_BIT  = 3'b011;
localparam s_CLEANUP      = 3'b100;

/* To avoid metastability */
reg           r_Rx_Data_R = 1'b1;
reg           r_Rx_Data   = 1'b1;

always @(posedge i_Clock) begin
  r_Rx_Data_R <= i_Rx_Serial;
  r_Rx_Data   <= r_Rx_Data_R;
end

/* Main FSM */
always @(posedge i_Clock) begin
  r_Rx_Data_R <= i_Rx_Serial;
  r_Rx_Data   <= r_Rx_Data_R;
  case (r_SM_Main)
    s_IDLE : begin
      r_Rx_DV       <= 1'b0;
      r_Clock_Count <= 0;
      r_Bit_Index   <= 0;
      r_config_data <= uart_config_data - 1;
       
      if (r_Rx_Data == 1'b0) begin  // Start bit detected
        r_SM_Main <= s_RX_START_BIT;
      end else begin
        r_SM_Main <= s_IDLE;
      end
    end
  
    s_RX_START_BIT : begin
      if (r_Clock_Count == (r_config_data >> 1)) begin
        if (r_Rx_Data == 1'b0) begin
          r_Clock_Count <= 0;  // reset counter, found the middle
          r_SM_Main     <= s_RX_DATA_BITS;
        end else begin
          r_SM_Main <= s_IDLE;
        end
      end else begin
        r_Clock_Count <= r_Clock_Count + 1;
        r_SM_Main     <= s_RX_START_BIT;
      end
    end

    s_RX_DATA_BITS : begin
      if (r_Clock_Count < r_config_data) begin
        r_Clock_Count <= r_Clock_Count + 1;
        r_SM_Main     <= s_RX_DATA_BITS;
      end else begin
        r_Clock_Count          <= 0;
        r_Rx_Byte[r_Bit_Index] <= r_Rx_Data;
         
        // Check if we have received all bits
        if (r_Bit_Index < 7) begin
          r_Bit_Index <= r_Bit_Index + 1;
          r_SM_Main   <= s_RX_DATA_BITS;
        end else begin
          r_Bit_Index <= 0;
          r_SM_Main   <= s_RX_STOP_BIT;
        end
      end
    end
 
    // Receive Stop bit.  Stop bit = 1
    s_RX_STOP_BIT : begin
      // Wait CLKS_PER_BIT-1 clock cycles for Stop bit to finish
      if (r_Clock_Count < r_config_data) begin
        r_Clock_Count <= r_Clock_Count + 1;
        r_SM_Main     <= s_RX_STOP_BIT;
      end else begin
        r_Rx_DV       <= 1'b1;
        r_Clock_Count <= 0;
        r_SM_Main     <= s_CLEANUP;
      end
    end

    // Stay here 1 clock
    s_CLEANUP : begin
      r_SM_Main <= s_IDLE;
      r_Rx_DV   <= 1'b0;
    end
     
    default : r_SM_Main <= s_IDLE;
  endcase
end

assign o_Rx_DV   = r_Rx_DV;
assign o_Rx_Byte = r_Rx_DV ? r_Rx_Byte : 0;

endmodule