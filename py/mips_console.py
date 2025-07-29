#!/usr/bin/env python3
"""
MIPS Pipeline Debugger Console
==============================

Aplicación de consola para debuggear el procesador MIPS con pipeline.
Interfaz completa con menús interactivos y múltiples modos de ejecución.

"""

import sys
import os
import time
import glob

# Importar la clase MIPSDebugger
from mips import MIPSDebugger

class MIPSConsole:
    def __init__(self):
        self.debugger = MIPSDebugger()
        self.current_program = None
        self.instructions = []
        self.step_count = 0
        
    def clear_screen(self):
        """Limpia la pantalla de la terminal"""
        os.system('clear')
        
    def print_header(self):
        """Imprime el header de la aplicación"""
        print("╔" + "═" * 68 + "╗")
        print("║" + " " * 20 + "MIPS Pipeline Debugger Console" + " " * 18 + "║")
        print("║" + " " * 15 + "Procesador MIPS con Pipeline de 5 Etapas" + " " * 13 + "║")
        print("╚" + "═" * 68 + "╝")
        print()
        
    def print_separator(self, char="─", length=70):
        """Imprime una línea separadora"""
        print(char * length)
        
    def wait_enter(self, message="Presiona Enter para continuar..."):
        """Espera que el usuario presione Enter"""
        input(f"\n📍 {message}")
        
    def show_error(self, message):
        """Muestra un mensaje de error"""
        print(f"\n❌ Error: {message}")
        self.wait_enter()
        
    def show_success(self, message):
        """Muestra un mensaje de éxito"""
        print(f"\n✅ {message}")
        
    def get_coe_files(self):
        """Obtiene la lista de archivos .coe disponibles"""
        instruccion_files_dir = os.path.join(os.path.dirname(__file__), 'instruccion_files')
        
        if not os.path.exists(instruccion_files_dir):
            return []
            
        coe_files = glob.glob(os.path.join(instruccion_files_dir, '*.coe'))
        return [os.path.basename(f) for f in coe_files]
        
    def select_instruction_file(self):
        """Permite al usuario seleccionar un archivo de instrucciones"""
        while True:
            self.clear_screen()
            self.print_header()
            
            print("📂 Selección de Archivo de Instrucciones")
            self.print_separator()
            
            coe_files = self.get_coe_files()
            
            if not coe_files:
                self.show_error("No se encontraron archivos .coe en la carpeta instruccion_files")
                return False
                
            print("\nArchivos disponibles:")
            for i, filename in enumerate(coe_files, 1):
                print(f"  {i}. {filename}")
                
            print(f"  {len(coe_files) + 1}. Salir")
            
            try:
                self.print_separator()
                choice = input(f"\nSelecciona un archivo (1-{len(coe_files) + 1}): ").strip()
                
                if choice == str(len(coe_files) + 1):
                    return False
                    
                choice_idx = int(choice) - 1
                if 0 <= choice_idx < len(coe_files):
                    selected_file = coe_files[choice_idx]
                    self.current_program = selected_file
                    
                    # Mostrar información del archivo seleccionado
                    print(f"\n📄 Archivo seleccionado: {selected_file}")
                    
                    # Cargar las instrucciones
                    if self.load_instructions():
                        self.show_success(f"Archivo {selected_file} cargado exitosamente")
                        self.wait_enter()
                        return True
                    else:
                        self.current_program = None
                        return False
                else:
                    self.show_error("Opción inválida")
                    
            except ValueError:
                self.show_error("Por favor ingresa un número válido")
            except KeyboardInterrupt:
                print("\n\n👋 Saliendo...")
                return False
                
    def load_instructions(self):
        """Carga las instrucciones del archivo seleccionado"""
        if not self.current_program:
            return False
            
        try:
            # Conectar si no está conectado
            if not self.debugger.ser or not self.debugger.ser.is_open:
                print("\n🔌 Conectando al puerto UART...")
                if not self.debugger.connect():
                    self.show_error("No se pudo conectar al puerto UART")
                    return False
                    
            # Reset del MIPS
            print("🔄 Reseteando MIPS...")
            self.debugger.reset_mips()
            
            # Cargar instrucciones
            coe_file = os.path.join(os.path.dirname(__file__), 'instruccion_files', self.current_program)
            self.instructions = self.debugger.load_instructions_from_coe(coe_file)
            
            if not self.instructions:
                self.show_error("No se pudieron cargar las instrucciones")
                return False
                
            # Cargar programa en el MIPS
            if not self.debugger.load_program(self.instructions):
                self.show_error("Error cargando programa en el MIPS")
                return False
                
            self.step_count = 0
            return True
            
        except Exception as e:
            self.show_error(f"Error cargando instrucciones: {e}")
            return False
            
    def show_main_menu(self):
        """Muestra el menú principal"""
        while True:
            self.clear_screen()
            self.print_header()
            
            print(f"📋 Menú Principal - Programa: {self.current_program}")
            self.print_separator()
            
            print("\nOpciones disponibles:")
            print("  1. 🏃 Free Run (Ejecutar programa completo)")
            print("  2. 🔧 Step-by-Step (Ejecución paso a paso)")
            print("  3. 🔄 Reset (Reiniciar y seleccionar nuevo archivo)")
            print("  4. 🚪 Salir")
            
            try:
                self.print_separator()
                choice = input("\nSelecciona una opción (1-4): ").strip()
                
                if choice == '1':
                    self.free_run_mode()
                elif choice == '2':
                    self.step_by_step_mode()
                elif choice == '3':
                    self.reset_system()
                    break
                elif choice == '4':
                    return False
                else:
                    self.show_error("Opción inválida")
                    
            except KeyboardInterrupt:
                print("\n\n👋 Saliendo...")
                return False
                
        return True
        
    def free_run_mode(self):
        """Modo de ejecución completa"""
        self.clear_screen()
        self.print_header()
        
        print("🏃 Modo Free Run - Ejecución Completa")
        self.print_separator()
        
        try:              
            print("🚀 Ejecutando programa completo...")
            
            if self.debugger.run_program():
                self.show_success("Programa ejecutado exitosamente")
                
                # Mostrar resultados finales
                self.show_final_results()
                
            else:
                self.show_error("Error durante la ejecución del programa")
                
        except Exception as e:
            self.show_error(f"Error en modo Free Run: {e}")
            
        self.wait_enter()
        
    def step_by_step_mode(self):
        """Modo de ejecución paso a paso"""
            
        while True:
            self.print_header()
            
            print(f"🔧 Modo Step-by-Step - Paso: {self.step_count}")
            print(f"📄 Programa: {self.current_program}")
            self.print_separator()
            
            # Mostrar estado actual
            self.show_current_state()
            
            self.print_separator()
            print("\nOpciones:")
            print("  1. ⏭️  Ejecutar siguiente paso")
            print("  2. 🏃 Continuar en Free Run")
            print("  3. 🔄 Reset programa")
            print("  4. 🔙 Volver al menú principal")
            
            try:
                choice = input(f"\nSelecciona una opción (1-4): ").strip()
                
                if choice == '1':
                    self.execute_step()
                elif choice == '2':
                    self.continue_free_run()
                    break
                elif choice == '3':
                    if self.reload_program():
                        self.show_success("Programa reiniciado")
                        time.sleep(1)
                elif choice == '4':
                    break
                elif choice == '5':
                    self.show_current_state() 
                else:
                    self.show_error("Opción inválida")
                    
            except KeyboardInterrupt:
                print("\n\n🔙 Volviendo al menú principal...")
                break
                
    def reload_program(self):
        """Recarga el programa actual"""
        try:
            print("🔄 Recargando programa...")
            
            # Reset del MIPS
            self.debugger.reset_mips()
            
            # Recargar programa
            if not self.debugger.load_program(self.instructions):
                self.show_error("Error recargando programa")
                return False
                
            self.step_count = 0
            time.sleep(1)
            return True
            
        except Exception as e:
            self.show_error(f"Error recargando programa: {e}")
            return False
            
    def execute_step(self):
        """Ejecuta un solo paso"""
        try:
            print("⏭️ Ejecutando paso...")
            
            if self.debugger.step():
                self.step_count += 1
                self.show_success(f"Paso {self.step_count} completado")
                time.sleep(0.5)
            else:
                self.show_error("Error ejecutando paso")
                
        except Exception as e:
            self.show_error(f"Error en ejecución paso a paso: {e}")
            
    def continue_free_run(self):
        """Continúa la ejecución en modo free run desde el estado actual"""
        self.clear_screen()
        self.print_header()
        
        print("🏃 Continuando en Free Run...")
        self.print_separator()
        
        try:
            if self.debugger.run_program():
                self.show_success("Ejecución completada")
                self.show_final_results()
            else:
                self.show_error("Error durante la ejecución")
                
        except Exception as e:
            self.show_error(f"Error continuando en Free Run: {e}")
            
        self.wait_enter()
        
    def show_current_state(self):
        """Muestra el estado actual completo del pipeline en formato horizontal"""
        try:
            print("\nEstado Completo del Pipeline:")
            
            # Leer todos los datos del pipeline
            ifid_data = self.debugger.read_latch_ifid()
            idex_data = self.debugger.read_latch_idex()
            exmem_data = self.debugger.read_latch_exmem()
            memwb_data = self.debugger.read_latch_memwb()
            
            # Leer todos los registros
            registers = {}
            for reg_num in range(32):
                registers[reg_num] = self.debugger.read_register(reg_num)
            
            # Leer memoria de datos (32 palabras)
            memory = {}
            for addr in range(0, 128, 4):  # 32 palabras * 4 bytes = 128 bytes
                try:
                    memory[addr] = self.debugger.read_memory(addr)
                except:
                    memory[addr] = 0
            
            # Define los anchos de cada columna
            w_ifid = 18
            w_reg  = 34
            w_idex = 20
            w_exmem = 18
            w_mem = 34
            w_memwb = 18
            
            print("=" * (w_ifid + w_reg + w_idex + w_exmem + w_mem + w_memwb + 15))
            print(f"{'IF/ID':^{w_ifid}} | {'REGISTROS':^{w_reg}} | {'ID/EX':^{w_idex}} | {'EX/MEM':^{w_exmem}} | {'MEMORIA':^{w_mem}} | {'MEM/WB':^{w_memwb}}")
            print("=" * (w_ifid + w_reg + w_idex + w_exmem + w_mem + w_memwb + 15))

            max_rows = 20  # Aumentar filas para mostrar más datos de latches

            for row in range(max_rows):
                # IF/ID
                if row == 0:
                    ifid_str = f"Next: 0x{ifid_data['next_pc']:08X}"
                elif row == 1:
                    ifid_str = f"Inst: 0x{ifid_data['instruction']:08X}"
                else:
                    ifid_str = ""

                # Registros (2 columnas: 0-15 y 16-31)
                if row < 16:
                    reg1_idx = row
                    reg2_idx = row + 16
                    reg1_val = registers[reg1_idx]
                    reg2_val = registers[reg2_idx]
                    reg_str = f"${reg1_idx:2d}:0x{reg1_val:08X}    ${reg2_idx:2d}:0x{reg2_val:08X}"
                else:
                    reg_str = ""

                # ID/EX (información de control y datos - 19 campos total)
                if row == 0:
                    idex_str = f"Rd1:0x{idex_data['read_data1']:08X}"
                elif row == 1:
                    idex_str = f"Rd2:0x{idex_data['read_data2']:08X}"
                elif row == 2:
                    idex_str = f"Imm:0x{idex_data['sign_ext_imm']:08X}"
                elif row == 3:
                    idex_str = f"RS:${idex_data['rs']:2d} RT:${idex_data['rt']:2d}"
                elif row == 4:
                    idex_str = f"RD:${idex_data['rd']:2d} Sham:{idex_data['shamt']:2d}"
                elif row == 5:
                    idex_str = f"NxtPC:0x{idex_data['next_pc']:08X}"
                elif row == 6:
                    idex_str = f"ALUSrcA:{idex_data['alu_src_a']:d}  ALUSrcB:{idex_data['alu_src_b']:d}"
                elif row == 7:
                    idex_str = f"RegDst:{idex_data['reg_dst']:d}  ALUCtrl:{idex_data['alu_control']:2d}"
                elif row == 8:
                    idex_str = f"RegW:{idex_data['reg_write']:d}  MemW:{idex_data['mem_write']:d}"
                elif row == 9:
                    idex_str = f"MemR:{idex_data['mem_read']:d}  M2R:{idex_data['mem_to_reg']:d}"
                elif row == 10:
                    idex_str = f"SignLoad:{idex_data['is_signed_load']:d} BMask:0x{idex_data['byte_mask']:X}"
                elif row == 11:
                    idex_str = f"Halt:{idex_data['is_halt']:d}"
                else:
                    idex_str = ""

                # EX/MEM (10 campos total)
                if row == 0:
                    exmem_str = f"ALU:0x{exmem_data['alu_result']:08X}"
                elif row == 1:
                    exmem_str = f"WDat:0x{exmem_data['write_data']:08X}"
                elif row == 2:
                    exmem_str = f"WReg: ${exmem_data['write_reg']:2d}"
                elif row == 3:
                    exmem_str = f"RegW: {exmem_data['reg_write']:d}"
                elif row == 4:
                    exmem_str = f"MemR: {exmem_data['mem_read']:d}"
                elif row == 5:
                    exmem_str = f"MemW: {exmem_data['mem_write']:d}"
                elif row == 6:
                    exmem_str = f"M2R:  {exmem_data['mem_to_reg']:d}"
                elif row == 7:
                    exmem_str = f"Halt: {exmem_data['is_halt']:d}"
                elif row == 8:
                    exmem_str = f"BMask:0x{exmem_data['byte_mask']:X}"
                elif row == 9:
                    exmem_str = f"SignLoad:{exmem_data['is_signed_load']:d}"
                else:
                    exmem_str = ""

                # Memoria (2 direcciones por fila, solo para primeras 16 filas)
                if row < 16:
                    mem_addr1 = row * 8
                    mem_addr2 = row * 8 + 4
                    mem_val1 = memory.get(mem_addr1, 0)
                    mem_val2 = memory.get(mem_addr2, 0)
                    mem_str = f"[{mem_addr1:3d}]:{mem_val1:08X} [{mem_addr2:3d}]:{mem_val2:08X}"
                else:
                    mem_str = ""

                # MEM/WB (4 campos total)
                if row == 0:
                    memwb_str = f"WDat:0x{memwb_data['write_data']:08X}"
                elif row == 1:
                    memwb_str = f"WReg: ${memwb_data['write_reg']:2d}"
                elif row == 2:
                    memwb_str = f"RegW: {memwb_data['reg_write']:d}"
                elif row == 3:
                    memwb_str = f"Halt: {memwb_data['is_halt']:d}"
                else:
                    memwb_str = ""

                # Imprimir la fila con anchos fijos y alineados
                print(f"{ifid_str:<{w_ifid}} | {reg_str:<{w_reg}} | {idex_str:<{w_idex}} | {exmem_str:<{w_exmem}} | {mem_str:<{w_mem}} | {memwb_str:<{w_memwb}}")

            print("=" * (w_ifid + w_reg + w_idex + w_exmem + w_mem + w_memwb + 15))
                                
        except Exception as e:
            print(f"❌ Error leyendo estado: {e}")
            
    def show_final_results(self):
        """Muestra los resultados finales de la ejecución"""
        print("\n📊 Resultados Finales:")
        self.print_separator()
        
        try:
            # Mostrar todos los registros (32 registros)
            print("\n🔢 Estado Final de los 32 Registros:")
            print("=" * 80)
            
            # Mostrar registros en 2 columnas
            for row in range(16):  # 16 filas para 32 registros
                reg1_idx = row
                reg2_idx = row + 16
                
                value1 = self.debugger.read_register(reg1_idx)
                value2 = self.debugger.read_register(reg2_idx)
                
                print(f"  ${reg1_idx:2d}: 0x{value1:08X}    ${reg2_idx:2d}: 0x{value2:08X}")

            # Mostrar todas las palabras de memoria (32 palabras)
            print("\n💾 Estado de las 32 Palabras de Memoria:")
            print("=" * 80)
            
            # Mostrar memoria en 2 columnas
            for row in range(16):  # 16 filas para 32 palabras
                addr1 = row * 8
                addr2 = row * 8 + 4
                
                try:
                    value1 = self.debugger.read_memory(addr1)
                except:
                    value1 = 0
                    
                try:
                    value2 = self.debugger.read_memory(addr2)
                except:
                    value2 = 0

                print(f"  mem[{addr1:3d}]:  0x{value1:08X}        mem[{addr2:3d}]:  0x{value2:08X}")

            print("=" * 80)
                    
        except Exception as e:
            print(f"❌ Error mostrando resultados: {e}")
            
    def reset_system(self):
        """Resetea el sistema completo"""
        try:
            print("\n🔄 Reseteando sistema...")
            
            if self.debugger.ser and self.debugger.ser.is_open:
                self.debugger.reset_mips()
                
            self.current_program = None
            self.instructions = []
            self.step_count = 0
            
            self.show_success("Sistema reseteado")
            time.sleep(1)
            
        except Exception as e:
            self.show_error(f"Error durante reset: {e}")
            
    def cleanup(self):
        """Limpia los recursos antes de salir"""
        try:
            if self.debugger:
                self.debugger.disconnect()
        except:
            pass
            
    def run(self):
        """Función principal de la aplicación"""
        try:
            while True:
                # Seleccionar archivo de instrucciones
                if not self.select_instruction_file():
                    break
                    
                # Mostrar menú principal
                if not self.show_main_menu():
                    break
                    
        except KeyboardInterrupt:
            print("\n\n⚡ Aplicación interrumpida por el usuario")
        except Exception as e:
            print(f"\n❌ Error fatal: {e}")
        finally:
            self.cleanup()
            
        self.clear_screen()
        print("👋 ¡Gracias por usar MIPS Pipeline Debugger!")
        print("🚀 ¡Hasta la próxima!")


def main():
    """Punto de entrada principal"""
    console = MIPSConsole()
    console.run()


if __name__ == "__main__":
    main()
