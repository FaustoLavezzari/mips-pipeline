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
      `ALU_AND:      result = a & b;
      `ALU_OR:       result = a | b;
      `ALU_ADD:      result = $signed(a) + $signed(b);  
      `ALU_ADDU:     result = a + b;                  
      `ALU_SUB:      result = $signed(a) - $signed(b);  
      `ALU_SUBU:     result = a - b;                   
      `ALU_SLT:      result = ($signed(a) < $signed(b)) ? 32'b1 : 32'b0;
      `ALU_SLTU:     result = (a < b) ? 32'b1 : 32'b0; 
      `ALU_NOR:      result = ~(a | b);
      `ALU_XOR:      result = a ^ b;
      `ALU_SLL:      result = b << a[4:0]; 
      `ALU_SRL:      result = b >> a[4:0]; 
      `ALU_SRA:      result = $signed(b) >>> a[4:0];
      `ALU_LUI:      result = {b[15:0], 16'b0}; 
      `ALU_BYPASS_A: result = a;           
      default:       result = a + b; // Por defecto suma (unsigned)
    endcase
    
  end

endmodule
