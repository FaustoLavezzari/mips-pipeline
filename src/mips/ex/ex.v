`timescale 1ns / 1ps
`include "../mips_pkg.vh"
 
module ex_stage(
  input  wire        clk,
  input  wire        reset,
  
  // Datos de la etapa ID/EX
  input  wire [31:0] i_read_data_1,       // Valor del registro rs
  input  wire [31:0] i_read_data_2,       // Valor del registro rt
  input  wire [31:0] i_sign_extended_imm, // Immediate con extensión de signo
  input  wire [5:0]  i_function,          // Campo function de la instrucción
  input  wire [4:0]  i_rt,                // Registro RT
  input  wire [4:0]  i_rd,                // Registro RD
  input  wire [4:0]  i_rs,                // Registro RS (para forwarding)
  input  wire [31:0]  i_shamt,            // Campo shamt para instrucciones SLL/SRL
  input  wire [5:0]  i_opcode,            // Código de operación
  input  wire [31:0] i_next_pc,           // PC+4 para instrucciones JAL/JALR
  
  // Señales para forwarding (anticipación de datos)
  input  wire [31:0] i_forwarded_value_a,   // Valor ya seleccionado para RS
  input  wire [31:0] i_forwarded_value_b,   // Valor ya seleccionado para RT
  input  wire        i_use_forwarded_a,     // Control de forwarding para RS (0:registro, 1:forwarded)
  input  wire        i_use_forwarded_b,     // Control de forwarding para RT (0:registro, 1:forwarded)

  // Señales de control para la etapa EX
  input  wire        i_alu_src,         // Selecciona entre registro rt (0) o inmediato (1)
  input  wire [2:0]  i_alu_op,          // Operación a realizar en la ALU
  input  wire        i_reg_dst,         // Selecciona registro destino: rt (0) o rd (1)
  input  wire        i_reg_write,       // Señal de escritura en registros
  input  wire        i_mem_read,        // Control de lectura de memoria
  input  wire        i_mem_write,       // Control de escritura en memoria
  input  wire        i_mem_to_reg,      // Selecciona entre ALU o memoria para WB
  input  wire        i_is_jal,          // Indica si es JAL (recibido desde ID)
  
  // Salidas hacia la etapa MEM
  output wire [31:0] o_alu_result,      // Resultado de la ALU
  output wire [31:0] o_read_data_2,     // Valor del registro rt (para SW)
  output wire [4:0]  o_write_register,  // Registro destino para WB
  output wire        o_reg_write,       // Señal de escritura en registros
  output wire        o_mem_read,        // Control de lectura de memoria
  output wire        o_mem_write,       // Control de escritura en memoria
  output wire        o_mem_to_reg       // Selecciona entre ALU o memoria para WB
);

  // Datos intermedios
  wire [31:0] alu_input_2;    // Segundo operando de la ALU
  wire [3:0]  alu_control;    // Señal de control para la ALU
  wire [4:0]  write_reg_rt_rd; // Registro destino (entre rt y rd)
  
  // Valores forwarded para los operandos
  reg [31:0] forwarded_a;  // Valor efectivo para el operando A
  reg [31:0] forwarded_b;  // Valor efectivo para el operando B
    
  // Lógica de multiplexor para el operando A (RS)
  always @(*) begin
    if (i_is_jal) begin
      // Si es JAL o JALR, mantenemos el valor de PC+4 intacto, evitando el forwarding
      forwarded_a = i_read_data_1;  // Contiene PC+4 
    end else begin
      // Forwarding simplificado para RS
      if (i_use_forwarded_a)
        forwarded_a = i_forwarded_value_a;  // Usar valor forwardeado
      else
        forwarded_a = i_read_data_1;        // Usar valor original
    end
  end
  
  // Lógica de multiplexor para el operando B (RT)
  always @(*) begin
    if (i_use_forwarded_b)
      forwarded_b = i_forwarded_value_b;  // Usar valor forwardeado
    else
      forwarded_b = i_read_data_2;        // Usar valor original
  end
  
  // Instancia del controlador de la ALU
  alu_control alu_control_inst (
    .func_code   (i_function),
    .i_opcode    (i_opcode),     // Pasar el opcode para instrucciones I-type
    .alu_op      (i_alu_op),
    .alu_control (alu_control)
  );

  // Multiplexor final para el segundo operando de la ALU
  // Selecciona entre el RT forwardeado y el inmediato extendido
  assign alu_input_2 = (i_alu_src) ? i_sign_extended_imm : forwarded_b;
  
  // Determinar si es una instrucción de desplazamiento estático (SLL, SRL, SRA)
  // donde se usa el campo shamt de la instrucción
  wire is_static_shift_op = (i_opcode == `OPCODE_R_TYPE) && 
                           (i_function == `FUNC_SLL || 
                            i_function == `FUNC_SRL || 
                            i_function == `FUNC_SRA);
  
  // Determinar si es una instrucción de desplazamiento variable (SLLV, SRLV, SRAV)
  // donde se usa el valor del registro RS como cantidad de desplazamiento
  wire is_var_shift_op = (i_opcode == `OPCODE_R_TYPE) &&
                         (i_function == `FUNC_SLLV ||
                          i_function == `FUNC_SRLV ||
                          i_function == `FUNC_SRAV);
  
  // Flag general para identificar si es cualquier tipo de desplazamiento
  wire is_shift_op = is_static_shift_op || is_var_shift_op;
                                       
  // Para instrucciones de desplazamiento estático, usamos el campo shamt directamente
  // Convertimos el campo shamt (5 bits) a 32 bits con zero extension
  wire [31:0] shift_amount = {27'b0, i_shamt};
  
  // El valor real para la cantidad de desplazamiento:
  // - Para desplazamientos estáticos (SLL, SRL, SRA): usar el valor de shamt
  // - Para desplazamientos variables (SLLV, SRLV, SRAV): usar forwarded_a (valor de RS)
  wire [31:0] shift_value = is_static_shift_op ? shift_amount : {27'b0, forwarded_a[4:0]};
  
  alu alu_inst (
    .a           (is_shift_op ? shift_value : forwarded_a),  // shamt/rs[4:0] para desplazamiento
    .b           (is_shift_op ? forwarded_b : alu_input_2),  // rt para desplazamientos, rt/imm para otros
    .alu_control (alu_control),
    .result      (o_alu_result)
  );
  
  // MUX para seleccionar entre rt y rd como registro destino
  // La etapa ID es responsable de configurar el registro destino apropiado
  assign o_write_register = (i_reg_dst) ? i_rd : i_rt;
  
  // Usar el valor RT forwardeado para instrucciones store
  assign o_read_data_2 = forwarded_b;

  // Pasar las señales de control
  assign o_reg_write = i_reg_write;
  assign o_mem_read = i_mem_read;
  assign o_mem_write = i_mem_write;
  assign o_mem_to_reg = i_mem_to_reg;

endmodule
