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
  
  // Entradas para forwarding desde EX
  input  wire [4:0]  i_ex_write_register,  // Registro destino en EX
  input  wire        i_ex_reg_write,       // Señal de escritura en registro en EX
  input  wire [31:0] i_ex_alu_result,      // Resultado de la ALU en EX
  
  // Entradas para forwarding desde MEM
  input  wire [4:0]  i_mem_write_register, // Registro destino en MEM
  input  wire        i_mem_reg_write,      // Señal de escritura en registro en MEM
  input  wire [31:0] i_mem_alu_result,     // Resultado de la ALU en MEM
  
  // Señales de control de forwarding (recibidas desde afuera)
  input  wire [1:0]  i_forward_a,          // Control de forwarding para RS
  input  wire [1:0]  i_forward_b,          // Control de forwarding para RT
  
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
  output wire        o_branch,             // Indica si es una instrucción de salto
  output wire        o_is_jal,             // Indica si es un JAL (Jump And Link)
  
  // Nuevas salidas para control de saltos en ID
  output wire        o_branch_prediction,   // Indica si se predice un salto (1) o no (0)
  output wire [31:0] o_branch_target_addr,  // Dirección de destino del salto 
  output wire        o_branch_taken,        // Indica si el salto se toma realmente
  output wire        o_jump_taken           // Indica si es un salto incondicional (J/JAL/JR/JALR)
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
  
  // Detectar tipos de instrucciones de salto
  wire is_beq = (opcode == `OPCODE_BEQ);
  wire is_bne = (opcode == `OPCODE_BNE);
  wire is_j   = (opcode == `OPCODE_J);
  wire is_jal = (opcode == `OPCODE_JAL);
  wire is_jr  = (opcode == `OPCODE_R_TYPE && funct == `FUNC_JR);
  wire is_jalr = (opcode == `OPCODE_R_TYPE && funct == `FUNC_JALR);
  
  // Extension de signo para el immediate, o 0 para JAL/JALR para que no afecte al PC+4
  assign o_sign_extended_imm = (is_jal || is_jalr) ? 32'b0 : {{16{immediate[15]}}, immediate};
  
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
  
  // Usar las señales de forwarding recibidas desde el exterior
  wire [1:0] forward_a = i_forward_a;
  wire [1:0] forward_b = i_forward_b;
  
  // Multiplexores para seleccionar los valores forwardeados
  // Implementación del forwarding para el operando A (RS)
  always @(*) begin
    case (forward_a)
      2'b01: forwarded_data_1 = i_ex_alu_result;  // Desde EX
      2'b10: forwarded_data_1 = i_mem_alu_result; // Desde MEM
      2'b11: forwarded_data_1 = i_write_data;     // Desde WB
      default: forwarded_data_1 = reg_data_1;     // Valor original
    endcase
  end
  
  // Implementación del forwarding para el operando B (RT)
  always @(*) begin
    case (forward_b)
      2'b01: forwarded_data_2 = i_ex_alu_result;  // Desde EX
      2'b10: forwarded_data_2 = i_mem_alu_result; // Desde MEM
      2'b11: forwarded_data_2 = i_write_data;     // Desde WB
      default: forwarded_data_2 = reg_data_2;     // Valor original
    endcase
  end
  
  // IMPORTANTE: JALR necesita dos valores distintos:
  // 1. PC+4 para guardar como dirección de retorno (esto va por o_read_data_1 hacia la ALU)
  // 2. El valor de RS para usarlo como destino de salto (esto va por jr_target)
  
  // Si es JAL o JALR, enviamos PC+4 a la ALU para guardarlo como dirección de retorno
  // De lo contrario, enviamos el valor del registro RS normalmente 
  assign o_read_data_1 = (is_jal || is_jalr) ? i_next_pc : forwarded_data_1;
  assign o_read_data_2 = forwarded_data_2;
  
  // Calcular la dirección destino del salto: PC+4 + (immediate << 2)
  wire [31:0] shifted_imm = {{16{immediate[15]}}, immediate} << 2; // Usar immediate original, no el que podría ser 0 para JAL/JALR
  wire [31:0] branch_target = i_next_pc + shifted_imm;
  
  // Para instrucciones JR/JALR, el destino es el valor del registro rs
  // Necesitamos usar el valor original/forwardeado de RS, no PC+4
  wire [31:0] jr_target = forwarded_data_1;
  
  // Lógica para determinar si el salto se toma
  wire is_equal = (forwarded_data_1 == forwarded_data_2);
  assign o_branch_taken = o_branch && ((is_beq && is_equal) || (is_bne && !is_equal));
  
  // Detectar saltos incondicionales
  assign o_jump_taken = is_j || is_jal || is_jr || is_jalr;
  
  // Determinar la dirección de destino basada en el tipo de salto
  assign o_branch_target_addr = (is_j || is_jal) ? jump_target :
                                (is_jr || is_jalr) ? jr_target :
                                branch_target;
  

  // Pasar campos rs, rt, rd, shamt y function a la siguiente etapa
  assign o_rs = rs; 
  assign o_rt = rt;
  assign o_rd = is_jal ? 5'b11111 : rd;
  assign o_shamt = shamt;         
  assign o_function = funct;
  assign o_opcode = opcode;     

  // Instanciar la unidad de control
  control control_inst (
    .opcode     (opcode),
    .funct      (funct),            // Pasamos el campo funct para JR/JALR
    .reg_dst    (o_reg_dst),
    .reg_write  (o_reg_write),
    .alu_src    (o_alu_src),
    .alu_op     (o_alu_op),
    .mem_read   (o_mem_read), 
    .mem_write  (o_mem_write),
    .mem_to_reg (o_mem_to_reg),
    .branch     (o_branch),
    .branch_prediction (o_branch_prediction),
    .o_is_jal   (o_is_jal)          // Recibimos la señal de JAL/JALR
  );

endmodule


