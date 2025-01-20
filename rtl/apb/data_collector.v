module data_collector(
parameter RAH_PACKET_WIDTH = 48)
(
     /* Clock Signals */
    input                           clk,

    /* pp_wr_fifo signals */
    input [RAH_PACKET_WIDTH-1:0]    fifo_read_data,
    input                           f_empty,
    input                           f_a_empty,
    output                          fifo_read_en,

    /* peripheral_grp_v=ctrl signals */
    output [RAH_PACKET_WIDTH-1:0]   fifo_write_data,
    output							wr_en,
);

parameter RAH_PACKET_WIDTH  = 48;

reg [

always @(posedge clk) begin
    /* Input FIFO read control */
    if (!f_empty) begin
        r_fifo_read_en <= 1;
    end

    if (f_a_empty && r_fifo_read_en) begin
        r_fifo_read_en <= 0;
    end

    /* Control for data sample */
    flag_data_sample <= r_fifo_read_en;

    /* Data sample and transfer */
    if (flag_data_sample) begin
            r_read_data <= fifo_read_data;
			r_wr_en <= 1'b1;
	end else begin
			r_wr_en <= 1'b0;
	end
end

assign wr_en = r_wr_en;
assign fifo_write_data = r_read_data;

endmodule
