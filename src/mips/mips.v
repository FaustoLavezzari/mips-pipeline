`timescale 1ns / 1ps
`include "mips_pkg.vh"

module mips(
  input  wire        clk,
  input  wire        reset,
  output wire [31:0] result
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
  
  wire [31:0] mem_alu_result;
  wire [31:0] mem_write_data;
  wire [4:0]  mem_write_register;
  wire        mem_reg_write;
  wire        mem_mem_read;
  wire        mem_mem_write;
  wire        mem_mem_to_reg;
  wire [31:0] mem_read_data;
  
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
    .o_next_pc          (if_next_pc),
    .o_instr            (if_instr)
  );
  
  // ========== Instancia del registro IF/ID ==========
  if_id if_id_reg(
    .clk         (clk),
    .reset       (reset),
    .flush       (ex_mispredicted),   // Flush cuando hay una predicción incorrecta
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
    .flush                (ex_mispredicted), // Conectar la señal de flush a ex_mispredicted
    .read_data_1_in       (id_read_data_1),
    .read_data_2_in       (id_read_data_2),
    .sign_extended_imm_in (id_sign_extended_imm),
    .rs_in                (id_rs),            // Registro RS para forwarding
    .rt_in                (id_rt),
    .rd_in                (id_rd),
    .function_in          (id_function),
    .opcode_in            (id_opcode),
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
    .o_mispredicted      (ex_mispredicted)
  );
  
  // ========== Instancia del latch EX/MEM ==========
  ex_mem ex_mem_reg(
    .clk                 (clk),
    .reset               (reset),
    .alu_result_in       (ex_alu_result),
    .read_data_2_in      (ex_write_data),
    .write_register_in   (ex_write_register),
    .reg_write_in        (ex_reg_write),      // Usando salida de EX stage
    .mem_read_in         (ex_mem_read),       // Usando salida de EX stage
    .mem_write_in        (ex_mem_write),      // Usando salida de EX stage
    .mem_to_reg_in       (ex_mem_to_reg),     // Usando salida de EX stage
    .alu_result_out      (mem_alu_result),
    .read_data_2_out     (mem_write_data),
    .write_register_out  (mem_write_register),
    .reg_write_out       (mem_reg_write),
    .mem_read_out        (mem_mem_read),
    .mem_write_out       (mem_mem_write),
    .mem_to_reg_out      (mem_mem_to_reg)
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

endmodule