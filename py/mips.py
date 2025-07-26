#!/usr/bin/env python3
"""
MIPS UART Debugger
==================

Programa para comunicarse con el debugger MIPS via UART.
- Detecta automáticamente el puerto serie
- Carga instrucciones desde archivo .coe
- Ejecuta el programa
- Lee y verifica los registros
- Lee y verifica la memoria de datos

Protocolo UART:
- 'L' (0x4C): Load Program mode
- 'R' (0x52): Run mode  
- 'H' (0x48): Reset MIPS
- 'G' (0x47): Get register value
- 'M' (0x4D): Memory read
- ACK (0x41): Acknowledgment

Author: Assistant
Created: July 2025
"""

import serial
import serial.tools.list_ports
import time
import sys
import os

class MIPSDebugger:
    def __init__(self, baudrate=19200, timeout=2):
        self.ser = None
        self.baudrate = baudrate
        self.timeout = timeout
        
        # Comandos del protocolo
        self.CMD_LOAD = 0x4C      # 'L'
        self.CMD_RUN = 0x52       # 'R' 
        self.CMD_RESET = 0x48     # 'H'
        self.CMD_READ_REG = 0x47  # 'G'
        self.CMD_READ_MEM = 0x4D  # 'M'
        self.ACK_BYTE = 0x41      # 'A'
        
    def detect_uart_port(self):
        """Detecta automáticamente el puerto UART disponible"""
        ports = serial.tools.list_ports.comports()
        
        if not ports:
            return None
            
        # Intentar conectar automáticamente al primer puerto disponible
        for port in ports:
            try:
                test_ser = serial.Serial(
                    port=port.device,
                    baudrate=self.baudrate,
                    timeout=self.timeout
                )
                test_ser.close()
                return port.device
            except Exception as e:
                continue
                
        return None
        
    def connect(self, port=None):
        """Conecta al puerto UART"""
        if port is None:
            port = self.detect_uart_port()
            if port is None:
                return False
                
        try:
            self.ser = serial.Serial(
                port=port,
                baudrate=self.baudrate,
                timeout=self.timeout,
                bytesize=serial.EIGHTBITS,
                parity=serial.PARITY_NONE,
                stopbits=serial.STOPBITS_ONE
            )
            print(f"✅ Conectado a {port} @ {self.baudrate} baud")
            time.sleep(0.1)  # Esperar estabilización
            return True
        except Exception as e:
            print(f"❌ Error conectando a {port}: {e}")
            return False
            
    def disconnect(self):
        """Desconecta del puerto UART"""
        if self.ser and self.ser.is_open:
            self.ser.close()
            print("🔌 Desconectado del puerto UART")
            
    def send_byte(self, byte_val):
        """Envía un byte por UART"""
        if not self.ser or not self.ser.is_open:
            raise Exception("Puerto UART no está conectado")
        self.ser.write(bytes([byte_val]))
        
    def read_byte(self):
        """Lee un byte de UART con timeout"""
        if not self.ser or not self.ser.is_open:
            raise Exception("Puerto UART no está conectado")
        data = self.ser.read(1)
        if len(data) == 0:
            raise Exception("Timeout esperando respuesta")
        return data[0]
        
    def wait_ack(self):
        """Espera el ACK del debugger"""
        ack = self.read_byte()
        if ack != self.ACK_BYTE:
            raise Exception(f"ACK esperado (0x{self.ACK_BYTE:02X}), recibido 0x{ack:02X}")
        return True
        
    def reset_mips(self):
        """Resetea el procesador MIPS"""
        print("🔄 Reseteando MIPS...")
        self.send_byte(self.CMD_RESET)
        time.sleep(0.1)
        
    def load_instructions_from_coe(self, coe_file):
        """Carga instrucciones desde archivo .coe"""
        if not os.path.exists(coe_file):
            raise Exception(f"Archivo {coe_file} no encontrado")
            
        instructions = []
        print(f"📂 Leyendo instrucciones desde {coe_file}...")
        
        with open(coe_file, 'r') as f:
            for line_num, line in enumerate(f, 1):
                line = line.strip()
                if not line or line.startswith('//'):
                    continue
                    
                # Extraer la parte binaria (antes del comentario)
                binary_part = line.split('//')[0].strip()
                
                if len(binary_part) != 32:
                    print(f"⚠️  Línea {line_num}: instrucción de longitud incorrecta ({len(binary_part)} bits)")
                    continue
                    
                try:
                    # Convertir binario a entero de 32 bits
                    instruction = int(binary_part, 2)
                    instructions.append(instruction)
                    print(f"  📝 Instrucción {len(instructions)}: 0x{instruction:08X} - {line.split('//')[-1].strip() if '//' in line else ''}")
                except ValueError:
                    print(f"⚠️  Línea {line_num}: formato binario inválido")
                    continue
                    
        print(f"✅ {len(instructions)} instrucciones cargadas")
        return instructions
        
    def load_program(self, instructions):
        """Carga programa en memoria de instrucciones"""
        print(f"📤 Cargando {len(instructions)} instrucciones...")
        
        # Enviar comando LOAD
        self.send_byte(self.CMD_LOAD)
        time.sleep(0.1)
        
        for i, instruction in enumerate(instructions):
            print(f"  📤 Enviando instrucción {i+1}: 0x{instruction:08X}")
            
            # Enviar 4 bytes en formato big-endian
            byte3 = (instruction >> 24) & 0xFF
            byte2 = (instruction >> 16) & 0xFF
            byte1 = (instruction >> 8) & 0xFF
            byte0 = instruction & 0xFF
            
            self.send_byte(byte3)
            self.send_byte(byte2) 
            self.send_byte(byte1)
            self.send_byte(byte0)
            
            # Esperar ACK
            try:
                self.wait_ack()
                print(f"    ✅ ACK recibido")
            except Exception as e:
                print(f"    ❌ Error: {e}")
                return False
                
        print("✅ Programa cargado exitosamente")
        return True
        
    def run_program(self):
        """Ejecuta el programa cargado"""
        print("🏃 Ejecutando programa...")
        self.send_byte(self.CMD_RUN)
        
        # Esperar hasta que el programa termine (recibir ACK)
        try:
            print("⏳ Esperando que termine la ejecución...")
            ack = self.read_byte()
            if ack == self.ACK_BYTE:
                print("✅ Programa terminado correctamente")
                return True
            else:
                print(f"❌ Respuesta inesperada: 0x{ack:02X}")
                return False
        except Exception as e:
            print(f"❌ Error durante ejecución: {e}")
            return False
            
    def read_register(self, reg_num):
        """Lee el valor de un registro específico"""
        if reg_num < 0 or reg_num > 31:
            raise Exception(f"Número de registro inválido: {reg_num}")
            
        # Enviar comando READ_REG
        self.send_byte(self.CMD_READ_REG)
        
        # Enviar número de registro
        self.send_byte(reg_num)
        
        # Leer 4 bytes del valor (big-endian)
        byte3 = self.read_byte()
        byte2 = self.read_byte()
        byte1 = self.read_byte()
        byte0 = self.read_byte()
        
        value = (byte3 << 24) | (byte2 << 16) | (byte1 << 8) | byte0
        return value
        
    def read_memory(self, mem_addr):
        """Lee el valor de una posición específica de memoria de datos"""
        if mem_addr < 0 or mem_addr > 0xFFFF:
            raise Exception(f"Dirección de memoria inválida: {mem_addr}")
            
        # Enviar comando READ_MEM
        self.send_byte(self.CMD_READ_MEM)
        
        # Enviar dirección de memoria (2 bytes, big-endian)
        byte1 = (mem_addr >> 8) & 0xFF
        byte0 = mem_addr & 0xFF
        
        self.send_byte(byte1)
        self.send_byte(byte0)
        
        # Leer 4 bytes del valor (big-endian)
        byte3 = self.read_byte()
        byte2 = self.read_byte()
        byte1 = self.read_byte()
        byte0 = self.read_byte()
        
        value = (byte3 << 24) | (byte2 << 16) | (byte1 << 8) | byte0
        return value
        
    def verify_registers(self, expected_values=None):
        """Verifica los valores de los registros"""
        print("🔍 Verificando registros...")
        
        # Si no se especifican valores esperados, usar los del programa de ejemplo
        if expected_values is None:
            expected_values = {
                1: 5,      # addi $1, $0, 5
                2: 10,     # addi $2, $0, 10  
                3: 100,    # addi $3, $0, 100
                4: 20,     # addi $4, $0, 20
                5: 15      # addi $5, $0, 15
            }
            
        results = {}
        for reg_num in range(1, 6):  # Verificar registros $1 a $5
            try:
                value = self.read_register(reg_num)
                results[reg_num] = value
                
                if reg_num in expected_values:
                    expected = expected_values[reg_num]
                    status = "✅" if value == expected else "❌"
                    print(f"  ${reg_num}: {value:8d} (0x{value:08X}) {status} {'✓' if value == expected else f'esperado: {expected}'}")
                else:
                    print(f"  ${reg_num}: {value:8d} (0x{value:08X})")
                    
            except Exception as e:
                print(f"  ❌ Error leyendo registro ${reg_num}: {e}")
                results[reg_num] = None
                
        return results

    def verify_memory(self, expected_values=None):
        """Verifica los valores de la memoria de datos"""
        print("🔍 Verificando memoria de datos...")
        
        # Si no se especifican valores esperados, usar los del programa de ejemplo
        # Basado en las instrucciones sw del basic_inst.coe:
        # sw $1,   0($0)  -> mem[0] = 5
        # sw $2,   4($0)  -> mem[4] = 10
        # sw $3,   8($0)  -> mem[8] = 100
        # sw $4,  12($0)  -> mem[12] = 20
        # sw $5,  16($0)  -> mem[16] = 15
        if expected_values is None:
            expected_values = {
                0: 5,      # sw $1, 0($0)
                4: 10,     # sw $2, 4($0)
                8: 100,    # sw $3, 8($0)
                12: 20,    # sw $4, 12($0)
                16: 15     # sw $5, 16($0)
            }
            
        results = {}
        for mem_addr in sorted(expected_values.keys()):
            try:
                value = self.read_memory(mem_addr)
                results[mem_addr] = value
                
                expected = expected_values[mem_addr]
                status = "✅" if value == expected else "❌"
                print(f"  mem[{mem_addr:2d}]: {value:8d} (0x{value:08X}) {status} {'✓' if value == expected else f'esperado: {expected}'}")
                    
            except Exception as e:
                print(f"  ❌ Error leyendo memoria[{mem_addr}]: {e}")
                results[mem_addr] = None
                
        return results


def main():
    """Función principal"""
    print("🚀 MIPS UART Debugger")
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
            
        # Ejecutar programa
        if not debugger.run_program():
            print("❌ Error ejecutando programa")
            return 1
            
       # Verificar registros
        time.sleep(0.5)  # Esperar un poco antes de leer registros
        reg_results = debugger.verify_registers()
        
        # Verificar memoria de datos
        time.sleep(0.5)  # Esperar un poco antes de leer memoria
        mem_results = debugger.verify_memory()
       
        # Resumen final
        print("\n📊 Resumen de verificación:")
        
        # Verificar registros
        reg_success = all(
            reg_results.get(i) == expected 
            for i, expected in {1: 5, 2: 10, 3: 100, 4: 20, 5: 15}.items()
        )
        
        # Verificar memoria
        mem_success = all(
            mem_results.get(addr) == expected 
            for addr, expected in {0: 5, 4: 10, 8: 100, 12: 20, 16: 15}.items()
        )
        
        if reg_success:
            print("🎉 ¡Todos los registros tienen los valores esperados!")
        else:
            print("⚠️  Algunos registros no tienen los valores esperados")
            
        if mem_success:
            print("🎉 ¡Toda la memoria tiene los valores esperados!")
        else:
            print("⚠️  Algunos valores de memoria no son los esperados")
            
        overall_success = reg_success and mem_success
        
        if overall_success:
            print("🏆 ¡Verificación completa exitosa!")
        else:
            print("💡 Revisar los valores que no coinciden")

        return 0 if overall_success else 1
        
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
