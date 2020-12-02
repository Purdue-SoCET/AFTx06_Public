/*
Patrick May
patrickmontemay@gmail.com

Spring 2018
SoC aftx04

This module performs rising edge detection on external interrupt requests
*/
module interrupt_request_reg #(
    parameter N_interrupts = 32
)
(
    input clk,
    input n_rst,
    input wire [N_interrupts-1:0]interrupt_requests_in,
    output reg [N_interrupts-1:0]interrupt_requests
);

    //Register Definitions
    reg [N_interrupts-1:0]interrupt_requests_in_prev;
    reg [N_interrupts-1:0]interrupt_requests_next;

    //Next state logic
    always_ff @(posedge clk, negedge n_rst)
    begin
        if(n_rst == 'b0)
        begin
            interrupt_requests_in_prev <= 'b0;
            interrupt_requests <= 'b0;
        end
        else
        begin
            interrupt_requests <= interrupt_requests_next;
            interrupt_requests_in_prev <= interrupt_requests_in;
        end	
    end

    //Rising edge detector logic
    always_comb
    begin
        interrupt_requests_next = interrupt_requests_in & ~interrupt_requests_in_prev;
    end

endmodule
