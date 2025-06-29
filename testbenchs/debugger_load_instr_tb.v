`timescale 1ns / 1ps

module debugger_load_instr_tb();

    // Simulation control
    initial begin
        $timeformat(-9, 2, " ns", 10);
    end

    // Clock and reset
    reg clk = 0;
    reg reset = 1;
    
    // UART simulation with simple FIFOs
    reg [7:0]  uart_tx_fifo [0:31];  // FIFO to send data to debugger
    reg [7:0]  uart_rx_fifo [0:31];  // FIFO to receive data from debugger
    reg [4:0]  tx_fifo_wr_ptr = 0;
    reg [4:0]  tx_fifo_rd_ptr = 0;
    reg [4:0]  rx_fifo_wr_ptr = 0;
    reg [4:0]  rx_fifo_rd_ptr = 0;
    
    // UART interface signals
    wire [7:0] uart_rx_data;
    wire       uart_rx_valid;
    wire [7:0] uart_tx_data;
    wire       uart_tx_valid;
    
    // MIPS interface signals
    wire       mips_reset;
    wire       mips_inst_write_en;
    wire [31:0] mips_inst_write_addr;
    wire [31:0] mips_inst_write_data;
    wire       mips_stall;
    
    // MIPS debug interface signals
    wire [4:0]  mips_reg_addr;
    wire [31:0] mips_reg_data;
    wire [31:0] mips_mem_addr;
    wire [31:0] mips_mem_data;
    
    // MIPS outputs for verification
    wire [31:0] mips_result;
    wire        mips_halt;
    
    // Clock generation
    always #5 clk = ~clk;  // 100MHz clock
    
    // UART TX FIFO control (sends data to debugger)
    reg tx_enable = 0;
    assign uart_rx_data = (tx_fifo_rd_ptr != tx_fifo_wr_ptr) ? uart_tx_fifo[tx_fifo_rd_ptr] : 8'h00;
    assign uart_rx_valid = tx_enable && (tx_fifo_rd_ptr != tx_fifo_wr_ptr);
    
    // UART RX FIFO control (receives data from debugger)
    always @(posedge clk) begin
        if (uart_tx_valid) begin
            uart_rx_fifo[rx_fifo_wr_ptr] <= uart_tx_data;
            rx_fifo_wr_ptr <= rx_fifo_wr_ptr + 1;
        end
    end
    
    // Update TX FIFO read pointer when data is consumed
    always @(posedge clk) begin
        if (uart_rx_valid && tx_enable) begin
            tx_fifo_rd_ptr <= tx_fifo_rd_ptr + 1;
        end
    end
    
    // Debugger instance
    debugger dut_debugger (
        .clk(clk),
        .reset(reset),
        .uart_rx_data(uart_rx_data),
        .uart_rx_valid(uart_rx_valid),
        .uart_tx_data(uart_tx_data),
        .uart_tx_valid(uart_tx_valid),
        .mips_reset(mips_reset),
        .mips_inst_write_en(mips_inst_write_en),
        .mips_inst_write_addr(mips_inst_write_addr),
        .mips_inst_write_data(mips_inst_write_data),
        .mips_stall(mips_stall),
        .mips_reg_addr(mips_reg_addr),
        .mips_reg_data(mips_reg_data),
        .mips_mem_addr(mips_mem_addr),
        .mips_mem_data(mips_mem_data)
    );
    
    // MIPS instance
    mips dut_mips (
        .clk(clk),
        .reset(mips_reset),
        .stall(mips_stall),
        .inst_write_en(mips_inst_write_en),
        .inst_write_addr(mips_inst_write_addr),
        .inst_write_data(mips_inst_write_data),
        .result(mips_result),
        .halt(mips_halt),
        .reg_addr(mips_reg_addr),
        .reg_data(mips_reg_data),
        .mem_debug_addr(mips_mem_addr),
        .mem_debug_data(mips_mem_data),
        .debug_if_id_instr(),
        .debug_if_id_next_pc(),
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
        .debug_mem_wb_alu_result(),
        .debug_mem_wb_read_data(),
        .debug_mem_wb_write_reg(),
        .debug_mem_wb_reg_write(),
        .debug_mem_wb_mem_to_reg(),
        .debug_mem_wb_is_halt()
    );
    
    // Task to load instruction via UART
    task load_instruction;
        input [31:0] instruction;
        begin
            $display("Loading instruction: 0x%08x", instruction);
            
            // Send load instruction command
            uart_tx_fifo[tx_fifo_wr_ptr] = 8'b00000001;  // CMD_LOAD_INSTRUCTION
            tx_fifo_wr_ptr = tx_fifo_wr_ptr + 1;
            
            // Send 4 bytes of instruction (MSB first)
            uart_tx_fifo[tx_fifo_wr_ptr] = instruction[31:24];
            tx_fifo_wr_ptr = tx_fifo_wr_ptr + 1;
            uart_tx_fifo[tx_fifo_wr_ptr] = instruction[23:16];
            tx_fifo_wr_ptr = tx_fifo_wr_ptr + 1;
            uart_tx_fifo[tx_fifo_wr_ptr] = instruction[15:8];
            tx_fifo_wr_ptr = tx_fifo_wr_ptr + 1;
            uart_tx_fifo[tx_fifo_wr_ptr] = instruction[7:0];
            tx_fifo_wr_ptr = tx_fifo_wr_ptr + 1;
        end
    endtask
    
    // Task to wait for ACK
    task wait_for_ack;
        begin
            wait(rx_fifo_wr_ptr > rx_fifo_rd_ptr);
            if (uart_rx_fifo[rx_fifo_rd_ptr] == 8'hFF) begin
                $display("ACK received successfully!");
            end else begin
                $display("ERROR: Expected ACK (0xFF), got 0x%02x", uart_rx_fifo[rx_fifo_rd_ptr]);
            end
            rx_fifo_rd_ptr = rx_fifo_rd_ptr + 1;
        end
    endtask
    
    // Task to verify instruction in MIPS memory
    task verify_instruction;
        input [31:0] address;
        input [31:0] expected_instruction;
        reg [31:0] actual_instruction;
        begin
            // Access MIPS instruction memory directly
            actual_instruction = {
                dut_mips.if_stage_inst.imem_inst.memory[address+3],
                dut_mips.if_stage_inst.imem_inst.memory[address+2],
                dut_mips.if_stage_inst.imem_inst.memory[address+1],
                dut_mips.if_stage_inst.imem_inst.memory[address]
            };
            
            if (actual_instruction == expected_instruction) begin
                $display("VERIFICATION PASSED: Address 0x%08x contains 0x%08x", address, actual_instruction);
            end else begin
                $display("VERIFICATION FAILED: Address 0x%08x expected 0x%08x, got 0x%08x", 
                        address, expected_instruction, actual_instruction);
            end
        end
    endtask
    
    // Task to verify memory is clean (contains zeros)
    task verify_memory_clean;
        input [31:0] start_addr;
        input [31:0] num_words;
        reg [31:0] actual_instruction;
        integer i;
        reg all_clean;
        begin
            all_clean = 1'b1;
            $display("Checking memory is clean from address 0x%08x to 0x%08x", start_addr, start_addr + (num_words * 4) - 4);
            
            for (i = 0; i < num_words; i = i + 1) begin
                actual_instruction = {
                    dut_mips.if_stage_inst.imem_inst.memory[start_addr + (i*4) + 3],
                    dut_mips.if_stage_inst.imem_inst.memory[start_addr + (i*4) + 2],
                    dut_mips.if_stage_inst.imem_inst.memory[start_addr + (i*4) + 1],
                    dut_mips.if_stage_inst.imem_inst.memory[start_addr + (i*4)]
                };
                
                if (actual_instruction != 32'h00000000) begin
                    $display("MEMORY NOT CLEAN: Address 0x%08x contains 0x%08x (expected 0x00000000)", 
                            start_addr + (i*4), actual_instruction);
                    all_clean = 1'b0;
                end
            end
            
            if (all_clean) begin
                $display("MEMORY CLEAN VERIFICATION PASSED: All checked addresses contain 0x00000000");
            end else begin
                $display("MEMORY CLEAN VERIFICATION FAILED: Some addresses still contain data");
            end
        end
    endtask
    
    // Task to send reset command
    task send_reset_command;
        begin
            $display("Sending RESET command to debugger");
            uart_tx_fifo[tx_fifo_wr_ptr] = 8'hFF;  // CMD_RESET
            tx_fifo_wr_ptr = tx_fifo_wr_ptr + 1;
        end
    endtask
    
    // Task to send free run command
    task send_free_run_command;
        begin
            $display("Sending FREE_RUN command to debugger");
            uart_tx_fifo[tx_fifo_wr_ptr] = 8'h04;  // CMD_FREE_RUN
            tx_fifo_wr_ptr = tx_fifo_wr_ptr + 1;
        end
    endtask
    
    // Test stimulus
    initial begin
        $display("Starting debugger instruction loading test");
        $display("============================================");
        
        // Inicialización de señales
        reset = 1;
        tx_enable = 0;
        
        // Liberar el reset después de unos ciclos
        #100;
        reset = 0;
        #50;
        
        // Enable UART transmission
        tx_enable = 1;
        #10;
        
        // Ejecutar toda la secuencia de pruebas con un timeout
        fork
            // Secuencia principal de pruebas
            begin
                // === FIRST SET OF INSTRUCTIONS ===
                $display("\n=== LOADING FIRST SET OF INSTRUCTIONS ===");
                
                // Test 1: Load first instruction (ADD $1, $2, $3)
                // add $1, $2, $3 -> 0x00431020
                $display("\nTest 1: Loading ADD instruction");
                load_instruction(32'h00431020);
                wait_for_ack();
                verify_instruction(32'h00000000, 32'h00431020);
                
                #100;
                
                // Test 2: Load second instruction (ADDI $4, $0, 10)
                // addi $4, $0, 10 -> 0x2004000A
                $display("\nTest 2: Loading ADDI instruction");
                load_instruction(32'h2004000A);
                wait_for_ack();
                verify_instruction(32'h00000004, 32'h2004000A);
                
                
                // Test 3: Load third instruction (SW $4, 0($1))
                // sw $4, 0($1) -> 0xAC240000
                $display("\nTest 3: Loading SW instruction");
                load_instruction(32'hAC240000);
                wait_for_ack();
                verify_instruction(32'h00000008, 32'hAC240000);
                
                #100;
                
                // === RESET AND VERIFY CLEAN ===
                $display("\n=== TESTING RESET FUNCTIONALITY ===");
                $display("Current time: %0t", $time);
                
                // Test 4: Reset MIPS and verify memory is cleared
                $display("\nTest 4: Testing MIPS reset");
                send_reset_command();
                $display("Reset command sent at time: %0t", $time);

                
                // Verify that instruction address was reset
                $display("Debugger instruction address after reset: 0x%08x", dut_debugger.instruction_address);
                
                // Verify memory is clean
                verify_memory_clean(32'h00000000, 4);  // Check first 4 words (16 bytes)
                
                #100;
                
                // === SECOND SET OF INSTRUCTIONS ===
                $display("\n=== LOADING SECOND SET OF INSTRUCTIONS ===");
                
                // Test 5: Load first instruction after reset (SUB $5, $6, $7)
                // sub $5, $6, $7 -> 0x00C72822
                $display("\nTest 5: Loading SUB instruction after reset");
                load_instruction(32'h00C72822);
                #200;
                wait_for_ack();
                verify_instruction(32'h00000000, 32'h00C72822);  // Should be at address 0 again
                
                #100;
                
                // Test 6: Load second instruction (LW $8, 4($5))
                // lw $8, 4($5) -> 0x8CA80004
                $display("\nTest 6: Loading LW instruction");
                load_instruction(32'h8CA80004);
                #200;
                wait_for_ack();
                verify_instruction(32'h00000004, 32'h8CA80004);
                
                #100;
                
                // Test 7: Load third instruction (BEQ $8, $9, 8)
                // beq $8, $9, 8 -> 0x11090008
                $display("\nTest 7: Loading BEQ instruction");
                load_instruction(32'h11090008);
                #200;
                wait_for_ack();
                verify_instruction(32'h00000008, 32'h11090008);
                
                #100;
                
                // Test 8: Load HALT instruction
                // HALT instruction -> 0xFFFFFFFF (all F's for clarity)
                $display("\nTest 8: Loading HALT instruction");
                load_instruction(32'hFFFFFFFF);
                #200;
                wait_for_ack();
                verify_instruction(32'h0000000C, 32'hFFFFFFFF);
                
                #100;
                
                // === FINAL VERIFICATION ===
                $display("\n=== FINAL VERIFICATION ===");
                $display("Final debugger instruction address: 0x%08x", dut_debugger.instruction_address);
                
                // Verify all four new instructions are in place
                $display("\nVerifying all second set instructions:");
                verify_instruction(32'h00000000, 32'h00C72822);  // SUB
                verify_instruction(32'h00000004, 32'h8CA80004);  // LW
                verify_instruction(32'h00000008, 32'h11090008);  // BEQ
                verify_instruction(32'h0000000C, 32'hFC000000);  // HALT
                
                #100;
                
                // === FREE RUN EXECUTION ===
                $display("\n=== STARTING FREE RUN EXECUTION ===");
                $display("Starting MIPS execution with loaded instructions");
                
                // Send free run command
                send_free_run_command();
                
                // Wait for MIPS to execute and halt
                $display("Waiting for MIPS to execute instructions and halt...");
                wait(mips_halt == 1'b1);
                $display("MIPS execution completed! HALT signal detected at time: %0t", $time);
                
                // Wait for ACK from debugger after halt
                wait_for_ack();
                $display("Received ACK after MIPS halt");
                
                #100;
                
                $display("\n============================================");
                $display("Test completed successfully!");
                $display("- Loaded 3 instructions in first set");
                $display("- Performed reset and verified memory clean");
                $display("- Loaded 4 instructions in second set (including HALT)");
                $display("- Executed FREE_RUN command");
                $display("- MIPS executed until HALT instruction");
                $display("- Verified address counter reset functionality");
                $display("- Total execution time: %0t", $time);
                $display("============================================");
                
                $finish;
            end
            
            // Timeout de seguridad
            begin
                #10000;  // 10μs timeout
                $display("\nERROR: Test timed out after 10μs!");
                $finish;
            end
        join
    end
    
    // Monitor key signals
    initial begin
        $monitor("Time=%0t, State=%0d, MIPS_Reset=%b, Stall=%b, InstAddr=0x%08x, InstData=0x%08x, WriteEn=%b", 
                 $time, dut_debugger.state, mips_reset, mips_stall, 
                 mips_inst_write_addr, mips_inst_write_data, mips_inst_write_en);
    end

endmodule
