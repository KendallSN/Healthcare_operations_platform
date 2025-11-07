# 📚 Conceptos Avanzados: Archive Logs y Replicación

**Archivo:** `conceptos-avanzados/83-archive-logs.md`
**Propósito:** Documentación profunda sobre Archive Logs en Oracle y su rol en Data Guard
**Parte de:** Sistema de Alta Disponibilidad Oracle 21c Data Guard
**Requisitos:** Haber leído 81-data-guard-conceptos.md y 82-modos-proteccion.md

---

## 📋 Tabla de Contenidos

1. [Introducción a Archive Logs](#introducción-a-archive-logs)
2. [Fundamentos de Redo y Archive Logs](#fundamentos-de-redo-y-archive-logs)
3. [Archive Log en el Contexto de Data Guard](#archive-log-en-el-contexto-de-data-guard)
4. [Configuración de Archive Logs](#configuración-de-archive-logs)
5. [Monitoreo y Diagnóstico](#monitoreo-y-diagnóstico)
6. [Gestión del Espacio de Archive Logs](#gestión-del-espacio-de-archive-logs)
7. [Archive Log Transport (Transporte de Logs)](#archive-log-transport)
8. [Archive Lag Target](#archive-lag-target)
9. [Troubleshooting de Archive Logs](#troubleshooting-de-archive-logs)
10. [Conclusiones](#conclusiones)

---

## 🎯 Introducción a Archive Logs

### ¿Qué son los Archive Logs?

Los **Archive Logs** (Archived Redo Logs) son copias permanentes de los archivos Redo Log que Oracle crea automáticamente cuando la base de datos está en modo ARCHIVELOG.

**Propósito principal:**
- **Recuperación**: Permiten recuperar la base de datos hasta cualquier punto en el tiempo
- **Replicación**: Son el mecanismo fundamental para transportar cambios al standby en Data Guard
- **Auditoría**: Mantienen un registro histórico completo de todas las transacciones

### ¿Por qué son Críticos para Data Guard?

En un entorno Data Guard:

1. **Transporte de Datos**: Los archive logs son el "vehículo" que lleva los cambios del primary al standby
2. **Apply en Standby**: El standby aplica estos logs para mantenerse sincronizado
3. **Zero Data Loss**: Con MAXAVAILABILITY, garantizan que ninguna transacción se pierde
4. **Recovery**: En caso de failover, permiten recuperación completa

---

## 🔄 Fundamentos de Redo y Archive Logs

### El Ciclo de Vida de los Cambios

```
┌─────────────┐
│   Usuario   │
│  (INSERT,   │
│  UPDATE)    │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────────────────┐
│         INSTANCIA ORACLE (SGA)              │
│  ┌──────────────────────────────────────┐   │
│  │      Redo Log Buffer (Memoria)       │   │
│  │  [Cambios en memoria antes de disco] │   │
│  └────────────┬─────────────────────────┘   │
└───────────────┼─────────────────────────────┘
                │
                │ (LGWR escribe)
                ▼
┌─────────────────────────────────────────────┐
│         ONLINE REDO LOGS (Disco)            │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐    │
│  │ Group 1 │→ │ Group 2 │→ │ Group 3 │→   │
│  │ (100MB) │  │ (100MB) │  │ (100MB) │ │  │
│  └─────────┘  └─────────┘  └─────────┘ │  │
│       ↑_________________________回归______│  │
│              (Rotación circular)            │
└───────────────┬─────────────────────────────┘
                │
                │ (ARCn copia cuando se llena)
                ▼
┌─────────────────────────────────────────────┐
│         ARCHIVE LOGS (FRA/Disco)            │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐    │
│  │ arch_1  │  │ arch_2  │  │ arch_3  │... │
│  │ 100MB   │  │ 100MB   │  │ 100MB   │    │
│  └─────────┘  └─────────┘  └─────────┘    │
│  (Permanentes hasta que se eliminen)       │
└─────────────────────────────────────────────┘
```

### Componentes Clave

#### 1. **Redo Log Buffer (SGA)**
- Área de memoria en la SGA
- Almacena cambios temporalmente antes de escribir a disco
- Tamaño: típicamente 10-15 MB

#### 2. **Online Redo Logs**
- 3+ grupos de archivos en disco (nuestro proyecto: 3 grupos)
- Se escriben de forma circular (round-robin)
- **Log Switch**: Cuando un grupo se llena, Oracle cambia al siguiente
- Crítico: LGWR (Log Writer) escribe aquí

#### 3. **Archive Logs**
- Copias permanentes de Online Redo Logs llenos
- Proceso ARCn (Archiver) los crea automáticamente
- Se almacenan en Fast Recovery Area (FRA) o destinos específicos
- No se sobrescriben automáticamente

### Procesos Involucrados

| Proceso | Función | Cuando Actúa |
|---------|---------|--------------|
| **LGWR** | Log Writer - Escribe cambios del buffer a Online Redo Logs | Continuamente (cada commit, cada 3 segundos, buffer 1/3 lleno) |
| **ARCn** | Archiver - Copia Online Redo Logs a Archive Logs | Al ocurrir log switch |
| **CKPT** | Checkpoint - Sincroniza archivos de datos con redo logs | Periódicamente y en log switches |

---

## 🔗 Archive Log en el Contexto de Data Guard

### Flujo de Archive Logs en Data Guard

```
┌─────────────────────────────────────────────────────────────────┐
│                    PRIMARY DATABASE                             │
│                                                                  │
│  1. Transacción → Redo Buffer → Online Redo Logs               │
│                         │                                        │
│                         ├─→ 2. ARCn → Archive Logs (Local FRA) │
│                         │                                        │
│                         └─→ 3. LNSn → Transporte a Standby     │
│                                  (ASYNC, SYNC, FASTSYNC)        │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          │ Red (1521) - Conexión TNS cifrada
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                   STANDBY DATABASE                              │
│                                                                  │
│  4. RFS → Recibe archive logs del primary                       │
│        │                                                         │
│        └─→ 5. Escribe a Standby Redo Logs                      │
│                    │                                             │
│                    └─→ 6. MRP (Recovery) aplica cambios        │
│                              │                                   │
│                              └─→ 7. Crea Archive Logs locales  │
│                                                                  │
│  Resultado: Base de datos sincronizada con primary             │
└─────────────────────────────────────────────────────────────────┘
```

### Transporte de Archive Logs: LGWR vs ARCn

Nuestro proyecto usa **LGWR transport (FASTSYNC)**:

| Característica | LGWR Transport (SYNC/FASTSYNC) | ARCn Transport (ASYNC) |
|----------------|--------------------------------|------------------------|
| **Proceso** | LGWR (Log Writer) | ARCn (Archiver) + LNSn |
| **Cuando se envía** | Inmediatamente al escribir a Online Redo Log | Después de log switch |
| **Latencia** | Muy baja (milisegundos) | Más alta (puede haber delay) |
| **Protección de datos** | Zero data loss (SYNC/FASTSYNC) | Posible pérdida de datos |
| **Impacto en primary** | Mayor (espera confirmación) | Menor (asíncrono) |
| **Modos soportados** | MAXPROTECTION, MAXAVAILABILITY | MAXPERFORMANCE |
| **Nuestro proyecto** | ✅ Usado (FASTSYNC) | ❌ No usado |

**Configuración en nuestro proyecto:**

```sql
-- Primary database configuration
ALTER SYSTEM SET log_archive_config='DG_CONFIG=(cdb1,cdb1_stby)';
ALTER SYSTEM SET log_archive_dest_1='LOCATION=/u01/app/oracle/fast_recovery_area/cdb1 VALID_FOR=(ALL_LOGFILES,ALL_ROLES) DB_UNIQUE_NAME=cdb1';
ALTER SYSTEM SET log_archive_dest_2='SERVICE=cdb1_stby LGWR SYNC VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=cdb1_stby';
ALTER SYSTEM SET log_archive_dest_state_2='ENABLE';
```

Aquí vemos:
- **DEST_1**: Archive logs locales (para backup)
- **DEST_2**: Transporte a standby usando LGWR SYNC (luego cambiado a FASTSYNC)

---

## ⚙️ Configuración de Archive Logs

### Parámetros Críticos del Primary

En el archivo `37-create-database.md` se documentan estos parámetros:

```sql
-- 1. Habilitar modo ARCHIVELOG
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;

-- 2. Configurar destinos de archive logs
ALTER SYSTEM SET log_archive_config='DG_CONFIG=(cdb1,cdb1_stby)' SCOPE=BOTH;

-- 3. Destino local (FRA)
ALTER SYSTEM SET log_archive_dest_1='LOCATION=/u01/app/oracle/fast_recovery_area/cdb1 VALID_FOR=(ALL_LOGFILES,ALL_ROLES) DB_UNIQUE_NAME=cdb1' SCOPE=BOTH;

-- 4. Destino remoto (standby)
ALTER SYSTEM SET log_archive_dest_2='SERVICE=cdb1_stby LGWR SYNC VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=cdb1_stby' SCOPE=BOTH;
ALTER SYSTEM SET log_archive_dest_state_2='ENABLE' SCOPE=BOTH;

-- 5. Lag target (enviar logs cada 5 minutos máximo)
ALTER SYSTEM SET archive_lag_target=300 SCOPE=BOTH;

-- 6. Formato de nombres
ALTER SYSTEM SET log_archive_format='%t_%s_%r.arc' SCOPE=SPFILE;
```

### Anatomía de un Destino de Archive Log

Analizando `log_archive_dest_2`:

```sql
ALTER SYSTEM SET log_archive_dest_2='
  SERVICE=cdb1_stby              -- Conexión TNS al standby
  LGWR                           -- Usar LGWR (no ARCn)
  SYNC                           -- Modo síncrono (confirmación requerida)
  VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE)  -- Solo cuando es primary
  DB_UNIQUE_NAME=cdb1_stby       -- Nombre único del standby
';
```

**Opciones de transporte:**
- `LGWR SYNC` = Síncrono, espera confirmación (MAXAVAILABILITY)
- `LGWR ASYNC` = Asíncrono, no espera (MAXPERFORMANCE)
- `ARCH` = Usa proceso archiver (MAXPERFORMANCE)

### Parámetros del Standby

El standby no requiere configuración de destinos de archive log mientras está en modo standby, pero **debe tener**:

```sql
-- Standby Redo Logs (SRLs) para recibir cambios
-- Creados durante RMAN DUPLICATE
-- Tamaño: igual a Online Redo Logs
-- Cantidad: N+1 (si primary tiene 3, standby debe tener 4 SRLs)
```

---

## 📊 Monitoreo y Diagnóstico

### Consultas Clave de Archive Logs

#### 1. Verificar Modo ARCHIVELOG

```sql
SELECT log_mode FROM v$database;

-- Resultado esperado:
-- ARCHIVELOG
```

#### 2. Ver Estado de Destinos de Archive Log

```sql
SELECT dest_id, dest_name, status, type, destination, error
FROM v$archive_dest
WHERE status != 'INACTIVE'
ORDER BY dest_id;

-- Resultado esperado (primary):
-- DEST_ID | DEST_NAME       | STATUS | TYPE  | DESTINATION                  | ERROR
-- --------|-----------------|--------|-------|------------------------------|-------
-- 1       | LOG_ARCHIVE_... | VALID  | LOCAL | /u01/app/oracle/fast_recov.. | NULL
-- 2       | LOG_ARCHIVE_... | VALID  | SERVICE | cdb1_stby                 | NULL
```

#### 3. Verificar Archive Logs Generados

```sql
SELECT sequence#, first_time, next_time, archived, applied, deleted
FROM v$archived_log
WHERE dest_id = 1
ORDER BY sequence# DESC
FETCH FIRST 10 ROWS ONLY;

-- Columnas clave:
-- - sequence#: Número secuencial del log
-- - archived: YES/NO (si fue archivado)
-- - applied: YES/NO (si fue aplicado en standby)
-- - deleted: YES/NO (si fue eliminado del disco)
```

#### 4. Detectar Gaps (Brechas de Secuencia)

```sql
-- En el STANDBY, ejecutar:
SELECT thread#, low_sequence#, high_sequence#
FROM v$archive_gap;

-- Si devuelve filas: HAY UN GAP
-- Si no devuelve filas: No hay gaps, todo bien
```

#### 5. Verificar Lag de Replicación

```sql
-- En el PRIMARY:
SELECT dest_id,
       status,
       type,
       target,
       (SELECT MAX(sequence#) FROM v$archived_log WHERE archived='YES') -
       MAX(sequence#) AS lag_in_sequences,
       error
FROM v$archive_dest_status
WHERE type = 'PHYSICAL'
GROUP BY dest_id, status, type, target, error;
```

#### 6. Historial de Transporte de Logs

```sql
SELECT sequence#,
       dest_id,
       to_char(first_time, 'YYYY-MM-DD HH24:MI:SS') AS first_time,
       to_char(completion_time, 'YYYY-MM-DD HH24:MI:SS') AS completion_time,
       (completion_time - first_time) * 24 * 60 AS minutes_to_transport
FROM v$archived_log
WHERE dest_id = 2  -- Destino remoto (standby)
  AND first_time > SYSDATE - 1  -- Últimas 24 horas
ORDER BY sequence# DESC;
```

### Script de Monitoreo Automatizado

Nuestro proyecto incluye el script `70-check-log-transport.md` que ejecuta verificaciones cada 10 minutos:

```bash
#!/bin/bash
# /home/oracle/automation/check_log_transport.sh
# Cron: */10 * * * *

# 1. Verificar gaps en standby
# 2. Verificar lag de secuencias
# 3. Verificar errores en destinos
# 4. Alertar si lag > 10 secuencias
```

---

## 💾 Gestión del Espacio de Archive Logs

### Crecimiento de Archive Logs

Los archive logs **crecen indefinidamente** si no se gestionan. Factores que afectan el crecimiento:

| Factor | Impacto |
|--------|---------|
| **Volumen de transacciones** | Más transacciones = más redo = más archive logs |
| **Tamaño de Online Redo Logs** | Logs más grandes = archive logs más grandes |
| **Frecuencia de log switches** | Más switches = más archive logs generados |
| **Archive lag target** | Lag de 300s = mínimo 1 archive log cada 5 minutos |

**Ejemplo de cálculo:**
```
Si:
- Online Redo Log = 100 MB
- Log switch cada 15 minutos = 4 por hora
- 24 horas de operación

Entonces:
- Archive logs por día = 4 * 24 = 96 logs
- Espacio por día = 96 * 100MB = 9.6 GB/día
- Espacio por semana = 9.6 * 7 = 67.2 GB/semana
```

### Estrategia de Limpieza

Nuestro proyecto implementa **limpieza automatizada** con retención de 7 días:

#### Primary: Script 72-delete-archives-primary.md

```bash
#!/bin/bash
# /home/oracle/automation/delete_old_archives_primary.sh
# Cron: 0 2 * * * (2 AM diario)

rman target / <<EOF
DELETE NOPROMPT ARCHIVELOG ALL COMPLETED BEFORE 'SYSDATE-7';
CROSSCHECK ARCHIVELOG ALL;
DELETE NOPROMPT EXPIRED ARCHIVELOG ALL;
EXIT;
EOF
```

**Qué hace:**
1. Elimina archive logs con más de 7 días de antigüedad
2. Verifica que los archive logs en el catálogo existen físicamente
3. Elimina registros expirados del catálogo

#### Standby: Script 73-delete-archives-standby.md

```bash
#!/bin/bash
# /home/oracle/automation/delete_old_archives_standby.sh
# Cron: 0 3 * * * (3 AM diario)

# Similar al primary, pero ejecuta 1 hora después
# para asegurar que los backups del primary ya terminaron
```

### Fast Recovery Area (FRA) - Gestión Automática

La FRA gestiona espacio automáticamente si está configurada:

```sql
-- Verificar configuración FRA
SELECT name, value FROM v$parameter WHERE name LIKE 'db_recovery%';

-- Resultado esperado:
-- db_recovery_file_dest      = /u01/app/oracle/fast_recovery_area
-- db_recovery_file_dest_size = 10G

-- Verificar uso de FRA
SELECT * FROM v$recovery_file_dest;

-- Columnas clave:
-- - space_limit: 10737418240 (10 GB)
-- - space_used: 5368709120 (5 GB usado)
-- - space_reclaimable: 2147483648 (2 GB reutilizable)
-- - number_of_files: 156
```

**Comportamiento de la FRA:**
- Oracle elimina automáticamente archive logs **obsoletos** (según política de RMAN)
- Prioriza mantener backups sobre archive logs
- Si FRA se llena al 100%, la base de datos puede **colgarse**

---

## 🚀 Archive Log Transport

### Modos de Transporte

Nuestro proyecto usa **LGWR FASTSYNC**. Comparación completa:

#### 1. LGWR SYNC (Síncrono)

```sql
ALTER SYSTEM SET log_archive_dest_2='SERVICE=cdb1_stby LGWR SYNC ...';
```

**Funcionamiento:**
1. Transacción hace COMMIT
2. LGWR escribe a Online Redo Log **local**
3. LGWR envía a standby
4. **ESPERA** confirmación del standby RFS
5. Solo entonces retorna el COMMIT al usuario

**Ventajas:**
- Zero data loss garantizado
- Sincronización perfecta

**Desventajas:**
- Latencia alta (depende de la red)
- Throughput reducido

#### 2. LGWR FASTSYNC (Optimizado)

```sql
ALTER SYSTEM SET log_archive_dest_2='SERVICE=cdb1_stby LGWR FASTSYNC ...';
```

**Funcionamiento:**
1. Transacción hace COMMIT
2. LGWR escribe a Online Redo Log **local**
3. LGWR envía a standby **en paralelo**
4. **NO ESPERA** confirmación completa (solo recepción de red)
5. Retorna el COMMIT al usuario rápidamente

**Ventajas:**
- Casi zero data loss (solo se pierden datos si falla el primary **antes** de que el standby reciba)
- Mejor performance que SYNC
- Ideal para MAXAVAILABILITY

**Desventajas:**
- Requiere red muy rápida y estable
- Ligeramente menos protección que SYNC puro

**⚠️ Configuración FASTSYNC en nuestro proyecto:**

En el archivo `57-rman-duplicate.md`, el script `configure_fastsync.sh` configura esto:

```bash
# Espera hasta 10 intentos para que FASTSYNC esté disponible
for i in {1..10}; do
    dgmgrl / <<EOF
    edit database cdb1 set property LogXptMode='FASTSYNC';
    edit database cdb1_stby set property LogXptMode='FASTSYNC';
    show configuration;
EOF

    if [ $? -eq 0 ]; then
        echo "FASTSYNC configurado exitosamente"
        break
    fi
    sleep 10
done
```

#### 3. ARCH ASYNC (Asíncrono - NO usado en nuestro proyecto)

```sql
ALTER SYSTEM SET log_archive_dest_2='SERVICE=cdb1_stby ARCH ASYNC ...';
```

**Funcionamiento:**
1. Transacción hace COMMIT
2. LGWR escribe a Online Redo Log
3. Retorna el COMMIT **inmediatamente**
4. **Después**, ARCn archiva y envía al standby (sin esperar)

**Ventajas:**
- Performance máxima
- Sin impacto en transacciones del primary

**Desventajas:**
- Posible pérdida de datos (RPO > 0)
- Lag de replicación más alto

### Proceso de Transporte en Detalle (FASTSYNC)

```
PRIMARY:                              STANDBY:
┌──────────────────┐                  ┌──────────────────┐
│  1. COMMIT       │                  │                  │
│     ejecutado    │                  │                  │
└────────┬─────────┘                  │                  │
         │                            │                  │
         ▼                            │                  │
┌──────────────────┐                  │                  │
│  2. LGWR escribe │                  │                  │
│     a Online     │                  │                  │
│     Redo Log     │                  │                  │
└────────┬─────────┘                  │                  │
         │                            │                  │
         ├─────────────────────────────────────────►     │
         │   3. LNSn envía redo      │  4. RFS recibe   │
         │      por red (1521)       │     y escribe a  │
         │                           │     Standby      │
         │                           │     Redo Logs    │
         │   5. Confirmación de red◄─┤                  │
         │      (no de disco)        │                  │
         ▼                            │                  │
┌──────────────────┐                  │                  │
│  6. COMMIT       │                  │                  │
│     retorna al   │                  │                  │
│     usuario      │                  │                  │
└──────────────────┘                  │                  │
                                      │                  │
                                      ▼                  │
                                 ┌────────────────────┐ │
                                 │  7. MRP aplica     │ │
                                 │     cambios        │ │
                                 │     (async)        │ │
                                 └────────────────────┘ │
                                      │                  │
                                      ▼                  │
                                 ┌────────────────────┐ │
                                 │  8. Archive log    │ │
                                 │     creado         │ │
                                 └────────────────────┘ │
```

---

## ⏱️ Archive Lag Target

### ¿Qué es el Archive Lag Target?

Parámetro que **fuerza** un log switch después de un tiempo específico, incluso si el Online Redo Log no está lleno.

**En nuestro proyecto:**

```sql
ALTER SYSTEM SET archive_lag_target=300 SCOPE=BOTH;
-- 300 segundos = 5 minutos
```

### ¿Por qué es Importante?

**Problema sin lag target:**
- En un sistema con **pocas transacciones**, un Online Redo Log puede tardar horas en llenarse
- El standby no recibe cambios hasta que ocurra un log switch
- **Resultado**: Replicación puede tener horas de retraso

**Solución con lag target:**
- Oracle fuerza un log switch cada 5 minutos (300s)
- Incluso si el redo log solo está 10% lleno
- **Resultado**: Replicación máxima de 5 minutos de retraso

### Impacto en el Sistema

| Aspecto | Impacto de lag_target=300 |
|---------|---------------------------|
| **Archive logs generados** | Mínimo 12 por hora (1 cada 5 min) = 288/día |
| **Tamaño de archive logs** | Pueden ser pequeños (20-30 MB si hay pocas transacciones) |
| **Lag de replicación** | Máximo 5 minutos (típicamente < 1 minuto) |
| **Espacio en disco** | Más archivos pequeños vs pocos archivos grandes |
| **Recovery Point** | RPO máximo de 5 minutos (en modo ASYNC) |

### Verificar Archive Lag Target

```sql
-- Ver configuración actual
SELECT name, value FROM v$parameter WHERE name = 'archive_lag_target';

-- Ver estadísticas de log switches
SELECT to_char(first_time, 'YYYY-MM-DD HH24') AS hour,
       COUNT(*) AS log_switches,
       ROUND(AVG(blocks * block_size / 1024 / 1024), 2) AS avg_mb
FROM v$archived_log
WHERE first_time > SYSDATE - 1
GROUP BY to_char(first_time, 'YYYY-MM-DD HH24')
ORDER BY hour;

-- Resultado esperado:
-- HOUR            | LOG_SWITCHES | AVG_MB
-- 2025-11-04 10   | 12           | 45.23
-- 2025-11-04 11   | 12           | 52.10
-- 2025-11-04 12   | 15           | 89.50  (más actividad)
```

---

## 🔧 Troubleshooting de Archive Logs

### Problema 1: Archive Logs no se Están Generando

**Síntomas:**
```sql
SELECT COUNT(*) FROM v$archived_log WHERE first_time > SYSDATE - 1;
-- Resultado: 0 (debería haber cientos)
```

**Causas posibles:**

1. **Base de datos no está en modo ARCHIVELOG**

```sql
-- Verificar
SELECT log_mode FROM v$database;
-- Si dice NOARCHIVELOG:

SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;
```

2. **Proceso ARCn no está corriendo**

```sql
-- Verificar procesos archiver
SELECT process, status, thread#, sequence#, block#, blocks
FROM v$managed_standby
WHERE process LIKE 'ARC%';

-- Si no hay procesos ARC, verificar parámetro
SELECT value FROM v$parameter WHERE name = 'log_archive_max_processes';
-- Debería ser > 0 (típicamente 4)

-- Ajustar si es necesario
ALTER SYSTEM SET log_archive_max_processes=4 SCOPE=BOTH;
```

### Problema 2: Destino de Archive Log con ERROR

**Síntomas:**
```sql
SELECT dest_id, status, error FROM v$archive_dest WHERE status = 'ERROR';

-- Resultado:
-- DEST_ID | STATUS | ERROR
-- 2       | ERROR  | ORA-16191: Primary log shipping client not logged on standby
```

**Causas y Soluciones:**

#### Error: ORA-16191 (Standby no accesible)

```bash
# 1. Verificar que standby está accesible
tnsping cdb1_stby

# Si falla, verificar:
# - Listener en standby: lsnrctl status
# - tnsnames.ora tiene entrada correcta
# - Firewall/red permite conexión en puerto 1521

# 2. Verificar que standby database está en modo MOUNT
sqlplus sys/password@cdb1_stby as sysdba <<EOF
SELECT open_mode FROM v$database;
-- Debería decir: MOUNTED
EOF

# 3. Re-habilitar destino
sqlplus / as sysdba <<EOF
ALTER SYSTEM SET log_archive_dest_state_2='DEFER';
ALTER SYSTEM SET log_archive_dest_state_2='ENABLE';
EOF
```

#### Error: ORA-16047 (DGID mismatch)

```sql
-- Verificar DGID en primary y standby
SELECT database_role, db_unique_name, dbid FROM v$database;

-- Si DGID no coincide, puede ser necesario recrear standby
-- (ver documentación en 57-rman-duplicate.md)
```

### Problema 3: Archive Log Destination Lleno (FRA 100%)

**Síntomas:**
```sql
SELECT * FROM v$recovery_file_dest;

-- SPACE_USED = SPACE_LIMIT (100% lleno)
```

**Alertas en el archivo de alerta:**
```
ORA-19815: WARNING: db_recovery_file_dest_size of 10737418240 bytes is 100.00% used
ORA-19809: limit exceeded for recovery files
```

**Solución inmediata:**

```sql
-- Opción 1: Limpiar archive logs antiguos con RMAN
RMAN> DELETE NOPROMPT ARCHIVELOG ALL COMPLETED BEFORE 'SYSDATE-3';

-- Opción 2: Expandir FRA (temporal)
ALTER SYSTEM SET db_recovery_file_dest_size=20G SCOPE=BOTH;

-- Opción 3: Mover archive logs a otra ubicación
ALTER SYSTEM SET log_archive_dest_1='LOCATION=/u02/archive_backup';
-- Luego mover archivos manualmente y limpiar FRA
```

**Solución permanente:**
- Verificar que scripts de limpieza (72, 73) están corriendo
- Ajustar retención de archive logs
- Aumentar tamaño de FRA si es necesario

### Problema 4: Gap de Secuencias (Archive Gap)

**Síntomas en STANDBY:**
```sql
SELECT * FROM v$archive_gap;

-- Resultado:
-- THREAD# | LOW_SEQUENCE# | HIGH_SEQUENCE#
-- 1       | 1523          | 1527
-- (Faltan logs del 1523 al 1527)
```

**Causa:**
- Interrupción de red
- Standby estuvo apagado
- Errores de transporte

**Solución automática (FAL - Fetch Archive Log):**

Oracle Data Guard tiene un mecanismo **automático** para recuperar logs faltantes:

```sql
-- Verificar configuración FAL en standby
SHOW PARAMETER fal

-- Debería mostrar:
-- fal_server = cdb1   (primary database)
-- fal_client = cdb1_stby  (este standby)
```

Si FAL está configurado, Oracle automáticamente:
1. Detecta el gap
2. Contacta al primary
3. Solicita los archive logs faltantes
4. Los aplica en orden

**Solución manual (si FAL falla):**

```bash
# 1. En PRIMARY, copiar archive logs faltantes
cd /u01/app/oracle/fast_recovery_area/cdb1/archivelog/2025_11_04
scp *_1523_*.arc oracle@ol8-21-dg2:/u01/app/oracle/arch_restore/
scp *_1524_*.arc oracle@ol8-21-dg2:/u01/app/oracle/arch_restore/
# ... hasta 1527

# 2. En STANDBY, registrar logs en catálogo
sqlplus / as sysdba <<EOF
ALTER DATABASE REGISTER LOGFILE '/u01/app/oracle/arch_restore/*_1523_*.arc';
ALTER DATABASE REGISTER LOGFILE '/u01/app/oracle/arch_restore/*_1524_*.arc';
-- ... hasta 1527
EOF

# 3. Verificar que gap se resolvió
SELECT * FROM v$archive_gap;
-- No debería devolver filas
```

### Problema 5: Lag Alto de Replicación

**Síntomas:**
```sql
-- En PRIMARY
SELECT name, value, unit, time_computed
FROM v$dataguard_stats
WHERE name IN ('transport lag', 'apply lag');

-- Resultado:
-- NAME          | VALUE    | UNIT    | TIME_COMPUTED
-- transport lag | +00 00:45| HH:MM:SS| 04-NOV-25 10:30:15
-- apply lag     | +00 01:15| HH:MM:SS| 04-NOV-25 10:30:15
-- (45 minutos de transport lag, 1h 15min de apply lag)
```

**Causas y Soluciones:**

1. **Red lenta o saturada**

```bash
# Verificar latencia de red
ping -c 10 192.168.56.102

# Verificar ancho de banda
iperf3 -s  # En standby
iperf3 -c 192.168.56.102  # En primary

# Si latencia > 50ms o ancho de banda < 100 Mbps:
# Considerar cambiar a modo ASYNC si MAXAVAILABILITY no es crítico
```

2. **Standby no puede aplicar logs lo suficientemente rápido**

```sql
-- En STANDBY, verificar proceso MRP
SELECT process, status, thread#, sequence#, block#, blocks
FROM v$managed_standby
WHERE process = 'MRP0';

-- Verificar si hay WAIT events problemáticos
SELECT event, total_waits, time_waited
FROM v$system_event
WHERE event LIKE '%log file%'
ORDER BY time_waited DESC;

-- Posibles soluciones:
-- - Aumentar memoria SGA en standby
-- - Mejorar I/O de discos (usar SSD)
-- - Habilitar parallel recovery (11g+)
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT PARALLEL 4;
```

3. **Archive lag target no configurado**

```sql
-- Verificar y configurar si es necesario
ALTER SYSTEM SET archive_lag_target=300 SCOPE=BOTH;
```

---

## 📝 Conclusiones

### Puntos Clave sobre Archive Logs

1. **Fundamento de Data Guard**: Los archive logs son el mecanismo que hace posible la replicación en Data Guard.

2. **Dos Propósitos**:
   - **Recuperación local**: Permiten point-in-time recovery
   - **Replicación**: Transportan cambios al standby

3. **Transporte Crítico**: La configuración del transporte (SYNC, FASTSYNC, ASYNC) determina el balance entre protección y performance.

4. **Gestión de Espacio**: Archive logs crecen indefinidamente, requieren limpieza automatizada (nuestros scripts 72-73).

5. **Monitoreo Constante**: Gaps y lag alto deben detectarse y resolverse rápidamente (nuestro script 70).

### Configuración en Nuestro Proyecto

| Aspecto | Configuración |
|---------|---------------|
| **Modo de transporte** | LGWR FASTSYNC |
| **Protection mode** | MAXAVAILABILITY |
| **Archive lag target** | 300 segundos (5 minutos) |
| **Destino local** | FRA (/u01/app/oracle/fast_recovery_area) |
| **Destino remoto** | Standby via TNS (cdb1_stby) |
| **Retención** | 7 días en primary y standby |
| **Limpieza** | Automatizada via cron (2 AM primary, 3 AM standby) |
| **Monitoreo** | Cada 10 minutos (script 70) |

### Relación con Otros Conceptos

- **Data Guard Broker** (85-data-guard-broker.md): Gestiona la configuración de transporte de logs
- **Flashback Database** (84-flashback-database.md): Usa archive logs para recovery
- **RMAN Backups** (87-rman-backups.md): Archive logs son esenciales para recovery completo
- **Modos de Protección** (82-modos-proteccion.md): Determinan cómo se transportan archive logs

### Comandos Rápidos de Referencia

```sql
-- Verificar modo ARCHIVELOG
SELECT log_mode FROM v$database;

-- Ver destinos de archive log
SELECT dest_id, status, destination FROM v$archive_dest WHERE status='VALID';

-- Verificar gaps
SELECT * FROM v$archive_gap;  -- En STANDBY

-- Verificar lag
SELECT name, value FROM v$dataguard_stats WHERE name LIKE '%lag%';

-- Limpiar archive logs antiguos
DELETE NOPROMPT ARCHIVELOG ALL COMPLETED BEFORE 'SYSDATE-7';

-- Forzar log switch (generar archive log inmediatamente)
ALTER SYSTEM SWITCH LOGFILE;

-- Ver últimos archive logs generados
SELECT sequence#, first_time, archived, applied
FROM v$archived_log
ORDER BY sequence# DESC
FETCH FIRST 10 ROWS ONLY;
```

---

**Siguiente:** [84-flashback-database.md](84-flashback-database.md) - Flashback Database para Recovery Rápido
**Anterior:** [82-modos-proteccion.md](82-modos-proteccion.md) - Modos de Protección de Data Guard
**Inicio:** [00-tabla-contenidos.md](../00-tabla-contenidos.md)
