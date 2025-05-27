`timescale 1ns / 1ps

module mips_pipeline_detailed_tb();

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
  
  // Mapa de instrucciones para mostrarlas de forma más legible
  reg [32*8:1] instr_map [0:15]; // Matriz de strings
  initial begin
    instr_map[0] = "addi $1, $0, 5";
    instr_map[1] = "addi $2, $0, 10";
    instr_map[2] = "addi $3, $0, 15";
    instr_map[3] = "addi $4, $0, 20";
    instr_map[4] = "add $5, $1, $2";
    instr_map[5] = "sub $6, $3, $1";
    instr_map[6] = "and $7, $2, $3";
    instr_map[7] = "or $8, $1, $4";
    instr_map[8] = "addi $9, $0, 100";
    instr_map[9] = "sw $5, 0($9)";
    instr_map[10] = "sw $6, 4($9)";
    instr_map[11] = "lw $10, 0($9)";
    instr_map[12] = "lw $11, 4($9)";
    instr_map[13] = "add $12, $10, $11";
    instr_map[14] = "xor $13, $5, $6";
    instr_map[15] = "NOP";
  end
  
  // Función para traducir opcode a string
  function [32*8:1] decode_instr;
    input [31:0] instr;
    input [31:0] pc;
    
    reg [5:0] opcode;
    reg [5:0] funct;
    integer instr_idx;
    
    begin
      opcode = instr[31:26];
      funct = instr[5:0];
      instr_idx = pc >> 2;  // PC/4 para obtener el índice
      
      if (instr_idx < 15 && instr != 0)
        decode_instr = instr_map[instr_idx];
      else if (instr == 0)
        decode_instr = "NOP";
      else
        decode_instr = "Instrucción desconocida";
    end
  endfunction
  
  // Inicio de la simulación
  initial begin
    // Inicialización de señales
    reset = 1;
    cycle_count = 0;
    
    // Mostrar encabezado
    $display("\n==== MIPS Pipeline Testbench Detallado ====\n");
    
    // Liberar el reset después de unos ciclos
    #15;
    reset = 0;

    // Ejecutar por suficientes ciclos para completar todas las instrucciones
    #1000;
    $finish;
  end
  
  // Para capturar valores de registros
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
  
  // Memoria de datos
  wire [31:0] mem_100 = dut.mem_stage_inst.memory[25];  // Memoria[100] (100/4 = 25)
  wire [31:0] mem_104 = dut.mem_stage_inst.memory[26];  // Memoria[104] (104/4 = 26)
  
  // Monitoreo de señales en cada ciclo
  always @(posedge clk) begin
    if (!reset) begin
      cycle_count = cycle_count + 1;
      
      // Extraemos las instrucciones que están en cada etapa del pipeline
      $display("==== Ciclo %0d (t=%0t ns) =================", cycle_count, $time);
      
      // Etapa IF: Instrucción actual siendo fetch
      $display("IF: PC=%0h | Instrucción: %0h | %0s", 
                dut.if_stage_inst.pc_inst.pc,
                dut.if_instr,
                decode_instr(dut.if_instr, dut.if_stage_inst.pc_inst.pc));
      
      // Etapa ID: Decodificando instrucción
      $display("ID: PC=%0h | Instrucción: %0h | %0s", 
                dut.id_next_pc - 4,
                dut.id_instr,
                decode_instr(dut.id_instr, dut.id_next_pc - 4));
      
      // Datos de la etapa ID
      if (dut.id_instr != 0) begin
        $display("   Datos: rs=%0d, rt=%0d, rd=%0d, imm=%0h", 
                  dut.id_instr[25:21], dut.id_instr[20:16], dut.id_instr[15:11], dut.id_instr[15:0]);
        $display("   Control: reg_dst=%0d, alu_src=%0d, alu_op=%0d, mem_read=%0d, mem_write=%0d, mem_to_reg=%0d, reg_write=%0d",
                  dut.id_stage_inst.o_reg_dst, dut.id_stage_inst.o_alu_src, dut.id_stage_inst.o_alu_op,
                  dut.id_stage_inst.o_mem_read, dut.id_stage_inst.o_mem_write, dut.id_stage_inst.o_mem_to_reg, dut.id_stage_inst.o_reg_write);
      end
      
      // Etapa EX: Ejecución de la operación ALU con depuración
      $display("EX: Operando1=%0d, Operando2=%0d, ALUResult=%0d, RegDst=%0b, RegWrite=%0b", 
                dut.ex_read_data_1, 
                dut.ex_alu_src ? dut.ex_sign_extended_imm : dut.ex_read_data_2,
                dut.ex_alu_result,
                dut.ex_reg_dst,
                dut.ex_reg_write);
      $display("     rd=%0d, rt=%0d, write_register=%0d", 
                dut.ex_rd, dut.ex_rt, dut.ex_write_register);
      
      // Etapa MEM: Acceso a memoria con depuración extendida
      $display("MEM: ALUResult=%0d, WriteData=%0d, MemRead=%0b, MemWrite=%0b, RegWrite=%0b", 
                dut.mem_alu_result, 
                dut.mem_write_data,
                dut.mem_mem_read,
                dut.mem_mem_write,
                dut.mem_reg_write);
      
      $display("     Señales de control adicionales: mem_to_reg=%0b, write_register=%0d", 
                dut.mem_mem_to_reg, dut.mem_write_register);
                
      if (dut.mem_mem_write) 
        $display("     Escribiendo %0d en Mem[%0d]", dut.mem_write_data, dut.mem_alu_result);
      if (dut.mem_mem_read)
        $display("     Leyendo %0d de Mem[%0d]", dut.mem_read_data, dut.mem_alu_result);
      
      // Etapa WB: Write-Back con depuración extendida
      $display("WB: WriteReg=%0d, WriteData=%0d, RegWrite=%0b, fixed_RegWrite=%0b", 
                dut.wb_write_register_out,
                dut.wb_write_data,
                dut.wb_reg_write,
                dut.wb_reg_write_out);
      $display("     Señales detalladas: mem_wb_reg.reg_write_in=%0b, mem_reg_write=%0b", 
                dut.mem_wb_reg.reg_write_in, 
                dut.mem_reg_write);
                
      if (dut.wb_reg_write_out && dut.wb_write_register_out != 0)
        $display("     Escribiendo %0d en Registro $%0d", dut.wb_write_data, dut.wb_write_register_out);
      
      // Mostrar el contenido de los registros cada pocos ciclos
      if (cycle_count % 5 == 0 || cycle_count == 19) begin
        $display("\n--- Estado de los Registros en el ciclo %0d ---", cycle_count);
        $display("$1=%0d, $2=%0d, $3=%0d, $4=%0d, $5=%0d", reg1, reg2, reg3, reg4, reg5);
        $display("$6=%0d, $7=%0d, $8=%0d, $9=%0d, $10=%0d", reg6, reg7, reg8, reg9, reg10);
        $display("$11=%0d, $12=%0d, $13=%0d", reg11, reg12, reg13);
        
        // Mostrar contenido de memoria relevante
        $display("\n--- Estado de la Memoria en el ciclo %0d ---", cycle_count);
        $display("Mem[100]=%0d, Mem[104]=%0d", mem_100, mem_104);
      end
      
      $display("");
    end
  end
  
  // Verificación final después de 20 ciclos (suficientes para procesar todas las instrucciones)
  always @(posedge clk) begin
    if (!reset && cycle_count == 20) begin
      $display("\n==== VERIFICACIÓN FINAL (Ciclo %0d) =====", cycle_count);
      $display("$1=%0d (Esperado: 5)", reg1);
      $display("$2=%0d (Esperado: 10)", reg2);
      $display("$3=%0d (Esperado: 15)", reg3);
      $display("$4=%0d (Esperado: 20)", reg4);
      $display("$5=%0d (Esperado: 15)", reg5);
      $display("$6=%0d (Esperado: 10)", reg6);
      $display("$7=%0d (Esperado: 10)", reg7);
      $display("$8=%0d (Esperado: 21)", reg8);
      $display("$9=%0d (Esperado: 100)", reg9);
      $display("$10=%0d (Esperado: 15)", reg10);
      $display("$11=%0d (Esperado: 10)", reg11);
      $display("$12=%0d (Esperado: 25)", reg12);
      $display("$13=%0d (Esperado: 5)", reg13);
      $display("Mem[100]=%0d (Esperado: 15)", mem_100);
      $display("Mem[104]=%0d (Esperado: 10)", mem_104);
      
      // Verificación automática de resultados
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
  
  // Inyección de debug para mostrar información detallada
  initial begin
    $dumpfile("mips_pipeline_detailed.vcd");
    $dumpvars(0, mips_pipeline_detailed_tb);
  end

endmodule
