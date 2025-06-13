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
  input  wire [5:0]  i_function,          // Campo function
  input  wire [4:0]  i_rt,                // Registro RT
  input  wire [4:0]  i_rd,                // Registro RD
  input  wire [4:0]  i_rs,                // Registro RS (para forwarding)
  input  wire [31:0] i_shamt,             // Campo shamt ya extendido a 32 bits
  input  wire [5:0]  i_opcode,            // Código de operación
  input  wire [31:0] i_next_pc,           // PC+4 para JAL/JALR
  
  // Entradas para forwarding
  input  wire [31:0] i_forwarded_value_a, // Valor forwardeado para RS
  input  wire [31:0] i_forwarded_value_b, // Valor forwardeado para RT
  input  wire        i_use_forwarded_a,   // Control de forwarding para RS
  input  wire        i_use_forwarded_b,   // Control de forwarding para RT

  // Señales de control
  input  wire        i_alu_src_b,           // Selección entre rt o inmediato
  input  wire [1:0]  i_alu_src_a,           // Selección entre rs o PC+4 o shamt
  input  wire        i_reg_dst,           // Selección registro destino
  input  wire        i_reg_write,         // Escritura en registros
  input  wire        i_mem_read,          // Lectura de memoria
  input  wire        i_mem_write,         // Escritura en memoria
  input  wire        i_mem_to_reg,        // Selección entre ALU o memoria
  
  // Salidas hacia la etapa MEM
  output wire [31:0] o_alu_result,        // Resultado de la ALU
  output wire [31:0] o_read_data_2,       // Valor rt para store
  output wire [4:0]  o_write_register,    // Registro destino
  output wire        o_reg_write,         // Control de escritura
  output wire        o_mem_read,          // Control de lectura
  output wire        o_mem_write,         // Control de escritura
  output wire        o_mem_to_reg         // Selección para WB
);

  //----------------------------------------------------------------------
  // 1. LÓGICA DE FORWARDING Y VALORES DE OPERANDOS
  //----------------------------------------------------------------------
  
  wire [31:0] updated_rs = i_use_forwarded_a ? i_forwarded_value_a : i_read_data_1;
  wire [31:0] updated_rt = i_use_forwarded_b ? i_forwarded_value_b : i_read_data_2;

  reg [31:0] alu_input_a;
  always @(*) begin
    case(i_alu_src_a)
      `CTRL_ALU_SRC_A_REG:   alu_input_a = updated_rs;
      `CTRL_ALU_SRC_A_PC:    alu_input_a = i_next_pc;
      `CTRL_ALU_SRC_A_SHAMT: alu_input_a = i_shamt;
      default:               alu_input_a = updated_rs;  
    endcase
  end

  reg [31:0] alu_input_b;
  always @(*) begin
    case(i_alu_src_b)
      `CTRL_ALU_SRC_B_REG: alu_input_b = updated_rt;
      `CTRL_ALU_SRC_B_IMM: alu_input_b = i_sign_extended_imm;
      default:             alu_input_b = 32'b0;
    endcase
  end

  //----------------------------------------------------------------------
  // 2. CONTROL DE LA ALU Y EJECUCIÓN
  //----------------------------------------------------------------------
  // Señal de control para la ALU
  wire [3:0] alu_control;

  // Controlador de la ALU
  alu_control alu_control_inst (
    .i_func_code   (i_function),
    .i_opcode    (i_opcode),
    .alu_control (alu_control)
  );
  
  // Unidad ALU
  alu alu_inst (
    .a           (alu_input_a),
    .b           (alu_input_b),
    .alu_control (alu_control),
    .result      (o_alu_result)
  );
  
  //----------------------------------------------------------------------
  // 3. SELECCIÓN DE REGISTRO Y SEÑALES DE CONTROL
  //----------------------------------------------------------------------
  // Selección del registro destino
  assign o_write_register = i_reg_dst ? i_rd : i_rt;
  
  // Valor rt para instrucciones store
  assign o_read_data_2 = updated_rt;
  
  // Paso de señales de control a la siguiente etapa
  assign o_reg_write = i_reg_write;
  assign o_mem_read = i_mem_read;
  assign o_mem_write = i_mem_write;
  assign o_mem_to_reg = i_mem_to_reg;

endmodule
