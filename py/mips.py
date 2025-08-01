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
- 'S' (0x53): Step mode
- ACK (0x41): Acknowledgment

"""

import serial
import serial.tools.list_ports
import time
import sys
import os

class MIPSDebugger:
    def __init__(self, baudrate=19200, timeout=5):
        self.ser = None
        self.baudrate = baudrate
        self.timeout = timeout
        
        # Comandos del protocolo
        self.CMD_LOAD = 0x4C      # 'L'
        self.CMD_RUN = 0x52       # 'R' 
        self.CMD_RESET = 0x48     # 'H'
        self.CMD_READ_REG = 0x47  # 'G'
        self.CMD_READ_MEM = 0x4D  # 'M'
        self.CMD_STEP = 0x53      # 'S'
        self.CMD_LATCH_IFID = 0x31   # '1' - Get IF/ID latch values
        self.CMD_LATCH_IDEX = 0x32   # '2' - Get ID/EX latch values
        self.CMD_LATCH_EXMEM = 0x33  # '3' - Get EX/MEM latch values
        self.CMD_LATCH_MEMWB = 0x34  # '4' - Get MEM/WB latch values
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
        """Carga instrucciones desde archivo .coe en formato Vivado"""
        if not os.path.exists(coe_file):
            raise Exception(f"Archivo {coe_file} no encontrado")
            
        instructions = []
        print(f"📂 Leyendo instrucciones desde {coe_file}...")
        
        with open(coe_file, 'r') as f:
            parsing_vector = False
            
            for line_num, line in enumerate(f, 1):
                line = line.strip()
                
                # Saltar líneas vacías y comentarios
                if not line or line.startswith(';'):
                    continue
                
                # Detectar configuración de radix
                if line.startswith('memory_initialization_radix='):
                    continue
                
                # Detectar inicio del vector de inicialización
                if line.startswith('memory_initialization_vector='):
                    parsing_vector = True
                    # Verificar si hay datos en la misma línea después del =
                    remaining = line.split('=', 1)[1].strip()
                    if remaining:
                        line = remaining
                    else:
                        continue
                
                # Si no estamos parseando el vector, continuar
                if not parsing_vector:
                    continue
                
                # Procesar línea con instrucciones
                # Remover el punto y coma final si existe
                if line.endswith(';'):
                    line = line[:-1]
                
                # Remover la coma final si existe
                if line.endswith(','):
                    line = line[:-1]
                
                # Extraer solo la parte hexadecimal (antes del comentario //)
                hex_part = line.split('//')[0].strip()
                
                # Remover comas y espacios
                hex_part = hex_part.replace(',', '').replace(' ', '')
                
                # Verificar que solo contenga caracteres hexadecimales
                hex_clean = ''.join(c for c in hex_part if c in '0123456789ABCDEFabcdef')
                
                if not hex_clean:
                    continue
                
                # Verificar longitud (debe ser 8 caracteres hex para 32 bits)
                if len(hex_clean) != 8:
                    print(f"⚠️  Línea {line_num}: longitud incorrecta ({len(hex_clean)} caracteres, esperados 8): {hex_clean}")
                    continue
                    
                try:
                    # Convertir hexadecimal a entero de 32 bits
                    instruction = int(hex_clean, 16)
                    instructions.append(instruction)
                    
                    # Extraer comentario si existe
                    comment = line.split('//')[-1].strip() if '//' in line else ''
                    print(f"  📝 Instrucción {len(instructions)}: 0x{instruction:08X} - {comment}")
                    
                except ValueError:
                    print(f"⚠️  Línea {line_num}: formato hexadecimal inválido: {hex_clean}")
                    continue
                    
                # Si encontramos el punto y coma final, terminamos
                if ';' in line:
                    break
                    
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
            
            # Esperar ACK (sin mostrar mensaje)
            try:
                self.wait_ack()
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
        
    def step(self):
        """Ejecuta un solo ciclo del MIPS"""
        # Enviar comando STEP
        self.send_byte(self.CMD_STEP)
        
        # Esperar ACK
        try:
            self.wait_ack()
            return True
        except Exception as e:
            print(f"❌ Error durante step: {e}")
            return False
    
    def read_latch_ifid(self):
        """Lee los datos del latch IF/ID"""
        # Enviar comando LATCH_IFID
        self.send_byte(self.CMD_LATCH_IFID)
        
        # Leer datos del latch (2 valores de 32 bits cada uno)
        # 1. debug_if_id_instr (32 bits)
        instr_bytes = [self.read_byte() for _ in range(4)]
        instr = (instr_bytes[0] << 24) | (instr_bytes[1] << 16) | (instr_bytes[2] << 8) | instr_bytes[3]
        
        # 2. debug_if_id_next_pc (32 bits)
        next_pc_bytes = [self.read_byte() for _ in range(4)]
        next_pc = (next_pc_bytes[0] << 24) | (next_pc_bytes[1] << 16) | (next_pc_bytes[2] << 8) | next_pc_bytes[3]
        
        # Esperar ACK final
        self.wait_ack()
        
        return {
            'instruction': instr,
            'next_pc': next_pc
        }
    
    def read_latch_idex(self):
        """Lee los datos del latch ID/EX"""
        # Enviar comando LATCH_IDEX
        self.send_byte(self.CMD_LATCH_IDEX)
        
        # Leer datos del latch (19 valores de 32 bits cada uno)
        data = {}
        field_names = [
            'read_data1', 'read_data2', 'sign_ext_imm', 'rs', 'rt', 'rd', 
            'shamt', 'next_pc', 'reg_dst', 'alu_src_b', 'alu_src_a', 
            'alu_control', 'mem_read', 'mem_write', 'reg_write', 
            'mem_to_reg', 'is_halt', 'byte_mask', 'is_signed_load'
        ]
        
        for field in field_names:
            field_bytes = [self.read_byte() for _ in range(4)]
            value = (field_bytes[0] << 24) | (field_bytes[1] << 16) | (field_bytes[2] << 8) | field_bytes[3]
            data[field] = value
        
        # Esperar ACK final
        self.wait_ack()
        
        return data
    
    def read_latch_exmem(self):
        """Lee los datos del latch EX/MEM"""
        # Enviar comando LATCH_EXMEM
        self.send_byte(self.CMD_LATCH_EXMEM)
        
        # Leer datos del latch (10 valores de 32 bits cada uno)
        data = {}
        field_names = [
            'alu_result', 'write_data', 'write_reg', 'reg_write', 
            'mem_read', 'mem_write', 'mem_to_reg', 'is_halt', 
            'byte_mask', 'is_signed_load'
        ]
        
        for field in field_names:
            field_bytes = [self.read_byte() for _ in range(4)]
            value = (field_bytes[0] << 24) | (field_bytes[1] << 16) | (field_bytes[2] << 8) | field_bytes[3]
            data[field] = value
        
        # Esperar ACK final
        self.wait_ack()
        
        return data
    
    def read_latch_memwb(self):
        """Lee los datos del latch MEM/WB"""
        # Enviar comando LATCH_MEMWB
        self.send_byte(self.CMD_LATCH_MEMWB)
        
        # Leer datos del latch (4 valores de 32 bits cada uno)
        data = {}
        field_names = [
            'write_data', 'write_reg', 'reg_write', 'is_halt'
        ]
        
        for field in field_names:
            field_bytes = [self.read_byte() for _ in range(4)]
            value = (field_bytes[0] << 24) | (field_bytes[1] << 16) | (field_bytes[2] << 8) | field_bytes[3]
            data[field] = value
        
        # Esperar ACK final
        self.wait_ack()
        
        return data

