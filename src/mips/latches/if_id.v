`timescale 1ns / 1ps

module if_id(
  input  wire       clk,
  input  wire       reset,
  input  wire [31:0] next_pc_in,
  input  wire [31:0] instr_in,
  output reg  [31:0] next_pc_out,
  output reg  [31:0] instr_out
);
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      next_pc_out    <= 0;
      instr_out <= 0;
    end else begin
      next_pc_out    <= next_pc_in;
      instr_out <= instr_in;
    end
  end
endmodule
