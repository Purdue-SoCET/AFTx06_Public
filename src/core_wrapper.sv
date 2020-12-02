/*
MODULE NAME         	: core_wrapper
AUTHOR                 	: Andrew Brito & Chuan Yean, Tan
LAST UPDATE        	: 6/26/13
VERSION         	: 1.0
DESCRIPTION         	: Wrapper interface between M0 Core and Debugger
*/

`include "ahb_if.vh"
`include "generic_bus_if.vh"
`include "core_interrupt_if.vh"

module core_wrapper(   
    //--INPUTS--//
    input		clk,
    input 		rst_n,
    //--DEBUG/UART SIGNALS--//
    input wire 	rx,
    output wire	tx,
    //--AHB BUS SIGNALS--//
    ahb_if.ahb_m muxed_ahb_if,
    //--INTERRUPT REQUEST--//
    core_interrupt_if.core interrupt_if        
);


    //CORE EXTRAS
    wire  TXEV;              // Event output (SEV executed)
    wire  LOCKUP;            // Core is locked-up
    wire  SYSRESETREQ;       // System reset request
    wire  SLEEPING;          // Core and NVIC sleeping
    wire M0_RST;

    //logic hprot;
    //assign HPROT = '0;

    // Interface Declarations
    ahb_if ahb_ifs[1:0]();


    //--PORT MAPS--//

    //--AHB-LITE MUX--//
    ahbl_bus_mux #(.MM(2)) BUS_MUX(
        .HCLK(clk),
        .HRESETn(rst_n),
        .m_in(ahb_ifs),
        .m_out(muxed_ahb_if)
    );

    // -- RISCV CORE --//
    RISCVBusiness RISCVBusiness (
        .CLK(clk),
        .nRST(M0_RST),
        .interrupt_if,
        .ahb_master(ahb_ifs[0])
    );

    assign ahb_ifs[1].HPROT = '0;
    //--DEBUGGER--//
    debugger_top debugger_top(
        .clk(clk),
        .rst_n(rst_n),
        .HREADY(ahb_ifs[1].HREADY),
        .HRDATA(ahb_ifs[1].HRDATA),
        .HWRITE(ahb_ifs[1].HWRITE),
        .HSIZE(ahb_ifs[1].HSIZE),
        .HBURST(ahb_ifs[1].HBURST),
        .HTRANS(ahb_ifs[1].HTRANS),
        .HADDR(ahb_ifs[1].HADDR),
        .HWDATA(ahb_ifs[1].HWDATA),
        .M0_RST(M0_RST),
        .rx(rx),
        .tx(tx) 
    );

endmodule

