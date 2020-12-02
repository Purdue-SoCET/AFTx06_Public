/*
Kenneth Jay Knepp
2*jj2*jnepp@purdue.edu

Spring 2018
SoC aftx04

Scaleable Inerrupt Priority Resolve

*/

module interrupt_priority_resolve #(
    parameter N_INTERRUPTS = 32
)
(
    input wire clk,
    input wire n_rst,
    input logic [N_INTERRUPTS-1:0][31:0] interrupt_priorities,
    input logic [N_INTERRUPTS-1:0] pending_interrupts, 
    output logic [N_INTERRUPTS-1:0] active_interrupt,
    output logic [31:0] active_interrupt_ID,
    //output logic interrupt_request,
    output logic interrupt_processing
);

    logic [N_INTERRUPTS-1:0][31:0] max_ids, max_priorities; // size is N_interrupts wide because we need to iterate through all the interrupts in order to find the max priority and id 
    logic [$clog2(N_INTERRUPTS):0][N_INTERRUPTS-1:0][31:0] ids, priorities;

    //logic [N_INTERRUPTS-1:0] active_interrupt_prev;
    logic interrupt_process, interrupt_process_prev;

    //assign interrupt_request = (active_interrupt != active_interrupt_prev); // pulse when any of the active interrupts change

    //assign active_interrupt_ID = max_ids[N_INTERRUPTS-1];
    assign active_interrupt_ID = (ids[$clog2(N_INTERRUPTS)][0] == 0) ? '0 : ids[$clog2(N_INTERRUPTS)][0];
    assign active_interrupt = (ids[$clog2(N_INTERRUPTS)][0] == 0) ? '0 : 'b1 << (ids[$clog2(N_INTERRUPTS)][0] - 1);

    assign interrupt_process = (pending_interrupts != '0);
    assign interrupt_processing = (interrupt_process & ~interrupt_process_prev); // pulse when there were originally 0 interrupts, and now an interrupt has occurred

    always_ff @(posedge clk, negedge n_rst) begin
        if (!n_rst) begin
            //active_interrupt_prev <= '0;
            interrupt_process_prev <= '0;
        end else begin 
            //active_interrupt_prev <= active_interrupt;
            interrupt_process_prev <= interrupt_process;
        end
    end

    /*
    always_comb begin
        active_interrupt = '0;
        if((pending_interrupts != '0) & (max_ids[N_INTERRUPTS-1] != '0)) begin // check that there exists a pending interrupt and that there is a non-zero ID associated with it
            active_interrupt[max_ids[N_INTERRUPTS-1]-1] = 1'b1;
        end
    end
    */

    /*
    * Pending interrupt tree
    *
    */


    genvar i, j;
    generate
        // outer loop: Tree levels (spans of 2^i interrupts)
        for(i = 0; i <= $clog2(N_INTERRUPTS); i++) begin : brian
            for(j = 0; j < 2**($clog2(N_INTERRUPTS)-i); j++) begin : brian
                if(i == 0) begin
                    assign ids[i][j]        = pending_interrupts[j] ? j+1 : 0;
                    assign priorities[i][j] = pending_interrupts[j] ? interrupt_priorities[j] : 0;
                end else begin
                    assign ids[i][j]        = (priorities[i-1][2*j] >= priorities[i-1][2*j+1]) ? ids[i-1][2*j]        : ids[i-1][2*j+1];
                    assign priorities[i][j] = (priorities[i-1][2*j] >= priorities[i-1][2*j+1]) ? priorities[i-1][2*j] : priorities[i-1][2*j+1];
                end
            end
        end
    endgenerate

    /*
    genvar i;
    generate 
        for(i=0; i<N_INTERRUPTS; i++) begin
            if(i == 0) begin
                //Assign for each Stage: |   Determine if current priority is higher and is pending|         Replace with first|   Pass 0 through
                assign max_ids[i]        = (pending_interrupts[i])                            ?                        i+1:   0;
                assign max_priorities[i] = (pending_interrupts[i])                            ?    interrupt_priorities[i]:   0;
            end else begin
                //Assign for each Stage: |                    Determine if current priority is higher and is pending|       Replace with current|   Pass the previous through
                assign max_ids[i]        = ((interrupt_priorities[i] >= max_priorities[i-1]) & pending_interrupts[i])?                        i+1:            max_ids[i-1];
                assign max_priorities[i] = ((interrupt_priorities[i] >= max_priorities[i-1]) & pending_interrupts[i])?    interrupt_priorities[i]:     max_priorities[i-1];
            end
        end
    endgenerate
    */


endmodule
