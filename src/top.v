`timescale 1ns / 1ps

/*
======== MIPS PIPELINE DEBUG UART PROTOCOL ========

The debugger supports the following commands via UART:

Basic Commands:
- 'L' (0x4C): Load program
- 'R' (0x52): Run program  
- 'H' (0x48): Reset/Halt MIPS
- 'G' (0x47): Get register value (requires 1 byte register number)
- 'M' (0x4D): Read memory (requires 2 bytes address)
- 'S' (0x53): Step one cycle

Latch Debug Commands:
- '1' (0x31): Get IF/ID latch values (2 fields, 8 bytes + ACK)
- '2' (0x32): Get ID/EX latch values (19 fields, 76 bytes + ACK)  
- '3' (0x33): Get EX/MEM latch values (10 fields, 40 bytes + ACK)
- '4' (0x34): Get MEM/WB latch values (4 fields, 16 bytes + ACK)

All latch data is sent as 32-bit big-endian values.
See debugger.v for detailed field transmission order.
*/

module top(
    input  wire        clk,          // Reloj del board (100MHz)
    input  wire        reset,        // Reset del board
    
    // UART physical interface
    input  wire        uart_rx,
    output wire        uart_tx,
    
    // RGB LEDs for MIPS status
    output wire        led0_r,       // MIPS halt (red)
    output wire        led1_r,       // MIPS stall (red)
    
    // Regular LEDs for debugger state (4 bits)
    output wire [3:0]  debugger_leds
);

    // ======== Señales de Clock Wizard ========
    wire        sys_clk;          // Reloj de 50MHz generado por Clock Wizard

    // ======== Parámetros UART ========
    localparam DBIT       = 8;     // data bits
    localparam SB_TICK    = 16;    // ticks for stop bits
    localparam DVSR       = 163;   // baud rate divisor (19200 baud)
    localparam DVSR_BITS  = 9;     // number of bits in divisor
    localparam FIFO_W     = 2;     // FIFO width (4 words)

    // ======== Señales internas UART ========
    wire [7:0]  uart_r_data;
    wire        uart_rx_empty_int;
    wire        uart_tx_full_int;
    wire        uart_tx_done_tick;
    wire        uart_rd_uart;
    wire        uart_wr_uart;
    wire [7:0]  uart_w_data;

    // ======== Señales internas MIPS ========
    wire        mips_reset;
    wire        mips_inst_write_en;
    wire [31:0] mips_inst_write_addr;
    wire [31:0] mips_inst_write_data;
    wire        mips_stall;     // Wire interno para stall
    wire        mips_halt;
    wire [31:0] mips_result_int;

    // ======== Señales de debug MIPS ========
    wire [4:0]  mips_reg_addr;
    wire [31:0] mips_reg_data;
    wire [31:0] mips_mem_addr;
    wire [31:0] mips_mem_data;
    
    // Debug latch signals - IF/ID
    wire [31:0] debug_if_id_instr;
    wire [31:0] debug_if_id_next_pc;
    
    // Debug latch signals - ID/EX
    wire [31:0] debug_id_ex_read_data1;
    wire [31:0] debug_id_ex_read_data2;
    wire [31:0] debug_id_ex_sign_ext_imm;
    wire [4:0]  debug_id_ex_rs;
    wire [4:0]  debug_id_ex_rt;
    wire [4:0]  debug_id_ex_rd;
    wire [31:0] debug_id_ex_shamt;
    wire [31:0] debug_id_ex_next_pc;
    wire        debug_id_ex_reg_dst;
    wire        debug_id_ex_alu_src_b;
    wire [1:0]  debug_id_ex_alu_src_a;
    wire [3:0]  debug_id_ex_alu_control;
    wire        debug_id_ex_mem_read;
    wire        debug_id_ex_mem_write;
    wire        debug_id_ex_reg_write;
    wire        debug_id_ex_mem_to_reg;
    wire        debug_id_ex_is_halt;
    wire [3:0]  debug_id_ex_byte_mask;
    wire        debug_id_ex_is_signed_load;
    
    // Debug latch signals - EX/MEM
    wire [31:0] debug_ex_mem_alu_result;
    wire [31:0] debug_ex_mem_write_data;
    wire [4:0]  debug_ex_mem_write_reg;
    wire        debug_ex_mem_reg_write;
    wire        debug_ex_mem_mem_read;
    wire        debug_ex_mem_mem_write;
    wire        debug_ex_mem_mem_to_reg;
    wire        debug_ex_mem_is_halt;
    wire [3:0]  debug_ex_mem_byte_mask;
    wire        debug_ex_mem_is_signed_load;
    
    // Debug latch signals - MEM/WB
    wire [31:0] debug_mem_wb_write_data;
    wire [4:0]  debug_mem_wb_write_reg;
    wire        debug_mem_wb_reg_write;
    wire        debug_mem_wb_is_halt;
    
    // ======== Señales de debug Debugger ========
    wire [3:0]  debugger_state;

    // ======== Asignaciones de salida ========
    assign led0_r = mips_halt;           // RGB LED 0 rojo para halt
    assign led1_r = mips_stall;          // RGB LED 1 rojo para stall
    assign debugger_leds = debugger_state; // LEDs normales para estado del debugger

    // ======== Instancia del Clock Wizard ========
    // NOTA: Este debe ser generado como IP en Vivado con el nombre 'clk_wiz_0'
    clk_wiz_0 u_clk_wiz_0 (
        // Clock out ports
        .clk_out1(sys_clk), 
        // Clock in ports
        .clk_in1(clk)
    );

    // ======== Instancia del módulo UART ========
    uart #(
        .DBIT(DBIT),
        .SB_TICK(SB_TICK),
        .DVSR(DVSR),
        .DVSR_BITS(DVSR_BITS),
        .FIFO_W(FIFO_W)
    ) uart_inst (
        .clk(sys_clk), 
        .reset(reset),
        .rd_uart(uart_rd_uart),
        .wr_uart(uart_wr_uart),
        .rx(uart_rx),
        .w_data(uart_w_data),
        .r_data(uart_r_data),
        .tx_full(uart_tx_full_int),
        .rx_empty(uart_rx_empty_int),
        .tx(uart_tx),
        .tx_done_tick(uart_tx_done_tick)
    );

    // ======== Instancia del módulo Debugger ========
    debugger debugger_inst (
        .clk(sys_clk),            
        .reset(reset),
        
        // UART interface
        .uart_r_data(uart_r_data),
        .uart_rx_empty(uart_rx_empty_int),
        .uart_tx_full(uart_tx_full_int),
        .uart_tx_done_tick(uart_tx_done_tick),
        .uart_rd_uart(uart_rd_uart),
        .uart_wr_uart(uart_wr_uart),
        .uart_w_data(uart_w_data),
        
        // MIPS interface
        .mips_reset(mips_reset),
        .mips_inst_write_en(mips_inst_write_en),
        .mips_inst_write_addr(mips_inst_write_addr),
        .mips_inst_write_data(mips_inst_write_data),
        .mips_stall(mips_stall),        
        .mips_halt(mips_halt),
        
        // MIPS debug read interface
        .mips_reg_addr(mips_reg_addr),
        .mips_reg_data(mips_reg_data),
        .mips_mem_addr(mips_mem_addr),
        .mips_mem_data(mips_mem_data),
        
        // Debug latch signals - IF/ID
        .debug_if_id_instr(debug_if_id_instr),
        .debug_if_id_next_pc(debug_if_id_next_pc),
        
        // Debug latch signals - ID/EX
        .debug_id_ex_read_data1(debug_id_ex_read_data1),
        .debug_id_ex_read_data2(debug_id_ex_read_data2),
        .debug_id_ex_sign_ext_imm(debug_id_ex_sign_ext_imm),
        .debug_id_ex_rs(debug_id_ex_rs),
        .debug_id_ex_rt(debug_id_ex_rt),
        .debug_id_ex_rd(debug_id_ex_rd),
        .debug_id_ex_shamt(debug_id_ex_shamt),
        .debug_id_ex_next_pc(debug_id_ex_next_pc),
        .debug_id_ex_reg_dst(debug_id_ex_reg_dst),
        .debug_id_ex_alu_src_b(debug_id_ex_alu_src_b),
        .debug_id_ex_alu_src_a(debug_id_ex_alu_src_a),
        .debug_id_ex_alu_control(debug_id_ex_alu_control),
        .debug_id_ex_mem_read(debug_id_ex_mem_read),
        .debug_id_ex_mem_write(debug_id_ex_mem_write),
        .debug_id_ex_reg_write(debug_id_ex_reg_write),
        .debug_id_ex_mem_to_reg(debug_id_ex_mem_to_reg),
        .debug_id_ex_is_halt(debug_id_ex_is_halt),
        .debug_id_ex_byte_mask(debug_id_ex_byte_mask),
        .debug_id_ex_is_signed_load(debug_id_ex_is_signed_load),
        
        // Debug latch signals - EX/MEM
        .debug_ex_mem_alu_result(debug_ex_mem_alu_result),
        .debug_ex_mem_write_data(debug_ex_mem_write_data),
        .debug_ex_mem_write_reg(debug_ex_mem_write_reg),
        .debug_ex_mem_reg_write(debug_ex_mem_reg_write),
        .debug_ex_mem_mem_read(debug_ex_mem_mem_read),
        .debug_ex_mem_mem_write(debug_ex_mem_mem_write),
        .debug_ex_mem_mem_to_reg(debug_ex_mem_mem_to_reg),
        .debug_ex_mem_is_halt(debug_ex_mem_is_halt),
        .debug_ex_mem_byte_mask(debug_ex_mem_byte_mask),
        .debug_ex_mem_is_signed_load(debug_ex_mem_is_signed_load),
        
        // Debug latch signals - MEM/WB
        .debug_mem_wb_write_data(debug_mem_wb_write_data),
        .debug_mem_wb_write_reg(debug_mem_wb_write_reg),
        .debug_mem_wb_reg_write(debug_mem_wb_reg_write),
        .debug_mem_wb_is_halt(debug_mem_wb_is_halt),
        
        // Debugger state output
        .debugger_state(debugger_state)
    );

    // ======== Instancia del módulo MIPS ========
    mips mips_inst (
        .clk(sys_clk),
        .reset(mips_reset),
        .stall(mips_stall),    
        // Instruction memory write interface
        .inst_write_en(mips_inst_write_en),
        .inst_write_addr(mips_inst_write_addr),
        .inst_write_data(mips_inst_write_data),
    
        .halt(mips_halt),
        
        // Debug register interface
        .reg_addr(mips_reg_addr),
        .reg_data(mips_reg_data),
        
        // Debug memory interface
        .mem_debug_addr(mips_mem_addr),
        .mem_debug_data(mips_mem_data),
        
        // Debug latch signals - IF/ID
        .debug_if_id_instr(debug_if_id_instr),
        .debug_if_id_next_pc(debug_if_id_next_pc),
        
        // Debug latch signals - ID/EX
        .debug_id_ex_read_data1(debug_id_ex_read_data1),
        .debug_id_ex_read_data2(debug_id_ex_read_data2),
        .debug_id_ex_sign_ext_imm(debug_id_ex_sign_ext_imm),
        .debug_id_ex_rs(debug_id_ex_rs),
        .debug_id_ex_rt(debug_id_ex_rt),
        .debug_id_ex_rd(debug_id_ex_rd),
        .debug_id_ex_shamt(debug_id_ex_shamt),
        .debug_id_ex_next_pc(debug_id_ex_next_pc),
        .debug_id_ex_reg_dst(debug_id_ex_reg_dst),
        .debug_id_ex_alu_src_b(debug_id_ex_alu_src_b),
        .debug_id_ex_alu_src_a(debug_id_ex_alu_src_a),
        .debug_id_ex_alu_control(debug_id_ex_alu_control),
        .debug_id_ex_mem_read(debug_id_ex_mem_read),
        .debug_id_ex_mem_write(debug_id_ex_mem_write),
        .debug_id_ex_reg_write(debug_id_ex_reg_write),
        .debug_id_ex_mem_to_reg(debug_id_ex_mem_to_reg),
        .debug_id_ex_is_halt(debug_id_ex_is_halt),
        .debug_id_ex_byte_mask(debug_id_ex_byte_mask),
        .debug_id_ex_is_signed_load(debug_id_ex_is_signed_load),
        
        // Debug latch signals - EX/MEM
        .debug_ex_mem_alu_result(debug_ex_mem_alu_result),
        .debug_ex_mem_write_data(debug_ex_mem_write_data),
        .debug_ex_mem_write_reg(debug_ex_mem_write_reg),
        .debug_ex_mem_reg_write(debug_ex_mem_reg_write),
        .debug_ex_mem_mem_read(debug_ex_mem_mem_read),
        .debug_ex_mem_mem_write(debug_ex_mem_mem_write),
        .debug_ex_mem_mem_to_reg(debug_ex_mem_mem_to_reg),
        .debug_ex_mem_is_halt(debug_ex_mem_is_halt),
        .debug_ex_mem_byte_mask(debug_ex_mem_byte_mask),
        .debug_ex_mem_is_signed_load(debug_ex_mem_is_signed_load),
        
        // Debug latch signals - MEM/WB
        .debug_mem_wb_write_data(debug_mem_wb_write_data),
        .debug_mem_wb_write_reg(debug_mem_wb_write_reg),
        .debug_mem_wb_reg_write(debug_mem_wb_reg_write),
        .debug_mem_wb_is_halt(debug_mem_wb_is_halt)
    );

endmodule
