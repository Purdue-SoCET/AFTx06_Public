`include "ahb_if.vh"
`include "plic_if.vh"
module plic_wrapper #(
  parameter [31:0] base_address = 32'h80040000,
  parameter N_interrupts = 32
)
(
  input logic clk,
  input logic n_rst,
  ahb_if.ahb_s ahbif,
  plic_if plicIf
);

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



  // assign plic inputs
  assign plicIf.wdata = ahbif.HWDATA;
  assign plicIf.rambusy = 1'b0;

  // latch the address phase of the ahb transaction since plic is combinational
  assign plicIf.wen = prev_wen;
  assign plicIf.ren = prev_ren;
  assign plicIf.addr = prev_addr;




  localparam NUMBER_ADDRESSES = (N_interrupts << 2) + (((N_interrupts >> 5) + (N_interrupts[0] | N_interrupts[1] | N_interrupts[2] | N_interrupts[3] | N_interrupts[4])) << 4) + 12;

  plic #(.base_address(base_address), .N_interrupts(N_interrupts)) PLIC(.clk(clk), .n_rst(n_rst), .icif(plicIf));


  ahb_slave #(.BASE_ADDRESS(base_address), .NUMBER_ADDRESSES(NUMBER_ADDRESSES)) AHBS2 (
  .HCLK(clk),
  .HRESETn(n_rst),
  .HMASTLOCK(ahbif.HMASTLOCK),
  .HWRITE(ahbif.HWRITE),
  .HSEL(ahbif.HSEL),
  .HREADYIN(1'b1),
  .HADDR(ahbif.HADDR),
  .HWDATA(ahbif.HWDATA),
  .HTRANS(ahbif.HTRANS),
  .HBURST(3'b0),
  .HSIZE(ahbif.HSIZE),
  .HPROT(ahbif.HPROT),
  .HRDATA(ahbif.HRDATA),
  .HREADYOUT(ahbif.HREADYOUT),
  .HRESP(ahbif.HRESP),


  .burst_cancel(1'b0),
  .slave_wait(1'b0),
  .rdata(plicIf.rdata),

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
