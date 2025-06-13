`timescale 1ns / 1ps
`include "../../mips_pkg.vh"

module alu_control(
  input  wire [5:0] i_func_code,   // Campo function de la instrucción
  input  wire [5:0] i_opcode,    // Opcode de la instrucción (para instrucciones I-type)
  output reg  [3:0] alu_control  // Señal de control para la ALU
);

  always @(*) begin
    // Asignación predeterminada inicial
    alu_control = `ALU_BYPASS_A;
    
    case(i_opcode)   
      `OPCODE_R_TYPE: begin // Instrucciones R-type - depende del campo function
        case(i_func_code) 
          `FUNC_ADDU: alu_control = `ALU_ADDU; 
          `FUNC_SUBU: alu_control = `ALU_SUBU;  // SUBU
          `FUNC_AND:  alu_control = `ALU_AND;  // AND
          `FUNC_OR:   alu_control = `ALU_OR;   // OR  
          `FUNC_NOR:  alu_control = `ALU_NOR;  // NOR
          `FUNC_SLT:  alu_control = `ALU_SLT;  // SLT
          `FUNC_SLTU: alu_control = `ALU_SLTU; // SLTU
          `FUNC_XOR:  alu_control = `ALU_XOR;  // XOR
          `FUNC_SLL:  alu_control = `ALU_SLL;  // SLL
          `FUNC_SRL:  alu_control = `ALU_SRL;  // SRL
          `FUNC_SRA:  alu_control = `ALU_SRA;  // SRA
          `FUNC_SLLV: alu_control = `ALU_SLL;  // SLLV - Usa misma operación que SLL
          `FUNC_SRLV: alu_control = `ALU_SRL;  // SRLV - Usa misma operación que SRL
          `FUNC_SRAV: alu_control = `ALU_SRA;  // SRAV - Usa misma operación que SRA   
          `FUNC_JR:   alu_control = `ALU_BYPASS_A; // JR - No se usa ALU 
          `FUNC_JALR: alu_control = `ALU_BYPASS_A;  // JALR - No usar PC+4 como operando A
          default:    alu_control = `ALU_ADD; // Por defecto, no se usa ALU
        endcase
      end

      `OPCODE_ADDI:   alu_control = `ALU_ADD; // ADDI - Suma con signo
      `OPCODE_ADDIU:  alu_control = `ALU_ADDU; // ADDIU - Suma sin signo
      `OPCODE_ANDI:   alu_control = `ALU_AND; // ANDI - AND con inmediato
      `OPCODE_ORI:    alu_control = `ALU_OR;  // ORI - OR con inmediato
      `OPCODE_XORI:   alu_control = `ALU_XOR; // XORI - XOR con inmediato
      `OPCODE_LUI:    alu_control = `ALU_LUI; // LUI - Carga inmediata superior
      `OPCODE_SLTI:   alu_control = `ALU_SLT; // SLTI - Comparación con inmediato
      `OPCODE_SLTIU:  alu_control = `ALU_SLTU; // SLTIU - Comparación sin signo con inmediato
      `OPCODE_J, `OPCODE_BNE, `OPCODE_BEQ: alu_control = `ALU_BYPASS_A; // J - No se usa ALU
      `OPCODE_JAL:    alu_control = `ALU_BYPASS_A; // JAL - usar PC+4 como operando A

      default: alu_control = `ALU_ADD; // Por defecto, no se usa ALU
    endcase
  end

endmodule
