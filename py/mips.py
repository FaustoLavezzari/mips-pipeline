"""
Programa para comunicarse con una FPGA a traves de un puerto serial.
"""

import sys
import time
import signal
import serial
import serial.tools.list_ports


# Obtener una lista de todos los puertos seriales disponibles
ports = list(serial.tools.list_ports.comports())

if not ports:
    print("No se encontro ningun puerto serial disponible.")
    sys.exit(1)

# Buscar automáticamente un puerto USB (probablemente la FPGA)
selected_port = None
for port_info in ports:
    if "USB" in port_info.device or "Digilent" in port_info.description:
        selected_port = port_info.device
        print(f"Puerto USB/FPGA detectado: {selected_port}")
        break

# Si no se encuentra un puerto USB, usar el primero disponible
if selected_port is None:
    selected_port = ports[0].device
    print(f"Usando puerto: {selected_port}")

print(f"Conectando a: {selected_port}")

# Intentar abrir el puerto serial con manejo de errores
serial_port = None
try:
    serial_port = serial.Serial(port=selected_port,
                                baudrate=19200,
                                parity=serial.PARITY_NONE,
                                stopbits=serial.STOPBITS_ONE,
                                bytesize=serial.EIGHTBITS,
                                timeout=1)
    print(f"Conexión exitosa al puerto: {selected_port}")
except serial.SerialException as e:
    print(f"Error abriendo el puerto {selected_port}: {e}")
    print("Posibles soluciones:")
    print("1. Verificar que el dispositivo esté conectado")
    print("2. Verificar permisos (agregar usuario al grupo dialout)")
    print("3. Cerrar otras aplicaciones que puedan usar el puerto")
    print("4. Intentar con otro puerto de la lista")
    sys.exit(1)
except Exception as e:
    print(f"Error inesperado: {e}")
    sys.exit(1)

# Códigos de comando del debugger
CMD_LOAD_INSTRUCTION = 0x01
CMD_RESET = 0xFF
CMD_REG = 0x02
CMD_MEM = 0x03
CMD_FREE_RUN = 0x04
ACK_CODE = 0xFF

def send_byte(byte_value):
    """Envía un byte al puerto serial."""
    serial_port.write(bytes([byte_value]))
    time.sleep(0.01)  # Pequeña pausa para dar tiempo al procesamiento

def send_word(word_value):
    """Envía una palabra de 32 bits (4 bytes) en formato big-endian."""
    bytes_to_send = [
        (word_value >> 24) & 0xFF,  # MSB
        (word_value >> 16) & 0xFF,
        (word_value >> 8) & 0xFF,
        word_value & 0xFF           # LSB
    ]
    for byte_val in bytes_to_send:
        send_byte(byte_val)

def wait_for_ack():
    """Espera por el código de acknowledgment del debugger."""
    timeout_counter = 0
    while timeout_counter < 100:  # Timeout de ~1 segundo
        if serial_port.in_waiting > 0:
            received = serial_port.read(1)
            if len(received) > 0 and received[0] == ACK_CODE:
                print("ACK recibido correctamente")
                return True
        time.sleep(0.01)
        timeout_counter += 1
    print("Timeout esperando ACK")
    return False

def read_word():
    """Lee una palabra de 32 bits del puerto serial."""
    bytes_received = []
    timeout_counter = 0
    
    while len(bytes_received) < 4 and timeout_counter < 500:
        if serial_port.in_waiting > 0:
            byte_data = serial_port.read(1)
            if len(byte_data) > 0:
                bytes_received.append(byte_data[0])
        else:
            time.sleep(0.01)
            timeout_counter += 1
    
    if len(bytes_received) == 4:
        # Reconstruir palabra de 32 bits (big-endian)
        word = (bytes_received[0] << 24) | (bytes_received[1] << 16) | \
               (bytes_received[2] << 8) | bytes_received[3]
        return word
    else:
        print(f"Error: Solo se recibieron {len(bytes_received)} bytes de 4 esperados")
        return None

def reset_mips():
    """Envía comando de reset al MIPS."""
    print("Enviando comando de reset...")
    send_byte(CMD_RESET)
    return wait_for_ack()

def load_instruction(instruction_word):
    """Carga una instrucción de 32 bits en el MIPS."""
    send_byte(CMD_LOAD_INSTRUCTION)
    send_word(instruction_word)
    return wait_for_ack()

def read_register(reg_addr):
    """Lee un registro del MIPS."""
    send_byte(CMD_REG)
    send_byte(reg_addr & 0x1F)  # Solo 5 bits para dirección de registro
    
    # Leer los 4 bytes de datos del registro
    reg_data = read_word()
    if reg_data is not None:
        if wait_for_ack():
            return reg_data
    return None

def read_memory(mem_addr):
    """Lee una palabra de memoria del MIPS."""
    send_byte(CMD_MEM)
    send_word(mem_addr)
    
    # Leer los 4 bytes de datos de memoria
    mem_data = read_word()
    if mem_data is not None:
        if wait_for_ack():
            return mem_data
    return None

def free_run():
    """Ejecuta el MIPS en modo libre hasta halt."""
    print("Iniciando ejecución libre...")
    send_byte(CMD_FREE_RUN)
    return wait_for_ack()

def parse_instruction_line(line):
    """Parsea una línea del archivo .coe y extrae la instrucción binaria."""
    # Remover comentarios y espacios
    instruction_part = line.split('//')[0].strip()
    if instruction_part:
        # Convertir de binario a entero
        return int(instruction_part, 2)
    return None

def load_instructions_from_file(filename):
    """Carga todas las instrucciones del archivo .coe."""
    instructions = []
    try:
        with open(filename, 'r') as file:
            for line_num, line in enumerate(file, 1):
                line = line.strip()
                if line and not line.startswith('//'):
                    instruction = parse_instruction_line(line)
                    if instruction is not None:
                        instructions.append(instruction)
                        print(f"Instrucción {len(instructions)}: 0x{instruction:08X}")
        print(f"Se cargaron {len(instructions)} instrucciones del archivo")
        return instructions
    except FileNotFoundError:
        print(f"Error: No se pudo encontrar el archivo {filename}")
        return []
    except Exception as e:
        print(f"Error leyendo el archivo: {e}")
        return []

def main():
    """Función principal del programa."""
    if serial_port is None:
        print("Error: No hay conexión serial disponible")
        return
        
    print(f"Conectado al puerto: {serial_port.port}")
    print("Iniciando comunicación con FPGA...")
    
    # Limpiar buffer de entrada
    serial_port.reset_input_buffer()
    serial_port.reset_output_buffer()
    
    try:
        # 1. Reset del MIPS
        if not reset_mips():
            print("Error en reset inicial")
            return
        
        time.sleep(0.1)
        
        # 2. Cargar instrucciones desde el archivo
        instructions = load_instructions_from_file('basic_inst.coe')
        if not instructions:
            print("No se pudieron cargar las instrucciones")
            return
        
        print(f"\nCargando {len(instructions)} instrucciones...")
        for i, instruction in enumerate(instructions):
            print(f"Cargando instrucción {i+1}//{len(instructions)}: 0x{instruction:08X}")
            if not load_instruction(instruction):
                print(f"Error cargando instrucción {i+1}")
                return
            time.sleep(0.05)  # Pausa entre instrucciones
        
        print("\nTodas las instrucciones cargadas exitosamente!")
        
        # 3. Ejecutar el programa
        print("\n" + "="*50)
        print("EJECUTANDO PROGRAMA")
        print("="*50)
        
        if not free_run():
            print("Error iniciando ejecución libre")
            return
        
        # Esperar un poco para que se complete la ejecución
        time.sleep(0.5)
        
        # 4. Leer registros involucrados (basado en las instrucciones)
        print("\n" + "="*50)
        print("ESTADO DE REGISTROS DESPUÉS DE LA EJECUCIÓN")
        print("="*50)
        
        # Registros usados en basic_inst.coe: $0, $1, $2, $3, $4, $5
        registers_to_check = [0, 1, 2, 3, 4, 5]
        
        for reg_num in registers_to_check:
            reg_value = read_register(reg_num)
            if reg_value is not None:
                print(f"Registro ${reg_num}: 0x{reg_value:08X} ({reg_value})")
            else:
                print(f"Error leyendo registro ${reg_num}")
            time.sleep(0.1)
        
        # 5. Leer direcciones de memoria involucradas
        print("\n" + "="*50)
        print("ESTADO DE MEMORIA DESPUÉS DE LA EJECUCIÓN")
        print("="*50)
        
        # Direcciones de memoria usadas: 0, 4, 8, 12, 16
        memory_addresses = [0, 4, 8, 12, 16]
        
        for addr in memory_addresses:
            mem_value = read_memory(addr)
            if mem_value is not None:
                print(f"Memoria[{addr:2d}]: 0x{mem_value:08X} ({mem_value})")
            else:
                print(f"Error leyendo memoria en dirección {addr}")
            time.sleep(0.1)
        
        print("\n" + "="*50)
        print("EJECUCIÓN COMPLETADA")
        print("="*50)
        
    except KeyboardInterrupt:
        print("\nPrograma interrumpido por el usuario")
    except Exception as e:
        print(f"Error durante la ejecución: {e}")
    finally:
        if serial_port and serial_port.is_open:
            serial_port.close()
            print("Puerto serial cerrado")
        else:
            print("Puerto serial ya estaba cerrado")

if __name__ == "__main__":
    main()