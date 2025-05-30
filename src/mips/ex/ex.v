`timescale 1ns / 1ps
`include "../mips_pkg.vh"

module ex_stage(
  input  wire        clk,
  input  wire        reset,
  
  // Datos de la etapa ID/EX
  input  wire [31:0] i_read_data_1,     // Valor del registro rs
  input  wire [31:0] i_read_data_2,     // Valor del registro rt
  input  wire [31:0] i_sign_extended_imm, // Immediate con extensión de signo
  input  wire [5:0]  i_function,        // Campo function de la instrucción
  input  wire [4:0]  i_rt,              // Registro RT
  input  wire [4:0]  i_rd,              // Registro RD
  
  // Señales de control para la etapa EX
  input  wire        i_alu_src,         // Selecciona entre registro rt (0) o inmediato (1)
  input  wire [1:0]  i_alu_op,          // Operación a realizar en la ALU
  input  wire        i_reg_dst,         // Selecciona registro destino: rt (0) o rd (1)
  input  wire        i_reg_write,       // Señal de escritura en registros
  input  wire        i_mem_read,        // Control de lectura de memoria
  input  wire        i_mem_write,       // Control de escritura en memoria
  input  wire        i_mem_to_reg,      // Selecciona entre ALU o memoria para WB
  input  wire        i_branch,          // Indica si es instrucción de salto
  
  // Salidas hacia la etapa MEM
  output wire [31:0] o_alu_result,      // Resultado de la ALU
  output wire [31:0] o_read_data_2,     // Valor del registro rt (para SW)
  output wire [4:0]  o_write_register,  // Registro destino para WB
  output wire        o_reg_write,       // Señal de escritura en registros
  output wire        o_mem_read,        // Control de lectura de memoria
  output wire        o_mem_write,       // Control de escritura en memoria
  output wire        o_mem_to_reg,      // Selecciona entre ALU o memoria para WB
  output wire        o_branch           // Indica si es instrucción de salto
);

  // Datos intermedios
  wire [31:0] alu_input_2;    // Segundo operando de la ALU
  wire [3:0]  alu_control;    // Señal de control para la ALU
  wire [4:0]  write_reg_rt_rd; // Registro destino (entre rt y rd)
  
  // Instancia del controlador de la ALU
  alu_control alu_control_inst (
    .func_code   (i_function),
    .alu_op      (i_alu_op),
    .alu_control (alu_control)
  );

  // Instancia de la ALU
  alu alu_inst (
    .a           (i_read_data_1),
    .b           (alu_input_2),
    .alu_control (alu_control),
    .result      (o_alu_result)
  );
  
  // MUX para seleccionar entre rt y el inmediato como segundo operando de la ALU
  assign alu_input_2 = (i_alu_src) ? i_sign_extended_imm : i_read_data_2;
  
  // MUX para seleccionar entre rt y rd como registro destino
  assign o_write_register = (i_reg_dst) ? i_rd : i_rt;
  
  // Pasar el valor de read_data_2 directamente como salida (para instrucciones store)
  assign o_read_data_2 = i_read_data_2;

  // Pasar las señales de control
  assign o_reg_write = i_reg_write;
  assign o_mem_read = i_mem_read;
  assign o_mem_write = i_mem_write;
  assign o_mem_to_reg = i_mem_to_reg;
  assign o_branch = i_branch;

endmodule
