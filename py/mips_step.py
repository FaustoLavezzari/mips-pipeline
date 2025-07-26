#!/usr/bin/env python3
"""
MIPS Step-by-Step Debugger
===========================

Programa para probar la funcionalidad de ejecución paso a paso del MIPS.
Permite ejecutar el programa ciclo por ciclo y ver el estado de los registros.

Protocolo:
- Carga el programa basic_inst.coe
- Ejecuta paso a paso presionando 'S'
- Muestra los registros después de cada paso
- Permite salir con 'Q'

Author: Assistant
Created: July 2025
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

def interactive_step_mode(debugger):
    """Modo interactivo paso a paso"""
    print("\n🔧 Modo Step-by-Step iniciado")
    print("=" * 50)
    print("Comandos disponibles:")
    print("  S o Enter: Ejecutar un paso")
    print("  Q: Salir")
    print("=" * 50)
    
    step_count = 0
    
    # Mostrar estado inicial
    show_registers(debugger, step_count)
    
    while True:
        try:
            # Leer comando del usuario
            user_input = input(f"\n[Paso {step_count}] Presiona S+Enter para siguiente paso (Q para salir): ").strip().upper()
            
            if user_input == 'Q':
                print("👋 Saliendo del modo step-by-step")
                break
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
                print("❓ Comando no reconocido. Usa 'S' para step o 'Q' para salir.")
                
        except KeyboardInterrupt:
            print("\n⚡ Interrumpido por el usuario")
            break
        except Exception as e:
            print(f"❌ Error: {e}")
            break

def main():
    """Función principal del modo step-by-step"""
    print("🚀 MIPS Step-by-Step Debugger")
    print("=" * 50)
    
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
