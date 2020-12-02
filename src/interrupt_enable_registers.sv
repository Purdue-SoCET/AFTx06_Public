/*
Patrick May
patrickmontemay@gmail.com

Spring 2018
SoC aftx04

This module arbitrates interrupt masking registers
and handles mask_below_val calculation
*/
module interrupt_enable_registers#(
    parameter N_interrupts = 32
)
(
    input wire n_rst,
    input wire clk,

    input logic [31:0] enable_addr,
    input logic [31:0] reserved_addr,
    input logic [31:0] priority_threshold_addr,
    input logic [31:0] claim_complete_addr,
    input wire[N_interrupts-1:0][31:0] interrupt_priority_regs,
    output reg[N_interrupts-1:0] interrupt_masks,

    input wire[31:0] addr,
    input wire wen,
    output reg[31:0] rdata,
    input wire[31:0] wdata,
    output wire addr_valid
);

    // File should handle interrupt enable as well as the priority threshold
    // mask an interrupt if the enable bit is turned off, OR the priority is <= than the threshold priority
    //Register definitions
    logic [(N_interrupts) >> 5:0][31:0] interrupt_enable_regs;
    logic [(N_interrupts) >> 5:0][31:0] interrupt_enable_regs_n;
    logic [31:0] interrupt_priority_thresh_regs;
    logic [31:0] interrupt_priority_thresh_regs_n;

    wire[31:0] addr_shifted_enable;
    reg [N_interrupts-1:0]interrupt_priority_below_mask_val;

    logic addr_valid_enable;
    logic addr_valid_priority_thresh;

    //First register is mask_below_val, next are PLIC R/W values
    assign addr_shifted_enable = addr - enable_addr;
    assign addr_valid_enable = (addr >= enable_addr) && (addr < reserved_addr);
    assign addr_valid_priority_thresh = (addr >= priority_threshold_addr) && (addr < claim_complete_addr);
    assign addr_valid = addr_valid_enable || addr_valid_priority_thresh;	

    //Low priority Mask Logic
    always_comb
    begin
        integer n;
        for(n=0; n<N_interrupts; n=n+1)
        begin
            if(interrupt_priority_regs[n] <= interrupt_priority_thresh_regs | ~interrupt_enable_regs[(n+1) >> 5][(n+1) & 32'd31]) // if the incoming priority is smaller than the threshold or it is disabled, it needs to be masked and not allowed to proceed to the processor
                interrupt_masks[n] = 1'b1;
            else
                interrupt_masks[n] = 1'b0;
        end
    end

    //Register Logic
    always_ff @(posedge clk, negedge n_rst)
    begin
        if(n_rst == 0)
        begin
            interrupt_enable_regs <= '0;
            interrupt_priority_thresh_regs <= '0;
        end
        else
        begin
            interrupt_enable_regs <= interrupt_enable_regs_n;
            interrupt_priority_thresh_regs <= interrupt_priority_thresh_regs_n;
        end
    end


    //Read value logic
    always_comb
    begin
        if(addr_valid_enable)
            rdata = interrupt_enable_regs[addr_shifted_enable >> 2];
        else if(addr_valid_priority_thresh)
            rdata = interrupt_priority_thresh_regs;
        else
            rdata = 'b0; 
    end


    always_comb begin
        interrupt_enable_regs_n = interrupt_enable_regs;
        if (addr_valid_enable & wen)
            interrupt_enable_regs_n[addr_shifted_enable >> 2] = wdata;
    end

    always_comb begin
        if (addr_valid_priority_thresh & wen)
            interrupt_priority_thresh_regs_n = wdata;

        else
            interrupt_priority_thresh_regs_n = interrupt_priority_thresh_regs;
    end


endmodule
