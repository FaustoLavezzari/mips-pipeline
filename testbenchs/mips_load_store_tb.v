`timescale 1ns / 1ps
`include "../src/mips/mips_pkg.vh"

module mips_load_store_tb();

  // Señales para conectar al DUT
  reg clk;
  reg reset;
  reg inst_write_en;        // Nueva señal para escritura de instrucciones
  reg [31:0] inst_write_addr;   // Nueva señal para dirección de escritura
  reg [31:0] inst_write_data;   // Nueva señal para datos de escritura
  wire [`DATA_WIDTH-1:0] result;
  wire halt;  // Agregamos un wire para la señal de halt
  
  // Señal de stall para cargar instrucciones
  reg stall;
  
  // Instancia del módulo MIPS
  mips dut (
    .clk            (clk),
    .reset          (reset),
    .inst_write_en  (inst_write_en),     // Conectamos los nuevos puertos
    .inst_write_addr(inst_write_addr),
    .inst_write_data(inst_write_data),
    .result         (result),
    .halt           (halt),
    .stall          (stall)   
  );
  
  // Genera un reloj de 10ns (100 MHz)
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end
  
  // Variables para el ciclo
  integer cycle_count;
  
  // Variables para cargar instrucciones
  reg [31:0] instructions [0:255]; // Arreglo para almacenar las instrucciones
  integer num_instructions;
  integer i;
  
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
    // Inicialización de señales
    reset = 1;
    stall = 1;              // Iniciar con stall activado
    inst_write_en = 0;
    cycle_count = 0;
    
    // Mostrar encabezado
    $display("\n==== MIPS Pipeline Load/Store Testbench ====\n");
    $display("Este testbench evalúa las instrucciones de carga/almacenamiento");
    $display("La simulación terminará automáticamente cuando la señal halt se active");
    
    // Cargar instrucciones desde el archivo
    $readmemh("/home/fausto/mips-pipeline/instructions/test_load_store_instr.mem", instructions);
    
    // Contar número de instrucciones no vacías (distintas de 32'h0)
    num_instructions = 0;
    for (i = 0; i < 256; i = i + 1) begin
      if (instructions[i] !== 32'h0 && ^instructions[i] !== 1'bx) begin
        num_instructions = num_instructions + 1;
      end
    end
    
    // Liberar el reset después de unos ciclos, pero mantener el stall
    #15;
    reset = 0;

    // Cargar instrucciones una por una
    $display("\n==== Cargando %0d instrucciones en la memoria ====", num_instructions);
    for (i = 0; i < 256; i = i + 1) begin
      // Solo cargar instrucciones válidas (no comentarios o líneas vacías)
      if (instructions[i] !== 32'h0 && ^instructions[i] !== 1'bx) begin
        inst_write_addr = i*4; // Dirección = índice * 4
        inst_write_data = instructions[i];
        inst_write_en = 1;
        $display("Ciclo de carga %0d: Escribiendo instrucción 0x%h en dirección 0x%h", 
                 i+1, inst_write_data, inst_write_addr);
        @(negedge clk);
        // Esperar un ciclo de reloj para que se escriba
      end
    end
    
    inst_write_en = 0;
    
    // Esperar un ciclo más para asegurar que la última instrucción se haya escrito
    @(posedge clk);
    
    $display("\n==== Carga de instrucciones completada, comenzando ejecución ====");
    
    // Desactivar stall para comenzar la ejecución
    stall = 0;
    @(posedge clk);      // ciclo de "llenado" del IF
    @(posedge clk);   
    
    // Esperar hasta que halt sea 1 o hasta un tiempo máximo por seguridad
    fork
      // Opción 1: Terminar cuando halt sea 1
      begin
        wait(halt);
        $display("\n==== Procesador terminado: señal halt detectada (t=%0t ns) ====", $time);
        
        // Añadir un tiempo de espera adicional para asegurar que todos los registros están actualizados
        #20;
        
        // Verificar resultados de los registros
        $display("\n==== VERIFICACIÓN FINAL AL DETECTAR HALT (Ciclo %0d) ====", cycle_count);
        
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
      
      // Opción 2: Tiempo máximo de seguridad
      begin
        #2000;  // Tiempo máximo de seguridad (2000 ns)
        $display("\n==== ADVERTENCIA: Se alcanzó tiempo máximo sin detectar señal halt ====");
        $finish;
      end
    join
  end
  
  // Monitorear el estado del procesador en cada ciclo
  always @(posedge clk) begin
    if (!reset && !stall) begin
      cycle_count = cycle_count + 1;
      
      // Mostrar información del ciclo
      $display("\n==== Ciclo %0d (t=%0t ns) ====", cycle_count, $time);
      
      // Mostrar el estado del pipeline
      $display("IF: PC=%0h, Instr=%0h, Tipo=%s", 
               dut.if_stage_inst.pc_inst.pc,
               dut.if_instr,
               instr_type(dut.if_instr));
               
      $display("ID: Instr=%0h, ALU_Control=%0h", 
               dut.id_instr,
               dut.id_alu_control);
               
      $display("ID_BRANCH_CONTROL: take_branch=%0b, target=0x%h, read_data_1=0x%h", 
               dut.id_take_branch,
               dut.id_branch_target_addr,
               dut.id_read_data_1);
               
      $display("ID_FORWARDING: UseForwardedA=%0b, UseForwardedB=%0b, RS=%0d, RT=%0d", 
               dut.id_use_forwarded_a,
               dut.id_use_forwarded_b,
               dut.id_rs,
               dut.id_rt);
               
      // Mostrar información de memoria en la etapa MEM
      if (dut.mem_mem_write)
        $display("MEM: Store mem[%0h] = 0x%h", 
                dut.mem_alu_result,
                dut.mem_write_data);
      if (dut.mem_mem_read)
        $display("MEM: Load from mem[%0h] = 0x%h", 
                dut.mem_alu_result,
                dut.mem_read_data);

      $display("Halt: %0b", halt);
    end
  end
  
  // Para generar formas de onda (VCD)
  initial begin
    $dumpfile("mips_load_store.vcd");
    $dumpvars(0, mips_load_store_tb);
  end

endmodule
