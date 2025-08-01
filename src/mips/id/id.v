`timescale 1ns / 1ps
`include "../mips_pkg.vh"

module id_stage(
  // Señales de sistema
  input  wire        clk,
  input  wire        reset,
  
  // Entradas desde la etapa IF
  input  wire [31:0] i_next_pc,          // PC+4 de la etapa IF
  input  wire [31:0] i_instruction,      // Instrucción de la etapa IF
  
  // Entradas para escritura en banco de registros (WB)
  input  wire        i_reg_write,        // Habilitación de escritura 
  input  wire [4:0]  i_write_register,   // Registro destino para WB
  input  wire [31:0] i_write_data,       // Dato a escribir en WB
  
  // Señales para forwarding
  input  wire [31:0] i_forwarded_value_a, // Valor forwardeado para RS
  input  wire [31:0] i_forwarded_value_b, // Valor forwardeado para RT
  input  wire        i_use_forwarded_a,   // Control de forwarding para RS
  input  wire        i_use_forwarded_b,   // Control de forwarding para RT
  
  // Salidas de datos hacia EX
  output wire [31:0] o_read_data_1,       // Valor del registro rs
  output wire [31:0] o_read_data_2,       // Valor del registro rt
  output wire [31:0] o_sign_extended_imm, // Inmediato con extensión de signo
  output wire [4:0]  o_rs,                // Campo rs
  output wire [4:0]  o_rt,                // Campo rt
  output wire [4:0]  o_rd,                // Campo rd
  output wire [31:0] o_shamt,             // Campo shamt
  output wire [5:0]  o_opcode,            // Campo opcode de la instrucción

  // debugging i/o
  input wire [4:0]  i_debug_reg,
  output wire [31:0] o_debug_reg_value,   // Valor del registro de depuración

  // Señales de control para EX
  output wire        o_alu_src_b,         // Selección del segundo operando ALU
  output wire [1:0]  o_alu_src_a,         // Selección del primer operando ALU
  output wire        o_reg_dst,           // Selección del registro destino
  output wire        o_reg_write,         // Habilitación escritura en banco de registros
  output wire        o_mem_read,          // Control de lectura de memoria
  output wire        o_mem_write,         // Control de escritura en memoria
  output wire        o_mem_to_reg,        // Selección entre ALU o memoria para WB
  output wire [3:0]  o_byte_mask,         // Máscara de bytes para memoria
  output wire        o_is_signed_load,    // Indica si es una carga con extensión de signo
  output wire [3:0]  o_alu_control,       // Control de la ALU (nueva)
  
  // Salidas para control de saltos
  output wire [31:0] o_branch_target_addr, // Dirección de destino del salto
  output wire        o_take_branch         // Señal de control de salto
);

  //----------------------------------------------------------------------
  // DECLARACIONES DE SEÑALES INTERNAS
  //----------------------------------------------------------------------
  // Señales decodificadas de instrucción (salidas del instruction_decoder)
  wire [5:0]  opcode;
  wire [4:0]  rd;
  wire [5:0]  funct;
  wire [25:0] target;
  
  // Señales del banco de registros (salidas del registers_bank)
  wire [31:0] reg_data_1;
  wire [31:0] reg_data_2;
  
  // Señales de control
  wire        is_equal = (o_read_data_2 == o_read_data_1);
  wire [1:0]  target_addr_sel;
  wire        is_jal;
  
  // Señales de direcciones de salto
  wire [31:0] shifted_imm = o_sign_extended_imm << 2;              // Desplazamiento para branch
  wire [31:0] branch_target;                                       // Salida del adder
  wire [31:0] jump_target = {i_next_pc[31:28], target, 2'b00};     // Jump target para J/JAL
  wire [31:0] jr_target = o_read_data_1;                           // Target para JR/JALR (contenido de rs)

  //----------------------------------------------------------------------
  // 1. DECODIFICACIÓN DE LA INSTRUCCIÓN
  //----------------------------------------------------------------------
  // Instancia del decodificador de instrucciones
  instruction_decoder inst_decoder (
    .i_instruction       (i_instruction),
    .o_opcode            (opcode),
    .o_rs                (o_rs),
    .o_rt                (o_rt),
    .o_rd                (rd),
    .o_funct             (funct),
    .o_shamt             (o_shamt),
    .o_sign_extended_imm (o_sign_extended_imm),
    .o_target            (target)
  );
  
  // Asignar opcode como salida
  assign o_opcode = opcode;

  //----------------------------------------------------------------------
  // 2. BANCO DE REGISTROS Y FORWARDING
  //----------------------------------------------------------------------
  // Instancia del banco de registros
  registers_bank reg_bank(
    .i_clk            (clk),
    .i_reset          (reset),
    .i_write_enable   (i_reg_write),
    .i_read_register_1(o_rs),
    .i_read_register_2(o_rt),
    .i_write_register (i_write_register),
    .i_write_data     (i_write_data),
    .o_read_data_1    (reg_data_1),
    .o_read_data_2    (reg_data_2),
    .i_debug_reg      (i_debug_reg),
    .o_debug_reg_value(o_debug_reg_value)
  );
  
  // Mux para forwarding del operando A (RS)
  mux #(
    .CHANNELS(2),
    .BUS_SIZE(32)
  ) forwarding_mux_a (
    .selector(i_use_forwarded_a),
    .data_in({i_forwarded_value_a, reg_data_1}),
    .data_out(o_read_data_1)
  );
  
  // Mux para forwarding del operando B (RT) 
  mux #(
    .CHANNELS(2),
    .BUS_SIZE(32)
  ) forwarding_mux_b (
    .selector(i_use_forwarded_b),
    .data_in({i_forwarded_value_b, reg_data_2}),
    .data_out(o_read_data_2)
  );

  //----------------------------------------------------------------------
  // 3. UNIDAD DE CONTROL Y SEÑALES DERIVADAS
  //----------------------------------------------------------------------
  control control_inst (
    .opcode       (o_opcode),
    .funct        (funct),
    .i_is_equal   (is_equal),
    .reg_dst      (o_reg_dst),
    .reg_write    (o_reg_write),
    .alu_src_b    (o_alu_src_b),
    .alu_src_a    (o_alu_src_a),
    .mem_read     (o_mem_read),
    .mem_write    (o_mem_write),
    .mem_to_reg   (o_mem_to_reg),
    .byte_mask    (o_byte_mask),
    .is_signed_load(o_is_signed_load),
    .o_target_addr(target_addr_sel),
    .o_take_branch(o_take_branch),
    .o_is_jal     (is_jal),
    .alu_control  (o_alu_control)
  );
  
  // Mux para selección de registro destino (rd vs $31 para JAL/JALR)
  mux #(
    .CHANNELS(2),
    .BUS_SIZE(5)
  ) rd_select_mux (
    .selector(is_jal),
    .data_in({5'b11111, rd}),  // {$31, rd}
    .data_out(o_rd)
  );

  // Calcular branch target: PC+4 + (imm<<2)
  adder #(
    .WIDTH(32)
  ) branch_adder (
    .a(i_next_pc),
    .b(shifted_imm),
    .sum(branch_target)
  );
  
  // Mux para selección de dirección de destino del salto
  mux #(
    .CHANNELS(3),
    .BUS_SIZE(32)
  ) branch_target_mux (
    .selector(target_addr_sel),
    .data_in({jr_target, jump_target, branch_target}),
    .data_out(o_branch_target_addr)
  );
      
endmodule
