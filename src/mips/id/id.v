`timescale 1ns / 1ps
`include "../mips_pkg.vh"

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
  output wire [4:0]  o_rs,                 // Campo rs de la instrucción (para forwarding)
  output wire [4:0]  o_rt,                 // Campo rt de la instrucción
  output wire [4:0]  o_rd,                 // Campo rd de la instrucción
  output wire [5:0]  o_function,           // Campo function de la instrucción
  output wire [5:0]  o_opcode,             // Código de operación de la instrucción
  
  // Señales de control para EX
  output wire        o_alu_src,            // Selección del segundo operando de la ALU
  output wire [1:0]  o_alu_op,             // Operación de la ALU
  output wire        o_reg_dst,            // Selección del registro destino
  output wire        o_reg_write,          // Habilitación de escritura en banco de registros
  output wire        o_mem_read,           // Control de lectura de memoria
  output wire        o_mem_write,          // Control de escritura en memoria
  output wire        o_mem_to_reg,         // Selección entre ALU o memoria para WB
  output wire        o_branch,             // Indica si es una instrucción de salto
  
  // Nuevas salidas para branch prediction
  output wire        o_branch_prediction,   // Indica si se predice un salto (1) o no (0)
  output wire [31:0] o_branch_target_addr  // Dirección de destino del salto
);

  // Extraer los campos de la instrucción
  wire [5:0] opcode = i_instruction[31:26];
  wire [4:0] rs     = i_instruction[25:21];
  wire [4:0] rt     = i_instruction[20:16];
  wire [4:0] rd     = i_instruction[15:11];
  wire [15:0] immediate = i_instruction[15:0];
  
  // Extension de signo para el immediate
  assign o_sign_extended_imm = {{16{immediate[15]}}, immediate};
  
  // Calcular la dirección destino del salto: PC+4 + (immediate << 2)
  wire [31:0] shifted_imm = o_sign_extended_imm << 2;
  assign o_branch_target_addr = i_next_pc + shifted_imm;
  
  // Pasar campos rs, rt, rd y function a la siguiente etapa
  assign o_rs = rs;               // Pasar rs para forwarding
  assign o_rt = rt;
  assign o_rd = rd;
  assign o_function = i_instruction[5:0];
  assign o_opcode = opcode;  // Pasar también el opcode para distinguir entre instrucciones
  
  // Instanciar la unidad de control
  control control_inst (
    .opcode     (opcode),
    .reg_dst    (o_reg_dst),
    .reg_write  (o_reg_write),
    .alu_src    (o_alu_src),
    .alu_op     (o_alu_op),
    .mem_read   (o_mem_read), 
    .mem_write  (o_mem_write),
    .mem_to_reg (o_mem_to_reg),
    .branch     (o_branch),
    .branch_prediction (o_branch_prediction)
  );
  
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


