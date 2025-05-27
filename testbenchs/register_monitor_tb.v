`timescale 1ns / 1ps

module register_monitor_tb();

  // Señales para conectar al DUT (Device Under Test)
  reg clk;
  reg reset;
  wire [31:0] result;
  
  // Contadores y variables
  integer cycle_count;
  
  // Instancia del módulo MIPS
  mips dut (
    .clk    (clk),
    .reset  (reset),
    .result (result)
  );
  
  // Genera un reloj de 10ns de período (100 MHz)
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end
  
  // Inicio de la simulación
  initial begin
    // Inicialización de señales
    reset = 1;
    cycle_count = 0;
    
    // Mostrar encabezado
    $display("\n==== MIPS Pipeline Register Monitor ====\n");
    
    // Liberar el reset después de unos ciclos
    #15;
    reset = 0;

    // Ejecutar por 25 ciclos (suficiente para todas las instrucciones)
    #250;
    $finish;
  end
  
  // Monitoreo de registros en cada ciclo
  always @(posedge clk) begin
    if (!reset) begin
      cycle_count = cycle_count + 1;
      
      // Mostrar el contador de ciclos
      $display("\n==== Ciclo %0d (t=%0t ns) ====", cycle_count, $time);
      
      // Mostrar PC y la instrucción actual
      $display("PC = %0h, Instrucción = %0h", 
               dut.if_stage_inst.pc_inst.pc,
               dut.if_instr);
      
      // Mostrar señales críticas de la etapa WB
      $display("WB: RegWrite=%0b, WriteReg=%0d, WriteData=%0d", 
                dut.wb_reg_write_out,
                dut.wb_write_register_out,
                dut.wb_write_data);
                
      // Mostrar contenido de registros
      $display("Registros:");
      $display("$1=%0d, $2=%0d, $3=%0d, $4=%0d", 
                dut.id_stage_inst.reg_bank.registers[1],
                dut.id_stage_inst.reg_bank.registers[2],
                dut.id_stage_inst.reg_bank.registers[3],
                dut.id_stage_inst.reg_bank.registers[4]);
      $display("$5=%0d, $6=%0d, $7=%0d, $8=%0d", 
                dut.id_stage_inst.reg_bank.registers[5],
                dut.id_stage_inst.reg_bank.registers[6],
                dut.id_stage_inst.reg_bank.registers[7],
                dut.id_stage_inst.reg_bank.registers[8]);
      $display("$9=%0d, $10=%0d, $11=%0d", 
                dut.id_stage_inst.reg_bank.registers[9],
                dut.id_stage_inst.reg_bank.registers[10],
                dut.id_stage_inst.reg_bank.registers[11]);
      $display("$12=%0d, $13=%0d", 
                dut.id_stage_inst.reg_bank.registers[12],
                dut.id_stage_inst.reg_bank.registers[13]);
                
      // Mostrar contenido relevante de memoria cada 5 ciclos
      if (cycle_count % 5 == 0) begin
        $display("\nMemoria:");
        $display("Mem[100]=%0d, Mem[104]=%0d", 
                dut.mem_stage_inst.memory[25],  // Memoria[100] (100/4 = 25)
                dut.mem_stage_inst.memory[26]); // Memoria[104] (104/4 = 26)
      end
      
      // Seguimiento del pipeline
      $display("\nPipeline:");
      $display("IF->ID: PC=%0h, Instr=%0h", 
                dut.if_stage_inst.pc_inst.pc,
                dut.if_instr);
      $display("ID->EX: RegDst=%0b, ALUOp=%0b, ALUSrc=%0b, RegWrite=%0b",
                dut.id_reg_dst,
                dut.id_alu_op,
                dut.id_alu_src,
                dut.id_reg_write);
      $display("EX->MEM: ALUResult=%0d, RegWrite=%0b", 
                dut.ex_alu_result,
                dut.ex_reg_write);
      $display("MEM->WB: ALUResult=%0d, RegWrite=%0b", 
                dut.mem_alu_result,
                dut.mem_reg_write);
    end
  end
  
  // Verificación final de resultados
  always @(posedge clk) begin
    if (!reset && cycle_count == 25) begin
      $display("\n==== VERIFICACIÓN FINAL DE RESULTADOS ====");
      // Verificar registros
      $display("$1=%0d (Esperado: 5)", dut.id_stage_inst.reg_bank.registers[1]);
      $display("$2=%0d (Esperado: 10)", dut.id_stage_inst.reg_bank.registers[2]);
      $display("$3=%0d (Esperado: 15)", dut.id_stage_inst.reg_bank.registers[3]);
      $display("$4=%0d (Esperado: 20)", dut.id_stage_inst.reg_bank.registers[4]);
      $display("$5=%0d (Esperado: 15)", dut.id_stage_inst.reg_bank.registers[5]);
      $display("$6=%0d (Esperado: 10)", dut.id_stage_inst.reg_bank.registers[6]);
      $display("$7=%0d (Esperado: 10)", dut.id_stage_inst.reg_bank.registers[7]);
      $display("$8=%0d (Esperado: 21)", dut.id_stage_inst.reg_bank.registers[8]);
      $display("$9=%0d (Esperado: 100)", dut.id_stage_inst.reg_bank.registers[9]);
      $display("$10=%0d (Esperado: 15)", dut.id_stage_inst.reg_bank.registers[10]);
      $display("$11=%0d (Esperado: 10)", dut.id_stage_inst.reg_bank.registers[11]);
      $display("$12=%0d (Esperado: 25)", dut.id_stage_inst.reg_bank.registers[12]);
      $display("$13=%0d (Esperado: 5)", dut.id_stage_inst.reg_bank.registers[13]);
      
      // Verificar memoria
      $display("Mem[100]=%0d (Esperado: 15)", dut.mem_stage_inst.memory[25]);
      $display("Mem[104]=%0d (Esperado: 10)", dut.mem_stage_inst.memory[26]);
    end
  end

  // Inyección de debug para exportar la forma de onda
  initial begin
    $dumpfile("register_monitor.vcd");
    $dumpvars(0, register_monitor_tb);
  end

endmodule
