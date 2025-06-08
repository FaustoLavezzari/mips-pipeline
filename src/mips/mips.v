`timescale 1ns / 1ps
`include "mips_pkg.vh"

//============================================================================
// PROCESADOR MIPS PIPELINE DE 5 ETAPAS
//
// Implementa un procesador MIPS de 5 etapas:
// 1. Instruction Fetch (IF)
// 2. Instruction Decode (ID)
// 3. Execution (EX)
// 4. Memory Access (MEM)
// 5. Write Back (WB)
//
// Con soporte para:
//  - Detección y resolución de riesgos de datos (forwarding)
//  - Detección y resolución de riesgos de control (predicción de saltos)
//  - Instrucciones aritméticas, lógicas, load/store y control de flujo
//============================================================================

module mips(
  input  wire        clk,        // Señal de reloj
  input  wire        reset,      // Señal de reset
  output wire        halt        // Señal de detención
);

  //===========================================================================
  // SEÑALES DE CONTROL Y DETECCIÓN DE RIESGOS (HAZARDS)
  //===========================================================================
  wire       pipeline_stall;     // Señal para detener el pipeline
  wire       pipeline_flush;     // Señal para limpiar el pipeline
  wire       halt_detected;      // Señal de instrucción HALT detectada
  wire       control_hazard;     // Señal de riesgo de control

  //===========================================================================
  // ETAPA 1: INSTRUCTION FETCH (IF)
  //===========================================================================
  
  // Señales de la etapa IF
  wire [31:0] if_next_pc;        // PC+4 calculado en IF
  wire [31:0] if_instr;          // Instrucción leída de memoria
  
  // Instancia del módulo de la etapa IF
  if_stage if_stage_inst(
    .clk                (clk),
    .reset              (reset),
    // Entradas para predicción de saltos desde ID
    .i_branch_prediction(id_branch_prediction),
    .i_branch_target_addr(id_branch_target_addr),
    // Entradas para corrección de predicciones desde EX
    .i_mispredicted     (ex_mispredicted),
    .i_branch_taken     (ex_branch_taken),
    .i_ex_branch_target (ex_branch_target_addr),
    // Entradas para control del pipeline
    .i_halt             (halt_detected),
    .i_stall            (pipeline_stall),
    // Salidas
    .o_next_pc          (if_next_pc),
    .o_instr            (if_instr)
  );
  
  //===========================================================================
  // LATCH DE PIPELINE IF/ID
  //===========================================================================
  
  // Señales entre IF e ID (Latch IF/ID)
  wire [31:0] id_next_pc;      
  wire [31:0] id_instr;         
  
  // Instancia del latch IF/ID
  if_id if_id_latch(
    .clk         (clk),
    .reset       (reset),
    .flush       (pipeline_flush), 
    .stall       (pipeline_stall),
    // Entradas desde IF
    .next_pc_in  (if_next_pc),
    .instr_in    (if_instr),
    // Salidas hacia ID
    .next_pc_out (id_next_pc),
    .instr_out   (id_instr)
  );

  //===========================================================================
  // ETAPA 2: INSTRUCTION DECODE (ID)
  //===========================================================================
  
  // Señales de datos de la etapa ID
  wire [31:0] id_read_data_1;    // Valor del registro rs
  wire [31:0] id_read_data_2;    // Valor del registro rt
  wire [31:0] id_sign_extended_imm; // Inmediato con extensión de signo
  wire [4:0]  id_rs;             // Número de registro rs
  wire [4:0]  id_rt;             // Número de registro rt
  wire [4:0]  id_rd;             // Número de registro rd
  wire [5:0]  id_function;       // Campo function de la instrucción
  wire [5:0]  id_opcode;         // Código de operación
  
  // Señales de predicción de saltos
  wire        id_branch_prediction; // Predicción de salto (0=not taken)
  wire [31:0] id_branch_target_addr; // Dirección destino del salto
  
  // Señales de control generadas en ID
  wire        id_alu_src;        // Selector de operando ALU (0=reg, 1=imm)
  wire [1:0]  id_alu_op;         // Tipo de operación ALU
  wire        id_reg_dst;        // Selector de registro destino (0=rt, 1=rd)
  wire        id_reg_write;      // Habilitación de escritura en registros
  wire        id_mem_read;       // Habilitación de lectura de memoria
  wire        id_mem_write;      // Habilitación de escritura en memoria
  wire        id_mem_to_reg;     // Selector de dato a escribir (0=ALU, 1=MEM)
  wire        id_branch;         // Indica instrucción de salto
  
  // Instancia del módulo de la etapa ID
  id_stage id_stage_inst(
    .clk                (clk),
    .reset              (reset),
    // Entradas desde IF/ID
    .i_next_pc          (id_next_pc),
    .i_instruction      (id_instr),
    // Entradas desde WB (retroalimentación)
    .i_reg_write        (wb_reg_write_out),      // Señal de escritura desde WB
    .i_write_register   (wb_write_register_out), // Registro destino desde WB
    .i_write_data       (wb_write_data),         // Dato a escribir desde WB
    // Salidas de datos
    .o_read_data_1      (id_read_data_1),
    .o_read_data_2      (id_read_data_2),
    .o_sign_extended_imm(id_sign_extended_imm),
    .o_rs               (id_rs),
    .o_rt               (id_rt),
    .o_rd               (id_rd),
    .o_function         (id_function),
    .o_opcode           (id_opcode),
    // Salidas de señales de control
    .o_alu_src          (id_alu_src),
    .o_alu_op           (id_alu_op),
    .o_reg_dst          (id_reg_dst),
    .o_reg_write        (id_reg_write),
    .o_mem_read         (id_mem_read),
    .o_mem_write        (id_mem_write),
    .o_mem_to_reg       (id_mem_to_reg),
    .o_branch           (id_branch),
    // Salidas de predicción de saltos
    .o_branch_prediction(id_branch_prediction),
    .o_branch_target_addr(id_branch_target_addr)
  );

  //===========================================================================
  // LATCH DE PIPELINE ID/EX
  //===========================================================================
  
  // Señales de datos entre ID y EX (registro ID/EX)
  wire [31:0] ex_read_data_1;    // Valor del registro rs propagado a EX
  wire [31:0] ex_read_data_2;    // Valor del registro rt propagado a EX
  wire [31:0] ex_sign_extended_imm; // Inmediato propagado a EX
  wire [4:0]  ex_rs;             // Número de registro rs propagado a EX
  wire [4:0]  ex_rt;             // Número de registro rt propagado a EX
  wire [4:0]  ex_rd;             // Número de registro rd propagado a EX
  wire [5:0]  ex_function;       // Campo function propagado a EX
  wire [5:0]  ex_opcode;         // Opcode propagado a EX
  wire [31:0] ex_next_pc;        // PC+4 propagado a EX
  
  // Señales de predicción de saltos propagadas a EX
  wire        ex_branch_prediction; // Predicción branch propagada a EX
  wire [31:0] ex_branch_target_addr; // Target branch propagado a EX
  
  // Señales de control propagadas a EX
  wire        i_ex_alu_src;      // Control ALU src propagado a EX
  wire [1:0]  i_ex_alu_op;       // Control ALU op propagado a EX
  wire        i_ex_reg_dst;      // Control reg dst propagado a EX
  wire        i_ex_reg_write;    // Control reg write propagado a EX
  wire        i_ex_mem_read;     // Control mem read propagado a EX
  wire        i_ex_mem_write;    // Control mem write propagado a EX
  wire        i_ex_mem_to_reg;   // Control mem-to-reg propagado a EX
  wire        i_ex_branch;       // Control branch propagado a EX
  
  // Instancia del latch ID/EX
  id_ex id_ex_latch(
    .clk                  (clk),
    .reset                (reset),
    .flush                (pipeline_flush), // Usamos pipeline_flush para ID/EX
    // Entradas de datos desde ID
    .read_data_1_in       (id_read_data_1),
    .read_data_2_in       (id_read_data_2),
    .sign_extended_imm_in (id_sign_extended_imm),
    .rs_in                (id_rs),
    .rt_in                (id_rt),
    .rd_in                (id_rd),
    .function_in          (id_function),
    .opcode_in            (id_opcode),
    .next_pc_in           (id_next_pc),
    // Entradas de señales de control desde ID
    .alu_src_in           (id_alu_src),
    .alu_op_in            (id_alu_op),
    .reg_dst_in           (id_reg_dst),
    .reg_write_in         (id_reg_write),
    .mem_read_in          (id_mem_read),
    .mem_write_in         (id_mem_write),
    .mem_to_reg_in        (id_mem_to_reg),
    .branch_in            (id_branch),
    // Entradas de predicción de saltos desde ID
    .branch_prediction_in (id_branch_prediction),
    .branch_target_addr_in(id_branch_target_addr),
    // Salidas de datos hacia EX
    .read_data_1_out      (ex_read_data_1),
    .read_data_2_out      (ex_read_data_2),
    .sign_extended_imm_out(ex_sign_extended_imm),
    .rs_out               (ex_rs),
    .rt_out               (ex_rt),
    .rd_out               (ex_rd),
    .function_out         (ex_function),
    .opcode_out           (ex_opcode),
    .next_pc_out          (ex_next_pc),
    // Salidas de señales de control hacia EX
    .alu_src_out          (i_ex_alu_src),
    .alu_op_out           (i_ex_alu_op),
    .reg_dst_out          (i_ex_reg_dst),
    .reg_write_out        (i_ex_reg_write),
    .mem_read_out         (i_ex_mem_read),
    .mem_write_out        (i_ex_mem_write),
    .mem_to_reg_out       (i_ex_mem_to_reg),
    .branch_out           (i_ex_branch),
    // Salidas de predicción de saltos hacia EX
    .branch_prediction_out(ex_branch_prediction),
    .branch_target_addr_out(ex_branch_target_addr)
  );

  //===========================================================================
  // ETAPA 3: EXECUTION (EX)
  //===========================================================================
  
  // Señales de datos de la etapa EX
  wire [31:0] ex_alu_result;     // Resultado de la ALU
  wire [31:0] ex_write_data;     // Dato para escribir en memoria (rt)
  wire [4:0]  ex_write_register; // Registro destino seleccionado
  wire [31:0] ex_pc_plus_4;      // PC+4 para JAL/JALR
  wire        ex_is_jal;         // Indica si es JAL/JALR
  
  // Señales de control generadas en EX
  wire        ex_reg_write;      // Control de escritura en registros
  wire        ex_mem_read;       // Control de lectura de memoria
  wire        ex_mem_write;      // Control de escritura en memoria
  wire        ex_mem_to_reg;     // Selector entre ALU y memoria
  wire        ex_branch;         // Indica si es instrucción de salto
  
  // Señales de información de saltos
  wire        ex_branch_taken;   // Indica si el salto se toma
  wire        ex_mispredicted;   // Indica error en predicción
  
  // Instancia del módulo de la etapa EX
  ex_stage ex_stage_inst(
    .clk                 (clk),
    .reset               (reset),
    // Entradas de datos desde ID/EX
    .i_read_data_1       (ex_read_data_1),
    .i_read_data_2       (ex_read_data_2),
    .i_sign_extended_imm (ex_sign_extended_imm),
    .i_function          (ex_function),
    .i_rs                (ex_rs),
    .i_rt                (ex_rt),
    .i_rd                (ex_rd),
    .i_opcode            (ex_opcode),
    .i_next_pc           (ex_next_pc),
    
    // Entradas para forwarding (anticipación de datos)
    .i_mem_write_register(mem_write_register), // Registro destino en MEM
    .i_mem_reg_write     (mem_reg_write),      // RegWrite en MEM
    .i_mem_alu_result    (mem_alu_result),     // Resultado ALU en MEM
    .i_wb_write_register (wb_write_register_out), // Registro destino en WB
    .i_wb_reg_write      (wb_reg_write_out),      // RegWrite en WB
    .i_wb_write_data     (wb_write_data),         // Dato de WB
    
    // Entradas de control de forwarding desde la unidad externa
    .i_forward_a         (forward_a),
    .i_forward_b         (forward_b),
    
    // Entradas de señales de control desde ID/EX
    .i_alu_src           (i_ex_alu_src),
    .i_alu_op            (i_ex_alu_op),
    .i_reg_dst           (i_ex_reg_dst),
    .i_reg_write         (i_ex_reg_write),
    .i_mem_read          (i_ex_mem_read),
    .i_mem_write         (i_ex_mem_write),
    .i_mem_to_reg        (i_ex_mem_to_reg),
    .i_branch            (i_ex_branch),
    
    // Entradas de predicción de saltos desde ID/EX
    .i_branch_prediction (ex_branch_prediction),
    .i_branch_target_addr(ex_branch_target_addr),
    
    // Salidas de datos
    .o_alu_result        (ex_alu_result),
    .o_read_data_2       (ex_write_data),
    .o_write_register    (ex_write_register),
    
    // Salidas de señales de control
    .o_reg_write         (ex_reg_write),
    .o_mem_read          (ex_mem_read),
    .o_mem_write         (ex_mem_write),
    .o_mem_to_reg        (ex_mem_to_reg),
    .o_branch            (ex_branch),
    
    // Salidas de información de saltos
    .o_branch_taken      (ex_branch_taken),
    .o_mispredicted      (ex_mispredicted),
    
    // Salidas para JAL/JALR
    .o_pc_plus_4         (ex_pc_plus_4),
    .o_is_jal            (ex_is_jal)
  );

  //===========================================================================
  // LATCH DE PIPELINE EX/MEM
  //===========================================================================
  
  // Señales de datos entre EX y MEM (registro EX/MEM)
  wire [31:0] mem_alu_result;    // Resultado ALU en MEM
  wire [31:0] mem_write_data;    // Dato para escribir en memoria
  wire [4:0]  mem_write_register; // Registro destino en MEM
  wire [31:0] mem_pc_plus_4;     // PC+4 para JAL/JALR
  wire        mem_is_jal;        // Indica si es JAL/JALR
  
  // Señales de control propagadas a MEM
  wire        mem_reg_write;     // Control de escritura en registros
  wire        mem_mem_read;      // Control de lectura de memoria
  wire        mem_mem_write;     // Control de escritura en memoria
  wire        mem_mem_to_reg;    // Selector entre ALU y memoria
  
  // Instancia del latch EX/MEM
  ex_mem ex_mem_latch(
    .clk                 (clk),
    .reset               (reset),
    // Entradas de datos desde EX
    .alu_result_in       (ex_alu_result),
    .read_data_2_in      (ex_write_data),
    .write_register_in   (ex_write_register),
    .pc_plus_4_in        (ex_pc_plus_4),
    .is_jal_in           (ex_is_jal),
    // Entradas de señales de control desde EX
    .reg_write_in        (ex_reg_write),
    .mem_read_in         (ex_mem_read),
    .mem_write_in        (ex_mem_write),
    .mem_to_reg_in       (ex_mem_to_reg),
    // Salidas de datos hacia MEM
    .alu_result_out      (mem_alu_result),
    .read_data_2_out     (mem_write_data),
    .write_register_out  (mem_write_register),
    .pc_plus_4_out       (mem_pc_plus_4),
    .is_jal_out          (mem_is_jal),
    // Salidas de señales de control hacia MEM
    .reg_write_out       (mem_reg_write),
    .mem_read_out        (mem_mem_read),
    .mem_write_out       (mem_mem_write),
    .mem_to_reg_out      (mem_mem_to_reg)
  );

  //===========================================================================
  // ETAPA 4: MEMORY ACCESS (MEM)
  //===========================================================================
  
  // Señales de datos de la etapa MEM
  wire [31:0] mem_read_data;     // Dato leído de memoria
  wire [31:0] mem_alu_result_out; // Resultado ALU desde MEM
  wire [4:0]  mem_write_register_out; // Registro destino desde MEM
  wire [31:0] mem_pc_plus_4_out;  // PC+4 desde MEM
  wire        mem_is_jal_out;     // Indica JAL/JALR desde MEM
  
  // Señales de control generadas en MEM
  wire        mem_reg_write_out;  // Control de escritura desde MEM
  wire        mem_mem_to_reg_out; // Selector desde MEM
  
  // Instancia del módulo de la etapa MEM
  mem_stage mem_stage_inst(
    .clk              (clk),
    .reset            (reset),
    // Entradas de datos desde EX/MEM
    .alu_result_in    (mem_alu_result),
    .write_data_in    (mem_write_data),
    .write_register_in(mem_write_register),
    .pc_plus_4_in     (mem_pc_plus_4),
    .is_jal_in        (mem_is_jal),
    // Entradas de señales de control desde EX/MEM
    .reg_write_in     (mem_reg_write),
    .mem_read_in      (mem_mem_read),
    .mem_write_in     (mem_mem_write),
    .mem_to_reg_in    (mem_mem_to_reg),
    // Salidas de datos
    .read_data_out    (mem_read_data),
    .alu_result_out   (mem_alu_result_out),
    .write_register_out(mem_write_register_out),
    .pc_plus_4_out    (mem_pc_plus_4_out),
    .is_jal_out       (mem_is_jal_out),
    // Salidas de señales de control
    .reg_write_out    (mem_reg_write_out),
    .mem_to_reg_out   (mem_mem_to_reg_out)
  );

  //===========================================================================
  // LATCH MEM/WB
  //===========================================================================
  
  // Señales de datos entre MEM y WB (registro MEM/WB)
  wire [31:0] wb_alu_result;     // Resultado ALU en WB
  wire [31:0] wb_read_data;      // Dato leído de memoria en WB
  wire [4:0]  wb_write_register; // Registro destino en WB
  wire [31:0] wb_pc_plus_4;      // PC+4 en WB
  wire        wb_is_jal;         // Indica JAL/JALR en WB
  
  // Señales de control propagadas a WB
  wire        wb_reg_write;      // Control de escritura en WB
  wire        wb_mem_to_reg;     // Selector en WB
  
 
  mem_wb mem_wb_latch(
    .clk                 (clk),
    .reset               (reset),
    // Entradas de datos desde MEM
    .alu_result_in       (mem_alu_result_out),
    .read_data_in        (mem_read_data),
    .write_register_in   (mem_write_register_out),
    .pc_plus_4_in        (mem_pc_plus_4_out),
    .is_jal_in           (mem_is_jal_out),
    // Entradas de señales de control desde MEM
    .reg_write_in        (mem_reg_write_out),
    .mem_to_reg_in       (mem_mem_to_reg_out),
    // Salidas de datos hacia WB
    .alu_result_out      (wb_alu_result),
    .read_data_out       (wb_read_data),
    .write_register_out  (wb_write_register),
    .pc_plus_4_out       (wb_pc_plus_4),
    .is_jal_out          (wb_is_jal),
    // Salidas de señales de control hacia WB
    .reg_write_out       (wb_reg_write),
    .mem_to_reg_out      (wb_mem_to_reg)
  );

  //===========================================================================
  // ETAPA 5: WRITE BACK (WB)
  //===========================================================================
  
  // Señales de datos de la etapa WB
  wire [31:0] wb_write_data;     // Dato a escribir en registros
  wire [4:0]  wb_write_register_out; // Registro destino final
  wire        wb_reg_write_out;  // Control de escritura final
  
  // Instancia del módulo de la etapa WB
  wb_stage wb_stage_inst(
    .clk              (clk),
    .reset            (reset),
    // Entradas de datos desde MEM/WB
    .i_alu_result     (wb_alu_result),
    .i_read_data      (wb_read_data),
    .i_write_register (wb_write_register),
    .i_pc_plus_4      (wb_pc_plus_4),
    .i_is_jal         (wb_is_jal),
    // Entradas de señales de control desde MEM/WB
    .i_reg_write      (wb_reg_write),
    .i_mem_to_reg     (wb_mem_to_reg),
    // Salidas hacia retroalimentación a ID
    .o_write_data     (wb_write_data),
    .o_write_register (wb_write_register_out),
    .o_reg_write      (wb_reg_write_out)
  );

  //===========================================================================
  // FORWARDING UNIT
  //===========================================================================
  
  // Señales de la unidad de forwarding
  wire [1:0] forward_a;  // Control para operando A (RS)
  wire [1:0] forward_b;  // Control para operando B (RT)
  
  // Instancia de la unidad de forwarding
  forwarding_unit forwarding_unit_inst(
    .i_ex_rs        (ex_rs),                  // RS en EX
    .i_ex_rt        (ex_rt),                  // RT en EX
    .i_mem_rd       (mem_write_register),     // Registro destino en MEM
    .i_mem_reg_write(mem_reg_write),          // RegWrite en MEM
    .i_wb_rd        (wb_write_register_out),  // Registro destino en WB
    .i_wb_reg_write (wb_reg_write_out),       // RegWrite en WB
    .o_forward_a    (forward_a),              // Control para operando A
    .o_forward_b    (forward_b)               // Control para operando B
  );

  //===========================================================================
  // UNIDAD DE DETECCIÓN DE RIESGOS (HAZARD DETECTION)
  //===========================================================================
  hazard_detection hazard_detection_unit(
    .i_if_id_rs            (id_rs),            // Registro RS desde etapa ID
    .i_if_id_rt            (id_rt),            // Registro RT desde etapa ID 
    .i_id_ex_rt            (ex_rt),            // Registro RT desde etapa EX
    .i_id_ex_mem_read      (i_ex_mem_read),    // Señal de lectura de memoria en EX
    .i_if_id_opcode        (id_opcode),        // Opcode desde etapa ID
    .i_if_id_funct         (id_function),      // Campo function desde etapa ID
    .i_branch_taken        (ex_branch_taken),  // Señal de salto tomado
    .i_branch_mispredicted (ex_mispredicted),  // Señal de predicción incorrecta
    .o_stall               (pipeline_stall),   // Señal de parada del pipeline
    .o_flush               (pipeline_flush),   // Señal de flush del pipeline
    .o_ctrl_hazard         (control_hazard),   // Señal de riesgo de control
    .o_halt                (halt_detected)     // Detección instrucción HALT
  );

  //===========================================================================
  // ASIGNACIONES DE SALIDA DEL PROCESADOR
  //===========================================================================
  
  // Conectar la señal de HALT a la salida
  assign halt = halt_detected;

endmodule
