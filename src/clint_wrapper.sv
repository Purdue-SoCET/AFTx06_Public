`include "ahb_if.vh"
`include "clint_if.vh"
module clint_wrapper #(
    parameter [31:0] base_address = 32'h80050000
)
(
    input logic clk,
    input logic n_rst,
    ahb_if.ahb_s ahbif,
	 output logic timer_int, clear_timer_int, soft_int, clear_soft_int
    //clint_if.top ctopIf();
	 //output logic [31:0] clintIf.addr
);
    clint_if clintIf();
	 assign timer_int = clintIf.timer_int;
	 assign clear_timer_int = clintIf.clear_timer_int;
	 assign soft_int = clintIf.soft_int;
	 assign clear_soft_int = clintIf.clear_soft_int;
	 
    logic [31:0] wdata, addr;
    logic r_prep, w_prep;
    logic wen, ren;
    logic [2:0] size;
    logic [4:0] burst_count;
    logic [2:0] burst_type;
	

    logic [31:0] prev_addr;
    logic prev_ren, prev_wen;

    always_ff @(posedge clk, negedge n_rst) begin
        if (!n_rst) begin
            prev_addr <= '0;
            prev_ren <= '0;
            prev_wen <= '0;

        end else begin
            prev_addr <= ahbif.HADDR;
            prev_ren <= ~ahbif.HWRITE;
            prev_wen <= ahbif.HWRITE;

        end
    end



    // assign clint inputs
    assign clintIf.wdata = ahbif.HWDATA;
    assign clintIf.rambusy = 1'b0;

    // latch the address phase of the ahb transaction since clint is combinational
    assign clintIf.wen = prev_wen;
    assign clintIf.ren = prev_ren;
    assign clintIf.addr = prev_addr;

    // add in the modified input clint signals
    assign clintIf.msip_sel = (clintIf.addr == base_address);
    assign clintIf.mtime_sel = (clintIf.addr == (base_address + 4));
    assign clintIf.mtimeh_sel = (clintIf.addr == (base_address + 8));
    assign clintIf.mtimecmp_sel = (clintIf.addr == (base_address + 12));
    assign clintIf.mtimecmph_sel = (clintIf.addr == (base_address + 16));



    localparam NUMBER_ADDRESSES = (5 << 2); // msip is one word (4 bytes), and mtime and mtimecmp are both double-words, which result in a total of 5 words 

    clint CLINT(.clk(clk), .n_rst(n_rst), .clif(clintIf));

	 logic HMASTLOCK, HWRITE, HSEL;
    logic [31:0] HADDR, HWDATA;
    logic [1:0] HTRANS;
    logic [2:0] HSIZE;
    logic [3:0] HPROT; 

	 assign HMASTLOCK = ahbif.HMASTLOCK;
	 assign HWRITE = ahbif.HWRITE;
	 assign HSEL = ahbif.HSEL;
    assign HADDR = ahbif.HADDR;
	 assign HWDATA = ahbif.HWDATA;
    assign HTRANS = ahbif.HTRANS;
    assign HSIZE = ahbif.HSIZE;
    assign HPROT = ahbif.HPROT;

    logic [31:0] HRDATA;
    logic HREADYOUT; 
    logic HRESP;
	 
	 assign ahbif.HRDATA = HRDATA;
	 assign ahbif.HREADYOUT = HREADYOUT;
	 assign ahbif.HRESP = HRESP;
	 
    ahb_slave #(.BASE_ADDRESS(base_address), .NUMBER_ADDRESSES(NUMBER_ADDRESSES)) AHBS2 (
        .HCLK(clk),
        .HRESETn(n_rst),
        .HMASTLOCK(HMASTLOCK),
        .HWRITE(HWRITE),
        .HSEL(HSEL),
        .HREADYIN(1'b1),
        .HADDR(HADDR),
        .HWDATA(HWDATA),
        .HTRANS(HTRANS),
        .HBURST(3'b0),
        .HSIZE(HSIZE),
        .HPROT(HPROT),
        .HRDATA(HRDATA),
        .HREADYOUT(HREADYOUT),
        .HRESP(HRESP),


        .burst_cancel(1'b0),
        .slave_wait(1'b0),
        .rdata(clintIf.rdata),

        .wdata(wdata),
        .addr(addr),
        .r_prep(r_prep),
        .w_prep(w_prep),
        .wen(wen),
        .ren(ren),
        .size(size),
        .burst_count(burst_count),
        .burst_type(burst_type)
		  
    );

endmodule
