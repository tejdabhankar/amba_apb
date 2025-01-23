`include "../apb.vh"

module apb_data_controller #(
parameter RAH_PACKET_WIDTH= 48,
parameter CONFIG_DATA_WIDTH = 40,
parameter WRITE_DATA_WIDTH = 16,
parameter LENGTH_WIDTH = 8,
parameter SLV_ID_WIDTH = 7)
(
/* Clock Signals */
	input clk,

/* input from Decoder */
	input [SLV_ID_WIDTH-1:0] slv_id,
	input [LENGTH_WIDTH-1:0] length,
	input [RAH_PACKET_WIDTH-1:0] wr_data,
	input cfg_sel,
	input first_frame,
	input dt_frame_en,

	output write_en,
	output [31:0] write_data,
    output [SLV_ID_WIDTH-1:0] write_id,
    output [LENGTH_WIDTH-1:0] write_addr,
    output data_hold_flag,
    output read_write,

    output [SLV_ID_WIDTH-1:0] config_id,
    output [LENGTH_WIDTH-1:0] config_addr,
    output [CONFIG_DATA_WIDTH-1:0] config_data
);

/* reg declaration */

reg [(`TOTAL_SLAVE-1):0] r_slv_sel;
reg [WRITE_DATA_WIDTH-1:0] r_wr_data;
reg [LENGTH_WIDTH-1:0] r_addr;
reg r_wr_en;
reg r_data_hold_flag;

reg [1:0] counter;
reg r_data_hold_flag;

reg [CONFIG_DATA_WIDTH-1:0] r_config_data;
reg [(`TOTAL_SLAVE-1):0] r_config_id;
reg [LENGTH_WIDTH-1:0] r_config_addr;
reg r_config_en;

always @(posedge clk) begin
	if (dt_frame_en) begin
		if (!cfg_sel) begin
			r_slv_sel[slv_id] <= 1'b1;
			r_addr <= 8'b10110011;
			r_wr_en <= 1'b1;
			if (first_frame) begin
				if (counter <2) begin
					counter <= counter + 1'b1;
					r_wr_data <= wr_data[((1-counter)*WRITE_DATA_WIDTH)-1
                                        +: WRITE_DATA_WIDTH];
				end else begin
					counter <= 0;
                end
			end else begin
				r_data_hold_flag <= 1'b1;
				if (counter <=2) begin
					counter <= counter +1'b1;
					r_wr_data <= wr_data[((2-counter)*WRITE_DATA_WIDTH)-1
                                        +: WRITE_DATA_WIDTH];
					if(counter !=0) begin
						r_data_hold_flag <=1'b0;
					end
				end else begin
					counter <= 0;
				end
			end
		end else  begin
            r_config_id[(`TOTAL_SLAVE-1)] <= 1;
			r_config_addr <= 8'b10110011;
			r_config_en <= 1'b1;
            r_config_data <= wr_data [CONFIG_DATA_WIDTH-1:0];
		end
    end else begin  
        r_slv_sel <= 0;
		r_addr <= 0;
        r_wr_data <= 0;
		r_wr_en <= 0;
        r_data_hold_flag <= 0;
        
		r_config_addr <= 0;
		r_config_en <= 0;
        r_config_data <= 0;
        r_config_id <= 0;
    end
end

/* Assignment of the blocks */

assign write_id = r_slv_sel;
assign write_addr = r_addr;
assign write_data =r_wr_data;
assign write_en = r_wr_en;
assign data_hold_flag = r_data_hold_flag;

assign config_id = r_config_id;
assign config_addr = r_config_addr;
assign config_data = r_config_data;
assign config_en = r_config_en;

endmodule
