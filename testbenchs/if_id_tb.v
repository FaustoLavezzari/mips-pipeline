`timescale 1ns / 1ps

module if_id_tb();
  // Señales de prueba
  reg clk;
  reg reset;
  reg [31:0] next_pc_in;
  reg [31:0] instr_in;
  wire [31:0] next_pc_out;
  wire [31:0] instr_out;
  
  // Instancia del módulo bajo prueba
  if_id dut (
    .clk(clk),
    .reset(reset),
    .next_pc_in(next_pc_in),
    .instr_in(instr_in),
    .next_pc_out(next_pc_out),
    .instr_out(instr_out)
  );
  
  // Generación de clock
  always #5 clk = ~clk;
  
  // Procedimiento de prueba
  initial begin
    // Inicialización
    clk = 0;
    reset = 1;
    next_pc_in = 32'h00000000;
    instr_in = 32'h00000000;
    
    // Visualización en consola
    $display("Tiempo\tReset\tPC_in\t\tInstr_in\tPC_out\t\tInstr_out");
    $monitor("%0t\t%b\t%h\t%h\t%h\t%h", 
             $time, reset, next_pc_in, instr_in, next_pc_out, instr_out);
    
    // Desactivar reset
    #10 reset = 0;
    
    // Probar con diferentes valores
    #10;
    next_pc_in = 32'h00000004;
    instr_in = 32'h8C130004; // lw $s3, 4($zero)
    
    #10;
    next_pc_in = 32'h00000008;
    instr_in = 32'h02224020; // add $t0, $s1, $s2
    
    #10;
    next_pc_in = 32'h0000000C;
    instr_in = 32'h01224822; // sub $t1, $t1, $s2
    
    // Probar reset durante la operación
    #5 reset = 1;
    #10 reset = 0;
    
    // Probar más valores después del reset
    #10;
    next_pc_in = 32'h00000010;
    instr_in = 32'hAAAAAAAB;
    
    // Finalizar simulación
    #10;
    $display("Test completado");
    $finish;
  end
  
  // Resultados esperados:
  // 1. Con reset activo, next_pc_out e instr_out deben ser 0
  // 2. Después de un ciclo de reloj, next_pc_out e instr_out deben tener los valores de entrada del ciclo anterior
  // 3. Después del segundo reset, next_pc_out e instr_out deben volver a 0
endmodule
