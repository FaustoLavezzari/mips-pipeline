`timescale 1ns / 1ps

module alu_control(
  input  wire [5:0] func_code,   // Campo function de la instrucción
  input  wire [1:0] alu_op,      // Señal de control de la ALU del control principal
  output reg  [3:0] alu_control  // Señal de control para la ALU
);

  // Definición de códigos de operación ALU
  localparam ALU_AND = 4'b0000;
  localparam ALU_OR  = 4'b0001;
  localparam ALU_ADD = 4'b0010;
  localparam ALU_SUB = 4'b0110;
  localparam ALU_SLT = 4'b0111;
  localparam ALU_NOR = 4'b1100;
  localparam ALU_XOR = 4'b1101;
  localparam ALU_SLL = 4'b1000;
  localparam ALU_SRL = 4'b1001;

  always @(*) begin
    // Por defecto, hacer una suma (para ADDI, LW, SW)
    alu_control = ALU_ADD;
    
    case(alu_op)
      2'b01: // BEQ, BNE - siempre resta (para comparar)
        alu_control = ALU_SUB;
        
      2'b10: // Instrucciones R-type - depende del campo function
        case(func_code)
          6'b100000: alu_control = ALU_ADD; // ADD
          6'b100010: alu_control = ALU_SUB; // SUB
          6'b100100: alu_control = ALU_AND; // AND
          6'b100101: alu_control = ALU_OR;  // OR
          6'b100111: alu_control = ALU_NOR; // NOR
          6'b101010: alu_control = ALU_SLT; // SLT
          6'b000000: alu_control = ALU_SLL; // SLL
          6'b000010: alu_control = ALU_SRL; // SRL
          default:   alu_control = ALU_ADD;
        endcase
        
      default: // ADDI y otras instrucciones que usan suma
        alu_control = ALU_ADD;
    endcase
  end

endmodule
