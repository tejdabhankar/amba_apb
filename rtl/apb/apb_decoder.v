module apb_decoder #(
parameter RAH_PACKET_WIDTH = 48)
(
	/* Clock Signals */
	input 						 clk,

	/* apb_fifo signals */
	input f_empty,
	output rd_en,
	input [RAH_PACKET_WIDTH-1:0] f_data,
	input f_a_empty,

	/* interface signal */
	
	output [6:0] slv_id,
	output cfg_sel,
	output [47:0] data,
	output length,
	output first_frame,
	output dt_frame_en

);

reg [RAH_PACKET_WIDTH-1:0] r_fifo_data;
reg [RAH_PACKET_WIDTH-1:0] r_data;
reg r_rd_en;
reg flag_data_sample;
reg r_data_flag;
reg r_config_sel;
reg [6:0] r_slv_id;
reg [7:0] r_length;
reg r_first_frame;
reg r_dt_frame_en;
always @(posedge clk) begin
	if(!f_data) begin
		r_rd_en <= 1;
	end

	if (f_a_empty && r_rd_en) begin
		r_rd_en <= 0;
	end

	flag_data_sample <= r_rd_en;

	if (flag_data_sample) begin
		if (!r_data_flag) begin
			r_config_sel <= f_data[47];
			r_slv_id <= f_data[46:40];
			r_length <= f_data[39:32];	
			r_data <= f_data[47:0];
			
			if (f_data[39:32] >8'h3) begin
				r_data_flag <= 1'b1;
				r_first_frame <= 1'b1;
			end else begin
				r_data_flag <= 1'b0;
			end
		r_dt_frame_en <= 1'b1;
		end else begin
			r_dt_frame_en <=1'b1;

			r_data <= f_data[47:0];
			
            if (r_first_frame) begin // For first data frame
                r_length <= r_length - 4;
                r_first_frame <= 0;

                if((r_length - 4) < 4'h6) begin
                    r_data_flag <= 0;
                end

            end else begin // For other than first data frame
                r_length <= r_length - 6;

                if ((r_length - 6) < 4'h6) begin
                    r_data_flag <= 0;
                end
            end
        end					
    end else if (!flag_data_sample && r_data_flag) begin
        /* Reset only control registers */
        r_config_sel <= 0;
        r_data <= 0;
		r_dt_frame_en <= 1'b0;

    end else if (!flag_data_sample && !r_data_flag) begin
        /* Reset all registers */
        r_config_sel <= 0; 
        r_slv_id <= 0;
        r_length <= 0;
        r_data <= 0;
		r_dt_frame_en <= 0;
    end
end

/* assignment */
assign rd_en = r_rd_en;
assign slv_id = r_slv_id;
assign cfg_sel = r_config_sel;
assign data = r_data;
assign length = r_length;
assign first_frame = r_first_frame;
assign dt_frame_en = r_dt_frame_en;

endmodule
