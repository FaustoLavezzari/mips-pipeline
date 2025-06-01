`timescale 1ns / 1ps

module hazard_detection(
    input wire [4:0]  i_if_id_rs,         // RS from instruction in ID stage
    input wire [4:0]  i_if_id_rt,         // RT from instruction in ID stage
    input wire [4:0]  i_id_ex_rt,         // RT from instruction in EX stage
    input wire        i_id_ex_mem_read,    // MemRead signal from EX stage
    input wire        i_branch_taken,      // Branch taken signal from EX stage
    input wire        i_branch_mispredicted, // Branch misprediction signal from EX stage
    output wire       o_stall,            // Signal to stall pipeline (load hazard)
    output wire       o_flush              // Signal to flush pipeline (branch hazard)
);

    // Detect load-use hazard: Previous instruction is a load AND 
    // its destination register is used by current instruction
    wire load_use_hazard = i_id_ex_mem_read && 
                          (i_id_ex_rt != 5'b0) && 
                          (i_id_ex_rt == i_if_id_rs || i_id_ex_rt == i_if_id_rt);
    
    // Detect control hazard: Branch misprediction
    wire control_hazard = i_branch_taken && i_branch_mispredicted;
    
    // Stall pipeline for load-use hazards
    assign o_stall = load_use_hazard;
    
    // Flush pipeline for control hazards
    assign o_flush = control_hazard;

endmodule
