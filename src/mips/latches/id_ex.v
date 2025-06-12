`timescale 1ns / 1ps
`include "../mips_pkg.vh"

module id_ex(
  input  wire        clk,
  input  wire        reset,
  input  wire        flush,         // Nueva señal para invalidar el latch cuando hay misprediction
  // Datos de la etapa ID
  input  wire [31:0] read_data_1_in,
  input  wire [31:0] read_data_2_in,
  input  wire [31:0] sign_extended_imm_in,
  input  wire [4:0]  rs_in,              // Registro RS (añadido para forwarding)
  input  wire [4:0]  rt_in,
  input  wire [4:0]  rd_in,
  input  wire [4:0]  shamt_in,            // Campo shamt para instrucciones SLL/SRL
  input  wire [5:0]  function_in,
  input  wire [5:0]  opcode_in,
  input  wire [31:0] next_pc_in,          // PC+4 (solo para uso general)
  
  // Señales de control de ID
  input  wire        alu_src_b_in,
  input  wire [2:0]  alu_op_in,
  input  wire        reg_dst_in,
  input  wire        reg_write_in,
  input  wire        mem_read_in,
  input  wire        mem_write_in,
  input  wire        mem_to_reg_in,
  input  wire        is_jal_in,    // Nueva señal para JAL
  
  // Salidas hacia la etapa EX
  output reg  [31:0] read_data_1_out,
  output reg  [31:0] read_data_2_out,
  output reg  [31:0] sign_extended_imm_out,
  output reg  [4:0]  rs_out,              
  output reg  [4:0]  rt_out,
  output reg  [4:0]  rd_out,
  output reg  [31:0]  shamt_out,           
  output reg  [5:0]  function_out,
  output reg  [5:0]  opcode_out,
  output reg  [31:0] next_pc_out,         

  // Señales de control hacia EX
  output reg         alu_src_b_out,
  output reg  [2:0]  alu_op_out,
  output reg         reg_dst_out,
  output reg         reg_write_out,
  output reg         mem_read_out,
  output reg         mem_write_out,
  output reg         mem_to_reg_out,
  output reg         is_jal_out,   // Salida de señal para JAL
  
  // Salidas de predicción de saltos
  output reg         branch_prediction_out,     // Señal de predicción
  output reg  [31:0] branch_target_addr_out     // Dirección destino del salto
);
  always @(posedge clk) begin
    if (reset || flush) begin
      // Datos - Insertar NOPs cuando hay flush o reset
      read_data_1_out       <= {`DATA_WIDTH{1'b0}};
      read_data_2_out       <= {`DATA_WIDTH{1'b0}};
      sign_extended_imm_out <= {`DATA_WIDTH{1'b0}};
      rs_out                <= {`REG_ADDR_WIDTH{1'b0}};
      rt_out                <= {`REG_ADDR_WIDTH{1'b0}};
      rd_out                <= {`REG_ADDR_WIDTH{1'b0}};
      shamt_out             <= {`REG_ADDR_WIDTH{1'b0}};
      function_out          <= 6'b0;
      opcode_out            <= 6'b0;
      next_pc_out           <= next_pc_in;
      
      // Señales de control - Desactivar todas en caso de flush o reset
      alu_src_b_out           <= `CTRL_ALU_SRC_B_REG;
      alu_op_out            <= `ALU_OP_ADD;
      reg_dst_out           <= `CTRL_REG_DST_RT;
      reg_write_out         <= `CTRL_REG_WRITE_DIS; 
      mem_read_out          <= 1'b0;
      mem_write_out         <= 1'b0;
      mem_to_reg_out        <= `CTRL_MEM_TO_REG_ALU;
      is_jal_out            <= 1'b0;              
      
    end
    else begin  // Actualizar registros siempre que no haya reset o flush
      // Datos
      read_data_1_out       <= read_data_1_in;
      read_data_2_out       <= read_data_2_in;
      sign_extended_imm_out <= sign_extended_imm_in;
      rs_out                <= rs_in;               
      rt_out                <= rt_in;
      shamt_out             <= shamt_in;
      rd_out                <= rd_in;
      function_out          <= function_in;
      opcode_out            <= opcode_in;
      next_pc_out           <= next_pc_in;
      
      // Señales de control
      alu_src_b_out           <= alu_src_b_in;
      alu_op_out            <= alu_op_in;
      reg_dst_out           <= reg_dst_in;
      reg_write_out         <= reg_write_in;
      mem_read_out          <= mem_read_in;
      mem_write_out         <= mem_write_in;
      mem_to_reg_out        <= mem_to_reg_in;
      is_jal_out            <= is_jal_in;            // Propagar señal JAL
      
    end
  end
endmodule

