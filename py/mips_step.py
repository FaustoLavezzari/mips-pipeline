#!/usr/bin/env python3
"""
MIPS Step-by-Step Debugger with Pipeline Latch Visualization
===========================================================

Programa para probar la funcionalidad de ejecución paso a paso del MIPS.
Permite ejecutar el programa ciclo por ciclo y ver el estado de los registros
y latches del pipeline.

Protocolo:
- Carga el programa basic_inst.coe
- Ejecuta paso a paso presionando 'S'
- Muestra los registros después de cada paso
- Muestra el estado de todos los latches del pipeline (IF/ID, ID/EX, EX/MEM, MEM/WB)
- Permite salir con 'Q'

"""

import sys
import os
import time

# Importar la clase MIPSDebugger del script principal
from mips import MIPSDebugger

def show_registers(debugger, step_count):
    """Muestra el estado actual de los registros"""
    print(f"\n📊 Estado después del paso {step_count}:")
    print("-" * 50)
    
    try:
        # Leer registros $1 a $5
        for reg_num in range(1, 6):
            value = debugger.read_register(reg_num)
            print(f"  ${reg_num}: {value:8d} (0x{value:08X})")
            
        # También mostrar $0 para verificar que siempre sea 0
        value_0 = debugger.read_register(0)
        print(f"  $0: {value_0:8d} (0x{value_0:08X}) [siempre debe ser 0]")
        
    except Exception as e:
        print(f"❌ Error leyendo registros: {e}")

def show_latches(debugger, step_count):
    """Muestra el estado actual de todos los latches del pipeline"""
    print(f"\n🔗 Estado de los Latches después del paso {step_count}:")
    print("=" * 70)
    
    try:
        # Latch IF/ID
        print("\n📍 IF/ID Latch:")
        print("-" * 30)
        ifid_data = debugger.read_latch_ifid()
        print(f"  Instrucción: 0x{ifid_data['instruction']:08X}")
        print(f"  Next PC:     0x{ifid_data['next_pc']:08X}")
        
        # Latch ID/EX
        print("\n📍 ID/EX Latch:")
        print("-" * 30)
        idex_data = debugger.read_latch_idex()
        print(f"  Read Data 1:     0x{idex_data['read_data1']:08X}")
        print(f"  Read Data 2:     0x{idex_data['read_data2']:08X}")
        print(f"  Sign Ext Imm:    0x{idex_data['sign_ext_imm']:08X}")
        print(f"  RS:              ${idex_data['rs']:d}")
        print(f"  RT:              ${idex_data['rt']:d}")
        print(f"  RD:              ${idex_data['rd']:d}")
        print(f"  Shamt:           {idex_data['shamt']:d}")
        print(f"  Next PC:         0x{idex_data['next_pc']:08X}")
        print(f"  RegDst:          {idex_data['reg_dst']:d}")
        print(f"  ALU Src B:       {idex_data['alu_src_b']:d}")
        print(f"  ALU Src A:       {idex_data['alu_src_a']:d}")
        print(f"  ALU Control:     {idex_data['alu_control']:d}")
        print(f"  MemRead:         {idex_data['mem_read']:d}")
        print(f"  MemWrite:        {idex_data['mem_write']:d}")
        print(f"  RegWrite:        {idex_data['reg_write']:d}")
        print(f"  MemToReg:        {idex_data['mem_to_reg']:d}")
        print(f"  Is Halt:         {idex_data['is_halt']:d}")
        
        # Latch EX/MEM
        print("\n📍 EX/MEM Latch:")
        print("-" * 30)
        exmem_data = debugger.read_latch_exmem()
        print(f"  ALU Result:      0x{exmem_data['alu_result']:08X}")
        print(f"  Write Data:      0x{exmem_data['write_data']:08X}")
        print(f"  Write Reg:       ${exmem_data['write_reg']:d}")
        print(f"  RegWrite:        {exmem_data['reg_write']:d}")
        print(f"  MemRead:         {exmem_data['mem_read']:d}")
        print(f"  MemWrite:        {exmem_data['mem_write']:d}")
        print(f"  MemToReg:        {exmem_data['mem_to_reg']:d}")
        print(f"  Is Halt:         {exmem_data['is_halt']:d}")
        
        # Latch MEM/WB
        print("\n📍 MEM/WB Latch:")
        print("-" * 30)
        memwb_data = debugger.read_latch_memwb()
        print(f"  ALU Result:      0x{memwb_data['alu_result']:08X}")
        print(f"  Read Data:       0x{memwb_data['read_data']:08X}")
        print(f"  Write Reg:       ${memwb_data['write_reg']:d}")
        print(f"  RegWrite:        {memwb_data['reg_write']:d}")
        print(f"  MemToReg:        {memwb_data['mem_to_reg']:d}")
        print(f"  Is Halt:         {memwb_data['is_halt']:d}")
        
    except Exception as e:
        print(f"❌ Error leyendo latches: {e}")

def interactive_step_mode(debugger):
    """Modo interactivo paso a paso"""
    print("\n🔧 Modo Step-by-Step iniciado")
    print("=" * 50)
    print("Comandos disponibles:")
    print("  S o Enter: Ejecutar un paso")
    print("  L: Mostrar solo latches (sin ejecutar paso)")
    print("  R: Mostrar solo registros (sin ejecutar paso)")
    print("  Q: Salir")
    print("=" * 50)
    
    step_count = 0
    
    # Mostrar estado inicial
    show_registers(debugger, step_count)
    show_latches(debugger, step_count)
    
    while True:
        try:
            # Leer comando del usuario
            user_input = input(f"\n[Paso {step_count}] Comando (S=step, L=latches, R=registros, Q=salir): ").strip().upper()
            
            if user_input == 'Q':
                print("👋 Saliendo del modo step-by-step")
                break
            elif user_input == 'L':
                # Mostrar solo latches
                show_latches(debugger, step_count)
            elif user_input == 'R':
                # Mostrar solo registros
                show_registers(debugger, step_count)
            elif user_input == 'S' or user_input == '':
                # Ejecutar un paso
                print(f"⏭️ Ejecutando paso {step_count + 1}...")
                
                if debugger.step():
                    step_count += 1
                    print(f"✅ Paso {step_count} completado")
                    
                    # Pequeña pausa para estabilización
                    time.sleep(0.1)
                    
                    # Mostrar estado de registros
                    show_registers(debugger, step_count)
                    
                    # Mostrar estado de los latches
                    show_latches(debugger, step_count)
                    
                    # Análisis esperado basado en basic_inst.coe
                    if step_count == 5:
                        print("🎯 En este paso debería aparecer el valor 5 en $1")
                    elif step_count == 10:
                        print("🎯 En este paso debería aparecer el valor 10 en $2")
                    elif step_count == 15:
                        print("🎯 En este paso debería aparecer el valor 100 en $3")
                    elif step_count == 20:
                        print("🎯 En este paso debería aparecer el valor 20 en $4")
                    elif step_count == 25:
                        print("🎯 En este paso debería aparecer el valor 15 en $5")
                        
                else:
                    print("❌ Error ejecutando paso")
                    break
            else:
                print("❓ Comando no reconocido. Usa 'S' para step, 'L' para latches, 'R' para registros o 'Q' para salir.")
                
        except KeyboardInterrupt:
            print("\n⚡ Interrumpido por el usuario")
            break
        except Exception as e:
            print(f"❌ Error: {e}")
            break

def main():
    """Función principal del modo step-by-step"""
    print("🚀 MIPS Step-by-Step Debugger with Pipeline Visualization")
    print("=" * 60)
    print("🔍 Esta herramienta permite:")
    print("  • Ejecutar el procesador MIPS paso a paso")
    print("  • Visualizar el estado de los registros")
    print("  • Inspeccionar todos los latches del pipeline:")
    print("    - IF/ID: Instruction Fetch / Instruction Decode")
    print("    - ID/EX: Instruction Decode / Execute")
    print("    - EX/MEM: Execute / Memory")
    print("    - MEM/WB: Memory / Write Back")
    print("=" * 60)
    
    # Crear debugger
    debugger = MIPSDebugger()
    
    try:
        # Conectar
        if not debugger.connect():
            print("❌ No se pudo conectar al puerto UART")
            return 1
            
        # Resetear MIPS
        debugger.reset_mips()
        
        # Cargar instrucciones desde archivo
        coe_file = os.path.join(os.path.dirname(__file__), 'basic_inst.coe')
        instructions = debugger.load_instructions_from_coe(coe_file)
        
        if not instructions:
            print("❌ No hay instrucciones para cargar")
            return 1
            
        # Cargar programa
        if not debugger.load_program(instructions):
            print("❌ Error cargando programa")
            return 1
            
        print("✅ Programa cargado. Listo para ejecución paso a paso.")
        print("🎮 Ahora puedes ejecutar paso a paso y ver el estado del pipeline completo.")
        
        # Entrar en modo interactivo
        interactive_step_mode(debugger)
        
        return 0
        
    except KeyboardInterrupt:
        print("\n⚡ Interrumpido por el usuario")
        return 1
    except Exception as e:
        print(f"❌ Error: {e}")
        return 1
    finally:
        debugger.disconnect()

if __name__ == "__main__":
    sys.exit(main())
