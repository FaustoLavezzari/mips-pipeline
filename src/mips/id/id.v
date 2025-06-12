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
  output wire [31:0]  o_shamt,            // Campo shamt
  output wire [5:0]  o_function,          // Campo function
  output wire [5:0]  o_opcode,            // Opcode
  
  // Señales de control para EX
  output wire        o_alu_src_b,         // Selección del segundo operando ALU
  output wire [2:0]  o_alu_op,            // Operación ALU
  output wire        o_reg_dst,           // Selección del registro destino
  output wire        o_reg_write,         // Habilitación escritura en banco de registros
  output wire        o_mem_read,          // Control de lectura de memoria
  output wire        o_mem_write,         // Control de escritura en memoria
  output wire        o_mem_to_reg,        // Selección entre ALU o memoria para WB
  output wire        o_is_jal,            // Indica si es JAL/JALR
  
  // Salidas para control de saltos
  output wire [31:0] o_branch_target_addr, // Dirección de destino del salto
  output wire        o_take_branch         // Señal de control de salto
);

  //----------------------------------------------------------------------
  // 1. EXTRACCIÓN DE CAMPOS DE LA INSTRUCCIÓN
  //----------------------------------------------------------------------
  wire [5:0] opcode = i_instruction[31:26];
  wire [4:0] rs     = i_instruction[25:21];
  wire [4:0] rt     = i_instruction[20:16];
  wire [4:0] rd     = i_instruction[15:11];
  wire [4:0] shamt  = i_instruction[10:6];
  wire [15:0] immediate = i_instruction[15:0];
  wire [25:0] target = i_instruction[25:0];
  wire [5:0]  funct  = i_instruction[5:0];

  //----------------------------------------------------------------------
  // 2. BANCO DE REGISTROS Y FORWARDING
  //----------------------------------------------------------------------
  // Valores leídos del banco de registros
  wire [31:0] reg_data_1;
  wire [31:0] reg_data_2;
  
  // Valores después del forwarding
  reg [31:0] forwarded_data_1;
  reg [31:0] forwarded_data_2;

  // Instancia del banco de registros
  registers_bank reg_bank(
    .i_clk            (clk),
    .i_reset          (reset),
    .i_write_enable   (i_reg_write),
    .i_read_register_1(rs),
    .i_read_register_2(rt),
    .i_write_register (i_write_register),
    .i_write_data     (i_write_data),
    .o_read_data_1    (reg_data_1),
    .o_read_data_2    (reg_data_2)
  );
  
  // Lógica de forwarding para operando A (RS), incluye caso especial JAL/JALR
  always @(*) begin
    if (branch_type == `BRANCH_TYPE_JAL || branch_type == `BRANCH_TYPE_JALR)
      forwarded_data_1 = i_next_pc;  // Para JAL/JALR, pasamos PC+4 directamente
    else
      forwarded_data_1 = i_use_forwarded_a ? i_forwarded_value_a : reg_data_1;
  end
  
  // Lógica de forwarding para operando B (RT)
  always @(*) begin
    forwarded_data_2 = i_use_forwarded_b ? i_forwarded_value_b : reg_data_2;
  end

  // Datos de los registros con forwarding aplicado
  assign o_read_data_1 = forwarded_data_1; 
  assign o_read_data_2 = forwarded_data_2;

  //----------------------------------------------------------------------
  // 3. UNIDAD DE CONTROL Y SEÑALES DERIVADAS
  //----------------------------------------------------------------------
  wire [2:0] branch_type;
  
  // Instancia de la unidad de control
  control control_inst (
    .opcode       (opcode),
    .funct        (funct), 
    .reg_dst      (o_reg_dst),
    .reg_write    (o_reg_write),
    .alu_src_b    (o_alu_src_b),
    .alu_op       (o_alu_op),
    .mem_read     (o_mem_read), 
    .mem_write    (o_mem_write),
    .mem_to_reg   (o_mem_to_reg),
    .o_branch_type(branch_type) 
  );

  // Extensión de signo del inmediato
  assign o_sign_extended_imm = {{16{immediate[15]}}, immediate};

  // Valores de salida para la etapa EX
  assign o_rs = rs;
  assign o_rt = rt;
  assign o_rd = (branch_type == `BRANCH_TYPE_JAL) ? 5'b11111 : rd;  // JAL: rd = $31
  assign o_shamt = {27'b0, shamt};
  assign o_function = funct;
  assign o_opcode = opcode;

  //----------------------------------------------------------------------
  // 4. LÓGICA DE CONTROL DE SALTOS
  //----------------------------------------------------------------------
  // Cálculo de direcciones de salto
  wire [31:0] shifted_imm = o_sign_extended_imm << 2; // Desplazamiento para branch
  wire [31:0] branch_target = i_next_pc + shifted_imm; // PC+4 + (imm<<2) para BEQ/BNE
  wire [31:0] jump_target = {i_next_pc[31:28], target, 2'b00}; // Jump target para J/JAL
  wire [31:0] jr_target = forwarded_data_1; // Target para JR/JALR (contenido de rs)
  
  // Condición de igualdad para BEQ/BNE
  wire is_equal = (forwarded_data_1 == forwarded_data_2);
  
  // Lógica de selección de salto
  assign o_take_branch = 
      ((branch_type == `BRANCH_TYPE_BEQ) && is_equal) ||         // BEQ y rs=rt
      ((branch_type == `BRANCH_TYPE_BNE) && !is_equal) ||        // BNE y rs≠rt
      (branch_type >= `BRANCH_TYPE_J);                           // Cualquier jump
  
  // Selección de dirección de destino
  assign o_branch_target_addr = 
      (branch_type == `BRANCH_TYPE_BEQ || branch_type == `BRANCH_TYPE_BNE) ? branch_target :
      (branch_type == `BRANCH_TYPE_J || branch_type == `BRANCH_TYPE_JAL) ? jump_target :
      (branch_type == `BRANCH_TYPE_JR || branch_type == `BRANCH_TYPE_JALR) ? jr_target :
      i_next_pc;
      
  // Indicador para JAL/JALR (para guardar PC+4 en reg destino)
  assign o_is_jal = (branch_type == `BRANCH_TYPE_JAL || branch_type == `BRANCH_TYPE_JALR);

endmodule
