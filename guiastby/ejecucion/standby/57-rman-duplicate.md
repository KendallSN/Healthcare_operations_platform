# 57 - 🔥 RMAN DUPLICATE - Creación del Standby Database 🔥

## Descripción General

**Archivo:** `2-Standby/scripts/standby/oracle_create_database.sh`

**Propósito:** Crear el standby database copiando TODA la base de datos primary a través de la red usando RMAN DUPLICATE, y configurar completamente Oracle Data Guard con protección MAXAVAILABILITY.

**Rol:** **ESTA ES LA ETAPA MÁS CRÍTICA Y COMPLEJA DE TODO EL DESPLIEGUE STANDBY.**

**Tiempo de ejecución:** 10-20 minutos (mayoría en RMAN DUPLICATE)

---

## 🎯 IMPORTANCIA CRÍTICA

**Este script es el corazón del despliegue standby.**

Sin este script:
- No habría standby database
- No habría replicación Data Guard
- No habría alta disponibilidad
- El proyecto completo no funcionaría

**Lo que hace este script:**
1. Configura conectividad de red (TNS)
2. Crea estructura de directorios
3. Copia password file de primary
4. Arranca instancia auxiliar
5. **EJECUTA RMAN DUPLICATE** ⭐⭐⭐ (copia 15-25 GB de datos)
6. Configura Data Guard Broker
7. Establece MAXAVAILABILITY protection mode
8. Configura FASTSYNC transport mode
9. Valida la configuración completa

---

## Tabla de Contenidos

1. [Flujo General del Script](#1-flujo-general-del-script)
2. [Parte 1: Configuración de Red TNS](#2-parte-1-configuración-de-red-tns)
3. [Parte 2: Preparación de Directorios](#3-parte-2-preparación-de-directorios)
4. [Parte 3: Password File](#4-parte-3-password-file)
5. [Parte 4: Auxiliary Instance](#5-parte-4-auxiliary-instance)
6. [Parte 5: Prueba de Conectividad](#6-parte-5-prueba-de-conectividad)
7. [Parte 6: 🔥 RMAN DUPLICATE 🔥](#7-parte-6-🔥-rman-duplicate-🔥)
8. [Parte 7: Flashback Database](#8-parte-7-flashback-database)
9. [Parte 8: Data Guard Broker](#9-parte-8-data-guard-broker)
10. [Parte 9: MAXAVAILABILITY Protection Mode](#10-parte-9-maxavailability-protection-mode)
11. [Parte 10: Validación Final](#11-parte-10-validación-final)
12. [Detalles Técnicos de RMAN DUPLICATE](#12-detalles-técnicos-de-rman-duplicate)
13. [Troubleshooting Completo](#13-troubleshooting-completo)

---

## 1. Flujo General del Script

```
┌─────────────────────────────────────────────────────────────────┐
│           oracle_create_database.sh - FLUJO COMPLETO            │
└─────────────────────────────────────────────────────────────────┘

[1] Source Variables
    ├─ /vagrant_config/install.env
    └─ /home/oracle/scripts/setEnv.sh

[2] Configurar Red (5 minutos)
    ├─ Crear tnsnames.ora
    ├─ Crear listener.ora
    ├─ Crear sqlnet.ora (con AES256 encryption)
    └─ Iniciar listener

[3] Preparar Directorios (1 minuto)
    ├─ /u01/oradata/CDB1/
    ├─ /u01/oradata/CDB1/pdbseed/
    ├─ /u01/oradata/CDB1/pdb1/
    ├─ /u02/fast_recovery_area/cdb1/
    ├─ /u01/oradata/CDB1/arch/
    ├─ /u01/app/oracle/admin/cdb1/adump/
    └─ /u02/backup_from_primary/  ⭐ Standby-specific

[4] Crear Password File (30 segundos)
    └─ orapwd (debe coincidir con primary EXACTAMENTE)

[5] Crear Instancia Auxiliar (1 minuto)
    ├─ Crear init temp file
    └─ STARTUP NOMOUNT con parámetros mínimos

[6] Probar Conectividad (30 segundos)
    └─ tnsping cdb1.world (primary)

[7] 🔥 RMAN DUPLICATE 🔥 (10-20 minutos) ⭐⭐⭐
    ├─ Conectar a primary (target) y standby (auxiliary)
    ├─ DUPLICATE TARGET DATABASE
    │   FOR STANDBY
    │   FROM ACTIVE DATABASE  ← Copia vía red
    │   DORECOVER            ← Aplica archive logs
    │   SPFILE               ← Crea spfile con parámetros
    │     SET db_unique_name='cdb1_stby'
    │   NOFILENAMECHECK
    └─ Resultado: Copia completa de primary en standby

[8] Habilitar Flashback (1 minuto)
    └─ ALTER DATABASE FLASHBACK ON (en standby)

[9] Configurar Data Guard Broker (3 minutos)
    ├─ Habilitar broker en standby
    ├─ Habilitar broker en primary (remoto)
    ├─ CREATE CONFIGURATION dg_config
    ├─ ADD DATABASE cdb1_stby
    └─ ENABLE CONFIGURATION

[10] Configurar MAXAVAILABILITY (2 minutos)
     ├─ SET LogXptMode=FASTSYNC (primary)
     ├─ SET LogXptMode=FASTSYNC (standby)
     ├─ Verificar LogXptMode aplicado
     ├─ SET STATE='APPLY-ON' (standby)
     ├─ SET PROTECTION MODE AS MAXAVAILABILITY
     └─ Verificar protection level = MAXIMUM AVAILABILITY

[11] Validar Configuración (1 minuto)
     ├─ VALIDATE DATABASE cdb1
     ├─ VALIDATE DATABASE cdb1_stby
     ├─ Verificar flashback en ambos
     ├─ SHOW CONFIGURATION
     └─ Verificar custom schema replicado

Total: 20-30 minutos
```

---

## 2. Parte 1: Configuración de Red TNS

### 2.1. ¿Por Qué Configurar Redes Primero?

**RMAN DUPLICATE necesita conectarse a primary vía red.**

Sin configuración TNS:
- RMAN no puede conectar a primary
- No hay forma de copiar los datos
- El despliegue falla

**Archivos necesarios:**
1. `tnsnames.ora` - Define service names (cdb1.world, cdb1_stby.world)
2. `listener.ora` - Configura listener del standby
3. `sqlnet.ora` - Configuración de red (encryption, timeout, domain)

---

### 2.2. Crear tnsnames.ora

**Ubicación:** `${ORACLE_HOME}/network/admin/tnsnames.ora`

**Código del script:**
```bash
cat > ${ORACLE_HOME}/network/admin/tnsnames.ora <<EOF
LISTENER${DB_DOMAIN_STR} = (ADDRESS = (PROTOCOL = TCP)(HOST = ${NODE2_FQ_HOSTNAME})(PORT = 1521))

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

**Resultado (con variables expandidas):**
```
LISTENER.world = (ADDRESS = (PROTOCOL = TCP)(HOST = ol8-21-dg2.localdomain)(PORT = 1521))

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

**Elementos importantes:**

**1. Service Names:**
- `cdb1.world` - Primary database
- `cdb1_stby.world` - Standby database
- `.world` - Domain (definido en `DB_DOMAIN=world`)

**2. Hostnames:**
- Primary: `ol8-21-dg1.localdomain`
- Standby: `ol8-21-dg2.localdomain`
- Deben resolver correctamente (configurados en /etc/hosts)

**3. SID vs SERVICE_NAME:**
- Aquí se usa `SID = cdb1` (mismo en ambos)
- Alternativa: `SERVICE_NAME = cdb1` o `SERVICE_NAME = cdb1_stby`
- SID es más directo para conexiones SYSDBA

**4. UR=A (UnRestricted):**
- Permite conectar incluso si DB está en RESTRICTED mode
- Importante para mantenimiento y Data Guard

**5. DEDICATED Server:**
- Cada conexión tiene su propio server process
- Requerido para SYSDBA connections
- Alternativa: SHARED (no usado aquí)

---

### 2.3. Crear listener.ora

**Ubicación:** `${ORACLE_HOME}/network/admin/listener.ora`

**Código:**
```bash
cat > ${ORACLE_HOME}/network/admin/listener.ora <<EOF
LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = ${NODE2_FQ_HOSTNAME})(PORT = 1521))
      (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1521))
    )
  )

SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = ${NODE2_DB_UNIQUE_NAME})
      (SID_NAME = ${ORACLE_SID})
      (ORACLE_HOME = ${ORACLE_HOME})
    )
    (SID_DESC =
      (GLOBAL_DBNAME = ${NODE2_DB_UNIQUE_NAME}${DB_DOMAIN_STR})
      (SID_NAME = ${ORACLE_SID})
      (ORACLE_HOME = ${ORACLE_HOME})
    )
    (SID_DESC =
      (SID_NAME = ${ORACLE_SID})
      (GLOBAL_DBNAME = ${NODE2_DB_UNIQUE_NAME}_DGMGRL${DB_DOMAIN_STR})
      (ORACLE_HOME = ${ORACLE_HOME})
      (ENVS="TNS_ADMIN=${ORACLE_HOME}/network/admin")
    )
  )

ADR_BASE_LISTENER = ${ORACLE_BASE}
INBOUND_CONNECT_TIMEOUT_LISTENER=400
EOF
```

**Resultado expandido:**
```
LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = ol8-21-dg2.localdomain)(PORT = 1521))
      (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1521))
    )
  )

SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = cdb1_stby)
      (SID_NAME = cdb1)
      (ORACLE_HOME = /u01/app/oracle/product/21.0.0/dbhome_1)
    )
    (SID_DESC =
      (GLOBAL_DBNAME = cdb1_stby.world)
      (SID_NAME = cdb1)
      (ORACLE_HOME = /u01/app/oracle/product/21.0.0/dbhome_1)
    )
    (SID_DESC =
      (SID_NAME = cdb1)
      (GLOBAL_DBNAME = cdb1_stby_DGMGRL.world)
      (ORACLE_HOME = /u01/app/oracle/product/21.0.0/dbhome_1)
      (ENVS="TNS_ADMIN=/u01/app/oracle/product/21.0.0/dbhome_1/network/admin")
    )
  )

ADR_BASE_LISTENER = /u01/app/oracle
INBOUND_CONNECT_TIMEOUT_LISTENER=400
```

**Elementos críticos:**

**1. Listener Address:**
- TCP port 1521 (estándar Oracle)
- Hostname del standby
- IPC para EXTPROC (external procedures)

**2. Static SID Registration:**
- Tres entradas SID_DESC:
  1. `cdb1_stby` - Sin domain
  2. `cdb1_stby.world` - Con domain ⭐ **Usado por RMAN DUPLICATE**
  3. `cdb1_stby_DGMGRL.world` - Para Data Guard Broker ⭐

**3. ¿Por qué Static Registration?**
- Durante RMAN DUPLICATE, DB está en NOMOUNT
- Dynamic registration solo funciona cuando DB está OPEN
- Static permite conectar a DB en NOMOUNT/MOUNT

**4. _DGMGRL entry:**
- Específica para Data Guard Broker
- Permite al Broker gestionar la database
- Incluye ENVS="TNS_ADMIN=..." para que Broker encuentre tnsnames.ora

**5. INBOUND_CONNECT_TIMEOUT:**
- 400 segundos (6 min 40 seg)
- Da tiempo para comandos largos (RMAN DUPLICATE)
- Por defecto es 60 segundos (muy corto)

---

### 2.4. Crear sqlnet.ora

**Ubicación:** `${ORACLE_HOME}/network/admin/sqlnet.ora`

**Código básico:**
```bash
cat > ${ORACLE_HOME}/network/admin/sqlnet.ora <<EOF
SQLNET.INBOUND_CONNECT_TIMEOUT=400
EOF
```

**Con Native Network Encryption (habilitado en este proyecto):**
```bash
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
```

**Con DB_DOMAIN:**
```bash
if [ "${DB_DOMAIN}" != "" ]; then
  cat >> ${ORACLE_HOME}/network/admin/sqlnet.ora <<EOF
NAMES.DEFAULT_DOMAIN=${DB_DOMAIN}
EOF
fi
```

**Resultado final:**
```
SQLNET.INBOUND_CONNECT_TIMEOUT=400

SQLNET.ENCRYPTION_SERVER=REQUIRED
SQLNET.ENCRYPTION_TYPES_SERVER=(AES256)

SQLNET.ENCRYPTION_CLIENT=REQUIRED
SQLNET.ENCRYPTION_TYPES_CLIENT=(AES256)

SQLNET.CRYPTO_CHECKSUM_SERVER=REQUIRED
SQLNET.CRYPTO_CHECKSUM_TYPES_SERVER = (SHA256)

SQLNET.CRYPTO_CHECKSUM_CLIENT=REQUIRED
SQLNET.CRYPTO_CHECKSUM_TYPES_CLIENT = (SHA256)

NAMES.DEFAULT_DOMAIN=world
```

**Explicación:**

**1. INBOUND_CONNECT_TIMEOUT:**
- Tiempo máximo para completar handshake inicial
- 400 segundos para RMAN DUPLICATE

**2. ENCRYPTION_SERVER/CLIENT = REQUIRED:**
- Cifrado obligatorio (no opcional)
- Todas las conexiones deben usar AES256
- Si cliente no soporta, conexión rechazada

**3. AES256:**
- Advanced Encryption Standard 256-bit
- Máximo nivel de seguridad
- Protege datos en tránsito entre primary y standby

**4. SHA256 Checksum:**
- Integridad de datos
- Detecta alteraciones en tránsito
- Complementa el cifrado

**5. DEFAULT_DOMAIN:**
- Si conectas a `cdb1`, se expande a `cdb1.world`
- Simplifica comandos:
  ```bash
  sqlplus sys/pass@cdb1 as sysdba
  # Busca en tnsnames.ora: cdb1.world
  ```

**¿Por qué Encryption?**
- Archive logs contienen datos sensibles (healthcare info)
- Tráfico primary ↔ standby debe estar cifrado
- Best practice de seguridad Oracle

---

### 2.5. Iniciar Listener

```bash
echo "******************************************************************************"
echo "Start listener." `date`
echo "******************************************************************************"
lsnrctl stop 2>/dev/null || true
lsnrctl start
lsnrctl status
```

**Desglose:**

**1. Stop anterior (si existe):**
```bash
lsnrctl stop 2>/dev/null || true
```
- Detiene listener previo (si hay)
- `2>/dev/null` - Suprime errores
- `|| true` - No falla si listener no estaba corriendo

**2. Start listener:**
```bash
lsnrctl start
```

**Salida típica:**
```
LSNRCTL for Linux: Version 21.0.0.0.0 - Production on 04-NOV-2025 17:15:32

Starting /u01/app/oracle/product/21.0.0/dbhome_1/bin/tnslsnr: please wait...

TNSLSNR for Linux: Version 21.0.0.0.0 - Production
System parameter file is /u01/app/oracle/product/21.0.0/dbhome_1/network/admin/listener.ora
Log messages written to /u01/app/oracle/diag/tnslsnr/ol8-21-dg2/listener/alert/log.xml
Listening on: (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=ol8-21-dg2.localdomain)(PORT=1521)))
Listening on: (DESCRIPTION=(ADDRESS=(PROTOCOL=ipc)(KEY=EXTPROC1521)))

Connecting to (DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=ol8-21-dg2.localdomain)(PORT=1521)))
STATUS of the LISTENER
------------------------
Alias                     LISTENER
Version                   TNSLSNR for Linux: Version 21.0.0.0.0 - Production
Start Date                04-NOV-2025 17:15:32
Uptime                    0 days 0 hr. 0 min. 0 sec
Trace Level               off
Security                  ON: Local OS Authentication
SNMP                      OFF
Listener Parameter File   /u01/app/oracle/product/21.0.0/dbhome_1/network/admin/listener.ora
Listener Log File         /u01/app/oracle/diag/tnslsnr/ol8-21-dg2/listener/alert/log.xml
Listening Endpoints Summary...
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=ol8-21-dg2.localdomain)(PORT=1521)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=ipc)(KEY=EXTPROC1521)))
Services Summary...
Service "cdb1_stby" has 1 instance(s).
  Instance "cdb1", status UNKNOWN, has 1 handler(s) for this service...
Service "cdb1_stby.world" has 1 instance(s).
  Instance "cdb1", status UNKNOWN, has 1 handler(s) for this service...
Service "cdb1_stby_DGMGRL.world" has 1 instance(s).
  Instance "cdb1", status UNKNOWN, has 1 handler(s) for this service...
The command completed successfully
```

**3. Status:**
```bash
lsnrctl status
```
- Verifica que listener esté corriendo
- Muestra services registrados
- `status UNKNOWN` es normal (DB aún no existe)

---

## 3. Parte 2: Preparación de Directorios

```bash
echo "******************************************************************************"
echo "Create directories and password file." `date`
echo "******************************************************************************"

mkdir -p /u01/oradata/${ORACLE_SID^^}
mkdir -p /u01/oradata/${ORACLE_SID^^}/pdbseed
mkdir -p /u01/oradata/${ORACLE_SID^^}/${PDB_NAME}
mkdir -p ${FRA_LOCATION}/${ORACLE_SID}
mkdir -p ${ORACLE_BASE}/admin/${ORACLE_SID}/adump
mkdir -p ${DATA_DIR}/${ORACLE_SID}/arch
mkdir -p /u02/backup_from_primary
```

**Directorios creados:**

```
/u01/oradata/CDB1/              # Datafiles del CDB
/u01/oradata/CDB1/pdbseed/      # PDB$SEED
/u01/oradata/CDB1/pdb1/         # PDB1 (healthcare schema)
/u02/fast_recovery_area/cdb1/   # FRA
/u01/app/oracle/admin/cdb1/adump/  # Audit files
/u01/oradata/CDB1/arch/         # Archive logs
/u02/backup_from_primary/       # ⭐ STANDBY SPECIFIC
```

**${ORACLE_SID^^}:**
- `^^` - Bash para convertir a mayúsculas
- `cdb1` → `CDB1`
- Oracle convention: directorios de datos en mayúsculas

**backup_from_primary:**
- Solo en standby
- Aquí llegan backups RMAN del primary vía rsync
- Primary hace backup a `/u02/backup/`
- Primary hace rsync a standby: `/u02/backup_from_primary/`

---

## 4. Parte 3: Password File

### 4.1. ¿Por Qué es Crítico?

**Password file permite autenticación SYSDBA remota.**

Sin password file:
- No puedes conectar como SYSDBA vía red
- RMAN DUPLICATE falla (necesita SYSDBA en primary y standby)
- Data Guard no funciona

**Requisito:** Password file de standby DEBE coincidir EXACTAMENTE con primary.

---

### 4.2. Crear Password File

```bash
orapwd file=$ORACLE_HOME/dbs/orapw${ORACLE_SID} password=${SYS_PASSWORD} entries=10 format=12
```

**Desglose:**

**1. Ubicación:**
```bash
$ORACLE_HOME/dbs/orapwcdb1
```
- Convención Oracle: `orapw<SID>`
- Debe estar en `$ORACLE_HOME/dbs/`

**2. Password:**
```bash
password=${SYS_PASSWORD}
# Valor: S1sPassword1! (de install.env)
```
- **DEBE SER IDÉNTICO AL PRIMARY** ⭐⭐⭐
- Si difiere, RMAN DUPLICATE falla con ORA-01017

**3. Entries:**
```bash
entries=10
```
- Número máximo de usuarios con SYSDBA/SYSOPER
- 10 es suficiente (solo necesitamos SYS)

**4. Format:**
```bash
format=12
```
- Oracle 12c+ format
- Soporta case-sensitive passwords
- Compatible con Data Guard

---

### 4.3. Verificación

```bash
# Ver password file
ls -l $ORACLE_HOME/dbs/orapwcdb1

# Ver usuarios en password file (después de crear DB)
sqlplus / as sysdba <<EOF
SELECT * FROM v\$pwfile_users;
EOF

# Resultado esperado:
USERNAME    SYSDBA    SYSOPER    SYSASM
--------    ------    -------    ------
SYS         TRUE      TRUE       FALSE
```

---

## 5. Parte 4: Auxiliary Instance

### 5.1. ¿Qué es una Auxiliary Instance?

**Instancia temporal mínima para que RMAN pueda trabajar.**

Características:
- Solo en memoria (sin datafiles)
- Modo NOMOUNT (no monta database)
- Usa parámetros mínimos (solo `db_name`)
- RMAN la usa como destino del DUPLICATE

---

### 5.2. Crear Init File Temporal

```bash
echo "******************************************************************************"
echo "Create temporary init.ora file for auxiliary instance." `date`
echo "******************************************************************************"

cat > /tmp/init${ORACLE_SID}_stby.ora <<EOF
*.db_name='${ORACLE_SID}'
EOF
```

**Resultado:**
```
# /tmp/initcdb1_stby.ora
*.db_name='cdb1'
```

**Por qué solo db_name:**
- Es el ÚNICO parámetro obligatorio para NOMOUNT
- Todo lo demás lo configurará RMAN con SPFILE durante DUPLICATE

**Temporal:**
- Este init file se usa SOLO durante DUPLICATE
- Después RMAN crea un SPFILE completo

---

### 5.3. Arrancar Auxiliary Instance

```bash
echo "******************************************************************************"
echo "Create auxiliary instance." `date`
echo "******************************************************************************"

sqlplus / as sysdba <<EOF
startup nomount pfile='/tmp/init${ORACLE_SID}_stby.ora';
exit;
EOF
```

**Salida esperada:**
```sql
SQL*Plus: Release 21.0.0.0.0 - Production on Mon Nov 4 17:20:15 2025

Connected to an idle instance.

SQL> startup nomount pfile='/tmp/initcdb1_stby.ora';
ORACLE instance started.

Total System Global Area 1593835520 bytes
Fixed Size                  9691264 bytes
Variable Size             469762048 bytes
Database Buffers         1107296256 bytes
Redo Buffers                7086080 bytes
SQL> exit
```

**Verificación:**
```bash
ps aux | grep pmon
# Debe mostrar: ora_pmon_cdb1
```

**Estado de la instancia:**
- STARTED (no MOUNTED, no OPEN)
- Solo procesos de background corriendo
- Sin datafiles montados
- Lista para RMAN DUPLICATE

---

## 6. Parte 5: Prueba de Conectividad

```bash
echo "******************************************************************************"
echo "Test connectivity to primary database." `date`
echo "******************************************************************************"

tnsping ${NODE1_DB_UNIQUE_NAME}${DB_DOMAIN_STR}
```

**Comando expandido:**
```bash
tnsping cdb1.world
```

**Salida esperada (éxito):**
```
TNS Ping Utility for Linux: Version 21.0.0.0.0 - Production on 04-NOV-2025 17:20:30

Used parameter files:
/u01/app/oracle/product/21.0.0/dbhome_1/network/admin/sqlnet.ora

Used TNSNAMES adapter to resolve the alias
Attempting to contact (DESCRIPTION = (ADDRESS_LIST = (ADDRESS = (PROTOCOL = TCP)(HOST = ol8-21-dg1.localdomain)(PORT = 1521))) (CONNECT_DATA = (SERVER = DEDICATED) (SID = cdb1) (UR=A)))
OK (20 msec)
```

**Qué verifica:**
- ✅ tnsnames.ora tiene entrada `cdb1.world`
- ✅ Hostname `ol8-21-dg1.localdomain` resuelve (DNS/hosts)
- ✅ Primary listener responde en puerto 1521
- ✅ Network path está abierto

**Si falla:**
- ❌ Primary no está corriendo
- ❌ Primary listener no responde
- ❌ Red no configurada
- ❌ tnsnames.ora incorrecto
- ❌ Firewall bloqueando

**NO verifica:**
- Password (eso se verifica en RMAN)
- Que DB esté OPEN
- Permisos SYSDBA

---

## 7. Parte 6: 🔥 RMAN DUPLICATE 🔥

### 7.1. Introducción

**ESTE ES EL CORAZÓN DEL SCRIPT Y DEL STANDBY DATABASE.**

**¿Qué hace RMAN DUPLICATE?**
- Copia TODA la base de datos primary a standby a través de la red
- Copia todos los datafiles (system, sysaux, users, temp, undo)
- Copia todos los PDBs (pdbseed, pdb1)
- Copia el schema HEALTHCENTER completo (tablas, datos, packages, triggers)
- Aplica archive logs hasta el momento (DORECOVER)
- Crea SPFILE con parámetros Data Guard
- Resultado: Réplica exacta de primary

**Tiempo:** 10-20 minutos (depende de tamaño de DB y velocidad de red)

---

### 7.2. Código RMAN DUPLICATE

```bash
echo "******************************************************************************"
echo "Create standby database using RMAN duplicate." `date`
echo "This may take 10-20 minutes depending on database size..."
echo "******************************************************************************"

rman target sys/${SYS_PASSWORD}@${NODE1_DB_UNIQUE_NAME}${DB_DOMAIN_STR} auxiliary sys/${SYS_PASSWORD}@${NODE2_DB_UNIQUE_NAME}${DB_DOMAIN_STR} <<EOF

duplicate target database
  for standby
  from active database
  dorecover
  spfile
    set db_unique_name='${NODE2_DB_UNIQUE_NAME}' comment 'Is standby'
  nofilenamecheck;

exit;
EOF
```

**Comando expandido:**
```bash
rman target sys/S1sPassword1!@cdb1.world auxiliary sys/S1sPassword1!@cdb1_stby.world

RMAN> duplicate target database
        for standby
        from active database
        dorecover
        spfile
          set db_unique_name='cdb1_stby' comment 'Is standby'
        nofilenamecheck;
```

---

### 7.3. Desglose del Comando RMAN

**1. Conexiones:**
```bash
target sys/S1sPassword1!@cdb1.world
```
- **TARGET** = Primary database (fuente)
- Conecta como SYS (SYSDBA)
- Vía red usando tnsnames.ora

```bash
auxiliary sys/S1sPassword1!@cdb1_stby.world
```
- **AUXILIARY** = Standby instance (destino)
- También como SYS
- Vía red (aunque esté en misma VM, usa network stack)

**2. DUPLICATE TARGET DATABASE:**
- Comando principal de RMAN
- Copia base de datos completa

**3. FOR STANDBY:**
- ⭐ **Clave:** Indica que es para standby, no para clonación normal
- RMAN configura parámetros Data Guard automáticamente
- Crea standby redo logs
- Configura archive log destination

**4. FROM ACTIVE DATABASE:**
- ⭐ **Método de copia:** Directo desde primary vía red
- **NO** usa backup files
- **NO** requiere backup previo
- Primary debe estar OPEN READ WRITE
- Alternativas:
  - `FROM BACKUPSET` - Usa backups RMAN existentes
  - Sin cláusula - Requiere backup previo

**5. DORECOVER:**
- ⭐ Después de copiar datafiles, aplica archive logs
- Resultado: Standby actualizado hasta el momento del duplicate
- Sin `DORECOVER`: Standby queda desfasado

**6. SPFILE:**
- Crea Server Parameter File en standby
- Copia parámetros de primary
- Permite modificar parámetros con SET

**7. SET db_unique_name='cdb1_stby':**
- ⭐⭐⭐ **MUY CRÍTICO**
- Establece DB_UNIQUE_NAME diferente del primary
- Sin esto, ambas DBs tendrían mismo unique name (error)

**8. NOFILENAMECHECK:**
- Permite que standby use rutas idénticas a primary
- Sin esto, RMAN esperaría rutas diferentes (diskgroups ASM)
- En este proyecto: rutas son idénticas (`/u01/oradata/CDB1/...`)

---

### 7.4. Progreso de RMAN DUPLICATE

**Salida típica (resumida):**

```
Recovery Manager: Release 21.0.0.0.0 - Production on Mon Nov 4 17:25:00 2025

connected to target database: CDB1 (DBID=1234567890)
connected to auxiliary database: CDB1 (not mounted)

Starting Duplicate Db at 04-NOV-25
using target database control file instead of recovery catalog
allocated channel: ORA_AUX_DISK_1
channel ORA_AUX_DISK_1: SID=245 device type=DISK

contents of Memory Script:
{
   backup as copy reuse
   targetfile '/u01/app/oracle/product/21.0.0/dbhome_1/dbs/orapwcdb1' auxiliary format
 '/u01/app/oracle/product/21.0.0/dbhome_1/dbs/orapwcdb1'   ;
}
executing Memory Script

Starting backup at 04-NOV-25
channel ORA_AUX_DISK_1: starting datafile copy
copying current control file
output file name=/u01/oradata/CDB1/control01.ctl tag=TAG20251104T172510
channel ORA_AUX_DISK_1: datafile copy complete, elapsed time: 00:00:03
Finished backup at 04-NOV-25

contents of Memory Script:
{
   restore clone from service  'cdb1.world' spfile to
 '/u01/app/oracle/product/21.0.0/dbhome_1/dbs/spfilecdb1.ora';
   sql clone "alter system set spfile= ''/u01/app/oracle/product/21.0.0/dbhome_1/dbs/spfilecdb1.ora''";
}
executing Memory Script

Starting restore at 04-NOV-25
channel ORA_AUX_DISK_1: starting datafile backup set restore
channel ORA_AUX_DISK_1: using network backup set from service cdb1.world
channel ORA_AUX_DISK_1: restoring SPFILE
output file name=/u01/app/oracle/product/21.0.0/dbhome_1/dbs/spfilecdb1.ora
channel ORA_AUX_DISK_1: restore complete, elapsed time: 00:00:01
Finished restore at 04-NOV-25

sql statement: alter system set spfile= ''/u01/app/oracle/product/21.0.0/dbhome_1/dbs/spfilecdb1.ora''

contents of Memory Script:
{
   sql clone "alter system set  db_unique_name =
 ''cdb1_stby'' comment=
 ''Is standby'' scope=spfile";
   shutdown clone immediate;
   startup clone force nomount;
}
executing Memory Script

sql statement: alter system set  db_unique_name =  ''cdb1_stby'' comment= ''Is standby'' scope=spfile

Oracle instance shut down

connected to auxiliary database (not started)
Oracle instance started

Total System Global Area    1593835520 bytes
Fixed Size                     9691264 bytes
Variable Size                469762048 bytes
Database Buffers            1107296256 bytes
Redo Buffers                   7086080 bytes

contents of Memory Script:
{
   set newname for clone datafile  1 to new;
   set newname for clone datafile  3 to new;
   set newname for clone datafile  4 to new;
   set newname for clone datafile  5 to new;
   set newname for clone datafile  7 to new;
   set newname for clone datafile  8 to new;
   set newname for clone datafile  9 to new;
   backup as copy reuse
   datafile  1 from service  'cdb1.world' auxiliary format
  "/u01/oradata/CDB1/system01.dbf"   datafile
  3 from service  'cdb1.world' auxiliary format
  "/u01/oradata/CDB1/sysaux01.dbf"   datafile
  4 from service  'cdb1.world' auxiliary format
  "/u01/oradata/CDB1/undotbs01.dbf"   datafile
  5 from service  'cdb1.world' auxiliary format
  "/u01/oradata/CDB1/pdbseed/system01.dbf"   datafile
  7 from service  'cdb1.world' auxiliary format
  "/u01/oradata/CDB1/users01.dbf"   datafile
  8 from service  'cdb1.world' auxiliary format
  "/u01/oradata/CDB1/pdbseed/sysaux01.dbf"   datafile
  9 from service  'cdb1.world' auxiliary format
  "/u01/oradata/CDB1/pdbseed/undotbs01.dbf"   ;
   sql 'alter system archive log current';
}
executing Memory Script

⭐ AQUÍ COMIENZA LA COPIA DE DATOS (10-20 minutos)

Starting backup at 04-NOV-25
channel ORA_AUX_DISK_1: starting datafile copy
input datafile file number=00001 name=/u01/oradata/CDB1/system01.dbf
output file name=/u01/oradata/CDB1/system01.dbf tag=TAG20251104T172530
channel ORA_AUX_DISK_1: datafile copy complete, elapsed time: 00:02:15
channel ORA_AUX_DISK_1: starting datafile copy
input datafile file number=00003 name=/u01/oradata/CDB1/sysaux01.dbf
output file name=/u01/oradata/CDB1/sysaux01.dbf tag=TAG20251104T172532
channel ORA_AUX_DISK_1: datafile copy complete, elapsed time: 00:01:45
channel ORA_AUX_DISK_1: starting datafile copy
input datafile file number=00004 name=/u01/oradata/CDB1/undotbs01.dbf
output file name=/u01/oradata/CDB1/undotbs01.dbf tag=TAG20251104T172534
channel ORA_AUX_DISK_1: datafile copy complete, elapsed time: 00:00:35
[... continúa para todos los datafiles ...]
Finished backup at 04-NOV-25

contents of Memory Script:
{
   switch clone datafile all;
}
executing Memory Script

datafile 1 switched to datafile copy
input datafile copy RECID=1 STAMP=1234567890 file name=/u01/oradata/CDB1/system01.dbf
[... más datafiles ...]

contents of Memory Script:
{
   catalog clone archivelog  '/u01/oradata/CDB1/arch/1_125_1234567890.arc';
   switch clone archivelog all;
}
executing Memory Script

cataloged archived log
archived log file name=/u01/oradata/CDB1/arch/1_125_1234567890.arc RECID=1 STAMP=1234567891

⭐ DORECOVER: Aplicar archive logs

contents of Memory Script:
{
   set until scn  2345678;
   recover
   standby
   clone database
    delete archivelog
   ;
}
executing Memory Script

Starting recover at 04-NOV-25

starting media recovery

archived log for thread 1 with sequence 125 is already on disk as file /u01/oradata/CDB1/arch/1_125_1234567890.arc
archived log for thread 1 with sequence 126 is already on disk as file /u01/oradata/CDB1/arch/1_126_1234567891.arc
archived log file name=/u01/oradata/CDB1/arch/1_125_1234567890.arc thread=1 sequence=125
archived log file name=/u01/oradata/CDB1/arch/1_126_1234567891.arc thread=1 sequence=126
media recovery complete, elapsed time: 00:00:15
Finished recover at 04-NOV-25

Finished Duplicate Db at 04-NOV-25
```

**RMAN DUPLICATE COMPLETO - Standby database ahora existe!**

---

### 7.5. ¿Qué Se Copió?

**Datafiles del CDB:**
- `system01.dbf` - System tablespace (~800 MB)
- `sysaux01.dbf` - Sysaux tablespace (~600 MB)
- `undotbs01.dbf` - Undo tablespace (~200 MB)
- `users01.dbf` - Default user tablespace (~5 MB)
- `temp01.dbf` - Temp tablespace (~100 MB)

**Datafiles de PDB$SEED:**
- `pdbseed/system01.dbf`
- `pdbseed/sysaux01.dbf`
- `pdbseed/undotbs01.dbf`

**Datafiles de PDB1:**
- `pdb1/system01.dbf`
- `pdb1/sysaux01.dbf`
- `pdb1/undotbs01.dbf`
- `pdb1/users01.dbf` ⭐ **Contiene schema HEALTHCENTER**

**Control Files (3 copias):**
- `/u01/oradata/CDB1/control01.ctl`
- `/u01/app/oracle/fast_recovery_area/cdb1/control02.ctl`
- `/u02/fast_recovery_area/cdb1/control03.ctl`

**Online Redo Logs:**
- `redo01.log`
- `redo02.log`
- `redo03.log`

**Standby Redo Logs (creados automáticamente):**
- `standby_redo01.log`
- `standby_redo02.log`
- `standby_redo03.log`
- `standby_redo04.log`

**Archive Logs (hasta el momento):**
- Todos los archives necesarios para recuperar hasta el SCN del duplicate

**SPFILE:**
- Copia del primary con modificaciones:
  ```sql
  db_unique_name='cdb1_stby'
  log_archive_dest_1='LOCATION=/u01/oradata/CDB1/arch VALID_FOR=(ALL_LOGFILES,ALL_ROLES) DB_UNIQUE_NAME=cdb1_stby'
  fal_server='cdb1'
  fal_client='cdb1_stby'
  standby_file_management='AUTO'
  ```

**Total copiado:** ~15-25 GB (depende de datos)

---

### 7.6. Qué NO Se Copia

**Archivos temporales:**
- Se recrean localmente (temp01.dbf)

**Online Redo Logs:**
- No útiles en standby (no se pueden aplicar)
- Standby usa Standby Redo Logs

**Backups:**
- Los backups RMAN del primary NO se copian
- Se transfieren por separado vía rsync

**Logs de Alert/Trace:**
- Cada nodo tiene sus propios logs

**Password file:**
- Ya fue creado manualmente antes

**Network files:**
- tnsnames.ora, listener.ora ya creados

---

## 8. Parte 7: Flashback Database

```bash
echo "******************************************************************************"
echo "Enable FLASHBACK DATABASE on standby." `date`
echo "******************************************************************************"

sqlplus / as sysdba <<EOF
-- Check if flashback is already enabled
SET SERVEROUTPUT ON
DECLARE
    v_flashback_on VARCHAR2(3);
BEGIN
    SELECT flashback_on INTO v_flashback_on FROM v\$database;

    IF v_flashback_on = 'NO' THEN
        DBMS_OUTPUT.PUT_LINE('Flashback is OFF on standby, enabling now...');
        EXECUTE IMMEDIATE 'ALTER DATABASE FLASHBACK ON';
        DBMS_OUTPUT.PUT_LINE('Flashback enabled successfully on standby.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Flashback is already ON on standby.');
    END IF;
END;
/

-- Verify flashback is enabled
SELECT name, db_unique_name, flashback_on, log_mode
FROM v\$database;

EXIT;
EOF
```

### 8.1. ¿Qué es Flashback Database?

**Permite retroceder la database en el tiempo.**

Similar a Time Machine (Mac) o System Restore (Windows), pero para bases de datos.

**Cómo funciona:**
- Oracle guarda "flashback logs" en FRA
- Registra bloques de datos ANTES de modificarlos
- Puedes hacer `FLASHBACK DATABASE TO TIMESTAMP`
- Base de datos retrocede sin restaurar backup

---

### 8.2. ¿Por Qué en Standby?

**Para reinstatement rápido después de failover.**

**Escenario sin Flashback:**
```
1. Primary falla
2. Failover: Standby se vuelve Primary
3. Old Primary se recupera
4. Old Primary NO puede ser Standby directamente
5. Solución: Rebuild completo con RMAN DUPLICATE (10-20 min)
```

**Escenario con Flashback:**
```
1. Primary falla
2. Failover: Standby se vuelve Primary
3. Old Primary se recupera
4. FLASHBACK old primary al punto de divergencia (1-2 min)
5. Old Primary se convierte en Standby (1-2 min)
Total: 3-5 minutos vs 20 minutos
```

---

### 8.3. Verificación

```sql
SELECT flashback_on FROM v$database;

FLASHBACK_ON
------------
YES          ⭐
```

**Ubicación de Flashback Logs:**
```
/u02/fast_recovery_area/cdb1/flashback/
```

**Ver espacio usado:**
```sql
SELECT * FROM v$flashback_database_log;

OLDEST_FLASHBACK_SCN OLDEST_FLASHBACK_TIME      RETENTION_TARGET FLASHBACK_SIZE ESTIMATED_FLASHBACK_SIZE
-------------------- -------------------------  ---------------- -------------- ------------------------
           987654321 04-NOV-25 17:30:15                     1440        1048576                  2097152
```

---

## 9. Parte 8: Data Guard Broker

### 9.1. ¿Qué es Data Guard Broker?

**Framework de gestión para Data Guard.**

Sin Broker:
- Configuración manual con ALTER SYSTEM
- Switchover/Failover manual (muchos pasos)
- Monitoreo manual con queries SQL

Con Broker:
- Configuración centralizada
- Switchover con 1 comando: `SWITCHOVER TO cdb1_stby`
- Failover automático (Fast-Start Failover)
- Monitoreo integrado: `SHOW CONFIGURATION`

---

### 9.2. Habilitar Broker en Standby

```bash
echo "******************************************************************************"
echo "Enable Data Guard Broker on standby." `date`
echo "******************************************************************************"

sqlplus / as sysdba <<EOF
alter system set dg_broker_start=true;
EXIT;
EOF
```

**Parámetro:**
```sql
dg_broker_start = TRUE
```

**Inicia proceso DMON (Data Guard Monitor):**
```bash
ps aux | grep dmon_cdb1
# ora_dmon_cdb1
```

---

### 9.3. Habilitar Broker en Primary (Remoto)

```bash
echo "******************************************************************************"
echo "Enable Data Guard Broker on primary and create configuration." `date`
echo "******************************************************************************"

# Enable broker on primary
sqlplus sys/${SYS_PASSWORD}@${NODE1_DB_UNIQUE_NAME}${DB_DOMAIN_STR} as sysdba <<EOF
alter system set dg_broker_start=true;
EXIT;
EOF

# Wait for broker to initialize
sleep 10
```

**Conexión remota a primary:**
```bash
sqlplus sys/S1sPassword1!@cdb1.world as sysdba
```

**Habilita broker en primary también:**
```sql
ALTER SYSTEM SET dg_broker_start=TRUE;
```

**Espera 10 segundos:**
- Broker necesita tiempo para inicializar
- Crea archivos de configuración
- Registra databases

---

### 9.4. Crear Configuración Data Guard

```bash
# Configure broker
dgmgrl sys/${SYS_PASSWORD}@${NODE1_DB_UNIQUE_NAME}${DB_DOMAIN_STR} <<EOF
remove configuration;
create configuration dg_config as primary database is ${NODE1_DB_UNIQUE_NAME} connect identifier is ${NODE1_DB_UNIQUE_NAME}${DB_DOMAIN_STR};
add database ${NODE2_DB_UNIQUE_NAME} as connect identifier is ${NODE2_DB_UNIQUE_NAME}${DB_DOMAIN_STR};
enable configuration;
show configuration;
exit;
EOF
```

**Comando 1: Remove configuration (si existe):**
```dgmgrl
remove configuration;
```
- Elimina configuración previa (si hay)
- Permite re-ejecutar script limpiamente

**Comando 2: Create configuration:**
```dgmgrl
create configuration dg_config as
  primary database is cdb1
  connect identifier is cdb1.world;
```

**Elementos:**
- `dg_config` - Nombre de la configuración (arbitrario)
- `primary database is cdb1` - DB_UNIQUE_NAME del primary
- `connect identifier is cdb1.world` - TNS alias para conectar

**Salida:**
```
Configuration "dg_config" created with primary database "cdb1"
```

**Comando 3: Add standby database:**
```dgmgrl
add database cdb1_stby as
  connect identifier is cdb1_stby.world;
```

**Elementos:**
- `cdb1_stby` - DB_UNIQUE_NAME del standby
- `connect identifier is cdb1_stby.world` - TNS alias

**Salida:**
```
Database "cdb1_stby" added
```

**Comando 4: Enable configuration:**
```dgmgrl
enable configuration;
```

**Activa la configuración:**
- Broker comienza a gestionar ambas databases
- Inicia log transport monitoring
- Habilita comandos de switchover/failover

**Salida:**
```
Enabled.
```

**Comando 5: Show configuration:**
```dgmgrl
show configuration;
```

**Salida esperada:**
```
Configuration - dg_config

  Protection Mode: MaxPerformance
  Members:
  cdb1        - Primary database
  cdb1_stby   - Physical standby database

Fast-Start Failover:  Disabled

Configuration Status:
SUCCESS   (status updated 2 seconds ago)
```

**Nota:** Protection Mode aún es MaxPerformance (se cambia después a MAXAVAILABILITY).

---

### 9.5. Archivos de Configuración Broker

**Ubicación (ambos nodos):**
```
/u01/app/oracle/product/21.0.0/dbhome_1/dbs/dr1cdb1.dat
/u01/app/oracle/product/21.0.0/dbhome_1/dbs/dr2cdb1.dat
```

**Contenido:**
- Configuración binaria de Broker
- Metadata de configuración DG
- NO editar manualmente (usar dgmgrl)

---

## 10. Parte 9: MAXAVAILABILITY Protection Mode

### 10.1. Modos de Protección Data Guard

| Modo | Data Loss | Performance | Uso |
|------|-----------|-------------|-----|
| **MAXPERFORMANCE** | Posible | Máximo | Desarrollo/Test |
| **MAXAVAILABILITY** | Cero* | Alto | Producción ⭐ |
| **MAXPROTECTION** | Cero | Bajo | Crítico |

**Este proyecto usa MAXAVAILABILITY.**

---

### 10.2. Configurar FASTSYNC Transport

```bash
echo "******************************************************************************"
echo "Configure MAXAVAILABILITY protection mode and FASTSYNC transport." `date`
echo "******************************************************************************"
```

**Step 1: Set FASTSYNC en Primary:**
```bash
dgmgrl sys/${SYS_PASSWORD}@${NODE1_DB_UNIQUE_NAME}${DB_DOMAIN_STR} <<EOF
EDIT DATABASE ${NODE1_DB_UNIQUE_NAME} SET PROPERTY LogXptMode='FASTSYNC';
exit;
EOF
```

**LogXptMode:**
- `SYNC` - Syncrónico (commit espera confirmación standby)
- `FASTSYNC` - Syncrónico con fallback asíncrono
- `ASYNC` - Asíncrono (no espera confirmación)

**FASTSYNC = SYNC + Resilience:**
- Normalmente: síncrono (cero data loss)
- Si standby falla: automáticamente cambia a async (no detiene primary)
- Cuando standby vuelve: automáticamente vuelve a sync

---

**Step 2: Set FASTSYNC en Standby:**
```bash
dgmgrl sys/${SYS_PASSWORD}@${NODE2_DB_UNIQUE_NAME}${DB_DOMAIN_STR} <<EOF
EDIT DATABASE ${NODE2_DB_UNIQUE_NAME} SET PROPERTY LogXptMode='FASTSYNC';
exit;
EOF
```

**Ambos deben tener FASTSYNC.**

---

### 10.3. Verificar LogXptMode (con Retry)

```bash
# Function to verify LogXptMode is set correctly on a database
verify_logxptmode() {
    local db_name=$1
    local expected_mode=$2
    local max_attempts=12  # 60 seconds total (12 * 5 seconds)
    local attempt=1

    echo "Verifying LogXptMode=${expected_mode} on ${db_name}..."

    while [ $attempt -le $max_attempts ]; do
        # Query the LogXptMode property from Data Guard Broker
        local actual_mode=$(dgmgrl -silent sys/${SYS_PASSWORD}@${NODE1_DB_UNIQUE_NAME}${DB_DOMAIN_STR} <<EOF | grep "LogXptMode" | awk '{print $3}' | tr -d "'"
SHOW DATABASE VERBOSE ${db_name};
exit;
EOF
)

        if echo "$actual_mode" | grep -qi "$expected_mode"; then
            echo "[OK] LogXptMode verified as ${expected_mode} on ${db_name}"
            return 0
        fi

        echo "  Attempt ${attempt}/${max_attempts}: LogXptMode is '${actual_mode}', waiting for '${expected_mode}'..."
        sleep 5
        attempt=$((attempt + 1))
    done

    echo "[ERROR] Failed to verify LogXptMode=${expected_mode} on ${db_name} after ${max_attempts} attempts"
    return 1
}

# Verify primary LogXptMode is applied
if ! verify_logxptmode "${NODE1_DB_UNIQUE_NAME}" "FASTSYNC"; then
    echo "WARNING: Could not verify LogXptMode on primary, but continuing..."
fi
```

**Por qué el retry:**
- Broker aplica cambios de forma asíncrona
- Puede tardar varios segundos
- Sin retry, podría fallar aunque configuración sea correcta

---

### 10.4. Habilitar Apply en Standby

```bash
echo "Enabling apply on standby database..."
dgmgrl sys/${SYS_PASSWORD}@${NODE1_DB_UNIQUE_NAME}${DB_DOMAIN_STR} <<EOF
EDIT DATABASE ${NODE2_DB_UNIQUE_NAME} SET STATE='APPLY-ON';
exit;
EOF

sleep 5
```

**SET STATE='APPLY-ON':**
- Inicia MRP (Managed Recovery Process)
- Standby comienza a aplicar archive logs automáticamente
- Resultado: Standby se mantiene sincronizado

**Estados posibles:**
- `APPLY-ON` - Aplicando logs (normal) ⭐
- `APPLY-OFF` - No aplicando (para mantenimiento)
- `TRANSPORT-ON` - Solo recibe logs, no aplica
- `TRANSPORT-OFF` - Completamente desconectado

---

### 10.5. Establecer MAXAVAILABILITY Protection Mode

```bash
echo "Setting MAXAVAILABILITY protection mode..."
dgmgrl sys/${SYS_PASSWORD}@${NODE1_DB_UNIQUE_NAME}${DB_DOMAIN_STR} <<EOF
EDIT CONFIGURATION SET PROTECTION MODE AS MAXAVAILABILITY;
exit;
EOF
```

**Efecto:**
- Commits en primary esperan confirmación de standby
- Si standby no confirma (FASTSYNC), commit NO se bloquea
- Pero garantiza cero data loss en situaciones normales

---

### 10.6. Verificar Protection Level

```bash
# Function to verify protection level is MAXIMUM AVAILABILITY (not RESYNCHRONIZATION)
verify_protection_level() {
    local max_attempts=12  # 60 seconds total
    local attempt=1

    echo "Verifying protection level is MAXIMUM AVAILABILITY..."

    while [ $attempt -le $max_attempts ]; do
        # Query protection level from the primary database
        local protection_level=$(sqlplus -s / as sysdba <<EOF
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF
SELECT protection_level FROM v\$database;
EXIT;
EOF
)

        # Trim whitespace
        protection_level=$(echo "$protection_level" | tr -d ' \t\r\n')

        if [ "$protection_level" = "MAXIMUMAVAILABILITY" ]; then
            echo "[OK] Protection level verified as MAXIMUM AVAILABILITY"
            return 0
        fi

        echo "  Attempt ${attempt}/${max_attempts}: Protection level is '${protection_level}', waiting for 'MAXIMUM AVAILABILITY'..."
        sleep 5
        attempt=$((attempt + 1))
    done

    echo "[ERROR] Failed to verify MAXIMUM AVAILABILITY protection level after ${max_attempts} attempts"
    echo "  Current protection level: ${protection_level}"
    return 1
}

# Verify protection level
if ! verify_protection_level; then
    echo "WARNING: Protection level verification failed!"
    echo "The configuration may be in RESYNCHRONIZATION or MAXIMUM PERFORMANCE mode."
    echo "Check Data Guard Broker status for ORA-16627 errors."
fi
```

**Por qué verificar:**
- A veces el modo no se aplica inmediatamente
- Puede quedar en "RESYNCHRONIZATION" temporalmente
- Sin verificación, no sabríamos si configuración es correcta

**Estados posibles:**
- `MAXIMUM AVAILABILITY` - ✅ Correcto
- `MAXIMUM PERFORMANCE` - ❌ No cambió (problema)
- `RESYNCHRONIZATION` - ⚠️ Temporal (standby catching up)

---

### 10.7. Mostrar Configuración Final

```bash
echo ""
echo "Final Data Guard Broker configuration:"
dgmgrl sys/${SYS_PASSWORD}@${NODE1_DB_UNIQUE_NAME}${DB_DOMAIN_STR} <<EOF
SHOW CONFIGURATION;
SHOW DATABASE ${NODE1_DB_UNIQUE_NAME};
SHOW DATABASE ${NODE2_DB_UNIQUE_NAME};
exit;
EOF
```

**Salida esperada:**
```
Configuration - dg_config

  Protection Mode: MaxAvailability     ⭐ Cambió!
  Members:
  cdb1        - Primary database
    Transport Lag:      0 seconds (computed 1 second ago)
    Apply Lag:          0 seconds (computed 1 second ago)

  cdb1_stby   - Physical standby database
    Transport Lag:      0 seconds (computed 1 second ago)
    Apply Lag:          0 seconds (computed 1 second ago)

Fast-Start Failover:  Disabled

Configuration Status:
SUCCESS
```

**Database cdb1 details:**
```
Database - cdb1

  Role:               PRIMARY
  Intended State:     TRANSPORT-ON
  Transport Lag:      0 seconds
  Apply Lag:          0 seconds
  Average Apply Rate: 0.00 KByte/s
  Real Time Query:    OFF

  Database Status:
  SUCCESS
```

**Database cdb1_stby details:**
```
Database - cdb1_stby

  Role:               PHYSICAL STANDBY
  Intended State:     APPLY-ON           ⭐
  Transport Lag:      0 seconds
  Apply Lag:          0 seconds
  Average Apply Rate: 0.00 KByte/s
  Real Time Query:    ON
  Instance(s):
    cdb1

  Database Status:
  SUCCESS
```

---

## 11. Parte 10: Validación Final

### 11.1. Validar Databases

```bash
echo "******************************************************************************"
echo "Validate Data Guard configuration." `date`
echo "******************************************************************************"

sleep 30  # Esperar que configuración se estabilice

dgmgrl sys/${SYS_PASSWORD}@${NODE1_DB_UNIQUE_NAME}${DB_DOMAIN_STR} <<EOF
validate database ${NODE1_DB_UNIQUE_NAME};
validate database ${NODE2_DB_UNIQUE_NAME};
validate database ${NODE2_DB_UNIQUE_NAME} spfile;
validate static connect identifier for ${NODE1_DB_UNIQUE_NAME};
validate static connect identifier for ${NODE2_DB_UNIQUE_NAME};
exit;
EOF
```

**Comandos de validación:**

**1. validate database cdb1:**
```
Database Role:     Primary database
  Ready for Switchover:  Yes
  Managed by Clusterware:  No

  Primary Log Files:  OK
  Standby Redo Log Files:  OK
  Current Log File Groups Configuration:  OK
  Future Log File Groups Configuration:  OK
  Log Transfer Configuration:  OK
  Redo Log Archival Configuration:  OK
```

**2. validate database cdb1_stby:**
```
Database Role:    Physical standby database
  Primary Database:  cdb1

  Ready for Switchover:  Yes
  Ready for Failover:  Yes (Primary Running)

  Managed by Clusterware:  No
  Valid Static Connect Identifier:  Yes

  Standby Redo Log Files:  OK
  Current Log File Groups Configuration:  OK
  Future Log File Groups Configuration:  OK
  Redo Log Archival Configuration:  OK
```

**3. validate database cdb1_stby spfile:**
- Verifica que SPFILE esté correctamente configurado
- Parámetros Data Guard son correctos

**4. validate static connect identifier:**
- Verifica que tnsnames.ora/listener.ora permiten conexión SYSDBA
- Crítico para Broker y RMAN

---

### 11.2. Verificar Flashback en Ambas Databases

```bash
echo "******************************************************************************"
echo "Verify FLASHBACK DATABASE is enabled on both databases." `date`
echo "******************************************************************************"

echo "Checking flashback status on PRIMARY..."
sqlplus -s sys/${SYS_PASSWORD}@${NODE1_DB_UNIQUE_NAME}${DB_DOMAIN_STR} as sysdba <<EOF
SET LINESIZE 180
COLUMN name FORMAT A15
COLUMN db_unique_name FORMAT A20
COLUMN flashback_on FORMAT A12
COLUMN log_mode FORMAT A12
SELECT name, db_unique_name, flashback_on, log_mode
FROM v\$database;
EXIT;
EOF

echo ""
echo "Checking flashback status on STANDBY..."
sqlplus -s / as sysdba <<EOF
SET LINESIZE 180
COLUMN name FORMAT A15
COLUMN db_unique_name FORMAT A20
COLUMN flashback_on FORMAT A12
COLUMN log_mode FORMAT A12
SELECT name, db_unique_name, flashback_on, log_mode
FROM v\$database;
EXIT;
EOF
```

**Salida esperada (Primary):**
```
NAME            DB_UNIQUE_NAME       FLASHBACK_ON LOG_MODE
--------------- -------------------- ------------ ------------
CDB1            cdb1                 YES          ARCHIVELOG
```

**Salida esperada (Standby):**
```
NAME            DB_UNIQUE_NAME       FLASHBACK_ON LOG_MODE
--------------- -------------------- ------------ ------------
CDB1            cdb1_stby            YES          ARCHIVELOG
```

**Ambos deben tener Flashback ON.**

---

### 11.3. Resumen Final del Script

```bash
echo ""
echo "Data Guard Synchronization Status:"
echo "- Standby database is managed by Data Guard Broker"
echo "- Custom schema (${APP_SCHEMA}) was created on primary before standby creation"
echo "- RMAN DUPLICATE copied all data including custom schema to standby"
echo "- Ongoing changes are replicated via Data Guard log transport and apply"
echo "- Use '/home/oracle/automation/verify_dataguard.sh' for detailed verification"
echo ""

echo "******************************************************************************"
echo "STANDBY database creation and configuration complete!" `date`
echo "******************************************************************************"
echo ""
echo "Data Guard Configuration Summary:"
echo "- Primary: ${NODE1_DB_UNIQUE_NAME} on ${NODE1_FQ_HOSTNAME}"
echo "- Standby: ${NODE2_DB_UNIQUE_NAME} on ${NODE2_FQ_HOSTNAME}"
echo "- Protection Mode: MAXAVAILABILITY"
echo "- Transport Mode: FASTSYNC (synchronous)"
echo "- Archive Lag Target: ${ARCHIVE_LAG_TARGET} seconds (5 minutes)"
echo "- Redo Log Size: ${REDO_LOG_SIZE} MB"
echo "- Flashback Database: ENABLED (allows fast reinstatement after failover)"
echo "- Custom schema has been replicated to standby"
echo ""
echo "Use 'dgmgrl sys/${SYS_PASSWORD}@${NODE1_DB_UNIQUE_NAME}${DB_DOMAIN_STR}' to manage Data Guard"
```

---

## 12. Detalles Técnicos de RMAN DUPLICATE

### 12.1. Archivos Transferidos por Red

**Durante RMAN DUPLICATE, estos datos viajan por red:**

1. **Password File** (primero)
2. **Control File** (copia del primary)
3. **SPFILE** (con modificaciones)
4. **Todos los Datafiles:**
   - system01.dbf (~800 MB)
   - sysaux01.dbf (~600 MB)
   - undotbs01.dbf (~200 MB)
   - users01.dbf (~5 MB)
   - temp01.dbf (recreado, no copiado)
   - pdbseed/system01.dbf
   - pdbseed/sysaux01.dbf
   - pdbseed/undotbs01.dbf
   - pdb1/system01.dbf
   - pdb1/sysaux01.dbf
   - pdb1/undotbs01.dbf
   - pdb1/users01.dbf ⭐ **Contiene HEALTHCENTER schema**

5. **Archive Logs** (para recovery)

**Total transferido: ~15-25 GB**

---

### 12.2. Ancho de Banda y Tiempo

**En red local (1 Gbps):**
- Throughput real: ~100 MB/s
- 20 GB / 100 MB/s = 200 segundos ≈ 3-4 minutos (solo copia)
- Recovery (archive logs): +2-3 minutos
- Overhead RMAN: +2-3 minutos
- **Total: ~10-15 minutos**

**En red lenta (100 Mbps):**
- Throughput: ~10 MB/s
- 20 GB / 10 MB/s = 2000 segundos ≈ 35 minutos
- **Total: ~40-50 minutos**

**Este proyecto (VirtualBox host-only):**
- Velocidad: Similar a local (~1 Gbps virtual)
- **Tiempo típico: 10-20 minutos**

---

### 12.3. Compresión durante DUPLICATE

**RMAN puede comprimir durante transfer:**
```rman
duplicate target database
  for standby
  from active database
  dorecover
  using compressed backupset  -- ⭐ Opción de compresión
  spfile ...
```

**Este proyecto NO usa compresión:**
- Red local es rápida
- Compresión añade CPU overhead
- Transferencia sin comprimir es más rápida en LAN

**Cuándo usar compresión:**
- Red lenta (< 100 Mbps)
- Enlaces WAN
- Conexiones limitadas

---

### 12.4. Troubleshooting RMAN DUPLICATE

Ver sección 13 para troubleshooting completo.

---

## 13. Troubleshooting Completo

### Error: ORA-01017: invalid username/password

**Síntoma:**
```
RMAN-00571: ===========================================================
RMAN-00569: =============== ERROR MESSAGE STACK FOLLOWS ===============
RMAN-00571: ===========================================================
RMAN-04006: error from auxiliary database: ORA-01017: invalid username/password; logon denied
```

**Causas:**
1. Password de SYS diferente entre primary y standby
2. Password file no coincide
3. Password file corrupto

**Solución:**
```bash
# Verificar password file en standby
ls -l $ORACLE_HOME/dbs/orapwcdb1

# Recrear password file con mismo password que primary
orapwd file=$ORACLE_HOME/dbs/orapwcdb1 password=S1sPassword1! entries=10 format=12 force=y
```

---

### Error: ORA-12170: TNS:Connect timeout occurred

**Síntoma:**
```
ORA-12170: TNS:Connect timeout occurred
```

**Causas:**
1. Primary listener no está corriendo
2. Primary database no está OPEN
3. tnsnames.ora incorrecto
4. Firewall bloqueando puerto 1521

**Solución:**
```bash
# Verificar primary está corriendo
vagrant ssh primary -c "ps aux | grep pmon"

# Verificar listener en primary
vagrant ssh primary -c "lsnrctl status"

# Verificar DB está OPEN
vagrant ssh primary -c "echo 'SELECT open_mode FROM v\$database;' | sqlplus -s / as sysdba"

# Test tnsping
tnsping cdb1.world
```

---

### Error: RMAN-03002: failure of Duplicate Db command

**Síntoma:**
```
RMAN-03002: failure of Duplicate Db command at 11/04/2025 17:30:00
RMAN-05501: aborting duplication of target database
RMAN-03015: error occurred in stored script Memory Script
```

**Causas múltiples:** Ver mensajes adicionales para detalles.

**Solución general:**
```bash
# Ver alert log de standby
tail -100 /u01/app/oracle/diag/rdbms/cdb1_stby/cdb1/trace/alert_cdb1.log

# Re-ejecutar script desde inicio
vagrant provision standby --provision-with root_setup
```

---

### Error: ORA-01578: ORACLE data block corrupted

**Síntoma:**
```
ORA-01578: ORACLE data block corrupted (file # 1, block # 12345)
ORA-01110: data file 1: '/u01/oradata/CDB1/system01.dbf'
```

**Causa:**
- Corrupción durante transferencia de red
- Problema de hardware en primary

**Solución:**
```bash
# En primary: verificar integridad
rman target / <<EOF
BACKUP VALIDATE DATABASE;
EOF

# Si hay corrupción, reparar primero en primary
```

---

### Error: Protection Mode queda en MAXIMUM PERFORMANCE

**Síntoma:**
```
SHOW CONFIGURATION muestra:
Protection Mode: MaxPerformance   ❌ Debería ser MaxAvailability
```

**Causa:**
- LogXptMode no se aplicó correctamente
- Standby no está sincronizado

**Solución:**
```bash
# Verificar LogXptMode
dgmgrl / <<EOF
SHOW DATABASE cdb1 LogXptMode;
SHOW DATABASE cdb1_stby LogXptMode;
EOF

# Si no es FASTSYNC, re-aplicar
dgmgrl / <<EOF
EDIT DATABASE cdb1 SET PROPERTY LogXptMode='FASTSYNC';
EDIT DATABASE cdb1_stby SET PROPERTY LogXptMode='FASTSYNC';
EDIT CONFIGURATION SET PROTECTION MODE AS MAXAVAILABILITY;
EOF
```

---

### Verificación Post-Despliegue

**Script completo de verificación:**
```bash
vagrant ssh standby -c "/home/oracle/automation/verify_dataguard.sh"
```

Ver [90-monitoreo-diario.md](../../operaciones/90-monitoreo-diario.md) para detalles.

---

## Resumen Final

### Este Script Es el Corazón del Standby

**Sin este script:**
- No hay standby database
- No hay Data Guard
- No hay alta disponibilidad

**Con este script:**
- ✅ Standby database creado (copia exacta de primary)
- ✅ Schema HEALTHCENTER replicado completamente
- ✅ Data Guard configurado con MAXAVAILABILITY
- ✅ Replicación sincrónica activa (FASTSYNC)
- ✅ Flashback habilitado (reinstatement rápido)
- ✅ Broker configurado (gestión centralizada)
- ✅ Sistema listo para producción

### Tiempo Total

```
Configuración red:      5 min
Directorios:            1 min
Password file:          0.5 min
Auxiliary instance:     1 min
Conectividad:           0.5 min
🔥 RMAN DUPLICATE:     12 min  ⭐ (lo más largo)
Flashback:              1 min
Data Guard Broker:      3 min
MAXAVAILABILITY:        2 min
Validación:             1 min
────────────────────────────────
TOTAL:              ~27 min
```

### Archivos Relacionados

- **Anterior:** [56-install-oracle.md](56-install-oracle.md)
- **Siguiente:** [58-setup-automation.md](58-setup-automation.md)
- **Crítico:** Este documento (57) es el más importante
- **Referencia:** [81-data-guard-conceptos.md](../../conceptos-avanzados/81-data-guard-conceptos.md)

---

**Siguiente:** [58 - Setup de Scripts de Automatización](58-setup-automation.md)

Este es el script más crítico y complejo de todo el despliegue standby. RMAN DUPLICATE copia toda la database vía red, y Data Guard Broker la configura para alta disponibilidad con cero pérdida de datos.
