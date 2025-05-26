`timescale 1ns / 1ps

module add4_tb();
  // Señales de prueba
  reg [31:0] in;
  wire [31:0] out;
  
  // Instancia del módulo bajo prueba
  add4 dut (
    .in(in),
    .out(out)
  );
  
  // Procedimiento de prueba
  initial begin
    // Inicialización
    in = 32'h00000000;
    
    // Visualización en consola
    $display("Tiempo\tEntrada\t\tSalida");
    $monitor("%0t\t%h\t%h", $time, in, out);
    
    // Probar con diferentes valores
    #10 in = 32'h00000000;
    #10 in = 32'h00000004;
    #10 in = 32'h0000000C;
    #10 in = 32'hFFFFFFFC; // Prueba de desbordamiento
    
    // Finalizar simulación
    #10;
    $display("Test completado");
    $finish;
  end
  
  // Resultados esperados:
  // 1. Para in=0x00000000, out debe ser 0x00000004
  // 2. Para in=0x00000004, out debe ser 0x00000008
  // 3. Para in=0x0000000C, out debe ser 0x00000010
  // 4. Para in=0xFFFFFFFC, out debe ser 0x00000000 (por desbordamiento)
endmodule
