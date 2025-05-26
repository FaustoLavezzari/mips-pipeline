// filepath: /home/fausto/mips-pipeline/src/mips/mips.v
`timescale 1ns / 1ps

module mips(
  input  wire       clk,
  input  wire       reset,
  output wire [31:0] result
);

  // Cables para interconectar etapas
  wire [31:0] if_next_pc;
  wire [31:0] if_instr;
  
  wire [31:0] id_next_pc;
  wire [31:0] id_instr;
  
  // Señales de la etapa ID
  wire [31:0] id_read_data_1;
  wire [31:0] id_read_data_2;
  wire [31:0] id_sign_extended_imm;
  wire [4:0]  id_rt;
  wire [4:0]  id_rd;

  // Señales del latch ID/EX
  wire [31:0] ex_read_data_1;
  wire [31:0] ex_read_data_2;
  wire [31:0] ex_sign_extended_imm;
  wire [4:0]  ex_rt;
  wire [4:0]  ex_rd;
  wire [31:0] ex_next_pc;

  // Instancia de la etapa IF (Instruction Fetch)
  if_stage if_stage_inst(
    .clk        (clk),
    .reset      (reset),
    .o_next_pc  (if_next_pc),
    .o_instr    (if_instr)
  );
  
  // Instancia del registro de pipeline IF/ID
  if_id if_id_reg(
    .clk         (clk),
    .reset       (reset),
    .next_pc_in  (if_next_pc),
    .instr_in    (if_instr),
    .next_pc_out (id_next_pc),
    .instr_out   (id_instr)
  );
  
  // Instancia de la etapa ID
  id_stage id_stage_inst(
    .clk              (clk),
    .reset            (reset),
    .i_next_pc        (id_next_pc),
    .i_instruction    (id_instr),
    .i_reg_write      (1'b0), // WB aún no implementado
    .i_write_register (5'b0),
    .i_write_data     (32'b0),
    .o_read_data_1    (id_read_data_1),
    .o_read_data_2    (id_read_data_2),
    .o_sign_extended_imm(id_sign_extended_imm),
    .o_rt             (id_rt),
    .o_rd             (id_rd)
  );

  // Instancia del latch ID/EX
  id_ie id_ie_reg(
    .clk                  (clk),
    .reset                (reset),
    .read_data_1_in       (id_read_data_1),
    .read_data_2_in       (id_read_data_2),
    .sign_extended_imm_in (id_sign_extended_imm),
    .rt_in                (id_rt),
    .rd_in                (id_rd),
    .next_pc_in           (id_next_pc),
    .read_data_1_out      (ex_read_data_1),
    .read_data_2_out      (ex_read_data_2),
    .sign_extended_imm_out(ex_sign_extended_imm),
    .rt_out               (ex_rt),
    .rd_out               (ex_rd),
    .next_pc_out          (ex_next_pc)
  );
  
  // Por ahora, solo hay implementación hasta la etapa ID
  // Otras etapas y conexiones se agregarán posteriormente
  
  // Output temporal
  assign result = 32'h00000000;

endmodule