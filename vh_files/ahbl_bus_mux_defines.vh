/*
:set expandtab
:set tabstop=4
:set shiftwidth=4
:retab

*/

`ifndef _AHBL_BUS_MUX_DEFINES_VH
`define _AHBL_BUS_MUX_DEFINES_VH

package ahbl_bus_mux_defines;

    localparam IDLE = 2'b00;
    localparam BUSY = 2'b01;
    localparam NONSEQ = 2'b10;
    localparam SEQ  = 2'b11;

    typedef struct packed {
        logic      [31:0] HADDR;
        logic      [ 2:0] HBURST;
        logic             HMASTLOCK;
        logic      [ 3:0] HPROT;
        logic      [ 2:0] HSIZE;
        logic      [ 1:0] HTRANS;
        logic             HWRITE;
    } aphase_t;

endpackage

`endif
