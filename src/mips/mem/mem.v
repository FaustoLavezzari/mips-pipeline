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
  // Ya no recibimos señales especiales para JAL/JALR
  input  wire [5:0]  opcode_in,        // Opcode para identificar tipo de carga
  
  // Salidas
  output wire [31:0] read_data_out,    // Dato leído de memoria (para LW)
  output wire [31:0] alu_result_out,   // Pasar el resultado de la ALU a WB
  output wire [4:0]  write_register_out, // Registro destino para WB
  output wire        reg_write_out,    // Señal de escritura en registros
  output wire        mem_to_reg_out   // Selección ALU/MEM para WB
  // Ya no propagamos señales especiales para JAL/JALR
);

  // Memoria de datos (256 palabras de 32 bits)
  reg [31:0] memory [0:255];
  
  // Cálculo del índice para acceder a la memoria (dirección dividida por 4)
  // Usar más bits para direccionar correctamente toda la memoria
  wire [31:0] mem_addr_full = alu_result_in >> 2; // División por 4 (palabra alineada)
  wire [7:0] mem_addr = mem_addr_full[7:0]; // Mantener compatibilidad con la definición de memoria
  
  // Debug: mostrar el cálculo de dirección de memoria 
  always @(*) begin
    if (mem_write_in || mem_read_in) begin
      $display("MEM ADDRESS: original=%d, ajustada=%d, índice=%d, offset=%d", 
               alu_result_in, mem_addr_full, mem_addr, alu_result_in[1:0]);
    end
  end
  
  always @(posedge clk) begin
    if (mem_write_in) begin
      case (opcode_in)
        `OPCODE_SB: begin  // Store Byte
          case (alu_result_in[1:0])
            2'b00: memory[mem_addr] <= {memory[mem_addr][31:8], write_data_in[7:0]};
            2'b01: memory[mem_addr] <= {memory[mem_addr][31:16], write_data_in[7:0], memory[mem_addr][7:0]};
            2'b10: memory[mem_addr] <= {memory[mem_addr][31:24], write_data_in[7:0], memory[mem_addr][15:0]};
            2'b11: memory[mem_addr] <= {write_data_in[7:0], memory[mem_addr][23:0]};
          endcase
          $display("SB: Escribiendo byte en Memoria[%d] = %h, offset=%b", 
                  mem_addr, write_data_in[7:0], alu_result_in[1:0]);
        end
        
        `OPCODE_SH: begin  // Store Halfword
          case (alu_result_in[1])
            1'b0: memory[mem_addr] <= {memory[mem_addr][31:16], write_data_in[15:0]};
            1'b1: memory[mem_addr] <= {write_data_in[15:0], memory[mem_addr][15:0]};
          endcase
          $display("SH: Escribiendo halfword en Memoria[%d] = %h, offset=%b", 
                  mem_addr, write_data_in[15:0], alu_result_in[1]);
        end
        
        `OPCODE_SW: begin  // Store Word (estándar)
          memory[mem_addr] <= write_data_in;
          $display("SW: Escribiendo word en Memoria[%d] = %d", alu_result_in, write_data_in);
        end
        
        default: begin
          memory[mem_addr] <= write_data_in;
          $display("Default Store: Memoria[%d] = %d", alu_result_in, write_data_in);
        end
      endcase
    end
  end

  // Lectura de memoria (asíncrona)
  reg [31:0] read_data;
  
  always @(*) begin
    if (mem_read_in) begin
      case (opcode_in)
        `OPCODE_LB: begin  // Load Byte (sign-extended)
          case (alu_result_in[1:0])
            2'b00: read_data = {{24{memory[mem_addr][7]}}, memory[mem_addr][7:0]};
            2'b01: read_data = {{24{memory[mem_addr][15]}}, memory[mem_addr][15:8]};
            2'b10: read_data = {{24{memory[mem_addr][23]}}, memory[mem_addr][23:16]};
            2'b11: read_data = {{24{memory[mem_addr][31]}}, memory[mem_addr][31:24]};
          endcase
          $display("LB: Leyendo byte en Memoria[%d] = %d", alu_result_in, read_data);
        end
        
        `OPCODE_LBU: begin  // Load Byte Unsigned (zero-extended)
          case (alu_result_in[1:0])
            2'b00: read_data = {24'b0, memory[mem_addr][7:0]};
            2'b01: read_data = {24'b0, memory[mem_addr][15:8]};
            2'b10: read_data = {24'b0, memory[mem_addr][23:16]};
            2'b11: read_data = {24'b0, memory[mem_addr][31:24]};
          endcase
          $display("LBU: Leyendo byte unsigned en Memoria[%d] = %d", alu_result_in, read_data);
        end
        
        `OPCODE_LH: begin  // Load Halfword (sign-extended)
          case (alu_result_in[1])
            1'b0: read_data = {{16{memory[mem_addr][15]}}, memory[mem_addr][15:0]};
            1'b1: read_data = {{16{memory[mem_addr][31]}}, memory[mem_addr][31:16]};
          endcase
          $display("LH: Leyendo halfword en Memoria[%d] = %d", alu_result_in, read_data);
        end
        
        `OPCODE_LHU: begin  // Load Halfword Unsigned (zero-extended)
          case (alu_result_in[1])
            1'b0: read_data = {16'b0, memory[mem_addr][15:0]};
            1'b1: read_data = {16'b0, memory[mem_addr][31:16]};
          endcase
          $display("LHU: Leyendo halfword unsigned en Memoria[%d] = %d", alu_result_in, read_data);
        end
        
        `OPCODE_LW: begin  // Load Word (standard)
          read_data = memory[mem_addr];
          $display("LW: Leyendo word en Memoria[%d] = %d", alu_result_in, read_data);
        end
        
        `OPCODE_LWU: begin  // Load Word Unsigned (no-op, igual a LW en un sistema de 32 bits)
          read_data = memory[mem_addr];
          $display("LWU: Leyendo word unsigned en Memoria[%d] = %d", alu_result_in, read_data);
        end
        
        default: begin
          read_data = memory[mem_addr]; // Por defecto, cargar palabra completa
        end
      endcase
    end else begin
      read_data = 32'b0;
    end
  end
  
  assign read_data_out = read_data;
  
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
  // Ya no propagamos señales JAL/JALR

endmodule
