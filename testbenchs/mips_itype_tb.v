`timescale 1ns / 1ps
`include "../src/mips/mips_pkg.vh"

module mips_itype_tb();

  // Señales para conectar al DUT
  reg clk;
  reg reset;
  wire [`DATA_WIDTH-1:0] result;
  
  // Instancia del módulo MIPS
  mips dut (
    .clk    (clk),
    .reset  (reset),
    .result (result)
  );
  
  // Genera un reloj de 10ns (100 MHz)
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end
  
  // Variables para el ciclo
  integer cycle_count;
  
  // Función para mostrar el tipo de instrucción
  function [8*20:1] instr_type;
    input [`DATA_WIDTH-1:0] instr;
    reg [5:0] opcode;
    reg [5:0] funct;
    begin
      opcode = instr[31:26];
      funct = instr[5:0];
      case(opcode)
        `OPCODE_R_TYPE: begin
          case(funct)
            `FUNC_AND:  instr_type = "AND";
            `FUNC_OR:   instr_type = "OR";
            `FUNC_XOR:  instr_type = "XOR";
            `FUNC_NOR:  instr_type = "NOR";
            `FUNC_SLT:  instr_type = "SLT";
            `FUNC_SLTU: instr_type = "SLTU";
            `FUNC_SLL:  instr_type = "SLL";
            `FUNC_SRL:  instr_type = "SRL";
            `FUNC_SRA:  instr_type = "SRA";
            `FUNC_ADDU: instr_type = "ADDU";
            `FUNC_SUBU: instr_type = "SUBU";
            default:    instr_type = "R-desconocida";
          endcase
        end
        `OPCODE_ADDI:   instr_type = "ADDI";
        `OPCODE_ADDIU:  instr_type = "ADDIU";
        `OPCODE_ANDI:   instr_type = "ANDI";
        `OPCODE_ORI:    instr_type = "ORI";
        `OPCODE_XORI:   instr_type = "XORI";   // Añadido opcode XORI
        `OPCODE_SLTI:   instr_type = "SLTI";
        `OPCODE_SLTIU:  instr_type = "SLTIU";  // Añadido opcode SLTIU
        `OPCODE_LW:     instr_type = "LW";
        `OPCODE_SW:     instr_type = "SW";
        `OPCODE_BEQ:    instr_type = "BEQ";
        `OPCODE_BNE:    instr_type = "BNE";
        `OPCODE_J:      instr_type = "J";
        `OPCODE_JAL:    instr_type = "JAL";
        `OPCODE_LB:     instr_type = "LB";
        `OPCODE_LBU:    instr_type = "LBU";
        `OPCODE_LH:     instr_type = "LH";
        `OPCODE_LHU:    instr_type = "LHU";
        `OPCODE_SB:     instr_type = "SB";     // Añadido opcode SB
        `OPCODE_SH:     instr_type = "SH";     // Añadido opcode SH
        `OPCODE_LWU:    instr_type = "LWU";
        `OPCODE_LUI:    instr_type = "LUI";
        default:        instr_type = "desconocida";
      endcase
    end
  endfunction
  
  // Inicio de la simulación
  initial begin
    // Inicialización de señales
    reset = 1;
    cycle_count = 0;
    
    // Mostrar encabezado
    $display("\n==== MIPS Pipeline I-Type Instructions Testbench ====\n");
    $display("Este testbench evalúa el funcionamiento de las instrucciones I-Type en el pipeline MIPS");
    
    // Liberar el reset después de unos ciclos
    #15;
    reset = 0;

    // Ejecutar por 90 ciclos + margen extra para completar todas las instrucciones
    #950;
    $finish;
  end
  
  // Imprime el estado de cada etapa en cada ciclo
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
               
      $display("ID: Instr=%0h, RegDst=%0b, ALUOp=%0b, RegWrite=%0b", 
               dut.id_instr,
               dut.id_reg_dst,
               dut.id_alu_op,
               dut.id_reg_write);
               
      $display("EX: ALUResult=%0d, RD=%0d, RegWrite=%0b", 
               dut.ex_alu_result,
               dut.ex_write_register,
               dut.ex_reg_write);
               
      // Mostrar información de branch prediction
      if (dut.id_branch) begin
        $display("BRANCH: opcode=%6b, prediction=%0b (always not taken), target=%0h", 
                 dut.id_opcode, 
                 dut.id_branch_prediction, 
                 dut.id_branch_target_addr);
      end
      
      // Mostrar información de la unidad de forwarding de ID y EX
      begin
        $display("ID_FORWARDING: ForwardA=%0b, ForwardB=%0b, RS=%0d, RT=%0d", 
                 dut.id_forward_a,
                 dut.id_forward_b,
                 dut.id_rs,
                 dut.id_rt);
                 
        $display("ID_BRANCH_CONTROL: branch=%0b, branch_taken=%0b, jump_taken=%0b, target=0x%h", 
                 dut.id_branch,
                 dut.id_branch_taken,
                 dut.id_jump_taken,
                 dut.id_branch_target_addr);
                 
        // Agregar check para JAL
        $display("JAL_CHECK: is_jal=%0b, PC+4=0x%h (ID)", 
                 dut.id_is_jal,
                 dut.id_next_pc);
                 
        $display("EX_FORWARDING: ForwardA=%0b, ForwardB=%0b", 
                 dut.ex_stage_inst.forward_a,
                 dut.ex_stage_inst.forward_b);
        
        // Mostrar también los registros de origen y destino relevantes
        $display("REGS: Rs=%0d, Rt=%0d, MEM_Rd=%0d, WB_Rd=%0d", 
                 dut.ex_rs,
                 dut.ex_rt,
                 dut.mem_write_register,
                 dut.wb_write_register_out);
      end
               
      $display("MEM: ALUResult=%0d, MemWrite=%0b, MemRead=%0b, RegWrite=%0b", 
               dut.mem_alu_result,
               dut.mem_mem_write,
               dut.mem_mem_read,
               dut.mem_reg_write_out);
               
      $display("WB: WriteReg=%0d, WriteData=%0d, RegWrite=%0b", 
               dut.wb_write_register_out,
               dut.wb_write_data,
               dut.wb_reg_write_out);
               
      // Agregar check específico para registros relevantes a JAL/J
      if (dut.wb_write_register_out == 31 || dut.wb_write_register_out == 19 || dut.wb_write_register_out == 20) begin
        $display("REGISTRO_CRÍTICO: Reg[%0d] <- %0d (0x%h), RegWrite=%0b", 
                 dut.wb_write_register_out,
                 dut.wb_write_data,
                 dut.wb_write_data,
                 dut.wb_reg_write_out);
      end
               
      // Mostrar el contenido de los registros cada ciclo
      if (cycle_count % 1 == 0) begin
        $display("\nRegistros en ciclo %0d:", cycle_count);
        $display("$1=%0d, $2=%0d, $3=%0d, $4=%0d, $5=%0d", 
                 dut.id_stage_inst.reg_bank.registers[1],
                 dut.id_stage_inst.reg_bank.registers[2],
                 dut.id_stage_inst.reg_bank.registers[3],
                 dut.id_stage_inst.reg_bank.registers[4],
                 dut.id_stage_inst.reg_bank.registers[5]);
        $display("$6=%0d, $7=%0d, $8=%0d, $9=%0d, $10=%0d",
                 dut.id_stage_inst.reg_bank.registers[6],
                 dut.id_stage_inst.reg_bank.registers[7],
                 dut.id_stage_inst.reg_bank.registers[8],
                 dut.id_stage_inst.reg_bank.registers[9],
                 dut.id_stage_inst.reg_bank.registers[10]);
        $display("$11=%0d, $12=%0d, $13=%0d, $14=%0d, $15=%0d",
                 dut.id_stage_inst.reg_bank.registers[11],
                 dut.id_stage_inst.reg_bank.registers[12],
                 dut.id_stage_inst.reg_bank.registers[13],
                 dut.id_stage_inst.reg_bank.registers[14],
                 dut.id_stage_inst.reg_bank.registers[15]);
        $display("$16=%0d, $17=%0d, $18=%0d, $19=%0d, $20=%0d",
                 dut.id_stage_inst.reg_bank.registers[16],
                 dut.id_stage_inst.reg_bank.registers[17],
                 dut.id_stage_inst.reg_bank.registers[18],
                 dut.id_stage_inst.reg_bank.registers[19],
                 dut.id_stage_inst.reg_bank.registers[20]);
        $display("$21=%0d, $22=%0x, $23=%0d, $24=%0d, $25=%0d",
                 dut.id_stage_inst.reg_bank.registers[21],
                 dut.id_stage_inst.reg_bank.registers[22],
                 dut.id_stage_inst.reg_bank.registers[23],
                 dut.id_stage_inst.reg_bank.registers[24],
                 dut.id_stage_inst.reg_bank.registers[25]);
        $display("$26=%0d, $27=%0d, $28=%0d, $29=%0d, $30=%0d, $31=%0d",
                 dut.id_stage_inst.reg_bank.registers[26],
                 dut.id_stage_inst.reg_bank.registers[27],
                 dut.id_stage_inst.reg_bank.registers[28],
                 dut.id_stage_inst.reg_bank.registers[29],
                 dut.id_stage_inst.reg_bank.registers[30],
                 dut.id_stage_inst.reg_bank.registers[31]);
                 
        // Mostrar contenido de memoria relevante
        $display("Memoria: Mem[0]=%0d, Mem[1]=%0d, Mem[2]=%0d, Mem[25]=%0d, Mem[26]=%0d",
                 dut.mem_stage_inst.memory[0],
                 dut.mem_stage_inst.memory[1],
                 dut.mem_stage_inst.memory[2],
                 dut.mem_stage_inst.memory[25],  // 100/4 = 25
                 dut.mem_stage_inst.memory[26]); // 104/4 = 26
        $display("Mem[29]=%0d, Mem[30]=%0d, Mem[31]=%0d (valores para pruebas de LB/LH)",
                 dut.mem_stage_inst.memory[29],  // (16+100)/4 = 29 (Mem para byte load)
                 dut.mem_stage_inst.memory[30],  // (20+100)/4 = 30 (Mem para half load)
                 dut.mem_stage_inst.memory[31]); // (24+100)/4 = 31 (Mem para half load negativo)
                         
        // Añadir valores para SB y SH
        $display("Mem[32]=%0d / 0x%h (SB - guarda solo un byte)", 
                 dut.mem_stage_inst.memory[32],  // (28+100)/4 = 32 (SB - memoria)
                 dut.mem_stage_inst.memory[32]);
        $display("Mem[33]=%0d / 0x%h (SH - guarda solo halfword)", 
                 dut.mem_stage_inst.memory[33],  // (32+100)/4 = 33 (SH - memoria)
                 dut.mem_stage_inst.memory[33]);
      end
    end
  end      // Verificación final después de 90 ciclos
  always @(posedge clk) begin
    if (!reset && cycle_count == 90) begin
      $display("\n==== VERIFICACIÓN FINAL (Ciclo %0d) ====", cycle_count);
      $display("Registros finales:");
      // Verificación de resultados ADDI, ADDIU
      $display("$1=%0d (Esperado: 170 - XORI)", 
               dut.id_stage_inst.reg_bank.registers[1]);
      $display("$2=%0d (Esperado: 20 - ADDI)", 
               dut.id_stage_inst.reg_bank.registers[2]);
      $display("$3=%0d (Esperado: 0 - ADDI)", 
               dut.id_stage_inst.reg_bank.registers[3]);
      $display("$4=%0d (Esperado: 100 - ADDI)", 
               dut.id_stage_inst.reg_bank.registers[4]);
      $display("$5=%0d (Esperado: 40 - ADDIU)", 
               dut.id_stage_inst.reg_bank.registers[5]);
      
      // Verificación de resultados ANDI, ORI, SLTI
      $display("$6=%0d (Esperado: 0 - ANDI)", 
               dut.id_stage_inst.reg_bank.registers[6]);
      $display("$7=%0d (Esperado: 7 - ORI)", 
               dut.id_stage_inst.reg_bank.registers[7]);
      $display("$8=%0d (Esperado: 0 - SLTIU)", 
               dut.id_stage_inst.reg_bank.registers[8]);
      $display("$9=%0d / 0x%h (Esperado: 0x12340000 - LUI)", 
               dut.id_stage_inst.reg_bank.registers[9],
               dut.id_stage_inst.reg_bank.registers[9]);
      $display("$10=%0d (Esperado: -256 - LH)", 
               dut.id_stage_inst.reg_bank.registers[10]);
               
      // Verificación de resultados LW, SW
      $display("$11=%0d (Esperado: 65280 - LHU)", 
               dut.id_stage_inst.reg_bank.registers[11]);
      $display("$12=%0d (Esperado: 10 - LW desde Mem[0])", 
               dut.id_stage_inst.reg_bank.registers[12]);
      $display("$13=%0d (Esperado: 20 - LW desde Mem[1])", 
               dut.id_stage_inst.reg_bank.registers[13]);
      $display("$14=%0d (Esperado: -10 - LW desde Mem[2])", 
               dut.id_stage_inst.reg_bank.registers[14]);
      $display("$15=%0d (Esperado: 20 - LW con offset)", 
               dut.id_stage_inst.reg_bank.registers[15]);
      $display("$16=%0d (Esperado: 10 - LW con offset)", 
               dut.id_stage_inst.reg_bank.registers[16]);
               
      // Verificación de resultados SB, SH (sobrescriben los valores originales de BEQ y BNE)
      $display("$17=%0d / 0x%h (Esperado: 220 / 0x000000dc - SB Test)", 
               dut.id_stage_inst.reg_bank.registers[17],
               dut.id_stage_inst.reg_bank.registers[17]);
      $display("$18=%0d / 0x%h (Esperado: 220 / 0x000000dc - SH Test)", 
               dut.id_stage_inst.reg_bank.registers[18],
               dut.id_stage_inst.reg_bank.registers[18]);
               
      // Verificación de resultados J, JAL
      $display("$19=%0d (Esperado: 100 - después del JUMP)", 
               dut.id_stage_inst.reg_bank.registers[19]);
      $display("$20=%0d (Esperado: 15 - después del JAL)", 
               dut.id_stage_inst.reg_bank.registers[20]);
               
      // Verificación para LB, LBU, LH, LHU, LWU, LUI
      $display("\n==== VERIFICACIÓN DE INSTRUCCIONES DE CARGA Y BYTES ====");
      $display("$21=%0d (Esperado: 255 - ADDI)", 
               dut.id_stage_inst.reg_bank.registers[21]);
      $display("$22=%0d / 0x%h (Esperado: 0xABCD0000 - LUI)", 
               dut.id_stage_inst.reg_bank.registers[22],
               dut.id_stage_inst.reg_bank.registers[22]);
      $display("$23=%0d (Esperado: -1 - LB con extensión de signo)", 
               dut.id_stage_inst.reg_bank.registers[23]);
      $display("$24=%0d (Esperado: 255 - LBU sin extensión de signo)", 
               dut.id_stage_inst.reg_bank.registers[24]);
      $display("$25=%0d (Esperado: 258 - ADDI)", 
               dut.id_stage_inst.reg_bank.registers[25]);
      $display("$26=%0d (Esperado: 258 - LH)", 
               dut.id_stage_inst.reg_bank.registers[26]);
      $display("$27=%0d (Esperado: 258 - LHU)", 
               dut.id_stage_inst.reg_bank.registers[27]);
      $display("$28=%0d (Esperado: 258 - LW)", 
               dut.id_stage_inst.reg_bank.registers[28]);
      $display("$29=%0d (Esperado: 258 - LWU)", 
               dut.id_stage_inst.reg_bank.registers[29]);
      $display("$30=%0d (Esperado: -256 - ADDI)", 
               dut.id_stage_inst.reg_bank.registers[30]);
      $display("$31=%0d (Esperado:  - JAL return)", 
               dut.id_stage_inst.reg_bank.registers[31]);
               
      // Verificación de memoria
      $display("\n==== VERIFICACIÓN DE MEMORIA ====");
      $display("Mem[0]=%0d (Esperado: 10 - SW)", 
               dut.mem_stage_inst.memory[0]);
      $display("Mem[1]=%0d (Esperado: 20 - SW)", 
               dut.mem_stage_inst.memory[1]);
      $display("Mem[2]=%0d (Esperado: -10 - SW)", 
               dut.mem_stage_inst.memory[2]);
      $display("Mem[25]=%0d (Esperado: 20 - SW con offset)", 
               dut.mem_stage_inst.memory[25]);  // 100/4 = 25
      $display("Mem[26]=%0d (Esperado: 10 - SW con offset)", 
               dut.mem_stage_inst.memory[26]);  // 104/4 = 26
      $display("Mem[29]=%0d (Esperado: 255 - SW con offset)", 
               dut.mem_stage_inst.memory[29]);  // 116/4 = 29 (16+100)/4
      $display("Mem[30]=%0d (Esperado: 258 - SW con offset)", 
               dut.mem_stage_inst.memory[30]);  // 120/4 = 30 (20+100)/4
      $display("Mem[31]=%0d (Esperado: -256 - SW con offset)", 
               dut.mem_stage_inst.memory[31]);  // 124/4 = 31 (24+100)/4
      $display("Mem[32]=%0d / 0x%h (Esperado: 0x000000dc - SB)", 
               dut.mem_stage_inst.memory[32],   // 128/4 = 32 (28+100)/4
               dut.mem_stage_inst.memory[32]);
      $display("Mem[33]=%0d / 0x%h (Esperado: 0x000000dc - SH)", 
               dut.mem_stage_inst.memory[33],   // 132/4 = 33 (32+100)/4
               dut.mem_stage_inst.memory[33]);
      
      // Verificar si todas las instrucciones funcionan correctamente
      if (dut.id_stage_inst.reg_bank.registers[1] == 170 &&
          dut.id_stage_inst.reg_bank.registers[2] == 20 &&
          dut.id_stage_inst.reg_bank.registers[3] == 0 &&
          dut.id_stage_inst.reg_bank.registers[4] == 100 &&
          dut.id_stage_inst.reg_bank.registers[5] == 40 &&
          dut.id_stage_inst.reg_bank.registers[6] == 0 &&
          dut.id_stage_inst.reg_bank.registers[7] == 7 &&
          dut.id_stage_inst.reg_bank.registers[8] == 0 &&  // SLTIU
          dut.id_stage_inst.reg_bank.registers[9] == 32'h12340000 &&  // LUI
          dut.id_stage_inst.reg_bank.registers[10] == -256 &&  // LH
          dut.id_stage_inst.reg_bank.registers[11] == 65280 && // LHU
          dut.id_stage_inst.reg_bank.registers[12] == 10 &&
          dut.id_stage_inst.reg_bank.registers[13] == 20 &&
          dut.id_stage_inst.reg_bank.registers[14] == -10 &&
          dut.id_stage_inst.reg_bank.registers[15] == 20 &&
          dut.id_stage_inst.reg_bank.registers[16] == 10 &&
          dut.id_stage_inst.reg_bank.registers[17] == 220 &&  // SB (0xAA) - verificación SB
          dut.id_stage_inst.reg_bank.registers[18] == 220 &&  // SH (0xAA) - verificación SH
          dut.id_stage_inst.reg_bank.registers[19] == 100 && // Jump
          dut.id_stage_inst.reg_bank.registers[20] == 15 && // JAL
          dut.id_stage_inst.reg_bank.registers[21] == 255 &&
          dut.id_stage_inst.reg_bank.registers[22] == 32'hABCD0000 && // LUI
          dut.id_stage_inst.reg_bank.registers[23] == -1 && // LB
          dut.id_stage_inst.reg_bank.registers[24] == 255 && // LBU
          dut.id_stage_inst.reg_bank.registers[25] == 258 &&
          dut.id_stage_inst.reg_bank.registers[26] == 258 && // LH
          dut.id_stage_inst.reg_bank.registers[27] == 258 && // LHU
          dut.id_stage_inst.reg_bank.registers[28] == 258 && // LW
          dut.id_stage_inst.reg_bank.registers[29] == 258 && // LWU
          dut.id_stage_inst.reg_bank.registers[30] == -256 &&
          dut.id_stage_inst.reg_bank.registers[31] == 220 && 
          dut.mem_stage_inst.memory[0] == 10 &&
          dut.mem_stage_inst.memory[1] == 20 &&
          dut.mem_stage_inst.memory[2] == -10 &&
          dut.mem_stage_inst.memory[25] == 20 &&
          dut.mem_stage_inst.memory[26] == 10 &&
          dut.mem_stage_inst.memory[29] == 255 &&
          dut.mem_stage_inst.memory[30] == 258 &&
          dut.mem_stage_inst.memory[31] == -256 &&
          dut.mem_stage_inst.memory[32] == 220 && // SB - verificar solo el byte bajo
          dut.mem_stage_inst.memory[33] == 220  // SH - verificar solo el halfword bajo
          ) begin          
        $display("\n¡PRUEBA EXITOSA! Todas las instrucciones I-Type implementadas funcionan correctamente.");
        $display("\nLas instrucciones ADDI, ADDIU, ANDI, ORI, XORI, SLTI, SLTIU, LW, SW, LB, SB, LH, SH,");
        $display("BEQ, BNE, J, JAL, LWU, LBU, LHU y LUI han sido verificadas.");
        $display("La unidad de forwarding y la predicción de saltos han manejado correctamente los riesgos.");
      end else begin
        $display("\n¡PRUEBA FALLIDA! Algunos resultados no coinciden con los valores esperados.");
        $display("Revisa los valores en los registros y en la memoria para identificar errores.");
      end
    end
  end

  // Para generar formas de onda (VCD)
  initial begin
    $dumpfile("mips_itype.vcd");
    $dumpvars(0, mips_itype_tb);
  end

endmodule
