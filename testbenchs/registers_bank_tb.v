`timescale 1ns / 1ps

module registers_bank_tb();
  // Señales de prueba
  reg clk;
  reg reset;
  reg write_enable;
  reg [4:0] read_register_1;
  reg [4:0] read_register_2;
  reg [4:0] write_register;
  reg [31:0] write_data;
  wire [31:0] read_data_1;
  wire [31:0] read_data_2;
  
  // Instancia del módulo bajo prueba
  registers_bank dut (
    .i_clk(clk),
    .i_reset(reset),
    .i_write_enable(write_enable),
    .i_read_register_1(read_register_1),
    .i_read_register_2(read_register_2),
    .i_write_register(write_register),
    .i_write_data(write_data),
    .o_read_data_1(read_data_1),
    .o_read_data_2(read_data_2)
  );
  
  // Generación de clock
  always #5 clk = ~clk;
  
  // Procedimiento de prueba
  initial begin
    // Inicialización
    clk = 0;
    reset = 1;
    write_enable = 0;
    read_register_1 = 0;
    read_register_2 = 0;
    write_register = 0;
    write_data = 0;
    
    // Visualización en consola
    $display("Tiempo\tReset\tWE\tWR\tWD\t\tRR1\tRD1\t\tRR2\tRD2");
    $monitor("%0t\t%b\t%b\t%d\t%h\t%d\t%h\t%d\t%h", 
             $time, reset, write_enable, write_register, write_data, 
             read_register_1, read_data_1, read_register_2, read_data_2);
    
    // Desactivar reset
    #10 reset = 0;
    
    // Escribir en varios registros
    #10;
    write_enable = 1;
    write_register = 1;
    write_data = 32'h11111111;
    
    #10;
    write_register = 2;
    write_data = 32'h22222222;
    
    #10;
    write_register = 3;
    write_data = 32'h33333333;
    
    // Intentar escribir en el registro 0 (no debería cambiar)
    #10;
    write_register = 0;
    write_data = 32'hAAAAAAAA;
    
    // Desactivar escritura y leer registros
    #10;
    write_enable = 0;
    read_register_1 = 1;
    read_register_2 = 2;
    
    #10;
    read_register_1 = 0;
    read_register_2 = 3;
    
    // Probar reset
    #10;
    reset = 1;
    
    #10;
    reset = 0;
    read_register_1 = 1;
    read_register_2 = 2;
    
    // Finalizar simulación
    #10;
    $display("Test completado");
    $finish;
  end
  
  // Resultados esperados:
  // 1. Después del reset inicial, todos los registros deben ser 0
  // 2. Al escribir, los registros deben actualizarse con los valores proporcionados
  // 3. El registro 0 debe permanecer en 0 incluso al intentar escribir en él
  // 4. Después del segundo reset, todos los registros deben volver a 0
endmodule
