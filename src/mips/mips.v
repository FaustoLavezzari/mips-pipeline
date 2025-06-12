`timescale 1ns / 1ps
`include "mips_pkg.vh"

module mips(
  input  wire        clk,
  input  wire        reset,
  output wire [31:0] result,
  output wire        halt    // Nueva señal de halt
);

  // ========== Señales para las etapas ==========
  wire [31:0] ex_alu_result;
  wire [31:0] ex_write_data;
  wire [4:0]  ex_write_register;
  wire        ex_reg_write;
  wire        ex_mem_read;
  wire        ex_mem_write;
  wire        ex_mem_to_reg;
  // Ya no necesitamos señales especiales para JAL/JALR en las salidas de EX
  
  wire [31:0] mem_alu_result;
  wire [31:0] mem_write_data;
  wire [4:0]  mem_write_register;
  wire        mem_reg_write;
  wire        mem_mem_read;
  wire        mem_mem_write;
  wire        mem_mem_to_reg;
  wire [31:0] mem_read_data;
  wire [5:0]  mem_opcode;           // Opcode para identificar el tipo de instrucción
  
  // Señales adicionales para propagar la etapa MEM
  wire [31:0] mem_alu_result_out;
  wire [4:0]  mem_write_register_out;
  wire        mem_reg_write_out;
  wire        mem_mem_to_reg_out;
  
  // ========== Señales de la etapa WB ==========
  wire [31:0] wb_alu_result;
  wire [31:0] wb_read_data;
  wire [4:0]  wb_write_register;
  wire        wb_reg_write;
  wire        wb_mem_to_reg;
  wire [31:0] wb_write_data;      // Dato a escribir en el banco de registros
  wire [4:0]  wb_write_register_out; // Señal corregida de salida de la etapa WB
  wire        wb_reg_write_out;      // Señal corregida de salida de la etapa WB

  // ========== Señales entre IF e ID ==========
  wire [31:0] if_next_pc;
  wire [31:0] if_instr;
  wire [31:0] id_next_pc;
  wire [31:0] id_instr;
  
  // ========== Señales de la etapa ID ==========
  wire [31:0] id_read_data_1;
  wire [31:0] id_read_data_2;
  wire [31:0] id_sign_extended_imm;
  wire [4:0]  id_rs;              // Añadido para forwarding
  wire [4:0]  id_rt;
  wire [4:0]  id_rd;
  wire [4:0]  id_shamt;           // Campo shamt para instrucciones SLL/SRL
  wire [5:0]  id_function;
  wire [5:0]  id_opcode;
  
  // ========== Señales para ID forwarding ==========
  wire        id_use_forwarded_a;  // Señal para usar valor forwardeado para RS
  wire        id_use_forwarded_b;  // Señal para usar valor forwardeado para RT
  wire        id_alu_src;
  wire [2:0]  id_alu_op;
  wire        id_reg_dst;
  wire        id_reg_write;
  wire        id_mem_read;
  wire        id_mem_write;
  wire        id_mem_to_reg;
  wire        id_branch_prediction = 1'b0;      // Señal de predicción (para compatibilidad)
  wire [31:0] id_branch_target_addr;     // Dirección destino del salto
  
  // ========== Señales para control de saltos en ID ==========
  wire        id_take_branch;           // Señal unificada para saltos (condicionales e incondicionales)
  wire        id_is_jal;                // Indica si es una instrucción JAL (Jump and Link)

  // ========== Señales del latch ID/EX ==========
  wire [31:0] ex_read_data_1;
  wire [31:0] ex_read_data_2;
  wire [31:0] ex_sign_extended_imm;
  wire [4:0]  ex_rs;              // Añadido para forwarding
  wire [4:0]  ex_rt;
  wire [4:0]  ex_rd;
  wire [4:0]  ex_shamt;           // Campo shamt para instrucciones SLL/SRL
  wire [5:0]  ex_function;
  wire [5:0]  ex_opcode;
  wire [31:0] ex_next_pc;         // PC+4 para JAL/JALR
  
  // ========== Señales de branch prediction en EX ==========
  wire        ex_branch_prediction;
  wire [31:0] ex_branch_target_addr;
  
  // ========== Señales de control entre ID/EX y EX ==========
  wire        i_ex_alu_src;
  wire [2:0]  i_ex_alu_op;
  wire        i_ex_reg_dst;
  wire        i_ex_reg_write;
  wire        i_ex_mem_read;
  wire        i_ex_mem_write;
  wire        i_ex_mem_to_reg;
  wire        i_ex_is_jal;      // Señal JAL para EX

  // ========== Hazard detection signals ==========
  wire       pipeline_stall;      // Signal to stall pipeline
  wire       flush_if_id;         // Signal to flush IF/ID stage (branch/jump hazard)
  wire       flush_id_ex;         // Signal to flush ID/EX stage (load hazard)
  wire       control_hazard;      // Signal for control hazard propagation
  wire       halt_detected;       // Signal for HALT instruction detected
  
  // ========== Instancia de la unidad de detección de riesgos ==========
  hazard_detection hazard_detection_unit(
    .i_if_id_rs            (id_rs),           // RS from ID stage
    .i_if_id_rt            (id_rt),           // RT from ID stage 
    .i_id_ex_rt            (ex_rt),           // RT from EX stage
    .i_id_ex_mem_read      (i_ex_mem_read),   // MemRead signal in EX stage
    .i_if_id_opcode        (id_opcode),       // Opcode from ID stage
    .i_if_id_funct         (id_function),     // Function code from ID stage
    .i_id_take_branch      (id_take_branch),  // Unified branch/jump taken signal from ID
    .o_stall              (pipeline_stall),   // Stall signal
    .o_flush_id_ex        (flush_id_ex),      // Flush signal for ID/EX stage
    .o_flush_if_id        (flush_if_id),      // Flush signal for IF/ID stage
    .o_ctrl_hazard        (control_hazard),   // Control hazard signal
    .o_halt               (halt_detected)     // HALT instruction detected
  );
  
  // ========== Instancia de la unidad de forwarding para ID ==========
  wire [31:0] id_forwarded_value_a;  // Valor forwardeado para RS
  wire [31:0] id_forwarded_value_b;  // Valor forwardeado para RT
  
  id_forwarding id_forwarding_inst(
    .i_id_rs          (id_rs),                   // RS en ID
    .i_id_rt          (id_rt),                   // RT en ID
    .i_ex_rd          (ex_write_register),       // Registro destino en EX
    .i_ex_reg_write   (ex_reg_write),            // RegWrite en EX
    .i_ex_alu_result  (ex_alu_result),           // Resultado ALU en EX
    .i_mem_rd         (mem_write_register),      // Registro destino en MEM
    .i_mem_reg_write  (mem_reg_write),           // RegWrite en MEM
    .i_mem_alu_result (mem_alu_result),          // Resultado ALU en MEM
    .i_wb_rd          (wb_write_register_out),   // Registro destino en WB
    .i_wb_reg_write   (wb_reg_write_out),        // RegWrite en WB
    .i_wb_write_data  (wb_write_data),           // Dato de WB
    .o_use_forwarded_a(id_use_forwarded_a),      // Señal para usar valor forwardeado para RS
    .o_use_forwarded_b(id_use_forwarded_b),      // Señal para usar valor forwardeado para RT
    .o_forwarded_value_a(id_forwarded_value_a),  // Valor forwardeado para RS
    .o_forwarded_value_b(id_forwarded_value_b)   // Valor forwardeado para RT
  );

  // ========== Instancia de la etapa IF ==========
  if_stage if_stage_inst(
    .clk                (clk),
    .reset              (reset),
    // Señales simplificadas de control de saltos desde ID
    .i_take_branch      (id_take_branch),
    .i_branch_target_addr(id_branch_target_addr),
    // Señales de control de pipeline
    .i_halt             (halt_detected),
    .i_stall            (pipeline_stall),    // Conectar señal de stall
    .o_next_pc          (if_next_pc),
    .o_instr            (if_instr)
  );
  
  // ========== Instancia del registro IF/ID ==========
  if_id if_id_reg(
    .clk         (clk),
    .reset       (reset),
    .flush       (flush_if_id),      // Flush IF/ID cuando hay branch/jump taken
    .stall       (pipeline_stall),   // Connect stall signal
    .next_pc_in  (if_next_pc),
    .instr_in    (if_instr),
    .next_pc_out (id_next_pc),
    .instr_out   (id_instr)
  );
  
  // ========== Instancia de la etapa ID ==========
  id_stage id_stage_inst(
    .clk                (clk),
    .reset              (reset),
    .i_next_pc          (id_next_pc),
    .i_instruction      (id_instr),
    
    // Señales para el banco de registros
    .i_reg_write        (wb_reg_write_out),      // Corregido para usar señal WB de salida
    .i_write_register   (wb_write_register_out), // Corregido para usar señal WB de salida
    .i_write_data       (wb_write_data),         // Esta señal está correcta
    
    // Entradas simplificadas para forwarding (valores ya seleccionados)
    .i_forwarded_value_a(id_forwarded_value_a),  // Valor ya seleccionado por la unidad de forwarding
    .i_forwarded_value_b(id_forwarded_value_b),  // Valor ya seleccionado por la unidad de forwarding
    
    // Señales de control de forwarding
    .i_use_forwarded_a  (id_use_forwarded_a),
    .i_use_forwarded_b  (id_use_forwarded_b),
    
    // Salidas de valores de registros
    .o_read_data_1      (id_read_data_1),
    .o_read_data_2      (id_read_data_2),
    .o_sign_extended_imm(id_sign_extended_imm),
    .o_rs               (id_rs),              // Registro RS para forwarding
    .o_rt               (id_rt),
    .o_rd               (id_rd),
    .o_shamt            (id_shamt),           // Campo shamt para instrucciones SLL/SRL
    .o_function         (id_function),
    .o_opcode           (id_opcode),
    .o_alu_src          (id_alu_src),
    .o_alu_op           (id_alu_op),
    .o_reg_dst          (id_reg_dst),
    .o_reg_write        (id_reg_write),
    .o_mem_read         (id_mem_read),
    .o_mem_write        (id_mem_write),
    .o_mem_to_reg       (id_mem_to_reg),
    .o_is_jal           (id_is_jal),               // Señal para JAL
    .o_branch_target_addr(id_branch_target_addr),  // Dirección de destino
    .o_take_branch      (id_take_branch)           // Señal unificada: saltar o no
  );

  // ========== Instancia del latch ID/EX ==========
id_ex id_ex_latch(
    .clk                  (clk),
    .reset                (reset),
    .flush                (flush_id_ex),      // Flush ID/EX cuando hay load hazard
    .read_data_1_in       (id_read_data_1),
    .read_data_2_in       (id_read_data_2),
    .sign_extended_imm_in (id_sign_extended_imm),
    .rs_in                (id_rs),            // Registro RS para forwarding
    .rt_in                (id_rt),
    .rd_in                (id_rd),
    .shamt_in             (id_shamt),         // Campo shamt para instrucciones SLL/SRL
    .function_in          (id_function),
    .opcode_in            (id_opcode),
    .next_pc_in           (id_next_pc),      // PC+4 para JAL/JALR
    .alu_src_in           (id_alu_src),
    .alu_op_in            (id_alu_op),
    .reg_dst_in           (id_reg_dst),
    .reg_write_in         (id_reg_write),
    .mem_read_in          (id_mem_read),
    .mem_write_in         (id_mem_write),
    .mem_to_reg_in        (id_mem_to_reg),
    .is_jal_in            (id_is_jal),            // Nueva señal para JAL
    .branch_prediction_in(id_branch_prediction),
    .branch_target_addr_in(id_branch_target_addr),
    .read_data_1_out      (ex_read_data_1),
    .read_data_2_out      (ex_read_data_2),
    .sign_extended_imm_out(ex_sign_extended_imm),
    .rs_out               (ex_rs),            // Registro RS para forwarding
    .rt_out               (ex_rt),
    .rd_out               (ex_rd),
    .shamt_out            (ex_shamt),         // Campo shamt para instrucciones SLL/SRL
    .function_out         (ex_function),
    .opcode_out           (ex_opcode),
    .next_pc_out          (ex_next_pc),         // PC+4 para JAL/JALR
    .alu_src_out          (i_ex_alu_src),
    .alu_op_out           (i_ex_alu_op),
    .reg_dst_out          (i_ex_reg_dst),
    .reg_write_out        (i_ex_reg_write),
    .mem_read_out         (i_ex_mem_read),
    .mem_write_out        (i_ex_mem_write),
    .mem_to_reg_out       (i_ex_mem_to_reg),
    .is_jal_out           (i_ex_is_jal),         // Salida de señal para JAL
    .branch_prediction_out(ex_branch_prediction),
    .branch_target_addr_out(ex_branch_target_addr)
  );
  
  // ========== Señales para la unidad de forwarding de EX ==========
  wire        ex_use_forwarded_a;      // Señal para usar valor forwardeado para RS
  wire        ex_use_forwarded_b;      // Señal para usar valor forwardeado para RT
  wire [31:0] ex_forwarded_value_a;    // Valor forwardeado para RS
  wire [31:0] ex_forwarded_value_b;    // Valor forwardeado para RT
  
  // ========== Instancia de la unidad de forwarding para EX ==========
  forwarding_unit forwarding_ex_inst(
    .i_ex_rs          (ex_rs),                   // RS en EX
    .i_ex_rt          (ex_rt),                   // RT en EX
    .i_mem_rd         (mem_write_register),      // Registro destino en MEM
    .i_mem_reg_write  (mem_reg_write),           // RegWrite en MEM
    .i_mem_result     (mem_alu_result),          // Resultado ALU en MEM
    .i_wb_rd          (wb_write_register_out),   // Registro destino en WB
    .i_wb_reg_write   (wb_reg_write_out),        // RegWrite en WB
    .i_wb_result      (wb_write_data),           // Datos desde WB
    .o_use_forwarded_a(ex_use_forwarded_a),      // Señal para usar valor forwardeado para RS
    .o_use_forwarded_b(ex_use_forwarded_b),      // Señal para usar valor forwardeado para RT
    .o_forwarded_value_a(ex_forwarded_value_a),  // Valor forwardeado para RS
    .o_forwarded_value_b(ex_forwarded_value_b)   // Valor forwardeado para RT
  );
  
  // ========== Instancia de la etapa EX ==========
  ex_stage ex_stage_inst(
    .clk                 (clk),
    .reset               (reset),
    .i_read_data_1       (ex_read_data_1),
    .i_read_data_2       (ex_read_data_2),
    .i_sign_extended_imm (ex_sign_extended_imm),
    .i_function          (ex_function),
    .i_rs                (ex_rs),            // Registro RS para forwarding
    .i_rt                (ex_rt),
    .i_rd                (ex_rd),
    .i_shamt             (ex_shamt),         // Campo shamt para instrucciones SLL/SRL
    .i_opcode            (ex_opcode),
    .i_next_pc           (ex_next_pc),       // PC+4 para JAL/JALR
    
    // Señales para forwarding (anticipación de datos)
    .i_forwarded_value_a (ex_forwarded_value_a),  // Valor ya seleccionado para RS
    .i_forwarded_value_b (ex_forwarded_value_b),  // Valor ya seleccionado para RT
    .i_use_forwarded_a   (ex_use_forwarded_a),    // Control de forwarding para RS (0:registro, 1:forwarded)
    .i_use_forwarded_b   (ex_use_forwarded_b),    // Control de forwarding para RT (0:registro, 1:forwarded)
    
    .i_alu_src           (i_ex_alu_src),
    .i_alu_op            (i_ex_alu_op),
    .i_reg_dst           (i_ex_reg_dst),
    .i_reg_write         (i_ex_reg_write),
    .i_mem_read          (i_ex_mem_read),
    .i_mem_write         (i_ex_mem_write),
    .i_mem_to_reg        (i_ex_mem_to_reg),
    .i_is_jal            (i_ex_is_jal),       // Para JAL/JALR
    
    .o_alu_result        (ex_alu_result),
    .o_read_data_2       (ex_write_data),
    .o_write_register    (ex_write_register),
    .o_reg_write         (ex_reg_write),
    .o_mem_read          (ex_mem_read),
    .o_mem_write         (ex_mem_write),
    .o_mem_to_reg        (ex_mem_to_reg)
  );
  
  // ========== Instancia del latch EX/MEM ==========
  ex_mem ex_mem_reg(
    .clk                 (clk),
    .reset               (reset),
    .flush               (1'b0),      // No hacemos flush de EX/MEM, las instrucciones que ya alcanzaron EX deben completarse
    .alu_result_in       (ex_alu_result),
    .read_data_2_in      (ex_write_data),
    .write_register_in   (ex_write_register),
    .reg_write_in        (ex_reg_write),      // Usando salida de EX stage
    .mem_read_in         (ex_mem_read),       // Usando salida de EX stage
    .mem_write_in        (ex_mem_write),      // Usando salida de EX stage
    .mem_to_reg_in       (ex_mem_to_reg),     // Usando salida de EX stage
    .opcode_in           (ex_opcode),         // Propagar el opcode a MEM
    .alu_result_out      (mem_alu_result),
    .read_data_2_out     (mem_write_data),
    .write_register_out  (mem_write_register),
    .reg_write_out       (mem_reg_write),
    .mem_read_out        (mem_mem_read),
    .mem_write_out       (mem_mem_write),
    .mem_to_reg_out      (mem_mem_to_reg),
    .opcode_out          (mem_opcode)
  );
  
  // ========== Instancia de la etapa MEM ==========
  mem_stage mem_stage_inst(
    .clk              (clk),
    .reset            (reset),
    .alu_result_in    (mem_alu_result),
    .write_data_in    (mem_write_data),
    .write_register_in(mem_write_register),
    .reg_write_in     (mem_reg_write),
    .mem_read_in      (mem_mem_read),
    .mem_write_in     (mem_mem_write),
    .mem_to_reg_in    (mem_mem_to_reg),
    .opcode_in        (mem_opcode),        // Opcode para identificar el tipo de instrucción
    .read_data_out    (mem_read_data),
    .alu_result_out   (mem_alu_result_out),
    .write_register_out(mem_write_register_out),
    .reg_write_out    (mem_reg_write_out),
    .mem_to_reg_out   (mem_mem_to_reg_out)
  );
  
  // ========== Instancia del latch MEM/WB ==========
  mem_wb mem_wb_reg(
    .clk                 (clk),
    .reset               (reset),
    .flush               (1'b0),      // No hacemos flush de MEM/WB para permitir que las instrucciones completen
    .alu_result_in       (mem_alu_result_out),
    .read_data_in        (mem_read_data),
    .write_register_in   (mem_write_register_out),
    .reg_write_in        (mem_reg_write_out),
    .mem_to_reg_in       (mem_mem_to_reg_out),
    .alu_result_out      (wb_alu_result),
    .read_data_out       (wb_read_data),
    .write_register_out  (wb_write_register),
    .reg_write_out       (wb_reg_write),
    .mem_to_reg_out      (wb_mem_to_reg)
  );
  
  // ========== Instancia de la etapa WB ==========
  // Corregimos las señales de retroalimentación para evitar el cortocircuito
  wb_stage wb_stage_inst(
    .clk              (clk),
    .reset            (reset),
    .i_alu_result     (wb_alu_result),
    .i_read_data      (wb_read_data),
    .i_write_register (wb_write_register),
    .i_reg_write      (wb_reg_write),
    .i_mem_to_reg     (wb_mem_to_reg),
    .o_write_data     (wb_write_data),
    .o_write_register (wb_write_register_out),  // Renombramos para evitar el cortocircuito
    .o_reg_write      (wb_reg_write_out)        // Renombramos para evitar el cortocircuito
  );
  
  // ========== Asignaciones adicionales ==========
  // El resultado final es el dato que se escribe en los registros
  assign result = wb_write_data;
  
  // Conectar la señal de HALT a la salida
  assign halt = halt_detected;

endmodule