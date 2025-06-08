`timescale 1ns / 1ps
`include "../mips_pkg.vh"

module if_id(
  input  wire       clk,
  input  wire       reset,
  input  wire       flush,        
  input  wire       stall,        
  input  wire [31:0] next_pc_in,  
  input  wire [31:0] instr_in,    
  output reg  [31:0] next_pc_out, 
  output reg  [31:0] instr_out    
);

  always @(posedge clk) begin
    if (reset || flush) begin
      next_pc_out <= 32'b0;
      instr_out   <= 32'b0;
    end 
    else if (!stall) begin  
      next_pc_out <= next_pc_in;
      instr_out   <= instr_in;
    end
  end

endmodule
