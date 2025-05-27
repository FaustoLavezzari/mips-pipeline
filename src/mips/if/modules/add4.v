`timescale 1ns / 1ps
`include "../../mips_pkg.vh"

module add4
  #(
    parameter WIDTH = `DATA_WIDTH
  )
  (
    input  wire [WIDTH-1:0] in,
    output wire [WIDTH-1:0] out
  );

  assign out = in + {{(WIDTH-3){1'b0}}, 1'b1, 2'b00}; // 4 = 000...0100


endmodule