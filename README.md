# MIPS Pipeline Processor

Un procesador MIPS de 5 etapas implementado en Verilog para FPGA, diseñado con pipeline completo y manejo de riesgos (hazards).

## Objetivos del Proyecto

Este proyecto implementa un procesador MIPS de 32 bits con arquitectura de pipeline de 5 etapas, optimizado para síntesis en FPGA. El diseño incluye:

- **Pipeline completo**: Las 5 etapas clásicas (IF, ID, EX, MEM, WB)
- **Manejo de riesgos**: Detección y resolución de hazards de datos y control
- **Forwarding**: Optimización del pipeline para reducir stalls
- **Conjunto de instrucciones**: Soporte para instrucciones R-type, I-type, saltos y loads/stores
- **Interfaz de debug**: Señales para monitoreo y depuración del procesador

## Arquitectura del Pipeline

### Etapa IF (Instruction Fetch)
**Ubicación**: `src/mips/if/`

La etapa de búsqueda de instrucciones maneja la obtención de instrucciones desde memoria y el control del Program Counter (PC).

**Módulos principales**:
- `if.v`: Módulo principal de la etapa
- `pc.v`: Registro del Program Counter con soporte para stalls
- `inst_mem.v`: Memoria de instrucciones con interfaz de escritura externa

**Cómo funciona**:
En cada ciclo de reloj, esta etapa realiza las siguientes operaciones:

1. **Lectura de instrucción**: El PC actual se usa como dirección para leer la instrucción desde la memoria
2. **Cálculo de PC+4**: Un sumador calcula automáticamente la dirección de la siguiente instrucción secuencial
3. **Selección de próximo PC**: Un multiplexor decide entre PC+4 (ejecución secuencial) o la dirección de salto proveniente de la etapa ID
4. **Actualización del PC**: El nuevo valor se almacena en el registro PC, a menos que haya una señal de stall activa

El diseño permite cargar programas dinámicamente a través de señales externas (`inst_write_en`, `inst_write_addr`, `inst_write_data`), útil para debugging y carga inicial de programas.

**Funcionalidades**:
- Cálculo automático de PC+4
- Soporte para saltos y branches desde la etapa ID
- Manejo de stalls para resolución de hazards
- Carga dinámica de instrucciones desde interfaz externa

### Etapa ID (Instruction Decode)
**Ubicación**: `src/mips/id/`

La etapa de decodificación se encarga del análisis de instrucciones, lectura de registros y generación de señales de control.

**Módulos principales**:
- `id.v`: Módulo principal de la etapa
- `instruction_decoder.v`: Decodificador de campos de instrucción
- `registers.v`: Banco de registros de 32 registros
- `control.v`: Unidad de control que genera todas las señales

**Cómo funciona**:
Esta es la etapa más compleja del pipeline, donde se realiza el "análisis inteligente" de cada instrucción:

1. **Decodificación de campos**: La instrucción de 32 bits se descompone en sus campos (opcode, rs, rt, rd, immediate, etc.)
2. **Lectura de registros**: Se accede al banco de registros para leer los valores de los registros fuente (rs y rt)
3. **Generación de control**: La unidad de control analiza el opcode y funct para generar todas las señales que controlarán las etapas siguientes
4. **Resolución de saltos**: Para branches y jumps, se evalúa la condición (ej: igualdad para BEQ) y se calcula la dirección destino
5. **Forwarding**: Se aplica forwarding cuando hay dependencias de datos, tomando valores de etapas posteriores en lugar del banco de registros
6. **Extensión de datos**: Los valores inmediatos se extienden a 32 bits con signo o sin signo según la instrucción

**Funcionalidades**:
- Decodificación completa de instrucciones MIPS
- Banco de registros con forwarding integrado
- Detección y resolución de branches/jumps
- Generación de señales de control para todas las etapas
- Soporte para instrucciones especiales (JAL, JALR, LUI)

### Etapa EX (Execute)
**Ubicación**: `src/mips/ex/`

La etapa de ejecución realiza operaciones aritméticas y lógicas mediante la ALU.

**Módulos principales**:
- `ex.v`: Módulo principal de la etapa
- `alu.v`: Unidad Aritmético-Lógica con soporte completo para operaciones MIPS

**Cómo funciona**:
La etapa EX es donde se ejecutan las operaciones computacionales del procesador:

1. **Selección de operandos**: Múltiples multiplexores seleccionan los operandos correctos para la ALU:
   - **Operando A**: Puede ser el contenido de rs, PC+4 (para JAL/JALR), o shamt (para desplazamientos)
   - **Operando B**: Puede ser el contenido de rt o el valor inmediato extendido

2. **Ejecución en ALU**: La ALU recibe una señal de control de 4 bits que determina la operación a realizar (suma, resta, AND, OR, desplazamientos, etc.)

3. **Cálculo de direcciones**: Para loads/stores, la ALU suma la dirección base (rs) con el offset (immediate)

4. **Selección de registro destino**: Un multiplexor decide entre:
   - rt (para instrucciones I-type)
   - rd (para instrucciones R-type)  
   - $31 (para JAL/JALR)

5. **Propagación de datos**: Los datos de rt se propagan sin modificar para instrucciones store

La ALU soporta 16 operaciones diferentes incluyendo aritmética con y sin signo, operaciones lógicas, comparaciones y desplazamientos variables.

**Funcionalidades**:
- Selección flexible de operandos (registros, inmediatos, PC+4, shamt)
- Soporte completo para operaciones R-type e I-type
- Cálculo de direcciones para loads/stores
- Selección de registro destino (rt vs rd vs $31)

### Etapa MEM (Memory Access)
**Ubicación**: `src/mips/mem/`

La etapa de memoria maneja accesos a memoria de datos con soporte para diferentes tamaños de datos.

**Módulos principales**:
- `mem.v`: Módulo principal de la etapa
- `data_memory.v`: Memoria de datos con filtrado de bytes
- `byte_filter.v`: Filtro para accesos de byte y halfword
- `conditional_sign_extend.v`: Extensión de signo para cargas

**Cómo funciona**:
Esta etapa maneja toda la interacción con la memoria de datos de manera sofisticada:

1. **Acceso a memoria**: 
   - **Reads**: Para loads (LW, LH, LB, etc.), se lee la palabra completa de 32 bits desde la dirección calculada en EX
   - **Writes**: Para stores (SW, SH, SB), se escribe selectivamente usando máscaras de bytes

2. **Manejo de máscaras**: Las señales `byte_mask` (4 bits) controlan qué bytes son afectados:
   - **SW**: `4'b1111` (todos los bytes)
   - **SH**: `4'b0011` (bytes 0 y 1)
   - **SB**: `4'b0001` (solo byte 0)
   - Para writes, cada bit de la máscara habilita la escritura del byte correspondiente

3. **Extensión de signo condicional**: Para cargas, el módulo `conditional_sign_extend` determina si extender con signo o con ceros:
   - **LB, LH**: Extensión con signo del bit más significativo cuando `is_signed_load = 1`
   - **LBU, LHU**: Extensión con ceros cuando `is_signed_load = 0`

4. **Selección de resultado final**: La etapa MEM ya realiza la selección final usando `mem_to_reg_in`:
   - Si `mem_to_reg_in = 1`: Envía el dato procesado de memoria
   - Si `mem_to_reg_in = 0`: Envía el resultado de la ALU

La interfaz de debug permite inspeccionar cualquier posición de memoria independientemente del pipeline.

**Funcionalidades**:
- Soporte para loads/stores de byte, halfword y word
- Manejo automático de extensión de signo y zero-extend
- Filtrado de bytes con máscaras configurables
- Interfaz de debug para inspección de memoria

### Etapa WB (Write Back)
**Ubicación**: `src/mips/wb/`

La etapa de escritura maneja la retroalimentación de datos al banco de registros.

**Módulos principales**:
- `wb.v`: Módulo principal de la etapa

**Cómo funciona**:
Aunque es la etapa más simple en términos de lógica, WB tiene responsabilidades críticas para el correcto funcionamiento del pipeline:

1. **Propagación directa de datos**: La etapa WB actúa principalmente como un buffer de salida:
   - **write_data**: Se propaga directamente sin modificaciones (la selección entre ALU y memoria ya se hizo en MEM)
   - **write_register**: Se propaga la dirección del registro destino
   - **reg_write**: Se propaga la señal de habilitación de escritura

2. **Sincronización del HALT**: La señal `halt` se maneja de forma especial:
   - Se registra en el **flanco negativo** del reloj para evitar conflictos
   - Se propaga como señal de finalización del procesador
   - Durante reset se inicializa en 0

3. **Retroalimentación al pipeline**: Las señales de WB se conectan directamente al banco de registros en ID:
   - **Registro destino**: La dirección del registro a escribir
   - **Dato**: El valor final a almacenar (ya procesado en MEM)
   - **Habilitación**: La señal que confirma la escritura válida

4. **Función de "buffer final"**: WB no realiza operaciones complejas, sino que:
   - Estabiliza las señales finales del pipeline
   - Proporciona el punto de salida limpio para la retroalimentación
   - Maneja la temporización crítica del HALT

**Nota importante**: La selección entre resultado de ALU y dato de memoria **NO** se realiza en WB, sino que ya viene resuelta desde la etapa MEM mediante la señal `mem_to_reg`.

Esta etapa cierra el ciclo del pipeline, permitiendo que los resultados calculados sean utilizados por instrucciones posteriores.


**Funcionalidades**:
- Propagación de datos ya procesados desde MEM
- Manejo temporizado de la señal HALT
- Retroalimentación sincronizada al banco de registros
- Buffer final del pipeline para estabilización de señales

## Manejo de Riesgos (Hazards)

### Detección de Riesgos
**Ubicación**: `src/mips/hazard/hazard_detection.v`

**Cómo funciona la detección**:
La unidad de detección opera como un "vigilante" del pipeline, monitoreando continuamente las instrucciones para identificar situaciones peligrosas:

1. **Load-Use Hazard**: 
   - **Detección**: Compara si el registro destino de un load en EX es el mismo que los registros fuente de la instrucción en ID
   - **Condición**: `(EX.rt == ID.rs) || (EX.rt == ID.rt)` cuando EX es un load
   - **Acción**: Genera señal de stall para detener las primeras dos etapas y flush para insertar una burbuja (NOP)

2. **Control Hazard**: 
   - **Detección**: Cuando la etapa ID determina que se debe tomar un salto o branch
   - **Problema**: La instrucción que ya se buscó en IF no es la correcta
   - **Acción**: Flush inmediato de IF/ID para descartar la instrucción incorrecta

3. **HALT Detection**:
   - **Detección**: Cuando se encuentra el opcode especial `111111`
   - **Acción**: Congela todo el pipeline hasta que la instrucción HALT llegue a WB

**Tipos de hazards detectados**:
- **Load-Use Hazard**: Detecta cuando una instrucción inmediatamente siguiente a un load necesita el dato cargado
- **Control Hazard**: Maneja branches y jumps con flush del pipeline
- **HALT Instruction**: Detección de instrucción especial de finalización

### Forwarding de Datos
**Ubicación**: `src/mips/hazard/id_forwarding.v`

**Cómo funciona el forwarding**:
El sistema de forwarding es una optimización inteligente que "adelanta" resultados de etapas posteriores cuando son necesarios en ID:

1. **Forwarding desde EX**: 
   - **Cuando**: Una instrucción en EX produce un resultado que necesita un branch en ID
   - **Mecánica**: El resultado de la ALU se envía directamente a ID en lugar de esperar a WB
   - **Ejemplo**: `ADD $1, $2, $3; BEQ $1, $0, label` - El resultado de ADD se usa inmediatamente en BEQ

2. **Forwarding desde MEM**:
   - **Cuando**: Una instrucción en MEM tiene un resultado que necesita un branch en ID  
   - **Mecánica**: El dato final (ALU o memoria) se envía a ID
   - **Ejemplo**: `LW $1, 0($2); NOP; BEQ $1, $0, label` - El valor cargado se usa en BEQ

3. **Forwarding desde WB**:
   - **Cuando**: Una instrucción en WB tiene un resultado que necesita un branch en ID
   - **Mecánica**: El dato final procesado se envía a ID sin esperar a que este sea escrito en el registro ya que eso toma un ciclo extra de reloj
   - **Ejemplo**: `ADD $1, $2, $3; NOP; NOP; BEQ $1, $0, label` - El resultado se usa dos ciclos después

4. **Prioridad de forwarding**: El sistema implementa una jerarquía de prioridades **EX > MEM > WB**:
   - Si hay múltiples fuentes disponibles, se selecciona la más reciente (EX tiene prioridad sobre MEM y WB)
   - Esto garantiza que se use el valor más actualizado en caso de dependencias múltiples

5. **Condiciones de forwarding**:
   - El registro destino de la instrucción posterior debe coincidir con rs o rt de la instrucción en ID
   - La instrucción posterior debe escribir al banco de registros (`reg_write = 1`)
   - El registro no puede ser $0 (hardwired zero)

6. **Selección automática**: Múltiplexores en ID seleccionan automáticamente entre:
   - Valor del banco de registros (caso normal)
   - Valor forwardeado desde EX (máxima prioridad)
   - Valor forwardeado desde MEM (prioridad media)
   - Valor forwardeado desde WB (prioridad baja)

Esta optimización elimina stalls innecesarios especialmente en branches, mejorando significativamente el rendimiento.

**Optimizaciones implementadas**:
- Forwarding desde EX/MEM a ID (para branches)
- Forwarding desde MEM/WB a ID (para branches)
- Forwarding desde WB a ID (para branches con mayor separación)
- Sistema de prioridades EX > MEM > WB para resolución de conflictos
- Prevención de stalls innecesarios en branches

## Latches de Pipeline

Los latches entre etapas preservan el estado del pipeline y permiten el procesamiento concurrente:

**Cómo funcionan los latches**:
Los latches son registros síncronos que actúan como "estaciones de paso" entre etapas, permitiendo que múltiples instrucciones se procesen simultáneamente:

1. **Sincronización**: En cada flanco positivo del reloj, los latches capturan todas las señales de la etapa anterior
2. **Preservación de estado**: Mantienen los datos estables durante todo el ciclo de reloj siguiente
3. **Control de flujo**: Responden a señales de control especiales (flush, stall) para manejar hazards

**Latches implementados**:

- **`if_id.v`**: Preserva instrucción y PC+4
  - **Entrada**: Instrucción de 32 bits y dirección PC+4 desde IF
  - **Salida**: Datos estables para decodificación en ID
  - **Control**: Stall congela los datos, flush los convierte en NOP (0x00000000)

- **`id_ex.v`**: Preserva datos de registros y señales de control  
  - **Entrada**: Valores de registros, inmediatos, y 15+ señales de control desde ID
  - **Salida**: Datos organizados para ejecución en EX
  - **Control**: Flush inserta bubbles cuando hay hazards

- **`ex_mem.v`**: Preserva resultados de ALU y datos para memoria
  - **Entrada**: Resultado ALU, datos para store, registro destino desde EX
  - **Salida**: Información preparada para acceso a memoria en MEM

- **`mem_wb.v`**: Preserva datos finales para write-back
  - **Entrada**: Dato final (ALU o memoria) y registro destino desde MEM  
  - **Salida**: Información lista para escritura en banco de registros

**Características especiales de cada latch**:
- **Señales de flush**: Convierten datos válidos en NOPs para resolución de hazards
- **Señales de stall**: Congelan el contenido para pausa temporal del pipeline
- **Reset síncrono**: Inicializan todos los registros a valores conocidos
- **Propagación selectiva**: Algunos latches manejan stalls diferenciados (primera vs segunda mitad del pipeline)

Los latches permiten que el procesador ejecute hasta 5 instrucciones simultáneamente en diferentes etapas, multiplicando efectivamente el throughput del sistema.

## Conjunto de Instrucciones Soportadas

### Instrucciones Tipo R
- Aritméticas: `ADD`, `ADDU`, `SUB`, `SUBU`
- Lógicas: `AND`, `OR`, `XOR`, `NOR`
- Comparación: `SLT`, `SLTU`
- Desplazamiento: `SLL`, `SRL`, `SRA`, `SLLV`, `SRLV`, `SRAV`
- Saltos: `JR`, `JALR`

### Instrucciones Tipo I
- Aritméticas: `ADDI`, `ADDIU`
- Lógicas: `ANDI`, `ORI`, `XORI`
- Comparación: `SLTI`, `SLTIU`
- Memoria: `LW`, `LH`, `LB`, `LHU`, `LBU`, `SW`, `SH`, `SB`
- Saltos: `BEQ`, `BNE`
- Especiales: `LUI`

### Instrucciones Tipo J
- `J` (Jump)
- `JAL` (Jump and Link)

### Instrucciones Especiales
- `HALT`: Instrucción personalizada para finalización de programa

## Herramientas de Desarrollo

### Simulación Python
**Ubicación**: `py/`

- `mips.py`: Simulador funcional del procesador
- `mips_console.py`: Interfaz de consola para debugging
- Archivos `.coe`: Programas de prueba en formato COE

### Testbenches
**Ubicación**: `testbenchs/`

Conjunto completo de testbenches para verificación:
- Tests por tipo de instrucción (R-type, I-type, Load/Store)
- Tests de saltos y branches
- Tests de hazards y forwarding

## Interfaz de Debug

**Ubicación**: `src/debugger/debugger.v`

El procesador incluye un sistema de debugging completo que permite control total y monitoreo en tiempo real del procesador a través de comunicación UART.

**Cómo funciona el debugger**:
El debugger opera como una máquina de estados que actúa como interfaz entre un host externo (PC) y el procesador MIPS:

### **Comunicación UART**
1. **Protocolo de comandos**: El debugger recibe comandos de 1 byte que especifican la operación deseada
2. **Transmisión de datos**: Los datos se envían en formato big-endian (byte más significativo primero)
3. **Confirmaciones**: Cada operación se confirma con un byte ACK ('A' = 0x41)
4. **Control de flujo**: Manejo automático de buffers UART llenos/vacíos con estados de espera

### **Comandos Disponibles**

**Carga de Programas**:
- **'L' (Load)**: Carga instrucciones en la memoria del procesador
  - **Proceso**: Recibe instrucciones de 32 bits (4 bytes) secuencialmente
  - **Finalización**: Se detecta automáticamente al recibir la instrucción HALT (0xFFFFFFFF)
  - **Direccionamiento**: Las instrucciones se cargan secuencialmente desde la dirección 0x00000000

**Control de Ejecución**:
- **'R' (Run)**: Inicia la ejecución del programa cargado
  - **Mecánica**: Libera la señal stall, permitiendo que el pipeline opere libremente
  - **Finalización**: Detecta automáticamente cuando el procesador ejecuta HALT
- **'H' (Halt/Reset)**: Resetea completamente el procesador MIPS
- **'S' (Step)**: Ejecuta exactamente un ciclo de reloj
  - **Implementación**: Libera stall por un ciclo, luego lo reactiva

**Inspección de Estado**:
- **'G' (Get Register)**: Lee el valor de un registro específico
  - **Parámetros**: Recibe número de registro (5 bits, 0-31)
  - **Respuesta**: Devuelve valor de 32 bits del registro solicitado
- **'M' (Memory)**: Lee una posición de memoria de datos
  - **Parámetros**: Recibe dirección de 16 bits
  - **Respuesta**: Devuelve valor de 32 bits de la memoria

**Monitoreo de Pipeline**:
- **'1'**: Obtiene estado del latch IF/ID (2 valores: instrucción y PC+4)
- **'2'**: Obtiene estado del latch ID/EX (19 valores: datos de registros y señales de control)
- **'3'**: Obtiene estado del latch EX/MEM (10 valores: resultado ALU y controles de memoria)
- **'4'**: Obtiene estado del latch MEM/WB (4 valores: datos finales y controles de writeback)

### **Máquina de Estados del Debugger**

El debugger implementa 16 estados diferentes:

**Estados de Control Principal**:
- **IDLE**: Espera comandos y decodifica la operación solicitada
- **MIPS_RESET**: Aplica reset al procesador MIPS

**Estados de Carga de Programa**:
- **LOAD_PROG**: Recibe bytes de instrucciones secuencialmente
- **WRITE_INST**: Escribe la instrucción completa en memoria de instrucciones
- **SEND_ACK**: Envía confirmación de operación completada

**Estados de Ejecución**:
- **RUN**: Permite ejecución libre del procesador hasta detectar HALT
- **STEP**: Ejecuta un solo ciclo de reloj con control preciso
- **SEND_RESULT**: Envía confirmación de finalización de programa

**Estados de Inspección**:
- **READ_REG/SEND_REG_VAL**: Maneja lectura y envío de valores de registros
- **READ_MEM/SEND_MEM_VAL**: Maneja lectura y envío de valores de memoria
- **SEND_LATCH/LATCH_ACK**: Maneja envío de datos de latches del pipeline

**Estados de Sincronización**:
- **WAIT_RX/WAIT_TX**: Estados de espera para sincronización con UART

### **Control del Procesador MIPS**

El debugger ejerce control total sobre el procesador através de señales específicas:

1. **Control de Ejecución**:
   - **mips_stall**: Congela el pipeline (activo la mayoría del tiempo)
   - **mips_reset**: Resetea completamente el procesador

2. **Carga de Programas**:
   - **mips_inst_write_en**: Habilita escritura en memoria de instrucciones
   - **mips_inst_write_addr/data**: Dirección y datos para carga de programa

3. **Inspección de Estado**:
   - **mips_reg_addr**: Selecciona registro para lectura
   - **mips_mem_addr**: Selecciona dirección de memoria para inspección

4. **Monitoreo de Pipeline**: Recibe todas las señales de debug de los latches

### **Funcionalidades de Debug**

**Inspección Completa**:
- **Registros**: Lectura de cualquier registro por dirección (0-31)
- **Memoria**: Inspección de memoria de datos por dirección
- **Pipeline**: Estado completo de todos los latches entre etapas
- **Control**: Monitoreo de señales de control activas en cada etapa

**Control de Ejecución**:
- **Ejecución paso a paso**: Control ciclo por ciclo del procesador
- **Ejecución continua**: Modo de ejecución libre hasta HALT
- **Reset controlado**: Reinicio completo del estado del procesador

**Programación Dinámica**:
- **Carga remota**: Carga de programas desde host externo vía UART
- **Detección automática**: Reconocimiento automático de fin de programa
- **Verificación**: Confirmación de cada operación de carga

Este sistema de debugging permite desarrollo, testing y análisis completo del procesador MIPS desde un entorno externo, facilitando enormemente el proceso de verificación y educación.

## Uso y Síntesis

### Estructura de Archivos
```
src/
├── top.v              # Módulo top-level
├── mips/              # Procesador MIPS
│   ├── mips.v         # Módulo principal del procesador
│   ├── mips_pkg.vh    # Definiciones y constantes
│   └── [etapas]/      # Módulos de cada etapa
└── uart/              # Interfaz UART (opcional)
```

### Constrains
**Ubicación**: `constraints/constraints.xdc`

Archivo de constrains para síntesis en FPGA Xilinx con definiciones de pines y timing.

## Características Técnicas

- **Arquitectura**: MIPS32 con pipeline de 5 etapas
- **Ancho de datos**: 32 bits
- **Memoria de instrucciones**: Configurable
- **Memoria de datos**: Configurable  
- **Banco de registros**: 32 registros de 32 bits
- **Soporte para FPGA**: Optimizado para síntesis
- **Clock**: Diseño síncrono con clock único
- **Reset**: Reset síncrono activo alto

---
