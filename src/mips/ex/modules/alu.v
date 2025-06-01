`timescale 1ns / 1ps
`include "../../mips_pkg.vh"

module alu(
  input  wire [31:0] a,           // Primer operando
  input  wire [31:0] b,           // Segundo operando
  input  wire [3:0]  alu_control, // Señal de control
  output reg  [31:0] result       // Resultado
);

  // Lógica de la ALU
  always @(*) begin
    case(alu_control)
      `ALU_AND: result = a & b;
      `ALU_OR:  result = a | b;
      `ALU_ADD: result = a + b;
      `ALU_SUB: result = a - b;
      `ALU_SLT: result = ($signed(a) < $signed(b)) ? 32'b1 : 32'b0;
      `ALU_NOR: result = ~(a | b);
      `ALU_XOR: result = a ^ b;
      `ALU_SLL: result = a << b[4:0];
      `ALU_SRL: result = a >> b[4:0];
      default: result = a + b; // Por defecto suma
    endcase
    
    // Debug: mostrar las operaciones OR para facilitar depuración
    if (alu_control == `ALU_OR) begin
      $display("ALU OR: %d | %d = %d", a, b, result);
    end
  end

endmodule
