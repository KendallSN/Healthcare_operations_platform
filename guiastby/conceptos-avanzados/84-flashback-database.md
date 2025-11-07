# 📚 Conceptos Avanzados: Flashback Database

**Archivo:** `conceptos-avanzados/84-flashback-database.md`
**Propósito:** Documentación profunda sobre Flashback Database en Oracle y su rol crítico en Data Guard
**Parte de:** Sistema de Alta Disponibilidad Oracle 21c Data Guard
**Requisitos:** Haber leído 80-oracle-cdb-pdb.md, 81-data-guard-conceptos.md

---

## 📋 Tabla de Contenidos

1. [Introducción a Flashback Database](#introducción-a-flashback-database)
2. [Fundamentos Técnicos](#fundamentos-técnicos)
3. [Flashback Database en Data Guard](#flashback-database-en-data-guard)
4. [Configuración de Flashback Database](#configuración-de-flashback-database)
5. [Operaciones con Flashback Database](#operaciones-con-flashback-database)
6. [Monitoreo y Gestión](#monitoreo-y-gestión)
7. [Casos de Uso Prácticos](#casos-de-uso-prácticos)
8. [Troubleshooting](#troubleshooting)
9. [Conclusiones](#conclusiones)

---

## 🎯 Introducción a Flashback Database

### ¿Qué es Flashback Database?

**Flashback Database** es una característica de Oracle que permite **retroceder** una base de datos completa a un punto anterior en el tiempo, sin necesidad de restaurar desde backup.

**Analogía simple:**
- Es como el "Ctrl+Z" (deshacer) de Oracle, pero para toda la base de datos
- En lugar de deshacer una operación, retrocedes la base de datos completa

### ¿Por qué es Crítico en Data Guard?

En un entorno Data Guard, Flashback Database es **absolutamente esencial** para:

#### 1. **Reinstatement Rápido después de Failover**

**Escenario sin Flashback:**
```
Primary falla → Failover a Standby → Standby se convierte en Primary
                                       ↓
                              El antiguo Primary ya NO puede ser standby
                              (tiene datos divergentes)
                                       ↓
                              SOLUCIÓN: Recrear standby desde cero
                              (RMAN DUPLICATE - 20-30 minutos)
```

**Escenario con Flashback:**
```
Primary falla → Failover a Standby → Standby se convierte en Primary
                                       ↓
                              Flashback del antiguo Primary al SCN de divergencia
                              (2-5 minutos)
                                       ↓
                              Antiguo Primary se convierte en nuevo Standby
```

**Ahorro de tiempo: De 30 minutos a 5 minutos**

#### 2. **Recuperación de Errores Lógicos**

```sql
-- ERROR: Alguien ejecutó esto por accidente a las 14:30
DELETE FROM hc_user WHERE 1=1;
COMMIT;

-- SOLUCIÓN con Flashback Database:
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
FLASHBACK DATABASE TO TIMESTAMP TO_TIMESTAMP('2025-11-04 14:25:00', 'YYYY-MM-DD HH24:MI:SS');
ALTER DATABASE OPEN RESETLOGS;
-- Base de datos restaurada a las 14:25 (antes del error)
```

#### 3. **Testing y Desarrollo**

- Probar upgrades de Oracle y retroceder si falla
- Probar cambios de aplicación en clon de producción
- Simulacros de disaster recovery

---

## 🔧 Fundamentos Técnicos

### ¿Cómo Funciona Flashback Database?

Flashback Database **no es un backup**. Es un mecanismo que registra los **cambios inversos** a los datos.

#### Arquitectura de Flashback

```
┌─────────────────────────────────────────────────────────────┐
│                    INSTANCIA ORACLE                         │
│                                                              │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                    SGA (Memoria)                       │  │
│  │  ┌──────────────┐         ┌──────────────────────┐   │  │
│  │  │ Redo Buffer  │         │ Flashback Buffer     │   │  │
│  │  │ (Cambios)    │         │ (Before-images)      │   │  │
│  │  └──────┬───────┘         └──────┬───────────────┘   │  │
│  └─────────┼────────────────────────┼───────────────────┘  │
└────────────┼────────────────────────┼──────────────────────┘
             │                        │
             │ LGWR escribe           │ RVWR escribe
             │ (Log Writer)           │ (Recovery Writer)
             ▼                        ▼
    ┌────────────────┐       ┌────────────────────────┐
    │  Online Redo   │       │  Flashback Logs        │
    │  Logs          │       │  (FRA)                 │
    │  (Cambios)     │       │  (Before-images)       │
    └────────────────┘       └────────────────────────┘
         │                            │
         │                            │
         ▼                            ▼
    Archive Logs            Flashback Logs se reciclan
    (permanentes)           (según retention target)
```

### Conceptos Clave

#### 1. **Flashback Logs**

- Archivos especiales almacenados en la **Fast Recovery Area (FRA)**
- Contienen **before-images** de bloques modificados
- Se crean automáticamente cuando Flashback Database está habilitado
- Tamaño: depende del retention target y volumen de cambios

**Nomenclatura:**
```
/u01/app/oracle/fast_recovery_area/CDB1/flashback/
    o1_mf_m4k2x7hp_.flb
    o1_mf_m4k2x9jq_.flb
```

#### 2. **RVWR (Recovery Writer Process)**

- Proceso background que escribe flashback logs
- Similar a LGWR pero para flashback data
- Solo existe si Flashback Database está habilitado

```sql
-- Verificar proceso RVWR
SELECT program FROM v$process WHERE program LIKE '%RVWR%';

-- Resultado:
-- oracle@ol8-21-dg1 (RVWR)
```

#### 3. **SCN (System Change Number)**

- Número secuencial que identifica un punto en el tiempo en Oracle
- Flashback Database usa SCN para identificar el punto de retroceso
- Cada transacción confirmada tiene un SCN asociado

```sql
-- Ver SCN actual
SELECT current_scn FROM v$database;

-- Resultado: 4827356
```

#### 4. **Flashback Retention Target**

- Parámetro que define **cuánto tiempo atrás** puedes retroceder
- Se mide en minutos (típicamente 1440 = 24 horas)
- Determina cuántos flashback logs se mantienen

**En nuestro proyecto:**
```sql
ALTER SYSTEM SET db_flashback_retention_target=1440 SCOPE=BOTH;
-- 1440 minutos = 24 horas de retención
```

### Diferencia entre Flashback Database y Backup/Restore

| Aspecto | Flashback Database | RMAN Backup/Restore |
|---------|-------------------|---------------------|
| **Velocidad** | Muy rápido (2-5 minutos) | Lento (20-60 minutos) |
| **Granularidad** | Cualquier punto en el retention window | Solo puntos de backup |
| **Espacio** | Moderado (flashback logs en FRA) | Alto (backupsets) |
| **Requiere RESETLOGS** | Sí (abre en nuevo incarnation) | Sí (si incomplete recovery) |
| **Retrocede todos los cambios** | Sí, toda la database | Sí, toda la database |
| **Puede recuperar objetos borrados** | Sí (si retention lo permite) | Sí (si backup existe) |
| **Uso principal** | Recovery rápido, reinstatement | Disaster recovery, long-term |

---

## 🔗 Flashback Database en Data Guard

### Rol en el Ciclo de Vida de Data Guard

Flashback Database habilita dos escenarios críticos en Data Guard:

#### Escenario 1: Failover y Reinstatement

```
Estado Inicial:
┌────────────┐  Replicación  ┌────────────┐
│  PRIMARY   │──────────────►│  STANDBY   │
│   (cdb1)   │  Archive Logs │ (cdb1_stby)│
└────────────┘               └────────────┘

1. Primary Falla:
┌────────────┐               ┌────────────┐
│  PRIMARY   │               │  STANDBY   │
│   (cdb1)   │     X         │ (cdb1_stby)│
│   [CAÍDO]  │               │  (Activo)  │
└────────────┘               └────────────┘

2. Failover (Standby se convierte en Primary):
┌────────────┐               ┌────────────┐
│ Antiguo    │               │   NUEVO    │
│  PRIMARY   │               │  PRIMARY   │
│  (cdb1)    │               │(cdb1_stby) │
│  [CAÍDO]   │               │ SCN: 5000  │
└────────────┘               └────────────┘
                             (Divergencia en SCN 4800)

3. Antiguo Primary se recupera:
┌────────────┐               ┌────────────┐
│ Antiguo    │               │   NUEVO    │
│  PRIMARY   │               │  PRIMARY   │
│  (cdb1)    │               │(cdb1_stby) │
│ SCN: 4800  │               │ SCN: 5200  │
│ (Divergente│               │            │
└────────────┘               └────────────┘

4. Flashback del antiguo Primary al SCN de divergencia:
FLASHBACK DATABASE TO SCN 4800;
┌────────────┐               ┌────────────┐
│   NUEVO    │ Replicación   │  PRIMARY   │
│  STANDBY   │◄──────────────│(cdb1_stby) │
│  (cdb1)    │ Archive Logs  │ SCN: 5200  │
│ SCN: 4800  │               │            │
└────────────┘               └────────────┘

Resultado: Alta disponibilidad restaurada en 5 minutos
```

**Sin Flashback Database:**
- Tendríamos que **recrear** el antiguo primary como standby usando RMAN DUPLICATE
- Tiempo: 20-30 minutos
- Proceso documentado en `57-rman-duplicate.md`

#### Escenario 2: Switchover Fallido

```
1. Inicio de switchover planificado:
PRIMARY (cdb1) ──switch──> STANDBY (cdb1_stby)

2. Switchover falla a mitad del proceso (error de red, timeout, etc.)
   Resultado: Ambas bases de datos pueden quedar en estado inconsistente

3. Solución con Flashback:
   - Flashback del primary al SCN antes del switchover
   - Flashback del standby al mismo SCN
   - Reintentar switchover o mantener configuración original
```

### Configuración de Flashback en Nuestro Proyecto

En el archivo `37-create-database.md`, Flashback se habilita en el **primary**:

```sql
-- Paso 1: Habilitar Flashback Database
ALTER DATABASE FLASHBACK ON;

-- Paso 2: Configurar retention target (24 horas)
ALTER SYSTEM SET db_flashback_retention_target=1440 SCOPE=BOTH;

-- Paso 3: Verificar
SELECT flashback_on FROM v$database;
-- Resultado esperado: YES
```

En el archivo `57-rman-duplicate.md`, Flashback se habilita en el **standby** después de RMAN DUPLICATE:

```sql
-- En el standby, después de crear la database física
ALTER DATABASE FLASHBACK ON;

-- Verificar
SELECT flashback_on FROM v$database;
-- Resultado esperado: YES
```

**⚠️ Importante:** Flashback Database **debe** estar habilitado en **ambas** bases de datos (primary y standby) para permitir reinstatement en ambas direcciones.

---

## ⚙️ Configuración de Flashback Database

### Requisitos Previos

1. **Fast Recovery Area (FRA) configurada**

```sql
-- Verificar FRA
SELECT name, value FROM v$parameter WHERE name LIKE 'db_recovery%';

-- Resultado esperado:
-- db_recovery_file_dest      = /u01/app/oracle/fast_recovery_area
-- db_recovery_file_dest_size = 10737418240  (10 GB)
```

2. **Modo ARCHIVELOG habilitado**

```sql
SELECT log_mode FROM v$database;
-- Debe decir: ARCHIVELOG
```

3. **Espacio suficiente en FRA**

```sql
SELECT * FROM v$recovery_file_dest;

-- Verificar:
-- - space_limit: tamaño total de FRA
-- - space_used: espacio usado actualmente
-- - Debe haber al menos 20-30% libre para flashback logs
```

### Habilitación Paso a Paso

#### En el Primary (durante creación - script 37)

```bash
#!/bin/bash
# /vagrant/2-Standby/scripts/primary/create_database.sh

# ... [creación de database con dbca] ...

sqlplus / as sysdba <<EOF
-- 1. Habilitar Flashback Database
ALTER DATABASE FLASHBACK ON;

-- 2. Configurar retention target
ALTER SYSTEM SET db_flashback_retention_target=1440 SCOPE=BOTH;

-- 3. Verificar
SELECT flashback_on, log_mode FROM v\$database;

-- Salida esperada:
-- FLASHBACK_ON | LOG_MODE
-- YES          | ARCHIVELOG

EXIT;
EOF
```

#### En el Standby (después de RMAN DUPLICATE - script 57)

```bash
#!/bin/bash
# /vagrant/2-Standby/scripts/standby/rman_duplicate.sh

# ... [después de RMAN DUPLICATE] ...

sqlplus / as sysdba <<EOF
-- El standby ya tiene flashback habilitado (copiado del primary)
-- Pero verificamos y configuramos si es necesario

-- Verificar
SELECT flashback_on FROM v\$database;

-- Si dice NO, habilitar:
ALTER DATABASE FLASHBACK ON;

EXIT;
EOF
```

### Parámetros de Configuración

```sql
-- 1. Retention target (minutos que puedes retroceder)
ALTER SYSTEM SET db_flashback_retention_target=1440 SCOPE=BOTH;
-- 1440 = 24 horas
-- Rango típico: 60-4320 (1 hora a 3 días)

-- 2. Tamaño de FRA (debe acomodar flashback logs)
ALTER SYSTEM SET db_recovery_file_dest_size=10G SCOPE=BOTH;

-- 3. Ubicación de FRA
ALTER SYSTEM SET db_recovery_file_dest='/u01/app/oracle/fast_recovery_area' SCOPE=BOTH;
```

**Cálculo de espacio para Flashback Logs:**

```
Espacio estimado = (Tasa de cambio de bloques por hora) * (Retention target en horas)

Ejemplo:
- Sistema con 500 MB/hora de cambios de bloques
- Retention target = 24 horas
- Espacio necesario = 500 MB * 24 = 12 GB

Recomendación: FRA debe ser 2-3x el espacio de flashback logs estimado
```

---

## 🎬 Operaciones con Flashback Database

### Operación 1: Flashback a Timestamp

**Caso de uso:** Retroceder a un momento específico (ej. antes de un error)

```sql
-- Paso 1: Shutdown y mount
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;

-- Paso 2: Flashback a timestamp específico
FLASHBACK DATABASE TO TIMESTAMP TO_TIMESTAMP('2025-11-04 14:25:00', 'YYYY-MM-DD HH24:MI:SS');

-- Paso 3: Abrir con RESETLOGS (crea nueva incarnation)
ALTER DATABASE OPEN RESETLOGS;

-- Verificar SCN actual
SELECT current_scn FROM v$database;
```

### Operación 2: Flashback a SCN

**Caso de uso:** Reinstatement después de failover (Data Guard)

```sql
-- Obtener SCN de divergencia (del DBA que hizo failover o de logs)
-- Supongamos SCN = 4825000

-- Paso 1: Shutdown y mount
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;

-- Paso 2: Flashback al SCN específico
FLASHBACK DATABASE TO SCN 4825000;

-- Paso 3: Abrir con RESETLOGS
ALTER DATABASE OPEN RESETLOGS;
```

### Operación 3: Flashback a Restore Point

**Caso de uso:** Retroceder a un punto de restauración nombrado

```sql
-- Primero, crear restore point (antes de cambio riesgoso)
CREATE RESTORE POINT before_upgrade GUARANTEE FLASHBACK DATABASE;

-- ... realizar cambio (upgrade, migration, etc.) ...

-- Si algo falla, flashback al restore point:
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
FLASHBACK DATABASE TO RESTORE POINT before_upgrade;
ALTER DATABASE OPEN RESETLOGS;

-- Limpiar restore point
DROP RESTORE POINT before_upgrade;
```

### Operación 4: Reinstatement de Standby después de Failover

**Escenario completo:**

```sql
-- SITUACIÓN:
-- - Primary original (cdb1) falló
-- - Hicimos failover a standby (cdb1_stby)
-- - Ahora cdb1_stby es el nuevo PRIMARY
-- - Queremos reinstaurar cdb1 como nuevo STANDBY

-- EN EL ANTIGUO PRIMARY (cdb1) que ahora será STANDBY:

-- 1. Obtener SCN de divergencia del nuevo primary
-- Ejecutar en el NUEVO PRIMARY (cdb1_stby):
SELECT to_char(standby_became_primary_scn) FROM v$database;
-- Resultado: 4827500

-- 2. En el ANTIGUO PRIMARY (cdb1):
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;

-- 3. Flashback al SCN de divergencia
FLASHBACK DATABASE TO SCN 4827500;

-- 4. Convertir a standby
ALTER DATABASE CONVERT TO PHYSICAL STANDBY;

-- 5. Shutdown y mount como standby
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;

-- 6. Iniciar recuperación
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT FROM SESSION;

-- 7. Verificar que está sincronizando
SELECT process, status, thread#, sequence#, block#, blocks
FROM v$managed_standby
WHERE process = 'MRP0';

-- Resultado esperado:
-- PROCESS | STATUS  | THREAD# | SEQUENCE# | ...
-- MRP0    | APPLYING| 1       | 1523      | ...
```

---

## 📊 Monitoreo y Gestión

### Verificar Estado de Flashback Database

```sql
-- 1. Verificar si está habilitado
SELECT flashback_on, oldest_flashback_scn, oldest_flashback_time
FROM v$database;

-- Resultado esperado:
-- FLASHBACK_ON | OLDEST_FLASHBACK_SCN | OLDEST_FLASHBACK_TIME
-- YES          | 4750000              | 03-NOV-25 14:30:15

-- 2. Ver retention target configurado
SELECT name, value FROM v$parameter WHERE name = 'db_flashback_retention_target';

-- Resultado:
-- NAME                             | VALUE
-- db_flashback_retention_target    | 1440  (minutos)

-- 3. Verificar proceso RVWR
SELECT program, spid FROM v$process WHERE program LIKE '%RVWR%';

-- Resultado:
-- PROGRAM              | SPID
-- oracle@ol8-21 (RVWR) | 5432
```

### Verificar Flashback Logs

```sql
-- 1. Ver espacio usado por flashback logs
SELECT * FROM v$flashback_database_log;

-- Columnas clave:
-- - oldest_flashback_scn: SCN más antiguo al que puedes retroceder
-- - oldest_flashback_time: Timestamp más antiguo
-- - retention_target: Retention configurado (minutos)
-- - flashback_size: Espacio usado por flashback logs (bytes)
-- - estimated_flashback_size: Espacio estimado necesario

-- 2. Ver flashback logs en disco
SELECT * FROM v$recovery_file_dest;

-- Columnas:
-- - space_limit: Tamaño total de FRA
-- - space_used: Espacio usado (incluye flashback logs + archive logs + backups)
-- - space_reclaimable: Espacio que puede ser recuperado
-- - number_of_files: Número total de archivos en FRA
```

### Consultas de Diagnóstico

```sql
-- 1. Verificar cuánto tiempo atrás puedes retroceder
SELECT oldest_flashback_time,
       ROUND((SYSDATE - oldest_flashback_time) * 24 * 60, 2) AS minutes_available,
       (SELECT value FROM v$parameter WHERE name = 'db_flashback_retention_target') AS retention_target
FROM v$database;

-- Resultado:
-- OLDEST_FLASHBACK_TIME | MINUTES_AVAILABLE | RETENTION_TARGET
-- 03-NOV-25 10:30:15    | 1425.50           | 1440
-- (Puedes retroceder ~23.75 horas, target es 24 horas - casi completo)

-- 2. Ver tasa de generación de flashback logs
SELECT to_char(begin_time, 'YYYY-MM-DD HH24:MI') AS period,
       flashback_data AS flashback_mb
FROM v$flashback_database_stat
WHERE begin_time > SYSDATE - 1
ORDER BY begin_time DESC;

-- Resultado:
-- PERIOD          | FLASHBACK_MB
-- 2025-11-04 10:00| 234
-- 2025-11-04 09:00| 189
-- 2025-11-04 08:00| 156
-- (MB de flashback data generados por hora)

-- 3. Ver espacio de FRA desglosado por tipo
SELECT file_type,
       ROUND(percent_space_used, 2) AS pct_used,
       ROUND(percent_space_reclaimable, 2) AS pct_reclaimable,
       number_of_files
FROM v$recovery_area_usage
WHERE percent_space_used > 0;

-- Resultado:
-- FILE_TYPE       | PCT_USED | PCT_RECLAIMABLE | NUMBER_OF_FILES
-- FLASHBACK LOG   | 15.23    | 2.10            | 8
-- ARCHIVED LOG    | 45.67    | 30.20           | 156
-- CONTROL FILE    | 0.05     | 0.00            | 2
-- BACKUP PIECE    | 25.50    | 10.00           | 12
```

---

## 🎯 Casos de Uso Prácticos

### Caso 1: Recuperación de Error de Aplicación

**Escenario:**
```
10:00 AM - Base de datos funcionando normalmente
14:30 PM - Usuario ejecuta: UPDATE hc_user SET usr_status = 'I';
           (Olvidó el WHERE - deshabilitó TODOS los usuarios)
14:32 PM - Usuarios reportan que no pueden iniciar sesión
14:35 PM - DBA confirma el error
```

**Solución con Flashback Database:**

```sql
-- 1. Identificar el momento ANTES del error (14:25 para seguridad)
-- 2. Notificar a usuarios (sistema estará down 3-5 minutos)

-- 3. Ejecutar flashback
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;

FLASHBACK DATABASE TO TIMESTAMP TO_TIMESTAMP('2025-11-04 14:25:00', 'YYYY-MM-DD HH24:MI:SS');

ALTER DATABASE OPEN RESETLOGS;

-- 4. Verificar que usuarios están activos
SELECT COUNT(*) FROM hc_user WHERE usr_status = 'A';
-- Esperado: número original de usuarios activos

-- Total downtime: 5 minutos
-- Datos perdidos: Transacciones entre 14:25 y 14:32 (7 minutos)
```

**Alternativa sin Flashback:**
- Restaurar backup de la noche anterior (15-30 minutos)
- Aplicar archive logs hasta 14:25 (10-20 minutos)
- Total downtime: 25-50 minutos

### Caso 2: Reinstatement después de Failover

**Escenario:**
```
12:00 PM - Primary (cdb1) tiene problema de hardware (disco falla)
12:05 PM - DBA ejecuta failover a standby (cdb1_stby)
12:10 PM - cdb1_stby ahora es PRIMARY, aplicación funciona
15:00 PM - Hardware reparado, cdb1 vuelve online
15:05 PM - Necesitamos reinstaurar cdb1 como STANDBY del nuevo primary
```

**Solución con Flashback Database:**

```sql
-- EN EL NUEVO PRIMARY (cdb1_stby):
SELECT to_char(standby_became_primary_scn) FROM v$database;
-- Resultado: 5234000 (SCN cuando se convirtió en primary)

-- EN EL ANTIGUO PRIMARY (cdb1):
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;

-- Flashback al SCN de failover
FLASHBACK DATABASE TO SCN 5234000;

-- Convertir a standby
ALTER DATABASE CONVERT TO PHYSICAL STANDBY;
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;

-- Iniciar replicación
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT FROM SESSION;

-- Verificar replicación
SELECT process, status FROM v$managed_standby WHERE process = 'MRP0';
-- PROCESS | STATUS
-- MRP0    | APPLYING

-- Total tiempo de reinstatement: 3-5 minutos
```

**Sin Flashback Database:**
- Recrear standby con RMAN DUPLICATE (script 57-rman-duplicate.md)
- Total tiempo: 20-30 minutos

### Caso 3: Testing de Upgrade

**Escenario:**
- Vas a actualizar aplicación de v2.0 a v3.0
- Quieres poder retroceder rápidamente si falla

**Solución con Flashback Database:**

```sql
-- 1. Crear restore point garantizado ANTES del upgrade
CREATE RESTORE POINT before_app_upgrade GUARANTEE FLASHBACK DATABASE;

-- Verificar
SELECT name, scn, time, guarantee_flashback_database
FROM v$restore_point
WHERE name = 'BEFORE_APP_UPGRADE';

-- 2. Realizar upgrade de aplicación
@upgrade_schema_v3.sql

-- 3A. Si upgrade es exitoso:
-- Eliminar restore point después de validar (ej. 2 días)
DROP RESTORE POINT before_app_upgrade;

-- 3B. Si upgrade falla:
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
FLASHBACK DATABASE TO RESTORE POINT before_app_upgrade;
ALTER DATABASE OPEN RESETLOGS;

-- Sistema retrocedido a v2.0 en 3-5 minutos
```

---

## 🔧 Troubleshooting

### Problema 1: No puedo habilitar Flashback Database

**Error:**
```sql
ALTER DATABASE FLASHBACK ON;

-- ORA-38706: Cannot turn on FLASHBACK DATABASE logging.
-- ORA-38707: Media recovery is not enabled.
```

**Causa:** Database no está en modo ARCHIVELOG

**Solución:**
```sql
-- Verificar modo
SELECT log_mode FROM v$database;

-- Si dice NOARCHIVELOG:
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;

-- Ahora habilitar flashback
ALTER DATABASE FLASHBACK ON;
```

### Problema 2: Flashback falla con ORA-38729

**Error:**
```sql
FLASHBACK DATABASE TO TIMESTAMP TO_TIMESTAMP('2025-11-01 10:00:00', 'YYYY-MM-DD HH24:MI:SS');

-- ORA-38729: Not enough flashback database log data to do FLASHBACK.
```

**Causa:** El timestamp solicitado es anterior al oldest_flashback_time disponible

**Diagnóstico:**
```sql
SELECT oldest_flashback_time FROM v$database;
-- Resultado: 03-NOV-25 14:30:15
-- (Solo puedes retroceder hasta Nov 3 14:30, no hasta Nov 1)
```

**Solución:**
- Retroceder a un timestamp dentro del retention window, O
- Usar RMAN restore/recover para ir más atrás en el tiempo

### Problema 3: FRA se llena con Flashback Logs

**Síntomas:**
```sql
SELECT * FROM v$recovery_file_dest;

-- SPACE_USED = 10,500 MB (FRA de 10 GB = 105% lleno)

-- Alert log muestra:
-- ORA-19815: WARNING: db_recovery_file_dest_size of 10737418240 bytes is 100.00% used
```

**Diagnóstico:**
```sql
SELECT file_type, percent_space_used
FROM v$recovery_area_usage
WHERE percent_space_used > 0;

-- FLASHBACK LOG | 60.00  (flashback logs usando 60% de FRA)
-- ARCHIVED LOG  | 35.00
-- BACKUP PIECE  | 5.00
```

**Soluciones:**

**Opción 1: Aumentar tamaño de FRA**
```sql
ALTER SYSTEM SET db_recovery_file_dest_size=20G SCOPE=BOTH;
```

**Opción 2: Reducir retention target**
```sql
-- Reducir de 24 horas a 12 horas
ALTER SYSTEM SET db_flashback_retention_target=720 SCOPE=BOTH;

-- Oracle automáticamente reciclará flashback logs antiguos
```

**Opción 3: Limpiar archive logs antiguos (libera espacio en FRA)**
```sql
RMAN> DELETE NOPROMPT ARCHIVELOG ALL COMPLETED BEFORE 'SYSDATE-3';
```

### Problema 4: Proceso RVWR no está corriendo

**Síntomas:**
```sql
SELECT flashback_on FROM v$database;
-- YES

SELECT * FROM v$process WHERE program LIKE '%RVWR%';
-- No rows returned (debería haber un proceso RVWR)
```

**Causa:** Flashback Database configurado pero proceso no inició (raro)

**Solución:**
```sql
-- Deshabilitar y re-habilitar flashback
ALTER DATABASE FLASHBACK OFF;
ALTER DATABASE FLASHBACK ON;

-- Verificar RVWR
SELECT program FROM v$process WHERE program LIKE '%RVWR%';
-- Debería mostrar: oracle@hostname (RVWR)
```

---

## 📝 Conclusiones

### Puntos Clave sobre Flashback Database

1. **Velocidad:** Flashback Database es **10x más rápido** que restore/recover tradicional (5 min vs 50 min).

2. **Requisito para Data Guard:** En un entorno Data Guard moderno, Flashback Database es **esencial** para reinstatement rápido.

3. **No es un Backup:** Flashback Database **complementa** los backups, no los reemplaza. Aún necesitas backups RMAN.

4. **Ventana de Retención:** Solo puedes retroceder dentro del retention target (ej. 24 horas). Para ir más atrás, necesitas RMAN.

5. **Costo de Espacio:** Flashback logs consumen 10-30% de FRA dependiendo de la carga de trabajo.

### Configuración en Nuestro Proyecto

| Componente | Configuración |
|------------|---------------|
| **Habilitado** | Sí (primary y standby) |
| **Retention target** | 1440 minutos (24 horas) |
| **FRA size** | 10 GB |
| **Uso típico de flashback logs** | 1-2 GB (10-20% de FRA) |
| **Oldest flashback time** | Típicamente 20-24 horas atrás |
| **Proceso RVWR** | Activo en ambas databases |

### Relación con Otros Componentes

- **Data Guard Broker** (85-data-guard-broker.md): Broker automatiza el uso de flashback en failover/switchover
- **Archive Logs** (83-archive-logs.md): Flashback necesita archive logs para aplicar cambios después del flashback
- **RMAN Backups** (87-rman-backups.md): Flashback complementa backups, no los reemplaza

### Comandos Rápidos de Referencia

```sql
-- Habilitar Flashback Database
ALTER DATABASE FLASHBACK ON;

-- Verificar estado
SELECT flashback_on, oldest_flashback_scn, oldest_flashback_time FROM v$database;

-- Flashback a timestamp
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
FLASHBACK DATABASE TO TIMESTAMP TO_TIMESTAMP('2025-11-04 10:00:00', 'YYYY-MM-DD HH24:MI:SS');
ALTER DATABASE OPEN RESETLOGS;

-- Flashback a SCN (para reinstatement)
FLASHBACK DATABASE TO SCN 4827500;

-- Crear restore point garantizado
CREATE RESTORE POINT my_point GUARANTEE FLASHBACK DATABASE;

-- Flashback a restore point
FLASHBACK DATABASE TO RESTORE POINT my_point;

-- Ver espacio de flashback logs
SELECT * FROM v$flashback_database_log;

-- Ver tasa de generación
SELECT * FROM v$flashback_database_stat WHERE begin_time > SYSDATE - 1;
```

---

**Siguiente:** [85-data-guard-broker.md](85-data-guard-broker.md) - Data Guard Broker para Gestión Centralizada
**Anterior:** [83-archive-logs.md](83-archive-logs.md) - Archive Logs y Replicación
**Inicio:** [00-tabla-contenidos.md](../00-tabla-contenidos.md)
