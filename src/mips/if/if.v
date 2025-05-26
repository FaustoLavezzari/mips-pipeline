`timescale 1ns / 1ps

module if_stage(
  input  wire       clk,
  input  wire       reset,
  output wire [31:0] o_next_pc,
  output wire [31:0] o_instr
);

  wire [31:0]   pc;
  wire [31:0]   pc_next; 
  wire [31:0]   instr;

  PC pc_inst(
    .clk    (clk),    
    .reset  (reset), 
    .pc     (pc)
  );

  instr_mem imem_inst ( 
    .addr   (pc),    
    .instr  (o_instr)
  );

  add4 add4_inst (
    .in   (pc), 
    .out  (o_next_pc)
  );

endmodule
