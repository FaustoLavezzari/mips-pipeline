`timescale 1ns / 1ps
`include "../src/mips/mips_pkg.vh"

module mips_load_store_tb_sm();

  // Señales para conectar al DUT
  reg clk;
  reg reset;
  reg inst_write_en;        // Señal para escritura de instrucciones
  reg [31:0] inst_write_addr;   // Dirección de escritura
  reg [31:0] inst_write_data;   // Datos de escritura
  wire [`DATA_WIDTH-1:0] result;
  wire halt;  // Señal de halt
  
  // Señal de stall para control del pipeline
  reg stall;
  
  // Señales para acceso a registros
  reg [4:0] reg_addr;
  wire [31:0] reg_data;

  // Señales para debug de memoria
  reg [31:0] mem_debug_addr;
  wire [31:0] mem_debug_data;

  // Variables para la máquina de estados
  reg [3:0] state;
  reg [3:0] next_state;
  
  // Estados de la máquina
  localparam RESET_STATE = 0;
  localparam LOAD_INSTR_STATE = 1;
  localparam RUN_CYCLE_STATE = 2;
  localparam STALL_STATE = 3;
  localparam READ_REG_STATE = 4;
  localparam PRINT_STATE = 5;
  localparam CHECK_END_STATE = 6;
  localparam END_STATE = 7;
  localparam READ_MEM_STATE = 8;
  
  // Arreglo para almacenar valores de registros
  reg [31:0] register_values [0:31];
  integer reg_index;

  // Arreglo para almacenar valores de memoria debug
  reg [31:0] mem_values [0:3]; // 4 direcciones usadas en el testbench
  integer mem_index;
  reg [31:0] mem_addrs [0:3];
  
  // Variables para el ciclo
  integer cycle_count;
  
  // Variables para cargar instrucciones una por una
  reg found_instruction;
  integer current_index;
  
  // Señales para debug de latches del pipeline
  wire [31:0] if_id_instr, if_id_next_pc;
  wire [31:0] id_ex_read_data1, id_ex_read_data2, id_ex_sign_ext_imm, id_ex_shamt, id_ex_next_pc;
  wire [4:0] id_ex_rs, id_ex_rt, id_ex_rd;
  wire id_ex_reg_dst, id_ex_alu_src_b, id_ex_mem_read, id_ex_mem_write, id_ex_reg_write, id_ex_mem_to_reg;
  wire id_ex_is_halt, id_ex_is_signed_load;
  wire [1:0] id_ex_alu_src_a;
  wire [3:0] id_ex_alu_control, id_ex_byte_mask;
  wire [31:0] ex_mem_alu_result, ex_mem_write_data;
  wire [4:0] ex_mem_write_reg;
  wire ex_mem_reg_write, ex_mem_mem_read, ex_mem_mem_write, ex_mem_mem_to_reg;
  wire ex_mem_is_halt, ex_mem_is_signed_load;
  wire [3:0] ex_mem_byte_mask;
  wire [31:0] mem_wb_alu_result, mem_wb_read_data;
  wire [4:0] mem_wb_write_reg;
  wire mem_wb_reg_write, mem_wb_mem_to_reg, mem_wb_is_halt;

  // Instancia del módulo MIPS
  mips dut (
    .clk            (clk),
    .reset          (reset),
    .inst_write_en  (inst_write_en),
    .inst_write_addr(inst_write_addr),
    .inst_write_data(inst_write_data),
    .result         (result),
    .halt           (halt),
    .stall          (stall),
    .reg_addr       (reg_addr),
    .reg_data       (reg_data),
    .mem_debug_addr (mem_debug_addr),
    .mem_debug_data (mem_debug_data),
    
    // Conexiones para debug de latches
    .debug_if_id_instr        (if_id_instr),
    .debug_if_id_next_pc      (if_id_next_pc),
    
    .debug_id_ex_read_data1   (id_ex_read_data1),
    .debug_id_ex_read_data2   (id_ex_read_data2),
    .debug_id_ex_sign_ext_imm (id_ex_sign_ext_imm),
    .debug_id_ex_rs           (id_ex_rs),
    .debug_id_ex_rt           (id_ex_rt),
    .debug_id_ex_rd           (id_ex_rd),
    .debug_id_ex_shamt        (id_ex_shamt),
    .debug_id_ex_next_pc      (id_ex_next_pc),
    .debug_id_ex_reg_dst      (id_ex_reg_dst),
    .debug_id_ex_alu_src_b    (id_ex_alu_src_b),
    .debug_id_ex_alu_src_a    (id_ex_alu_src_a),
    .debug_id_ex_alu_control  (id_ex_alu_control),
    .debug_id_ex_mem_read     (id_ex_mem_read),
    .debug_id_ex_mem_write    (id_ex_mem_write),
    .debug_id_ex_reg_write    (id_ex_reg_write),
    .debug_id_ex_mem_to_reg   (id_ex_mem_to_reg),
    .debug_id_ex_is_halt      (id_ex_is_halt),
    .debug_id_ex_byte_mask    (id_ex_byte_mask),
    .debug_id_ex_is_signed_load (id_ex_is_signed_load),
    
    .debug_ex_mem_alu_result  (ex_mem_alu_result),
    .debug_ex_mem_write_data  (ex_mem_write_data),
    .debug_ex_mem_write_reg   (ex_mem_write_reg),
    .debug_ex_mem_reg_write   (ex_mem_reg_write),
    .debug_ex_mem_mem_read    (ex_mem_mem_read),
    .debug_ex_mem_mem_write   (ex_mem_mem_write),
    .debug_ex_mem_mem_to_reg  (ex_mem_mem_to_reg),
    .debug_ex_mem_is_halt     (ex_mem_is_halt),
    .debug_ex_mem_byte_mask   (ex_mem_byte_mask),
    .debug_ex_mem_is_signed_load (ex_mem_is_signed_load),
    
    .debug_mem_wb_alu_result  (mem_wb_alu_result),
    .debug_mem_wb_read_data   (mem_wb_read_data),
    .debug_mem_wb_write_reg   (mem_wb_write_reg),
    .debug_mem_wb_reg_write   (mem_wb_reg_write),
    .debug_mem_wb_mem_to_reg  (mem_wb_mem_to_reg),
    .debug_mem_wb_is_halt     (mem_wb_is_halt)
  );
  
  // Genera un reloj de 10ns (100 MHz)
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end
  
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
  
  // Variables para cargar instrucciones
  reg [31:0] instructions [0:255]; // Arreglo para almacenar las instrucciones
  integer num_instructions;
  integer i;
  integer instr_loaded;
  
  // Inicio de la simulación
  initial begin
    // Inicialización de señales
    reset = 1;
    stall = 1;
    inst_write_en = 0;
    cycle_count = 0;
    state = RESET_STATE;
    next_state = RESET_STATE;
    reg_index = 0;
    instr_loaded = 0;
    mem_index = 0;
    // Direcciones de memoria relevantes (usadas en el testbench)
    mem_addrs[0] = 100;
    mem_addrs[1] = 104;
    mem_addrs[2] = 35;
    mem_addrs[3] = 39;

    mem_values[0] = 0; // Inicializar valores de memoria
    mem_values[1] = 0;
    mem_values[2] = 0;  
    mem_values[3] = 0;
    
    // Cargar instrucciones desde el archivo
    $readmemh("/home/fausto/mips-pipeline/instructions/test_load_store_instr.mem", instructions);
    
    // Contar número de instrucciones válidas (incluyendo NOPs, excluyendo solo indefinidas)
    num_instructions = 0;
    for (i = 0; i < 256; i = i + 1) begin
      if (^instructions[i] !== 1'bx) begin
        num_instructions = num_instructions + 1;
      end
    end
    
    // Mostrar encabezado
    $display("\n==== MIPS Pipeline Load/Store Testbench con Máquina de Estados ====\n");
    $display("Este testbench evalúa las instrucciones de carga/almacenamiento");
    $display("En cada ciclo se hará una pausa para leer el estado de los registros");
    $display("La simulación terminará automáticamente cuando la señal halt se active");
  end
  
  // Lógica secuencial de la máquina de estados
  always @(posedge clk) begin
    state <= next_state;
  end
  
  // Lógica combinacional de la máquina de estados
  always @(*) begin
    case(state)
      RESET_STATE: begin
        // Estado inicial: reset, y después pasar a carga de instrucciones
        if (cycle_count >= 3) begin
          next_state = LOAD_INSTR_STATE;
        end else begin
          next_state = RESET_STATE;
        end
      end
      
      LOAD_INSTR_STATE: begin
        // Cargar instrucciones una por una
        if (instr_loaded < num_instructions) begin
          next_state = LOAD_INSTR_STATE;
        end else begin
          // Terminamos de cargar las instrucciones, iniciar ejecución
          next_state = RUN_CYCLE_STATE;
        end
      end
      
      RUN_CYCLE_STATE: begin
        // Ejecutar un ciclo del pipeline
        next_state = STALL_STATE;
      end
      
      STALL_STATE: begin
        // Hacer stall para comenzar a leer registros
        next_state = READ_REG_STATE;
      end
      
      READ_REG_STATE: begin
        // Leer registros uno por ciclo
        if (reg_index < 31) begin
          next_state = READ_REG_STATE;
        end else begin
          next_state = PRINT_STATE;
        end
      end
      
      PRINT_STATE: begin
        // Imprimir estado del pipeline con los valores leídos
        next_state = READ_MEM_STATE;
      end
      
      READ_MEM_STATE: begin
        // Leer memoria una dirección por ciclo
        if (mem_index < 3) begin
          next_state = READ_MEM_STATE;
        end else begin
          next_state = CHECK_END_STATE;
        end
      end
      
      CHECK_END_STATE: begin
        // Verificar si debemos terminar o continuar
        if (halt) begin
          next_state = END_STATE;
        end else begin
          next_state = RUN_CYCLE_STATE;
        end
      end
      
      END_STATE: begin
        // Estado final, mantenerse aquí
        next_state = END_STATE;
      end
      
      default: begin
        next_state = RESET_STATE;
      end
    endcase
  end
  
  // Lógica de salidas para cada estado
  always @(posedge clk) begin
    case(state)
      RESET_STATE: begin
        reset <= 1;
        stall <= 1;
        inst_write_en <= 0;
        reg_addr <= 0;
        cycle_count <= cycle_count + 1;
        
        if (cycle_count == 3) begin
          reset <= 0;
          $display("\n==== Reset completado, comenzando carga de instrucciones ====");
        end
      end
      
      LOAD_INSTR_STATE: begin
        reset <= 0;
        stall <= 1;  // Mantener stall durante carga
        
        // Cargar la siguiente instrucción
        if (instr_loaded < num_instructions) begin
          // Cargar instrucción directamente usando el índice instr_loaded
          inst_write_addr <= instr_loaded*4;
          inst_write_data <= instructions[instr_loaded];
          inst_write_en <= 1;
          if (instructions[instr_loaded] !== 32'h0) begin
            $display("Ciclo de carga %0d: Escribiendo instrucción 0x%h en dirección 0x%h", 
                    instr_loaded+1, instructions[instr_loaded], instr_loaded*4);
          end else begin
            $display("Ciclo de carga %0d: Escribiendo NOP (0x00000000) en dirección 0x%h", 
                    instr_loaded+1, instr_loaded*4);
          end
          instr_loaded <= instr_loaded + 1;
        end else begin
          // Ya cargamos todas las instrucciones
          inst_write_en <= 0;
          // Reiniciar el contador de ciclos para empezar desde 1
          cycle_count <= 0;
          $display("\n==== Carga de instrucciones completada, comenzando ejecución ====");
        end
      end
      
      RUN_CYCLE_STATE: begin
        // Dejar el pipeline avanzar un ciclo
        reset <= 0;
        stall <= 0;
        inst_write_en <= 0;
        
        // Incrementar contador de ciclos (ahora empezará en 1 para el primer ciclo)
        cycle_count <= cycle_count + 1;
      end
      
      STALL_STATE: begin
        // Hacer stall al pipeline para leer registros
        reset <= 0;
        stall <= 1;
        inst_write_en <= 0;
        
        // Reiniciar índice para leer registros
        reg_index <= 0;
        reg_addr <= 0;
      end
      
      READ_REG_STATE: begin
        // Seguimos en stall mientras leemos los registros
        reset <= 0;
        stall <= 1;
        inst_write_en <= 0;
        
        // Guardar el valor leído en el ciclo anterior
        register_values[reg_index] <= reg_data;
        
        // Preparar para leer el siguiente registro
        reg_index <= reg_index + 1;
        reg_addr <= reg_index + 1;
      end
      
      PRINT_STATE: begin
        // Seguimos en stall mientras mostramos resultados
        reset <= 0;
        stall <= 1;
        inst_write_en <= 0;
        
        // Mostrar información del ciclo
        $display("\n==== Ciclo %0d (t=%0t ns) ====", cycle_count, $time);
        
        // Mostrar el estado del pipeline usando solo señales de debug de los latches
        // Etapa IF/ID
        $display("IF/ID:");
        $display("  Instr=%0h, Tipo=%s", 
                if_id_instr,
                instr_type(if_id_instr));
        $display("  PC+4=%0h", if_id_next_pc);
        
        // Etapa ID/EX
        $display("\nID/EX:");
        $display("  RS=%0d (val=%0d), RT=%0d (val=%0d), RD=%0d", 
                id_ex_rs, id_ex_read_data1, id_ex_rt, id_ex_read_data2, id_ex_rd);
        $display("  Imm=0x%h, Shamt=0x%h, NextPC=0x%h", id_ex_sign_ext_imm, id_ex_shamt, id_ex_next_pc);
        $display("  Control: RegDst=%0b, ALUSrcA=%0b, ALUSrcB=%0b, ALUControl=%0h", 
                id_ex_reg_dst, id_ex_alu_src_a, id_ex_alu_src_b, id_ex_alu_control);
        $display("  MEM: MemRead=%0b, MemWrite=%0b, ByteMask=0x%h, IsSignedLoad=%0b", 
                id_ex_mem_read, id_ex_mem_write, id_ex_byte_mask, id_ex_is_signed_load);
        $display("  WB: RegWrite=%0b, MemToReg=%0b, IsHalt=%0b", 
                id_ex_reg_write, id_ex_mem_to_reg, id_ex_is_halt);
        
        // Etapa EX/MEM
        $display("\nEX/MEM:");
        $display("  ALUResult=%0d, WriteData=%0d, WriteReg=%0d", 
                ex_mem_alu_result, ex_mem_write_data, ex_mem_write_reg);
        $display("  MEM: MemRead=%0b, MemWrite=%0b, ByteMask=0x%h, IsSignedLoad=%0b", 
                ex_mem_mem_read, ex_mem_mem_write, ex_mem_byte_mask, ex_mem_is_signed_load);
        $display("  WB: RegWrite=%0b, MemToReg=%0b, IsHalt=%0b", 
                ex_mem_reg_write, ex_mem_mem_to_reg, ex_mem_is_halt);
        
        // Mostrar información específica para load/store
        if (ex_mem_mem_write) begin
          $display("  STORE: mem[%0h] = 0x%h", ex_mem_alu_result, ex_mem_write_data);
        end
        if (ex_mem_mem_read) begin
          $display("  LOAD: from mem[%0h]", ex_mem_alu_result);
        end
        
        // Etapa MEM/WB
        $display("\nMEM/WB:");
        $display("  ALUResult=%0d, ReadData=%0d, WriteReg=%0d", 
                mem_wb_alu_result, mem_wb_read_data, mem_wb_write_reg);
        $display("  WB: RegWrite=%0b, MemToReg=%0b, IsHalt=%0b", 
                mem_wb_reg_write, mem_wb_mem_to_reg, mem_wb_is_halt);
        
        // Resumen de registros de destino en cada etapa
        $display("\nPipeline Registers:");
        $display("  ID/EX: Rs=%0d, Rt=%0d, Rd=%0d", id_ex_rs, id_ex_rt, id_ex_rd);
        $display("  EX/MEM: Rd=%0d", ex_mem_write_reg);
        $display("  MEM/WB: Rd=%0d", mem_wb_write_reg);
        
        // Mostrar estado de registros
        $display("\n==== Estado de Registros (Ciclo %0d) ====", cycle_count);
        $display("$0=%0d, $1=0x%h, $2=0x%h, $3=0x%h", register_values[0], register_values[1], register_values[2], register_values[3]);
        $display("$4=0x%h, $5=0x%h, $6=0x%h, $7=0x%h", register_values[4], register_values[5], register_values[6], register_values[7]);
        $display("$8=0x%h, $9=0x%h, $10=0x%h, $11=0x%h", register_values[8], register_values[9], register_values[10], register_values[11]);
        $display("$12=0x%h, $13=0x%h, $14=0x%h, $15=0x%h", register_values[12], register_values[13], register_values[14], register_values[15]);
        $display("$16=0x%h, $17=0x%h, $18=0x%h, $19=0x%h", register_values[16], register_values[17], register_values[18], register_values[19]);
        $display("$20=0x%h, $21=0x%h, $22=0x%h, $23=0x%h", register_values[20], register_values[21], register_values[22], register_values[23]);
        $display("$24=0x%h, $25=0x%h, $26=0x%h, $27=0x%h", register_values[24], register_values[25], register_values[26], register_values[27]);
        $display("$28=0x%h, $29=0x%h, $30=0x%h, $31=0x%h", register_values[28], register_values[29], register_values[30], register_values[31]);
        // Mostrar estado de memoria relevante
        $display("\n==== Estado de Memoria (Ciclo %0d) ====", cycle_count);
        $display("Mem[%0d]=%0d (hex: 0x%h)", mem_addrs[0], mem_values[0], mem_values[0]);
        $display("Mem[%0d]=%0d (hex: 0x%h)", mem_addrs[1], mem_values[1], mem_values[1]);
        $display("Mem[%0d]=%0d (hex: 0x%h)", mem_addrs[2], mem_values[2], mem_values[2]);
        $display("Mem[%0d]=%0d (hex: 0x%h)", mem_addrs[3], mem_values[3], mem_values[3]);
        // Preparar para leer memoria
        mem_index <= 0;
        mem_debug_addr <= mem_addrs[0];
      end
      READ_MEM_STATE: begin
        // Leer memoria una dirección por ciclo
        mem_values[mem_index] <= mem_debug_data;
        mem_index <= mem_index + 1;
        if (mem_index < 3) begin
          mem_debug_addr <= mem_addrs[mem_index + 1];
        end
        // (No imprimir aquí)
      end
      CHECK_END_STATE: begin
        if (halt) begin
          $display("\n==== Procesador terminado: señal halt detectada (t=%0t ns) ====", $time);
          
          // Verificación final de resultados
          $display("\n==== VERIFICACIÓN FINAL AL DETECTAR HALT (Ciclo %0d) ====", cycle_count);
          
          // Test SB, LB, LBU
          $display("\n=== TEST SB, LB, LBU ===");
          $display("$1 = 0x%h (Esperado: 0x000000FF)", register_values[1]);
          $display("$2 = 0x%h (Esperado: 0x000000FF sin signo)", register_values[2]);
          $display("$3 = 0x%h (Esperado: 0xFFFFFFFF con signo)", register_values[3]);

          // Test SH, LH, LHU (positivo)
          $display("\n=== TEST SH, LH, LHU (positivo) ===");
          $display("$4 = 0x%h (Esperado: 0x00001234)", register_values[4]);
          $display("$5 = 0x%h (Esperado: 0x00001234 sin signo)", register_values[5]);
          $display("$6 = 0x%h (Esperado: 0x00001234 con signo)", register_values[6]);

          // Test SH, LH, LHU (negativo)
          $display("\n=== TEST SH, LH, LHU (negativo) ===");
          $display("$13 = 0x%h (Esperado: 0xFFFFCFC7)", register_values[13]);
          $display("$14 = 0x%h (Esperado: 0xFFFFCFC7 con signo)", register_values[14]);
          $display("$15 = 0x%h (Esperado: 0x0000CFC7 sin signo)", register_values[15]);

          // Test SW, LW, LWU (positivo)
          $display("\n=== TEST SW, LW, LWU (positivo) ===");
          $display("$7 = 0x%h (Esperado: 0x00005678)", register_values[7]);
          $display("$8 = 0x%h (Esperado: 0x00005678)", register_values[8]);
          $display("$9 = 0x%h (Esperado: 0x00005678)", register_values[9]);

          // Test SW, LW, LWU (negativo)
          $display("\n=== TEST SW, LW, LWU (negativo) ===");
          $display("$10 = 0x%h (Esperado: 0xFFFFFFFF)", register_values[10]);
          $display("$11 = 0x%h (Esperado: 0xFFFFFFFF con signo)", register_values[11]);
          $display("$12 = 0x%h (Esperado: 0xFFFFFFFF sin signo)", register_values[12]);

          // Test SB, LB, LBU (negativo)
          $display("\n=== TEST SB, LB, LBU (negativo) ===");
          $display("$16 = 0x%h (Esperado: 0xFFFFFFFE)", register_values[16]);
          $display("$17 = 0x%h (Esperado: 0x000000FE sin signo)", register_values[17]);
          $display("$18 = 0x%h (Esperado: 0xFFFFFFFE con signo)", register_values[18]);

          // Verificación global de resultados
          if (register_values[1] == 32'h000000FF &&
              register_values[2] == 32'h000000FF &&
              register_values[3] == 32'hFFFFFFFF &&
              register_values[4] == 32'h00001234 &&
              register_values[5] == 32'h00001234 &&
              register_values[6] == 32'h00001234 &&
              register_values[7] == 32'h00005678 &&
              register_values[8] == 32'h00005678 &&
              register_values[9] == 32'h00005678 &&
              register_values[10] == 32'hFFFFFFFF &&
              register_values[11] == 32'hFFFFFFFF &&
              register_values[12] == 32'hFFFFFFFF &&
              register_values[13] == 32'hFFFFCFC7 &&
              register_values[14] == 32'hFFFFCFC7 &&
              register_values[15] == 32'h0000CFC7 &&
              register_values[16] == 32'hFFFFFFFE &&
              register_values[17] == 32'h000000FE &&
              register_values[18] == 32'hFFFFFFFE) begin
            $display("\n¡TEST EXITOSO! Las instrucciones de carga/almacenamiento funcionan correctamente");
          end else begin
            $display("\n¡TEST FALLIDO! Las instrucciones de carga/almacenamiento no funcionan como se esperaba");
          end
          
          $finish;
        end
      end
      
      END_STATE: begin
        // No hacer nada, esperar a que termine la simulación
      end
    endcase
  end

  // Para generar formas de onda (VCD)
  initial begin
    $dumpfile("mips_load_store_sm.vcd");
    $dumpvars(0, mips_load_store_tb_sm);
  end

endmodule
