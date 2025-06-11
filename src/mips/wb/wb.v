`timescale 1ns / 1ps
`include "../mips_pkg.vh"

module wb_stage(
  input  wire        clk,
  input  wire        reset,
  
  // Entradas desde MEM/WB
  input  wire [31:0] i_alu_result,     // Resultado de la ALU
  input  wire [31:0] i_read_data,      // Dato leído de memoria
  input  wire [4:0]  i_write_register, // Registro destino
  input  wire        i_reg_write,      // Control de escritura en registros
  input  wire        i_mem_to_reg,     // Selección entre ALU o memoria
  // Ya no necesitamos señales especiales para JAL/JALR
  
  // Salidas para retroalimentación
  output wire [31:0] o_write_data,     // Dato a escribir en el banco de registros
  output wire [4:0]  o_write_register, // Registro destino
  output wire        o_reg_write       // Control de escritura en registros
);

  // Selecciona el dato a escribir en el banco de registros
  assign o_write_data = (i_mem_to_reg) ? i_read_data : i_alu_result;
  
  // Propagar las señales de control directamente
  // El registro destino ya fue configurado en la etapa ID para JAL/JALR
  assign o_write_register = i_write_register;
  assign o_reg_write = i_reg_write;

endmodule
