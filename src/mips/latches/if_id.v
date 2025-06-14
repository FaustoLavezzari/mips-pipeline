`timescale 1ns / 1ps
`include "../mips_pkg.vh"

module if_id(
  input  wire        clk,
  input  wire        reset,
  input  wire        flush,       // Señal para invalidar el latch (en caso de predicción incorrecta)
  input  wire        stall,       // Señal de control para el stall
  input  wire [31:0] next_pc_in,  // PC+4 de la etapa IF
  input  wire [31:0] instr_in,    // Instrucción de la etapa IF
  output reg  [31:0] next_pc_out, // PC+4 a la etapa ID
  output reg  [31:0] instr_out    // Instrucción a la etapa ID
);

  always @(posedge clk) begin
    if (reset || flush) begin
      next_pc_out <= 32'b0;
      instr_out   <= 32'b0;
    end 
    else if (!stall) begin
      next_pc_out <= next_pc_in;
      instr_out   <= instr_in;
    end
  end

endmodule
