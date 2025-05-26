`timescale 1ns / 1ps

module pc_tb();
  // Señales de entrada
  reg clk;
  reg reset;
  
  // Señales de salida
  wire [31:0] pc;
  
  // Instancia del módulo a probar
  PC dut (
    .clk(clk),
    .reset(reset),
    .pc(pc)
  );
  
  // Generación de clock
  always #5 clk = ~clk;
  
  // Procedimiento de test
  initial begin
    // Inicialización
    clk = 0;
    reset = 1;
    
    // Visualización en consola
    $display("Tiempo\tReset\tPC");
    $monitor("%0t\t%b\t%h", $time, reset, pc);
    
    // Iniciar con reset
    #10 reset = 0;
    
    // Comprobar incrementos
    // Después de 4 ciclos, debería ser 16 (decimal)
    #40;
    
    // Probar reset durante la operación
    reset = 1;
    #10 reset = 0;
    
    // Ejecutar unos ciclos más
    #30;
    
    // Finalizar simulación
    $display("Test completado");
    $finish;
  end
  
  // Resultados esperados:
  // 1. PC debe iniciar en 0x00000000 cuando reset=1
  // 2. PC debe incrementarse en 4 en cada ciclo de reloj cuando reset=0
  // 3. PC debe volver a 0x00000000 cuando se aplica reset en cualquier momento
endmodule
