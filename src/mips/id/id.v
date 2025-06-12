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
  
  // Entradas simplificadas para forwarding
  input  wire [31:0] i_forwarded_value_a,   // Valor ya seleccionado para RS (desde EX/MEM/WB)
  input  wire [31:0] i_forwarded_value_b,   // Valor ya seleccionado para RT (desde EX/MEM/WB)
  input  wire        i_use_forwarded_a,     // Control de forwarding para RS (0:registro, 1:forwarded)
  input  wire        i_use_forwarded_b,     // Control de forwarding para RT (0:registro, 1:forwarded)
  
  // Salidas hacia la etapa EX
  output wire [31:0] o_read_data_1,        // Valor del registro rs
  output wire [31:0] o_read_data_2,        // Valor del registro rt
  output wire [31:0] o_sign_extended_imm,  // Inmediato con extensión de signo
  output wire [4:0]  o_rs,                 // Campo rs de la instrucción (para forwarding)
  output wire [4:0]  o_rt,                 // Campo rt de la instrucción
  output wire [4:0]  o_rd,                 // Campo rd de la instrucción
  output wire [4:0]  o_shamt,              // Campo shamt de la instrucción para SLL, SRL
  output wire [5:0]  o_function,           // Campo function de la instrucción
  output wire [5:0]  o_opcode,             // Código de operación de la instrucción
  
  // Señales de control para EX
  output wire        o_alu_src,            // Selección del segundo operando de la ALU
  output wire [2:0]  o_alu_op,             // Operación de la ALU
  output wire        o_reg_dst,            // Selección del registro destino
  output wire        o_reg_write,          // Habilitación de escritura en banco de registros
  output wire        o_mem_read,           // Control de lectura de memoria
  output wire        o_mem_write,          // Control de escritura en memoria
  output wire        o_mem_to_reg,         // Selección entre ALU o memoria para WB
  output wire        o_is_jal,             // Indica si es un JAL (Jump And Link)
  
  // Salidas para control de saltos en ID (simplificadas)
  output wire [31:0] o_branch_target_addr,  // Dirección de destino del salto
  output wire        o_take_branch          // Señal unificada: saltar (1) o no (0)
);

  // Extraer los campos de la instrucción
  wire [5:0] opcode = i_instruction[31:26];
  wire [4:0] rs     = i_instruction[25:21];
  wire [4:0] rt     = i_instruction[20:16];
  wire [4:0] rd     = i_instruction[15:11];
  wire [4:0] shamt  = i_instruction[10:6];  // Campo shamt para instrucciones de desplazamiento
  wire [15:0] immediate = i_instruction[15:0];
  wire [25:0] target = i_instruction[25:0]; // Campo target para instrucciones J y JAL
  wire [5:0]  funct  = i_instruction[5:0];  // Campo function para instrucciones tipo R
  
  // Extension de signo para el immediate - ya no necesitamos casos especiales
  // porque la ALU hará un bypass directo del operando A
  assign o_sign_extended_imm = {{16{immediate[15]}}, immediate};

  // Para instrucciones J/JAL, también necesitamos el target completo
  wire [31:0] jump_target = {i_next_pc[31:28], target, 2'b00};
  
  // Valores originales leídos del banco de registros
  wire [31:0] reg_data_1;
  wire [31:0] reg_data_2;
  
  // Valores finales después del forwarding (declarados como reg para usar en bloques always)
  reg [31:0] forwarded_data_1;
  reg [31:0] forwarded_data_2;
  
  // Instanciar el banco de registros
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
  
  // Multiplexores simplificados para los valores forwardeados
  // Implementación del forwarding para el operando A (RS)
  always @(*) begin
    if (i_use_forwarded_a)
      forwarded_data_1 = i_forwarded_value_a;  // Usar valor forwardeado
    else
      forwarded_data_1 = reg_data_1;          // Usar valor del registro
  end
  
  // Implementación del forwarding para el operando B (RT)
  always @(*) begin
    if (i_use_forwarded_b)
      forwarded_data_2 = i_forwarded_value_b;  // Usar valor forwardeado
    else
      forwarded_data_2 = reg_data_2;          // Usar valor del registro
  end
  
  // Para todas las instrucciones, simplemente pasamos los valores forwardeados
  // Para JAL/JALR, pasaremos siempre i_next_pc y la ALU se encargará de hacer bypass
  assign o_read_data_1 = (branch_type == `BRANCH_TYPE_JAL || branch_type == `BRANCH_TYPE_JALR) ? i_next_pc : forwarded_data_1;
  assign o_read_data_2 = forwarded_data_2;
  
  // Calcular la dirección destino del salto: PC+4 + (immediate << 2)
  wire [31:0] shifted_imm = {{16{immediate[15]}}, immediate} << 2;
  wire [31:0] branch_target = i_next_pc + shifted_imm;
  
  // Para instrucciones JR/JALR, el destino es el valor del registro rs
  // Necesitamos usar el valor original/forwardeado de RS, no PC+4
  wire [31:0] jr_target = forwarded_data_1;
  
  // Lógica para determinar si el salto se toma y la dirección de salto
  wire is_equal = (forwarded_data_1 == forwarded_data_2);
  
  // La lógica de salto se basa directamente en branch_type
  assign o_take_branch = 
      // Para saltos condicionales (BEQ/BNE)
      ((branch_type == `BRANCH_TYPE_BEQ) && is_equal) ||               // BEQ y son iguales
      ((branch_type == `BRANCH_TYPE_BNE) && !is_equal) ||              // BNE y son diferentes
      (branch_type >= `BRANCH_TYPE_J);                                 // Cualquier tipo de jump
      
  // Multiplexor directo usando branch_type
  assign o_branch_target_addr = 
      (branch_type == `BRANCH_TYPE_BEQ || branch_type == `BRANCH_TYPE_BNE) ? branch_target :   // BEQ o BNE
      (branch_type == `BRANCH_TYPE_J || branch_type == `BRANCH_TYPE_JAL) ? jump_target :      // J o JAL
      (branch_type == `BRANCH_TYPE_JR || branch_type == `BRANCH_TYPE_JALR) ? jr_target :      // JR o JALR
      i_next_pc; // Por defecto PC+4 
      
  assign o_is_jal = ((branch_type == `BRANCH_TYPE_JAL) || (branch_type == `BRANCH_TYPE_JALR));                                                                                                                                    // Por defecto PC+4
  
  // Pasar campos rs, rt, rd, shamt y function a la siguiente etapa
  assign o_rs = rs; 
  assign o_rt = rt;
  assign o_rd = (branch_type == `BRANCH_TYPE_JAL) ? 5'b11111 : rd;  // Si es JAL, rd = $31 (ra)
  assign o_shamt = shamt;         
  assign o_function = funct;
  assign o_opcode = opcode;     

  // Señal interna para el tipo de salto
  wire [2:0] branch_type;
  
  // Instanciar la unidad de control
  control control_inst (
    .opcode       (opcode),
    .funct        (funct), 
    .reg_dst      (o_reg_dst),
    .reg_write    (o_reg_write),
    .alu_src      (o_alu_src),
    .alu_op       (o_alu_op),
    .mem_read     (o_mem_read), 
    .mem_write    (o_mem_write),
    .mem_to_reg   (o_mem_to_reg),
    .o_branch_type(branch_type) 
  );

endmodule


