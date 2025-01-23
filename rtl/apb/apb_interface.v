module apb_interface #(
	parameter DATA_WIDTH = 16,
	parameter ADDR_WIDTH = 8)
(
	/* clock */
	input clk,

	/* collecting data from the fifo */
	input wr_en,
	input [DATA_WIDTH-1:0] wr_data,
	input [ADDR_WIDTH-1:0] addr_data,
	output[DATA_WIDTH-1:0] rd_data,
	output rd_en,
	input read_write,
	
	/* output signals for slave*/
	output pclk,
	output [`total_slave-1:0] psel,
	output [ADDR_WIDTH-1:0] paddr,
	output penable,
	output [DATA_WIDTH-1:0] pwdata,
	input pready,
	input prdata
);

reg [DATA_WIDTH-1:0] r_wr_data;
reg [ADDR_WIDTH-1:0] r_addr;
reg start_transfer;
reg r_psel;
reg r_pwrite;
reg start_enable;
reg r_penable;
reg r_prdata;
    

	
always @(posedge clk) begin
	if (wr_en) begin
		r_wr_data <= wr_data;
		r_addr <= addr_data;
		start_transfer <= 1'b1;
	end

	if (start_transfer) begin
		r_psel <= 1'b1;
		r_pwrite <=read_write;
		start_enable <= 1'b1;
	end else begin
		start_enable <= 1'b0;
	end
	
	if (start_enable) begin
		r_penable <= 1'b1;

		if (pready) begin
			r_penable <= 1'b0;
			start_transfer <= 1'b0;

			if (read_write == 0) begin
				r_prdata <= prdata;
			end
		end
	end
end
 			
endmodule
