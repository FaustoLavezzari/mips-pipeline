`timescale 1ns / 1ps
`include "../src/mips/mips_pkg.vh"

module mips_jr_tb;

  reg clk;
  reg reset;
  wire [31:0] result;
  wire halt;
  
  // Instanciar el procesador MIPS
  mips dut(
    .clk(clk), 
    .reset(reset),
    .result(result),
    .halt(halt)
  );
  
  // Generar señal de reloj
  always #5 clk = ~clk;
  
  // Variables para contar ciclos
  integer cycle_count = 0;
  
  // Función para identificar el tipo de instrucción
  function [100:0] instr_type;
    input [31:0] instr;
    reg [5:0] opcode;
    reg [5:0] funct;
    begin
      opcode = instr[31:26];
      funct = instr[5:0];
      
      if (instr == 32'b0) 
        instr_type = "NOP";
      else if (opcode == `OPCODE_R_TYPE) begin
        // Para instrucciones de tipo R, verificar el campo funct
        case (funct)
          `FUNC_JR    : instr_type = "JR";
          `FUNC_JALR  : instr_type = "JALR";
          default     : instr_type = "R-TYPE";
        endcase
      end else begin
        // Para instrucciones de tipo I o J
        case (opcode)
          `OPCODE_ADDI  : instr_type = "ADDI";
          `OPCODE_J     : instr_type = "J";
          `OPCODE_JAL   : instr_type = "JAL";
          `OPCODE_BEQ   : instr_type = "BEQ";
          `OPCODE_BNE   : instr_type = "BNE";
          `OPCODE_LW    : instr_type = "LW";
          `OPCODE_SW    : instr_type = "SW";
          default       : instr_type = "OTHER";
        endcase
      end
    end
  endfunction
  
  initial begin
    // Inicialización
    clk = 0;
    reset = 1;
    
    // Cargar programa de prueba JR
    $readmemh("../instructions/test_jr_instr.mem", dut.if_stage_inst.imem_inst.memory);
    
    // Reiniciar procesador
    #10 reset = 0;
    
    // Ejecutar la simulación por más ciclos para completar el programa
    #700;
    
    // Verificar resultados
    $display("\n==== Verificación de resultados ====");
    $display("$1 = %0d (Esperado: 5)", 
             dut.id_stage_inst.reg_bank.registers[1]);
    $display("$2 = %0d (Esperado: 100)", 
             dut.id_stage_inst.reg_bank.registers[2]);
    $display("$16 = %0d (Esperado: 24)", // Corregido: debe ser 24, no 16
             dut.id_stage_inst.reg_bank.registers[16]);
    $display("$3 = %0d (Esperado: 0)", // No debe cambiar por el salto
             dut.id_stage_inst.reg_bank.registers[3]);
    $display("$4 = %0d (Esperado: 0)", // No debe cambiar por el salto
             dut.id_stage_inst.reg_bank.registers[4]);
    $display("$5 = %0d (Esperado: 153)", // Debe ser modificado después del JR
             dut.id_stage_inst.reg_bank.registers[5]);
    $display("$6 = %0d (Esperado: 6)", // Debe ser modificado después del JR
             dut.id_stage_inst.reg_bank.registers[6]);
             
    // Verificación de registros para JALR
    $display("\n==== Verificación de resultados para JALR ====");
    $display("$7 = %0d (Esperado: 64)", // Dirección para salto JALR
             dut.id_stage_inst.reg_bank.registers[7]);
    $display("$8 = %0d (Esperado: 0)", // No debe cambiar por el salto JALR
             dut.id_stage_inst.reg_bank.registers[8]);
    $display("$9 = %0d (Esperado: 0)", // No debe cambiar por el salto JALR
             dut.id_stage_inst.reg_bank.registers[9]);
    $display("$10 = %0d (Esperado: 0)", // No debe cambiar por el salto JALR
             dut.id_stage_inst.reg_bank.registers[10]);
    $display("$11 = %0d (Esperado: 11)", // Debe ser modificado después del JALR
             dut.id_stage_inst.reg_bank.registers[11]);
    $display("$31 = %0d (Return address de JALR)", // Contiene la dirección de retorno
             dut.id_stage_inst.reg_bank.registers[31]);
    
    // Verificación de resultados para JR
    if (dut.id_stage_inst.reg_bank.registers[1] == 5 &&
        dut.id_stage_inst.reg_bank.registers[2] == 100 &&
        dut.id_stage_inst.reg_bank.registers[16] == 24 &&
        dut.id_stage_inst.reg_bank.registers[3] == 0 &&
        dut.id_stage_inst.reg_bank.registers[4] == 0 &&
        dut.id_stage_inst.reg_bank.registers[5] == 153 &&
        dut.id_stage_inst.reg_bank.registers[6] == 6) begin
      $display("\n¡TEST EXITOSO! La instrucción JR funciona correctamente\n");
    end else begin
      $display("\n¡TEST FALLIDO! La instrucción JR no funciona como se esperada\n");
    end
    
    // Verificación de resultados para JALR
    if (dut.id_stage_inst.reg_bank.registers[7] == 64 &&
        dut.id_stage_inst.reg_bank.registers[8] == 0 &&
        dut.id_stage_inst.reg_bank.registers[9] == 0 &&
        dut.id_stage_inst.reg_bank.registers[10] == 0 &&
        dut.id_stage_inst.reg_bank.registers[11] == 11 &&
        dut.id_stage_inst.reg_bank.registers[31] != 0) begin
      $display("\n¡TEST EXITOSO! La instrucción JALR funciona correctamente\n");
      $display("Dirección de retorno almacenada en $31: %0d\n", 
               dut.id_stage_inst.reg_bank.registers[31]);
    end else begin
      $display("\n¡TEST FALLIDO! La instrucción JALR no funciona como se esperada\n");
    end
    
    $finish;
  end
  
  // Monitorear el estado del procesador en cada ciclo
  always @(posedge clk) begin
    if (!reset) begin
      cycle_count = cycle_count + 1;
      
      // Mostrar información del ciclo
      $display("\n==== Ciclo %0d (t=%0t ns) ====", cycle_count, $time);
      
      // Mostrar el estado del pipeline
      $display("IF: PC=%0h, Instr=%0h, Tipo=%s", 
               dut.if_stage_inst.pc_inst.pc,
               dut.if_instr,
               instr_type(dut.if_instr));
               
      $display("ID: Instr=%0h, Take Branch=%0b, Function=%0h", 
               dut.id_instr,
               dut.id_take_branch,
               dut.id_function);
               
      $display("ID_BRANCH_CONTROL: take_branch=%0b, target=0x%h, read_data_1=0x%h", 
               dut.id_take_branch,
               dut.id_branch_target_addr,
               dut.id_read_data_1);
               
      $display("ID_FORWARDING: UseForwardedA=%0b, UseForwardedB=%0b, RS=%0d, RT=%0d", 
               dut.id_use_forwarded_a,
               dut.id_use_forwarded_b,
               dut.id_rs,
               dut.id_rt);
               
      $display("EX: ALUResult=%0d", 
               dut.ex_alu_result);
               
      // Mostrar opcode y function code en EX para debugging
      $display("EX Debug: Opcode=%b, Function=%b, forwarded_a=%0d", 
               dut.ex_stage_inst.i_opcode,
               dut.ex_stage_inst.i_function,
               dut.ex_stage_inst.forwarded_a);
    end
  end

endmodule
