`timescale 1ns / 1ps
`include "../mips_pkg.vh"

module hazard_detection(
    input wire [4:0]  i_if_id_rs,         // RS from instruction in ID stage
    input wire [4:0]  i_if_id_rt,         // RT from instruction in ID stage
    input wire [4:0]  i_id_ex_rt,         // RT from instruction in EX stage
    input wire        i_id_ex_mem_read,   // MemRead signal from EX stage
    input wire [5:0]  i_if_id_opcode,     // Opcode of instruction in ID stage
    input wire [5:0]  i_if_id_funct,      // Function code for R-type instructions
    input wire        i_id_take_branch,   // Unified branch/jump taken signal from ID stage
    output wire       o_stall,            // Signal to stall pipeline (load hazard) 
    output wire       o_flush_id_ex,      // Signal to flush ID/EX stage (load hazard)
    output wire       o_flush_if_id,      // Signal to flush IF/ID stage (branch/jump hazard)
    output wire       o_ctrl_hazard,      // Control hazard signal (for propagation control)
    output wire       o_halt              // HALT instruction detected
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
    
    
    // Detect control hazard from unified branch/jump taken signal
    wire is_control_hazard = i_id_take_branch;
                   
    // Detect HALT instruction
    wire is_halt = (i_if_id_opcode == `OPCODE_HALT);
    
    // Control hazard ya no depende de EX, viene directamente de ID
    wire control_hazard = is_control_hazard;
    
    // No stall when a branch/jump is taken
    assign o_stall = (load_use_hazard && !control_hazard) || is_halt; 
    
    // Load hazard requires flushing ID/EX
    assign o_flush_id_ex = load_use_hazard || is_halt;
    
    // Control hazard (branch/jump) requires flushing IF/ID
    assign o_flush_if_id = control_hazard;
    
    // Signal for control propagation management
    assign o_ctrl_hazard = control_hazard;
    
    // Generate halt signal
    assign o_halt = is_halt;

endmodule
