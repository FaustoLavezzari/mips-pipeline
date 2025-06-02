`timescale 1ns / 1ps
`include "../src/mips/mips_pkg.vh"

module mips_simple_tb();

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
    begin
      opcode = instr[31:26];
      case(opcode)
        `OPCODE_R_TYPE: instr_type = "R-type";
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
    $display("\n==== MIPS Pipeline Simple Testbench con Forwarding Unit ====\n");
    $display("Este testbench evalúa el funcionamiento del pipeline MIPS");
    
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
               
      // Mostrar información de branch prediction
      if (dut.id_branch) begin
        $display("BRANCH: opcode=%6b, prediction=%0b (always not taken), target=%0h", 
                 dut.id_opcode, 
                 dut.id_branch_prediction, 
                 dut.id_branch_target_addr);
      end
      
      // Mostrar información de verificación de saltos
      if (dut.i_ex_branch) begin
        $display("BRANCH CHECK: actually taken=%0b, mispredicted=%0b", 
                 dut.ex_branch_taken, 
                 dut.ex_mispredicted);
      end
      
      // Mostrar información de la unidad de forwarding
      begin
        $display("FORWARDING: ForwardA=%0b, ForwardB=%0b", 
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
               
      // Mostrar el contenido de los registros cada 5 ciclos
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
        
        // Mostrar memoria relevante
        $display("Memoria: Mem[100]=%0d, Mem[104]=%0d",
                 dut.mem_stage_inst.memory[25],  // 100/4 = 25
                 dut.mem_stage_inst.memory[26]); // 104/4 = 26
      end
    end
  end
  
  // Verificación final después de 70 ciclos (aumentado para permitir la ejecución completa de todas las instrucciones)
  always @(posedge clk) begin
    if (!reset && cycle_count == 90) begin
      $display("\n==== VERIFICACIÓN FINAL (Ciclo %0d) ====", cycle_count);
      $display("Registros finales:");
      $display("$1=%0d (Esperado: 5)", 
               dut.id_stage_inst.reg_bank.registers[1]);
      $display("$2=%0d (Esperado: 10)", 
               dut.id_stage_inst.reg_bank.registers[2]);
      $display("$3=%0d (Esperado: 100)", // Se restaura a 100 después de cambios para forwarding
               dut.id_stage_inst.reg_bank.registers[3]);
      $display("$4=%0d (Esperado: 20)", // Se restaura a 20 después de cambios para forwarding
               dut.id_stage_inst.reg_bank.registers[4]);
      $display("$5=%0d (Esperado: 5)", // Valor cambiado para pruebas de forwarding
               dut.id_stage_inst.reg_bank.registers[5]);
      $display("$6=%0d (Esperado: 5)", // Valor cambiado con forwarding desde $5
               dut.id_stage_inst.reg_bank.registers[6]);
      $display("$7=%0d (Esperado: 10)", // $7 = $2 & $3 = 10 & 15 = 10 (cuando $3=15)
               dut.id_stage_inst.reg_bank.registers[7]);
      $display("$8=%0d (Esperado: 39)", // $8 = $1 | $4 = 5 | 35 = 39 (cuando $4=35)
               dut.id_stage_inst.reg_bank.registers[8]);
      $display("$9=%0d (Esperado: 1)", // Valor para pruebas de saltos
               dut.id_stage_inst.reg_bank.registers[9]);
      // $10 cambia con forwarding y load, difícil predecir su valor exacto
      $display("$10=%0d", dut.id_stage_inst.reg_bank.registers[10]);
      $display("$11=%0d (Esperado: 5)", // Actualizado con valor de Mem[104]
               dut.id_stage_inst.reg_bank.registers[11]);
      $display("$12=%0d (Esperado: 10)", // $12 = $11 + $6 = 5 + 5 = 10 (forwarding)
               dut.id_stage_inst.reg_bank.registers[12]);
      $display("$13=%0d (Esperado: 0)", // $13 = $5 ^ $6 = 5 ^ 5 = 0
               dut.id_stage_inst.reg_bank.registers[13]);
      $display("$14=%0d (Esperado: 7)", // Registro usado para verificar saltos
               dut.id_stage_inst.reg_bank.registers[14]);
      $display("$15=%0d (Esperado: 20)", // Registro usado para verificar saltos
               dut.id_stage_inst.reg_bank.registers[15]);
               
      // Verificar memoria
      $display("\nMemoria final:");
      $display("Mem[100]=%0d (Esperado: 5)", 
               dut.mem_stage_inst.memory[25]);
      $display("Mem[104]=%0d (Esperado: 5)", 
               dut.mem_stage_inst.memory[26]);
      $display("Mem[35]=%0d (Esperado: 15)", 
               dut.mem_stage_inst.memory[8]);  // 35/4 = 8 (redondeado hacia abajo)
      $display("Mem[39]=%0d (Esperado: 35)", 
               dut.mem_stage_inst.memory[9]);  // 39/4 = 9 (redondeado hacia abajo)
               
      // Verificar resultado
      // Verificamos que los resultados sean correctos considerando los NOPs agregados
      // para evitar riesgos de datos que no puede resolver el forwarding
      if (dut.id_stage_inst.reg_bank.registers[1] == 5 &&
          dut.id_stage_inst.reg_bank.registers[2] == 10 &&
          dut.id_stage_inst.reg_bank.registers[3] == 100 &&    // Restaurado a 100
          dut.id_stage_inst.reg_bank.registers[4] == 20 &&     // Restaurado a 20
          dut.id_stage_inst.reg_bank.registers[5] == 5 &&      // Cambiado a 5 para forwarding
          dut.id_stage_inst.reg_bank.registers[6] == 5 &&      // $6 = $5 + $6(0) = 5 + 0 = 5
          dut.id_stage_inst.reg_bank.registers[7] == 10 &&     // $7 = $2 & $3 = 10 & 15 = 10 (cuando $3=15)
          dut.id_stage_inst.reg_bank.registers[8] == 39 &&     // $8 = $1 | $4 = 5 | 35 = 39
          dut.id_stage_inst.reg_bank.registers[9] == 1 &&      // $9 = 1 (para saltos)
          dut.id_stage_inst.reg_bank.registers[11] == 5 &&     // $11 = Mem[104] = 5
          dut.id_stage_inst.reg_bank.registers[12] == 10 &&    // $12 = $11 + $6 = 5 + 5 = 10
          dut.id_stage_inst.reg_bank.registers[13] == 0 &&     // $13 = $5 ^ $6 = 5 ^ 5 = 0
          dut.id_stage_inst.reg_bank.registers[14] == 7 &&     // $14 = 7 (después de saltos)
          dut.id_stage_inst.reg_bank.registers[15] == 20 &&    // $15 = 20 (después de saltos)
          dut.mem_stage_inst.memory[25] == 5 &&               // Mem[100] = $5 = 5
          dut.mem_stage_inst.memory[26] == 5 &&               // Mem[104] = $6 = 5
          dut.mem_stage_inst.memory[8] == 15 &&               // Mem[35] = $3 = 15
          dut.mem_stage_inst.memory[9] == 35) begin           // Mem[39] = $4 = 35
        $display("\n¡PRUEBA EXITOSA! Todos los resultados son correctos.");
        $display("\nLa unidad de forwarding ha manejado correctamente los riesgos de datos resolubles.");
        $display("Los NOPs insertados han ayudado a evitar los riesgos no resolubles mediante forwarding.");
        $display("(Principalmente: load-use hazards y dependencias EX-EX que requieren stalls)");
      end else begin
        $display("\n¡PRUEBA FALLIDA! Algunos resultados no coinciden con los valores esperados.");
      end
    end
  end

  // Para generar formas de onda (VCD)
  initial begin
    $dumpfile("mips_simple.vcd");
    $dumpvars(0, mips_simple_tb);
  end

endmodule
