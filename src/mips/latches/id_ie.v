`timescale 1ns / 1ps
`include "../mips_pkg.vh"

module id_ie(
  input  wire        clk,
  input  wire        reset,
  // Datos de la etapa ID
  input  wire [31:0] read_data_1_in,
  input  wire [31:0] read_data_2_in,
  input  wire [31:0] sign_extended_imm_in,
  input  wire [4:0]  rt_in,
  input  wire [4:0]  rd_in,
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
      read_data_1_out       <= {`DATA_WIDTH{1'b0}};
      read_data_2_out       <= {`DATA_WIDTH{1'b0}};
      sign_extended_imm_out <= {`DATA_WIDTH{1'b0}};
      rt_out                <= {`REG_ADDR_WIDTH{1'b0}};
      rd_out                <= {`REG_ADDR_WIDTH{1'b0}};
      function_out         <= 6'b0;
      
      // Señales de control
      alu_src_out          <= `CTRL_ALU_SRC_REG;
      alu_op_out           <= `ALU_OP_ADD;
      reg_dst_out          <= `CTRL_REG_DST_RT;
      reg_write_out        <= `CTRL_REG_WRITE_DIS;
      mem_read_out         <= 1'b0;
      mem_write_out        <= 1'b0;
      mem_to_reg_out       <= `CTRL_MEM_TO_REG_ALU;
      branch_out           <= `CTRL_BRANCH_DIS;
    end else begin
      // Datos
      read_data_1_out       <= read_data_1_in;
      read_data_2_out       <= read_data_2_in;
      sign_extended_imm_out <= sign_extended_imm_in;
      rt_out                <= rt_in;
      rd_out                <= rd_in;
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

