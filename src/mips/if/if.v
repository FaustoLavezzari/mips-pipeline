`timescale 1ns / 1ps
`include "../mips_pkg.vh"

module if_stage(
  input  wire       clk,
  input  wire       reset,
  // Entradas para branch prediction desde ID
  input  wire       i_branch_prediction,     // Señal de predicción (0 para not taken)
  input  wire [31:0] i_branch_target_addr,   // Dirección de destino del salto
  
  // Entradas para corrección de predicciones desde EX
  input  wire       i_mispredicted,          // Indica si hubo un error en la predicción
  input  wire       i_branch_taken,          // Indica si el salto se toma realmente
  input  wire [31:0] i_ex_branch_target,     // Dirección destino desde EX
  
  // Entradas para manejo de stalls
  input  wire       i_halt,                  // Señal de HALT para detener el PC
  input  wire       i_stall,                 // Señal de stall para detener el PC
  
  output wire [31:0] o_next_pc,
  output wire [31:0] o_instr
);

  wire [31:0]   pc;
  wire [31:0]   pc_next; 
  wire [31:0]   pc_selected; // PC seleccionado después de considerar predicciones/correcciones
  wire [31:0]   instr;

  // Calcular PC+4
  add4 add4_inst (
    .in   (pc), 
    .out  (pc_next)
  );
  
  // Seleccionar PC basado en predicciones y posibles correcciones
  // Prioridad: 1. Corrección de predicción 2. Predicción normal
  wire [31:0] branch_target = i_mispredicted ? 
                             (i_branch_taken ? i_ex_branch_target : pc_next) : 
                             (i_branch_prediction ? i_branch_target_addr : pc_next);
  wire        take_branch = i_mispredicted || i_branch_prediction;

  // Actualizar el PC con el valor seleccionado
  PC pc_inst(
    .clk           (clk),    
    .reset         (reset),
    .next_pc       (pc_next),
    .branch_target (branch_target),
    .take_branch   (take_branch),
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
