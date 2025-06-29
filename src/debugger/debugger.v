`timescale 1ns / 1ps

module debugger(
    input  wire        clk,
    input  wire        reset,
    
    // UART interface
    input  wire [7:0]  uart_r_data,      // Datos leídos del UART
    input  wire        uart_rx_empty,    // FIFO RX vacío
    input  wire        uart_tx_full,     // FIFO TX lleno
    input  wire        uart_tx_done_tick,// Tick de transmisión completa
    output reg         uart_rd_uart,     // Señal para leer del UART
    output reg         uart_wr_uart,     // Señal para escribir al UART
    output reg  [7:0]  uart_w_data,      // Datos para escribir al UART
    
    // MIPS interface
    output reg         mips_reset,
    output reg         mips_inst_write_en,
    output reg  [31:0] mips_inst_write_addr,
    output reg  [31:0] mips_inst_write_data,
    output reg         mips_stall,        // Control de stall del MIPS
    input  wire        mips_halt,         // Señal de halt del MIPS
    
    // MIPS debug read interface
    output reg  [4:0]  mips_reg_addr,     // Dirección de registro para debug
    input  wire [31:0] mips_reg_data,     // Datos del registro
    output reg  [31:0] mips_mem_addr,     // Dirección de memoria para debug
    input  wire [31:0] mips_mem_data      // Datos de memoria
);

    // Estados de la máquina de estados
    localparam IDLE                 = 4'b0000;
    localparam WAIT_INSTR_BYTES     = 4'b0001;
    localparam WRITE_INSTRUCTION    = 4'b0010;
    localparam SEND_ACK             = 4'b0011;
    localparam RESET_MIPS           = 4'b0100;
    localparam WAIT_REG_ADDR        = 4'b0101;
    localparam READ_REGISTER        = 4'b0110;
    localparam SEND_REG_DATA        = 4'b0111;
    localparam WAIT_MEM_ADDR_BYTES  = 4'b1000;
    localparam READ_MEMORY          = 4'b1001;
    localparam SEND_MEM_DATA        = 4'b1010;
    localparam FREE_RUN             = 4'b1011;

    // Códigos de comando
    localparam CMD_LOAD_INSTRUCTION = 8'b00000001;
    localparam CMD_RESET            = 8'b11111111;
    localparam CMD_REG              = 8'b00000010;
    localparam CMD_MEM              = 8'b00000011;
    localparam CMD_FREE_RUN         = 8'b00000100;
    localparam ACK_CODE             = 8'b11111111;

    // Registros internos
    reg [3:0]  state, next_state;
    reg [31:0] instruction_buffer;
    reg [31:0] instruction_address;
    reg [3:0]  reset_counter;
    reg [1:0]  byte_counter;  // Contador para los 4 bytes
    reg        tx_done_flag;
    reg [31:0] mem_addr_buffer;  // Buffer para direcciones de memoria
    reg [4:0]  reg_addr_buffer;  // Buffer para dirección de registro
    reg [31:0] read_data_buffer; // Buffer para datos leídos
    reg [1:0]  tx_byte_counter;  // Contador para envío de bytes
    
    // Nuevos registros para control UART
    reg        uart_rx_available;    // Datos RX disponibles
    reg        uart_tx_in_progress;  // Transmisión en progreso
    reg        uart_read_request;    // Solicitud de lectura pendiente
    reg [7:0]  uart_rx_data_reg;     // Registro para datos RX leídos

    // Lógica secuencial para cambio de estados
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            instruction_address <= 32'h00000000;
            reset_counter <= 4'h0;
            byte_counter <= 2'b00;
            tx_done_flag <= 1'b0;
            mem_addr_buffer <= 32'h00000000;
            reg_addr_buffer <= 5'h00;
            read_data_buffer <= 32'h00000000;
            tx_byte_counter <= 2'b00;
            uart_rx_available <= 1'b0;
            uart_tx_in_progress <= 1'b0;
            uart_read_request <= 1'b0;
            uart_rx_data_reg <= 8'h00;
        end else begin
            state <= next_state;
            
            // Detección de datos RX disponibles
            uart_rx_available <= ~uart_rx_empty;
            
            // Control de solicitud de lectura UART
            if (uart_rx_available && !uart_read_request && 
                (state == IDLE || state == WAIT_INSTR_BYTES || 
                 state == WAIT_REG_ADDR || state == WAIT_MEM_ADDR_BYTES || 
                 state == FREE_RUN)) begin
                uart_read_request <= 1'b1;
            end else if (uart_read_request) begin
                uart_read_request <= 1'b0;
                uart_rx_data_reg <= uart_r_data;
            end
            
            // Contador para los bytes de instrucción
            if (state == WAIT_INSTR_BYTES && uart_read_request) begin
                byte_counter <= byte_counter + 1;
            end else if (state == IDLE) begin
                byte_counter <= 2'b00;
            end
            
            // Contador para bytes de dirección de memoria
            if (state == WAIT_MEM_ADDR_BYTES && uart_read_request) begin
                byte_counter <= byte_counter + 1;
            end else if (state == IDLE || state == WAIT_REG_ADDR) begin
                byte_counter <= 2'b00;
            end
            
            // Contador para el reset del MIPS
            if (state == RESET_MIPS) begin
                if (reset_counter < 4'hF)
                    reset_counter <= reset_counter + 1;
            end else begin
                reset_counter <= 4'h0;
            end
            
            // Control de transmisión TX
            if (uart_tx_done_tick) begin
                uart_tx_in_progress <= 1'b0;
                if (state == SEND_ACK) begin
                    tx_done_flag <= 1'b1;
                end else if ((state == SEND_REG_DATA || state == SEND_MEM_DATA)) begin
                    tx_byte_counter <= tx_byte_counter + 1;
                    if (tx_byte_counter == 2'b11) begin
                        tx_done_flag <= 1'b1;
                    end
                end
            end else if (state == IDLE || state == READ_REGISTER || state == READ_MEMORY) begin
                tx_byte_counter <= 2'b00;
                tx_done_flag <= 1'b0;
            end else if (state != SEND_ACK && state != SEND_REG_DATA && state != SEND_MEM_DATA) begin
                tx_done_flag <= 1'b0;
            end
        end
    end

    // Lógica combinacional para próximo estado
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (uart_read_request && !uart_rx_empty) begin
                    case (uart_r_data)
                        CMD_LOAD_INSTRUCTION: next_state = WAIT_INSTR_BYTES;
                        CMD_RESET:            next_state = RESET_MIPS;
                        CMD_REG:              next_state = WAIT_REG_ADDR;
                        CMD_MEM:              next_state = WAIT_MEM_ADDR_BYTES;
                        CMD_FREE_RUN:         next_state = FREE_RUN;
                        default:              next_state = IDLE;
                    endcase
                end
            end
            
            WAIT_INSTR_BYTES: begin
                if (uart_read_request && byte_counter == 2'b11)
                    next_state = WRITE_INSTRUCTION;
            end
            
            WRITE_INSTRUCTION: begin
                next_state = SEND_ACK;
            end
            
            WAIT_REG_ADDR: begin
                if (uart_read_request)
                    next_state = READ_REGISTER;
            end
            
            READ_REGISTER: begin
                next_state = SEND_REG_DATA;
            end
            
            SEND_REG_DATA: begin
                if (tx_done_flag)
                    next_state = SEND_ACK;
            end
            
            WAIT_MEM_ADDR_BYTES: begin
                if (uart_read_request && byte_counter == 2'b11)
                    next_state = READ_MEMORY;
            end
            
            READ_MEMORY: begin
                next_state = SEND_MEM_DATA;
            end
            
            SEND_MEM_DATA: begin
                if (tx_done_flag)
                    next_state = SEND_ACK;
            end
            
            SEND_ACK: begin
                if (tx_done_flag)
                    next_state = IDLE;
            end
            
            RESET_MIPS: begin
                if (reset_counter >= 4'hF)
                    next_state = IDLE;
            end
            
            FREE_RUN: begin
                // Si recibimos un comando de RESET, interrumpir la ejecución
                if (uart_read_request && uart_r_data == CMD_RESET) begin
                    next_state = RESET_MIPS;
                end
                // Si el MIPS indica HALT, enviar ACK y volver a IDLE
                else if (mips_halt) begin
                    next_state = SEND_ACK;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Lógica para capturar los bytes de la instrucción y direcciones
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            instruction_buffer <= 32'h00000000;
            mem_addr_buffer <= 32'h00000000;
            reg_addr_buffer <= 5'h00;
        end else begin
            // Captura de bytes de instrucción
            if (state == WAIT_INSTR_BYTES && uart_read_request) begin
                case (byte_counter)
                    2'b00: instruction_buffer[31:24] <= uart_rx_data_reg;  // Primer byte (MSB)
                    2'b01: instruction_buffer[23:16] <= uart_rx_data_reg;  // Segundo byte
                    2'b10: instruction_buffer[15:8]  <= uart_rx_data_reg;  // Tercer byte
                    2'b11: instruction_buffer[7:0]   <= uart_rx_data_reg;  // Cuarto byte (LSB)
                endcase
            end
            
            // Captura de dirección de registro (1 byte, solo 5 bits usados)
            if (state == WAIT_REG_ADDR && uart_read_request) begin
                reg_addr_buffer <= uart_rx_data_reg[4:0];
            end
            
            // Captura de bytes de dirección de memoria
            if (state == WAIT_MEM_ADDR_BYTES && uart_read_request) begin
                case (byte_counter)
                    2'b00: mem_addr_buffer[31:24] <= uart_rx_data_reg;  // Primer byte (MSB)
                    2'b01: mem_addr_buffer[23:16] <= uart_rx_data_reg;  // Segundo byte
                    2'b10: mem_addr_buffer[15:8]  <= uart_rx_data_reg;  // Tercer byte
                    2'b11: mem_addr_buffer[7:0]   <= uart_rx_data_reg;  // Cuarto byte (LSB)
                endcase
            end
        end
    end

    // Lógica para capturar datos leídos del MIPS
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            read_data_buffer <= 32'h00000000;
        end else begin
            // Capturar datos del registro
            if (state == READ_REGISTER) begin
                read_data_buffer <= mips_reg_data;
            end
            // Capturar datos de memoria
            else if (state == READ_MEMORY) begin
                read_data_buffer <= mips_mem_data;
            end
        end
    end
    // Lógica de salida
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            mips_reset <= 1'b1;
            mips_inst_write_en <= 1'b0;
            mips_inst_write_addr <= 32'h00000000;
            mips_inst_write_data <= 32'h00000000;
            mips_stall <= 1'b1;  // Iniciar con MIPS en stall
            mips_reg_addr <= 5'h00;
            mips_mem_addr <= 32'h00000000;
            uart_w_data <= 8'h00;
            uart_wr_uart <= 1'b0;
            uart_rd_uart <= 1'b0;
        end else begin
            // Valores por defecto
            mips_inst_write_en <= 1'b0;
            uart_wr_uart <= 1'b0;
            uart_rd_uart <= 1'b0;
            mips_stall <= 1'b1;  // Por defecto MIPS en stall
            
            // Control de lectura UART
            if (uart_read_request && uart_rx_available) begin
                uart_rd_uart <= 1'b1;
            end
            
            case (state)
                IDLE: begin
                    mips_reset <= 1'b0;
                end
                
                FREE_RUN: begin
                    mips_stall <= 1'b0;  // Liberar el stall para permitir ejecución
                end
                
                WRITE_INSTRUCTION: begin
                    mips_inst_write_en <= 1'b1;
                    mips_inst_write_addr <= instruction_address;
                    mips_inst_write_data <= instruction_buffer;
                    // Incrementar la dirección para la próxima instrucción
                    instruction_address <= instruction_address + 4;
                end
                
                READ_REGISTER: begin
                    mips_reg_addr <= reg_addr_buffer;
                end
                
                READ_MEMORY: begin
                    mips_mem_addr <= mem_addr_buffer;
                end
                
                SEND_REG_DATA, SEND_MEM_DATA: begin
                    if (!tx_done_flag && !uart_tx_full && !uart_tx_in_progress) begin
                        case (tx_byte_counter)
                            2'b00: uart_w_data <= read_data_buffer[31:24];  // MSB
                            2'b01: uart_w_data <= read_data_buffer[23:16];
                            2'b10: uart_w_data <= read_data_buffer[15:8];
                            2'b11: uart_w_data <= read_data_buffer[7:0];    // LSB
                        endcase
                        uart_wr_uart <= 1'b1;
                        uart_tx_in_progress <= 1'b1;
                    end
                end
                
                SEND_ACK: begin
                    if (!tx_done_flag && !uart_tx_full && !uart_tx_in_progress) begin
                        uart_w_data <= ACK_CODE;
                        uart_wr_uart <= 1'b1;
                        uart_tx_in_progress <= 1'b1;
                    end
                end
                
                RESET_MIPS: begin
                    mips_reset <= 1'b1;
                    // Reiniciar variables internas del debugger
                    if (reset_counter == 4'h1) begin
                        instruction_address <= 32'h00000000;
                    end
                end
            endcase
        end
    end

endmodule
