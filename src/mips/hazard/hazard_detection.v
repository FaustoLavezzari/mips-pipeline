`timescale 1ns / 1ps
`include "../mips_pkg.vh"

module hazard_detection(
    input wire [4:0]  i_if_id_rs,         // RS from instruction in ID stage
    input wire [4:0]  i_if_id_rt,         // RT from instruction in ID stage
    input wire [4:0]  i_id_ex_rt,         // RT from instruction in EX stage
    input wire        i_id_ex_mem_read,    // MemRead signal from EX stage
    input wire [5:0]  i_if_id_opcode,     // Opcode of instruction in ID stage
    input wire [5:0]  i_if_id_funct,      // Function code for R-type instructions
    input wire        i_branch_taken,      // Branch taken signal from EX stage
    input wire        i_branch_mispredicted, // Branch misprediction signal from EX stage
    output wire       o_stall,            // Signal to stall pipeline (load hazard) 
    output wire       o_flush,            // Signal to flush pipeline (branch hazard)
    output wire       o_ctrl_hazard,      // Control hazard signal (for propagation control)
    output wire       o_halt              // HALT instruction detected
);

    // Detect load-use hazard: Previous instruction is a load AND 
    // its destination register is used by current instruction as source
    wire load_use_hazard = i_id_ex_mem_read && 
                          ((i_id_ex_rt != 5'b0) && 
                           ((i_id_ex_rt == i_if_id_rs) || (i_id_ex_rt == i_if_id_rt)));
    
    // Detect control hazard from branch misprediction
    wire is_branch_hazard = i_branch_taken && i_branch_mispredicted;
    
    // Detect jump instructions
    wire is_jump = (i_if_id_opcode == `OPCODE_J) ||
                   (i_if_id_opcode == `OPCODE_R_TYPE && 
                   (i_if_id_funct == `FUNC_JR || i_if_id_funct == `FUNC_JALR));
                   
    // Detect HALT instruction
    wire is_halt = (i_if_id_opcode == `OPCODE_HALT);
    
    // Combined control hazard
    wire control_hazard = is_branch_hazard || is_jump;
    
    // Generate stall signal - stall for load-use hazard and RAW hazards
    // and make sure we're not stalling during a control hazard
    assign o_stall = (load_use_hazard ) && !control_hazard;
    
    // Flush pipeline for control hazards
    assign o_flush = control_hazard;
    
    // Signal for control propagation management
    assign o_ctrl_hazard = control_hazard;
    
    // Generate halt signal (only once)
    assign o_halt = is_halt;

endmodule
