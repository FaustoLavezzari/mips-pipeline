`timescale 1ns / 1ps
`include "../mips_pkg.vh"
 
module ex_stage(
  // Señales de sistema
  input  wire        clk,
  input  wire        reset,
  
  // Datos de la etapa ID/EX
  input  wire [31:0] i_read_data_1,       // Valor del registro rs
  input  wire [31:0] i_read_data_2,       // Valor del registro rt
  input  wire [31:0] i_sign_extended_imm, // Immediate con extensión de signo
  input  wire [4:0]  i_rt,                // Registro RT
  input  wire [4:0]  i_rd,                // Registro RD
  input  wire [4:0]  i_rs,                // Registro RS (para forwarding)
  input  wire [31:0] i_shamt,             // Campo shamt ya extendido a 32 bits
  input  wire [31:0] i_next_pc,           // PC+4 para JAL/JALR
  
  // Señales de control
  input  wire        i_alu_src_b,         // Selección entre rt o inmediato
  input  wire [1:0]  i_alu_src_a,         // Selección entre rs o PC+4 o shamt
  input  wire        i_reg_dst,           // Selección registro destino
  input  wire        i_reg_write,         // Escritura en registros
  input  wire        i_mem_read,          // Lectura de memoria
  input  wire        i_mem_write,         // Escritura en memoria
  input  wire        i_mem_to_reg,        // Selección entre ALU o memoria
  input  wire        i_is_halt,           // Señal de HALT (para detener el pipeline)
  input  wire [3:0]  i_byte_mask,         // Máscara de bytes para memoria
  input  wire        i_is_signed_load,    // Indica si es una carga con extensión de signo
  input  wire [3:0]  i_alu_control,       // Control de la ALU (nueva)
  
  // Salidas hacia la etapa MEM
  output wire [31:0] o_alu_result,        // Resultado de la ALU
  output wire [31:0] o_read_data_2,       // Valor rt para store
  output wire [4:0]  o_write_register,    // Registro destino
  output wire        o_reg_write,         // Control de escritura 
  output wire        o_mem_read,          // Control de lectura
  output wire        o_mem_write,         // Control de escritura
  output wire        o_mem_to_reg,        // Selección para WB
  output wire        o_is_halt,           // Señal de HALT
  output wire [3:0]  o_byte_mask,         // Máscara de bytes para memoria
  output wire        o_is_signed_load     // Indica si es una carga con extensión de signo
);

  wire [31:0] alu_input_a;
  wire [31:0] alu_input_b;

  //----------------------------------------------------------------------
  // 1. OPERANDOS DE LA ALU
  //----------------------------------------------------------------------
  
  // Mux para selección del operando A de la ALU
  mux #(
    .CHANNELS(3),
    .BUS_SIZE(32)
  ) alu_src_a_mux (
    .selector(i_alu_src_a),
    .data_in({i_shamt, i_next_pc, i_read_data_1}),  
    .data_out(alu_input_a)
  );
  
  // Mux para selección del operando B de la ALU
  mux #(
    .CHANNELS(2),
    .BUS_SIZE(32)
  ) alu_src_b_mux (
    .selector(i_alu_src_b),
    .data_in({i_sign_extended_imm, i_read_data_2}),
    .data_out(alu_input_b)
  );
  
  //----------------------------------------------------------------------
  // 2. EJECUCIÓN DE LA ALU
  //----------------------------------------------------------------------
  // Unidad ALU - Usa directamente la señal de control generada en la etapa ID
  alu alu_inst (
    .a           (alu_input_a),
    .b           (alu_input_b),
    .alu_control (i_alu_control),  // Usa señal de control desde ID
    .result      (o_alu_result)
  );
  
  //----------------------------------------------------------------------
  // 3. SELECCIÓN DE REGISTRO Y SEÑALES DE CONTROL
  //----------------------------------------------------------------------
  // Mux para selección del registro destino
  mux #(
    .CHANNELS(2),
    .BUS_SIZE(5)
  ) reg_dst_mux (
    .selector(i_reg_dst),
    .data_in({i_rd, i_rt}),
    .data_out(o_write_register)
  );
  
  // Valor rt para instrucciones store
  assign o_read_data_2 = i_read_data_2;

  // Paso de señales de control a la siguiente etapa
  assign o_reg_write = i_reg_write;
  assign o_mem_read = i_mem_read;
  assign o_mem_write = i_mem_write;
  assign o_mem_to_reg = i_mem_to_reg;
  assign o_is_halt = i_is_halt;
  assign o_byte_mask = i_byte_mask;
  assign o_is_signed_load = i_is_signed_load;

endmodule
