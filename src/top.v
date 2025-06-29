`timescale 1ns / 1ps

module top(
    input  wire        clk,          // Reloj del board (100MHz)
    input  wire        reset,        // Reset del board
    
    // UART physical interface
    input  wire        uart_rx,
    output wire        uart_tx,
    
    // Optional debug outputs
    output wire [31:0] mips_result,
    output wire        mips_halt_out,
    output wire        uart_tx_full,
    output wire        uart_rx_empty,
    
    // LED debug outputs
    output wire        mips_stall     // Para LED1 - MIPS stall
);

    // ======== Señales de Clock Wizard ========
    wire        clk_50mhz;          // Reloj de 50MHz generado por Clock Wizard

    // ======== Parámetros UART ========
    localparam DBIT       = 8;     // data bits
    localparam SB_TICK    = 16;    // ticks for stop bits
    localparam DVSR       = 163;   // baud rate divisor (19200 baud @ 50MHz)
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
    wire        mips_stall;
    wire        mips_halt;
    wire [31:0] mips_result_int;

    // ======== Señales de debug MIPS ========
    wire [4:0]  mips_reg_addr;
    wire [31:0] mips_reg_data;
    wire [31:0] mips_mem_addr;
    wire [31:0] mips_mem_data;

    // ======== Asignaciones de salida ========
    assign mips_result = mips_result_int;
    assign mips_halt_out = mips_halt;
    assign uart_tx_full = uart_tx_full_int;
    assign uart_rx_empty = uart_rx_empty_int;
    assign mips_stall = mips_stall;          // Para LED debug

    // ======== Instancia del Clock Wizard ========
    // NOTA: Este debe ser generado como IP en Vivado con el nombre 'clk_wiz_0'
    clk_wiz_0 u_clk_wiz_0 (
        // Clock out ports
        .clk_50mhz(clk_50mhz),      // Salida de 50MHz
        // Status and control signals  
        .reset(reset),              // Reset de entrada
        .locked(),                  // Señal locked (no usada por ahora)
        // Clock in ports
        .clk_in1(clk)              // Entrada de reloj del board
    );

    // ======== Instancia del módulo UART ========
    uart #(
        .DBIT(DBIT),
        .SB_TICK(SB_TICK),
        .DVSR(DVSR),
        .DVSR_BITS(DVSR_BITS),
        .FIFO_W(FIFO_W)
    ) uart_inst (
        .clk(clk_50mhz),            // Usar reloj de 50MHz del Clock Wizard
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
        .clk(clk_50mhz),            // Usar reloj de 50MHz del Clock Wizard
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
        .mips_mem_data(mips_mem_data)
    );

    // ======== Instancia del módulo MIPS ========
    mips mips_inst (
        .clk(clk_50mhz),            // Usar reloj de 50MHz del Clock Wizard
        .reset(mips_reset),
        .stall(mips_stall),
        
        // Instruction memory write interface
        .inst_write_en(mips_inst_write_en),
        .inst_write_addr(mips_inst_write_addr),
        .inst_write_data(mips_inst_write_data),
        
        // Main outputs
        .result(mips_result_int),
        .halt(mips_halt),
        
        // Debug register interface
        .reg_addr(mips_reg_addr),
        .reg_data(mips_reg_data),
        
        // Debug memory interface
        .mem_debug_addr(mips_mem_addr),
        .mem_debug_data(mips_mem_data),
        
        // Debug latch signals - IF/ID
        .debug_if_id_instr(),
        .debug_if_id_next_pc(),
        
        // Debug latch signals - ID/EX
        .debug_id_ex_read_data1(),
        .debug_id_ex_read_data2(),
        .debug_id_ex_sign_ext_imm(),
        .debug_id_ex_rs(),
        .debug_id_ex_rt(),
        .debug_id_ex_rd(),
        .debug_id_ex_shamt(),
        .debug_id_ex_next_pc(),
        .debug_id_ex_reg_dst(),
        .debug_id_ex_alu_src_b(),
        .debug_id_ex_alu_src_a(),
        .debug_id_ex_alu_control(),
        .debug_id_ex_mem_read(),
        .debug_id_ex_mem_write(),
        .debug_id_ex_reg_write(),
        .debug_id_ex_mem_to_reg(),
        .debug_id_ex_is_halt(),
        .debug_id_ex_byte_mask(),
        .debug_id_ex_is_signed_load(),
        
        // Debug latch signals - EX/MEM
        .debug_ex_mem_alu_result(),
        .debug_ex_mem_write_data(),
        .debug_ex_mem_write_reg(),
        .debug_ex_mem_reg_write(),
        .debug_ex_mem_mem_read(),
        .debug_ex_mem_mem_write(),
        .debug_ex_mem_mem_to_reg(),
        .debug_ex_mem_is_halt(),
        .debug_ex_mem_byte_mask(),
        .debug_ex_mem_is_signed_load(),
        
        // Debug latch signals - MEM/WB
        .debug_mem_wb_alu_result(),
        .debug_mem_wb_read_data(),
        .debug_mem_wb_write_reg(),
        .debug_mem_wb_reg_write(),
        .debug_mem_wb_mem_to_reg(),
        .debug_mem_wb_is_halt()
    );

endmodule
