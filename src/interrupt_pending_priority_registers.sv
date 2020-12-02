/*
Patrick May
patrickmontemay@gmail.com

Spring 2018
SoC aftx04

This module controls the interrupt pending registers
and interrupt priority registers.

There are roof(log2(N_interrupt)/32) interrupt pending registers
and N_interrupt priority registers.

Higher unsigned values in the priority registers are associated with
higher interrupt priority during arbitration.

*/

module interrupt_pending_priority_registers #(
    parameter N_interrupts = 32
)
(
    input logic clk, 
    input logic n_rst,
    input logic [N_interrupts-1:0]interrupt_requests_masked,
    output logic [N_interrupts-1:0]pending_interrupts,
    output reg [N_interrupts-1:0][31:0]interrupt_priority_regs,
    input logic [N_interrupts-1:0] active_interrupt,
    input logic interrupt_claimed,
    input logic [31:0] priority_addr,
    input logic [31:0] pending_addr,
    input logic [31:0] enable_addr,

    //Register Access Interface
    input logic [31:0]addr,
    input logic wen,
    output reg [31:0]rdata,
    input logic [31:0]wdata,
    output logic addr_valid
);
    //Register Definitions
    reg [(N_interrupts - 1) >> 5:0][31:0] interrupt_pending_regs;
    reg [(N_interrupts - 1) >> 5:0][31:0] interrupt_pending_regs_n;
    reg [N_interrupts - 1:0][31:0] interrupt_priority_regs_n;

    logic [31:0] addr_shifted_pending, addr_shifted_priority;

    //Translation logic definitions
    logic addr_valid_interrupt_pending, addr_valid_priority; 

    //Translate address relative to base address
    assign addr_shifted_pending = addr - pending_addr;
    assign addr_shifted_priority = addr - priority_addr;

    //Valid range definitions for address vectors
    assign addr_valid_interrupt_pending = (addr >= pending_addr) && (addr < enable_addr);
    assign addr_valid_priority = (addr >= priority_addr) && (addr < pending_addr);
    assign addr_valid = addr_valid_interrupt_pending || addr_valid_priority;

    //Strip off trailing zeros in interrupt pending regs
    //assign pending_interrupts[N_interrupts-1:0] = interrupt_pending_regs[0];
    genvar i;
    generate
        for (i=0; i < $size(interrupt_pending_regs); i++) begin : brian
            if (i == ($size(interrupt_pending_regs) - 1))
                assign pending_interrupts[N_interrupts-1:32*i] = interrupt_pending_regs[i];
            else
                assign pending_interrupts[32*i+31:32*i] = interrupt_pending_regs[i];      
        end
    endgenerate

    always_comb
    begin
        interrupt_pending_regs_n = (interrupt_pending_regs | interrupt_requests_masked);

        //disable the specific pending interrupt if it is currently being serviced
        if(interrupt_claimed == 1'b1)
        begin
            interrupt_pending_regs_n = (interrupt_pending_regs | interrupt_requests_masked) & ~active_interrupt;
        end

        //Manual activation of interrupts
        //if(addr_valid_interrupt_pending && wen)
        //begin
        //	interrupt_pending_regs_n[addr_shifted_pending >> 2] = wdata;
        //end

        //If we disable the module, clear all pending interrupts and don't accept any others
        //if(enable_module == 1'b0)
        //	interrupt_pending_regs_n = 'b0;

    end

    //Register next state logic
    always_ff @ (posedge clk, negedge n_rst)
    begin
        if(n_rst == 'b0)
        begin
            interrupt_pending_regs <= 'b0;
            interrupt_priority_regs <= 'b0;
        end
        else
        begin
            interrupt_pending_regs <= interrupt_pending_regs_n;
            interrupt_priority_regs <= interrupt_priority_regs_n;
        end
    end

    always_comb
    begin
        interrupt_priority_regs_n = interrupt_priority_regs;
        if(addr_valid_priority && wen) // Disclude the last 2 bits of the shifted priority
            interrupt_priority_regs_n[addr_shifted_priority >> 2] = {29'b0, wdata[2:0]}; 
    end


    always_comb
    begin
        if(addr_valid_priority) 
            rdata = interrupt_priority_regs[addr_shifted_priority >> 2];

        else if (addr_valid_interrupt_pending)
            rdata = interrupt_pending_regs[addr_shifted_pending >> 2];
        else
            rdata = 32'b0;
    end	

endmodule
