`timescale 1ns / 1ps
`include "../../mips_pkg.vh"

module PC(
  input  wire       clk,
  input  wire       reset,
  input  wire [31:0] next_pc,
  input  wire [31:0] branch_target,  // Dirección del salto
  input  wire       take_branch,     // Señal para tomar el salto
  output reg [31:0] pc
);

  always @(posedge clk) begin
    if (reset) 
      pc <= {`DATA_WIDTH{1'b0}};
    else if (take_branch)
      pc <= branch_target;
    else 
      pc <= next_pc;
  end
endmodule
