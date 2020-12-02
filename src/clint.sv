/*
*   Copyright 2016 Purdue University
*   
*   Licensed under the Apache License, Version 2.0 (the "License");
*   you may not use this file except in compliance with the License.
*   You may obtain a copy of the License at
*   
*       http://www.apache.org/licenses/LICENSE-2.0
*   
*   Unless required by applicable law or agreed to in writing, software
*   distributed under the License is distributed on an "AS IS" BASIS,
*   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
*   See the License for the specific language governing permissions and
*   limitations under the License.
*
*
*   Filename:     local_internal_controller.sv
*
*   Created by:   Enes Shaltami
*   Email:        ashaltam@purdue.edu
*   Date Created: 06/20/2020
*   Description:  Internal Interrupt Implementation for software and timer interrupts
*/
`include "clint_if.vh"


module clint (
    input clk, n_rst,
    clint_if.clint clif
);

    logic [31:0] mtime, mtime_next, mtimeh, mtimeh_next, mtimecmp, mtimecmp_next, mtimecmph, mtimecmph_next, msip, msip_next;
    logic [63:0] mtimefull, mtimefull_next, mtimecmpfull, mtimecmpfull_next;

    logic timer_int, prev_timer_int;

    // assignments for partial registers
    assign mtime = mtimefull[31:0];
    assign mtimeh = mtimefull[63:32];
    assign mtimecmp = mtimecmpfull[31:0];
    assign mtimecmph = mtimecmpfull[63:32];

    assign timer_int = (mtimefull >= mtimecmpfull);

    assign clif.timer_int = (timer_int & !prev_timer_int); // only get the first cycle of the interrupt since this interrupt is set high continuously
    assign clif.clear_timer_int = clif.wen & (clif.mtimecmp_sel | clif.mtimecmph_sel); // clear the pending interrupt if writing to one of the mtimecmp registers
    assign clif.soft_int = clif.wen & clif.wdata[0] & clif.msip_sel;
    assign clif.clear_soft_int = clif.wen & ~clif.wdata[0] & clif.msip_sel;

    assign msip_next = (clif.msip_sel & clif.wen)? clif.wdata : msip;


    always_ff @(posedge clk, negedge n_rst) begin
        if (!n_rst) begin
            mtimefull <= '0;
            mtimecmpfull <= '0;
            msip <= '0;
            prev_timer_int <= '0;

        end else begin
            mtimefull <= mtimefull_next;
            mtimecmpfull <= mtimecmpfull_next;
            msip <= msip_next;
            prev_timer_int <= timer_int;
        end
    end


    always_comb begin
        mtimefull_next = mtimefull + 1; // increment the mtimefull register
        if (clif.mtime_sel & clif.wen) mtimefull_next = {mtimefull[63:32], clif.wdata};
        else if (clif.mtimeh_sel & clif.wen) mtimefull_next = {clif.wdata, mtimefull[31:0]};
    end

    always_comb begin
        mtimecmpfull_next = mtimecmpfull; // keep the mtimecmp register the same until a requested change occurs
        if (clif.mtimecmp_sel & clif.wen) mtimecmpfull_next = {mtimecmpfull[63:32], clif.wdata};
        else if (clif.mtimecmph_sel & clif.wen) mtimecmpfull_next = {clif.wdata, mtimecmpfull[31:0]};
    end

    always_comb begin
        clif.rdata = 'bZ;
        if (clif.mtime_sel) clif.rdata = mtime;
        else if (clif.mtimeh_sel) clif.rdata = mtimeh;
        else if (clif.mtimecmp_sel) clif.rdata = mtimecmp;
        else if (clif.mtimecmph_sel) clif.rdata = mtimecmph;
        else if (clif.msip_sel) clif.rdata = msip;
    end

endmodule
