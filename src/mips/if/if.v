`timescale 1ns / 1ps
`include "../mips_pkg.vh"

module if_stage(
  input  wire       clk,
  input  wire       reset,
  
  // Entradas para control de saltos desde ID (simplificadas)
  input  wire        i_take_branch,           // Señal unificada: saltar (1) o no (0)
  input  wire [31:0] i_branch_target_addr,    // Dirección de destino del salto
  
  // Entradas para manejo de stalls
  input  wire        i_stall,                  // Señal de stall para detener el PC
  
  // Entradas para escritura de instrucciones desde fuera
  input  wire        i_inst_write_en,          // Señal de habilitación de escritura
  input  wire [31:0] i_inst_write_addr,        // Dirección a escribir
  input  wire [31:0] i_inst_write_data,        // Instrucción a escribir
  
  output wire [31:0] o_next_pc,
  output wire [31:0] o_instr
);

  wire [31:0]   pc;
  wire [31:0]   pc_next; 
  wire [31:0]   instr;
  wire [31:0] next_pc_selected;


  // Calcular PC+4 
  adder #(
    .WIDTH(32)
  ) pc_adder_inst (
    .a(pc),
    .b(32'd4),
    .sum(pc_next)
  );
    
  // Seleccionar la dirección de destino
  mux #(
    .CHANNELS(2),
    .BUS_SIZE(32)
  ) pc_mux_inst (
    .selector(i_take_branch),  
    .data_in({i_branch_target_addr, pc_next}),
    .data_out(next_pc_selected)
  );

  PC pc_inst(
    .clk           (clk),    
    .reset         (reset),
    .next_pc       (next_pc_selected),
    .stall         (i_stall),
    .pc            (pc)
  );

  
  instr_mem imem_inst ( 
    .clk       (clk),
    .reset     (reset),
    .write_en  (i_inst_write_en),
    .read_en   (1'b1),                
    .read_addr (pc),                  
    .write_addr(i_inst_write_addr),  
    .write_data(i_inst_write_data),
    .instr     (o_instr)
  );

  assign o_next_pc = pc_next;

endmodule
