# 📚 Conceptos Avanzados: Data Guard Broker

**Archivo:** `conceptos-avanzados/85-data-guard-broker.md`
**Propósito:** Documentación profunda sobre Data Guard Broker y gestión centralizada de configuración
**Parte de:** Sistema de Alta Disponibilidad Oracle 21c Data Guard
**Requisitos:** Haber leído 81-data-guard-conceptos.md, 82-modos-proteccion.md

---

## 📋 Tabla de Contenidos

1. [Introducción a Data Guard Broker](#introducción-a-data-guard-broker)
2. [Arquitectura de Data Guard Broker](#arquitectura-de-data-guard-broker)
3. [Configuración de Data Guard Broker](#configuración-de-data-guard-broker)
4. [Comandos DGMGRL](#comandos-dgmgrl)
5. [Propiedades y Parámetros](#propiedades-y-parámetros)
6. [Operaciones Avanzadas](#operaciones-avanzadas)
7. [Monitoreo y Diagnóstico](#monitoreo-y-diagnóstico)
8. [Switchover y Failover con Broker](#switchover-y-failover-con-broker)
9. [Troubleshooting](#troubleshooting)
10. [Conclusiones](#conclusiones)

---

## 🎯 Introducción a Data Guard Broker

### ¿Qué es Data Guard Broker?

**Data Guard Broker** es una capa de gestión centralizada que simplifica la administración de entornos Oracle Data Guard.

**Analogía:**
- Sin Broker: Eres un piloto manual - debes ajustar cada parámetro SQL individualmente
- Con Broker: Eres un piloto con piloto automático - defines objetivos y Broker configura todo

### ¿Por qué Usar Data Guard Broker?

#### Ventajas

| Aspecto | Sin Broker | Con Broker |
|---------|-----------|------------|
| **Configuración** | Configurar manualmente 20+ parámetros en cada database | Un solo comando: `CREATE CONFIGURATION` |
| **Switchover** | 15+ comandos SQL en orden específico | Un comando: `SWITCHOVER TO standby` |
| **Failover** | 10+ comandos SQL + verificación manual | Un comando: `FAILOVER TO standby` |
| **Monitoreo** | Consultar múltiples vistas V$ en cada DB | `SHOW CONFIGURATION` - vista unificada |
| **Protection modes** | Cambiar parámetros SQL complejos | `EDIT CONFIGURATION SET PROTECTION MODE` |
| **Reinstatement** | Manual con Flashback Database | Automático después de failover |
| **Health checks** | Scripts personalizados | Validaciones integradas |

#### Beneficios Clave

1. **Gestión Centralizada**: Administra toda la configuración desde un solo punto
2. **Automatización**: Switchover/failover con un comando
3. **Validación**: Verifica configuración antes de ejecutar operaciones
4. **Monitoreo**: Estado de replicación en tiempo real
5. **Reinstatement Automático**: Convierte antiguo primary en standby sin intervención
6. **Fast-Start Failover (FSFO)**: Failover automático sin DBA (opcional, no usado en nuestro proyecto)

### Broker en Nuestro Proyecto

En el archivo `57-rman-duplicate.md`, Data Guard Broker se configura como parte del despliegue del standby:

```bash
# Después de RMAN DUPLICATE, el script configura Broker
dgmgrl / <<EOF
CREATE CONFIGURATION dg_config AS PRIMARY DATABASE IS cdb1 CONNECT IDENTIFIER IS cdb1;
ADD DATABASE cdb1_stby AS CONNECT IDENTIFIER IS cdb1_stby;
ENABLE CONFIGURATION;
EDIT CONFIGURATION SET PROTECTION MODE AS MAXAVAILABILITY;
SHOW CONFIGURATION;
EOF
```

---

## 🏗️ Arquitectura de Data Guard Broker

### Componentes de Broker

```
┌────────────────────────────────────────────────────────────────┐
│                    CLIENTE DE GESTIÓN                          │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  DGMGRL (Data Guard Manager Command Line)               │  │
│  │  - CLI para administración                               │  │
│  │  - Conexión a primary o standby                          │  │
│  │  - Comandos: CREATE, EDIT, SHOW, SWITCHOVER, FAILOVER   │  │
│  └────────────┬─────────────────────────────────────────────┘  │
└───────────────┼────────────────────────────────────────────────┘
                │
                │ Conexión SQL*Net (puerto 1521)
                │
┌───────────────▼────────────────────┬───────────────────────────┐
│         PRIMARY DATABASE           │      STANDBY DATABASE     │
│  ┌──────────────────────────────┐  │  ┌─────────────────────┐ │
│  │   DMON (Broker Monitor)      │◄─┼──┤   DMON              │ │
│  │   - Proceso background       │  │  │   - Proceso bgrd    │ │
│  │   - Monitorea health         │  │  │   - Monitorea health│ │
│  │   - Ejecuta comandos Broker  │  │  │   - Sincroniza      │ │
│  └──────────┬───────────────────┘  │  └──────┬──────────────┘ │
│             │                       │         │                │
│             ▼                       │         ▼                │
│  ┌──────────────────────────────┐  │  ┌─────────────────────┐ │
│  │ Broker Configuration File    │  │  │ Broker Config File  │ │
│  │ (dr1cdb1.dat + dr2cdb1.dat)  │  │  │ (sincronizado)      │ │
│  │                              │  │  │                     │ │
│  │ - Configuración de DG        │  │  │ - Misma config      │ │
│  │ - Estado de databases        │  │  │ - Estado replicado  │ │
│  │ - Propiedades               │  │  │                     │ │
│  └──────────────────────────────┘  │  └─────────────────────┘ │
└────────────────────────────────────┴───────────────────────────┘
```

### Procesos Clave

#### 1. **DMON (Data Guard Monitor)**

- Proceso background en cada database (primary y standby)
- Se inicia automáticamente si `dg_broker_start=true`
- Funciones:
  - Monitorea health de la configuración
  - Ejecuta comandos de Broker (switchover, failover)
  - Sincroniza configuration file entre databases
  - Detecta fallos y ejecuta reinstatement

```sql
-- Verificar proceso DMON
SELECT program FROM v$process WHERE program LIKE '%DMON%';

-- Resultado:
-- oracle@ol8-21-dg1 (DMON)
```

#### 2. **Configuration File (Broker Config)**

- Par de archivos binarios (dr1<db_unique_name>.dat, dr2<db_unique_name>.dat)
- Ubicación: $ORACLE_HOME/dbs/ por defecto
- Contiene:
  - Configuración de Data Guard
  - Estado de cada database
  - Propiedades y parámetros
  - Historial de operaciones

**En nuestro proyecto:**
```bash
# Primary
/u01/app/oracle/product/21c/dbhome_1/dbs/dr1cdb1.dat
/u01/app/oracle/product/21c/dbhome_1/dbs/dr2cdb1.dat

# Standby
/u01/app/oracle/product/21c/dbhome_1/dbs/dr1cdb1_stby.dat
/u01/app/oracle/product/21c/dbhome_1/dbs/dr2cdb1_stby.dat
```

#### 3. **DGMGRL (Data Guard Manager CLI)**

- Herramienta de línea de comandos
- Se conecta a primary o standby (ambos funcionan)
- Sintaxis simple: `VERB OBJECT OPTIONS`
- Puede ejecutar scripts batch

```bash
# Uso interactivo
dgmgrl /
DGMGRL> SHOW CONFIGURATION;

# Uso con script
dgmgrl / <<EOF
SHOW CONFIGURATION;
SHOW DATABASE cdb1;
EXIT;
EOF
```

---

## ⚙️ Configuración de Data Guard Broker

### Paso 1: Habilitar Broker en Ambas Databases

**En Primary:**
```sql
-- Habilitar proceso DMON
ALTER SYSTEM SET dg_broker_start=true SCOPE=BOTH;

-- Verificar
SELECT value FROM v$parameter WHERE name = 'dg_broker_start';
-- Resultado: TRUE

-- Verificar proceso DMON
SELECT program FROM v$process WHERE program LIKE '%DMON%';
-- Resultado: oracle@ol8-21-dg1 (DMON)
```

**En Standby:**
```sql
-- Habilitar proceso DMON
ALTER SYSTEM SET dg_broker_start=true SCOPE=BOTH;

-- Verificar
SELECT value FROM v$parameter WHERE name = 'dg_broker_start';
-- Resultado: TRUE
```

### Paso 2: Crear Configuración de Broker

**Desde el Primary** (preferido, pero puede ser desde standby también):

```bash
dgmgrl / <<EOF
-- Crear configuración con primary
CREATE CONFIGURATION dg_config AS
  PRIMARY DATABASE IS cdb1
  CONNECT IDENTIFIER IS cdb1;

-- Ver configuración (solo tiene primary por ahora)
SHOW CONFIGURATION;

-- Resultado esperado:
-- Configuration - dg_config
--   Protection Mode: MaxPerformance
--   Members:
--   cdb1 - Primary database

EXIT;
EOF
```

**Anatomía del comando CREATE CONFIGURATION:**
```
CREATE CONFIGURATION <nombre_config> AS
  PRIMARY DATABASE IS <db_unique_name>
  CONNECT IDENTIFIER IS <tns_alias>;

Donde:
- nombre_config: Nombre de la configuración (ej. dg_config)
- db_unique_name: Nombre único de la DB (parámetro db_unique_name)
- tns_alias: Alias en tnsnames.ora para conectar a la DB
```

### Paso 3: Añadir Standby a la Configuración

```bash
dgmgrl / <<EOF
-- Añadir standby database
ADD DATABASE cdb1_stby AS
  CONNECT IDENTIFIER IS cdb1_stby;

-- Ver configuración (ahora tiene primary y standby)
SHOW CONFIGURATION;

-- Resultado esperado:
-- Configuration - dg_config
--   Protection Mode: MaxPerformance
--   Members:
--   cdb1      - Primary database
--   cdb1_stby - Physical standby database

EXIT;
EOF
```

### Paso 4: Habilitar la Configuración

```bash
dgmgrl / <<EOF
-- Habilitar configuración (inicia gestión activa)
ENABLE CONFIGURATION;

-- Verificar
SHOW CONFIGURATION;

-- Resultado esperado:
-- Configuration - dg_config
--   Protection Mode: MaxPerformance
--   Members:
--   cdb1      - Primary database
--   cdb1_stby - Physical standby database
--
-- Fast-Start Failover:  Disabled
--
-- Configuration Status:
-- SUCCESS   (configuración operativa y saludable)

EXIT;
EOF
```

### Paso 5: Configurar Protection Mode

En nuestro proyecto usamos **MAXAVAILABILITY**:

```bash
dgmgrl / <<EOF
-- Cambiar a MAXAVAILABILITY
EDIT CONFIGURATION SET PROTECTION MODE AS MAXAVAILABILITY;

-- Verificar
SHOW CONFIGURATION;

-- Resultado:
--   Protection Mode: MaxAvailability

EXIT;
EOF
```

**⚠️ Nota:** Broker verifica que la configuración soporta MAXAVAILABILITY antes de aplicarlo:
- Flashback Database habilitado: ✓
- Standby Redo Logs configurados: ✓
- Transport mode: SYNC o FASTSYNC: ✓

### Paso 6: Configurar FASTSYNC (Opcional pero Recomendado)

Nuestro proyecto configura FASTSYNC para mejor performance:

```bash
#!/bin/bash
# /vagrant/2-Standby/scripts/standby/configure_fastsync.sh

# Reintentar hasta 10 veces (puede fallar si replicación no está estable)
for i in {1..10}; do
    dgmgrl / <<EOF
    EDIT DATABASE cdb1 SET PROPERTY LogXptMode='FASTSYNC';
    EDIT DATABASE cdb1_stby SET PROPERTY LogXptMode='FASTSYNC';
    SHOW CONFIGURATION;
EOF

    if [ $? -eq 0 ]; then
        echo "FASTSYNC configurado exitosamente en intento $i"
        break
    fi

    echo "Intento $i falló, reintentando en 10 segundos..."
    sleep 10
done
```

---

## 💻 Comandos DGMGRL

### Comandos de Visualización

#### SHOW CONFIGURATION

Muestra estado general de la configuración:

```bash
dgmgrl /
DGMGRL> SHOW CONFIGURATION;

# Salida:
Configuration - dg_config
  Protection Mode: MaxAvailability
  Members:
  cdb1      - Primary database
    cdb1_stby - Physical standby database

Fast-Start Failover:  Disabled

Configuration Status:
SUCCESS
```

**Estados posibles:**
- `SUCCESS`: Configuración saludable
- `WARNING`: Advertencias (ej. lag alto, pero funcional)
- `ERROR`: Errores críticos (ej. standby no accesible)

#### SHOW DATABASE

Muestra detalles de una database específica:

```bash
DGMGRL> SHOW DATABASE cdb1;

Database - cdb1
  Role:               PRIMARY
  Intended State:     TRANSPORT-ON
  Instance(s):
    cdb1

Database Status:
SUCCESS
```

**Con más detalle (verbose):**

```bash
DGMGRL> SHOW DATABASE VERBOSE cdb1;

# Muestra 100+ propiedades:
# - LogXptMode='FASTSYNC'
# - LogShipping='ON'
# - DGConnectIdentifier='cdb1'
# - StaticConnectIdentifier=...
# - RedoRoutes=...
# - etc.
```

#### SHOW DATABASE STATUS

Ver estado de replicación en tiempo real:

```bash
DGMGRL> SHOW DATABASE cdb1_stby 'StatusReport';

# Salida:
  Transport Lag:      0 seconds (computed 2 seconds ago)
  Apply Lag:          0 seconds (computed 2 seconds ago)
  Apply Rate:         15.23 MB/s
  Real Time Query:    OFF
  Instance(s):
    cdb1_stby
```

### Comandos de Configuración

#### CREATE CONFIGURATION

```bash
# Sintaxis básica
CREATE CONFIGURATION <config_name> AS
  PRIMARY DATABASE IS <db_unique_name>
  CONNECT IDENTIFIER IS <tns_alias>;

# Ejemplo
CREATE CONFIGURATION dg_config AS
  PRIMARY DATABASE IS cdb1
  CONNECT IDENTIFIER IS cdb1;
```

#### ADD DATABASE

```bash
# Añadir standby físico
ADD DATABASE <db_unique_name> AS
  CONNECT IDENTIFIER IS <tns_alias>;

# Ejemplo
ADD DATABASE cdb1_stby AS
  CONNECT IDENTIFIER IS cdb1_stby;
```

#### EDIT CONFIGURATION

```bash
# Cambiar protection mode
EDIT CONFIGURATION SET PROTECTION MODE AS { MAXPROTECTION | MAXAVAILABILITY | MAXPERFORMANCE };

# Ejemplo
EDIT CONFIGURATION SET PROTECTION MODE AS MAXAVAILABILITY;
```

#### EDIT DATABASE

```bash
# Cambiar propiedades de una database
EDIT DATABASE <db_name> SET PROPERTY <propiedad>='<valor>';

# Ejemplos:
EDIT DATABASE cdb1 SET PROPERTY LogXptMode='FASTSYNC';
EDIT DATABASE cdb1_stby SET PROPERTY LogXptMode='FASTSYNC';
EDIT DATABASE cdb1 SET STATE='TRANSPORT-ON';
EDIT DATABASE cdb1_stby SET STATE='APPLY-ON';
```

### Comandos de Operación

#### ENABLE / DISABLE

```bash
# Habilitar configuración completa
ENABLE CONFIGURATION;

# Deshabilitar configuración (para mantenimiento)
DISABLE CONFIGURATION;

# Habilitar database específica
ENABLE DATABASE cdb1_stby;

# Deshabilitar database específica (detiene replicación)
DISABLE DATABASE cdb1_stby;
```

#### SWITCHOVER

```bash
# Switchover planificado (cambiar roles)
SWITCHOVER TO <standby_db_name>;

# Ejemplo
SWITCHOVER TO cdb1_stby;

# Proceso automático:
# 1. Broker verifica que standby está sincronizado
# 2. Convierte primary a standby
# 3. Convierte standby a primary
# 4. Invierte dirección de replicación
# 5. Verifica configuración final
# Tiempo: 2-5 minutos
```

#### FAILOVER

```bash
# Failover (emergencia - primary caído)
FAILOVER TO <standby_db_name>;

# Ejemplo
FAILOVER TO cdb1_stby;

# Proceso automático:
# 1. Activa standby como nuevo primary
# 2. Aplica todos los archive logs disponibles
# 3. Abre database en modo READ WRITE
# 4. Marca antiguo primary como "failed" (para reinstatement futuro)
# Tiempo: 3-10 minutos (depende de apply lag)
```

#### REINSTATE

```bash
# Reinstaurar database fallida como nuevo standby
REINSTATE DATABASE <failed_db_name>;

# Ejemplo (después de failover)
REINSTATE DATABASE cdb1;

# Proceso automático:
# 1. Broker verifica que Flashback Database está habilitado
# 2. Flashback de la database fallida al SCN de divergencia
# 3. Convierte database a physical standby
# 4. Inicia replicación desde nuevo primary
# Tiempo: 2-5 minutos
```

### Comandos de Validación

#### VALIDATE CONFIGURATION

```bash
DGMGRL> VALIDATE CONFIGURATION;

# Verifica:
# - Conectividad entre primary y standby
# - Parámetros de inicialización correctos
# - Standby Redo Logs configurados
# - Archive log destinations
# - Flashback Database habilitado
# - Protection mode factible

# Salida:
  Database Role:    Primary database
  Ready for Switchover:  Yes
  Ready for Failover:    Yes (Primary Running)

  Managed by Clusterware:  NO
  Warning: Managed database requires clusterware to open automatically.
```

#### VALIDATE DATABASE

```bash
DGMGRL> VALIDATE DATABASE cdb1_stby;

# Verifica standby específico:
# - Puede recibir archive logs
# - Puede aplicar redo data
# - Network path operativo
# - Flashback habilitado
# - Redo transport configurado
```

---

## 🔧 Propiedades y Parámetros

### Propiedades Críticas de Database

#### LogXptMode (Transport Mode)

Define cómo se envían los redo logs al standby:

```bash
# Ver valor actual
SHOW DATABASE cdb1 'LogXptMode';

# Valores posibles:
# - SYNC       = Síncrono (MAXPROTECTION, MAXAVAILABILITY)
# - FASTSYNC   = Optimizado síncrono (MAXAVAILABILITY recomendado)
# - ASYNC      = Asíncrono (MAXPERFORMANCE)

# Cambiar a FASTSYNC (nuestro proyecto)
EDIT DATABASE cdb1 SET PROPERTY LogXptMode='FASTSYNC';
EDIT DATABASE cdb1_stby SET PROPERTY LogXptMode='FASTSYNC';
```

#### ApplyLagThreshold

Umbral de lag de aplicación para alertas:

```bash
# Configurar alerta si apply lag > 60 segundos
EDIT DATABASE cdb1_stby SET PROPERTY ApplyLagThreshold=60;

# Ver valor
SHOW DATABASE cdb1_stby 'ApplyLagThreshold';
```

#### TransportLagThreshold

Umbral de lag de transporte para alertas:

```bash
# Configurar alerta si transport lag > 30 segundos
EDIT DATABASE cdb1_stby SET PROPERTY TransportLagThreshold=30;
```

#### RedoRoutes

Rutas de redo entre databases (útil para configuraciones multi-standby):

```bash
# Ver rutas actuales
SHOW DATABASE cdb1 'RedoRoutes';

# Configurar ruta específica
EDIT DATABASE cdb1 SET PROPERTY RedoRoutes='(LOCAL : cdb1_stby)';
```

#### StaticConnectIdentifier

Cadena de conexión para conectarse a la database cuando está en MOUNT:

```bash
# Ver valor
SHOW DATABASE cdb1 'StaticConnectIdentifier';

# Típicamente:
# (DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=ol8-21-dg1.localdomain)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=cdb1)(INSTANCE_NAME=cdb1)))
```

### Propiedades de Configuration

#### Protection Mode

```bash
# Ver modo actual
SHOW CONFIGURATION;

# Cambiar modo
EDIT CONFIGURATION SET PROTECTION MODE AS MAXAVAILABILITY;
```

#### FastStartFailoverThreshold

Tiempo antes de failover automático (si FSFO está habilitado - NO usado en nuestro proyecto):

```bash
# Ver valor
SHOW CONFIGURATION 'FastStartFailoverThreshold';

# Configurar (solo si usas FSFO)
EDIT CONFIGURATION SET PROPERTY FastStartFailoverThreshold=30;
```

---

## 🎬 Operaciones Avanzadas

### Operación 1: Switchover Planificado

**Caso de uso:** Mantenimiento del primary, cambiar roles temporalmente

```bash
#!/bin/bash
# switchover.sh - Cambiar roles entre primary y standby

dgmgrl / <<EOF
-- Verificar estado antes del switchover
SHOW CONFIGURATION;
VALIDATE CONFIGURATION;

-- Ejecutar switchover
SWITCHOVER TO cdb1_stby;

-- Verificar estado después del switchover
SHOW CONFIGURATION;

-- Resultado esperado:
-- Configuration - dg_config
--   Members:
--   cdb1_stby - Primary database     (era standby, ahora es primary)
--   cdb1      - Physical standby database  (era primary, ahora es standby)

EXIT;
EOF
```

**Proceso interno del Broker durante switchover:**

```
1. Validación:
   - Standby está sincronizado (lag < threshold)
   - Flashback Database habilitado
   - Connectivity OK

2. Preparar Primary:
   - Switchear todos los online redo logs (flush redo)
   - Cerrar PDBs
   - Convertir a standby: ALTER DATABASE COMMIT TO SWITCHOVER TO PHYSICAL STANDBY

3. Preparar Standby:
   - Aplicar todos los redo logs pendientes
   - Convertir a primary: ALTER DATABASE COMMIT TO SWITCHOVER TO PRIMARY
   - Abrir database: ALTER DATABASE OPEN

4. Reconfiguración:
   - Invertir dirección de replicación
   - Actualizar redo routes
   - Iniciar managed recovery en nuevo standby

5. Verificación:
   - Confirmar nuevo primary abierto
   - Confirmar nuevo standby aplicando logs
   - Actualizar broker configuration file

Total: 2-5 minutos (depende de tamaño de database y lag)
```

### Operación 2: Failover de Emergencia

**Caso de uso:** Primary completamente caído, necesidad inmediata de disponibilidad

```bash
#!/bin/bash
# failover.sh - Failover cuando primary está caído

dgmgrl sys/password@cdb1_stby <<EOF
-- Conectarse al STANDBY (primary está caído)

-- Ver configuración (primary mostrará ERROR)
SHOW CONFIGURATION;

-- Ejecutar failover
FAILOVER TO cdb1_stby;

-- Resultado:
-- Performing failover NOW, please wait...
-- Failover succeeded, new primary is "cdb1_stby"

-- Verificar nuevo estado
SHOW CONFIGURATION;

-- Resultado esperado:
-- Configuration - dg_config
--   Members:
--   cdb1_stby - Primary database
--   cdb1      - Physical standby database (disabled) ← Marcado para reinstatement

EXIT;
EOF
```

**Proceso interno durante failover:**

```
1. Detección de fallo:
   - Primary no responde a health checks
   - DBA ejecuta FAILOVER manualmente

2. Activar Standby:
   - Recuperar y aplicar TODOS los archive logs disponibles del primary caído
   - Si hay gaps: alertar (posible pérdida de datos)
   - Activar standby: ALTER DATABASE ACTIVATE STANDBY DATABASE
   - Abrir database: ALTER DATABASE OPEN RESETLOGS

3. Reconfiguración:
   - Marcar antiguo primary como "disabled" en broker config
   - Actualizar redo routes
   - Deshabilitar replicación al antiguo primary

4. Preparar Reinstatement:
   - Registrar SCN de divergencia
   - Cuando antiguo primary vuelva online, REINSTATE DATABASE lo convertirá en standby

Total: 3-10 minutos (depende de cuántos logs hay que aplicar)
```

### Operación 3: Reinstatement después de Failover

**Caso de uso:** Antiguo primary vuelve online después de failover

```bash
#!/bin/bash
# reinstate.sh - Convertir antiguo primary en nuevo standby

# Primero, iniciar el antiguo primary en MOUNT
sqlplus / as sysdba <<EOF
STARTUP MOUNT;
EXIT;
EOF

# Luego, reinstaurar con Broker
dgmgrl / <<EOF
-- Reinstaurar database (Broker usa Flashback Database automáticamente)
REINSTATE DATABASE cdb1;

-- Resultado:
-- Reinstating database "cdb1", please wait...
-- Reinstatement of database "cdb1" succeeded

-- Verificar configuración
SHOW CONFIGURATION;

-- Resultado esperado:
-- Configuration - dg_config
--   Members:
--   cdb1_stby - Primary database
--   cdb1      - Physical standby database  ← Ahora es standby funcional

EXIT;
EOF
```

**Proceso interno durante reinstatement:**

```
1. Validación:
   - Flashback Database habilitado: YES
   - Database en MOUNT: YES
   - Flashback logs disponibles hasta SCN de divergencia: YES

2. Flashback:
   - FLASHBACK DATABASE TO SCN <scn_de_divergencia>
   - Retrocede la database al punto donde divergió del nuevo primary

3. Conversión:
   - ALTER DATABASE CONVERT TO PHYSICAL STANDBY
   - Database ahora es standby físico

4. Iniciar Replicación:
   - ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT
   - Inicia aplicación de redo logs desde nuevo primary

5. Sincronización:
   - Aplicar todos los archive logs desde el SCN de divergencia
   - Alcanzar al primary

Total: 2-5 minutos (mucho más rápido que recrear standby con RMAN DUPLICATE)
```

---

## 📊 Monitoreo y Diagnóstico

### Monitoreo Básico

#### Estado General

```bash
dgmgrl / <<EOF
-- Estado de toda la configuración
SHOW CONFIGURATION;

-- Estado detallado de cada database
SHOW DATABASE cdb1;
SHOW DATABASE cdb1_stby;

EXIT;
EOF
```

#### Lag de Replicación

```bash
dgmgrl / <<EOF
-- Ver lag de transporte y aplicación
SHOW DATABASE cdb1_stby 'StatusReport';

-- Salida:
--   Transport Lag:      2 seconds
--   Apply Lag:          5 seconds
--   Apply Rate:         12.45 MB/s

EXIT;
EOF
```

#### Validación de Configuración

```bash
dgmgrl / <<EOF
-- Validar configuración completa
VALIDATE CONFIGURATION;

-- Validar database específica
VALIDATE DATABASE cdb1_stby;

EXIT;
EOF
```

### Consultas SQL de Broker

Además de DGMGRL, puedes consultar vistas V$ para información de Broker:

```sql
-- 1. Ver configuración desde SQL
SELECT * FROM v$dg_broker_config;

-- Columnas clave:
-- - db_unique_name: cdb1, cdb1_stby
-- - target_name: CONFIGURATION, DATABASE
-- - connect_id: Identificador de conexión

-- 2. Ver estado de Broker
SELECT database_role, protection_mode, protection_level, fs_failover_status
FROM v$database;

-- Resultado (en primary):
-- DATABASE_ROLE | PROTECTION_MODE  | PROTECTION_LEVEL | FS_FAILOVER_STATUS
-- PRIMARY       | MAXIMUM AVAILABILITY | MAXIMUM AVAILABILITY | DISABLED

-- 3. Ver propiedades de Broker
SELECT name, value
FROM v$dg_broker_property
WHERE name IN ('LogXptMode', 'ApplyLagThreshold', 'TransportLagThreshold');

-- Resultado:
-- NAME                    | VALUE
-- LogXptMode              | FASTSYNC
-- ApplyLagThreshold       | 60
-- TransportLagThreshold   | 30
```

### Script de Monitoreo Automatizado

Nuestro proyecto incluye verificaciones de Data Guard (script 74-verify-dataguard.md), pero Broker añade más información:

```bash
#!/bin/bash
# /home/oracle/automation/verify_broker.sh

dgmgrl / <<EOF
-- Mostrar configuración
SHOW CONFIGURATION;

-- Verificar lag
SHOW DATABASE cdb1_stby 'StatusReport';

-- Validar todo
VALIDATE CONFIGURATION;

EXIT;
EOF
```

---

## 🎭 Switchover y Failover con Broker

### Switchover Paso a Paso

**Pre-requisitos:**
1. Primary y standby operativos
2. Lag de replicación bajo (< 30 segundos)
3. Flashback Database habilitado

**Ejecución:**

```bash
#!/bin/bash
# Manual paso a paso

# 1. Verificar estado actual
dgmgrl / <<EOF
SHOW CONFIGURATION;
EXIT;
EOF

# Output esperado:
# cdb1      - Primary database
# cdb1_stby - Physical standby database

# 2. Validar antes de switchover
dgmgrl / <<EOF
VALIDATE CONFIGURATION;
EXIT;
EOF

# Output debe decir:
# Ready for Switchover:  Yes

# 3. Ejecutar switchover
dgmgrl / <<EOF
SWITCHOVER TO cdb1_stby;
EXIT;
EOF

# Output:
# Performing switchover NOW, please wait...
# Switchover succeeded, new primary is "cdb1_stby"

# 4. Verificar nuevo estado
dgmgrl / <<EOF
SHOW CONFIGURATION;
EXIT;
EOF

# Output esperado:
# cdb1_stby - Primary database        ← Ahora es primary
# cdb1      - Physical standby database  ← Ahora es standby
```

**Documentación detallada:** Ver `92-switchover.md` para procedimiento completo con validaciones.

### Failover Paso a Paso

**Pre-requisitos:**
1. Primary completamente caído (no responde)
2. Standby operativo

**Ejecución:**

```bash
#!/bin/bash
# Failover de emergencia

# 1. Conectarse al STANDBY (primary está caído)
dgmgrl sys/password@cdb1_stby <<EOF
SHOW CONFIGURATION;
EXIT;
EOF

# Output esperado:
# cdb1      - Primary database (ERROR - no responde)
# cdb1_stby - Physical standby database

# 2. Ejecutar failover
dgmgrl sys/password@cdb1_stby <<EOF
FAILOVER TO cdb1_stby;
EXIT;
EOF

# Output:
# Performing failover NOW, please wait...
# Failover succeeded, new primary is "cdb1_stby"

# 3. Verificar nuevo estado
dgmgrl sys/password@cdb1_stby <<EOF
SHOW CONFIGURATION;
EXIT;
EOF

# Output:
# cdb1_stby - Primary database
# cdb1      - Physical standby database (disabled)

# 4. Cuando el antiguo primary vuelva, reinstaurar:
sqlplus / as sysdba <<EOF
STARTUP MOUNT;
EXIT;
EOF

dgmgrl / <<EOF
REINSTATE DATABASE cdb1;
SHOW CONFIGURATION;
EXIT;
EOF
```

**Documentación detallada:** Ver `93-failover.md` para procedimiento completo con troubleshooting.

---

## 🔧 Troubleshooting

### Problema 1: Proceso DMON no Inicia

**Síntomas:**
```sql
SELECT value FROM v$parameter WHERE name = 'dg_broker_start';
-- Resultado: TRUE

SELECT program FROM v$process WHERE program LIKE '%DMON%';
-- No rows returned (debería haber DMON)
```

**Causa:** Parámetro configurado pero proceso no inició

**Solución:**
```sql
-- Reiniciar Broker
ALTER SYSTEM SET dg_broker_start=false SCOPE=BOTH;
ALTER SYSTEM SET dg_broker_start=true SCOPE=BOTH;

-- Verificar
SELECT program FROM v$process WHERE program LIKE '%DMON%';
-- Debe mostrar: oracle@hostname (DMON)
```

### Problema 2: CREATE CONFIGURATION Falla con ORA-16698

**Error:**
```bash
dgmgrl /
DGMGRL> CREATE CONFIGURATION dg_config AS PRIMARY DATABASE IS cdb1 CONNECT IDENTIFIER IS cdb1;

# Error:
# ORA-16698: member has a LOG_ARCHIVE_DEST_n parameter with SERVICE attribute set
```

**Causa:** Parámetros log_archive_dest_n configurados manualmente (conflicto con Broker)

**Solución:**
```sql
-- Deshabilitar destinos manuales de archive log
ALTER SYSTEM SET log_archive_dest_2='' SCOPE=BOTH;
ALTER SYSTEM SET log_archive_dest_state_2='DEFER' SCOPE=BOTH;

-- Ahora Broker puede gestionar los destinos
```

**Mejor práctica:** Si usas Broker, deja que Broker gestione `log_archive_dest_n`. No configures manualmente.

### Problema 3: SWITCHOVER Falla con ORA-16475

**Error:**
```bash
DGMGRL> SWITCHOVER TO cdb1_stby;

# Error:
# ORA-16475: succeeded with warnings, check configuration and member state
```

**Causa:** Standby tiene lag alto (no está sincronizado)

**Diagnóstico:**
```bash
DGMGRL> SHOW DATABASE cdb1_stby 'StatusReport';

# Output:
#   Transport Lag:      0 seconds
#   Apply Lag:          180 seconds  ← LAG ALTO (3 minutos)
```

**Solución:**
```bash
# Esperar a que el lag disminuya
# Monitorear hasta que Apply Lag < 10 segundos

# Verificar MRP en standby
sqlplus / as sysdba <<EOF
SELECT process, status FROM v\$managed_standby WHERE process = 'MRP0';
-- Debe decir: MRP0 | APPLYING
EXIT;
EOF

# Reintentar switchover cuando lag < 10s
```

### Problema 4: Configuration Status = ERROR

**Síntomas:**
```bash
DGMGRL> SHOW CONFIGURATION;

# Output:
# Configuration Status:
# ERROR
```

**Diagnóstico:**
```bash
# Ver detalles del error
DGMGRL> SHOW CONFIGURATION VERBOSE;

# O ver estado de cada database
DGMGRL> SHOW DATABASE cdb1;
DGMGRL> SHOW DATABASE cdb1_stby;

# Uno de ellos mostrará ERROR con detalles
```

**Causas comunes:**

1. **Standby no accesible por red**
```bash
# Verificar conectividad
tnsping cdb1_stby

# Verificar listener en standby
ssh oracle@ol8-21-dg2 "lsnrctl status"
```

2. **Standby no está en modo MOUNT**
```bash
# Verificar open_mode en standby
sqlplus sys/password@cdb1_stby as sysdba <<EOF
SELECT open_mode FROM v\$database;
-- Debe decir: MOUNTED (no OPEN)
EXIT;
EOF
```

3. **Flashback Database no habilitado**
```sql
-- En primary y standby
SELECT flashback_on FROM v$database;
-- Debe decir: YES

-- Si dice NO, habilitar:
ALTER DATABASE FLASHBACK ON;
```

### Problema 5: REINSTATE Falla

**Error:**
```bash
DGMGRL> REINSTATE DATABASE cdb1;

# Error:
# ORA-16653: failed to reinstate database
```

**Causas posibles:**

1. **Flashback Database no habilitado**
```sql
SELECT flashback_on FROM v$database;
-- Si dice NO:
ALTER DATABASE FLASHBACK ON;
```

2. **No hay flashback logs suficientes**
```sql
-- Verificar oldest_flashback_scn
SELECT oldest_flashback_scn, oldest_flashback_time FROM v$database;

-- Si el SCN de divergencia es más antiguo que oldest_flashback_scn:
-- NO SE PUEDE REINSTATE - Necesitas RMAN DUPLICATE (script 57)
```

3. **Database no está en MOUNT**
```sql
-- Verificar
SELECT open_mode FROM v$database;
-- Debe decir: MOUNTED

-- Si dice OPEN:
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
```

---

## 📝 Conclusiones

### Puntos Clave sobre Data Guard Broker

1. **Simplificación:** Broker reduce operaciones complejas (switchover, failover) de 15+ comandos a 1 comando.

2. **Gestión Centralizada:** Configura y monitorea todo el entorno Data Guard desde un solo punto.

3. **Automatización:** Reinstatement automático después de failover (con Flashback Database) es un game-changer.

4. **Validación:** Broker valida configuración antes de ejecutar operaciones críticas (previene errores).

5. **Obligatorio en Producción:** En entornos de producción, Broker es prácticamente obligatorio por su robustez.

### Configuración en Nuestro Proyecto

| Aspecto | Configuración |
|---------|---------------|
| **Broker habilitado** | Sí (en primary y standby) |
| **Configuration name** | dg_config |
| **Protection mode** | MAXAVAILABILITY |
| **Transport mode** | FASTSYNC |
| **Fast-Start Failover** | NO (manual failover) |
| **Proceso DMON** | Activo en ambas databases |
| **Configuration file** | Default location ($ORACLE_HOME/dbs/) |
| **Validación automática** | Sí (health checks cada 30s) |

### Relación con Otros Componentes

- **Archive Logs** (83-archive-logs.md): Broker gestiona automáticamente `log_archive_dest_n`
- **Flashback Database** (84-flashback-database.md): Broker usa Flashback para reinstatement
- **Modos de Protección** (82-modos-proteccion.md): Broker facilita cambiar entre modos
- **Switchover** (92-switchover.md): Broker automatiza el proceso completo
- **Failover** (93-failover.md): Broker ejecuta failover con un comando

### Comandos Rápidos de Referencia

```bash
# Habilitar Broker
ALTER SYSTEM SET dg_broker_start=true SCOPE=BOTH;

# Crear configuración
dgmgrl /
CREATE CONFIGURATION dg_config AS PRIMARY DATABASE IS cdb1 CONNECT IDENTIFIER IS cdb1;
ADD DATABASE cdb1_stby AS CONNECT IDENTIFIER IS cdb1_stby;
ENABLE CONFIGURATION;
EDIT CONFIGURATION SET PROTECTION MODE AS MAXAVAILABILITY;

# Ver estado
SHOW CONFIGURATION;
SHOW DATABASE cdb1;
SHOW DATABASE cdb1_stby 'StatusReport';

# Validar
VALIDATE CONFIGURATION;
VALIDATE DATABASE cdb1_stby;

# Switchover
SWITCHOVER TO cdb1_stby;

# Failover
FAILOVER TO cdb1_stby;

# Reinstate
REINSTATE DATABASE cdb1;

# Configurar propiedades
EDIT DATABASE cdb1 SET PROPERTY LogXptMode='FASTSYNC';
EDIT DATABASE cdb1_stby SET PROPERTY ApplyLagThreshold=60;
```

---

**Siguiente:** [86-networking-tns.md](86-networking-tns.md) - Configuración de Networking TNS
**Anterior:** [84-flashback-database.md](84-flashback-database.md) - Flashback Database
**Inicio:** [00-tabla-contenidos.md](../00-tabla-contenidos.md)
