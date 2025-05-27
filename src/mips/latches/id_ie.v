// filepath: /home/fausto/mips-pipeline/src/mips/latches/id_ie.v
`timescale 1ns / 1ps

module id_ie(
  input  wire        clk,
  input  wire        reset,
  // Datos de la etapa ID
  input  wire [31:0] read_data_1_in,
  input  wire [31:0] read_data_2_in,
  input  wire [31:0] sign_extended_imm_in,
  input  wire [4:0]  rt_in,
  input  wire [4:0]  rd_in,
  input  wire [31:0] next_pc_in,
  input  wire [5:0]  function_in,
  
  // Señales de control de ID
  input  wire        alu_src_in,
  input  wire [1:0]  alu_op_in,
  input  wire        reg_dst_in,
  input  wire        reg_write_in,
  input  wire        mem_read_in,
  input  wire        mem_write_in,
  input  wire        mem_to_reg_in,
  input  wire        branch_in,
  
  // Salidas hacia la etapa EX
  output reg  [31:0] read_data_1_out,
  output reg  [31:0] read_data_2_out,
  output reg  [31:0] sign_extended_imm_out,
  output reg  [4:0]  rt_out,
  output reg  [4:0]  rd_out,
  output reg  [31:0] next_pc_out,
  output reg  [5:0]  function_out,
  
  // Señales de control hacia EX
  output reg         alu_src_out,
  output reg  [1:0]  alu_op_out,
  output reg         reg_dst_out,
  output reg         reg_write_out,
  output reg         mem_read_out,
  output reg         mem_write_out,
  output reg         mem_to_reg_out,
  output reg         branch_out
);
  always @(posedge clk) begin
    if (reset) begin
      // Datos
      read_data_1_out       <= 0;
      read_data_2_out       <= 0;
      sign_extended_imm_out <= 0;
      rt_out                <= 0;
      rd_out                <= 0;
      next_pc_out          <= 0;
      function_out         <= 0;
      
      // Señales de control
      alu_src_out          <= 0;
      alu_op_out           <= 0;
      reg_dst_out          <= 0;
      reg_write_out        <= 0;
      mem_read_out         <= 0;
      mem_write_out        <= 0;
      mem_to_reg_out       <= 0;
      branch_out           <= 0;
    end else begin
      // Datos
      read_data_1_out       <= read_data_1_in;
      read_data_2_out       <= read_data_2_in;
      sign_extended_imm_out <= sign_extended_imm_in;
      rt_out                <= rt_in;
      rd_out                <= rd_in;
      next_pc_out          <= next_pc_in;
      function_out         <= function_in;
      
      // Señales de control
      alu_src_out         <= alu_src_in;
      alu_op_out          <= alu_op_in;
      reg_dst_out         <= reg_dst_in;
      reg_write_out       <= reg_write_in;
      mem_read_out        <= mem_read_in;
      mem_write_out       <= mem_write_in;
      mem_to_reg_out      <= mem_to_reg_in;
      branch_out          <= branch_in;
    end
  end
endmodule

