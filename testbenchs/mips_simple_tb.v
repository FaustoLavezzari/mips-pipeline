`timescale 1ns / 1ps
`include "../src/mips/mips_pkg.vh"

module mips_simple_tb();

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
    .halt           (halt),  // Conectamos la señal de halt para detectar fin de ejecución
    .stall          (stall)  // Usamos stall para cargar instrucciones
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
    $display("\n==== MIPS Pipeline Simple Testbench con Forwarding Unit ====\n");
    $display("Este testbench evalúa el funcionamiento del pipeline MIPS");
    $display("La simulación terminará automáticamente cuando la señal halt se active");
    
    // Cargar instrucciones desde el archivo
    $readmemh("/home/fausto/mips-pipeline/instructions/test_instr.mem", instructions);
    
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
    
    // Esperar hasta que halt sea 1 o hasta un tiempo máximo por seguridad
    fork
      // Opción 1: Terminar cuando halt sea 1
      begin
        wait(halt);
        $display("\n==== Procesador terminado: señal halt detectada (t=%0t ns) ====", $time);
        
        // Realizar la verificación final al detectar halt
        $display("\n==== VERIFICACIÓN FINAL AL DETECTAR HALT (Ciclo %0d) ====", cycle_count);
        $display("Registros finales:");
        $display("$1=%0d (Esperado: 5)", 
               dut.id_stage_inst.reg_bank.registers[1]);
        $display("$2=%0d (Esperado: 10)", 
               dut.id_stage_inst.reg_bank.registers[2]);
        $display("$3=%0d (Esperado: 100)", 
               dut.id_stage_inst.reg_bank.registers[3]);
        $display("$4=%0d (Esperado: 20)", 
               dut.id_stage_inst.reg_bank.registers[4]);
        $display("$5=%0d (Esperado: 5)", 
               dut.id_stage_inst.reg_bank.registers[5]);
        $display("$6=%0d (Esperado: 5)", 
               dut.id_stage_inst.reg_bank.registers[6]);
        $display("$7=%0d (Esperado: 10)", 
               dut.id_stage_inst.reg_bank.registers[7]);
        $display("$8=%0d (Esperado: 39)", 
               dut.id_stage_inst.reg_bank.registers[8]);
        $display("$9=%0d (Esperado: 1)", 
               dut.id_stage_inst.reg_bank.registers[9]);
        $display("$10=%0d", dut.id_stage_inst.reg_bank.registers[10]);
        $display("$11=%0d (Esperado: 5)", 
               dut.id_stage_inst.reg_bank.registers[11]);
        $display("$12=%0d (Esperado: 10)", 
               dut.id_stage_inst.reg_bank.registers[12]);
        $display("$13=%0d (Esperado: 0)", 
               dut.id_stage_inst.reg_bank.registers[13]);
        $display("$14=%0d (Esperado: 7)", 
               dut.id_stage_inst.reg_bank.registers[14]);
        $display("$15=%0d (Esperado: 20)", 
               dut.id_stage_inst.reg_bank.registers[15]);
               
        // Verificar memoria - accediendo por bytes como en data_memory.v
        $display("\nMemoria final:");
        $display("Mem[100]=%0d (Esperado: 5)", 
               {dut.mem_stage_inst.data_mem.memory[103], dut.mem_stage_inst.data_mem.memory[102], 
                dut.mem_stage_inst.data_mem.memory[101], dut.mem_stage_inst.data_mem.memory[100]});
        $display("Mem[104]=%0d (Esperado: 5)", 
               {dut.mem_stage_inst.data_mem.memory[107], dut.mem_stage_inst.data_mem.memory[106], 
                dut.mem_stage_inst.data_mem.memory[105], dut.mem_stage_inst.data_mem.memory[104]});
        $display("Mem[35]=%0d (Esperado: 15)", 
               {dut.mem_stage_inst.data_mem.memory[38], dut.mem_stage_inst.data_mem.memory[37], 
                dut.mem_stage_inst.data_mem.memory[36], dut.mem_stage_inst.data_mem.memory[35]});
        $display("Mem[39]=%0d (Esperado: 35)", 
               {dut.mem_stage_inst.data_mem.memory[42], dut.mem_stage_inst.data_mem.memory[41], 
                dut.mem_stage_inst.data_mem.memory[40], dut.mem_stage_inst.data_mem.memory[39]});
               
        // Verificar resultado
        if (dut.id_stage_inst.reg_bank.registers[1] == 5 &&
            dut.id_stage_inst.reg_bank.registers[2] == 10 &&
            dut.id_stage_inst.reg_bank.registers[3] == 100 &&
            dut.id_stage_inst.reg_bank.registers[4] == 20 &&
            dut.id_stage_inst.reg_bank.registers[5] == 5 &&
            dut.id_stage_inst.reg_bank.registers[6] == 5 &&
            dut.id_stage_inst.reg_bank.registers[7] == 10 &&
            dut.id_stage_inst.reg_bank.registers[8] == 39 &&
            dut.id_stage_inst.reg_bank.registers[9] == 1 &&
            dut.id_stage_inst.reg_bank.registers[11] == 5 &&
            dut.id_stage_inst.reg_bank.registers[12] == 10 &&
            dut.id_stage_inst.reg_bank.registers[13] == 0 &&
            dut.id_stage_inst.reg_bank.registers[14] == 7 &&
            dut.id_stage_inst.reg_bank.registers[15] == 20 &&
            {dut.mem_stage_inst.data_mem.memory[103], dut.mem_stage_inst.data_mem.memory[102], 
             dut.mem_stage_inst.data_mem.memory[101], dut.mem_stage_inst.data_mem.memory[100]} == 5 &&
            {dut.mem_stage_inst.data_mem.memory[107], dut.mem_stage_inst.data_mem.memory[106], 
             dut.mem_stage_inst.data_mem.memory[105], dut.mem_stage_inst.data_mem.memory[104]} == 5 &&
            {dut.mem_stage_inst.data_mem.memory[38], dut.mem_stage_inst.data_mem.memory[37], 
             dut.mem_stage_inst.data_mem.memory[36], dut.mem_stage_inst.data_mem.memory[35]} == 15 &&
            {dut.mem_stage_inst.data_mem.memory[42], dut.mem_stage_inst.data_mem.memory[41], 
             dut.mem_stage_inst.data_mem.memory[40], dut.mem_stage_inst.data_mem.memory[39]} == 35) begin
          $display("\n¡PRUEBA EXITOSA! Todos los resultados son correctos.");
          $display("\nLa unidad de forwarding ha manejado correctamente los riesgos de datos resolubles.");
          $display("Los NOPs insertados han ayudado a evitar los riesgos no resolubles mediante forwarding.");
          $display("(Principalmente: load-use hazards y dependencias EX-EX que requieren stalls)");
        end else begin
          $display("\n¡PRUEBA FALLIDA! Algunos resultados no coinciden con los valores esperados.");
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
  
  // Imprime el estado de cada etapa en cada ciclo
  always @(negedge clk) begin
    if (!reset && !stall) begin
      cycle_count = cycle_count + 1;
      
      // Mostrar información del ciclo
      $display("\n==== Ciclo %0d (t=%0t ns) ====", cycle_count, $time);
      
      // Mostrar el estado del pipeline
      $display("IF: PC=%0h, Instr=%0h, Tipo=%s", 
               dut.if_stage_inst.pc_inst.pc,
               dut.if_instr,
               instr_type(dut.if_instr));
      
        $display("ID: Instr=%0h, RegDst=%0b, OpCode=%0b, ALUSrcA=%0b, ALUSrcB=%0b, Shamt=0x%h, ALU_Control=%0h, RegWrite=%0b", 
                 dut.id_instr,
                 dut.id_reg_dst,
                 dut.id_instr[31:26], // Extract opcode directly from instruction
                 dut.id_alu_src_a,
                 dut.id_alu_src_b,
                 dut.id_shamt,
                 dut.id_alu_control,
                 dut.id_reg_write);

        $display("Branch Control: Take Branch=%0b, Target Address=0x%0h, Branch Type=%0b, PC+4=0x%0h", 
                  dut.id_take_branch,
                  dut.id_branch_target_addr,
                  dut.id_stage_inst.branch_type,
                  dut.id_next_pc);         

        $display("EX: ALUSrcA=%0b, ALUinputA=%0d, ALUinputB=%0d, Shamt=0x%h, ALUControl=%0d, ALUResult=%0d, RD=%0d, RegWrite=%0b",
                 dut.ex_stage_inst.i_alu_src_a,
                 dut.ex_stage_inst.alu_input_a,
                 dut.ex_stage_inst.alu_input_b, 
                 dut.ex_stage_inst.i_shamt,
                 dut.ex_stage_inst.i_alu_control,
                 dut.ex_alu_result,
                 dut.ex_write_register,
                 dut.ex_reg_write);
        
        // Mostrar también los registros de origen y destino relevantes
        $display("REGS: Rs=%0d, Rt=%0d, MEM_Rd=%0d, WB_Rd=%0d", 
                 dut.ex_rs,
                 dut.ex_rt,
                 dut.mem_write_register,
                 dut.wb_write_register_out);
               
        $display("MEM: ALUResult=%0d, MemWrite=%0b, MemRead=%0b, RegWrite=%0b", 
                 dut.mem_alu_result,
                 dut.mem_mem_write,
                 dut.mem_mem_read,
                 dut.mem_reg_write_out);
                 
        $display("WB: WriteReg=%0d, WriteData=%0d, RegWrite=%0b", 
                 dut.wb_write_register_out,
                 dut.wb_write_data,
                 dut.wb_reg_write_out);
    end
  end
  
  // Ya no necesitamos la verificación basada en ciclos, 
  // ya que ahora se ejecuta cuando halt=1

  // Para generar formas de onda (VCD)
  initial begin
    $dumpfile("mips_simple.vcd");
    $dumpvars(0, mips_simple_tb);
  end

endmodule
