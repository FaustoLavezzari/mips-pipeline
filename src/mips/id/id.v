`timescale 1ns / 1ps

module id_stage(
  input  wire        clk,
  input  wire        reset,
  input  wire [31:0] i_next_pc,      // PC+4 de la etapa IF
  input  wire [31:0] i_instruction,  // Instrucción de la etapa IF
  
  // Señales WB (para escritura en banco de registros)
  input  wire        i_reg_write,          // Señal de habilitación de escritura 
  input  wire [4:0]  i_write_register,     // Registro destino para WB
  input  wire [31:0] i_write_data,         // Dato a escribir en WB
  
  // Salidas hacia la etapa EX
  output wire [31:0] o_read_data_1,        // Valor del registro rs
  output wire [31:0] o_read_data_2,        // Valor del registro rt
  output wire [31:0] o_sign_extended_imm,  // Inmediato con extensión de signo
  output wire [4:0]  o_rt,                 // Campo rt de la instrucción
  output wire [4:0]  o_rd                  // Campo rd de la instrucción
);

  // Extraer los campos de la instrucción
  wire [5:0] opcode = i_instruction[31:26];
  wire [4:0] rs     = i_instruction[25:21];
  wire [4:0] rt     = i_instruction[20:16];
  wire [4:0] rd     = i_instruction[15:11];
  wire [15:0] immediate = i_instruction[15:0];
  
  // Extension de signo para el immediate
  assign o_sign_extended_imm = {{16{immediate[15]}}, immediate};
  
  // Pasar campos rt y rd a la siguiente etapa
  assign o_rt = rt;
  assign o_rd = rd;
  
  // Instanciar el banco de registros
  registers_bank reg_bank(
    .i_clk            (clk),
    .i_reset          (reset),
    .i_write_enable   (i_reg_write),
    .i_read_register_1(rs),
    .i_read_register_2(rt),
    .i_write_register (i_write_register),
    .i_write_data     (i_write_data),
    .o_read_data_1    (o_read_data_1),
    .o_read_data_2    (o_read_data_2)
  );

endmodule


