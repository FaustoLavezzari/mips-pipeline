`timescale 1ns / 1ps

module alu(
  input  wire [31:0] a,           // Primer operando
  input  wire [31:0] b,           // Segundo operando
  input  wire [3:0]  alu_control, // Señal de control
  output reg  [31:0] result       // Resultado
);

  // Definición de las operaciones ALU
  localparam ALU_AND = 4'b0000;
  localparam ALU_OR  = 4'b0001;
  localparam ALU_ADD = 4'b0010;
  localparam ALU_SUB = 4'b0110;
  localparam ALU_SLT = 4'b0111;
  localparam ALU_NOR = 4'b1100;
  localparam ALU_XOR = 4'b1101;
  localparam ALU_SLL = 4'b1000;
  localparam ALU_SRL = 4'b1001;

  // Lógica de la ALU
  always @(*) begin
    case(alu_control)
      ALU_AND: result = a & b;
      ALU_OR:  result = a | b;
      ALU_ADD: result = a + b;
      ALU_SUB: result = a - b;
      ALU_SLT: result = ($signed(a) < $signed(b)) ? 32'b1 : 32'b0;
      ALU_NOR: result = ~(a | b);
      ALU_XOR: result = a ^ b;
      ALU_SLL: result = a << b[4:0];
      ALU_SRL: result = a >> b[4:0];
      default: result = a + b; // Por defecto suma
    endcase
  end

endmodule
