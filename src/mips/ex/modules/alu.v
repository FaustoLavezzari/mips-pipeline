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
      `ALU_SLTU: result = (a < b) ? 32'b1 : 32'b0; // Comparación sin signo
      `ALU_NOR: result = ~(a | b);
      `ALU_XOR: result = a ^ b;
      `ALU_SLL: result = b << a[4:0]; // b (rt) desplazado por a[4:0] (shamt)
      `ALU_SRL: begin
        result = b >> a[4:0]; // b (rt) desplazado por a[4:0] (shamt)
        $display("ALU SRL: b=%d, a[4:0]=%d, result=%d", b, a[4:0], result);
      end
      `ALU_SRA: begin
        result = $signed(b) >>> a[4:0]; // Desplazamiento aritmético a la derecha
        $display("ALU SRA: b=%d, a[4:0]=%d, result=%d", $signed(b), a[4:0], result);
      end
      default: result = a + b; // Por defecto suma
    endcase
    
  end

endmodule
