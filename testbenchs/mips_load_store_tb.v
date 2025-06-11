`timescale 1ns / 1ps
`include "../src/mips/mips_pkg.vh"

module mips_load_store_tb;

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
          `OPCODE_LWU   : instr_type = "LWU";
          `OPCODE_LH    : instr_type = "LH";
          `OPCODE_LHU   : instr_type = "LHU";
          `OPCODE_LB    : instr_type = "LB";
          `OPCODE_LBU   : instr_type = "LBU";
          `OPCODE_SW    : instr_type = "SW";
          `OPCODE_SH    : instr_type = "SH";
          `OPCODE_SB    : instr_type = "SB";
          default       : instr_type = "OTHER";
        endcase
      end
    end
  endfunction
  
  initial begin
    // Inicialización
    clk = 0;
    reset = 1;
    
    // Cargar programa de prueba Load/Store
    // ya está cargado en el modulo inst_mem directamente
    
    // Reiniciar procesador
    #10 reset = 0;
    
    // Ejecutar la simulación por suficientes ciclos para completar el programa
    #700;
    
    // Verificar resultados de los registros
    $display("\n==== Verificación de resultados de registros ====");
    
    // Test SB, LB, LBU
    $display("\n=== TEST SB, LB, LBU ===");
    $display("$1 = 0x%h (Esperado: 0x000000FF)", 
             dut.id_stage_inst.reg_bank.registers[1]);
    $display("$2 = 0x%h (Esperado: 0x000000FF sin signo)", 
             dut.id_stage_inst.reg_bank.registers[2]);
    $display("$3 = 0x%h (Esperado: 0xFFFFFFFF con signo)", 
             dut.id_stage_inst.reg_bank.registers[3]);

    // Test SH, LH, LHU (positivo)
    $display("\n=== TEST SH, LH, LHU (positivo) ===");
    $display("$4 = 0x%h (Esperado: 0x00001234)", 
             dut.id_stage_inst.reg_bank.registers[4]);
    $display("$5 = 0x%h (Esperado: 0x00001234 sin signo)", 
             dut.id_stage_inst.reg_bank.registers[5]);
    $display("$6 = 0x%h (Esperado: 0x00001234 con signo)", 
             dut.id_stage_inst.reg_bank.registers[6]);

    // Test SH, LH, LHU (negativo)
    $display("\n=== TEST SH, LH, LHU (negativo) ===");
    $display("$13 = 0x%h (Esperado: 0xFFFFCFC7)", 
             dut.id_stage_inst.reg_bank.registers[13]);
    $display("$14 = 0x%h (Esperado: 0xFFFFCFC7 con signo)", 
             dut.id_stage_inst.reg_bank.registers[14]);
    $display("$15 = 0x%h (Esperado: 0x0000CFC7 sin signo)", 
             dut.id_stage_inst.reg_bank.registers[15]);

    // Test SW, LW, LWU (positivo)
    $display("\n=== TEST SW, LW, LWU (positivo) ===");
    $display("$7 = 0x%h (Esperado: 0x00005678)", 
             dut.id_stage_inst.reg_bank.registers[7]);
    $display("$8 = 0x%h (Esperado: 0x00005678)", 
             dut.id_stage_inst.reg_bank.registers[8]);
    $display("$9 = 0x%h (Esperado: 0x00005678)", 
             dut.id_stage_inst.reg_bank.registers[9]);

    // Test SW, LW, LWU (negativo)
    $display("\n=== TEST SW, LW, LWU (negativo) ===");
    $display("$10 = 0x%h (Esperado: 0xFFFFFFFF)", 
             dut.id_stage_inst.reg_bank.registers[10]);
    $display("$11 = 0x%h (Esperado: 0xFFFFFFFF con signo)", 
             dut.id_stage_inst.reg_bank.registers[11]);
    $display("$12 = 0x%h (Esperado: 0xFFFFFFFF sin signo)", 
             dut.id_stage_inst.reg_bank.registers[12]);

    // Test SB, LB, LBU (negativo)
    $display("\n=== TEST SB, LB, LBU (negativo) ===");
    $display("$16 = 0x%h (Esperado: 0xFFFFFFFE)", 
             dut.id_stage_inst.reg_bank.registers[16]);
    $display("$17 = 0x%h (Esperado: 0x000000FE sin signo)", 
             dut.id_stage_inst.reg_bank.registers[17]);
    $display("$18 = 0x%h (Esperado: 0xFFFFFFFE con signo)", 
             dut.id_stage_inst.reg_bank.registers[18]);

    // Verificación global de resultados
    if (dut.id_stage_inst.reg_bank.registers[1] == 32'h000000FF &&
        dut.id_stage_inst.reg_bank.registers[2] == 32'h000000FF &&
        dut.id_stage_inst.reg_bank.registers[3] == 32'hFFFFFFFF &&
        dut.id_stage_inst.reg_bank.registers[4] == 32'h00001234 &&
        dut.id_stage_inst.reg_bank.registers[5] == 32'h00001234 &&
        dut.id_stage_inst.reg_bank.registers[6] == 32'h00001234 &&
        dut.id_stage_inst.reg_bank.registers[7] == 32'h00005678 &&
        dut.id_stage_inst.reg_bank.registers[8] == 32'h00005678 &&
        dut.id_stage_inst.reg_bank.registers[9] == 32'h00005678 &&
        dut.id_stage_inst.reg_bank.registers[10] == 32'hFFFFFFFF &&
        dut.id_stage_inst.reg_bank.registers[11] == 32'hFFFFFFFF &&
        dut.id_stage_inst.reg_bank.registers[12] == 32'hFFFFFFFF &&
        dut.id_stage_inst.reg_bank.registers[13] == 32'hFFFFCFC7 &&
        dut.id_stage_inst.reg_bank.registers[14] == 32'hFFFFCFC7 &&
        dut.id_stage_inst.reg_bank.registers[15] == 32'h0000CFC7 &&
        dut.id_stage_inst.reg_bank.registers[16] == 32'hFFFFFFFE &&
        dut.id_stage_inst.reg_bank.registers[17] == 32'h000000FE &&
        dut.id_stage_inst.reg_bank.registers[18] == 32'hFFFFFFFE) begin
      $display("\n¡TEST EXITOSO! Las instrucciones de carga/almacenamiento funcionan correctamente\n");
    end else begin
      $display("\n¡TEST FALLIDO! Las instrucciones de carga/almacenamiento no funcionan como se esperaba\n");
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
               
      $display("ID: Instr=%0h, Branch=%0b, Function=%0h", 
               dut.id_instr,
               dut.id_branch,
               dut.id_function);
               
      $display("ID_BRANCH_CONTROL: branch=%0b, branch_taken=%0b, jump_taken=%0b, target=0x%h, read_data_1=0x%h", 
               dut.id_branch,
               dut.id_branch_taken,
               dut.id_jump_taken,
               dut.id_branch_target_addr,
               dut.id_read_data_1);
               
      $display("ID_FORWARDING: ForwardA=%0b, ForwardB=%0b, RS=%0d, RT=%0d", 
               dut.id_forward_a,
               dut.id_forward_b,
               dut.id_rs,
               dut.id_rt);
               
      // Mostrar información de la etapa EX
      $display("EX: ALUResult=%0d, TargetAddr=%0h", 
               dut.ex_alu_result,
               dut.ex_branch_target_addr);
               
      // Mostrar información de memoria en la etapa MEM
      if (dut.mem_mem_write)
        $display("MEM: Store mem[%0h] = 0x%h", 
                dut.mem_alu_result,
                dut.mem_write_data);
      if (dut.mem_mem_read)
        $display("MEM: Load from mem[%0h] = 0x%h", 
                dut.mem_alu_result,
                dut.mem_read_data);
    end
  end

endmodule
