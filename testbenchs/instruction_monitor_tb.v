`timescale 1ns / 1ps

module instruction_monitor_tb();

  // Señales para conectar al DUT
  reg clk;
  reg reset;
  wire [31:0] result;
  
  // Instancia del módulo MIPS
  mips dut (
    .clk    (clk),
    .reset  (reset),
    .result (result)
  );
  
  // Genera un reloj de 10ns (100 MHz)
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end
  
  // Variables para el ciclo
  integer cycle_count;
  
  // Función para decodificar y mostrar la instrucción
  function automatic [200:0] decode_instruction;
    input [31:0] instr;
    
    reg [5:0] opcode;
    reg [5:0] funct;
    reg [4:0] rs, rt, rd;
    reg [15:0] imm;
    
    begin
      opcode = instr[31:26];
      rs = instr[25:21];
      rt = instr[20:16];
      rd = instr[15:11];
      imm = instr[15:0];
      funct = instr[5:0];
      
      case(opcode)
        6'b000000: begin // R-type
          case(funct)
            6'b100000: $sformat(decode_instruction, "add $%0d, $%0d, $%0d", rd, rs, rt);
            6'b100010: $sformat(decode_instruction, "sub $%0d, $%0d, $%0d", rd, rs, rt);
            6'b100100: $sformat(decode_instruction, "and $%0d, $%0d, $%0d", rd, rs, rt);
            6'b100101: $sformat(decode_instruction, "or $%0d, $%0d, $%0d", rd, rs, rt);
            6'b100110: $sformat(decode_instruction, "xor $%0d, $%0d, $%0d", rd, rs, rt);
            default:   $sformat(decode_instruction, "R-type desconocida");
          endcase
        end
        6'b001000: $sformat(decode_instruction, "addi $%0d, $%0d, %0d", rt, rs, $signed(imm));
        6'b100011: $sformat(decode_instruction, "lw $%0d, %0d($%0d)", rt, $signed(imm), rs);
        6'b101011: $sformat(decode_instruction, "sw $%0d, %0d($%0d)", rt, $signed(imm), rs);
        default:   $sformat(decode_instruction, "Instrucción desconocida");
      endcase
    end
  endfunction
  
  // Inicio de la simulación
  initial begin
    // Inicialización de señales
    reset = 1;
    cycle_count = 0;
    
    // Mostrar encabezado
    $display("\n==== MIPS Pipeline Instruction Monitor ====\n");
    
    // Liberar el reset después de unos ciclos
    #15;
    reset = 0;

    // Ejecutar por 25 ciclos
    #250;
    $finish;
  end
  
  // Seguimiento del pipeline
  always @(posedge clk) begin
    if (!reset) begin
      cycle_count = cycle_count + 1;
      
      // Mostrar el ciclo actual
      $display("\n==== Ciclo %0d (t=%0t ns) ====", cycle_count, $time);
      
      // Mostrar estado de las etapas del pipeline
      $display("IF: PC=%0h, Instrucción=%0h [%s]", 
               dut.if_stage_inst.pc_inst.pc,
               dut.if_instr,
               decode_instruction(dut.if_instr));
      
      $display("ID: Instrucción=%0h [%s]", 
               dut.id_instr,
               decode_instruction(dut.id_instr));
      
      $display("EX: rs=$%0d=%0d, rt=$%0d=%0d, rd=$%0d, ALUResult=%0d", 
               dut.id_instr[25:21], dut.ex_read_data_1,
               dut.id_instr[20:16], dut.ex_read_data_2,
               dut.ex_write_register,
               dut.ex_alu_result);
      
      $display("MEM: ALUResult=%0d, MemWrite=%0b, MemRead=%0b", 
               dut.mem_alu_result,
               dut.mem_mem_write,
               dut.mem_mem_read);
      
      $display("WB: WriteReg=$%0d, WriteData=%0d, RegWrite=%0b", 
               dut.wb_write_register_out,
               dut.wb_write_data,
               dut.wb_reg_write_out);
      
      // Mostrar el contenido de los registros cada 5 ciclos o al final
      if (cycle_count % 5 == 0 || cycle_count == 25) begin
        $display("\nEstado de Registros:");
        $display("$1=%0d, $2=%0d, $3=%0d, $4=%0d, $5=%0d", 
                 dut.id_stage_inst.reg_bank.registers[1],
                 dut.id_stage_inst.reg_bank.registers[2],
                 dut.id_stage_inst.reg_bank.registers[3],
                 dut.id_stage_inst.reg_bank.registers[4],
                 dut.id_stage_inst.reg_bank.registers[5]);
        $display("$6=%0d, $7=%0d, $8=%0d, $9=%0d", 
                 dut.id_stage_inst.reg_bank.registers[6],
                 dut.id_stage_inst.reg_bank.registers[7],
                 dut.id_stage_inst.reg_bank.registers[8],
                 dut.id_stage_inst.reg_bank.registers[9]);
        $display("$10=%0d, $11=%0d, $12=%0d, $13=%0d", 
                 dut.id_stage_inst.reg_bank.registers[10],
                 dut.id_stage_inst.reg_bank.registers[11],
                 dut.id_stage_inst.reg_bank.registers[12],
                 dut.id_stage_inst.reg_bank.registers[13]);
                 
        // Memoria relevante
        $display("\nEstado de Memoria:");
        $display("Mem[100]=%0d, Mem[104]=%0d", 
                 dut.mem_stage_inst.memory[25],  // Memoria[100] (100/4 = 25)
                 dut.mem_stage_inst.memory[26]); // Memoria[104] (104/4 = 26)
      end
    end
  end

  // Inyección para formas de onda
  initial begin
    $dumpfile("instruction_monitor.vcd");
    $dumpvars(0, instruction_monitor_tb);
  end

endmodule
