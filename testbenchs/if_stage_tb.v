`timescale 1ns / 1ps

module if_stage_tb();
  // Señales de prueba
  reg clk;
  reg reset;
  wire [31:0] o_next_pc;
  wire [31:0] o_instr;
  
  // Instancia del módulo bajo prueba
  if_stage dut (
    .clk(clk),
    .reset(reset),
    .o_next_pc(o_next_pc),
    .o_instr(o_instr)
  );
  
  // Generación de clock
  always #5 clk = ~clk;
  
  // Procedimiento de prueba
  initial begin
    // Inicialización
    clk = 0;
    reset = 1;
    
    // Visualización en consola
    $display("Tiempo\tReset\tPC+4\t\tInstrucción");
    $monitor("%0t\t%b\t%h\t%h", $time, reset, o_next_pc, o_instr);
    
    // Desactivar reset después de 10ns
    #10 reset = 0;
    
    // Ejecutar varios ciclos y observar instrucciones leídas
    #50;
    
    // Activar reset de nuevo
    reset = 1;
    #10 reset = 0;
    
    // Ejecutar más ciclos
    #40;
    
    // Finalizar simulación
    $display("Test completado");
    $finish;
  end
  
  // Resultados esperados:
  // 1. Con reset=1, o_next_pc debe ser 4 y o_instr debe ser la instrucción en la dirección 0
  // 2. En cada ciclo, o_next_pc debe aumentar en 4 y o_instr debe ser la instrucción en la nueva dirección
  // 3. Después del segundo reset, o_next_pc debe volver a 4 y o_instr debe ser de nuevo la primera instrucción
endmodule
