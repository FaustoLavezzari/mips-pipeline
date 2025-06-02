`timescale 1ns / 1ps
`include "mips_pkg.vh"

module mips(
  input  wire        clk,
  input  wire        reset,
  output wire [31:0] result,
  output wire        halt    // Nueva señal de s  // ========== Instancia del registro ID/IE ==========

);
  //  == Señales para las etapas ==========
  wire [31:0] ex_alu_result;
  wire [31:0] ex_write_data;
  wire [4:0]  ex_write_register;
  wire        ex_reg_write;
  wire        ex_mem_read;
  wire        ex_mem_write;
  wire        ex_mem_to_reg;
  wire        ex_branch;
  wire        ex_branch_taken;     // Indica si el salto se toma realmente
  wire        ex_mispredicted;     // Indica si hubo un error en la predicción
  wire [31:0] ex_pc_plus_4;        // PC+4 para JAL/JALR
  wire        ex_is_jal;           // Señal para indicar JAL/JALR
  
  wire [31:0] mem_alu_result;
  wire [31:0] mem_write_data;
  wire [4:0]  mem_write_register;
  wire        mem_reg_write;
  wire        mem_mem_read;
  wire        mem_mem_write;
  wire        mem_mem_to_reg;
  wire [31:0] mem_read_data;
  wire [31:0] mem_pc_plus_4;        // PC+4 para JAL/JALR
  wire        mem_is_jal;           // Señal para indicar JAL/JALR
  
  // Señales adicionales para propagar la etapa MEM
  wire [31:0] mem_alu_result_out;
  wire [4:0]  mem_write_register_out;
  wire        mem_reg_write_out;
  wire        mem_mem_to_reg_out;
  wire [31:0] mem_pc_plus_4_out;     // PC+4 para JAL/JALR propagado
  wire        mem_is_jal_out;        // Señal JAL/JALR propagada
  
  // ========== Señales de la etapa WB ==========
  wire [31:0] wb_alu_result;
  wire [31:0] wb_read_data;
  wire [4:0]  wb_write_register;
  wire        wb_reg_write;
  wire        wb_mem_to_reg;
  wire [31:0] wb_pc_plus_4;       // PC+4 para JAL/JALR
  wire        wb_is_jal;          // Señal para JAL/JALR
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
  wire [5:0]  id_function;
  wire [5:0]  id_opcode;
  wire        id_alu_src;
  wire [1:0]  id_alu_op;
  wire        id_reg_dst;
  wire        id_reg_write;
  wire        id_mem_read;
  wire        id_mem_write;
  wire        id_mem_to_reg;
  wire        id_branch;
  wire        id_branch_prediction;      // Señal de predicción (0 = not taken)
  wire [31:0] id_branch_target_addr;     // Dirección destino del salto
  
  // ========== Señales para branch prediction ==========
  wire        id_branch_prediction;

  // ========== Señales del latch ID/EX ==========
  wire [31:0] ex_read_data_1;
  wire [31:0] ex_read_data_2;
  wire [31:0] ex_sign_extended_imm;
  wire [4:0]  ex_rs;              // Añadido para forwarding
  wire [4:0]  ex_rt;
  wire [4:0]  ex_rd;
  wire [5:0]  ex_function;
  wire [5:0]  ex_opcode;
  wire [31:0] ex_next_pc;         // PC+4 para JAL/JALR
  
  // ========== Señales de branch prediction en EX ==========
  wire        ex_branch_prediction;
  wire [31:0] ex_branch_target_addr;
  
  // ========== Señales de control entre ID/EX y EX ==========
  wire        i_ex_alu_src;
  wire [1:0]  i_ex_alu_op;
  wire        i_ex_reg_dst;
  wire        i_ex_reg_write;
  wire        i_ex_mem_read;
  wire        i_ex_mem_write;
  wire        i_ex_mem_to_reg;
  wire        i_ex_branch;

  // ========== Hazard detection signals ==========
  wire       pipeline_stall;    // Signal to stall pipeline
  wire       pipeline_flush;    // Signal to flush pipeline
  wire       control_hazard;    // Signal for control hazard propagation
  wire       halt_detected;     // Signal for HALT instruction detected
  
  // ========== Instancia de la unidad de detección de riesgos ==========
  hazard_detection hazard_detection_unit(
    .i_if_id_rs            (id_rs),           // RS from ID stage
    .i_if_id_rt            (id_rt),           // RT from ID stage 
    .i_id_ex_rt            (ex_rt),           // RT from EX stage
    .i_id_ex_mem_read      (i_ex_mem_read),   // MemRead signal in EX stage
    .i_if_id_opcode        (id_opcode),       // Opcode from ID stage
    .i_if_id_funct         (id_function),     // Function code from ID stage
    .i_branch_taken        (ex_branch_taken),      // Branch taken signal
    .i_branch_mispredicted (ex_mispredicted), // Branch misprediction
    .o_stall              (pipeline_stall),   // Stall signal
    .o_flush              (pipeline_flush),   // Flush signal
    .o_ctrl_hazard        (control_hazard),   // Control hazard signal
    .o_halt               (halt_detected)     // HALT instruction detected
  );

  // ========== Instancia de la etapa IF ==========
  if_stage if_stage_inst(
    .clk                (clk),
    .reset              (reset),
    // Señales de predicción desde ID
    .i_branch_prediction(id_branch_prediction),
    .i_branch_target_addr(id_branch_target_addr),
    // Señales de corrección desde EX
    .i_mispredicted     (ex_mispredicted),
    .i_branch_taken     (ex_branch_taken),
    .i_ex_branch_target (ex_branch_target_addr),
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
    .flush       (pipeline_flush),    // Connect flush signal
    .stall       (pipeline_stall),    // Connect stall signal
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
    .i_reg_write        (wb_reg_write_out),      // Corregido para usar señal WB de salida
    .i_write_register   (wb_write_register_out), // Corregido para usar señal WB de salida
    .i_write_data       (wb_write_data),         // Esta señal está correcta
    .o_read_data_1      (id_read_data_1),
    .o_read_data_2      (id_read_data_2),
    .o_sign_extended_imm(id_sign_extended_imm),
    .o_rs               (id_rs),              // Registro RS para forwarding
    .o_rt               (id_rt),
    .o_rd               (id_rd),
    .o_function         (id_function),
    .o_opcode           (id_opcode),
    .o_alu_src          (id_alu_src),
    .o_alu_op           (id_alu_op),
    .o_reg_dst          (id_reg_dst),
    .o_reg_write        (id_reg_write),
    .o_mem_read         (id_mem_read),
    .o_mem_write        (id_mem_write),
    .o_mem_to_reg       (id_mem_to_reg),
    .o_branch           (id_branch),
    .o_branch_prediction(id_branch_prediction),
    .o_branch_target_addr(id_branch_target_addr)
  );

  // ========== Instancia del latch ID/EX ==========
  id_ie id_ie_reg(
    .clk                  (clk),
    .reset                (reset),
    .flush                (pipeline_flush), // Connect flush signal
    .read_data_1_in       (id_read_data_1),
    .read_data_2_in       (id_read_data_2),
    .sign_extended_imm_in (id_sign_extended_imm),
    .rs_in                (id_rs),            // Registro RS para forwarding
    .rt_in                (id_rt),
    .rd_in                (id_rd),
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
    .branch_in            (id_branch),
    .branch_prediction_in(id_branch_prediction),
    .branch_target_addr_in(id_branch_target_addr),
    .read_data_1_out      (ex_read_data_1),
    .read_data_2_out      (ex_read_data_2),
    .sign_extended_imm_out(ex_sign_extended_imm),
    .rs_out               (ex_rs),            // Registro RS para forwarding
    .rt_out               (ex_rt),
    .rd_out               (ex_rd),
    .function_out         (ex_function),
    .opcode_out           (ex_opcode),
    .alu_src_out          (i_ex_alu_src),
    .alu_op_out           (i_ex_alu_op),
    .reg_dst_out          (i_ex_reg_dst),
    .reg_write_out        (i_ex_reg_write),
    .mem_read_out         (i_ex_mem_read),
    .mem_write_out        (i_ex_mem_write),
    .mem_to_reg_out       (i_ex_mem_to_reg),
    .branch_out           (i_ex_branch),
    .branch_prediction_out(ex_branch_prediction),
    .branch_target_addr_out(ex_branch_target_addr)
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
    .i_opcode            (ex_opcode),
    .i_next_pc           (ex_next_pc),       // PC+4 para JAL/JALR
    
    // Señales para forwarding (anticipación de datos)
    .i_mem_write_register(mem_write_register), // Registro destino en MEM
    .i_mem_reg_write     (mem_reg_write),      // RegWrite en MEM
    .i_mem_alu_result    (mem_alu_result),     // Resultado ALU en MEM
    .i_wb_write_register (wb_write_register_out), // Registro destino en WB
    .i_wb_reg_write      (wb_reg_write_out),      // RegWrite en WB
    .i_wb_write_data     (wb_write_data),         // Dato de WB
    
    .i_alu_src           (i_ex_alu_src),
    .i_alu_op            (i_ex_alu_op),
    .i_reg_dst           (i_ex_reg_dst),
    .i_reg_write         (i_ex_reg_write),
    .i_mem_read          (i_ex_mem_read),
    .i_mem_write         (i_ex_mem_write),
    .i_mem_to_reg        (i_ex_mem_to_reg),
    .i_branch            (i_ex_branch),
    .i_branch_prediction (ex_branch_prediction),
    .i_branch_target_addr(ex_branch_target_addr),
    .o_alu_result        (ex_alu_result),
    .o_read_data_2       (ex_write_data),
    .o_write_register    (ex_write_register),
    .o_reg_write         (ex_reg_write),
    .o_mem_read          (ex_mem_read),
    .o_mem_write         (ex_mem_write),
    .o_mem_to_reg        (ex_mem_to_reg),
    .o_branch            (ex_branch),
    .o_branch_taken      (ex_branch_taken),
    .o_mispredicted      (ex_mispredicted),
    .o_pc_plus_4         (ex_pc_plus_4),     // PC+4 para JAL/JALR
    .o_is_jal            (ex_is_jal)         // Señal para JAL/JALR
  );
  
  // ========== Instancia del latch EX/MEM ==========
  ex_mem ex_mem_reg(
    .clk                 (clk),
    .reset               (reset),
    .flush               (pipeline_flush),      // Añadimos la señal de flush para limpiar el registro en caso de saltos mal predichos
    .alu_result_in       (ex_alu_result),
    .read_data_2_in      (ex_write_data),
    .write_register_in   (ex_write_register),
    .reg_write_in        (ex_reg_write),      // Usando salida de EX stage
    .mem_read_in         (ex_mem_read),       // Usando salida de EX stage
    .mem_write_in        (ex_mem_write),      // Usando salida de EX stage
    .mem_to_reg_in       (ex_mem_to_reg),     // Usando salida de EX stage
    .pc_plus_4_in        (ex_pc_plus_4),      // PC+4 para JAL/JALR
    .is_jal_in           (ex_is_jal),         // Señal para JAL/JALR
    .alu_result_out      (mem_alu_result),
    .read_data_2_out     (mem_write_data),
    .write_register_out  (mem_write_register),
    .reg_write_out       (mem_reg_write),
    .mem_read_out        (mem_mem_read),
    .mem_write_out       (mem_mem_write),
    .mem_to_reg_out      (mem_mem_to_reg),
    .pc_plus_4_out       (mem_pc_plus_4),
    .is_jal_out          (mem_is_jal)
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
    .pc_plus_4_in     (mem_pc_plus_4),     // PC+4 para JAL/JALR
    .is_jal_in        (mem_is_jal),        // Señal para JAL/JALR
    .read_data_out    (mem_read_data),
    .alu_result_out   (mem_alu_result_out),
    .write_register_out(mem_write_register_out),
    .reg_write_out    (mem_reg_write_out),
    .mem_to_reg_out   (mem_mem_to_reg_out),
    .pc_plus_4_out    (mem_pc_plus_4_out),
    .is_jal_out       (mem_is_jal_out)
  );
  
  // ========== Instancia del latch MEM/WB ==========
  mem_wb mem_wb_reg(
    .clk                 (clk),
    .reset               (reset),
    .flush               (pipeline_flush),      // Añadimos la señal de flush para limpiar el registro en caso de saltos mal predichos
    .alu_result_in       (mem_alu_result_out),
    .read_data_in        (mem_read_data),
    .write_register_in   (mem_write_register_out),
    .reg_write_in        (mem_reg_write_out),
    .mem_to_reg_in       (mem_mem_to_reg_out),
    .pc_plus_4_in        (mem_pc_plus_4_out),
    .is_jal_in           (mem_is_jal_out),
    .alu_result_out      (wb_alu_result),
    .read_data_out       (wb_read_data),
    .write_register_out  (wb_write_register),
    .reg_write_out       (wb_reg_write),
    .mem_to_reg_out      (wb_mem_to_reg),
    .pc_plus_4_out       (wb_pc_plus_4),
    .is_jal_out          (wb_is_jal)
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
    .i_pc_plus_4      (wb_pc_plus_4),
    .i_is_jal         (wb_is_jal),
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