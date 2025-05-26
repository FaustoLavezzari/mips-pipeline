`timescale 1ns / 1ps

module id_ie_tb();
  // Señales de prueba
  reg clk;
  reg reset;
  reg [31:0] read_data_1_in;
  reg [31:0] read_data_2_in;
  reg [31:0] sign_extended_imm_in;
  reg [4:0] rt_in;
  reg [4:0] rd_in;
  reg [31:0] next_pc_in;
  
  wire [31:0] read_data_1_out;
  wire [31:0] read_data_2_out;
  wire [31:0] sign_extended_imm_out;
  wire [4:0] rt_out;
  wire [4:0] rd_out;
  wire [31:0] next_pc_out;
  
  // Instancia del módulo bajo prueba
  id_ie dut (
    .clk(clk),
    .reset(reset),
    .read_data_1_in(read_data_1_in),
    .read_data_2_in(read_data_2_in),
    .sign_extended_imm_in(sign_extended_imm_in),
    .rt_in(rt_in),
    .rd_in(rd_in),
    .next_pc_in(next_pc_in),
    .read_data_1_out(read_data_1_out),
    .read_data_2_out(read_data_2_out),
    .sign_extended_imm_out(sign_extended_imm_out),
    .rt_out(rt_out),
    .rd_out(rd_out),
    .next_pc_out(next_pc_out)
  );
  
  // Generación de clock
  always #5 clk = ~clk;
  
  // Procedimiento de prueba
  initial begin
    // Inicialización
    clk = 0;
    reset = 1;
    read_data_1_in = 32'h00000000;
    read_data_2_in = 32'h00000000;
    sign_extended_imm_in = 32'h00000000;
    rt_in = 5'b00000;
    rd_in = 5'b00000;
    next_pc_in = 32'h00000000;
    
    // Visualización en consola
    $display("Tiempo\tReset\tRD1_in\t\tRD2_in\t\tImm_in\t\tRT_in\tRD_in\tPC_in\t\tRD1_out\t\tRD2_out\t\tImm_out\t\tRT_out\tRD_out\tPC_out");
    $monitor("%0t\t%b\t%h\t%h\t%h\t%d\t%d\t%h\t%h\t%h\t%h\t%d\t%d\t%h", 
             $time, reset, 
             read_data_1_in, read_data_2_in, sign_extended_imm_in, 
             rt_in, rd_in, next_pc_in,
             read_data_1_out, read_data_2_out, sign_extended_imm_out, 
             rt_out, rd_out, next_pc_out);
    
    // Desactivar reset
    #10 reset = 0;
    
    // Probar con diferentes valores para una instrucción tipo-R
    #10;
    read_data_1_in = 32'h0000000A; // Valor de RS = 10
    read_data_2_in = 32'h00000014; // Valor de RT = 20
    sign_extended_imm_in = 32'h00000000;
    rt_in = 5'b00010; // RT = 2
    rd_in = 5'b00011; // RD = 3
    next_pc_in = 32'h00000004;
    
    // Probar con diferentes valores para una instrucción tipo-I
    #10;
    read_data_1_in = 32'h0000001E; // Valor de RS = 30
    read_data_2_in = 32'h00000000;
    sign_extended_imm_in = 32'h00000064; // Inmediato = 100
    rt_in = 5'b00100; // RT = 4
    rd_in = 5'b00000;
    next_pc_in = 32'h00000008;
    
    // Probar reset durante la operación
    #5 reset = 1;
    #10 reset = 0;
    
    // Probar más valores después del reset
    #10;
    read_data_1_in = 32'h00000028; // Valor de RS = 40
    read_data_2_in = 32'h00000032; // Valor de RT = 50
    sign_extended_imm_in = 32'hFFFFFFCE; // Inmediato = -50
    rt_in = 5'b00101; // RT = 5
    rd_in = 5'b00110; // RD = 6
    next_pc_in = 32'h0000000C;
    
    // Finalizar simulación
    #10;
    $display("Test completado");
    $finish;
  end
  
  // Resultados esperados:
  // 1. Con reset activo, todas las salidas deben ser 0
  // 2. Después de un ciclo de reloj, las salidas deben tener los valores de entrada del ciclo anterior
  // 3. Después del segundo reset, todas las salidas deben volver a 0
endmodule
