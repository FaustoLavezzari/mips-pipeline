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
  
  // Dirección base para el acceso a memoria (cálculo del índice)
  // La dirección efectiva ya viene calculada en alu_result_in
  // La memoria está organizada en palabras, por lo tanto se divide entre 4 (shift right 2)
  wire [31:0] mem_addr = alu_result_in >> 2;
  
  // Registro para almacenar el dato leído (lectura síncrona)
  reg [31:0] read_data_reg;
  
  // Registro para guardar dirección previa de escritura y datos para forwarding
  reg [31:0] last_write_addr;
  reg [31:0] last_write_data;
  reg        last_write_valid;
  
  // Lectura síncrona y forwarding de memoria
  // Vamos a mantener un historial de las últimas N escrituras para forwarding genérico
  parameter WRITE_HISTORY_SIZE = 4;  // Número de escrituras anteriores a recordar
  reg [31:0] write_history_addr [0:WRITE_HISTORY_SIZE-1];
  reg [31:0] write_history_data [0:WRITE_HISTORY_SIZE-1];
  reg        write_history_valid [0:WRITE_HISTORY_SIZE-1];
  
  // Manejo de historial de escrituras para forwarding genérico
  integer hist_idx;
  always @(posedge clk) begin
    if (reset) begin
      read_data_reg <= {`DATA_WIDTH{1'b0}};
      last_write_addr <= {`DATA_WIDTH{1'b0}};
      last_write_data <= {`DATA_WIDTH{1'b0}};
      last_write_valid <= 1'b0;
      
      // Reiniciar el historial de escrituras
      for (hist_idx = 0; hist_idx < WRITE_HISTORY_SIZE; hist_idx = hist_idx + 1) begin
        write_history_addr[hist_idx] <= {`DATA_WIDTH{1'b0}};
        write_history_data[hist_idx] <= {`DATA_WIDTH{1'b0}};
        write_history_valid[hist_idx] <= 1'b0;
      end
    end
    else begin
      // Actualizar registro de último write (mantener este para compatibilidad)
      if (mem_write_in) begin
        last_write_addr <= mem_addr;
        last_write_data <= write_data_in;
        last_write_valid <= 1'b1;
        
        // Actualizar el historial de escrituras, desplazando entradas anteriores
        for (hist_idx = WRITE_HISTORY_SIZE-1; hist_idx > 0; hist_idx = hist_idx - 1) begin
          write_history_addr[hist_idx] <= write_history_addr[hist_idx-1];
          write_history_data[hist_idx] <= write_history_data[hist_idx-1];
          write_history_valid[hist_idx] <= write_history_valid[hist_idx-1];
        end
        
        // Agregar la nueva escritura al inicio del historial
        write_history_addr[0] <= mem_addr;
        write_history_data[0] <= write_data_in;
        write_history_valid[0] <= 1'b1;
        
        // Debug para mostrar la actualización del historial
        $display("DEBUG_MEM_HISTORY: Agregando escritura en addr=%0d, data=%0d, cycle=%0t", 
                 mem_addr, write_data_in, $time);
      end else begin
        last_write_valid <= 1'b0;
      end
      
      // Realizar lectura síncrona
      if (mem_read_in) begin
        read_data_reg <= memory[mem_addr];
      end
    end
  end
  
  // Lógica de forwarding para lectura mejorada con historial
  // Buscar en todo el historial para encontrar la escritura más reciente a esta dirección
  reg [31:0] forwarded_data;
  reg        found_in_history;
  integer    search_idx;
  
  always @(*) begin
    found_in_history = 1'b0;
    forwarded_data = {`DATA_WIDTH{1'b0}};
    
    // Buscar en todo el historial, empezando por la escritura más reciente
    for (search_idx = 0; search_idx < WRITE_HISTORY_SIZE && !found_in_history; search_idx = search_idx + 1) begin
      if (write_history_valid[search_idx] && (write_history_addr[search_idx] == mem_addr)) begin
        forwarded_data = write_history_data[search_idx];
        found_in_history = 1'b1;
        
        // Debug para mostrar el forwarding
        $display("DEBUG_MEM_FORWARD: Usando dato de historial idx=%0d para addr=%0d, data=%0d, cycle=%0t", 
                 search_idx, mem_addr << 2, forwarded_data, $time);
      end
    end
  end
  
  // Usar también el forwarding simple para compatibilidad
  wire mem_forwarding_needed = mem_read_in && (last_write_valid && (mem_addr == last_write_addr) || found_in_history);
  
  // Seleccionar entre dato almacenado en memoria y dato forwardeado
  assign read_data_out = (mem_read_in) ? 
                         (mem_forwarding_needed ? 
                           (found_in_history ? forwarded_data : last_write_data) : 
                           read_data_reg) : 
                         {`DATA_WIDTH{1'b0}};
  
  // Escritura síncrona con forwarding genérico mejorado
  always @(posedge clk) begin
    if (reset) begin
      // No es necesario resetear toda la memoria aquí, ya se inicializa en el bloque initial
    end
    else if (mem_write_in) begin
      $display("DEBUG_MEM_SIGNALS: mem_write_in=%b, write_data_in=%0d, addr=%0d, calculated_index=%0d", 
               mem_write_in, write_data_in, alu_result_in, mem_addr);
      
      // Actualizar la memoria
      memory[mem_addr] <= write_data_in;
      
      // Log para operaciones de escritura
      $display("DEBUG_MEM_WRITE: Writing %0d to address %0d (word index %0d), cycle=%0t", 
               write_data_in, alu_result_in, mem_addr, $time);
    end
  end

  // Inicialización de la memoria
  integer i;
  initial begin
    for (i = 0; i < 256; i = i + 1)
      memory[i] = {`DATA_WIDTH{1'b0}};
  end
  
  // Propagar señales de control y datos
  assign alu_result_out = alu_result_in;
  assign write_register_out = write_register_in;
  assign reg_write_out = reg_write_in;
  assign mem_to_reg_out = mem_to_reg_in;
  assign pc_plus_4_out = pc_plus_4_in;
  assign is_jal_out = is_jal_in;
  
  // Mensaje de depuración para operaciones de memoria
  always @(posedge clk) begin
    if (mem_write_in)
      $display("DEBUG_MEM_SIGNALS: mem_write_in=%b, write_data_in=%0d, addr=%0d, calculated_index=%0d", 
               mem_write_in, write_data_in, alu_result_in, alu_result_in >> 2);
      
    // Depuración específica para instrucciones SW con base en $3
    if (mem_write_in && (alu_result_in >= 100 && alu_result_in < 120)) begin
      $display("DEBUG_SW_REG3: Ciclo=%0t, Dirección base=$3=%0d, Dato=%0d, Ubicación memoria=%0d",
               $time, alu_result_in, write_data_in, alu_result_in >> 2);
    end
      
    if (mem_read_in)
      $display("DEBUG_MEM_SIGNALS: mem_read_in=%b, addr=%0d, calculated_index=%0d, read_data=%0d", 
               mem_read_in, alu_result_in, alu_result_in >> 2, read_data_out);
  end

endmodule
