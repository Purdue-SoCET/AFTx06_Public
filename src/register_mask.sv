/*
  Patrick May
  patrickmontemay@gmail.com

  Spring 2018
  SoC aftx04

  This module masks incoming interrupts
  based on current mask settings
*/
module register_mask
#(
parameter N_interrupts = 32
)
(
	input wire [N_interrupts-1:0]interrupt_requests,
	input wire [N_interrupts-1:0]interrupt_masks,
	output wire [N_interrupts-1:0]interrupt_requests_masked
);

	assign interrupt_requests_masked = interrupt_requests & ~interrupt_masks;

endmodule