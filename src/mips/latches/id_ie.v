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
  // Salidas hacia la etapa EX
  output reg  [31:0] read_data_1_out,
  output reg  [31:0] read_data_2_out,
  output reg  [31:0] sign_extended_imm_out,
  output reg  [4:0]  rt_out,
  output reg  [4:0]  rd_out,
  output reg  [31:0] next_pc_out
);
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      read_data_1_out       <= 0;
      read_data_2_out       <= 0;
      sign_extended_imm_out <= 0;
      rt_out                <= 0;
      rd_out                <= 0;
      next_pc_out          <= 0;
    end else begin
      read_data_1_out       <= read_data_1_in;
      read_data_2_out       <= read_data_2_in;
      sign_extended_imm_out <= sign_extended_imm_in;
      rt_out                <= rt_in;
      rd_out                <= rd_in;
      next_pc_out          <= next_pc_in;
    end
  end
endmodule

