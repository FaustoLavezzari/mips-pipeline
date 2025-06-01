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
  input  wire [4:0]  i_rs,              // Registro RS (para forwarding)
  input  wire [5:0]  i_opcode,          // Código de operación para distinguir entre BEQ y BNE
  input  wire [31:0] i_next_pc,         // PC+4 para instrucciones JAL/JALR
  
  // Señales para forwarding (anticipación de datos)
  input  wire [4:0]  i_mem_write_register, // Registro destino en etapa MEM
  input  wire        i_mem_reg_write,      // Señal RegWrite en etapa MEM
  input  wire [31:0] i_mem_alu_result,     // Resultado ALU en etapa MEM
  input  wire [4:0]  i_wb_write_register,  // Registro destino en etapa WB
  input  wire        i_wb_reg_write,       // Señal RegWrite en etapa WB
  input  wire [31:0] i_wb_write_data,      // Dato a escribir en etapa WB
  
  // Señales de control para la etapa EX
  input  wire        i_alu_src,         // Selecciona entre registro rt (0) o inmediato (1)
  input  wire [1:0]  i_alu_op,          // Operación a realizar en la ALU
  input  wire        i_reg_dst,         // Selecciona registro destino: rt (0) o rd (1)
  input  wire        i_reg_write,       // Señal de escritura en registros
  input  wire        i_mem_read,        // Control de lectura de memoria
  input  wire        i_mem_write,       // Control de escritura en memoria
  input  wire        i_mem_to_reg,      // Selecciona entre ALU o memoria para WB
  input  wire        i_branch,          // Indica si es instrucción de salto
  
  // Señales de branch prediction
  input  wire        i_branch_prediction, // Predicción de salto (0 = not taken)
  input  wire [31:0] i_branch_target_addr, // Dirección destino del salto
  
  // Salidas hacia la etapa MEM
  output wire [31:0] o_alu_result,      // Resultado de la ALU
  output wire [31:0] o_read_data_2,     // Valor del registro rt (para SW)
  output wire [4:0]  o_write_register,  // Registro destino para WB
  output wire        o_reg_write,       // Señal de escritura en registros
  output wire        o_mem_read,        // Control de lectura de memoria
  output wire        o_mem_write,       // Control de escritura en memoria
  output wire        o_mem_to_reg,      // Selecciona entre ALU o memoria para WB
  output wire        o_branch,          // Indica si es instrucción de salto
  
  // Salidas para corrección de predicciones
  output wire        o_branch_taken,     // Indica si el salto se toma realmente
  output wire        o_mispredicted,     // Indica si hubo un error en la predicción
  
  // Salidas para instrucciones JAL/JALR
  output wire [31:0] o_pc_plus_4,       // PC+4 para JAL/JALR
  output wire        o_is_jal           // Indica si es una instrucción JAL/JALR
);

  // Datos intermedios
  wire [31:0] alu_input_2;    // Segundo operando de la ALU
  wire [3:0]  alu_control;    // Señal de control para la ALU
  wire [4:0]  write_reg_rt_rd; // Registro destino (entre rt y rd)
  
  // Señales para la unidad de forwarding
  wire [1:0] forward_a;  // Control para operando A (RS)
  wire [1:0] forward_b;  // Control para operando B (RT)
  
  // Valores forwarded para los operandos
  reg [31:0] forwarded_a;  // Valor efectivo para el operando A
  reg [31:0] forwarded_b;  // Valor efectivo para el operando B
  
  // Instancia de la unidad de forwarding
  forwarding_unit forwarding_inst (
    .i_ex_rs        (i_rs),                 // RS en EX
    .i_ex_rt        (i_rt),                 // RT en EX
    .i_mem_rd       (i_mem_write_register), // Registro destino en MEM
    .i_mem_reg_write(i_mem_reg_write),      // RegWrite en MEM
    .i_wb_rd        (i_wb_write_register),  // Registro destino en WB
    .i_wb_reg_write (i_wb_reg_write),       // RegWrite en WB
    .o_forward_a    (forward_a),            // Control para operando A
    .o_forward_b    (forward_b)             // Control para operando B
  );
  
  // Lógica de multiplexor para el operando A (RS)
  always @(*) begin
    case (forward_a)
      2'b00: forwarded_a = i_read_data_1;        // No forwarding
      2'b01: forwarded_a = i_mem_alu_result;     // Desde MEM
      2'b10: forwarded_a = i_wb_write_data;      // Desde WB
      default: forwarded_a = i_read_data_1;      // Default: no forwarding
    endcase
  end
  
  // Lógica de multiplexor para el operando B (RT)
  always @(*) begin
    case (forward_b)
      2'b00: forwarded_b = i_read_data_2;        // No forwarding
      2'b01: forwarded_b = i_mem_alu_result;     // Desde MEM
      2'b10: forwarded_b = i_wb_write_data;      // Desde WB
      default: forwarded_b = i_read_data_2;      // Default: no forwarding
    endcase
    
  end
  
  // Instancia del controlador de la ALU
  alu_control alu_control_inst (
    .func_code   (i_function),
    .alu_op      (i_alu_op),
    .alu_control (alu_control)
  );

  // Multiplexor final para el segundo operando de la ALU
  // Selecciona entre el RT forwardeado y el inmediato extendido
  assign alu_input_2 = (i_alu_src) ? i_sign_extended_imm : forwarded_b;

  // Instancia de la ALU - usar forwarded_a como operando A
  alu alu_inst (
    .a           (forwarded_a),            // Operando A con forwarding
    .b           (alu_input_2),            // Operando B (ya sea RT forwardeado o inmediato)
    .alu_control (alu_control),
    .result      (o_alu_result)
  );
  
  // MUX para seleccionar entre rt y rd como registro destino
  assign o_write_register = (i_reg_dst) ? i_rd : i_rt;
  
  // Usar el valor RT forwardeado para instrucciones store
  assign o_read_data_2 = forwarded_b;

  // Pasar las señales de control
  assign o_reg_write = i_reg_write;
  assign o_mem_read = i_mem_read;
  assign o_mem_write = i_mem_write; // Importante para instrucciones SW
  assign o_mem_to_reg = i_mem_to_reg;
  assign o_branch = i_branch;
  
  // Debug: mostrar estado de señales para instrucciones SW
  always @(*) begin
    if (i_mem_write) begin
      $display("EX: SW detectado - MemWrite=1, Dato=%d, Addr=%d", forwarded_b, o_alu_result);
    end
  end

  // Lógica para determinar si el salto se toma realmente 
  // BEQ: si los valores son iguales
  // BNE: si los valores son diferentes
  // Usamos los valores forwardeados para una comparación precisa
  wire is_equal = (forwarded_a == forwarded_b);
  // Identificar si la instrucción es BEQ o BNE según el opcode
  wire is_beq = (i_opcode == `OPCODE_BEQ);
  wire is_bne = (i_opcode == `OPCODE_BNE);
  
  // Salto tomado si:
  // - Es BEQ y los valores son iguales, o
  // - Es BNE y los valores son diferentes
  assign o_branch_taken = i_branch && ((is_beq && is_equal) || (is_bne && !is_equal));
  
  // Error de predicción si la predicción no coincide con el resultado real
  assign o_mispredicted = i_branch && (o_branch_taken != i_branch_prediction);
  
  // Detectar instrucciones JAL y JALR
  wire is_jal = (i_opcode == `OPCODE_JAL);
  wire is_jalr = (i_opcode == `OPCODE_R_TYPE && i_function == `FUNC_JALR);
  
  // Señal para instrucciones JAL/JALR
  assign o_is_jal = is_jal || is_jalr;
  
  // Propagar PC+4 para instrucciones JAL/JALR
  assign o_pc_plus_4 = i_next_pc;

endmodule
