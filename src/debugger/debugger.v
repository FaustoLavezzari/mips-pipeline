`timescale 1ns / 1ps

//===========================================
// Module: debugger
//
// Description:
//    Simple debugger for MIPS pipeline processor.
//    Handles instruction loading via UART and free-run execution.
//    Sends ACK after each instruction write and final result after halt.
//
// Author: Assistant based on reference design
// Created: 2025
//
// Commands (1 byte):
// - 0x4C ('L'): Load Program mode - start receiving instructions
// - 0x52 ('R'): Run mode - execute loaded program until halt
// - 0x48 ('H'): Reset MIPS processor
//
// Protocol:
// 1. Send 'L' to enter load mode
// 2. Send 4 bytes per instruction (big-endian: [31:24][23:16][15:8][7:0])
// 3. Receive ACK (0x41) after each complete instruction
// 4. Send 'R' to start execution
// 5. Processor runs until halt, then sends result
//===========================================

module debugger(
    // Clock and reset
    input  wire        clk,
    input  wire        reset,
    
    // UART interface
    input  wire [7:0]  uart_r_data,
    input  wire        uart_rx_empty,
    input  wire        uart_tx_full,
    input  wire        uart_tx_done_tick,
    output reg         uart_rd_uart,
    output reg         uart_wr_uart,
    output reg  [7:0]  uart_w_data,
    
    // MIPS control interface
    output reg         mips_reset,
    output reg         mips_inst_write_en,
    output reg  [31:0] mips_inst_write_addr,
    output reg  [31:0] mips_inst_write_data,
    output reg         mips_stall,
    input  wire        mips_halt,
    
    // MIPS debug read interface
    output reg  [4:0]  mips_reg_addr,
    input  wire [31:0] mips_reg_data,
    output reg  [31:0] mips_mem_addr,
    input  wire [31:0] mips_mem_data,
    
    // Debugger state output for LEDs
    output wire [3:0]  debugger_state
);

    // ======== State Machine Parameters ========
    localparam IDLE         = 4'b0000;  // Esperando comando
    localparam LOAD_PROG    = 4'b0001;  // Cargando programa
    localparam WRITE_INST   = 4'b0010;  // Escribiendo instrucción en memoria
    localparam SEND_ACK     = 4'b0011;  // Enviando ACK
    localparam RUN          = 4'b0100;  // Ejecutando programa
    localparam SEND_RESULT  = 4'b0101;  // Enviando resultado
    localparam MIPS_RESET   = 4'b0110;  // Reseteando MIPS
    localparam WAIT_RX      = 4'b0111;  // Esperando datos UART RX
    localparam WAIT_TX      = 4'b1000;  // Esperando que UART TX esté libre
    
    // ======== Command Codes ========
    localparam CMD_LOAD     = 8'h4C;    // 'L' - Load program
    localparam CMD_RUN      = 8'h52;    // 'R' - Run program
    localparam CMD_RESET    = 8'h48;    // 'H' - Reset (Halt)
    localparam ACK_BYTE     = 8'h41;    // 'A' - Acknowledgment
    localparam HALT_INST    = 32'hFFFFFFFF;   // Halt instruction code
    
    // ======== State Machine Registers ========
    reg [3:0]  state, next_state;
    reg [3:0]  waiting_state, next_waiting_state;
    reg [1:0]  byte_counter, next_byte_counter;
    reg [31:0] instruction_buffer, next_instruction_buffer;
    reg [31:0] inst_addr, next_inst_addr;
    reg [1:0]  result_byte_counter, next_result_byte_counter;
    
    // ======== State Register Update ========
    always @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            waiting_state <= IDLE;
            byte_counter <= 2'b00;
            instruction_buffer <= 32'h00000000;
            inst_addr <= 32'h00000000;
            result_byte_counter <= 2'b00;
        end else begin
            state <= next_state;
            waiting_state <= next_waiting_state;
            byte_counter <= next_byte_counter;
            instruction_buffer <= next_instruction_buffer;
            inst_addr <= next_inst_addr;
            result_byte_counter <= next_result_byte_counter;
        end
    end
    
    // ======== Next State Logic ========
    always @(*) begin
        // Default values
        next_state = state;
        next_waiting_state = waiting_state;
        next_byte_counter = byte_counter;
        next_instruction_buffer = instruction_buffer;
        next_inst_addr = inst_addr;
        next_result_byte_counter = result_byte_counter;
        
        case (state)
            IDLE: begin
                next_inst_addr = 32'h00000000;
                next_byte_counter = 2'b00;
                next_result_byte_counter = 2'b00;
                
                if (!uart_rx_empty) begin
                    // Comando disponible en UART
                    if (uart_r_data == CMD_LOAD) begin
                        next_state = LOAD_PROG;
                    end else if (uart_r_data == CMD_RUN) begin
                        next_state = RUN;
                    end else if (uart_r_data == CMD_RESET) begin
                        next_state = MIPS_RESET;
                    end
                    // Si no es un comando válido, permanece en IDLE
                end
            end
            
            LOAD_PROG: begin
                if (uart_rx_empty) begin
                    next_state = WAIT_RX;
                    next_waiting_state = LOAD_PROG;
                end else begin
                    // Recibir bytes de la instrucción (big-endian)
                    case (byte_counter)
                        2'b00: next_instruction_buffer = {uart_r_data, 24'h000000};
                        2'b01: next_instruction_buffer = {instruction_buffer[31:24], uart_r_data, 16'h0000};
                        2'b10: next_instruction_buffer = {instruction_buffer[31:16], uart_r_data, 8'h00};
                        2'b11: next_instruction_buffer = {instruction_buffer[31:8], uart_r_data};
                    endcase
                    
                    next_byte_counter = byte_counter + 1;
                    
                    if (byte_counter == 2'b11) begin
                        // Instrucción completa recibida
                        next_byte_counter = 2'b00;
                        next_state = WRITE_INST;
                    end
                end
            end
            
            WRITE_INST: begin
                // Escribir instrucción en memoria y avanzar dirección
                next_inst_addr = inst_addr + 4;
                
                if (instruction_buffer == HALT_INST) begin
                    // Si es instrucción HALT, volver a IDLE (programa completo)
                    next_state = SEND_ACK;
                    next_waiting_state = IDLE;
                end else begin
                    // Continuar cargando más instrucciones
                    next_state = SEND_ACK;
                    next_waiting_state = LOAD_PROG;
                end
            end
            
            SEND_ACK: begin
                if (uart_tx_full) begin
                    next_state = WAIT_TX;
                    next_waiting_state = SEND_ACK;
                end else begin
                    next_state = waiting_state;
                end
            end
            
            RUN: begin
                if (mips_halt) begin
                    // Programa terminado, enviar resultado
                    next_state = SEND_RESULT;
                    next_result_byte_counter = 2'b00;
                end
                // Mientras no haya halt, seguir ejecutando
            end
            
            SEND_RESULT: begin
                if (uart_tx_full) begin
                    next_state = WAIT_TX;
                    next_waiting_state = SEND_RESULT;
                end else begin
                    next_result_byte_counter = result_byte_counter + 1;
                    
                    if (result_byte_counter == 2'b11) begin
                        // Resultado completo enviado
                        next_state = IDLE;
                        next_result_byte_counter = 2'b00;
                    end
                end
            end
            
            MIPS_RESET: begin
                next_state = IDLE;
            end
            
            WAIT_RX: begin
                if (!uart_rx_empty) begin
                    next_state = waiting_state;
                end
            end
            
            WAIT_TX: begin
                if (!uart_tx_full) begin
                    next_state = waiting_state;
                end
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    // ======== Output Logic ========
    always @(*) begin
        case (state)
            IDLE: begin
                uart_rd_uart = !uart_rx_empty;
                uart_wr_uart = 1'b0;
                uart_w_data = 8'h00;
                mips_reset = 1'b0;
                mips_inst_write_en = 1'b0;
                mips_inst_write_addr = 32'h00000000;
                mips_inst_write_data = 32'h00000000;
                mips_stall = 1'b1;
                mips_reg_addr = 5'b00000;
                mips_mem_addr = 32'h00000000;
            end
            
            LOAD_PROG: begin
                uart_rd_uart = !uart_rx_empty;
                uart_wr_uart = 1'b0;
                uart_w_data = 8'h00;
                mips_reset = 1'b0;
                mips_inst_write_en = 1'b0;
                mips_inst_write_addr = 32'h00000000;
                mips_inst_write_data = 32'h00000000;
                mips_stall = 1'b1;
                mips_reg_addr = 5'b00000;
                mips_mem_addr = 32'h00000000;
            end
            
            WRITE_INST: begin
                uart_rd_uart = 1'b0;
                uart_wr_uart = 1'b0;
                uart_w_data = 8'h00;
                mips_reset = 1'b0;
                mips_inst_write_en = 1'b1;
                mips_inst_write_addr = inst_addr;
                mips_inst_write_data = instruction_buffer;
                mips_stall = 1'b1;
                mips_reg_addr = 5'b00000;
                mips_mem_addr = 32'h00000000;
            end
            
            SEND_ACK: begin
                uart_rd_uart = 1'b0;
                uart_wr_uart = !uart_tx_full;
                uart_w_data = ACK_BYTE;
                mips_reset = 1'b0;
                mips_inst_write_en = 1'b0;
                mips_inst_write_addr = 32'h00000000;
                mips_inst_write_data = 32'h00000000;
                mips_stall = 1'b1;
                mips_reg_addr = 5'b00000;
                mips_mem_addr = 32'h00000000;
            end
            
            RUN: begin
                uart_rd_uart = 1'b0;
                uart_wr_uart = 1'b0;
                uart_w_data = 8'h00;
                mips_reset = 1'b0;
                mips_inst_write_en = 1'b0;
                mips_inst_write_addr = 32'h00000000;
                mips_inst_write_data = 32'h00000000;
                mips_stall = 1'b0;  // ¡MIPS corriendo!
                mips_reg_addr = 5'b00000;
                mips_mem_addr = 32'h00000000;
            end
            
            SEND_RESULT: begin
                uart_rd_uart = 1'b0;
                uart_wr_uart = !uart_tx_full;
                mips_reset = 1'b0;
                mips_inst_write_en = 1'b0;
                mips_inst_write_addr = 32'h00000000;
                mips_inst_write_data = 32'h00000000;
                mips_stall = 1'b1;
                mips_reg_addr = 5'b00010;  // Registro $v0 (resultado)
                mips_mem_addr = 32'h00000000;
                
                // Enviar resultado en big-endian
                case (result_byte_counter)
                    2'b00: uart_w_data = mips_reg_data[31:24];
                    2'b01: uart_w_data = mips_reg_data[23:16];
                    2'b10: uart_w_data = mips_reg_data[15:8];
                    2'b11: uart_w_data = mips_reg_data[7:0];
                endcase
            end
            
            MIPS_RESET: begin
                uart_rd_uart = 1'b0;
                uart_wr_uart = 1'b0;
                uart_w_data = 8'h00;
                mips_reset = 1'b1;  // ¡Reset activo!
                mips_inst_write_en = 1'b0;
                mips_inst_write_addr = 32'h00000000;
                mips_inst_write_data = 32'h00000000;
                mips_stall = 1'b1;
                mips_reg_addr = 5'b00000;
                mips_mem_addr = 32'h00000000;
            end
            
            WAIT_RX: begin
                uart_rd_uart = 1'b0;
                uart_wr_uart = 1'b0;
                uart_w_data = 8'h00;
                mips_reset = 1'b0;
                mips_inst_write_en = 1'b0;
                mips_inst_write_addr = 32'h00000000;
                mips_inst_write_data = 32'h00000000;
                mips_stall = 1'b1;
                mips_reg_addr = 5'b00000;
                mips_mem_addr = 32'h00000000;
            end
            
            WAIT_TX: begin
                uart_rd_uart = 1'b0;
                uart_wr_uart = 1'b0;
                uart_w_data = 8'h00;
                mips_reset = 1'b0;
                mips_inst_write_en = 1'b0;
                mips_inst_write_addr = 32'h00000000;
                mips_inst_write_data = 32'h00000000;
                mips_stall = 1'b1;
                mips_reg_addr = 5'b00000;
                mips_mem_addr = 32'h00000000;
            end
            
            default: begin
                uart_rd_uart = 1'b0;
                uart_wr_uart = 1'b0;
                uart_w_data = 8'h00;
                mips_reset = 1'b0;
                mips_inst_write_en = 1'b0;
                mips_inst_write_addr = 32'h00000000;
                mips_inst_write_data = 32'h00000000;
                mips_stall = 1'b1;
                mips_reg_addr = 5'b00000;
                mips_mem_addr = 32'h00000000;
            end
        endcase
    end
    
    // ======== Debug State Output ========
    assign debugger_state = state;

endmodule
