`timescale 1ns / 1ps
`include "../mips_pkg.vh"

module if_id(
  input  wire       clk,
  input  wire       reset,
  input  wire [31:0] next_pc_in,
  input  wire [31:0] instr_in,
  output reg  [31:0] next_pc_out,
  output reg  [31:0] instr_out
);
  always @(posedge clk) begin
    if (reset) begin
      next_pc_out    <= {`DATA_WIDTH{1'b0}};
      instr_out <= {`DATA_WIDTH{1'b0}};
    end else begin
      next_pc_out    <= next_pc_in;
      instr_out <= instr_in;
    end
  end
endmodule
