`timescale 1ns / 1ps

module mips_pipeline_tb();

  // Señales para conectar al DUT (Device Under Test)
  reg clk;
  reg reset;
  wire [31:0] result;
  
  // Contadores y variables de apoyo
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
  
  // Monitoreo del banco de registros
  wire [31:0] reg1 = dut.id_stage_inst.reg_bank.registers[1];  // $1
  wire [31:0] reg2 = dut.id_stage_inst.reg_bank.registers[2];  // $2
  wire [31:0] reg3 = dut.id_stage_inst.reg_bank.registers[3];  // $3
  wire [31:0] reg4 = dut.id_stage_inst.reg_bank.registers[4];  // $4
  wire [31:0] reg5 = dut.id_stage_inst.reg_bank.registers[5];  // $5
  wire [31:0] reg6 = dut.id_stage_inst.reg_bank.registers[6];  // $6
  wire [31:0] reg7 = dut.id_stage_inst.reg_bank.registers[7];  // $7
  wire [31:0] reg8 = dut.id_stage_inst.reg_bank.registers[8];  // $8
  wire [31:0] reg9 = dut.id_stage_inst.reg_bank.registers[9];  // $9
  wire [31:0] reg10 = dut.id_stage_inst.reg_bank.registers[10]; // $10
  wire [31:0] reg11 = dut.id_stage_inst.reg_bank.registers[11]; // $11
  wire [31:0] reg12 = dut.id_stage_inst.reg_bank.registers[12]; // $12
  wire [31:0] reg13 = dut.id_stage_inst.reg_bank.registers[13]; // $13
  
  // Monitoreo de memoria
  wire [31:0] mem_100 = dut.mem_stage_inst.memory[25];  // Memoria[100] (100/4 = 25)
  wire [31:0] mem_104 = dut.mem_stage_inst.memory[26];  // Memoria[104] (104/4 = 26)
  
  // Inicio de la simulación
  initial begin
    // Inicialización de señales
    reset = 1;
    cycle_count = 0;
    
    // Mostrar encabezado
    $display("==== MIPS Pipeline Testbench ====");
    $display("Tiempo\t| Ciclo\t| PC\t| Instrucción\t\t| Etapa IF\t| Etapa ID\t| Etapa EX\t| Etapa MEM\t| Etapa WB");
    
    // Liberar el reset después de unos ciclos
    #15;
    reset = 0;

    // Ejecutar por 20 ciclos
    #1000;
    $finish;
  end
  
  // Monitoreo en cada ciclo
  always @(posedge clk) begin
    if (!reset) begin
      cycle_count = cycle_count + 1;
      
      // Mostrar estado del pipeline en cada ciclo
      $display("t=%0t | %0d\t| %0h | %0h | IF=%0h | ID=%0h | EX=%0h | MEM=%0h | WB=%0h",
                $time,
                cycle_count,
                dut.if_stage_inst.pc_inst.pc,
                dut.if_stage_inst.o_instr,
                dut.if_stage_inst.pc_inst.pc,
                dut.id_instr,
                (dut.ex_alu_result !== 'hx) ? dut.ex_alu_result : 32'h00000000,
                (dut.mem_alu_result !== 'hx) ? dut.mem_alu_result : 32'h00000000,
                (dut.wb_write_data !== 'hx) ? dut.wb_write_data : 32'h00000000
              );
      
      // Mostrar el contenido de los registros cada 5 ciclos
      if (cycle_count % 5 == 0 || cycle_count == 15) begin
        $display("\nEstado de Registros en el ciclo %0d:", cycle_count);
        $display("$1 = %0d, $2 = %0d, $3 = %0d, $4 = %0d, $5 = %0d", reg1, reg2, reg3, reg4, reg5);
        $display("$6 = %0d, $7 = %0d, $8 = %0d, $9 = %0d, $10 = %0d", reg6, reg7, reg8, reg9, reg10);
        $display("$11 = %0d, $12 = %0d, $13 = %0d", reg11, reg12, reg13);
        
        // Mostrar memoria relevante
        $display("\nMemoria en el ciclo %0d:", cycle_count);
        $display("Mem[100] = %0d, Mem[104] = %0d\n", mem_100, mem_104);
      end
      
      // Verificar resultados después de que todas las instrucciones se ejecuten (ciclo 20)
      if (cycle_count == 20) begin
        $display("\n==== Verificación de resultados (ciclo 20) ====");
        $display("$1 = %0d (Esperado: 5)", reg1);
        $display("$2 = %0d (Esperado: 10)", reg2);
        $display("$3 = %0d (Esperado: 15)", reg3);
        $display("$4 = %0d (Esperado: 20)", reg4);
        $display("$5 = %0d (Esperado: 15)", reg5);
        $display("$6 = %0d (Esperado: 10)", reg6);
        $display("$7 = %0d (Esperado: 10)", reg7);
        $display("$8 = %0d (Esperado: 21)", reg8);
        $display("$9 = %0d (Esperado: 100)", reg9);
        $display("$10 = %0d (Esperado: 15)", reg10);
        $display("$11 = %0d (Esperado: 10)", reg11);
        $display("$12 = %0d (Esperado: 25)", reg12);
        $display("$13 = %0d (Esperado: 5)", reg13);
        $display("Mem[100] = %0d (Esperado: 15)", mem_100);
        $display("Mem[104] = %0d (Esperado: 10)", mem_104);
        
        // Verificación de resultados
        if (reg1 == 5 && reg2 == 10 && reg3 == 15 && reg4 == 20 &&
            reg5 == 15 && reg6 == 10 && reg7 == 10 && reg8 == 21 && 
            reg9 == 100 && reg10 == 15 && reg11 == 10 && reg12 == 25 && 
            reg13 == 5 && mem_100 == 15 && mem_104 == 10) begin
          $display("\n¡PRUEBA EXITOSA! Todos los resultados son correctos.");
        end else begin
          $display("\n¡PRUEBA FALLIDA! Algunos resultados no coinciden con los valores esperados.");
        end
      end
    end
  end
  
  // Inyección de debug para mostrar información detallada
  initial begin
    $dumpfile("mips_pipeline.vcd");
    $dumpvars(0, mips_pipeline_tb);
  end

endmodule
