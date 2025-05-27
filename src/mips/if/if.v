`timescale 1ns / 1ps
`include "../mips_pkg.vh"

module if_stage(
  input  wire       clk,
  input  wire       reset,
  output wire [31:0] o_next_pc,
  output wire [31:0] o_instr
);

  wire [31:0]   pc;
  wire [31:0]   pc_next; 
  wire [31:0]   instr;

  // Calcular PC+4
  add4 add4_inst (
    .in   (pc), 
    .out  (pc_next)
  );

  // Actualizar el PC con el valor incrementado
  PC pc_inst(
    .clk     (clk),    
    .reset   (reset),
    .next_pc (pc_next),
    .pc      (pc)
  );

  // Leer la instrucción de memoria
  instr_mem imem_inst ( 
    .addr   (pc),    
    .instr  (o_instr)
  );

  // Enviar PC+4 a la siguiente etapa
  assign o_next_pc = pc_next;

endmodule
