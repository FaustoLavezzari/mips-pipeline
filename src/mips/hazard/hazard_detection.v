`timescale 1ns / 1ps
`include "../mips_pkg.vh"

module hazard_detection(
    input wire [4:0]  i_if_id_rs,         // RS from instruction in ID stage
    input wire [4:0]  i_if_id_rt,         // RT from instruction in ID stage
    input wire [4:0]  i_id_ex_rt,         // RT from instruction in EX stage
    input wire        i_id_ex_mem_read,   // MemRead signal from EX stage
    input wire [5:0]  i_if_id_opcode,     // Opcode of instruction in ID stage
    input wire        i_id_take_branch,   // Unified branch/jump taken signal from ID stage
    input wire        i_total_stall,      // Stall signal from control unit
    output wire       o_flush_id_ex,      // Signal to flush ID/EX stage (load hazard)
    output wire       o_flush_if_id,      // Signal to flush IF/ID stage (branch/jump hazard)
    output wire       o_halt,              // HALT instruction detected

    //stall management
    output wire       o_stall_first_half, // Stall signal for first half of pipeline (PC-if/id)
    output wire       o_stall_second_half // Stall signal for second half of pipeline (id/ex, ex/mem, mem/wb)
);

    // Detect load-use hazard: Previous instruction is a load AND 
    // its destination register is used by current instruction as source
    // Note: Only check i_if_id_rt when instruction is NOT a load, since in loads rt is destination
    wire is_load_in_id = (i_if_id_opcode == `OPCODE_LW) ||
                         (i_if_id_opcode == `OPCODE_LH) ||
                         (i_if_id_opcode == `OPCODE_LB) ||
                         (i_if_id_opcode == `OPCODE_LHU) ||
                         (i_if_id_opcode == `OPCODE_LBU) ||
                         (i_if_id_opcode == `OPCODE_LWU);
                        
    wire load_use_hazard = i_id_ex_mem_read && 
                          ((i_id_ex_rt != 5'b0) && 
                           ((i_id_ex_rt == i_if_id_rs) || 
                           (i_id_ex_rt == i_if_id_rt && !is_load_in_id)));

    // HALT instruction
    wire is_halt = (i_if_id_opcode == `OPCODE_HALT);
    assign o_halt = is_halt;
    
    // Load hazard requires flushing ID/EX
    assign o_flush_id_ex = load_use_hazard || is_halt;
    
    // Control hazard (branch/jump) requires flushing IF/ID
    assign o_flush_if_id = i_id_take_branch;

    // Stall management signals
    assign o_stall_first_half = (load_use_hazard && !i_id_take_branch) || is_halt || i_total_stall;
    assign o_stall_second_half = i_total_stall;

endmodule
