/*
	Interface for interrupt controller
	Author: Enes Shaltami
*/

`ifndef CLINT_IF_VH
`define CLINT_IF_VH

interface clint_if ();


  logic mtime_sel, mtimeh_sel, mtimecmp_sel, mtimecmph_sel, msip_sel, wen, ren;
  logic [31:0] wdata; // data to write to a register
  logic [31:0] rdata; // data read from a register
  logic timer_int, clear_timer_int, soft_int, clear_soft_int; // interrupt signals
  logic [31:0] addr;
  logic rambusy;


	modport clint (
		input	mtime_sel, mtimeh_sel, mtimecmp_sel, mtimecmph_sel, msip_sel, wen, wdata, ren, addr, rambusy,
		output  rdata, timer_int, clear_timer_int, soft_int, clear_soft_int

	);

	modport top (
		output	mtime_sel, mtimeh_sel, mtimecmp_sel, mtimecmph_sel, msip_sel, wen, wdata, ren,
		input  rdata, timer_int, clear_timer_int, soft_int
	);
endinterface

`endif //CLINT_IF_VH
