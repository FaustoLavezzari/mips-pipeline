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
    $display("\n==== MIPS Pipeline Simple Testbench ====\n");
    
    // Liberar el reset después de unos ciclos
    #15;
    reset = 0;

    // Ejecutar por 40 ciclos (aumentado debido a los NOPs)
    #400;
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
      if (cycle_count % 5 == 0) begin
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
        $display("$11=%0d, $12=%0d, $13=%0d",
                 dut.id_stage_inst.reg_bank.registers[11],
                 dut.id_stage_inst.reg_bank.registers[12],
                 dut.id_stage_inst.reg_bank.registers[13]);
        
        // Mostrar memoria relevante
        $display("Memoria: Mem[100]=%0d, Mem[104]=%0d",
                 dut.mem_stage_inst.memory[25],  // 100/4 = 25
                 dut.mem_stage_inst.memory[26]); // 104/4 = 26
      end
    end
  end
  
  // Verificación final después de 40 ciclos (aumentado debido a los NOPs)
  always @(posedge clk) begin
    if (!reset && cycle_count == 40) begin
      $display("\n==== VERIFICACIÓN FINAL (Ciclo %0d) ====", cycle_count);
      $display("Registros finales:");
      $display("$1=%0d (Esperado: 5)", 
               dut.id_stage_inst.reg_bank.registers[1]);
      $display("$2=%0d (Esperado: 10)", 
               dut.id_stage_inst.reg_bank.registers[2]);
      $display("$3=%0d (Esperado: 100)", 
               dut.id_stage_inst.reg_bank.registers[3]);
      $display("$4=%0d (Esperado: 20)", 
               dut.id_stage_inst.reg_bank.registers[4]);
      $display("$5=%0d (Esperado: 15)", 
               dut.id_stage_inst.reg_bank.registers[5]);
      $display("$6=%0d (Esperado: 10)", 
               dut.id_stage_inst.reg_bank.registers[6]);
      $display("$7=%0d (Esperado: 0)", // $7 = $2 & $3 = 10 & 100 = 0
               dut.id_stage_inst.reg_bank.registers[7]);
      $display("$8=%0d (Esperado: 21)", 
               dut.id_stage_inst.reg_bank.registers[8]);
      $display("$9=%0d (Esperado: 0)", // No se usa $9 en el nuevo código
               dut.id_stage_inst.reg_bank.registers[9]);
      $display("$10=%0d (Esperado: 15)", 
               dut.id_stage_inst.reg_bank.registers[10]);
      $display("$11=%0d (Esperado: 10)", 
               dut.id_stage_inst.reg_bank.registers[11]);
      $display("$12=%0d (Esperado: 25)", 
               dut.id_stage_inst.reg_bank.registers[12]);
      $display("$13=%0d (Esperado: 5)", 
               dut.id_stage_inst.reg_bank.registers[13]);
               
      // Verificar memoria
      $display("\nMemoria final:");
      $display("Mem[100]=%0d (Esperado: 15)", 
               dut.mem_stage_inst.memory[25]);
      $display("Mem[104]=%0d (Esperado: 10)", 
               dut.mem_stage_inst.memory[26]);
               
      // Verificar resultado
      if (dut.id_stage_inst.reg_bank.registers[1] == 5 &&
          dut.id_stage_inst.reg_bank.registers[2] == 10 &&
          dut.id_stage_inst.reg_bank.registers[3] == 100 &&
          dut.id_stage_inst.reg_bank.registers[4] == 20 &&
          dut.id_stage_inst.reg_bank.registers[5] == 15 &&
          dut.id_stage_inst.reg_bank.registers[6] == 10 &&
          dut.id_stage_inst.reg_bank.registers[7] == 0 &&   // $7 = $2 & $3 = 10 & 100 = 0
          dut.id_stage_inst.reg_bank.registers[8] == 21 &&
          dut.id_stage_inst.reg_bank.registers[10] == 15 && // $9 no importa
          dut.id_stage_inst.reg_bank.registers[11] == 10 &&
          dut.id_stage_inst.reg_bank.registers[12] == 25 &&
          dut.id_stage_inst.reg_bank.registers[13] == 5 &&
          dut.mem_stage_inst.memory[25] == 15 &&
          dut.mem_stage_inst.memory[26] == 10) begin
        $display("\n¡PRUEBA EXITOSA! Todos los resultados son correctos.");
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
