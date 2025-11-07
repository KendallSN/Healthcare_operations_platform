# 37 - Create Database ⭐ CRÍTICO - Creación de Base de Datos con Data Guard

## Creación de Base de Datos Oracle 21c Preparada para Data Guard

Este es el **script más crítico del proyecto**. Crea la base de datos CDB+PDB, configura todos los archivos de red (listener, tnsnames, sqlnet), y lo más importante: **prepara la base de datos para Data Guard** usando el comando moderno `PREPARE DATABASE FOR DATA GUARD`. Sin este script, no hay Data Guard.

## Ubicación

`2-Standby/scripts/primary/oracle_create_database.sh`

**Nota:** Este es un script **específico de primary**. El standby usa RMAN DUPLICATE.

## Propósito

- **Función principal:** Crear base de datos CDB+PDB lista para Data Guard
- **Responsabilidad:** Configuración de red, creación de DB, configuración Data Guard completa
- **Resultado:** Base de datos en ARCHIVELOG mode con Flashback Database habilitado

## Cuándo se Ejecuta

- **Llamado por:** `root_setup.sh`
- **Orden:** Paso 12 de 12 en el despliegue primario
- **Usuario:** `oracle`
- **Duración:** 8-12 minutos

## Variables de Entorno Utilizadas

```bash
# De install.env
NODE1_FQ_HOSTNAME=ol8-21-dg1.localdomain
NODE2_FQ_HOSTNAME=ol8-21-dg2.localdomain
NODE1_DB_UNIQUE_NAME=cdb1
NODE2_DB_UNIQUE_NAME=cdb1_stby
DB_NAME=cdb1
PDB_NAME=pdb1
DB_DOMAIN=world
ORACLE_SID=cdb1
DATA_DIR=/u01/oradata
SYS_PASSWORD="S1sPassword1!"
PDB_PASSWORD="PdbPassword1!"
REDO_LOG_SIZE=50                # MB
ARCHIVE_LAG_TARGET=300          # 5 minutos
FRA_LOCATION=/u01/app/oracle/fast_recovery_area
FRA_SIZE=100G
NATIVE_NETWORK_ENCRYPTION=true
```

## Flujo de Ejecución Paso a Paso

### PARTE 1: CONFIGURACIÓN DE RED (Red TNS, Listener, Network Encryption)

#### Paso 1: Crear tnsnames.ora

```bash
cat > ${ORACLE_HOME}/network/admin/tnsnames.ora <<EOF
LISTENER${DB_DOMAIN_STR} = (ADDRESS = (PROTOCOL = TCP)(HOST = ${NODE1_FQ_HOSTNAME})(PORT = 1521))

${NODE1_DB_UNIQUE_NAME}${DB_DOMAIN_STR} =
  (DESCRIPTION =
    (ADDRESS_LIST =
      (ADDRESS = (PROTOCOL = TCP)(HOST = ${NODE1_FQ_HOSTNAME})(PORT = 1521))
    )
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SID = ${ORACLE_SID})
      (UR=A)
    )
  )

${NODE2_DB_UNIQUE_NAME}${DB_DOMAIN_STR} =
  (DESCRIPTION =
    (ADDRESS_LIST =
      (ADDRESS = (PROTOCOL = TCP)(HOST = ${NODE2_FQ_HOSTNAME})(PORT = 1521))
    )
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SID = ${ORACLE_SID})
      (UR=A)
    )
  )
EOF
```

**Contenido expandido:**
```
LISTENER.world = (ADDRESS = (PROTOCOL = TCP)(HOST = ol8-21-dg1.localdomain)(PORT = 1521))

cdb1.world =
  (DESCRIPTION =
    (ADDRESS_LIST =
      (ADDRESS = (PROTOCOL = TCP)(HOST = ol8-21-dg1.localdomain)(PORT = 1521))
    )
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SID = cdb1)
      (UR=A)
    )
  )

cdb1_stby.world =
  (DESCRIPTION =
    (ADDRESS_LIST =
      (ADDRESS = (PROTOCOL = TCP)(HOST = ol8-21-dg2.localdomain)(PORT = 1521))
    )
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SID = cdb1)
      (UR=A)
    )
  )
```

**Explicación:**
- **LISTENER:** Referencia al listener local
- **cdb1.world:** TNS alias para primary database
- **cdb1_stby.world:** TNS alias para standby database (usado por Data Guard)
- **UR=A:** Unregister After (permite conexión aunque servicio no esté registrado)
- **SID vs SERVICE_NAME:** Usamos SID para conectividad inicial antes de que servicios estén registrados

#### Paso 2: Crear listener.ora

```bash
cat > ${ORACLE_HOME}/network/admin/listener.ora <<EOF
LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = ${NODE1_FQ_HOSTNAME})(PORT = 1521))
      (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1521))
    )
  )

SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = ${NODE1_DB_UNIQUE_NAME})
      (SID_NAME = ${ORACLE_SID})
      (ORACLE_HOME = ${ORACLE_HOME})
    )
    (SID_DESC =
      (GLOBAL_DBNAME = ${NODE1_DB_UNIQUE_NAME}${DB_DOMAIN_STR})
      (SID_NAME = ${ORACLE_SID})
      (ORACLE_HOME = ${ORACLE_HOME})
    )
    (SID_DESC =
      (SID_NAME = ${ORACLE_SID})
      (GLOBAL_DBNAME = ${NODE1_DB_UNIQUE_NAME}_DGMGRL${DB_DOMAIN_STR})
      (ORACLE_HOME = ${ORACLE_HOME})
      (ENVS="TNS_ADMIN=${ORACLE_HOME}/network/admin")
    )
  )

ADR_BASE_LISTENER = ${ORACLE_BASE}
INBOUND_CONNECT_TIMEOUT_LISTENER=400
EOF
```

**Explicación:**
- **LISTENER:** Escucha en puerto 1521 (TCP) y IPC (para conexiones locales)
- **SID_LIST_LISTENER:** Registra estáticamente servicios (antes de que DB arranque)
- **GLOBAL_DBNAME:** Nombre completo de la database (cdb1, cdb1.world)
- **_DGMGRL:** Servicio especial para Data Guard Broker
- **INBOUND_CONNECT_TIMEOUT:** Timeout de 400 segundos (para transferencias largas de Data Guard)

#### Paso 3: Crear sqlnet.ora con Network Encryption

```bash
cat > ${ORACLE_HOME}/network/admin/sqlnet.ora <<EOF
SQLNET.INBOUND_CONNECT_TIMEOUT=400
EOF

# Add Native Network Encryption if enabled
if [ "${NATIVE_NETWORK_ENCRYPTION}" = "true" ]; then
  cat >> ${ORACLE_HOME}/network/admin/sqlnet.ora <<EOF
SQLNET.ENCRYPTION_SERVER=REQUIRED
SQLNET.ENCRYPTION_TYPES_SERVER=(AES256)

SQLNET.ENCRYPTION_CLIENT=REQUIRED
SQLNET.ENCRYPTION_TYPES_CLIENT=(AES256)

SQLNET.CRYPTO_CHECKSUM_SERVER=REQUIRED
SQLNET.CRYPTO_CHECKSUM_TYPES_SERVER = (SHA256)

SQLNET.CRYPTO_CHECKSUM_CLIENT=REQUIRED
SQLNET.CRYPTO_CHECKSUM_TYPES_CLIENT = (SHA256)
EOF
fi

if [ "${DB_DOMAIN}" != "" ]; then
  cat >> ${ORACLE_HOME}/network/admin/sqlnet.ora <<EOF
NAMES.DEFAULT_DOMAIN=${DB_DOMAIN}
EOF
fi
```

**Configuración de encriptación:**
- **AES256:** Algoritmo de encriptación (Advanced Encryption Standard 256-bit)
- **SHA256:** Algoritmo de checksum para integridad
- **REQUIRED:** Rechaza conexiones no encriptadas
- **Aplica a:** Archive log transport de Data Guard (protege datos en tránsito)

**¿Por qué encriptar?**
- Archive logs contienen datos sensibles (healthcare data)
- Viajan por red entre primary y standby
- AES256 + SHA256 es prácticamente imposible de descifrar

#### Paso 4: Arrancar Listener

```bash
lsnrctl stop 2>/dev/null || true  # Stop si existe
lsnrctl start
lsnrctl status
```

**Salida esperada:**
```
Starting /u01/app/oracle/product/21.0.0/dbhome_1/bin/tnslsnr: please wait...

TNSLSNR for Linux: Version 21.0.0.0.0 - Production
System parameter file is /u01/app/oracle/product/21.0.0/dbhome_1/network/admin/listener.ora
Log messages written to /u01/app/oracle/diag/tnslsnr/.../alert/log.xml
Listening on: (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=ol8-21-dg1.localdomain)(PORT=1521)))
Listening on: (DESCRIPTION=(ADDRESS=(PROTOCOL=ipc)(KEY=EXTPROC1521)))

Connecting to (DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=ol8-21-dg1.localdomain)(PORT=1521)))
STATUS of the LISTENER
------------------------
Alias                     LISTENER
Version                   TNSLSNR for Linux: Version 21.0.0.0.0 - Production
Start Date                04-NOV-2025 14:35:22
Uptime                    0 days 0 hr. 0 min. 3 sec
Trace Level               off
Security                  ON: Local OS Authentication
SNMP                      OFF
Listener Parameter File   /u01/app/oracle/product/21.0.0/dbhome_1/network/admin/listener.ora
Listener Log File         /u01/app/oracle/diag/tnslsnr/.../alert/log.xml
Listening Endpoints Summary...
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=ol8-21-dg1.localdomain)(PORT=1521)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=ipc)(KEY=EXTPROC1521)))
Services Summary...
Service "cdb1" has 1 instance(s).
  Instance "cdb1", status UNKNOWN, has 1 handler(s) for this service...
The command completed successfully
```

---

### PARTE 2: CREACIÓN DE BASE DE DATOS (DBCA en modo silencioso)

#### Paso 5: Crear CDB + PDB usando DBCA

```bash
dbca -silent -createDatabase \
  -templateName General_Purpose.dbc \
  -sid ${ORACLE_SID} \
  -responseFile NO_VALUE \
  -gdbname ${DB_NAME}${DB_DOMAIN_STR} \
  -characterSet AL32UTF8 \
  -sysPassword ${SYS_PASSWORD} \
  -systemPassword ${SYS_PASSWORD} \
  -createAsContainerDatabase true \
  -numberOfPDBs 1 \
  -pdbName ${PDB_NAME} \
  -pdbAdminPassword ${PDB_PASSWORD} \
  -databaseType MULTIPURPOSE \
  -automaticMemoryManagement false \
  -totalMemory 2048 \
  -storageType FS \
  -datafileDestination "${DATA_DIR}" \
  -redoLogFileSize ${REDO_LOG_SIZE} \
  -emConfiguration NONE \
  -initparams db_name=${DB_NAME},db_unique_name=${NODE1_DB_UNIQUE_NAME} \
  -ignorePreReqs
```

**Parámetros clave:**

**Arquitectura Container Database:**
- `-createAsContainerDatabase true`: Crear CDB (multitenant architecture)
- `-numberOfPDBs 1`: Crear 1 PDB dentro del CDB
- `-pdbName pdb1`: Nombre del PDB

**Character set:**
- `-characterSet AL32UTF8`: Unicode completo (UTF-8), soporta todos los idiomas

**Memoria:**
- `-automaticMemoryManagement false`: Usar manual memory management (mejor para VMs pequeñas)
- `-totalMemory 2048`: 2 GB RAM (SGA + PGA)

**Redo logs:**
- `-redoLogFileSize 50`: 50 MB por redo log (adecuado para Data Guard)

**Enterprise Manager:**
- `-emConfiguration NONE`: No configurar EM (ahorra recursos)

**Init params:**
- `db_name=cdb1`: Nombre de la base de datos
- `db_unique_name=cdb1`: Unique name (diferente en standby: cdb1_stby)

**Duración:** 5-7 minutos

**Estructura creada:**
```
CDB: cdb1
├── SYSTEM tablespace
├── SYSAUX tablespace
├── TEMP tablespace
├── UNDO tablespace
├── USERS tablespace
└── PDB: pdb1
    ├── SYSTEM tablespace (PDB)
    ├── SYSAUX tablespace (PDB)
    ├── TEMP tablespace (PDB)
    └── USERS tablespace (PDB)
```

#### Paso 6: Configurar PDB Auto-Start

```bash
sqlplus / as sysdba <<EOF
alter system set db_create_file_dest='${DATA_DIR}';
alter system set db_create_online_log_dest_1='${DATA_DIR}';
alter pluggable database ${PDB_NAME} save state;
alter system reset local_listener;
exit;
EOF
```

**Explicación:**
- `db_create_file_dest`: Directorio por defecto para crear datafiles
- `db_create_online_log_dest_1`: Directorio para online redo logs
- `save state`: PDB se abre automáticamente al arrancar CDB
- `reset local_listener`: Permite dynamic service registration

---

### PARTE 3: PREPARACIÓN PARA DATA GUARD (⭐ SECCIÓN MÁS CRÍTICA)

#### Paso 7: Crear Directorios para Data Guard

```bash
mkdir -p ${FRA_LOCATION}
mkdir -p ${DATA_DIR}/${ORACLE_SID}/arch
```

**Explicación:**
- **FRA_LOCATION:** Fast Recovery Area para flashback logs, backups, archive logs
- **arch:** Directorio para archive logs locales (log_archive_dest_1)

#### Paso 8: Ejecutar PREPARE DATABASE FOR DATA GUARD (Comando Moderno Oracle 21c)

```bash
dgmgrl / <<EOF
prepare database for data guard
  with db_unique_name is ${NODE1_DB_UNIQUE_NAME}
  db_recovery_file_dest is "${FRA_LOCATION}"
  db_recovery_file_dest_size is ${FRA_SIZE};
exit;
EOF
```

**Este comando único realiza TODAS estas operaciones:**

1. **Pone DB en ARCHIVELOG mode**
2. **Habilita FORCE LOGGING** (todas las operaciones se loggean)
3. **Crea STANDBY REDO LOGS** (para redo data del standby)
4. **Configura Fast Recovery Area**
5. **Habilita FLASHBACK DATABASE**
6. **Configura db_unique_name**

**Salida esperada:**
```
DGMGRL for Linux: Version 21.0.0.0.0 - Production

Copyright (c) 2000, 2021, Oracle. All rights reserved.

Welcome to DGMGRL, type "help" for information.
Connected to "cdb1"
Connected as SYSDBA.
Preparing database for Data Guard...
Database prepared for Data Guard.
```

**¿Por qué usar PREPARE DATABASE en lugar de configuración manual?**
- **Más confiable:** Oracle garantiza configuración correcta
- **Más rápido:** Un comando vs ~20 comandos SQL
- **Menos errores:** No olvidar ningún paso
- **Siguiendo mejores prácticas:** Oracle recomienda este método desde 21c

**Configuración manual equivalente (NO USADA, pero para referencia):**
```sql
-- Lo que PREPARE DATABASE hace automáticamente:
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE FORCE LOGGING;
ALTER DATABASE OPEN;
ALTER DATABASE ADD STANDBY LOGFILE SIZE 52428800; -- Múltiples standby logs
ALTER SYSTEM SET db_recovery_file_dest='/path/to/fra' SCOPE=BOTH;
ALTER SYSTEM SET db_recovery_file_dest_size=100G SCOPE=BOTH;
ALTER DATABASE FLASHBACK ON;
```

#### Paso 9: Configurar Parámetros Adicionales de Data Guard

```bash
sqlplus / as sysdba <<EOF
-- Archive lag target (5 minutes as per guide)
ALTER SYSTEM SET archive_lag_target=${ARCHIVE_LAG_TARGET} SCOPE=BOTH;

-- Log archive configuration
ALTER SYSTEM SET log_archive_config='DG_CONFIG=(${NODE1_DB_UNIQUE_NAME},${NODE2_DB_UNIQUE_NAME})' SCOPE=BOTH;

-- Archive destinations
ALTER SYSTEM SET log_archive_dest_1=
  'LOCATION=${DATA_DIR}/${ORACLE_SID}/arch VALID_FOR=(ALL_LOGFILES,ALL_ROLES) DB_UNIQUE_NAME=${NODE1_DB_UNIQUE_NAME}'
  SCOPE=BOTH;

-- LOG_ARCHIVE_DEST_2 is managed by Data Guard Broker (not configured manually)

ALTER SYSTEM SET log_archive_dest_state_1='ENABLE' SCOPE=BOTH;
ALTER SYSTEM SET log_archive_format='%t_%s_%r.arc' SCOPE=SPFILE;

-- Archive process configuration
ALTER SYSTEM SET log_archive_max_processes=8 SCOPE=BOTH;

-- Standby file management
ALTER SYSTEM SET standby_file_management='AUTO' SCOPE=BOTH;

-- Protection and checking
ALTER SYSTEM SET db_lost_write_protect='TYPICAL' SCOPE=BOTH;
ALTER SYSTEM SET db_block_checking='MEDIUM' SCOPE=BOTH;
ALTER SYSTEM SET db_block_checksum='TYPICAL' SCOPE=BOTH;

-- File name conversion (para RMAN DUPLICATE en standby)
ALTER SYSTEM SET db_file_name_convert='/u01/oradata/${NODE2_DB_UNIQUE_NAME}/','/u01/oradata/${NODE1_DB_UNIQUE_NAME}/' SCOPE=SPFILE;
ALTER SYSTEM SET log_file_name_convert='/u01/oradata/${NODE2_DB_UNIQUE_NAME}/','/u01/oradata/${NODE1_DB_UNIQUE_NAME}/' SCOPE=SPFILE;

-- Create password file
!orapwd file=${ORACLE_HOME}/dbs/orapw${ORACLE_SID} password=${SYS_PASSWORD} entries=10 format=12

EXIT;
EOF
```

**Parámetros explicados:**

**archive_lag_target=300:**
- Fuerza switch de redo log cada 5 minutos
- Garantiza que standby no está más de 5 minutos detrás
- Crítico para RPO (Recovery Point Objective)

**log_archive_config:**
```sql
DG_CONFIG=(cdb1,cdb1_stby)
```
- Lista de databases en configuración Data Guard
- Primary y standby deben tener nombres únicos

**log_archive_dest_1:**
```
LOCATION=/u01/oradata/cdb1/arch
VALID_FOR=(ALL_LOGFILES,ALL_ROLES)
DB_UNIQUE_NAME=cdb1
```
- Destino local para archive logs
- `ALL_LOGFILES,ALL_ROLES`: Válido como primary y standby
- Archive logs necesarios para recovery

**log_archive_dest_2:**
- **NO configurado manualmente**
- Data Guard Broker lo configura automáticamente
- Apunta al standby para log transport

**log_archive_format:**
```
%t_%s_%r.arc
```
- `%t`: Thread number
- `%s`: Sequence number
- `%r`: Resetlogs ID
- Ejemplo: `1_123_987654321.arc`

**log_archive_max_processes=8:**
- Número de procesos ARCn (archive log processes)
- Más procesos = más throughput de archiving
- Data Guard usa múltiples procesos para paralelizar

**standby_file_management=AUTO:**
- Automáticamente agrega/elimina datafiles en standby
- Cuando primary crea tablespace, standby lo crea automáticamente

**db_lost_write_protect=TYPICAL:**
- Detecta "lost writes" (escrituras que no llegaron a disco)
- Protege contra corrupción de datos

**db_block_checking=MEDIUM:**
- Verifica checksums de bloques de datos
- Detecta corrupción tempranamente

**db_block_checksum=TYPICAL:**
- Calcula checksums al escribir bloques
- Permite detectar corrupción al leer

**db_file_name_convert y log_file_name_convert:**
```sql
db_file_name_convert='/u01/oradata/cdb1_stby/','/u01/oradata/cdb1/'
```
- Usado por RMAN DUPLICATE en standby
- Convierte nombres de archivos de primary a standby

**Password file (orapwd):**
```bash
orapwd file=$ORACLE_HOME/dbs/orapwcdb1 password=S1sPassword1! entries=10 format=12
```
- Permite autenticación remota como SYSDBA
- Necesario para Data Guard Broker
- Format 12: Permite sincronización de usuarios entre primary y standby

#### Paso 10: Verificar Flashback Database Habilitado

```bash
sqlplus / as sysdba <<EOF
-- Check if flashback is already enabled (PREPARE DATABASE FOR DATA GUARD enables it automatically)
SET SERVEROUTPUT ON
DECLARE
    v_flashback_on VARCHAR2(3);
BEGIN
    SELECT flashback_on INTO v_flashback_on FROM v\$database;

    IF v_flashback_on = 'NO' THEN
        DBMS_OUTPUT.PUT_LINE('Flashback is OFF, enabling now...');
        EXECUTE IMMEDIATE 'ALTER DATABASE FLASHBACK ON';
        DBMS_OUTPUT.PUT_LINE('Flashback enabled successfully.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Flashback is already ON (enabled by PREPARE DATABASE FOR DATA GUARD).');
    END IF;
END;
/

-- Verify flashback is enabled
SELECT name, db_unique_name, flashback_on, log_mode
FROM v\$database;

-- Show FRA configuration
SHOW PARAMETER db_recovery_file_dest;

EXIT;
EOF
```

**Salida esperada:**
```
Flashback is already ON (enabled by PREPARE DATABASE FOR DATA GUARD).

NAME      DB_UNIQUE_NAME FLASHBACK_ON LOG_MODE
--------- -------------- ------------ ------------
CDB1      cdb1           YES          ARCHIVELOG

db_recovery_file_dest           string      /u01/app/oracle/fast_recovery_area
db_recovery_file_dest_size      big integer 100G
```

---

## Archivos Creados/Modificados

### Archivos de Configuración de Red

| Archivo | Descripción |
|---------|-------------|
| `$ORACLE_HOME/network/admin/tnsnames.ora` | TNS aliases para primary y standby |
| `$ORACLE_HOME/network/admin/listener.ora` | Configuración del listener |
| `$ORACLE_HOME/network/admin/sqlnet.ora` | Network encryption (AES256 + SHA256) |

### Archivos de Base de Datos

| Archivo/Directorio | Descripción | Tamaño |
|-------------------|-------------|--------|
| `/u01/oradata/cdb1/system01.dbf` | SYSTEM tablespace | ~900 MB |
| `/u01/oradata/cdb1/sysaux01.dbf` | SYSAUX tablespace | ~600 MB |
| `/u01/oradata/cdb1/undotbs01.dbf` | UNDO tablespace | ~500 MB |
| `/u01/oradata/cdb1/users01.dbf` | USERS tablespace | ~5 MB |
| `/u01/oradata/cdb1/redo01.log` | Online redo log 1 | 50 MB |
| `/u01/oradata/cdb1/redo02.log` | Online redo log 2 | 50 MB |
| `/u01/oradata/cdb1/redo03.log` | Online redo log 3 | 50 MB |
| `/u01/oradata/cdb1/pdb1/system01.dbf` | PDB SYSTEM | ~280 MB |
| `/u01/oradata/cdb1/pdb1/sysaux01.dbf` | PDB SYSAUX | ~500 MB |
| `/u01/oradata/cdb1/arch/` | Archive logs directory | (crece) |

### Fast Recovery Area

| Directorio | Contenido |
|-----------|-----------|
| `/u01/app/oracle/fast_recovery_area/CDB1/` | FRA base |
| `.../flashback/` | Flashback logs |
| `.../archivelog/` | Archive logs (antes de limpiar) |
| `.../backupset/` | RMAN backups |
| `.../autobackup/` | Control file autobackups |

### Archivos de Control y Parámetros

| Archivo | Descripción |
|---------|-------------|
| `/u01/oradata/cdb1/control01.ctl` | Control file 1 |
| `/u01/app/oracle/fast_recovery_area/cdb1/control02.ctl` | Control file 2 (multiplexed) |
| `$ORACLE_HOME/dbs/spfilecdb1.ora` | Server parameter file (binary) |
| `$ORACLE_HOME/dbs/orapwcdb1` | Password file |

### Standby Redo Logs (creados por PREPARE DATABASE)

```sql
SELECT group#, thread#, bytes/1024/1024 as size_mb, status
FROM v$standby_log;

GROUP# THREAD# SIZE_MB STATUS
------ ------- ------- ---------
     4       1      50 UNASSIGNED
     5       1      50 UNASSIGNED
     6       1      50 UNASSIGNED
     7       1      50 UNASSIGNED
```

## Dependencias

### Prerequisitos Absolutos

1. Oracle software instalado (ORACLE_HOME poblado)
2. Listener configurado y corriendo
3. Discos u01 y u02 montados
4. Network configuration (hosts, hostname, chrony) correcta
5. setEnv.sh cargado

### Si Falta Algo

- Sin discos → DBCA falla (no puede crear datafiles)
- Sin network config → Listener no arranca
- Sin setEnv.sh → Variables undefined
- Sin permisos → DBCA permission denied

## Logs y Verificación

### Logs de DBCA

```bash
tail -f $ORACLE_BASE/cfgtoollogs/dbca/cdb1/cdb1.log
```

### Alert Log de la Base de Datos

```bash
tail -f $ORACLE_BASE/diag/rdbms/cdb1/cdb1/trace/alert_cdb1.log
```

**Buscar confirmación de Data Guard:**
```
ALTER DATABASE ARCHIVELOG
Completed: ALTER DATABASE ARCHIVELOG
ALTER DATABASE FORCE LOGGING
Completed: ALTER DATABASE FORCE LOGGING
ALTER DATABASE FLASHBACK ON
Completed: ALTER DATABASE FLASHBACK ON
```

### Verificación Completa de Data Guard Configuration

```sql
-- Conectar como SYSDBA
sqlplus / as sysdba

-- Verificar configuración general
SELECT name, db_unique_name, database_role, log_mode, flashback_on,
       force_logging, protection_mode, protection_level
FROM v$database;

-- Expected:
-- NAME: CDB1
-- DB_UNIQUE_NAME: cdb1
-- DATABASE_ROLE: PRIMARY
-- LOG_MODE: ARCHIVELOG
-- FLASHBACK_ON: YES
-- FORCE_LOGGING: YES
-- PROTECTION_MODE: MAXIMUM PERFORMANCE (cambiará a MAXIMUM AVAILABILITY con standby)
-- PROTECTION_LEVEL: MAXIMUM PERFORMANCE

-- Verificar standby redo logs
SELECT group#, thread#, sequence#, bytes/1024/1024 as size_mb, status
FROM v$standby_log;

-- Expected: 4 standby redo logs de 50 MB cada uno

-- Verificar parámetros de Data Guard
SHOW PARAMETER log_archive_dest
SHOW PARAMETER log_archive_config
SHOW PARAMETER db_recovery_file_dest
SHOW PARAMETER archive_lag_target

-- Verificar que password file existe
HOST ls -l $ORACLE_HOME/dbs/orapw*

-- Verificar procesos de background
SELECT program FROM v$process WHERE program LIKE '%ARC%';
-- Debe listar: ora_arc0_cdb1, ora_arc1_cdb1, etc.

-- Verificar archive logs generados
SELECT name FROM v$archived_log WHERE dest_id=1 ORDER BY sequence# DESC FETCH FIRST 5 ROWS ONLY;
```

## Puntos de Fallo Comunes

### 1. DBCA Falla por Memoria Insuficiente

**Error:**
```
ORA-27102: out of memory
Linux-x86_64 Error: 28: No space left on device
```

**Causa:** VM tiene menos de 2 GB RAM

**Solución:**
- Aumentar RAM en vagrant.yml: `memory: 4096`
- O reducir memory en dbca: `-totalMemory 1536`

### 2. Listener No Arranca

**Error:**
```
TNS-12555: TNS:permission denied
TNS-12560: TNS:protocol adapter error
```

**Causa:** Puerto 1521 ya en uso o permisos incorrectos

**Solución:**
```bash
# Verificar puerto
netstat -tuln | grep 1521

# Matar proceso si existe
lsnrctl stop
pkill tnslsnr

# Reintentar
lsnrctl start
```

### 3. PREPARE DATABASE Falla

**Error:**
```
ORA-16000: database or pluggable database open for read-only access
```

**Causa:** PDB abierto en modo read-only

**Solución:**
```sql
ALTER PLUGGABLE DATABASE ALL CLOSE;
ALTER PLUGGABLE DATABASE ALL OPEN;
```

### 4. Flashback No Se Habilita

**Error:**
```
ORA-38706: Cannot turn on FLASHBACK DATABASE logging.
ORA-38709: Recovery Area is not enabled.
```

**Causa:** FRA no configurado correctamente

**Solución:**
```sql
ALTER SYSTEM SET db_recovery_file_dest='/u01/app/oracle/fast_recovery_area' SCOPE=BOTH;
ALTER SYSTEM SET db_recovery_file_dest_size=100G SCOPE=BOTH;
ALTER DATABASE FLASHBACK ON;
```

### 5. Archive Logs No Se Generan

**Síntoma:** `SELECT * FROM v$archived_log;` vacío

**Causa:** Archive lag target no fuerza log switch

**Solución:**
```sql
-- Forzar log switch manual
ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM ARCHIVE LOG CURRENT;

-- Verificar
SELECT sequence#, name FROM v$archived_log ORDER BY sequence# DESC;
```

## Importancia para Data Guard - Resumen

Este script es el **corazón de toda la configuración Data Guard:**

**Sin este script:**
- No hay ARCHIVELOG mode → No hay replicación
- No hay standby redo logs → No hay FASTSYNC
- No hay Flashback Database → No hay failover rápido
- No hay password file → Broker no puede conectar
- No hay network encryption → Datos viajan sin protección
- No hay FRA → Backups y archive logs sin gestión

**Con este script:**
- ✅ Primary COMPLETAMENTE listo para Data Guard
- ✅ Standby puede conectarse y comenzar redo apply
- ✅ Protection mode MAXAVAILABILITY posible
- ✅ Flashback para reinstatement después de failover
- ✅ Network encryption AES256
- ✅ Archive logs con lag máximo de 5 minutos

## Referencias Cruzadas

### Scripts Relacionados

- **[31 - Primary Root Setup](31-primary-root-setup.md)** - Orquestador
- **[57 - Standby RMAN Duplicate](../standby/57-rman-duplicate.md)** - Usa esta DB como source
- **[38 - Deploy Schema](38-deploy-schema.md)** - Despliega healthcare schema en esta DB

### Documentación de Conceptos

- **[80 - Oracle CDB/PDB](../../conceptos-avanzados/80-oracle-cdb-pdb.md)** - Arquitectura multitenant
- **[81 - Data Guard Conceptos](../../conceptos-avanzados/81-data-guard-conceptos.md)** - Teoría de Data Guard
- **[83 - Archive Logs](../../conceptos-avanzados/83-archive-logs.md)** - Archive log management
- **[84 - Flashback Database](../../conceptos-avanzados/84-flashback-database.md)** - Flashback explicado
- **[86 - Networking TNS](../../conceptos-avanzados/86-networking-tns.md)** - TNS configuration

## Código Fuente Completo

Ver archivo: `2-Standby/scripts/primary/oracle_create_database.sh` (237 líneas)

---

**Siguiente:** [38 - Deploy Schema](38-deploy-schema.md) - Despliegue del healthcare management schema en PDB.
