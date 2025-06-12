`timescale 1ns / 1ps
`include "../src/mips/mips_pkg.vh"

module mips_rtype_tb();

  // Señales para conectar al DUT
  reg clk;
  reg reset;
  wire [`DATA_WIDTH-1:0] result;
  wire halt;
  
  // Instancia del módulo MIPS
  mips dut (
    .clk    (clk),
    .reset  (reset),
    .result (result),
    .halt   (halt)
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
        `OPCODE_ADDI:   instr_type = "addi";
        `OPCODE_LW:     instr_type = "lw";
        `OPCODE_SW:     instr_type = "sw";
        `OPCODE_BEQ:    instr_type = "beq";
        `OPCODE_BNE:    instr_type = "bne";
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
    $display("\n==== MIPS Pipeline R-Type Instructions Testbench ====\n");
    $display("Este testbench evalúa el funcionamiento de las instrucciones R-Type en el pipeline MIPS");
    
    // Liberar el reset después de unos ciclos
    #15;
    reset = 0;

    // Ejecutar por 75 ciclos + margen extra para completar todas las instrucciones
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
      
      // Mostrar información de la unidad de forwarding de ID y EX
      begin
        $display("ID_FORWARDING: ForwardA=%0b, ForwardB=%0b, RS=%0d, RT=%0d", 
                 dut.id_forward_a,
                 dut.id_forward_b,
                 dut.id_rs,
                 dut.id_rt);
                 
        $display("ID_BRANCH_CONTROL: take_branch=%0b, target=0x%h", 
                 dut.id_take_branch,
                 dut.id_branch_target_addr);
                 
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
                 
        // Mostrar contenido de memoria relevante
        $display("Memoria: Mem[100]=%0d, Mem[104]=%0d",
                 dut.mem_stage_inst.memory[25],  // 100/4 = 25
                 dut.mem_stage_inst.memory[26]); // 104/4 = 26
      end
    end
  end
  
  // Verificación final después de 70 ciclos
  always @(posedge clk) begin
    if (!reset && cycle_count == 90) begin
      $display("\n==== VERIFICACIÓN FINAL (Ciclo %0d) ====", cycle_count);
      $display("Registros finales:");
      $display("$1=%0d (Esperado: 10)", 
               dut.id_stage_inst.reg_bank.registers[1]);
      $display("$2=%0d (Esperado: 20)", 
               dut.id_stage_inst.reg_bank.registers[2]);
      $display("$3=%0d (Esperado: 10 & 20 = 0)", 
               dut.id_stage_inst.reg_bank.registers[3]);
      $display("$4=%0d (Esperado: 10 | 20 = 30)", 
               dut.id_stage_inst.reg_bank.registers[4]);
      $display("$5=%0d (Esperado: 10 ^ 20 = 30)", 
               dut.id_stage_inst.reg_bank.registers[5]);
      $display("$6=%0d (Esperado: ~(10 | 20) = -31)", 
               dut.id_stage_inst.reg_bank.registers[6]);
      $display("$7=%0d (Esperado: (10 < 20) ? 1 : 0 = 1)", 
               dut.id_stage_inst.reg_bank.registers[7]);
      $display("$8=%0d (Esperado: 20 << 2 = 80)", 
               dut.id_stage_inst.reg_bank.registers[8]);
      $display("$9=%0d (Esperado: 20 >> 2 = 5)", 
               dut.id_stage_inst.reg_bank.registers[9]);
      $display("$10=%0d (Esperado: 10 + 20 = 30)", 
               dut.id_stage_inst.reg_bank.registers[10]);
      $display("$11=%0d (Esperado: 20 - 10 = 10)", 
               dut.id_stage_inst.reg_bank.registers[11]);
      $display("$12=%0d (Esperado: (10u < 20u) ? 1 : 0 = 1)", 
               dut.id_stage_inst.reg_bank.registers[12]);
      $display("$14=%0d (Sin valor esperado específico)", 
               dut.id_stage_inst.reg_bank.registers[14]);
      $display("$15=%0d (Esperado: 2)", // Resultado de SRA con desplazamiento de 3 bits
               dut.id_stage_inst.reg_bank.registers[15]);
      $display("$16=%0d (Esperado: 100 - dirección base para memoria)", 
               dut.id_stage_inst.reg_bank.registers[16]);
      $display("$17=%0d (Esperado: 20 << 3 = 160 - SLLV)", 
               dut.id_stage_inst.reg_bank.registers[17]);
      $display("$18=%0d (Esperado: 20 >> 2 = 5 - SRLV)", 
               dut.id_stage_inst.reg_bank.registers[18]);
      $display("$19=%0d (Esperado: -3 >>> 2 = -1 - SRAV)", 
               dut.id_stage_inst.reg_bank.registers[19]);
      $display("$20=%0d (Esperado: 2 - cantidad desplazamiento)", 
               dut.id_stage_inst.reg_bank.registers[20]);
              
               
      // Verificar resultado
      if (dut.id_stage_inst.reg_bank.registers[3] == 0 &&
          dut.id_stage_inst.reg_bank.registers[4] == 30 &&
          dut.id_stage_inst.reg_bank.registers[5] == 30 &&
          dut.id_stage_inst.reg_bank.registers[6] == -31 &&
          dut.id_stage_inst.reg_bank.registers[7] == 1 &&
          dut.id_stage_inst.reg_bank.registers[8] == 80 &&
          dut.id_stage_inst.reg_bank.registers[9] == 5 &&
          dut.id_stage_inst.reg_bank.registers[10] == 30 &&
          dut.id_stage_inst.reg_bank.registers[11] == 10 &&
          dut.id_stage_inst.reg_bank.registers[12] == 1 &&
          dut.id_stage_inst.reg_bank.registers[15] == 2 &&  
          dut.id_stage_inst.reg_bank.registers[17] == 160 &&  
          dut.id_stage_inst.reg_bank.registers[18] == 5 &&   
          dut.id_stage_inst.reg_bank.registers[19] == -1    
          ) begin          
        $display("\n¡PRUEBA EXITOSA! Todas las instrucciones R-Type funcionan correctamente.");
        $display("\nLas instrucciones AND, OR, XOR, NOR, SLT, SLL, SRL, SRA, ADDU, SUBU, SLTU, SLLV, SRLV, y SRAV han sido verificadas.");
        $display("La unidad de forwarding ha manejado correctamente los riesgos de datos.");
      end else begin
        $display("\n¡PRUEBA FALLIDA! Algunos resultados no coinciden con los valores esperados.");
      end
    end
  end

  // Para generar formas de onda (VCD)
  initial begin
    $dumpfile("mips_rtype.vcd");
    $dumpvars(0, mips_rtype_tb);
  end

endmodule
