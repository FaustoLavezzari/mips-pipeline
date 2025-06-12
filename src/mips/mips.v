`timescale 1ns / 1ps
`include "mips_pkg.vh"

module mips(
  input  wire        clk,
  input  wire        reset,
  output wire [31:0] result,
  output wire        halt
);

  // ======== Señales de control de pipeline ========
  wire       pipeline_stall;
  wire       flush_if_id;
  wire       flush_id_ex;
  wire       control_hazard;
  wire       halt_detected;

  // ======== Etapa IF y señales ========
  wire [31:0] if_next_pc;
  wire [31:0] if_instr;
  
  if_stage if_stage_inst(
    .clk                (clk),
    .reset              (reset),
    .i_take_branch      (id_take_branch),
    .i_branch_target_addr(id_branch_target_addr),
    .i_halt             (halt_detected),
    .i_stall            (pipeline_stall),
    .o_next_pc          (if_next_pc),
    .o_instr            (if_instr)
  );

  // ======== Latch IF/ID y señales ========
  wire [31:0] id_next_pc;
  wire [31:0] id_instr;
  
  if_id if_id_latch(
    .clk         (clk),
    .reset       (reset),
    .flush       (flush_if_id),
    .stall       (pipeline_stall),
    .next_pc_in  (if_next_pc),
    .instr_in    (if_instr),
    .next_pc_out (id_next_pc),
    .instr_out   (id_instr)
  );

  // ======== Etapa ID y señales ========
  wire [31:0] id_read_data_1;
  wire [31:0] id_read_data_2;
  wire [31:0] id_sign_extended_imm;
  wire [4:0]  id_rs;
  wire [4:0]  id_rt;
  wire [4:0]  id_rd;
  wire [31:0] id_shamt;
  wire [5:0]  id_function;
  wire [5:0]  id_opcode;
  wire        id_alu_src_b_b;
  wire [2:0]  id_alu_op;
  wire        id_reg_dst;
  wire        id_reg_write;
  wire        id_mem_read;
  wire        id_mem_write;
  wire        id_mem_to_reg;
  wire        id_is_jal;
  wire [31:0] id_branch_target_addr;
  wire        id_take_branch;

  // ID Forwarding señales
  wire        id_use_forwarded_a;
  wire        id_use_forwarded_b;
  wire [31:0] id_forwarded_value_a;
  wire [31:0] id_forwarded_value_b;
  
  id_forwarding id_forwarding_inst(
    .i_id_rs          (id_rs),
    .i_id_rt          (id_rt),
    .i_ex_rd          (ex_write_register),
    .i_ex_reg_write   (ex_reg_write),
    .i_ex_alu_result  (ex_alu_result),
    .i_mem_rd         (mem_write_register),
    .i_mem_reg_write  (mem_reg_write),
    .i_mem_alu_result (mem_alu_result),
    .i_wb_rd          (wb_write_register_out),
    .i_wb_reg_write   (wb_reg_write_out),
    .i_wb_write_data  (wb_write_data),
    .o_use_forwarded_a(id_use_forwarded_a),
    .o_use_forwarded_b(id_use_forwarded_b),
    .o_forwarded_value_a(id_forwarded_value_a),
    .o_forwarded_value_b(id_forwarded_value_b)
  );
  
  id_stage id_stage_inst(
    .clk                (clk),
    .reset              (reset),
    .i_next_pc          (id_next_pc),
    .i_instruction      (id_instr),
    .i_reg_write        (wb_reg_write_out),
    .i_write_register   (wb_write_register_out),
    .i_write_data       (wb_write_data),
    .i_forwarded_value_a(id_forwarded_value_a),
    .i_forwarded_value_b(id_forwarded_value_b),
    .i_use_forwarded_a  (id_use_forwarded_a),
    .i_use_forwarded_b  (id_use_forwarded_b),
    .o_read_data_1      (id_read_data_1),
    .o_read_data_2      (id_read_data_2),
    .o_sign_extended_imm(id_sign_extended_imm),
    .o_rs               (id_rs),
    .o_rt               (id_rt),
    .o_rd               (id_rd),
    .o_shamt            (id_shamt),
    .o_function         (id_function),
    .o_opcode           (id_opcode),
    .o_alu_src_b          (id_alu_src_b),
    .o_alu_op           (id_alu_op),
    .o_reg_dst          (id_reg_dst),
    .o_reg_write        (id_reg_write),
    .o_mem_read         (id_mem_read),
    .o_mem_write        (id_mem_write),
    .o_mem_to_reg       (id_mem_to_reg),
    .o_is_jal           (id_is_jal),
    .o_branch_target_addr(id_branch_target_addr),
    .o_take_branch      (id_take_branch)
  );

  // ======== Unidad de detección de riesgos ========
  hazard_detection hazard_detection_unit(
    .i_if_id_rs            (id_rs),
    .i_if_id_rt            (id_rt),
    .i_id_ex_rt            (ex_rt),
    .i_id_ex_mem_read      (i_ex_mem_read),
    .i_if_id_opcode        (id_opcode),
    .i_if_id_funct         (id_function),
    .i_id_take_branch      (id_take_branch),
    .o_stall              (pipeline_stall),
    .o_flush_id_ex        (flush_id_ex),
    .o_flush_if_id        (flush_if_id),
    .o_ctrl_hazard        (control_hazard),
    .o_halt               (halt_detected)
  );

  // ======== Latch ID/EX y señales ========
  wire [31:0] ex_read_data_1;
  wire [31:0] ex_read_data_2;
  wire [31:0] ex_sign_extended_imm;
  wire [4:0]  ex_rs;
  wire [4:0]  ex_rt;
  wire [4:0]  ex_rd;
  wire [31:0]  ex_shamt;
  wire [5:0]  ex_function;
  wire [5:0]  ex_opcode;
  wire [31:0] ex_next_pc;
  wire        i_ex_alu_src_b;
  wire [2:0]  i_ex_alu_op;
  wire        i_ex_reg_dst;
  wire        i_ex_reg_write;
  wire        i_ex_mem_read;
  wire        i_ex_mem_write;
  wire        i_ex_mem_to_reg;
  wire        i_ex_is_jal;
  wire [31:0] ex_branch_target_addr;
  
  id_ex id_ex_latch(
    .clk                  (clk),
    .reset                (reset),
    .flush                (flush_id_ex),
    .read_data_1_in       (id_read_data_1),
    .read_data_2_in       (id_read_data_2),
    .sign_extended_imm_in (id_sign_extended_imm),
    .rs_in                (id_rs),
    .rt_in                (id_rt),
    .rd_in                (id_rd),
    .shamt_in             (id_shamt),
    .function_in          (id_function),
    .opcode_in            (id_opcode),
    .next_pc_in           (id_next_pc),
    .alu_src_b_in           (id_alu_src_b),
    .alu_op_in            (id_alu_op),
    .reg_dst_in           (id_reg_dst),
    .reg_write_in         (id_reg_write),
    .mem_read_in          (id_mem_read),
    .mem_write_in         (id_mem_write),
    .mem_to_reg_in        (id_mem_to_reg),
    .is_jal_in            (id_is_jal),
    .read_data_1_out      (ex_read_data_1),
    .read_data_2_out      (ex_read_data_2),
    .sign_extended_imm_out(ex_sign_extended_imm),
    .rs_out               (ex_rs),
    .rt_out               (ex_rt),
    .rd_out               (ex_rd),
    .shamt_out            (ex_shamt),
    .function_out         (ex_function),
    .opcode_out           (ex_opcode),
    .next_pc_out          (ex_next_pc),
    .alu_src_b_out          (i_ex_alu_src_b),
    .alu_op_out           (i_ex_alu_op),
    .reg_dst_out          (i_ex_reg_dst),
    .reg_write_out        (i_ex_reg_write),
    .mem_read_out         (i_ex_mem_read),
    .mem_write_out        (i_ex_mem_write),
    .mem_to_reg_out       (i_ex_mem_to_reg),
    .is_jal_out           (i_ex_is_jal)
  );

  // ======== EX Forwarding y señales ========
  wire        ex_use_forwarded_a;
  wire        ex_use_forwarded_b;
  wire [31:0] ex_forwarded_value_a;
  wire [31:0] ex_forwarded_value_b;
  
  forwarding_unit forwarding_ex_inst(
    .i_ex_rs          (ex_rs),
    .i_ex_rt          (ex_rt),
    .i_mem_rd         (mem_write_register),
    .i_mem_reg_write  (mem_reg_write),
    .i_mem_result     (mem_alu_result),
    .i_wb_rd          (wb_write_register_out),
    .i_wb_reg_write   (wb_reg_write_out),
    .i_wb_result      (wb_write_data),
    .o_use_forwarded_a(ex_use_forwarded_a),
    .o_use_forwarded_b(ex_use_forwarded_b),
    .o_forwarded_value_a(ex_forwarded_value_a),
    .o_forwarded_value_b(ex_forwarded_value_b)
  );

  // ======== Etapa EX y señales de salida ========
  wire [31:0] ex_alu_result;
  wire [31:0] ex_write_data;
  wire [4:0]  ex_write_register;
  wire        ex_reg_write;
  wire        ex_mem_read;
  wire        ex_mem_write;
  wire        ex_mem_to_reg;
  
  ex_stage ex_stage_inst(
    .clk                 (clk),
    .reset               (reset),
    .i_read_data_1       (ex_read_data_1),
    .i_read_data_2       (ex_read_data_2),
    .i_sign_extended_imm (ex_sign_extended_imm),
    .i_function          (ex_function),
    .i_rs                (ex_rs),
    .i_rt                (ex_rt),
    .i_rd                (ex_rd),
    .i_shamt             (ex_shamt),
    .i_opcode            (ex_opcode),
    .i_next_pc           (ex_next_pc),
    .i_forwarded_value_a (ex_forwarded_value_a),
    .i_forwarded_value_b (ex_forwarded_value_b),
    .i_use_forwarded_a   (ex_use_forwarded_a),
    .i_use_forwarded_b   (ex_use_forwarded_b),
    .i_alu_src_b           (i_ex_alu_src_b),
    .i_alu_op            (i_ex_alu_op),
    .i_reg_dst           (i_ex_reg_dst),
    .i_reg_write         (i_ex_reg_write),
    .i_mem_read          (i_ex_mem_read),
    .i_mem_write         (i_ex_mem_write),
    .i_mem_to_reg        (i_ex_mem_to_reg),
    .i_is_jal            (i_ex_is_jal),
    .o_alu_result        (ex_alu_result),
    .o_read_data_2       (ex_write_data),
    .o_write_register    (ex_write_register),
    .o_reg_write         (ex_reg_write),
    .o_mem_read          (ex_mem_read),
    .o_mem_write         (ex_mem_write),
    .o_mem_to_reg        (ex_mem_to_reg)
  );

  // ======== Latch EX/MEM y señales ========
  wire [31:0] mem_alu_result;
  wire [31:0] mem_write_data;
  wire [4:0]  mem_write_register;
  wire        mem_reg_write;
  wire        mem_mem_read;
  wire        mem_mem_write;
  wire        mem_mem_to_reg;
  wire [5:0]  mem_opcode;
  
  ex_mem ex_mem_latch(
    .clk                 (clk),
    .reset               (reset),
    .flush               (1'b0),
    .alu_result_in       (ex_alu_result),
    .read_data_2_in      (ex_write_data),
    .write_register_in   (ex_write_register),
    .reg_write_in        (ex_reg_write),
    .mem_read_in         (ex_mem_read),
    .mem_write_in        (ex_mem_write),
    .mem_to_reg_in       (ex_mem_to_reg),
    .opcode_in           (ex_opcode),
    .alu_result_out      (mem_alu_result),
    .read_data_2_out     (mem_write_data),
    .write_register_out  (mem_write_register),
    .reg_write_out       (mem_reg_write),
    .mem_read_out        (mem_mem_read),
    .mem_write_out       (mem_mem_write),
    .mem_to_reg_out      (mem_mem_to_reg),
    .opcode_out          (mem_opcode)
  );

  // ======== Etapa MEM y señales de salida ========
  wire [31:0] mem_read_data;
  wire [31:0] mem_alu_result_out;
  wire [4:0]  mem_write_register_out;
  wire        mem_reg_write_out;
  wire        mem_mem_to_reg_out;
  
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
    .opcode_in        (mem_opcode),
    .read_data_out    (mem_read_data),
    .alu_result_out   (mem_alu_result_out),
    .write_register_out(mem_write_register_out),
    .reg_write_out    (mem_reg_write_out),
    .mem_to_reg_out   (mem_mem_to_reg_out)
  );

  // ======== Latch MEM/WB y señales ========
  wire [31:0] wb_alu_result;
  wire [31:0] wb_read_data;
  wire [4:0]  wb_write_register;
  wire        wb_reg_write;
  wire        wb_mem_to_reg;
  
  mem_wb mem_wb_latch(
    .clk                 (clk),
    .reset               (reset),
    .flush               (1'b0),
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

  // ======== Etapa WB y señales de salida ========
  wire [31:0] wb_write_data;
  wire [4:0]  wb_write_register_out;
  wire        wb_reg_write_out;
  
  wb_stage wb_stage_inst(
    .clk              (clk),
    .reset            (reset),
    .i_alu_result     (wb_alu_result),
    .i_read_data      (wb_read_data),
    .i_write_register (wb_write_register),
    .i_reg_write      (wb_reg_write),
    .i_mem_to_reg     (wb_mem_to_reg),
    .o_write_data     (wb_write_data),
    .o_write_register (wb_write_register_out),
    .o_reg_write      (wb_reg_write_out)
  );

  // ======== Salidas del módulo ========
  assign result = wb_write_data;
  assign halt = halt_detected;

endmodule
