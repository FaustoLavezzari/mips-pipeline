`timescale 1ns / 1ps
`include "../mips_pkg.vh"

module if_stage(
  input  wire       clk,
  input  wire       reset,
  
  // Entradas para control de saltos desde ID (nueva implementación)
  input  wire       i_branch_taken,          // Indica si el salto condicional se toma
  input  wire       i_jump_taken,            // Indica si es un salto incondicional
  input  wire [31:0] i_branch_target_addr,   // Dirección de destino del salto
  
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
  
  // Decidir si se toma cualquier tipo de salto (condicional o incondicional)
  wire branch_or_jump_taken = i_branch_taken || i_jump_taken;
  
  // Seleccionar la dirección de destino
  wire [31:0] next_pc_value = branch_or_jump_taken ? i_branch_target_addr : pc_next;

  // Actualizar el PC con el valor seleccionado
  PC pc_inst(
    .clk           (clk),    
    .reset         (reset),
    .next_pc       (pc_next),
    .branch_target (i_branch_target_addr),
    .take_branch   (branch_or_jump_taken),
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
