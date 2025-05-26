`timescale 1ns / 1ps

module instr_mem_tb();
  // Señales de prueba
  reg [31:0] addr;
  wire [31:0] instr;
  
  // Instancia del módulo bajo prueba
  instr_mem dut (
    .addr(addr),
    .instr(instr)
  );
  
  // Procedimiento de prueba
  initial begin
    // Inicialización
    addr = 32'h00000000;
    
    // Visualización en consola
    $display("Tiempo\tDirección\tInstrucción");
    $monitor("%0t\t%h\t%h", $time, addr, instr);
    
    // Probar con diferentes direcciones
    // Nota: Como memoria usa addr[9:2], incrementamos de 4 en 4
    #10 addr = 32'h00000000; // Debería leer la primera instrucción
    #10 addr = 32'h00000004; // Segunda instrucción
    #10 addr = 32'h00000008; // Tercera instrucción
    #10 addr = 32'h0000000C; // Cuarta instrucción
    
    // Finalizar simulación
    #10;
    $display("Test completado");
    $finish;
  end
  
  // Resultados esperados:
  // Basándose en el archivo instr_mem.mem:
  // 1. Para addr=0x00000000, instr debe ser 0x00000000
  // 2. Para addr=0x00000004, instr debe ser 0x8C130004 (lw $s3, 4($zero))
  // 3. Para addr=0x00000008, instr debe ser 0x02224020 (add $t0, $s1, $s2)
  // 4. Para addr=0x0000000C, instr debe ser 0x01224822 (sub $t1, $t1, $s2)
endmodule
