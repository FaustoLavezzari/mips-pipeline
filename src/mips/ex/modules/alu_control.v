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
          `FUNC_ADD:  alu_control = `ALU_ADD;  // ADD
          `FUNC_ADDU: alu_control = `ALU_ADD;  // ADDU (misma operación que ADD en la ALU)
          `FUNC_SUB:  alu_control = `ALU_SUB;  // SUB
          `FUNC_SUBU: alu_control = `ALU_SUB;  // SUBU (misma operación que SUB en la ALU)
          `FUNC_AND:  alu_control = `ALU_AND;  // AND
          `FUNC_OR:   alu_control = `ALU_OR;   // OR  
          `FUNC_NOR:  alu_control = `ALU_NOR;  // NOR
          `FUNC_SLT:  alu_control = `ALU_SLT;  // SLT
          `FUNC_SLTU: alu_control = `ALU_SLTU; // SLTU
          `FUNC_XOR:  alu_control = `ALU_XOR;  // XOR
          `FUNC_SLL:  begin
                      alu_control = `ALU_SLL;  // SLL
                      $display("SLL detectado: func_code=%b, alu_control=%b", func_code, alu_control);
                      end
          `FUNC_SRL:  begin
                      alu_control = `ALU_SRL;  // SRL
                      $display("SRL detectado: func_code=%b, alu_control=%b", func_code, alu_control);
                      end
          `FUNC_SRA:  begin
                      alu_control = `ALU_SRA;  // SRA
                      $display("SRA detectado: func_code=%b, alu_control=%b", func_code, alu_control);
                      end
          `FUNC_SLLV: begin
                      alu_control = `ALU_SLL;  // SLLV - Usa misma operación que SLL
                      $display("SLLV detectado: func_code=%b, alu_control=%b", func_code, alu_control);
                      end
          `FUNC_SRLV: begin
                      alu_control = `ALU_SRL;  // SRLV - Usa misma operación que SRL
                      $display("SRLV detectado: func_code=%b, alu_control=%b", func_code, alu_control);
                      end
          `FUNC_SRAV: begin
                      alu_control = `ALU_SRA;  // SRAV - Usa misma operación que SRA
                      $display("SRAV detectado: func_code=%b, alu_control=%b", func_code, alu_control);
                      end
          default:    alu_control = `ALU_ADD;  // Por defecto suma
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
