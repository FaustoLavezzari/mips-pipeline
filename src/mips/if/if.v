`timescale 1ns / 1ps
`include "../mips_pkg.vh"

module if_stage(
  input  wire       clk,
  input  wire       reset,
  
  // Entradas para control de saltos desde ID (simplificadas)
  input  wire        i_take_branch,           // Señal unificada: saltar (1) o no (0)
  input  wire [31:0] i_branch_target_addr,   // Dirección de destino del salto
  
  // Entradas para manejo de stalls
  input  wire       i_halt,                  // Señal de HALT para detener el PC
  input  wire       i_stall,                 // Señal de stall para detener el PC
  
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
    
  // Seleccionar la dirección de destino
  wire [31:0] next_pc_selected = i_take_branch ? i_branch_target_addr : pc_next;

  // Actualizar el PC con el valor seleccionado
  PC pc_inst(
    .clk           (clk),    
    .reset         (reset),
    .next_pc       (next_pc_selected),
    .halt          (i_halt),
    .stall         (i_stall),
    .pc            (pc)
  );

  // Leer la instrucción de memoria
  instr_mem imem_inst ( 
    .addr   (pc),    
    .instr  (o_instr)
  );

  // Enviar PC+4 a la siguiente etapa
  assign o_next_pc = pc_next;

endmodule
