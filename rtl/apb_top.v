module apb_master(
    /* Clock Signals */
    input                           apb_clk,
    input                           dt_clk,

    /* pp_wr_fifo signals */
    input                           pp_wr_fifo_empty,
    input                           pp_wr_fifo_a_empty,
    input [RAH_PACKET_WIDTH-1:0]    pp_wr_fifo_read_data,
    output                          pp_wr_fifo_read_en,

     /* pp_rd_fifo signals */
    input                           pp_rd_fifo_full,
    input                           pp_rd_almost_fifo_full,
    input                           pp_rd_prog_fifo_full,
    output                          pp_rd_fifo_en,
    output [RAH_PACKET_WIDTH-1:0]   pp_rd_fifo_data
);
/* global parameter */
parameter RAH_PACKET_WIDTH   = 48;

/* reg declaration */
reg r_wr_fifo_read_rn;

/* This logic is to pick the data from the rah fifo and
/* append into the apb_fifo. The reason is fifo of rah is
/* too small so we maintain our own fifo to keep the data being 
/* loss and corrupted */
always @(posedge dt_clk) begin
	if (!pp_wr_fifo_empty) begin
		r_wr_fifo_read_rn <= 1'b1;
	end else begin
		r_wr_fifo_read_rn <= 1'b0;
	end
end

/* wire declaration */
wire [RAH_PACKET_WIDTH-1:0] w_apb_fifo_data;
wire [RAH_PACKET_WIDTH-1:0] w_data;
wire [6:0] w_slv_id;
wire [7:0] w_length;

wr_apb_fifo wr_apb_fifo(
    .wr_clk_i       (dt_clk),
    .rd_clk_i       (dt_clk),
    .wr_en_i        (w_wr_fifo_read_en),
    .wdata          (pp_wr_fifo_read_data),
    .rd_en_i        (w_apb_fifo_rd_en),
    .rdata          (w_apb_fifo_data),
    .empty_o        (w_apb_fifo_empty),
	.almost_empty_o (w_apb_fifo_a_empty)
);

apb_decoder #(
	.RAH_PACKET_WIDTH(RAH_PACKET_WIDTH)
)apb_dec(
	.clk            (dt_clk),
	.f_empty 		(w_apb_fifo_empty),
	.f_data			(w_apb_fifo_data),
	.f_rd_en		(w_apb_fifo_rd_en),
	.f_a_empty 		(w_apb_fifo_a_empty),
	
	.slv_id			(w_slv_id),
	.cfg_sel		(w_config),
	.data			(w_data),
	.length			(w_length),
	.first_frame	(w_first_frame)
);

/* assignment */
assign pp_wr_fifo_read_en = r_wr_fifo_read_rn;
assign w_wr_fifo_read_en = r_wr_fifo_read_rn;

endmodule
