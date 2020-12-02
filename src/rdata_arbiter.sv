/*
  Patrick May
  patrickmontemay@gmail.com

  Spring 2018
  SoC aftx04

  This module multiplexes the read registers so that 
  only one is using the rdata bus at a time.
*/
module rdata_arbiter
(
	input wire [31:0]rdata1,
	input wire [31:0]rdata2,
	input wire [31:0]rdata3,
	input wire ren,
	input wire addr_valid1,
	input wire addr_valid2,
	input wire addr_valid3,
	output reg[31:0]rdata
);

	always_comb
	begin
		if(addr_valid1 & ren)
			rdata = rdata1;
		else if(addr_valid2 & ren)
			rdata = rdata2;
		else if(addr_valid3 & ren)
			rdata = rdata3;
		else 
			rdata = 'bZ; 
	end
endmodule
