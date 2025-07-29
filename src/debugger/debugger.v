`timescale 1ns / 1ps

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
    
    // Debug latch signals - IF/ID
    input  wire [31:0] debug_if_id_instr,
    input  wire [31:0] debug_if_id_next_pc,
    
    // Debug latch signals - ID/EX
    input  wire [31:0] debug_id_ex_read_data1,
    input  wire [31:0] debug_id_ex_read_data2,
    input  wire [31:0] debug_id_ex_sign_ext_imm,
    input  wire [4:0]  debug_id_ex_rs,
    input  wire [4:0]  debug_id_ex_rt,
    input  wire [4:0]  debug_id_ex_rd,
    input  wire [31:0] debug_id_ex_shamt,
    input  wire [31:0] debug_id_ex_next_pc,
    input  wire        debug_id_ex_reg_dst,
    input  wire        debug_id_ex_alu_src_b,
    input  wire [1:0]  debug_id_ex_alu_src_a,
    input  wire [3:0]  debug_id_ex_alu_control,
    input  wire        debug_id_ex_mem_read,
    input  wire        debug_id_ex_mem_write,
    input  wire        debug_id_ex_reg_write,
    input  wire        debug_id_ex_mem_to_reg,
    input  wire        debug_id_ex_is_halt,
    input  wire [3:0]  debug_id_ex_byte_mask,
    input  wire        debug_id_ex_is_signed_load,
    
    // Debug latch signals - EX/MEM
    input  wire [31:0] debug_ex_mem_alu_result,
    input  wire [31:0] debug_ex_mem_write_data,
    input  wire [4:0]  debug_ex_mem_write_reg,
    input  wire        debug_ex_mem_reg_write,
    input  wire        debug_ex_mem_mem_read,
    input  wire        debug_ex_mem_mem_write,
    input  wire        debug_ex_mem_mem_to_reg,
    input  wire        debug_ex_mem_is_halt,
    input  wire [3:0]  debug_ex_mem_byte_mask,
    input  wire        debug_ex_mem_is_signed_load,
    
    // Debug latch signals - MEM/WB
    input  wire [31:0] debug_mem_wb_write_data,
    input  wire [4:0]  debug_mem_wb_write_reg,
    input  wire        debug_mem_wb_reg_write,
    input  wire        debug_mem_wb_is_halt,
    
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
    localparam READ_REG     = 4'b1001;  // Leyendo número de registro
    localparam SEND_REG_VAL = 4'b1010;  // Enviando valor del registro
    localparam READ_MEM     = 4'b1011;  // Leyendo dirección de memoria
    localparam SEND_MEM_VAL = 4'b1100;  // Enviando valor de memoria
    localparam STEP         = 4'b1101;  // Ejecutando un solo ciclo
    localparam SEND_LATCH   = 4'b1110;  // Enviando datos de latch
    localparam LATCH_ACK    = 4'b1111;  // Enviando ACK final de latch
    
    // ======== Command Codes ========
    localparam CMD_LOAD     = 8'h4C;        // 'L' - Load program
    localparam CMD_RUN      = 8'h52;        // 'R' - Run program
    localparam CMD_RESET    = 8'h48;        // 'H' - Reset (Halt)
    localparam CMD_READ_REG = 8'h47;        // 'G' - Get register value
    localparam CMD_READ_MEM = 8'h4D;        // 'M' - Memory read
    localparam CMD_STEP     = 8'h53;        // 'S' - Step one cycle
    localparam CMD_LATCH_IFID   = 8'h31;    // '1' - Get IF/ID latch values
    localparam CMD_LATCH_IDEX   = 8'h32;    // '2' - Get ID/EX latch values
    localparam CMD_LATCH_EXMEM  = 8'h33;    // '3' - Get EX/MEM latch values
    localparam CMD_LATCH_MEMWB  = 8'h34;    // '4' - Get MEM/WB latch values
    localparam ACK_BYTE     = 8'h41;        // 'A' - Acknowledgment
    localparam HALT_INST    = 32'hFFFFFFFF; // Halt instruction code
    
    /*
    ======== LATCH DATA TRANSMISSION ORDER DOCUMENTATION ========
    
    When requesting latch data, each command sends data in the following order:
    All values are sent as 4 bytes (32-bit) in big-endian format, followed by an ACK byte.
    
    CMD_LATCH_IFID ('1'): IF/ID Latch - 2 values (8 bytes total + ACK)
    1. debug_if_id_instr (32 bits)
    2. debug_if_id_next_pc (32 bits)
    
    CMD_LATCH_IDEX ('2'): ID/EX Latch - 18 values (72 bytes total + ACK)
    1. debug_id_ex_read_data1 (32 bits)
    2. debug_id_ex_read_data2 (32 bits)
    3. debug_id_ex_sign_ext_imm (32 bits)
    4. debug_id_ex_rs (32 bits, extended from 5 bits)
    5. debug_id_ex_rt (32 bits, extended from 5 bits)
    6. debug_id_ex_rd (32 bits, extended from 5 bits)
    7. debug_id_ex_shamt (32 bits)
    8. debug_id_ex_next_pc (32 bits)
    9. debug_id_ex_reg_dst (32 bits, extended from 1 bit)
    10. debug_id_ex_alu_src_b (32 bits, extended from 1 bit)
    11. debug_id_ex_alu_src_a (32 bits, extended from 2 bits)
    12. debug_id_ex_alu_control (32 bits, extended from 4 bits)
    13. debug_id_ex_mem_read (32 bits, extended from 1 bit)
    14. debug_id_ex_mem_write (32 bits, extended from 1 bit)
    15. debug_id_ex_reg_write (32 bits, extended from 1 bit)
    16. debug_id_ex_mem_to_reg (32 bits, extended from 1 bit)
    17. debug_id_ex_is_halt (32 bits, extended from 1 bit)
    18. debug_id_ex_byte_mask (32 bits, extended from 4 bits)
    19. debug_id_ex_is_signed_load (32 bits, extended from 1 bit)
    
    CMD_LATCH_EXMEM ('3'): EX/MEM Latch - 10 values (40 bytes total + ACK)
    1. debug_ex_mem_alu_result (32 bits)
    2. debug_ex_mem_write_data (32 bits)
    3. debug_ex_mem_write_reg (32 bits, extended from 5 bits)
    4. debug_ex_mem_reg_write (32 bits, extended from 1 bit)
    5. debug_ex_mem_mem_read (32 bits, extended from 1 bit)
    6. debug_ex_mem_mem_write (32 bits, extended from 1 bit)
    7. debug_ex_mem_mem_to_reg (32 bits, extended from 1 bit)
    8. debug_ex_mem_is_halt (32 bits, extended from 1 bit)
    9. debug_ex_mem_byte_mask (32 bits, extended from 4 bits)
    10. debug_ex_mem_is_signed_load (32 bits, extended from 1 bit)
    
    CMD_LATCH_MEMWB ('4'): MEM/WB Latch - 4 values (16 bytes total + ACK)
    1. debug_mem_wb_write_data (32 bits)
    2. debug_mem_wb_write_reg (32 bits, extended from 5 bits)
    3. debug_mem_wb_reg_write (32 bits, extended from 1 bit)
    4. debug_mem_wb_is_halt (32 bits, extended from 1 bit)
    */
    
    // ======== State Machine Registers ========
    reg [3:0]  state, next_state;
    reg [3:0]  waiting_state, next_waiting_state;
    reg [1:0]  byte_counter, next_byte_counter;
    reg [31:0] instruction_buffer, next_instruction_buffer;
    reg [31:0] inst_addr, next_inst_addr;
    reg [1:0]  result_byte_counter, next_result_byte_counter;
    reg [4:0]  requested_reg, next_requested_reg;
    reg [1:0]  reg_byte_counter, next_reg_byte_counter;
    reg [15:0] requested_mem_addr, next_requested_mem_addr;
    reg [1:0]  mem_addr_byte_counter, next_mem_addr_byte_counter;
    reg [1:0]  mem_byte_counter, next_mem_byte_counter;
    reg        step_cycle_done, next_step_cycle_done;
    
    // Latch transmission control
    reg [1:0]  latch_type, next_latch_type;        // Which latch (0=IF/ID, 1=ID/EX, 2=EX/MEM, 3=MEM/WB)
    reg [4:0]  latch_data_index, next_latch_data_index; // Which data field to send (0-18)
    reg [1:0]  latch_byte_counter, next_latch_byte_counter; // Which byte of current field (0-3)
    
    // ======== State Register Update ========
    always @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            waiting_state <= IDLE;
            byte_counter <= 2'b00;
            instruction_buffer <= 32'h00000000;
            inst_addr <= 32'h00000000;
            result_byte_counter <= 2'b00;
            requested_reg <= 5'b00000;
            reg_byte_counter <= 2'b00;
            requested_mem_addr <= 16'h0000;
            mem_addr_byte_counter <= 2'b00;
            mem_byte_counter <= 2'b00;
            step_cycle_done <= 1'b0;
            latch_type <= 2'b00;
            latch_data_index <= 5'b00000;
            latch_byte_counter <= 2'b00;
        end else begin
            state <= next_state;
            waiting_state <= next_waiting_state;
            byte_counter <= next_byte_counter;
            instruction_buffer <= next_instruction_buffer;
            inst_addr <= next_inst_addr;
            result_byte_counter <= next_result_byte_counter;
            requested_reg <= next_requested_reg;
            reg_byte_counter <= next_reg_byte_counter;
            requested_mem_addr <= next_requested_mem_addr;
            mem_addr_byte_counter <= next_mem_addr_byte_counter;
            mem_byte_counter <= next_mem_byte_counter;
            step_cycle_done <= next_step_cycle_done;
            latch_type <= next_latch_type;
            latch_data_index <= next_latch_data_index;
            latch_byte_counter <= next_latch_byte_counter;
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
        next_requested_reg = requested_reg;
        next_reg_byte_counter = reg_byte_counter;
        next_requested_mem_addr = requested_mem_addr;
        next_mem_addr_byte_counter = mem_addr_byte_counter;
        next_mem_byte_counter = mem_byte_counter;
        next_step_cycle_done = step_cycle_done;
        next_latch_type = latch_type;
        next_latch_data_index = latch_data_index;
        next_latch_byte_counter = latch_byte_counter;
        
        case (state)
            IDLE: begin
                next_inst_addr = 32'h00000000;
                next_byte_counter = 2'b00;
                next_result_byte_counter = 2'b00;
                next_reg_byte_counter = 2'b00;
                next_mem_addr_byte_counter = 2'b00;
                next_mem_byte_counter = 2'b00;
                next_step_cycle_done = 1'b0;
                next_latch_data_index = 5'b00000;
                next_latch_byte_counter = 2'b00;
                
                if (!uart_rx_empty) begin
                    // Comando disponible en UART
                    if (uart_r_data == CMD_LOAD) begin
                        next_state = LOAD_PROG;
                    end else if (uart_r_data == CMD_RUN) begin
                        next_state = RUN;
                    end else if (uart_r_data == CMD_RESET) begin
                        next_state = MIPS_RESET;
                    end else if (uart_r_data == CMD_READ_REG) begin
                        next_state = READ_REG;
                    end else if (uart_r_data == CMD_READ_MEM) begin
                        next_state = READ_MEM;
                    end else if (uart_r_data == CMD_STEP) begin
                        next_state = STEP;
                    end else if (uart_r_data == CMD_LATCH_IFID) begin
                        next_state = SEND_LATCH;
                        next_latch_type = 2'b00;  // IF/ID
                    end else if (uart_r_data == CMD_LATCH_IDEX) begin
                        next_state = SEND_LATCH;
                        next_latch_type = 2'b01;  // ID/EX
                    end else if (uart_r_data == CMD_LATCH_EXMEM) begin
                        next_state = SEND_LATCH;
                        next_latch_type = 2'b10;  // EX/MEM
                    end else if (uart_r_data == CMD_LATCH_MEMWB) begin
                        next_state = SEND_LATCH;
                        next_latch_type = 2'b11;  // MEM/WB
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
                    // Programa terminado, enviar ACK
                    next_state = SEND_RESULT;
                end
                // Mientras no haya halt, seguir ejecutando
            end
            
            SEND_RESULT: begin
                if (uart_tx_full) begin
                    next_state = WAIT_TX;
                    next_waiting_state = SEND_RESULT;
                end else begin
                    // ACK enviado, volver a IDLE
                    next_state = IDLE;
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
            
            READ_REG: begin
                if (uart_rx_empty) begin
                    next_state = WAIT_RX;
                    next_waiting_state = READ_REG;
                end else begin
                    // Recibir número de registro (solo 5 bits válidos)
                    next_requested_reg = uart_r_data[4:0];
                    next_state = SEND_REG_VAL;
                    next_reg_byte_counter = 2'b00;
                end
            end
            
            SEND_REG_VAL: begin
                if (uart_tx_full) begin
                    next_state = WAIT_TX;
                    next_waiting_state = SEND_REG_VAL;
                end else begin
                    next_reg_byte_counter = reg_byte_counter + 1;
                    
                    if (reg_byte_counter == 2'b11) begin
                        // Valor del registro completo enviado
                        next_state = IDLE;
                        next_reg_byte_counter = 2'b00;
                    end
                end
            end
            
            READ_MEM: begin
                if (uart_rx_empty) begin
                    next_state = WAIT_RX;
                    next_waiting_state = READ_MEM;
                end else begin
                    // Recibir bytes de la dirección de memoria (big-endian, 2 bytes)
                    case (mem_addr_byte_counter)
                        2'b00: next_requested_mem_addr = {uart_r_data, 8'h00};
                        2'b01: next_requested_mem_addr = {requested_mem_addr[15:8], uart_r_data};
                    endcase
                    
                    next_mem_addr_byte_counter = mem_addr_byte_counter + 1;
                    
                    if (mem_addr_byte_counter == 2'b01) begin
                        // Dirección completa recibida
                        next_mem_addr_byte_counter = 2'b00;
                        next_state = SEND_MEM_VAL;
                        next_mem_byte_counter = 2'b00;
                    end
                end
            end
            
            SEND_MEM_VAL: begin
                if (uart_tx_full) begin
                    next_state = WAIT_TX;
                    next_waiting_state = SEND_MEM_VAL;
                end else begin
                    next_mem_byte_counter = mem_byte_counter + 1;
                    
                    if (mem_byte_counter == 2'b11) begin
                        // Valor de memoria completo enviado
                        next_state = IDLE;
                        next_mem_byte_counter = 2'b00;
                    end
                end
            end
            
            STEP: begin
                if (!step_cycle_done) begin
                    // Primer ciclo: ejecutar y marcar como hecho
                    next_step_cycle_done = 1'b1;
                end else begin
                    // Segundo ciclo: enviar ACK y volver a IDLE
                    next_step_cycle_done = 1'b0;
                    next_state = SEND_ACK;
                    next_waiting_state = IDLE;
                end
            end
            
            SEND_LATCH: begin
                if (uart_tx_full) begin
                    next_state = WAIT_TX;
                    next_waiting_state = SEND_LATCH;
                end else begin
                    next_latch_byte_counter = latch_byte_counter + 1;
                    
                    if (latch_byte_counter == 2'b11) begin
                        // 4 bytes del campo actual enviados
                        next_latch_byte_counter = 2'b00;
                        next_latch_data_index = latch_data_index + 1;
                        
                        // Check if all data for this latch type has been sent
                        case (latch_type)
                            2'b00: begin // IF/ID - 2 fields
                                if (latch_data_index == 5'd1) begin
                                    next_state = LATCH_ACK;
                                end
                            end
                            2'b01: begin // ID/EX - 19 fields
                                if (latch_data_index == 5'd18) begin
                                    next_state = LATCH_ACK;
                                end
                            end
                            2'b10: begin // EX/MEM - 10 fields
                                if (latch_data_index == 5'd9) begin
                                    next_state = LATCH_ACK;
                                end
                            end
                            2'b11: begin // MEM/WB - 4 fields
                                if (latch_data_index == 5'd3) begin
                                    next_state = LATCH_ACK;
                                end
                            end
                        endcase
                    end
                end
            end
            
            LATCH_ACK: begin
                if (uart_tx_full) begin
                    next_state = WAIT_TX;
                    next_waiting_state = LATCH_ACK;
                end else begin
                    next_state = IDLE;
                end
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    // ======== Latch Data Selection ========
    reg [31:0] selected_latch_data;
    always @(*) begin
        case (latch_type)
            2'b00: begin // IF/ID
                case (latch_data_index)
                    5'd0: selected_latch_data = debug_if_id_instr;
                    5'd1: selected_latch_data = debug_if_id_next_pc;
                    default: selected_latch_data = 32'h00000000;
                endcase
            end
            2'b01: begin // ID/EX
                case (latch_data_index)
                    5'd0:  selected_latch_data = debug_id_ex_read_data1;
                    5'd1:  selected_latch_data = debug_id_ex_read_data2;
                    5'd2:  selected_latch_data = debug_id_ex_sign_ext_imm;
                    5'd3:  selected_latch_data = {27'b0, debug_id_ex_rs};
                    5'd4:  selected_latch_data = {27'b0, debug_id_ex_rt};
                    5'd5:  selected_latch_data = {27'b0, debug_id_ex_rd};
                    5'd6:  selected_latch_data = debug_id_ex_shamt;
                    5'd7:  selected_latch_data = debug_id_ex_next_pc;
                    5'd8:  selected_latch_data = {31'b0, debug_id_ex_reg_dst};
                    5'd9:  selected_latch_data = {31'b0, debug_id_ex_alu_src_b};
                    5'd10: selected_latch_data = {30'b0, debug_id_ex_alu_src_a};
                    5'd11: selected_latch_data = {28'b0, debug_id_ex_alu_control};
                    5'd12: selected_latch_data = {31'b0, debug_id_ex_mem_read};
                    5'd13: selected_latch_data = {31'b0, debug_id_ex_mem_write};
                    5'd14: selected_latch_data = {31'b0, debug_id_ex_reg_write};
                    5'd15: selected_latch_data = {31'b0, debug_id_ex_mem_to_reg};
                    5'd16: selected_latch_data = {31'b0, debug_id_ex_is_halt};
                    5'd17: selected_latch_data = {28'b0, debug_id_ex_byte_mask};
                    5'd18: selected_latch_data = {31'b0, debug_id_ex_is_signed_load};
                    default: selected_latch_data = 32'h00000000;
                endcase
            end
            2'b10: begin // EX/MEM
                case (latch_data_index)
                    5'd0: selected_latch_data = debug_ex_mem_alu_result;
                    5'd1: selected_latch_data = debug_ex_mem_write_data;
                    5'd2: selected_latch_data = {27'b0, debug_ex_mem_write_reg};
                    5'd3: selected_latch_data = {31'b0, debug_ex_mem_reg_write};
                    5'd4: selected_latch_data = {31'b0, debug_ex_mem_mem_read};
                    5'd5: selected_latch_data = {31'b0, debug_ex_mem_mem_write};
                    5'd6: selected_latch_data = {31'b0, debug_ex_mem_mem_to_reg};
                    5'd7: selected_latch_data = {31'b0, debug_ex_mem_is_halt};
                    5'd8: selected_latch_data = {28'b0, debug_ex_mem_byte_mask};
                    5'd9: selected_latch_data = {31'b0, debug_ex_mem_is_signed_load};
                    default: selected_latch_data = 32'h00000000;
                endcase
            end
            2'b11: begin // MEM/WB
                case (latch_data_index)
                    5'd0: selected_latch_data = debug_mem_wb_write_data;
                    5'd1: selected_latch_data = {27'b0, debug_mem_wb_write_reg};
                    5'd2: selected_latch_data = {31'b0, debug_mem_wb_reg_write};
                    5'd3: selected_latch_data = {31'b0, debug_mem_wb_is_halt};
                    default: selected_latch_data = 32'h00000000;
                endcase
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
                uart_w_data = ACK_BYTE;  // Enviar ACK simple
                mips_reset = 1'b0;
                mips_inst_write_en = 1'b0;
                mips_inst_write_addr = 32'h00000000;
                mips_inst_write_data = 32'h00000000;
                mips_stall = 1'b1;
                mips_reg_addr = 5'b00000;
                mips_mem_addr = 32'h00000000;
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
            
            READ_REG: begin
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
            
            SEND_REG_VAL: begin
                uart_rd_uart = 1'b0;
                uart_wr_uart = !uart_tx_full;
                mips_reset = 1'b0;
                mips_inst_write_en = 1'b0;
                mips_inst_write_addr = 32'h00000000;
                mips_inst_write_data = 32'h00000000;
                mips_stall = 1'b1;
                mips_reg_addr = requested_reg;  // Usar el registro solicitado
                mips_mem_addr = 32'h00000000;
                
                // Enviar valor del registro en big-endian
                case (reg_byte_counter)
                    2'b00: uart_w_data = mips_reg_data[31:24];
                    2'b01: uart_w_data = mips_reg_data[23:16];
                    2'b10: uart_w_data = mips_reg_data[15:8];
                    2'b11: uart_w_data = mips_reg_data[7:0];
                endcase
            end
            
            READ_MEM: begin
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
            
            SEND_MEM_VAL: begin
                uart_rd_uart = 1'b0;
                uart_wr_uart = !uart_tx_full;
                mips_reset = 1'b0;
                mips_inst_write_en = 1'b0;
                mips_inst_write_addr = 32'h00000000;
                mips_inst_write_data = 32'h00000000;
                mips_stall = 1'b1;
                mips_reg_addr = 5'b00000;
                mips_mem_addr = {16'h0000, requested_mem_addr};  // Usar la dirección solicitada
                
                // Enviar valor de memoria en big-endian
                case (mem_byte_counter)
                    2'b00: uart_w_data = mips_mem_data[31:24];
                    2'b01: uart_w_data = mips_mem_data[23:16];
                    2'b10: uart_w_data = mips_mem_data[15:8];
                    2'b11: uart_w_data = mips_mem_data[7:0];
                endcase
            end
            
            STEP: begin
                uart_rd_uart = 1'b0;
                uart_wr_uart = 1'b0;
                uart_w_data = 8'h00;
                mips_reset = 1'b0;
                mips_inst_write_en = 1'b0;
                mips_inst_write_addr = 32'h00000000;
                mips_inst_write_data = 32'h00000000;
                mips_stall = step_cycle_done;  // Solo NO stall en el primer ciclo
                mips_reg_addr = 5'b00000;
                mips_mem_addr = 32'h00000000;
            end
            
            SEND_LATCH: begin
                uart_rd_uart = 1'b0;
                uart_wr_uart = !uart_tx_full;
                mips_reset = 1'b0;
                mips_inst_write_en = 1'b0;
                mips_inst_write_addr = 32'h00000000;
                mips_inst_write_data = 32'h00000000;
                mips_stall = 1'b1;
                mips_reg_addr = 5'b00000;
                mips_mem_addr = 32'h00000000;
                
                // Enviar datos del latch seleccionado en big-endian
                case (latch_byte_counter)
                    2'b00: uart_w_data = selected_latch_data[31:24];
                    2'b01: uart_w_data = selected_latch_data[23:16];
                    2'b10: uart_w_data = selected_latch_data[15:8];
                    2'b11: uart_w_data = selected_latch_data[7:0];
                endcase
            end
            
            LATCH_ACK: begin
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
