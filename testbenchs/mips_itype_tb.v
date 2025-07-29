`timescale 1ns / 1ps
`include "../src/mips/mips_pkg.vh"

module mips_itype_tb();

  // Señales para conectar al DUT
  reg clk;
  reg reset;
  reg inst_write_en;        // Nueva señal para escritura de instrucciones
  reg [31:0] inst_write_addr;   // Nueva señal para dirección de escritura
  reg [31:0] inst_write_data;   // Nueva señal para datos de escritura
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
  
  // Variables para cargar instrucciones
  reg [31:0] instructions [0:255]; // Arreglo para almacenar las instrucciones
  integer num_instructions;
  integer i;
  
  // Inicio de la simulación
  initial begin
    // Inicialización de señales
    reset = 1;
    stall = 1;              // Iniciar con stall activado
    inst_write_en = 0;
    cycle_count = 0;
    
    // Mostrar encabezado
    $display("\n==== MIPS Pipeline I-Type Instructions Testbench ====\n");
    $display("Este testbench evalúa el funcionamiento de las instrucciones I-Type en el pipeline MIPS");
    $display("La simulación terminará automáticamente cuando la señal halt se active");
    
    // Cargar instrucciones desde el archivo
    $readmemh("/home/fausto/mips-pipeline/instructions/test_itype_instr.mem", instructions);
    
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
    
    // Ejecutar hasta que se detecte la señal de halt o se alcance el tiempo límite de seguridad
    fork
      // Opción 1: Terminar cuando halt sea 1
      begin
        wait(halt);
        $display("\n==== Procesador terminado: señal halt detectada (t=%0t ns) ====", $time);
        // Esperar un ciclo más para asegurar que todas las operaciones en vuelo terminen
        #10;
        do_verification();
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
               
      $display("ID: Instr=%0h, RegDst=%0b, OpCode=%0b, ALUSrcA=%0b, ALUSrcB=%0b, ALU_Control=%0h, RegWrite=%0b", 
               dut.id_instr,
               dut.id_reg_dst,
               dut.id_instr[31:26], // Extract opcode directly from instruction
               dut.id_alu_src_a,
               dut.id_alu_src_b,
               dut.id_alu_control,
               dut.id_reg_write);
               
      $display("EX: ALUinputA=%0d, ALUinputB=%0d, ALUControl=%0d, ALUResult=%0d, RD=%0d, RegWrite=%0b",
               dut.ex_stage_inst.alu_input_a,
               dut.ex_stage_inst.alu_input_b, 
               dut.ex_stage_inst.i_alu_control,
               dut.ex_alu_result,
               dut.ex_write_register,
               dut.ex_reg_write);
      
      // Mostrar información de la unidad de forwarding de ID y EX
      begin
        $display("ID_FORWARDING: UseForwardedA=%0b, UseForwardedB=%0b, RS=%0d, RT=%0d", 
                 dut.id_use_forwarded_a,
                 dut.id_use_forwarded_b,
                 dut.id_rs,
                 dut.id_rt);
                 
        $display("ID_BRANCH_CONTROL: take_branch=%0b, target=0x%h", 
                 dut.id_take_branch,
                 dut.id_branch_target_addr);
                 
        $display("EX_FORWARDING: UseForwardedA=%0b, UseForwardedB=%0b", 
                 dut.ex_use_forwarded_a,
                 dut.ex_use_forwarded_b);
        
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
                 
        // Mostrar contenido de memoria relevante - accediendo por bytes
        $display("Memoria: Mem[0]=%0d, Mem[4]=%0d, Mem[8]=%0d, Mem[16]=%0d, Mem[20]=%0d",
                 {dut.mem_stage_inst.data_mem.memory[3], dut.mem_stage_inst.data_mem.memory[2], 
                  dut.mem_stage_inst.data_mem.memory[1], dut.mem_stage_inst.data_mem.memory[0]},
                 {dut.mem_stage_inst.data_mem.memory[7], dut.mem_stage_inst.data_mem.memory[6], 
                  dut.mem_stage_inst.data_mem.memory[5], dut.mem_stage_inst.data_mem.memory[4]},
                 {dut.mem_stage_inst.data_mem.memory[11], dut.mem_stage_inst.data_mem.memory[10], 
                  dut.mem_stage_inst.data_mem.memory[9], dut.mem_stage_inst.data_mem.memory[8]},
                 {dut.mem_stage_inst.data_mem.memory[19], dut.mem_stage_inst.data_mem.memory[18], 
                  dut.mem_stage_inst.data_mem.memory[17], dut.mem_stage_inst.data_mem.memory[16]},
                 {dut.mem_stage_inst.data_mem.memory[23], dut.mem_stage_inst.data_mem.memory[22], 
                  dut.mem_stage_inst.data_mem.memory[21], dut.mem_stage_inst.data_mem.memory[20]}); 

        $display("Mem[24]=%0d, Mem[28]=%0d, Mem[32]=%0d (valores para pruebas de LB/LH)",
                 {dut.mem_stage_inst.data_mem.memory[27], dut.mem_stage_inst.data_mem.memory[26], 
                  dut.mem_stage_inst.data_mem.memory[25], dut.mem_stage_inst.data_mem.memory[24]},
                 {dut.mem_stage_inst.data_mem.memory[31], dut.mem_stage_inst.data_mem.memory[30], 
                  dut.mem_stage_inst.data_mem.memory[29], dut.mem_stage_inst.data_mem.memory[28]},
                 {dut.mem_stage_inst.data_mem.memory[35], dut.mem_stage_inst.data_mem.memory[34], 
                  dut.mem_stage_inst.data_mem.memory[33], dut.mem_stage_inst.data_mem.memory[32]});
                         
        // Añadir valores para SB y SH
        $display("Mem[36]=%0d / 0x%h (SB - guarda solo un byte)", 
                 {dut.mem_stage_inst.data_mem.memory[39], dut.mem_stage_inst.data_mem.memory[38], 
                  dut.mem_stage_inst.data_mem.memory[37], dut.mem_stage_inst.data_mem.memory[36]},
                 {dut.mem_stage_inst.data_mem.memory[39], dut.mem_stage_inst.data_mem.memory[38], 
                  dut.mem_stage_inst.data_mem.memory[37], dut.mem_stage_inst.data_mem.memory[36]});
        $display("Mem[40]=%0d / 0x%h (SH - guarda solo halfword)", 
                 {dut.mem_stage_inst.data_mem.memory[43], dut.mem_stage_inst.data_mem.memory[42], 
                  dut.mem_stage_inst.data_mem.memory[41], dut.mem_stage_inst.data_mem.memory[40]},
                 {dut.mem_stage_inst.data_mem.memory[43], dut.mem_stage_inst.data_mem.memory[42], 
                  dut.mem_stage_inst.data_mem.memory[41], dut.mem_stage_inst.data_mem.memory[40]});
      end
    end
  end      // Tarea para la verificación final
  task do_verification;
    begin
      $display("\n==== VERIFICACIÓN FINAL (Ciclo %0d) ====", cycle_count);
      $display("Registros finales:");
      // Verificación de resultados ADDI, ADDIU
      $display("$1=%0d (Esperado: 170 - XORI)", 
               dut.id_stage_inst.reg_bank.registers[1]);
      $display("$2=%0d (Esperado: 20 - ADDI)", 
               dut.id_stage_inst.reg_bank.registers[2]);
      $display("$3=%0d (Esperado: 0 - ADDI)", 
               dut.id_stage_inst.reg_bank.registers[3]);
      $display("$4=%0d (Esperado: 16 - ADDI)", 
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
      
      // Usar la misma lógica de acceso a memoria por bytes que usa el módulo data_memory
      // Para Mem[0] (dirección 0) - ahora accediendo byte a byte y mostrando el valor completo de 32 bits
      $display("Mem[0]=%0d (Esperado: 10 - SW)", 
               {dut.mem_stage_inst.data_mem.memory[3], dut.mem_stage_inst.data_mem.memory[2], 
                dut.mem_stage_inst.data_mem.memory[1], dut.mem_stage_inst.data_mem.memory[0]});
                
      // Para Mem[1] (dirección 4) - ahora dirección 4-7
      $display("Mem[4]=%0d (Esperado: 20 - SW)", 
               {dut.mem_stage_inst.data_mem.memory[7], dut.mem_stage_inst.data_mem.memory[6], 
                dut.mem_stage_inst.data_mem.memory[5], dut.mem_stage_inst.data_mem.memory[4]});
                
      // Para Mem[2] (dirección 8) - ahora dirección 8-11
      $display("Mem[8]=%0d (Esperado: -10 - SW)", 
               {dut.mem_stage_inst.data_mem.memory[11], dut.mem_stage_inst.data_mem.memory[10], 
                dut.mem_stage_inst.data_mem.memory[9], dut.mem_stage_inst.data_mem.memory[8]});
                
      // Para Mem[4] (dirección 16) - ahora dirección 16-19
      $display("Mem[16]=%0d (Esperado: 20 - SW con offset)", 
               {dut.mem_stage_inst.data_mem.memory[19], dut.mem_stage_inst.data_mem.memory[18], 
                dut.mem_stage_inst.data_mem.memory[17], dut.mem_stage_inst.data_mem.memory[16]});
                
      // Para Mem[5] (dirección 20) - ahora dirección 20-23
      $display("Mem[20]=%0d (Esperado: 10 - SW con offset)", 
               {dut.mem_stage_inst.data_mem.memory[23], dut.mem_stage_inst.data_mem.memory[22], 
                dut.mem_stage_inst.data_mem.memory[21], dut.mem_stage_inst.data_mem.memory[20]});
                
      // Para Mem[6] (dirección 24) - ahora dirección 24-27
      $display("Mem[24]=%0d (Esperado: 255 - SW con offset)", 
               {dut.mem_stage_inst.data_mem.memory[27], dut.mem_stage_inst.data_mem.memory[26], 
                dut.mem_stage_inst.data_mem.memory[25], dut.mem_stage_inst.data_mem.memory[24]});
                
      // Para Mem[7] (dirección 28) - ahora dirección 28-31
      $display("Mem[28]=%0d (Esperado: 258 - SW con offset)", 
               {dut.mem_stage_inst.data_mem.memory[31], dut.mem_stage_inst.data_mem.memory[30], 
                dut.mem_stage_inst.data_mem.memory[29], dut.mem_stage_inst.data_mem.memory[28]});
                
      // Para Mem[8] (dirección 32) - ahora dirección 32-35
      $display("Mem[32]=%0d (Esperado: -256 - SW con offset)", 
               {dut.mem_stage_inst.data_mem.memory[35], dut.mem_stage_inst.data_mem.memory[34], 
                dut.mem_stage_inst.data_mem.memory[33], dut.mem_stage_inst.data_mem.memory[32]});
                
      // Para Mem[9] (dirección 36) - ahora dirección 36-39
      $display("Mem[36]=%0d / 0x%h (Esperado: 0x000000dc - SB)", 
               {dut.mem_stage_inst.data_mem.memory[39], dut.mem_stage_inst.data_mem.memory[38], 
                dut.mem_stage_inst.data_mem.memory[37], dut.mem_stage_inst.data_mem.memory[36]},
               {dut.mem_stage_inst.data_mem.memory[39], dut.mem_stage_inst.data_mem.memory[38], 
                dut.mem_stage_inst.data_mem.memory[37], dut.mem_stage_inst.data_mem.memory[36]});
                
      // Para Mem[10] (dirección 40) - ahora dirección 40-43
      $display("Mem[40]=%0d / 0x%h (Esperado: 0x000000dc - SH)", 
               {dut.mem_stage_inst.data_mem.memory[43], dut.mem_stage_inst.data_mem.memory[42], 
                dut.mem_stage_inst.data_mem.memory[41], dut.mem_stage_inst.data_mem.memory[40]},
               {dut.mem_stage_inst.data_mem.memory[43], dut.mem_stage_inst.data_mem.memory[42], 
                dut.mem_stage_inst.data_mem.memory[41], dut.mem_stage_inst.data_mem.memory[40]});
      
      // Verificar si todas las instrucciones funcionan correctamente
      // Actualizar las comparaciones de memoria para usar las direcciones de byte correctas
      if (dut.id_stage_inst.reg_bank.registers[1] == 170 &&
          dut.id_stage_inst.reg_bank.registers[2] == 20 &&
          dut.id_stage_inst.reg_bank.registers[3] == 0 &&
          dut.id_stage_inst.reg_bank.registers[4] == 16 &&
          dut.id_stage_inst.reg_bank.registers[5] == 40 &&
          dut.id_stage_inst.reg_bank.registers[6] == 0 &&
          dut.id_stage_inst.reg_bank.registers[7] == 7 &&
          dut.id_stage_inst.reg_bank.registers[8] == 0 &&  // SLTIU
          dut.id_stage_inst.reg_bank.registers[9] == 32'h12340000 &&  // LUI
          dut.id_stage_inst.reg_bank.registers[10] == 32'hFFFFFF00 &&  // LH (-256)
          dut.id_stage_inst.reg_bank.registers[11] == 65280 && // LHU
          dut.id_stage_inst.reg_bank.registers[12] == 10 &&
          dut.id_stage_inst.reg_bank.registers[13] == 20 &&
          dut.id_stage_inst.reg_bank.registers[14] == 32'hFFFFFFF6 &&  // -10
          dut.id_stage_inst.reg_bank.registers[15] == 20 &&
          dut.id_stage_inst.reg_bank.registers[16] == 10 &&
          dut.id_stage_inst.reg_bank.registers[17] == 220 &&  // SB (0xAA) - verificación SB
          dut.id_stage_inst.reg_bank.registers[18] == 220 &&  // SH (0xAA) - verificación SH
          dut.id_stage_inst.reg_bank.registers[19] == 100 && // Jump
          dut.id_stage_inst.reg_bank.registers[20] == 15 && // JAL
          dut.id_stage_inst.reg_bank.registers[21] == 255 &&
          dut.id_stage_inst.reg_bank.registers[22] == 32'hABCD0000 && // LUI
          dut.id_stage_inst.reg_bank.registers[23] == 32'hFFFFFFFF && // LB (-1)
          dut.id_stage_inst.reg_bank.registers[24] == 255 && // LBU
          dut.id_stage_inst.reg_bank.registers[25] == 258 &&
          dut.id_stage_inst.reg_bank.registers[26] == 258 && // LH
          dut.id_stage_inst.reg_bank.registers[27] == 258 && // LHU
          dut.id_stage_inst.reg_bank.registers[28] == 258 && // LW
          dut.id_stage_inst.reg_bank.registers[29] == 258 && // LWU
          dut.id_stage_inst.reg_bank.registers[30] == 32'hFFFFFF00 &&  // -256
          dut.id_stage_inst.reg_bank.registers[31] == 220 && 
          {dut.mem_stage_inst.data_mem.memory[3], dut.mem_stage_inst.data_mem.memory[2], 
           dut.mem_stage_inst.data_mem.memory[1], dut.mem_stage_inst.data_mem.memory[0]} == 10 &&
          {dut.mem_stage_inst.data_mem.memory[7], dut.mem_stage_inst.data_mem.memory[6], 
           dut.mem_stage_inst.data_mem.memory[5], dut.mem_stage_inst.data_mem.memory[4]} == 20 &&
          {dut.mem_stage_inst.data_mem.memory[11], dut.mem_stage_inst.data_mem.memory[10], 
           dut.mem_stage_inst.data_mem.memory[9], dut.mem_stage_inst.data_mem.memory[8]} == 32'hFFFFFFF6 &&  // -10
          {dut.mem_stage_inst.data_mem.memory[19], dut.mem_stage_inst.data_mem.memory[18], 
           dut.mem_stage_inst.data_mem.memory[17], dut.mem_stage_inst.data_mem.memory[16]} == 20 &&
          {dut.mem_stage_inst.data_mem.memory[23], dut.mem_stage_inst.data_mem.memory[22], 
           dut.mem_stage_inst.data_mem.memory[21], dut.mem_stage_inst.data_mem.memory[20]} == 10 &&
          {dut.mem_stage_inst.data_mem.memory[27], dut.mem_stage_inst.data_mem.memory[26], 
           dut.mem_stage_inst.data_mem.memory[25], dut.mem_stage_inst.data_mem.memory[24]} == 255 &&
          {dut.mem_stage_inst.data_mem.memory[31], dut.mem_stage_inst.data_mem.memory[30], 
           dut.mem_stage_inst.data_mem.memory[29], dut.mem_stage_inst.data_mem.memory[28]} == 258 &&
          {dut.mem_stage_inst.data_mem.memory[35], dut.mem_stage_inst.data_mem.memory[34], 
           dut.mem_stage_inst.data_mem.memory[33], dut.mem_stage_inst.data_mem.memory[32]} == 32'hFFFFFF00 &&  // -256
          {dut.mem_stage_inst.data_mem.memory[39], dut.mem_stage_inst.data_mem.memory[38], 
           dut.mem_stage_inst.data_mem.memory[37], dut.mem_stage_inst.data_mem.memory[36]} == 220 && // SB
          {dut.mem_stage_inst.data_mem.memory[43], dut.mem_stage_inst.data_mem.memory[42], 
           dut.mem_stage_inst.data_mem.memory[41], dut.mem_stage_inst.data_mem.memory[40]} == 220  // SH
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
  endtask

  // Para generar formas de onda (VCD)
  initial begin
    $dumpfile("mips_itype.vcd");
    $dumpvars(0, mips_itype_tb);
  end

endmodule
