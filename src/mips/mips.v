`timescale 1ns / 1ps
`include "mips_pkg.vh"

module mips(
  input  wire        clk,
  input  wire        reset,
  input  wire        stall,
  // Nuevos puertos para escritura de instrucciones
  input  wire        inst_write_en,        // Habilitar escritura de instrucción
  input  wire [31:0] inst_write_addr,      // Dirección a escribir
  input  wire [31:0] inst_write_data,      // Datos a escribir (instrucción)

  output wire        halt,

  // Debug register ports
  input  wire [4:0]  reg_addr,
  output wire [31:0] reg_data,
  // Debug memory ports
  input  wire [31:0] mem_debug_addr,
  output wire [31:0] mem_debug_data,
  
  // Debug latch signals - IF/ID
  output wire [31:0] debug_if_id_instr,
  output wire [31:0] debug_if_id_next_pc,
  
  // Debug latch signals - ID/EX
  output wire [31:0] debug_id_ex_read_data1,
  output wire [31:0] debug_id_ex_read_data2,
  output wire [31:0] debug_id_ex_sign_ext_imm,
  output wire [4:0]  debug_id_ex_rs,
  output wire [4:0]  debug_id_ex_rt,
  output wire [4:0]  debug_id_ex_rd,
  output wire [31:0] debug_id_ex_shamt,
  output wire [31:0] debug_id_ex_next_pc,
  output wire        debug_id_ex_reg_dst,
  output wire        debug_id_ex_alu_src_b,
  output wire [1:0]  debug_id_ex_alu_src_a,
  output wire [3:0]  debug_id_ex_alu_control,
  output wire        debug_id_ex_mem_read,
  output wire        debug_id_ex_mem_write,
  output wire        debug_id_ex_reg_write,
  output wire        debug_id_ex_mem_to_reg,
  output wire        debug_id_ex_is_halt,
  output wire [3:0]  debug_id_ex_byte_mask,
  output wire        debug_id_ex_is_signed_load,
  
  // Debug latch signals - EX/MEM
  output wire [31:0] debug_ex_mem_alu_result,
  output wire [31:0] debug_ex_mem_write_data,
  output wire [4:0]  debug_ex_mem_write_reg,
  output wire        debug_ex_mem_reg_write,
  output wire        debug_ex_mem_mem_read,
  output wire        debug_ex_mem_mem_write,
  output wire        debug_ex_mem_mem_to_reg,
  output wire        debug_ex_mem_is_halt,
  output wire [3:0]  debug_ex_mem_byte_mask,
  output wire        debug_ex_mem_is_signed_load,
  
  // Debug latch signals - MEM/WB
  output wire [31:0] debug_mem_wb_write_data,
  output wire [4:0]  debug_mem_wb_write_reg,
  output wire        debug_mem_wb_reg_write,
  output wire        debug_mem_wb_is_halt
);

  // ======== Señales de control de pipeline ========
  wire       flush_if_id;
  wire       flush_id_ex;
  wire       stall_first_half;
  wire       stall_second_half;
  wire       halt_detected;
  wire       end_program;

  // ======== Etapa IF y señales ========
  wire [31:0] if_next_pc;
  wire [31:0] if_instr;
  
  if_stage if_stage_inst(
    .clk                 (clk),
    .reset               (reset),
    .i_take_branch       (id_take_branch),
    .i_branch_target_addr(id_branch_target_addr),
    .i_stall             (stall_first_half),
    .i_inst_write_en     (inst_write_en),      // Pasar señal de escritura
    .i_inst_write_addr   (inst_write_addr),    // Pasar dirección de escritura
    .i_inst_write_data   (inst_write_data),    // Pasar datos a escribir
    .o_next_pc           (if_next_pc),
    .o_instr             (if_instr)
  );

  // ======== Latch IF/ID y señales ========
  wire [31:0] id_next_pc;
  wire [31:0] id_instr;
  
  if_id if_id_latch(
    .clk         (clk),
    .reset       (reset),
    .flush       (flush_if_id),
    .stall       (stall_first_half),
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
  wire        id_alu_src_b;
  wire [3:0]  id_alu_control;
  wire [1:0]  id_alu_src_a;
  wire        id_reg_dst;
  wire        id_reg_write;
  wire        id_mem_read;
  wire        id_mem_write;
  wire        id_mem_to_reg;
  wire [3:0]  id_byte_mask;
  wire [31:0] id_branch_target_addr;
  wire        id_take_branch;
  wire [5:0]  id_opcode;
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
    .i_mem_write_data (mem_write_data_out),
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
    .i_debug_reg        (reg_addr),
    .o_debug_reg_value  (reg_data),
    .o_read_data_1      (id_read_data_1),
    .o_read_data_2      (id_read_data_2),
    .o_sign_extended_imm(id_sign_extended_imm),
    .o_rs               (id_rs),
    .o_rt               (id_rt),
    .o_rd               (id_rd),
    .o_shamt            (id_shamt),
    .o_opcode           (id_opcode),
    .o_alu_src_b        (id_alu_src_b),
    .o_alu_control      (id_alu_control),
    .o_alu_src_a        (id_alu_src_a),
    .o_reg_dst          (id_reg_dst),
    .o_reg_write        (id_reg_write),
    .o_mem_read         (id_mem_read),
    .o_mem_write        (id_mem_write),
    .o_mem_to_reg       (id_mem_to_reg),
    .o_byte_mask        (id_byte_mask),
    .o_is_signed_load   (id_is_signed_load),
    .o_branch_target_addr(id_branch_target_addr),
    .o_take_branch      (id_take_branch)
  );

  // El opcode ahora viene directamente de la etapa ID

  // ======== Unidad de detección de riesgos ========
  hazard_detection hazard_detection_unit(
    .i_if_id_rs            (id_rs),
    .i_if_id_rt            (id_rt),
    .i_id_ex_rt            (ex_rt),
    .i_id_ex_mem_read      (ex_mem_read),
    .i_if_id_opcode        (id_opcode),
    .i_id_take_branch      (id_take_branch),
    .i_total_stall         (stall),
    .o_flush_id_ex        (flush_id_ex),
    .o_flush_if_id        (flush_if_id),
    .o_stall_first_half    (stall_first_half),
    .o_stall_second_half   (stall_second_half),
    .o_halt               (halt_detected)
  );

  // ======== Latch ID/EX y señales ========
  wire [31:0] ex_read_data_1;
  wire [31:0] ex_read_data_2;
  wire [31:0] ex_sign_extended_imm;
  wire [4:0]  ex_rs;
  wire [4:0]  ex_rt;
  wire [4:0]  ex_rd;
  wire [31:0] ex_shamt;
  wire [31:0] ex_next_pc;
  wire [3:0]  ex_alu_control;
  wire        i_ex_is_halt;
  wire        i_ex_alu_src_b;
  wire [1:0]  i_ex_alu_src_a;
  wire        i_ex_reg_dst;
  wire        i_ex_reg_write;
  wire        i_ex_mem_read;
  wire        i_ex_mem_write;
  wire        i_ex_mem_to_reg;
  wire [3:0]  i_ex_byte_mask;
  wire        id_is_signed_load;
  wire        i_ex_is_signed_load;
  
  id_ex id_ex_latch(
    .clk                  (clk),
    .reset                (reset),
    .flush                (flush_id_ex),
    .stall                (stall_second_half),
    .read_data_1_in       (id_read_data_1),
    .read_data_2_in       (id_read_data_2),
    .sign_extended_imm_in (id_sign_extended_imm),
    .rs_in                (id_rs),
    .rt_in                (id_rt),
    .rd_in                (id_rd),
    .shamt_in             (id_shamt),
    .next_pc_in           (id_next_pc),
    .alu_control_in       (id_alu_control),
    .alu_src_b_in         (id_alu_src_b),
    .alu_src_a_in         (id_alu_src_a),
    .reg_dst_in           (id_reg_dst),
    .reg_write_in         (id_reg_write),
    .mem_read_in          (id_mem_read),
    .mem_write_in         (id_mem_write),
    .mem_to_reg_in        (id_mem_to_reg),
    .is_halt_in           (halt_detected),
    .byte_mask_in         (id_byte_mask),
    .is_signed_load_in    (id_is_signed_load),
    .read_data_1_out      (ex_read_data_1),
    .read_data_2_out      (ex_read_data_2),
    .sign_extended_imm_out(ex_sign_extended_imm),
    .rs_out               (ex_rs),
    .rt_out               (ex_rt),
    .rd_out               (ex_rd),
    .shamt_out            (ex_shamt),
    .next_pc_out          (ex_next_pc),
    .alu_control_out      (ex_alu_control),
    .alu_src_b_out        (i_ex_alu_src_b),
    .alu_src_a_out        (i_ex_alu_src_a),
    .reg_dst_out          (i_ex_reg_dst),
    .reg_write_out        (i_ex_reg_write),
    .mem_read_out         (i_ex_mem_read),
    .mem_write_out        (i_ex_mem_write),
    .mem_to_reg_out       (i_ex_mem_to_reg),
    .is_halt_out          (i_ex_is_halt),
    .byte_mask_out        (i_ex_byte_mask),
    .is_signed_load_out   (i_ex_is_signed_load)
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
  wire        ex_is_halt;
  wire [3:0]  ex_byte_mask;
  
  ex_stage ex_stage_inst(
    .clk                 (clk),
    .reset               (reset),
    .i_read_data_1       (ex_read_data_1),
    .i_read_data_2       (ex_read_data_2),
    .i_sign_extended_imm (ex_sign_extended_imm),
    .i_rs                (ex_rs),
    .i_rt                (ex_rt),
    .i_rd                (ex_rd),
    .i_shamt             (ex_shamt),
    .i_next_pc           (ex_next_pc),
    .i_forwarded_value_a (ex_forwarded_value_a),
    .i_forwarded_value_b (ex_forwarded_value_b),
    .i_use_forwarded_a   (ex_use_forwarded_a),
    .i_use_forwarded_b   (ex_use_forwarded_b),
    .i_alu_src_b         (i_ex_alu_src_b),
    .i_alu_src_a         (i_ex_alu_src_a),
    .i_reg_dst           (i_ex_reg_dst),
    .i_reg_write         (i_ex_reg_write),
    .i_mem_read          (i_ex_mem_read),
    .i_mem_write         (i_ex_mem_write),
    .i_mem_to_reg        (i_ex_mem_to_reg),
    .i_is_halt           (i_ex_is_halt),
    .i_byte_mask         (i_ex_byte_mask),
    .i_is_signed_load    (i_ex_is_signed_load),
    .i_alu_control       (ex_alu_control),
    .o_alu_result        (ex_alu_result),
    .o_read_data_2       (ex_write_data),
    .o_write_register    (ex_write_register),
    .o_reg_write         (ex_reg_write),
    .o_mem_read          (ex_mem_read),
    .o_mem_write         (ex_mem_write),
    .o_byte_mask         (ex_byte_mask),
    .o_mem_to_reg        (ex_mem_to_reg),
    .o_is_halt           (ex_is_halt),
    .o_is_signed_load    (ex_is_signed_load)
  );

  // ======== Latch EX/MEM y señales ========
  wire [31:0] mem_alu_result;
  wire [31:0] mem_write_data;
  wire [4:0]  mem_write_register;
  wire        mem_reg_write;
  wire        mem_mem_read;
  wire        mem_mem_write;
  wire        mem_mem_to_reg;
  wire [3:0]  mem_byte_mask;
  wire [5:0]  mem_opcode;
  wire        mem_is_halt;
  wire        mem_is_signed_load;
  
  ex_mem ex_mem_latch(
    .clk                 (clk),
    .reset               (reset),
    .stall               (stall_second_half),
    .alu_result_in       (ex_alu_result),
    .read_data_2_in      (ex_write_data),
    .write_register_in   (ex_write_register),
    .reg_write_in        (ex_reg_write),
    .mem_read_in         (ex_mem_read),
    .mem_write_in        (ex_mem_write),
    .mem_to_reg_in       (ex_mem_to_reg),
    .is_halt_in          (ex_is_halt),
    .byte_mask_in        (ex_byte_mask),
    .is_signed_load_in   (ex_is_signed_load),
    .alu_result_out      (mem_alu_result),
    .read_data_2_out     (mem_write_data),
    .write_register_out  (mem_write_register),
    .reg_write_out       (mem_reg_write),
    .mem_read_out        (mem_mem_read),
    .mem_write_out       (mem_mem_write),
    .mem_to_reg_out      (mem_mem_to_reg),
    .byte_mask_out       (mem_byte_mask),
    .is_halt_out         (mem_is_halt),
    .is_signed_load_out  (mem_is_signed_load)
  );

  // ======== Etapa MEM y señales de salida ========
  wire [31:0] mem_write_data_out;
  wire [31:0] mem_alu_result_out;
  wire [4:0]  mem_write_register_out;
  wire        mem_reg_write_out;
  wire        mem_mem_to_reg_out;
  wire        mem_is_halt_out;
  
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
    .is_halt_in       (mem_is_halt),
    .byte_mask_in     (mem_byte_mask),
    .is_signed_load_in(mem_is_signed_load),
    .i_debug_addr     (mem_debug_addr),
    .o_debug_data     (mem_debug_data),
    .write_data_out   (mem_write_data_out),
    .write_register_out(mem_write_register_out),
    .reg_write_out    (mem_reg_write_out),
    .is_halt_out      (mem_is_halt_out)
  );

  // ======== Latch MEM/WB y señales ========
  wire [31:0] wb_write_data_i;
  wire [4:0]  wb_write_register;
  wire        wb_reg_write;
  wire        wb_is_halt;

  mem_wb mem_wb_latch(
    .clk                 (clk),
    .reset               (reset),
    .stall               (stall_second_half),
    .write_register_in   (mem_write_register_out),
    .is_halt_in          (mem_is_halt_out),
    .reg_write_in        (mem_reg_write_out),
    .write_data_in       (mem_write_data_out),
    .write_data_out      (wb_write_data),
    .write_register_out  (wb_write_register),
    .reg_write_out       (wb_reg_write),
    .is_halt_out         (wb_is_halt)
  );

  // ======== Etapa WB y señales de salida ========
  wire [31:0] wb_write_data;
  wire [4:0]  wb_write_register_out;
  wire        wb_reg_write_out;
  
  wb_stage wb_stage_inst(
    .clk              (clk),
    .reset            (reset),
    .i_write_data     (wb_write_data_i),
    .i_write_register (wb_write_register),
    .i_reg_write      (wb_reg_write),
    .i_is_halt        (wb_is_halt),
    .o_write_data     (wb_write_data),
    .o_write_register (wb_write_register_out),
    .o_reg_write      (wb_reg_write_out),
    .o_is_halt        (end_program)
  );


  assign halt = end_program;
  
  // ======== Conexión de señales de debug para los latches ========
  // IF/ID
  assign debug_if_id_instr   = if_instr;   // id_instr
  assign debug_if_id_next_pc = if_next_pc; // id_next_pc
  
  // ID/EX
  assign debug_id_ex_read_data1     = id_read_data_1;       // ex_read_data_1
  assign debug_id_ex_read_data2     = id_read_data_2;       // ex_read_data_2
  assign debug_id_ex_sign_ext_imm   = id_sign_extended_imm; // ex_sign_extended_imm
  assign debug_id_ex_rs             = id_rs;                // ex_rs
  assign debug_id_ex_rt             = id_rt;                // ex_rt
  assign debug_id_ex_rd             = id_rd;                // ex_rd
  assign debug_id_ex_shamt          = id_shamt;             // ex_shamt
  assign debug_id_ex_next_pc        = id_next_pc;           // ex_next_pc
  assign debug_id_ex_reg_dst        = id_reg_dst;           // i_ex_reg_dst
  assign debug_id_ex_alu_src_b      = id_alu_src_b;         // i_ex_alu_src_b
  assign debug_id_ex_alu_src_a      = id_alu_src_a;         // i_ex_alu_src_a
  assign debug_id_ex_alu_control    = id_alu_control;       // ex_alu_control
  assign debug_id_ex_mem_read       = id_mem_read;          // i_ex_mem_read
  assign debug_id_ex_mem_write      = id_mem_write;         // i_ex_mem_write
  assign debug_id_ex_reg_write      = id_reg_write;         // i_ex_reg_write
  assign debug_id_ex_mem_to_reg     = id_mem_to_reg;        // i_ex_mem_to_reg
  assign debug_id_ex_is_halt        = halt_detected;        // i_ex_is_halt
  assign debug_id_ex_byte_mask      = id_byte_mask;         // i_ex_byte_mask
  assign debug_id_ex_is_signed_load = id_is_signed_load;    // i_ex_is_signed_load

  // EX/MEM
  assign debug_ex_mem_alu_result     = ex_alu_result;     // mem_alu_result
  assign debug_ex_mem_write_data     = ex_write_data;     // mem_write_data
  assign debug_ex_mem_write_reg      = ex_write_register; // mem_write_register
  assign debug_ex_mem_reg_write      = ex_reg_write;      // mem_reg_write
  assign debug_ex_mem_mem_read       = ex_mem_read;       // mem_mem_read
  assign debug_ex_mem_mem_write      = ex_mem_write;      // mem_mem_write
  assign debug_ex_mem_mem_to_reg     = ex_mem_to_reg;     // mem_mem_to_reg
  assign debug_ex_mem_is_halt        = ex_is_halt;        // mem_is_halt
  assign debug_ex_mem_byte_mask      = ex_byte_mask;      // mem_byte_mask
  assign debug_ex_mem_is_signed_load = ex_is_signed_load; // mem_is_signed_load
  
  // MEM/WB
  assign debug_mem_wb_write_data = mem_write_data_out;     // wb_write_data
  assign debug_mem_wb_write_reg  = mem_write_register_out; // wb_write_register
  assign debug_mem_wb_reg_write  = mem_reg_write_out;      // wb_reg_write
  assign debug_mem_wb_is_halt    = mem_is_halt_out;        // wb_is_halt

endmodule
