/*
	Interface for interrupt controller
	Author: Ruoyi Chen
*/

`ifndef INTERRUPT_CONTROLLER_IF_VH
`define INTERRUPT_CONTROLLER_IF_VH

interface plic_if ();

	parameter N_interrupts = 32;

 	logic interrupt_service_request, interrupt_clear;
	logic [N_interrupts-1:0] hw_interrupt_requests;
	
	logic [31:0]addr;
	logic ren;
	logic wen;
	logic [31:0]rdata;
	logic [31:0]wdata;
	logic rambusy;

	modport ic (
		input	hw_interrupt_requests, addr, ren, wen, wdata, rambusy, 
		output  interrupt_service_request, interrupt_clear, rdata

	);

	modport top (
		output	hw_interrupt_requests, addr, ren, wen, wdata, rambusy, 
		input  interrupt_service_request, interrupt_clear, rdata
	);
endinterface

`endif //INTERRUPT_CONTROLLER_IF_VH
