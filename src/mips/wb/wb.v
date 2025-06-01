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
  input  wire [31:0] i_pc_plus_4,      // PC+4 para JAL/JALR
  input  wire        i_is_jal,         // Indica si es instrucción JAL/JALR
  
  // Salidas para retroalimentación
  output wire [31:0] o_write_data,     // Dato a escribir en el banco de registros
  output wire [4:0]  o_write_register, // Registro destino
  output wire        o_reg_write       // Control de escritura en registros
);

  // Selecciona el dato a escribir en el banco de registros
  // Para JAL/JALR, el dato a escribir es PC+4, para otras instrucciones sigue la lógica normal
  wire [31:0] mem_alu_result = (i_mem_to_reg) ? i_read_data : i_alu_result;
  assign o_write_data = (i_is_jal) ? i_pc_plus_4 : mem_alu_result;
  
  // Propagar las señales de control
  // Para instrucciones JAL, el registro destino es siempre $31 (registro de retorno)
  assign o_write_register = i_is_jal ? 5'b11111 : i_write_register;
  assign o_reg_write = i_reg_write;

endmodule
