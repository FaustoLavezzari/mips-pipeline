`timescale 1ns / 1ps

module mips_tb();
  // Señales de prueba
  reg clk;
  reg reset;
  wire [31:0] result;
  
  // Instancia del módulo bajo prueba
  mips dut (
    .clk(clk),
    .reset(reset),
    .result(result)
  );
  
  // Señales internas para observación
  wire [31:0] if_pc_value = dut.if_stage_inst.pc_inst.pc;
  wire [31:0] if_instr = dut.if_instr;
  wire [31:0] id_instr = dut.id_instr;
  wire [31:0] id_read_data_1 = dut.id_read_data_1;
  wire [31:0] id_read_data_2 = dut.id_read_data_2;
  wire [31:0] ex_read_data_1 = dut.ex_read_data_1;
  wire [31:0] ex_read_data_2 = dut.ex_read_data_2;
  
  // Generación de clock
  always #5 clk = ~clk;
  
  // Procedimiento de prueba
  initial begin
    // Inicialización
    clk = 0;
    reset = 1;
    
    // Visualización en consola
    $display("MIPS Pipeline Test");
    $display("Tiempo\tPC\t\tIF_Instr\tID_Instr\tID_RD1\t\tID_RD2\t\tEX_RD1\t\tEX_RD2");
    $monitor("%0t\t%h\t%h\t%h\t%h\t%h\t%h\t%h", 
             $time, if_pc_value, if_instr, id_instr, 
             id_read_data_1, id_read_data_2,
             ex_read_data_1, ex_read_data_2);
    
    // Desactivar reset después de 10ns
    #10 reset = 0;
    
    // Ejecutar por un tiempo más largo para ver el procesamiento
    // de más instrucciones a través del pipeline
    #300;
    
    // Finalizar simulación
    $display("\nTest completado");
    $finish;
  end
  
  // Resultados esperados:
  // 1. En el primer ciclo después del reset (t=15ns), PC=0, IF_Instr=Mem[0]
  // 2. En el siguiente ciclo (t=25ns), PC=4, IF_Instr=Mem[1], y la primera instrucción pasa a ID
  // 3. En el tercer ciclo (t=35ns), PC=8, IF_Instr=Mem[2], la primera instrucción pasa a EX y la segunda a ID
  //
  // Basado en el archivo instr_mem.mem, las instrucciones son:
  // 0x00: 20080005 - addi $t0, $zero, 5     # $t0 = 5 (valor inicial conocido)
  // 0x04: 2009000A - addi $t1, $zero, 10    # $t1 = 10 (valor inicial conocido) 
  // 0x08: 200A00FF - addi $t2, $zero, 255   # $t2 = 255 (valor visible para depuración)
  // 0x0C: 01095020 - add $t2, $t0, $t1      # $t2 = $t0 + $t1 = 15
  // 0x10: 01095822 - sub $t3, $t0, $t1      # $t3 = $t0 - $t1 = -5
  // 0x14: 01095824 - and $t3, $t0, $t1      # $t3 = $t0 & $t1
  // 0x18: 01095825 - or $t3, $t0, $t1       # $t3 = $t0 | $t1
  // 0x1C: AC080020 - sw $t0, 32($zero)      # Guarda $t0 en memoria[32]
  // 0x20: 8C0B0020 - lw $t3, 32($zero)      # Carga el valor de memoria[32] en $t3 (debe ser 5)
  // 0x24: 11090002 - beq $t0, $t1, 2        # Si $t0==$t1, salta 2 instrucciones (no debería saltar)
  // 0x28: 000A5880 - sll $t3, $t2, 2        # $t3 = $t2 << 2 (desplazamiento lógico izquierda)
  // 0x2C: 012A602A - slt $t4, $t1, $t2      # $t4 = ($t1 < $t2) ? 1 : 0 (debe ser 1 porque $t1=10 < $t2=15)
  //
  // Nota: Como aún no está implementada la etapa WB, los valores en los registros 
  // no se actualizarán, pero podemos verificar la correcta propagación de las instrucciones
  // a través del pipeline.
endmodule
