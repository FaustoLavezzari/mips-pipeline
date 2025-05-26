`timescale 1ns / 1ps

module id_stage_tb();
  // Señales de prueba
  reg clk;
  reg reset;
  reg [31:0] next_pc;
  reg [31:0] instruction;
  reg reg_write;
  reg [4:0] write_register;
  reg [31:0] write_data;
  
  wire [31:0] read_data_1;
  wire [31:0] read_data_2;
  wire [31:0] sign_extended_imm;
  wire [4:0] rt;
  wire [4:0] rd;
  
  // Instancia del módulo bajo prueba
  id_stage dut (
    .clk(clk),
    .reset(reset),
    .i_next_pc(next_pc),
    .i_instruction(instruction),
    .i_reg_write(reg_write),
    .i_write_register(write_register),
    .i_write_data(write_data),
    .o_read_data_1(read_data_1),
    .o_read_data_2(read_data_2),
    .o_sign_extended_imm(sign_extended_imm),
    .o_rt(rt),
    .o_rd(rd)
  );
  
  // Generación de clock
  always #5 clk = ~clk;
  
  // Procedimiento de prueba
  initial begin
    // Inicialización
    clk = 0;
    reset = 1;
    next_pc = 32'h00000004;
    instruction = 32'h00000000;
    reg_write = 0;
    write_register = 0;
    write_data = 0;
    
    // Visualización en consola
    $display("Tiempo\tInstr\t\tRD1\t\tRD2\t\tImm\t\tRT\tRD");
    $monitor("%0t\t%h\t%h\t%h\t%h\t%d\t%d", 
             $time, instruction, read_data_1, read_data_2, sign_extended_imm, rt, rd);
    
    // Desactivar reset
    #10 reset = 0;
    
    // Probar instrucción tipo-R: add $3, $1, $2
    #10;
    instruction = 32'h00221820; // add $3, $1, $2
    
    // Escribir en registros
    #10;
    reg_write = 1;
    write_register = 1;
    write_data = 32'h0000000A; // r1 = 10
    
    #10;
    write_register = 2;
    write_data = 32'h00000014; // r2 = 20
    
    // Probar la extracción de operandos
    #10;
    reg_write = 0;
    
    // Probar instrucción tipo-I: addi $4, $1, 100
    #10;
    instruction = 32'h20240064; // addi $4, $1, 100
    
    // Probar instrucción con inmediato negativo: addi $5, $2, -50
    #10;
    instruction = 32'h2045FFCE; // addi $5, $2, -50
    
    // Probar instrucción tipo-I de memoria: lw $6, 8($1)
    #10;
    instruction = 32'h8C260008; // lw $6, 8($1)
    
    // Finalizar simulación
    #10;
    $display("Test completado");
    $finish;
  end
  
  // Resultados esperados:
  // 1. Para add $3, $1, $2:
  //    - read_data_1 debe ser el valor de $1 (10 después de escribir)
  //    - read_data_2 debe ser el valor de $2 (20 después de escribir)
  //    - rt debe ser 2, rd debe ser 3
  //
  // 2. Para addi $4, $1, 100:
  //    - read_data_1 debe ser el valor de $1 (10)
  //    - sign_extended_imm debe ser 0x00000064 (100 en decimal)
  //    - rt debe ser 4
  //
  // 3. Para addi $5, $2, -50:
  //    - read_data_1 debe ser el valor de $2 (20)
  //    - sign_extended_imm debe ser 0xFFFFFFCE (-50 en decimal con extensión de signo)
  //    - rt debe ser 5
  //
  // 4. Para lw $6, 8($1):
  //    - read_data_1 debe ser el valor de $1 (10)
  //    - sign_extended_imm debe ser 0x00000008
  //    - rt debe ser 6
endmodule
