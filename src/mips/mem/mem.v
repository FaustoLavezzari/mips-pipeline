`timescale 1ns / 1ps
`include "../mips_pkg.vh"

module mem_stage(
  input  wire        clk,
  input  wire        reset,
  
  // Entradas desde EX/MEM
  input  wire [31:0] alu_result_in,    // Dirección para LW/SW
  input  wire [31:0] write_data_in,    // Dato a escribir (para SW)
  input  wire [4:0]  write_register_in, // Registro destino para WB
  input  wire        reg_write_in,     // Señal de escritura en registros
  input  wire        mem_read_in,      // Control de lectura
  input  wire        mem_write_in,     // Control de escritura
  input  wire        mem_to_reg_in,    // Selección ALU/MEM para WB
  input  wire [31:0] pc_plus_4_in,     // PC+4 para JAL
  input  wire        is_jal_in,        // Indica si es instrucción JAL
  
  // Salidas
  output wire [31:0] read_data_out,    // Dato leído de memoria (para LW)
  output wire [31:0] alu_result_out,   // Pasar el resultado de la ALU a WB
  output wire [4:0]  write_register_out, // Registro destino para WB
  output wire        reg_write_out,    // Señal de escritura en registros
  output wire        mem_to_reg_out,   // Selección ALU/MEM para WB
  output wire [31:0] pc_plus_4_out,    // PC+4 para JAL
  output wire        is_jal_out        // Indica si es instrucción JAL
);

  // Memoria de datos (256 palabras de 32 bits)
  reg [31:0] memory [0:255];
  
  // Cálculo del índice para acceder a la memoria (dirección dividida por 4)
  // Usar más bits para direccionar correctamente toda la memoria
  wire [31:0] mem_addr_full = alu_result_in >> 2; // División por 4
  wire [7:0] mem_addr = mem_addr_full[7:0]; // Mantener compatibilidad con la definición de memoria
  
  // Debug: mostrar el cálculo de dirección de memoria 
  always @(*) begin
    if (mem_write_in || mem_read_in) begin
      $display("MEM ADDRESS: original=%d, ajustada=%d, índice=%d", 
               alu_result_in, mem_addr_full, mem_addr);
    end
  end
  
  always @(posedge clk) begin
    if (mem_write_in) begin
      memory[mem_addr] <= write_data_in;
      $display("SW: Memoria[%d] = %d", alu_result_in, write_data_in); // Depuración
    end
  end

  // Lectura de memoria (asíncrona)
  assign read_data_out = mem_read_in ? memory[mem_addr] : 32'b0;
  
  // Inicialización de la memoria
  integer i;
  initial begin
    for (i = 0; i < 256; i = i + 1)
      memory[i] = 32'b0;
  end
  
  // Propagar señales de control y datos
  assign alu_result_out = alu_result_in;
  assign write_register_out = write_register_in;
  assign reg_write_out = reg_write_in;
  assign mem_to_reg_out = mem_to_reg_in;
  assign pc_plus_4_out = pc_plus_4_in;
  assign is_jal_out = is_jal_in;

endmodule
