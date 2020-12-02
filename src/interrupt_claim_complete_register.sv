/*
Patrick May
patrickmontemay@gmail.com

Spring 2018
SoC aftx04

This module controls the interrupt status register
and active interrupt register.

The interrupt status register contains the enable, interrupt serviced,
mask_all, and mask_below_val registers.

The info register is the value of the interrupt to be serviced.
*/
module interrupt_claim_complete_register #(
    parameter N_interrupts = 32
)
(
    input clk,
    input n_rst,
    input interrupt_processing,
    input reg [31:0]claim_complete_addr,
    input reg [31:0]active_interrupt_ID,
    //input wire interrupt_request,
    input reg [N_interrupts-1:0]active_interrupt,
    output reg interrupt_claimed,
    output wire interrupt_request_pulse,

    //Register Access Interface
    input wire [31:0]addr,
    input wire wen,
    input wire ren,
    output reg [31:0]rdata,
    input wire [31:0]wdata,
    output wire addr_valid
);
    //Register declarations
    //reg interrupt_request_prev;
    logic [31:0] claim_complete_reg;
    logic [31:0] claim_complete_reg_n;
    logic interrupt_claim, interrupt_claim_prev;
    logic interrupt_request, interrupt_request_prev;


    assign addr_valid = (addr >= claim_complete_addr) && (addr < (claim_complete_addr + 4));
    assign interrupt_request = wen & addr_valid & (active_interrupt_ID != '0);
    //assign interrupt_request_adjusted = interrupt_request & ~interrupt_request_prev;

    //Register/Write request logic
    always_ff @ (posedge clk, negedge n_rst)
    begin
        if(n_rst == 1'b0)
        begin
            //By default enable interrupt module
            claim_complete_reg <= '0;
            interrupt_claim_prev <= '0;
            interrupt_request_prev <= '0;

        end
        else
        begin
            claim_complete_reg <= claim_complete_reg_n;
            interrupt_claim_prev <= interrupt_claim;
            interrupt_request_prev <= interrupt_request;

        end
    end


    always_comb begin // writes are used to designate interrupt completion
        if (addr_valid && wen)
            claim_complete_reg_n = wdata;

        else if (interrupt_request_pulse)
            claim_complete_reg_n = active_interrupt_ID;

        else
            claim_complete_reg_n = claim_complete_reg;
    end


    //Assign wires to status register values
    //Interrupt request should pulse for 1 cycle
    assign interrupt_request_pulse = (interrupt_request_prev | interrupt_processing); // send out an interrupt either when a new interrupt came in, or right after the processor has written to the PLIC

    //Status register output
    assign interrupt_claim = (addr_valid && ren);
    assign interrupt_claimed = (interrupt_claim && ~interrupt_claim_prev); // interrupt claim occurs as soon as the claim_complete register is read

    //Read request logic
    always_comb // reads designate an interrupt claim
    begin
        if(addr_valid)
            rdata = claim_complete_reg;
        else
            rdata = 32'b0;
    end	
endmodule 
