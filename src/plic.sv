`include "plic_if.vh"
module plic#(
    parameter N_interrupts = 32,
    parameter [31:0] base_address = 32'h80040000
)
(
    input wire clk,
    input wire n_rst,
    plic_if.ic icif
);


    logic [31:0] priority_addr, pending_addr, reserved_addr, enable_addr, priority_threshold_addr, claim_complete_addr;
    logic carry_over_mod;
    wire [N_interrupts-1:0]interrupt_requests_unmasked;
    wire [N_interrupts-1:0][31:0] interrupt_priority_regs;
    wire[N_interrupts-1:0] interrupt_masks;
    wire [N_interrupts-1:0]interrupt_requests_masked;
    wire [N_interrupts-1:0]pending_interrupts;
    wire interrupt_claimed;
    wire [31:0]active_interrupt_ID;
    wire [N_interrupts-1:0]active_interrupt;
    wire interrupt_priority_request;
    wire interrupt_processing;

    wire[31:0] rdata1; 
    wire[31:0] rdata2;
    wire[31:0] rdata3;
    wire addr_valid1;
    wire addr_valid2;
    wire addr_valid3;

    assign carry_over_mod = (N_interrupts[0] | N_interrupts[1] | N_interrupts[2] | N_interrupts[3] | N_interrupts[4]);
    assign icif.interrupt_clear = interrupt_claimed;

    assign priority_addr = base_address + 4;
    assign pending_addr = priority_addr + (N_interrupts << 2);
    assign enable_addr = pending_addr + (((N_interrupts >> 5) + carry_over_mod) << 2);
    assign reserved_addr = enable_addr + (((N_interrupts >> 5) + carry_over_mod) << 2);
    assign priority_threshold_addr = reserved_addr + 4;
    assign claim_complete_addr = priority_threshold_addr + 4;


    interrupt_enable_registers #(.N_interrupts(N_interrupts)) my_interrupt_en 	(
        .n_rst(n_rst), 
        .clk(clk), 
        .addr(icif.addr), 
        .wen(icif.wen), 
        .rdata(rdata1), 
        .wdata(icif.wdata), 
        .addr_valid(addr_valid1), 
        .interrupt_masks(interrupt_masks), 
        .enable_addr(enable_addr), 
        .reserved_addr(reserved_addr), 
        .priority_threshold_addr(priority_threshold_addr), 
        .claim_complete_addr(claim_complete_addr), 
        .interrupt_priority_regs(interrupt_priority_regs)
    );

    register_mask #(.N_interrupts(N_interrupts)) my_register_mask_module (
        .interrupt_masks(interrupt_masks), 
        .interrupt_requests(interrupt_requests_unmasked), 
        .interrupt_requests_masked(interrupt_requests_masked)
    );

    interrupt_pending_priority_registers#(.N_interrupts(N_interrupts)) my_interrupt_pending_priority (
        .clk(clk), 
        .n_rst(n_rst), 
        .interrupt_requests_masked(interrupt_requests_masked), 
        .pending_interrupts(pending_interrupts),
        .interrupt_priority_regs(interrupt_priority_regs), 
        .active_interrupt(active_interrupt), 
        .interrupt_claimed(interrupt_claimed), 
        .priority_addr(priority_addr),
        .pending_addr(pending_addr), 
        .enable_addr(enable_addr), 
        .addr(icif.addr), 
        .wen(icif.wen), 
        .rdata(rdata2), 
        .wdata(icif.wdata), 
        .addr_valid(addr_valid2)
    );

    interrupt_priority_resolve#(.N_INTERRUPTS(N_interrupts)) my_interrupt_priority_resolve (
        .clk(clk), 
        .n_rst(n_rst), 
        .interrupt_priorities(interrupt_priority_regs), 
        .pending_interrupts(pending_interrupts), 
        .active_interrupt(active_interrupt), 
        .active_interrupt_ID(active_interrupt_ID), 
        .interrupt_processing(interrupt_processing)
    );

    interrupt_request_reg#(.N_interrupts(N_interrupts)) my_interrupt_request_reg (
        .clk(clk), 
        .n_rst(n_rst), 
        .interrupt_requests_in(icif.hw_interrupt_requests), 
        .interrupt_requests(interrupt_requests_unmasked)
    );

    interrupt_claim_complete_register#(.N_interrupts(N_interrupts)) my_interrupt_claim_complete_register (
        .clk(clk), 
        .n_rst(n_rst), 
        .active_interrupt_ID(active_interrupt_ID), 
        .active_interrupt(active_interrupt),
        .interrupt_claimed(interrupt_claimed), 
        .interrupt_request_pulse(icif.interrupt_service_request), 
        .claim_complete_addr(claim_complete_addr),
        .addr(icif.addr), 
        .wen(icif.wen), 
        .rdata(rdata3),
        .wdata(icif.wdata), 
        .addr_valid(addr_valid3), 
        .ren(icif.ren), 
        .interrupt_processing(interrupt_processing)
    );

    rdata_arbiter my_rdata (
        .rdata1(rdata1), 
        .rdata2(rdata2), 
        .rdata3(rdata3), 
        .ren(icif.ren), 
        .addr_valid1(addr_valid1),
        .addr_valid2(addr_valid2),
        .addr_valid3(addr_valid3),
        .rdata(icif.rdata)
    );


endmodule
