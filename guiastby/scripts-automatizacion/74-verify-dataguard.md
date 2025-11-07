# 74 - Verify Data Guard

## Script de Verificación Completa de Configuración Data Guard

Este es el script de verificación MÁS COMPLETO del sistema. Ejecuta 11 secciones de verificación que cubren todos los aspectos críticos de la configuración Data Guard, desde el estado de las bases de datos hasta el esquema personalizado de healthcare en el PDB.

## Ubicación

`2-Standby/automation/verify_dataguard.sh`

## Propósito

Proporcionar un reporte integral del estado del sistema Data Guard que incluye:
- Estado de primary y standby databases
- Configuración de destinos de archivado
- Standby redo logs
- Historial de log switches
- Estado de aplicación en standby
- Métricas de lag (transport lag y apply lag)
- Detección de gaps en archive logs
- Configuración del Data Guard Broker
- Verificación del esquema personalizado (HEALTHCENTER)

Este script cumple el requisito: "Generación de reporte a petición del profesor"

## Cuándo se Ejecuta

- **Frecuencia:** Manual (bajo demanda)
- **Nodo:** Primary
- **Usuario:** oracle
- **Installed by:** N/A (no es cron job)

## Uso Manual

```bash
# Como usuario oracle en primary
/home/oracle/automation/verify_dataguard.sh

# Guardar output en archivo
/home/oracle/automation/verify_dataguard.sh > /tmp/dataguard_report_$(date +%Y%m%d).txt

# Ver solo secciones específicas
/home/oracle/automation/verify_dataguard.sh | grep -A 20 "PRIMARY DATABASE STATUS"
```

## Variables de Entorno

Desde `config/install.env`:

```bash
# Nodos Data Guard
NODE1_DB_UNIQUE_NAME=cdb1                # Nombre único del primary
NODE2_DB_UNIQUE_NAME=cdb1_stby          # Nombre único del standby
DB_DOMAIN=world                          # Dominio de base de datos

# Credenciales
SYS_PASSWORD=S1sPassword1!               # Password del usuario SYS

# PDB
PDB_NAME=pdb1                            # Nombre del pluggable database

# Oracle
ORACLE_SID=cdb1
ORACLE_HOME=/u01/app/oracle/product/21.0.0/dbhome_1
```

## Qué Hace el Script (Paso a Paso)

### Sección 1: Primary Database Status

```bash
echo "=== PRIMARY DATABASE STATUS ==="
sqlplus -s / as sysdba <<EOF
SET LINESIZE 150
COL name FORMAT A10
COL db_unique_name FORMAT A15
COL database_role FORMAT A16
COL open_mode FORMAT A12
COL protection_mode FORMAT A20
COL protection_level FORMAT A20

SELECT name, db_unique_name, database_role, open_mode, log_mode,
       force_logging, flashback_on, protection_mode, protection_level
FROM v\$database;
EOF
```

**Explicación:**

Esta sección muestra el estado fundamental del primary database.

**Columnas importantes:**

#### name
- Nombre de la base de datos (CDB1)
- Debe coincidir con DB_NAME en ambos nodos

#### db_unique_name
- Nombre único que distingue primary de standby
- Primary: cdb1
- Standby: cdb1_stby

#### database_role
- PRIMARY = nodo primario activo
- PHYSICAL STANDBY = nodo standby
- Confirma que estamos conectados al primary

#### open_mode
- READ WRITE = primary aceptando transacciones
- READ ONLY = standby en modo lectura (si Active Data Guard)
- MOUNTED = standby en recuperación

#### log_mode
- ARCHIVELOG = modo requerido para Data Guard
- NOARCHIVELOG = NO compatible con Data Guard

#### force_logging
- YES = fuerza logging de todos los cambios (requerido para Data Guard)
- NO = algunos cambios podrían no replicarse

#### flashback_on
- YES = Flashback Database habilitado
- Permite retroceder en el tiempo sin restore de backup

#### protection_mode
- MAXAVAILABILITY = sin pérdida de datos, permite operación si standby falla temporalmente
- MAXPROTECTION = sin pérdida de datos, NO permite operación si standby falla
- MAXPERFORMANCE = mejor rendimiento, puede perder datos

#### protection_level
- Nivel actual de protección
- Puede diferir de protection_mode si standby está caído

**Salida esperada:**
```
NAME   DB_UNIQUE_NAME DATABASE_ROLE    OPEN_MODE    LOG_MODE     FORCE_LOGGING FLASHBACK_ON PROTECTION_MODE     PROTECTION_LEVEL
------ -------------- ---------------- ------------ ------------ ------------- ------------ ------------------- ------------------
CDB1   CDB1           PRIMARY          READ WRITE   ARCHIVELOG   YES           YES          MAXAVAILABILITY     MAXAVAILABILITY
```

### Sección 2: Archive Destinations

```bash
echo "=== ARCHIVE DESTINATIONS ==="
sqlplus -s / as sysdba <<EOF
SET LINESIZE 200
COL dest_name FORMAT A15
COL status FORMAT A10
COL destination FORMAT A40
COL error FORMAT A30

SELECT dest_name, status, destination, error
FROM v\$archive_dest
WHERE status != 'INACTIVE'
ORDER BY dest_id;
EOF
```

**Explicación:**

Muestra configuración de destinos de archivado (dónde se envían archive logs).

**Destinos típicos:**

#### LOG_ARCHIVE_DEST_1 (Local)
- **Destino:** Local Fast Recovery Area
- **Status:** VALID
- **Destination:** `/u01/app/oracle/fast_recovery_area`
- **Propósito:** Almacenamiento local de archives

#### LOG_ARCHIVE_DEST_2 (Remote)
- **Destino:** Standby database
- **Status:** VALID
- **Destination:** `SERVICE=cdb1_stby.world ASYNC VALID_FOR=(...)`
- **Propósito:** Replicación a standby

**Status posibles:**
- **VALID:** Funcionando correctamente
- **ERROR:** Problema en destino (revisar columna ERROR)
- **DEFERRED:** Temporalmente deshabilitado
- **INACTIVE:** No configurado

**Salida esperada:**
```
DEST_NAME       STATUS     DESTINATION                              ERROR
--------------- ---------- ---------------------------------------- --------------
LOG_ARCHIVE_... VALID      /u01/app/oracle/fast_recovery_area
LOG_ARCHIVE_... VALID      SERVICE=cdb1_stby.world ASYNC VALID_...
```

**Señales de problemas:**
```
DEST_NAME       STATUS     DESTINATION                              ERROR
--------------- ---------- ---------------------------------------- ------------------------------
LOG_ARCHIVE_... ERROR      SERVICE=cdb1_stby.world ...              ORA-16191: Primary log shipping
                                                                    client not logged on standby
```

### Sección 3: Standby Redo Logs

```bash
echo "=== STANDBY REDO LOGS ==="
sqlplus -s / as sysdba <<EOF
COL member FORMAT A50
SELECT l.group#, l.thread#, l.sequence#, l.bytes/1024/1024 AS size_mb,
       l.archived, l.status, f.member
FROM v\$standby_log l, v\$logfile f
WHERE l.group# = f.group#
ORDER BY l.group#;
EOF
```

**Explicación:**

Standby Redo Logs (SRLs) son redo logs especiales usados para replicación en tiempo real.

**¿Qué son SRLs?**
- Logs en el PRIMARY que reciben cambios antes de escribirse a archive logs
- Permiten FASTSYNC (replicación síncrona sin esperar archivado)
- Mejoran rendimiento de replicación

**Configuración requerida:**
- **Cantidad:** Al menos (número de redo log groups + 1)
- **Tamaño:** Mismo tamaño que redo logs online
- En nuestro caso: 4 SRLs de 50MB cada uno

**Columnas importantes:**

#### group#
- Número de grupo del SRL (4, 5, 6, 7 típicamente)
- No se sobrepone con online redo logs (1, 2, 3)

#### sequence#
- Secuencia actual escrita en este SRL
- 0 = no ha sido usado aún

#### size_mb
- Tamaño en MB (debe ser ≥ tamaño de redo logs)
- Nuestro caso: 50MB

#### archived
- YES = contenido fue archivado
- NO = aún no archivado

#### status
- UNASSIGNED = disponible para uso
- ACTIVE = en uso actual
- CURRENT = recibiendo escrituras ahora

**Salida esperada:**
```
GROUP# THREAD# SEQUENCE# SIZE_MB ARCHIVED STATUS      MEMBER
------ ------- --------- ------- -------- ----------- --------------------------------------------------
     4       1         0      50 YES      UNASSIGNED  /u01/oradata/cdb1/standby_redo01.log
     5       1         0      50 YES      UNASSIGNED  /u01/oradata/cdb1/standby_redo02.log
     6       1         0      50 YES      UNASSIGNED  /u01/oradata/cdb1/standby_redo03.log
     7       1         0      50 YES      UNASSIGNED  /u01/oradata/cdb1/standby_redo04.log
```

### Sección 4: Archive Lag Configuration

```bash
echo "=== ARCHIVE LAG TARGET ==="
sqlplus -s / as sysdba <<EOF
SHOW PARAMETER ARCHIVE_LAG_TARGET;
EOF
```

**Explicación:**

ARCHIVE_LAG_TARGET controla cada cuánto se fuerza un log switch (archivado).

**Configuración:**
- **Valor:** 300 segundos (5 minutos)
- **Propósito:** Garantizar RPO máximo de 5 minutos
- **Funcionamiento:** Si pasan 5 minutos sin log switch, Oracle fuerza uno

**¿Por qué 5 minutos?**
- Balance entre RPO y overhead
- RPO = Recovery Point Objective (cuántos datos se pueden perder)
- Con 5 min, máximo se pierden 5 minutos de transacciones

**Salida esperada:**
```
NAME                      TYPE        VALUE
------------------------- ----------- -----
archive_lag_target        integer     300
```

### Sección 5: Log Switch History

```bash
echo "=== RECENT LOG SWITCHES ==="
sqlplus -s / as sysdba <<EOF
SELECT sequence#, first_time, next_time,
       ROUND((next_time - first_time) * 24 * 60, 2) AS minutes_to_fill
FROM v\$log_history
WHERE first_time > SYSDATE - 1
ORDER BY sequence# DESC
FETCH FIRST 10 ROWS ONLY;
EOF
```

**Explicación:**

Muestra los últimos 10 log switches (últimas 24 horas).

**¿Qué se puede aprender?**

#### Frecuencia de switches
- Si minutes_to_fill es consistentemente ~5 min → ARCHIVE_LAG_TARGET forzando switches
- Si varía mucho (1 min, 3 min, 8 min) → actividad transaccional variable

#### Actividad del sistema
- Muchos switches (cada 1-2 min) → sistema muy activo
- Pocos switches (cada 10+ min) → sistema poco activo

#### Funcionamiento de lag target
- Si ves switches exactamente cada 5 min → lag target trabajando
- Si switches son mucho más frecuentes → redo logs se llenan rápido (alta actividad)

**Salida esperada:**
```
SEQUENCE# FIRST_TIME          NEXT_TIME           MINUTES_TO_FILL
--------- ------------------- ------------------- ---------------
      260 04-NOV-25 14:30:00  04-NOV-25 14:35:00             5.00
      259 04-NOV-25 14:25:00  04-NOV-25 14:30:00             5.00
      258 04-NOV-25 14:20:00  04-NOV-25 14:25:00             5.00
      257 04-NOV-25 14:15:00  04-NOV-25 14:20:00             5.00
      256 04-NOV-25 14:10:00  04-NOV-25 14:15:00             5.00
      255 04-NOV-25 14:05:00  04-NOV-25 14:10:00             5.00
      254 04-NOV-25 14:00:00  04-NOV-25 14:05:00             5.00
      253 04-NOV-25 13:55:00  04-NOV-25 14:00:00             5.00
      252 04-NOV-25 13:50:00  04-NOV-25 13:55:00             5.00
      251 04-NOV-25 13:45:00  04-NOV-25 13:50:00             5.00
```

**Interpretación:** Switches perfectamente cada 5 minutos = ARCHIVE_LAG_TARGET funcionando

### Sección 6: Standby Database Status

```bash
echo "=== STANDBY DATABASE STATUS ==="
sqlplus -s sys/${SYS_PASSWORD}@${NODE2_DB_UNIQUE_NAME}${DB_DOMAIN_STR} as sysdba <<EOF
SET LINESIZE 150
SELECT name, db_unique_name, database_role, open_mode, log_mode
FROM v\$database;
EOF
```

**Explicación:**

Conecta remotamente al standby y consulta su estado.

**Diferencias vs Primary:**

| Campo | Primary | Standby |
|-------|---------|---------|
| name | CDB1 | CDB1 (mismo) |
| db_unique_name | cdb1 | cdb1_stby (diferente) |
| database_role | PRIMARY | PHYSICAL STANDBY |
| open_mode | READ WRITE | MOUNTED (o READ ONLY si Active DG) |
| log_mode | ARCHIVELOG | ARCHIVELOG |

**Salida esperada:**
```
NAME   DB_UNIQUE_NAME DATABASE_ROLE       OPEN_MODE     LOG_MODE
------ -------------- ------------------- ------------- ------------
CDB1   CDB1_STBY      PHYSICAL STANDBY    MOUNTED       ARCHIVELOG
```

**Modos de open_mode en standby:**
- **MOUNTED:** Modo normal para recuperación (MRP aplicando logs)
- **READ ONLY:** Active Data Guard (permite queries mientras aplica)
- **READ WRITE:** ERROR - standby NO debe estar en read-write

### Sección 7: Standby Apply Status

```bash
echo "=== STANDBY APPLY STATUS ==="
sqlplus -s sys/${SYS_PASSWORD}@${NODE2_DB_UNIQUE_NAME}${DB_DOMAIN_STR} as sysdba <<EOF
SELECT process, status, thread#, sequence#, block#, blocks
FROM v\$managed_standby
WHERE process LIKE 'MRP%' OR process LIKE 'RFS%' OR process LIKE 'LNS%';
EOF
```

**Explicación:**

Muestra procesos activos de Data Guard en el standby.

**Procesos clave:**

#### MRP (Managed Recovery Process)
- **Función:** Aplica archive logs al standby
- **Status esperado:** APPLYING (trabajando) o WAIT_FOR_LOG (esperando siguiente log)
- **sequence#:** Secuencia actual siendo aplicada
- **Múltiples MRP:** MRP0 es coordinador, MRP1-MRPn son workers paralelos

#### RFS (Remote File Server)
- **Función:** Recibe archive logs desde primary
- **Uno por cada conexión desde primary**
- **Status:** IDLE (esperando) o RECEIVING (recibiendo log)

#### LNS (Log Network Server)
- **Función:** (en primary) Envía logs al standby
- **No debería aparecer en standby**
- Si aparece, puede indicar configuración incorrecta

**Salida esperada (standby saludable):**
```
PROCESS STATUS       THREAD# SEQUENCE# BLOCK# BLOCKS
------- ------------ ------- --------- ------ ------
MRP0    APPLYING           1       260   1024   2048
RFS     IDLE               1       261      0      0
RFS     IDLE               1       261      0      0
```

**Interpretación:**
- MRP0 aplicando secuencia 260
- 2 procesos RFS listos para recibir (standby está "escuchando")
- Secuencia de RFS (261) es siguiente a la que MRP aplica (260) = normal

**Problemas comunes:**
```
PROCESS STATUS       THREAD# SEQUENCE# BLOCK# BLOCKS
------- ------------ ------- --------- ------ ------
(no rows)
```
**Problema:** MRP no está corriendo. Standby no está aplicando logs.

### Sección 8: Transport and Apply Lag

```bash
echo "=== TRANSPORT AND APPLY LAG ==="
sqlplus -s sys/${SYS_PASSWORD}@${NODE2_DB_UNIQUE_NAME}${DB_DOMAIN_STR} as sysdba <<EOF
COL name FORMAT A20
COL value FORMAT A20
COL unit FORMAT A15
COL time_computed FORMAT A20

SELECT name, value, unit, TO_CHAR(time_computed, 'YYYY-MM-DD HH24:MI:SS') AS time_computed
FROM v\$dataguard_stats
WHERE name IN ('transport lag', 'apply lag');
EOF
```

**Explicación:**

Métricas específicas de Data Guard sobre retrasos en replicación.

**Métricas:**

#### transport lag
- **Significado:** Tiempo entre generación de log en primary y recepción en standby
- **Ideal:** 0 segundos (o pocos segundos)
- **Formato:** +HH:MI:SS
- **Ejemplo:** +0 00:00:02 = 2 segundos de retraso

#### apply lag
- **Significado:** Tiempo entre generación de cambio en primary y aplicación en standby
- **Ideal:** < 1 minuto
- **Incluye:** transport lag + tiempo de aplicación
- **Ejemplo:** +0 00:02:30 = 2 minutos 30 segundos

**¿Qué es buen lag?**

| Lag Value | Estado | Acción |
|-----------|--------|--------|
| +0 00:00:00 - +0 00:01:00 | Excelente | Ninguna |
| +0 00:01:00 - +0 00:05:00 | Bueno | Monitorear |
| +0 00:05:00 - +0 00:15:00 | Aceptable | Investigar causa |
| +0 00:15:00+ | Problemático | Acción requerida |

**Salida esperada:**
```
NAME            VALUE          UNIT            TIME_COMPUTED
--------------- -------------- --------------- --------------------
transport lag   +0 00:00:03    seconds         2025-11-04 14:35:22
apply lag       +0 00:00:45    seconds         2025-11-04 14:35:22
```

**Interpretación:**
- Transport lag de 3 segundos = excelente
- Apply lag de 45 segundos = muy bueno
- Standby está ~45 segundos detrás de primary (aceptable)

### Sección 9: Archive Gap Check

```bash
echo "=== ARCHIVE GAP CHECK ==="
sqlplus -s sys/${SYS_PASSWORD}@${NODE2_DB_UNIQUE_NAME}${DB_DOMAIN_STR} as sysdba <<EOF
SELECT * FROM v\$archive_gap;
EOF

echo ""
echo "If no rows returned, there are NO GAPS (this is good)"
```

**Explicación:**

v$archive_gap solo tiene filas si hay GAPS (archives faltantes).

**¿Qué es un gap?**
- Secuencias de archive log que faltan en el standby
- Ejemplo: Standby tiene 100, 101, 103, 104 → GAP en 102
- Impide que MRP continúe (necesita 102 antes de aplicar 103)

**Causas de gaps:**
- Red caída temporalmente
- Primary no pudo enviar log
- Standby rechazó log (problemas de espacio)
- Archive log corrupto

**Salida ideal:**
```
no rows selected
```

**Salida con problema:**
```
THREAD# LOW_SEQUENCE# HIGH_SEQUENCE#
------- ------------- --------------
      1           102            102
```

**Interpretación:** Falta secuencia 102

**Cómo resolver gap:**
```bash
# En primary, copiar archive log faltante manualmente
scp /u01/app/oracle/fast_recovery_area/CDB1/archivelog/.../o1_mf_1_102_*.arc \
    oracle@ol8-21-dg2:/u01/app/oracle/fast_recovery_area/CDB1_STBY/archivelog/

# En standby, registrar el archive
sqlplus / as sysdba
ALTER DATABASE REGISTER PHYSICAL LOGFILE '/u01/.../o1_mf_1_102_*.arc';

# MRP automáticamente detectará y aplicará
```

### Sección 10: Data Guard Broker Configuration

```bash
echo "=== DATA GUARD BROKER CONFIGURATION ==="
dgmgrl -silent sys/${SYS_PASSWORD}@${NODE1_DB_UNIQUE_NAME}${DB_DOMAIN_STR} <<EOF
SHOW CONFIGURATION;
SHOW DATABASE ${NODE1_DB_UNIQUE_NAME};
SHOW DATABASE ${NODE2_DB_UNIQUE_NAME};
EXIT;
EOF
```

**Explicación:**

Data Guard Broker es la interfaz de gestión de Data Guard.

**¿Qué es dgmgrl?**
- Command-line interface para Data Guard Broker
- Permite configurar, monitorear, y operar Data Guard
- Alternativa a configuración manual vía SQL

**SHOW CONFIGURATION:**

Muestra configuración general del Data Guard setup.

**Salida esperada:**
```
Configuration - dg_config

  Protection Mode: MaxAvailability
  Members:
  cdb1      - Primary database
    cdb1_stby - Physical standby database

Fast-Start Failover:  Disabled

Configuration Status:
SUCCESS   (status updated 12 seconds ago)
```

**Campos importantes:**

#### Protection Mode
- MaxAvailability = nuestro modo configurado
- Confirma que se configuró correctamente

#### Members
- Lista de databases en configuración
- cdb1 debe ser Primary
- cdb1_stby debe ser Physical standby

#### Configuration Status
- **SUCCESS:** Todo funcionando
- **WARNING:** Problemas menores
- **ERROR:** Problemas críticos

**SHOW DATABASE cdb1 (primary):**

```
Database - cdb1

  Role:               PRIMARY
  Intended State:     TRANSPORT-ON
  Instance(s):
    cdb1

  Properties:
    DGConnectIdentifier             = 'cdb1.world'
    LogXptMode                      = 'ASYNC'
    LogArchiveTrace                 = '0'
    RedoRoutes                      = ''

Database Status:
SUCCESS
```

**Campos importantes:**

#### Role
- PRIMARY = rol actual del database
- Debe coincidir con v$database.database_role

#### Intended State
- TRANSPORT-ON = debe transportar logs
- TRANSPORT-OFF = no transportar (útil para mantenimiento)

#### LogXptMode
- ASYNC = asíncrono (replicación sin esperar confirmación)
- SYNC = síncrono (espera confirmación del standby)
- FASTSYNC = síncrono con Standby Redo Logs

**SHOW DATABASE cdb1_stby (standby):**

```
Database - cdb1_stby

  Role:               PHYSICAL STANDBY
  Intended State:     APPLY-ON
  Transport Lag:      0 seconds (computed 3 seconds ago)
  Apply Lag:          5 seconds (computed 3 seconds ago)
  Average Apply Rate: 12.00 KByte/s
  Real Time Query:    OFF
  Instance(s):
    cdb1

  Properties:
    DGConnectIdentifier             = 'cdb1_stby.world'
    LogXptMode                      = 'ASYNC'
    LogArchiveTrace                 = '0'
    RedoRoutes                      = ''

Database Status:
SUCCESS
```

**Campos importantes:**

#### Role
- PHYSICAL STANDBY = confirmación de rol

#### Intended State
- APPLY-ON = debe aplicar logs
- APPLY-OFF = no aplicar (útil para queries)

#### Transport Lag / Apply Lag
- Mismo significado que v$dataguard_stats
- Broker proporciona sus propias mediciones

#### Real Time Query
- ON = Active Data Guard (requiere licencia)
- OFF = standby mounted, solo recuperación

### Sección 11: Custom Schema Verification

```bash
echo "=== CUSTOM SCHEMA VERIFICATION (in PDB) ==="
sqlplus -s sys/${SYS_PASSWORD}@localhost:1521/${PDB_NAME} as sysdba <<EOF
SET LINESIZE 150
COL owner FORMAT A15
COL table_name FORMAT A30
SELECT owner, table_name, num_rows
FROM dba_tables
WHERE owner NOT IN ('SYS','SYSTEM','OUTLN','DBSNMP','APPQOSSYS',
                     'DBSFWUSER','GGSYS','ANONYMOUS','CTXSYS','DVSYS',
                     'DVF','GSMADMIN_INTERNAL','LBACSYS','MDSYS',
                     'OJVMSYS','OLAPSYS','ORDDATA','ORDSYS','WMSYS',
                     'XDB','AUDSYS','ORDPLUGINS','SI_INFORMTN_SCHEMA')
ORDER BY owner, table_name;
EOF
```

**Explicación:**

Verifica que el esquema personalizado (HEALTHCENTER) existe y contiene tablas.

**¿Por qué verificar PDB?**
- CDB solo contiene metadatos
- Aplicación real (healthcare system) vive en PDB (pdb1)
- Esquema HEALTHCENTER debe existir con sus tablas

**Conexión al PDB:**
```
sys/${SYS_PASSWORD}@localhost:1521/pdb1
```
- Conecta a pdb1 (no al CDB)
- Usa localhost (estamos en primary)
- Puerto 1521 (listener)

**Filtrado de esquemas:**
- Excluye todos los esquemas de Oracle internos
- Solo muestra esquemas de usuario (HEALTHCENTER en nuestro caso)

**Salida esperada:**
```
OWNER           TABLE_NAME                     NUM_ROWS
--------------- ------------------------------ --------
HEALTHCENTER    HC_HEALTHCENTER                       3
HEALTHCENTER    HC_LOGBOOK                           45
HEALTHCENTER    HC_MONTHSCALE                        12
HEALTHCENTER    HC_PAYROLL                          120
HEALTHCENTER    HC_PAYROLLMOVEMENT                 1580
HEALTHCENTER    HC_PAYROLLXUSER                     360
HEALTHCENTER    HC_POSITION                           8
HEALTHCENTER    HC_PROCEDURE                        235
HEALTHCENTER    HC_TURN                              24
HEALTHCENTER    HC_TURNXMONTHSCALE                  288
HEALTHCENTER    HC_USER                              45
```

**¿Por qué es importante?**
- Confirma que deploy_custom_schema.sh funcionó
- Verifica que esquema se replicó al standby (si se ejecuta en standby)
- Muestra que aplicación tiene datos

**Problemas posibles:**
```
no rows selected
```
**Causa:** Esquema no existe o PDB no está abierto

**Solución:**
```sql
-- Verificar estado del PDB
SHOW PDBS;

-- Si está MOUNTED, abrir
ALTER PLUGGABLE DATABASE pdb1 OPEN;

-- Re-ejecutar verificación
```

## Salida Completa Esperada

Cuando todo está funcionando correctamente, el script genera aproximadamente 150-200 líneas de output estructurado en 11 secciones claras. Aquí un ejemplo completo:

```
========================================================================
DATA GUARD CONFIGURATION VERIFICATION
========================================================================

=== PRIMARY DATABASE STATUS ===
NAME   DB_UNIQUE_NAME DATABASE_ROLE    OPEN_MODE    LOG_MODE     FORCE_LOGGING FLASHBACK_ON PROTECTION_MODE     PROTECTION_LEVEL
------ -------------- ---------------- ------------ ------------ ------------- ------------ ------------------- ------------------
CDB1   CDB1           PRIMARY          READ WRITE   ARCHIVELOG   YES           YES          MAXAVAILABILITY     MAXAVAILABILITY

=== ARCHIVE DESTINATIONS ===
DEST_NAME       STATUS     DESTINATION                              ERROR
--------------- ---------- ---------------------------------------- --------------
LOG_ARCHIVE_... VALID      /u01/app/oracle/fast_recovery_area
LOG_ARCHIVE_... VALID      SERVICE=cdb1_stby.world ASYNC VALID_...

=== STANDBY REDO LOGS ===
GROUP# THREAD# SEQUENCE# SIZE_MB ARCHIVED STATUS      MEMBER
------ ------- --------- ------- -------- ----------- --------------------------------------------------
     4       1         0      50 YES      UNASSIGNED  /u01/oradata/cdb1/standby_redo01.log
     5       1         0      50 YES      UNASSIGNED  /u01/oradata/cdb1/standby_redo02.log
     6       1         0      50 YES      UNASSIGNED  /u01/oradata/cdb1/standby_redo03.log
     7       1         0      50 YES      UNASSIGNED  /u01/oradata/cdb1/standby_redo04.log

=== ARCHIVE LAG TARGET ===
NAME                      TYPE        VALUE
------------------------- ----------- -----
archive_lag_target        integer     300

=== RECENT LOG SWITCHES ===
SEQUENCE# FIRST_TIME          NEXT_TIME           MINUTES_TO_FILL
--------- ------------------- ------------------- ---------------
      260 04-NOV-25 14:30:00  04-NOV-25 14:35:00             5.00
      259 04-NOV-25 14:25:00  04-NOV-25 14:30:00             5.00
      258 04-NOV-25 14:20:00  04-NOV-25 14:25:00             5.00
      257 04-NOV-25 14:15:00  04-NOV-25 14:20:00             5.00
      256 04-NOV-25 14:10:00  04-NOV-25 14:15:00             5.00
      255 04-NOV-25 14:05:00  04-NOV-25 14:10:00             5.00
      254 04-NOV-25 14:00:00  04-NOV-25 14:05:00             5.00
      253 04-NOV-25 13:55:00  04-NOV-25 14:00:00             5.00
      252 04-NOV-25 13:50:00  04-NOV-25 13:55:00             5.00
      251 04-NOV-25 13:45:00  04-NOV-25 13:50:00             5.00

=== STANDBY DATABASE STATUS ===
NAME   DB_UNIQUE_NAME DATABASE_ROLE       OPEN_MODE     LOG_MODE
------ -------------- ------------------- ------------- ------------
CDB1   CDB1_STBY      PHYSICAL STANDBY    MOUNTED       ARCHIVELOG

=== STANDBY APPLY STATUS ===
PROCESS STATUS       THREAD# SEQUENCE# BLOCK# BLOCKS
------- ------------ ------- --------- ------ ------
MRP0    APPLYING           1       260   1024   2048
RFS     IDLE               1       261      0      0
RFS     IDLE               1       261      0      0

=== TRANSPORT AND APPLY LAG ===
NAME            VALUE          UNIT            TIME_COMPUTED
--------------- -------------- --------------- --------------------
transport lag   +0 00:00:03    seconds         2025-11-04 14:35:22
apply lag       +0 00:00:45    seconds         2025-11-04 14:35:22

=== ARCHIVE GAP CHECK ===
no rows selected

If no rows returned, there are NO GAPS (this is good)

=== DATA GUARD BROKER CONFIGURATION ===
Configuration - dg_config

  Protection Mode: MaxAvailability
  Members:
  cdb1      - Primary database
    cdb1_stby - Physical standby database

Fast-Start Failover:  Disabled

Configuration Status:
SUCCESS   (status updated 12 seconds ago)

Database - cdb1

  Role:               PRIMARY
  Intended State:     TRANSPORT-ON
  Instance(s):
    cdb1

  Properties:
    DGConnectIdentifier             = 'cdb1.world'
    LogXptMode                      = 'ASYNC'

Database Status:
SUCCESS

Database - cdb1_stby

  Role:               PHYSICAL STANDBY
  Intended State:     APPLY-ON
  Transport Lag:      0 seconds (computed 3 seconds ago)
  Apply Lag:          5 seconds (computed 3 seconds ago)
  Average Apply Rate: 12.00 KByte/s
  Real Time Query:    OFF
  Instance(s):
    cdb1

  Properties:
    DGConnectIdentifier             = 'cdb1_stby.world'
    LogXptMode                      = 'ASYNC'

Database Status:
SUCCESS

=== CUSTOM SCHEMA VERIFICATION (in PDB) ===
OWNER           TABLE_NAME                     NUM_ROWS
--------------- ------------------------------ --------
HEALTHCENTER    HC_HEALTHCENTER                       3
HEALTHCENTER    HC_LOGBOOK                           45
HEALTHCENTER    HC_MONTHSCALE                        12
HEALTHCENTER    HC_PAYROLL                          120
HEALTHCENTER    HC_PAYROLLMOVEMENT                 1580
HEALTHCENTER    HC_PAYROLLXUSER                     360
HEALTHCENTER    HC_POSITION                           8
HEALTHCENTER    HC_PROCEDURE                        235
HEALTHCENTER    HC_TURN                              24
HEALTHCENTER    HC_TURNXMONTHSCALE                  288
HEALTHCENTER    HC_USER                              45

========================================================================
VERIFICATION COMPLETE
========================================================================
```

## Casos de Uso

### 1. Reporte para Profesor/Auditoría

```bash
# Generar reporte completo con timestamp
/home/oracle/automation/verify_dataguard.sh > \
  /vagrant/dataguard_verification_$(date +%Y%m%d_%H%M%S).txt

# Archivo queda en carpeta compartida de Vagrant
# Accesible desde Windows: C:\...\AdminBDProyecto\dataguard_verification_*.txt
```

### 2. Diagnóstico de Problemas

```bash
# Ejecutar y buscar errores
/home/oracle/automation/verify_dataguard.sh | grep -i error

# Ver solo estado de lag
/home/oracle/automation/verify_dataguard.sh | grep -A 5 "TRANSPORT AND APPLY LAG"

# Verificar gaps
/home/oracle/automation/verify_dataguard.sh | grep -A 10 "ARCHIVE GAP"
```

### 3. Verificación Post-Deployment

```bash
# Después de vagrant up, verificar que todo funcionó
vagrant ssh primary -c "/home/oracle/automation/verify_dataguard.sh"

# Si todo muestra SUCCESS, deployment exitoso
```

### 4. Verificación Pre-Switchover

```bash
# Antes de switchover, confirmar que standby está sincronizado
/home/oracle/automation/verify_dataguard.sh | grep -A 3 "apply lag"

# Si apply lag < 1 minuto, es seguro hacer switchover
```

### 5. Monitoreo Periódico

```bash
# Agregar a cron para ejecutar semanalmente (opcional)
# 0 8 * * 0 /home/oracle/automation/verify_dataguard.sh > /home/oracle/logs/weekly_verification_$(date +\%Y\%m\%d).log

# Mantener historial de verificaciones
```

## Interpretación de Resultados

### Escenario 1: Sistema Saludable

**Indicadores clave:**
- Protection Mode/Level: MAXAVAILABILITY
- Archive Dest 2: VALID
- Transport lag: < 5 segundos
- Apply lag: < 2 minutos
- No archive gaps
- Broker config: SUCCESS
- Esquema existe con datos

**Acción:** Ninguna, sistema funcionando óptimamente

### Escenario 2: Standby Retrasado

**Síntomas:**
- Apply lag: +0 00:15:00 o más
- MRP status: WAIT_FOR_LOG
- Gap check: muestra gaps

**Diagnóstico:**
- Standby no está recibiendo logs o no los está aplicando rápido
- Posible problema de red o rendimiento

**Acción:**
1. Verificar conectividad: `ping ol8-21-dg2.localdomain`
2. Verificar espacio en standby: `ssh oracle@ol8-21-dg2 "df -h /u01"`
3. Revisar alertlog del standby

### Escenario 3: Standby Desconectado

**Síntomas:**
- Archive Dest 2: ERROR
- ERROR column: "ORA-16191: Primary log shipping client not logged on standby"
- Todas las consultas al standby fallan

**Diagnóstico:**
- Standby database caído o listener no funciona
- Red entre primary y standby caída

**Acción:**
```bash
# Verificar listener en standby
ssh oracle@ol8-21-dg2 "lsnrctl status"

# Verificar database en standby
ssh oracle@ol8-21-dg2 "sqlplus / as sysdba <<< 'SELECT status FROM v\$instance;'"

# Si está OPEN (debería ser MOUNTED), hay problema
```

### Escenario 4: Protection Degradada

**Síntomas:**
- Protection Mode: MAXAVAILABILITY
- Protection Level: MAXPERFORMANCE (diferente)

**Diagnóstico:**
- Standby no disponible, primary degradó protección
- Operando sin garantía de no pérdida de datos

**Acción:**
1. Resolver problema de standby
2. Protection level volverá automáticamente a MAXAVAILABILITY

## Puntos de Fallo Comunes

### 1. "ORA-12170: TNS:Connect timeout" al Consultar Standby

**Causa:** Standby no alcanzable

**Efecto en output:**
- Secciones 6-9 fallarán (todo lo que consulta standby)
- Resto del script continúa

**Solución:** Ver sección de troubleshooting en 70-check-log-transport.md

### 2. "ORA-65011: Pluggable database does not exist"

**Causa:** PDB no existe o nombre incorrecto

**Solución:**
```sql
-- Ver PDBs disponibles
SHOW PDBS;

-- Actualizar PDB_NAME en install.env si es diferente
```

### 3. Broker Shows "WARNING" or "ERROR"

**Causa:** Configuración inconsistente o problema temporal

**Solución:**
```bash
# Ver detalles del problema
dgmgrl sys/S1sPassword1!@cdb1.world
SHOW CONFIGURATION VERBOSE;

# Intentar reiniciar broker
DISABLE CONFIGURATION;
ENABLE CONFIGURATION;
```

### 4. No Custom Schema Tables Found

**Causa:** Schema no se desplegó o PDB no abierto

**Solución:**
```sql
-- Abrir PDB
ALTER PLUGGABLE DATABASE pdb1 OPEN;

-- Verificar que usuario existe
SELECT username FROM dba_users WHERE username = 'HEALTHCENTER';

-- Si no existe, re-ejecutar deploy_custom_schema.sh
```

## Importancia para el Sistema

Este script es **CRÍTICO** para:

### 1. Cumplimiento de Requisitos Académicos

"Generación de reporte a petición del profesor"
- Demuestra que Data Guard está configurado
- Evidencia que cumple todos los requisitos
- Formato claro para evaluación

### 2. Diagnóstico Integral

Un solo script verifica TODO:
- No necesita ejecutar múltiples comandos
- Vista completa del sistema en segundos
- Detecta problemas antes de que sean críticos

### 3. Documentación del Estado

Output sirve como:
- Snapshot del sistema en un momento dado
- Evidencia de funcionamiento correcto
- Base para comparar cambios futuros

### 4. Confianza para Operaciones

Antes de switchover/failover:
- Ejecutar este script confirma readiness
- Verde en todas las secciones = seguro proceder
- Problemas visibles antes de intentar cambio

### 5. Training y Aprendizaje

Script enseña:
- Qué aspectos de Data Guard monitorear
- Cómo se ven valores saludables vs problemáticos
- Relación entre diferentes componentes

## Referencias Cruzadas

### Documentos Relacionados

- **[70-check-log-transport.md](70-check-log-transport.md)** - Monitoreo continuo (subset de este script)
- **[81-data-guard-conceptos.md](../conceptos-avanzados/81-data-guard-conceptos.md)** - Conceptos profundos
- **[85-data-guard-broker.md](../conceptos-avanzados/85-data-guard-broker.md)** - Detalles del Broker
- **[90-monitoreo-diario.md](../operaciones/90-monitoreo-diario.md)** - Uso de este script en operaciones
- **[92-switchover.md](../operaciones/92-switchover.md)** - Uso pre-switchover

### Vistas y Comandos Importantes

**Vistas dinámicas:**
```sql
v$database           -- Estado general de la DB
v$archive_dest       -- Destinos de archivado
v$standby_log        -- Standby redo logs
v$log_history        -- Historial de switches
v$managed_standby    -- Procesos de recuperación
v$dataguard_stats    -- Métricas de Data Guard
v$archive_gap        -- Gaps en replicación
dba_tables           -- Tablas de usuarios
```

**Comandos dgmgrl:**
```bash
SHOW CONFIGURATION              # Config general
SHOW DATABASE nombre             # Detalles de DB específica
VALIDATE DATABASE nombre         # Validar configuración
SWITCHOVER TO nombre             # Cambiar roles
FAILOVER TO nombre               # Failover forzado
```

---

**Última Actualización:** 2025-11-04
**Autor:** Claude (Subagente 4)
**Versión:** 1.0
