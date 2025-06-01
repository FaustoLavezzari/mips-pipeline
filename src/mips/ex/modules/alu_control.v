`timescale 1ns / 1ps
`include "../../mips_pkg.vh"

module alu_control(
  input  wire [5:0] func_code,   // Campo function de la instrucción
  input  wire [1:0] alu_op,      // Señal de control de la ALU del control principal
  output reg  [3:0] alu_control  // Señal de control para la ALU
);

  always @(*) begin
    // Asignación predeterminada inicial
    alu_control = `ALU_ADD;
    
    case(alu_op)
      `ALU_OP_SUB: // BEQ, BNE - siempre resta (para comparar)
        alu_control = `ALU_SUB;

      `ALU_OP_RTYPE: begin // Instrucciones R-type - depende del campo function
        case(func_code)
          `FUNC_ADD:  alu_control = `ALU_ADD; // ADD
          `FUNC_SUB:  alu_control = `ALU_SUB; // SUB
          `FUNC_AND:  alu_control = `ALU_AND; // AND
          `FUNC_OR:   alu_control = `ALU_OR;  // OR  
          `FUNC_NOR:  alu_control = `ALU_NOR; // NOR
          `FUNC_SLT:  alu_control = `ALU_SLT; // SLT
          `FUNC_XOR:  alu_control = `ALU_XOR; // XOR
          6'b000000:  alu_control = `ALU_SLL; // SLL
          6'b000010:  alu_control = `ALU_SRL; // SRL
          default:    alu_control = `ALU_ADD; // Por defecto suma
        endcase
      end

      `ALU_OP_IMM: begin // ANDI, ORI, SLTI
        if (func_code[5:0] == `OPCODE_ANDI)
          alu_control = `ALU_AND; // ANDI
        else if (func_code[5:0] == `OPCODE_ORI)
          alu_control = `ALU_OR;  // ORI
        else if (func_code[5:0] == `OPCODE_SLTI)
          alu_control = `ALU_SLT; // SLTI
      end
      
    endcase
  end

endmodule
