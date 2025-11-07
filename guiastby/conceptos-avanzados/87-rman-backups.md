# 📚 Conceptos Avanzados: RMAN Backups y Recovery

**Archivo:** `conceptos-avanzados/87-rman-backups.md`
**Propósito:** Documentación profunda sobre RMAN (Recovery Manager) y estrategias de backup/recovery
**Parte de:** Sistema de Alta Disponibilidad Oracle 21c Data Guard
**Requisitos:** Haber leído 83-archive-logs.md, 84-flashback-database.md

---

## 📋 Tabla de Contenidos

1. [Introducción a RMAN](#introducción-a-rman)
2. [Arquitectura de RMAN](#arquitectura-de-rman)
3. [Tipos de Backups](#tipos-de-backups)
4. [Configuración de RMAN](#configuración-de-rman)
5. [Operaciones de Backup](#operaciones-de-backup)
6. [Operaciones de Restore y Recover](#operaciones-de-restore-y-recover)
7. [RMAN DUPLICATE para Data Guard](#rman-duplicate-para-data-guard)
8. [Estrategias de Backup](#estrategias-de-backup)
9. [Troubleshooting](#troubleshooting)
10. [Conclusiones](#conclusiones)

---

## 🎯 Introducción a RMAN

### ¿Qué es RMAN?

**RMAN (Recovery Manager)** es la herramienta oficial de Oracle para realizar backups y recovery de bases de datos.

**Analogía:**
- RMAN es como un sistema de "copias de seguridad inteligente"
- Conoce la estructura interna de Oracle (bloques, archivos, tablespaces)
- Puede hacer backups incrementales (solo bloques modificados)
- Detecta bloques corruptos durante el backup

### ¿Por qué Usar RMAN?

| Aspecto | RMAN | Copias del SO (cp, tar) |
|---------|------|------------------------|
| **Consistencia** | Garantizada (no requiere shutdown) | Requiere shutdown IMMEDIATE |
| **Compresión** | Sí (compresión integrada) | No (a menos que uses tar.gz) |
| **Incremental** | Sí (solo bloques modificados) | No (siempre full copy) |
| **Block-level corruption detection** | Sí (detecta corrupción durante backup) | No |
| **Restore granular** | Sí (tablespace, datafile, block) | No (todo o nada) |
| **Catálogo** | Sí (registro de backups) | No (debes trackear manualmente) |
| **Integración con Data Guard** | Sí (RMAN DUPLICATE) | No |

### RMAN en Nuestro Proyecto

RMAN se usa para:

1. **Backups diarios automatizados** (script 71-rman-daily-backup.md):
   - Full backup de database + archive logs
   - Ejecución: 1 AM diario (cron)
   - Retención: 7 días

2. **Creación del standby** (script 57-rman-duplicate.md):
   - RMAN DUPLICATE FROM ACTIVE DATABASE
   - Crea standby físico sin backup manual

3. **Recovery testing** (opcional):
   - Restore/recover en caso de corrupción
   - Point-in-time recovery (PITR)

---

## 🏗️ Arquitectura de RMAN

### Componentes de RMAN

```
┌────────────────────────────────────────────────────────────┐
│                     CLIENTE RMAN                           │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Comando: rman target /                              │  │
│  │  Script RMAN o comandos interactivos                 │  │
│  └────────────┬─────────────────────────────────────────┘  │
└───────────────┼────────────────────────────────────────────┘
                │
                │ Conexión SQL*Net
                │
┌───────────────▼────────────────────────────────────────────┐
│                  TARGET DATABASE                           │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  RMAN Server Process (sesión SQL dedicada)          │  │
│  │  - Lee metadata de control file                     │  │
│  │  - Coordina backups y restores                      │  │
│  └────────────┬─────────────────────────────────────────┘  │
│               │                                            │
│               ▼                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Control File (Catálogo integrado)                  │  │
│  │  - Registro de backups                              │  │
│  │  - Metadata de archivos                             │  │
│  │  - Información de SCNs                              │  │
│  └────────────┬─────────────────────────────────────────┘  │
│               │                                            │
│               ▼                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Channel Processes (procesos background)            │  │
│  │  - ORA_DISK_1, ORA_DISK_2, etc.                     │  │
│  │  - Leen bloques de datafiles                        │  │
│  │  - Escriben a backup destination                    │  │
│  └────────────┬─────────────────────────────────────────┘  │
└───────────────┼────────────────────────────────────────────┘
                │
                ▼
┌────────────────────────────────────────────────────────────┐
│              BACKUP DESTINATION                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Fast Recovery Area (FRA)                           │  │
│  │  /u01/app/oracle/fast_recovery_area/CDB1/           │  │
│  │                                                      │  │
│  │  backupset/                                         │  │
│  │    ├── o1_mf_nnndf_TAG20251104_m4k2x7hp_.bkp       │  │
│  │    ├── o1_mf_nnsnf_TAG20251104_m4k2x8jq_.bkp       │  │
│  │    └── ...                                          │  │
│  │                                                      │  │
│  │  archivelog/                                        │  │
│  │    ├── 2025_11_04/                                  │  │
│  │    │   ├── o1_mf_1_123_m4k2x9kr_.arc               │  │
│  │    │   └── ...                                      │  │
│  └──────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│         BACKUP REMOTO (opcional)                           │
│  /u02/backups/ (primary) → rsync → /u02/backups/ (standby)│
└────────────────────────────────────────────────────────────┘
```

### Procesos Clave

#### 1. **RMAN Client Process**

- CLI que interpretas comandos RMAN
- Se conecta al target database
- Envía comandos al server process

```bash
# Iniciar RMAN
rman target /

# Conectado a:
# Recovery Manager: Release 21.0.0.0.0 - Production on Mon Nov 4 10:30:15 2025
# connected to target database: CDB1 (DBID=1234567890)
```

#### 2. **Server Process**

- Sesión SQL dedicada en el target database
- Lee metadata del control file
- Coordina channels para I/O

#### 3. **Channels**

- Procesos que realizan I/O físico
- Tipos:
  - **DISK**: Backup a disco (nuestro proyecto usa solo DISK)
  - **SBT_TAPE**: Backup a cinta o cloud (no usado)
- Paralelización: Múltiples channels = backup más rápido

```rman
-- Configurar 2 channels (parallelism)
CONFIGURE DEVICE TYPE DISK PARALLELISM 2;

-- Durante backup:
-- Channel 1: Copia datafiles 1, 3, 5, ...
-- Channel 2: Copia datafiles 2, 4, 6, ...
```

#### 4. **Control File (Catálogo Integrado)**

- Registro de todos los backups realizados
- Metadata: qué archivos se respaldaron, cuándo, SCNs, etc.
- Alternativa: Recovery Catalog (database separada - no usada en nuestro proyecto)

```rman
-- Ver backups registrados en control file
LIST BACKUP SUMMARY;

-- Salida:
-- BS Key  Type LV Size       Device Type Elapsed Time Completion Time
-- ------- ---- -- ---------- ----------- ------------ ---------------
-- 1       Full    2.50G      DISK        00:15:23     04-NOV-25
-- 2       Full    2.48G      DISK        00:14:56     03-NOV-25
```

---

## 📦 Tipos de Backups

### 1. Full Backup (Backup Completo)

Copia **todos** los bloques de datos utilizados en los datafiles, estén modificados o no.

```rman
BACKUP DATABASE;

-- Copia:
-- - Todos los datafiles (incluye SYSTEM, SYSAUX, UNDO, USER tablespaces)
-- - Control file
-- - SPFILE (opcional)
```

**Ventajas:**
- Restore rápido (solo necesitas el full backup + archive logs)
- Simple de gestionar

**Desventajas:**
- Tamaño grande (GB a TB)
- Tiempo largo (20-60 minutos en nuestro proyecto)

### 2. Incremental Backup (Backup Incremental)

Copia **solo bloques modificados** desde el último backup.

#### Incremental Level 0

- Equivalente a full backup, pero sirve como base para incrementales

```rman
BACKUP INCREMENTAL LEVEL 0 DATABASE;
```

#### Incremental Level 1

- **Differential** (default): Bloques modificados desde el último backup (Level 0 o Level 1)
- **Cumulative**: Bloques modificados desde el último Level 0

```rman
-- Diferencial (solo cambios desde ayer)
BACKUP INCREMENTAL LEVEL 1 DATABASE;

-- Cumulativo (todos los cambios desde Level 0)
BACKUP INCREMENTAL LEVEL 1 CUMULATIVE DATABASE;
```

**Ejemplo de estrategia incremental:**

```
Domingo:   Level 0 (full incremental)   → 2 GB
Lunes:     Level 1 (diferencial)        → 200 MB (cambios domingo-lunes)
Martes:    Level 1 (diferencial)        → 180 MB (cambios lunes-martes)
Miércoles: Level 1 (diferencial)        → 220 MB (cambios martes-miércoles)
...
```

**Ventaja:** Backups diarios pequeños (200-300 MB vs 2 GB)
**Desventaja:** Restore más complejo (necesitas Level 0 + todos los Level 1 + archive logs)

### 3. Archive Log Backup

Backup de archive logs (separado o junto con database backup).

```rman
-- Solo archive logs
BACKUP ARCHIVELOG ALL;

-- Database + archive logs (nuestro proyecto)
BACKUP DATABASE PLUS ARCHIVELOG;
```

**Qué hace `PLUS ARCHIVELOG`:**
```
1. BACKUP ARCHIVELOG ALL;           (respalda archive logs existentes)
2. ALTER SYSTEM SWITCH LOGFILE;     (fuerza log switch)
3. BACKUP DATABASE;                 (respalda database)
4. BACKUP ARCHIVELOG ALL;           (respalda nuevos archive logs generados durante backup)
```

### 4. Compressed Backup

Comprime backupsets para ahorrar espacio.

```rman
-- Backup comprimido (nuestro proyecto usa esto)
BACKUP AS COMPRESSED BACKUPSET DATABASE PLUS ARCHIVELOG;

-- Compresión típica: 40-60%
-- Ejemplo: 2 GB → 800 MB - 1.2 GB
```

**Algoritmo de compresión:**
- Oracle usa algoritmo propietario (similar a gzip)
- CPU overhead moderado (10-20% más lento)
- Ahorro de espacio significativo

---

## ⚙️ Configuración de RMAN

### Parámetros de Configuración Persistente

RMAN permite configurar parámetros que se aplican a todos los backups futuros:

```rman
-- Ver configuración actual
SHOW ALL;

-- Resultado típico:
-- CONFIGURE RETENTION POLICY TO REDUNDANCY 1;
-- CONFIGURE BACKUP OPTIMIZATION OFF;
-- CONFIGURE DEFAULT DEVICE TYPE TO DISK;
-- CONFIGURE CONTROLFILE AUTOBACKUP ON;
-- CONFIGURE DEVICE TYPE DISK PARALLELISM 1 BACKUP TYPE TO BACKUPSET;
-- CONFIGURE COMPRESSION ALGORITHM 'BASIC';
-- ...
```

### Configuraciones Importantes en Nuestro Proyecto

```rman
-- 1. Retención: Mantener backups por 7 días
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 7 DAYS;

-- Significado:
-- - RMAN marca backups obsoletos si son más antiguos que 7 días
-- - DELETE OBSOLETE eliminará estos backups

-- 2. Autobackup de Control File
CONFIGURE CONTROLFILE AUTOBACKUP ON;

-- Significado:
-- - Después de cada backup, RMAN automáticamente respalda el control file
-- - Crítico para recovery: necesitas control file para restaurar

-- 3. Device Type: DISK
CONFIGURE DEFAULT DEVICE TYPE TO DISK;

-- 4. Backup Optimization
CONFIGURE BACKUP OPTIMIZATION ON;

-- Significado:
-- - Si un archivo no ha cambiado desde último backup, RMAN lo omite
-- - Acelera backups incrementales

-- 5. Compression
CONFIGURE COMPRESSION ALGORITHM 'BASIC';

-- Algoritmos disponibles:
-- - BASIC: Compresión estándar (gratuito)
-- - MEDIUM: Mejor compresión (requiere Advanced Compression license)
-- - HIGH: Máxima compresión (requiere Advanced Compression license)

-- 6. Channels (paralelismo)
CONFIGURE DEVICE TYPE DISK PARALLELISM 1;

-- 1 = Un solo canal (un proceso I/O)
-- 2 = Dos canales (backup paralelo, más rápido)
-- Nuestro proyecto usa 1 (suficiente para databases pequeñas)

-- 7. Ubicación de backups (Fast Recovery Area)
CONFIGURE CHANNEL DEVICE TYPE DISK FORMAT '/u01/app/oracle/fast_recovery_area/CDB1/%U';

-- %U = Placeholder para nombre único generado automáticamente
```

### Aplicar Configuración Inicial

En nuestro proyecto, la configuración se aplica durante el despliegue:

```bash
#!/bin/bash
# Script de configuración inicial RMAN

rman target / <<EOF
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 7 DAYS;
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE DEFAULT DEVICE TYPE TO DISK;
CONFIGURE BACKUP OPTIMIZATION ON;
CONFIGURE COMPRESSION ALGORITHM 'BASIC';
CONFIGURE DEVICE TYPE DISK PARALLELISM 1;
EXIT;
EOF
```

---

## 💾 Operaciones de Backup

### Backup Diario (Script 71)

**Script:** `/home/oracle/automation/rman_daily_backup.sh`
**Cron:** `0 1 * * *` (1 AM diario)

```bash
#!/bin/bash
# RMAN Daily Backup Script
# Ejecuta backup completo de database + archive logs

export ORACLE_HOME=/u01/app/oracle/product/21c/dbhome_1
export ORACLE_SID=cdb1
export PATH=$ORACLE_HOME/bin:$PATH

# Log file con timestamp
LOG_FILE="/home/oracle/logs/rman_backup_$(date +%Y%m%d_%H%M%S).log"

# Ejecutar RMAN backup
rman target / <<EOF | tee $LOG_FILE
-- Backup database + archive logs
BACKUP AS COMPRESSED BACKUPSET
  DATABASE
  PLUS ARCHIVELOG
  DELETE INPUT;

-- DELETE INPUT: Elimina archive logs después de respaldarlos
-- (libera espacio en FRA)

-- Limpiar backups obsoletos (> 7 días)
DELETE NOPROMPT OBSOLETE;

-- Limpiar archive logs antiguos (> 7 días)
DELETE NOPROMPT ARCHIVELOG ALL COMPLETED BEFORE 'SYSDATE-7';

-- Verificar integridad del backup
LIST BACKUP SUMMARY;

-- Crosscheck (verificar que backups físicos existen)
CROSSCHECK BACKUP;
CROSSCHECK ARCHIVELOG ALL;

-- Eliminar backups expirados (referenciados en catálogo pero no existen físicamente)
DELETE NOPROMPT EXPIRED BACKUP;
DELETE NOPROMPT EXPIRED ARCHIVELOG ALL;

EXIT;
EOF

# Transferir backup al standby via rsync (para redundancia geográfica)
rsync -avz --delete /u01/app/oracle/fast_recovery_area/CDB1/backupset/ \
      oracle@ol8-21-dg2:/u02/backups/primary/

echo "Backup completado: $(date)" >> $LOG_FILE
```

**Salida esperada:**

```
Starting backup at 04-NOV-25
current log archived
allocated channel: ORA_DISK_1
channel ORA_DISK_1: SID=123 device type=DISK
channel ORA_DISK_1: starting compressed full datafile backup set
channel ORA_DISK_1: specifying datafile(s) in backup set
input datafile file number=00001 name=/u01/app/oracle/oradata/CDB1/system01.dbf
input datafile file number=00003 name=/u01/app/oracle/oradata/CDB1/sysaux01.dbf
input datafile file number=00004 name=/u01/app/oracle/oradata/CDB1/undotbs01.dbf
...
channel ORA_DISK_1: starting piece 1 at 04-NOV-25
channel ORA_DISK_1: finished piece 1 at 04-NOV-25
piece handle=/u01/app/oracle/fast_recovery_area/CDB1/backupset/2025_11_04/o1_mf_nnndf_TAG20251104T010000_m4k2x7hp_.bkp tag=TAG20251104T010000 comment=NONE
channel ORA_DISK_1: backup set complete, elapsed time: 00:15:23
Finished backup at 04-NOV-25

Starting backup at 04-NOV-25
current log archived
channel ORA_DISK_1: starting compressed archived log backup set
...
Finished backup at 04-NOV-25

Starting Control File and SPFILE Autobackup at 04-NOV-25
piece handle=/u01/app/oracle/fast_recovery_area/CDB1/autobackup/2025_11_04/o1_mf_s_1234567890_m4k2x9kr_.bkp comment=NONE
Finished Control File and SPFILE Autobackup at 04-NOV-25
```

### Backup Manual Ad-Hoc

```bash
# Conectarse a RMAN
rman target /

# Backup full simple
RMAN> BACKUP DATABASE;

# Backup comprimido con archive logs
RMAN> BACKUP AS COMPRESSED BACKUPSET DATABASE PLUS ARCHIVELOG;

# Backup de tablespace específico
RMAN> BACKUP TABLESPACE users;

# Backup incremental
RMAN> BACKUP INCREMENTAL LEVEL 0 DATABASE;
RMAN> BACKUP INCREMENTAL LEVEL 1 DATABASE;

# Solo control file y SPFILE
RMAN> BACKUP CURRENT CONTROLFILE;
RMAN> BACKUP SPFILE;
```

---

## 🔄 Operaciones de Restore y Recover

### Conceptos: Restore vs Recover

| Operación | Qué Hace | Ejemplo |
|-----------|----------|---------|
| **RESTORE** | Copia archivos desde backup a su ubicación original | Restaura datafiles perdidos o corruptos |
| **RECOVER** | Aplica archive logs y redo logs para llevar database a un SCN específico | Sincroniza datafiles restaurados con estado actual |

**Proceso típico:**
```
1. RESTORE: Copia datafiles desde backup (estado de hace 1 día)
2. RECOVER: Aplica archive logs (actualiza datafiles al estado de hace 1 hora)
3. OPEN: Abre database (requiere redo logs para llegar al estado actual)
```

### Escenario 1: Restore Completo (Database Perdida)

**Situación:** Disco de datos falla, todos los datafiles perdidos

**Solución:**

```bash
# 1. Shutdown database (si aún está up)
sqlplus / as sysdba <<EOF
SHUTDOWN ABORT;
EXIT;
EOF

# 2. Startup en MOUNT (para restore)
sqlplus / as sysdba <<EOF
STARTUP MOUNT;
EXIT;
EOF

# 3. Restore y Recover con RMAN
rman target / <<EOF
-- Restaurar todos los datafiles desde último backup
RESTORE DATABASE;

-- Aplicar archive logs para actualizar
RECOVER DATABASE;

-- Abrir database (con RESETLOGS si fue incomplete recovery)
ALTER DATABASE OPEN RESETLOGS;

EXIT;
EOF
```

**Tiempo estimado:**
- RESTORE: 15-30 minutos (copia 2-3 GB desde backup)
- RECOVER: 5-15 minutos (aplica archive logs de 1 día)
- Total: 20-45 minutos

### Escenario 2: Restore de Tablespace Específico

**Situación:** Tablespace USERS corrupto, resto de database OK

**Solución:**

```rman
-- 1. Poner tablespace offline
SQL "ALTER TABLESPACE users OFFLINE IMMEDIATE";

-- 2. Restaurar datafiles del tablespace
RESTORE TABLESPACE users;

-- 3. Recuperar (aplicar archive logs)
RECOVER TABLESPACE users;

-- 4. Poner tablespace online
SQL "ALTER TABLESPACE users ONLINE";
```

**Ventaja:** Database sigue accesible (solo tablespace USERS está offline)

### Escenario 3: Point-in-Time Recovery (PITR)

**Situación:** Usuario borró tabla crítica a las 14:30, quieres recuperar database a las 14:25

**Solución:**

```bash
# 1. Shutdown y mount
sqlplus / as sysdba <<EOF
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
EXIT;
EOF

# 2. Restore y recover hasta timestamp específico
rman target / <<EOF
RESTORE DATABASE;

RECOVER DATABASE UNTIL TIME "TO_DATE('2025-11-04 14:25:00', 'YYYY-MM-DD HH24:MI:SS')";

-- Abrir con RESETLOGS (crea nueva incarnation)
ALTER DATABASE OPEN RESETLOGS;

EXIT;
EOF
```

**Consecuencia:** Pierdes todas las transacciones después de 14:25

**Alternativa:** Flashback Database (más rápido) - ver `84-flashback-database.md`

### Escenario 4: Block-Level Recovery

**Situación:** Un bloque específico corrupto (no todo el datafile)

**Solución:**

```rman
-- Recuperar bloque específico
RECOVER DATAFILE 4 BLOCK 123;

-- Ventaja: Database sigue online, solo el bloque se repara
```

---

## 🔁 RMAN DUPLICATE para Data Guard

### ¿Qué es RMAN DUPLICATE?

Crea una **copia exacta** de la database primary en otra máquina, específicamente para crear un standby físico.

**Métodos:**

1. **DUPLICATE FROM ACTIVE DATABASE** (nuestro proyecto):
   - Copia directamente desde primary sin backup previo
   - Usa red (SQL*Net) para transferir bloques
   - Más lento pero no requiere espacio de backup

2. **DUPLICATE FROM BACKUPSET**:
   - Usa backupsets existentes
   - Más rápido si backups están en disco rápido
   - Requiere copiar backupsets al standby primero

### RMAN DUPLICATE en Nuestro Proyecto (Script 57)

**Script:** `/vagrant/2-Standby/scripts/standby/rman_duplicate.sh`

```bash
#!/bin/bash
# RMAN DUPLICATE - Crear standby físico desde primary activo

export ORACLE_HOME=/u01/app/oracle/product/21c/dbhome_1
export ORACLE_SID=cdb1_stby
export PATH=$ORACLE_HOME/bin:$PATH

# 1. Crear directorios necesarios en standby
mkdir -p /u01/app/oracle/oradata/CDB1_STBY
mkdir -p /u01/app/oracle/fast_recovery_area/CDB1_STBY
mkdir -p /u01/app/oracle/admin/cdb1_stby/adump

# 2. Crear SPFILE inicial (mínimo para NOMOUNT)
sqlplus / as sysdba <<EOF
CREATE SPFILE FROM PFILE='/vagrant_config/init_standby.ora';
STARTUP NOMOUNT;
EXIT;
EOF

# 3. Ejecutar RMAN DUPLICATE
rman target sys/S1sPassword1!@cdb1 auxiliary / <<EOF
RUN {
  ALLOCATE CHANNEL prmy1 DEVICE TYPE DISK;
  ALLOCATE CHANNEL prmy2 DEVICE TYPE DISK;
  ALLOCATE AUXILIARY CHANNEL stby DEVICE TYPE DISK;

  DUPLICATE TARGET DATABASE
    FOR STANDBY
    FROM ACTIVE DATABASE
    DORECOVER
    SPFILE
      SET db_unique_name='cdb1_stby' COMMENT 'Standby unique name'
      SET fal_server='cdb1' COMMENT 'Fetch Archive Log server'
      SET fal_client='cdb1_stby' COMMENT 'Fetch Archive Log client'
      SET standby_file_management='AUTO' COMMENT 'Auto manage standby files'
      SET log_archive_config='DG_CONFIG=(cdb1,cdb1_stby)'
      SET log_archive_dest_1='LOCATION=/u01/app/oracle/fast_recovery_area/cdb1_stby'
    NOFILENAMECHECK;
}
EXIT;
EOF

# 4. Iniciar recuperación managed standby
sqlplus / as sysdba <<EOF
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;
EXIT;
EOF

echo "RMAN DUPLICATE completado exitosamente"
```

**Anatomía del comando DUPLICATE:**

```rman
DUPLICATE TARGET DATABASE
  FOR STANDBY                  -- Crear standby físico (no copia exacta)
  FROM ACTIVE DATABASE         -- Copiar desde primary activo (no desde backup)
  DORECOVER                    -- Aplicar archive logs después de copiar
  SPFILE                       -- Generar SPFILE con parámetros personalizados
    SET db_unique_name='cdb1_stby'  -- Parámetros específicos del standby
    SET fal_server='cdb1'           -- Configurar Fetch Archive Log
    ...
  NOFILENAMECHECK;             -- No verificar nombres de archivos (están en paths diferentes)
```

**Proceso interno:**

```
1. Validación:
   - Verificar conectividad a primary (target)
   - Verificar standby en NOMOUNT (auxiliary)

2. Copiar SPFILE y Control File:
   - Copiar SPFILE del primary
   - Aplicar parámetros SET
   - Crear control file para standby

3. Copiar Datafiles:
   - Primary: Leer bloques de datafiles (sin afectar usuarios)
   - Red: Transferir bloques (cifrados con AES256)
   - Standby: Escribir bloques a /u01/app/oracle/oradata/CDB1_STBY/

4. Crear Standby Redo Logs:
   - Primary tiene 3 online redo log groups
   - Standby necesita 4+ standby redo log groups (N+1)
   - RMAN crea automáticamente

5. DORECOVER:
   - Aplicar archive logs generados durante DUPLICATE
   - Sincronizar standby con primary
   - Standby queda en MOUNT, listo para managed recovery

Tiempo total: 20-30 minutos (database de 2-3 GB)
```

---

## 📋 Estrategias de Backup

### Estrategia en Nuestro Proyecto

**Tipo:** Full backup diario + Archive logs

```
Domingo:   Full Backup (2 GB comprimido)          1 AM
Lunes:     Full Backup (2 GB comprimido)          1 AM
Martes:    Full Backup (2 GB comprimido)          1 AM
Miércoles: Full Backup (2 GB comprimido)          1 AM
Jueves:    Full Backup (2 GB comprimido)          1 AM
Viernes:   Full Backup (2 GB comprimido)          1 AM
Sábado:    Full Backup (2 GB comprimido)          1 AM

Retención: 7 días
Espacio total: ~14 GB (7 backups × 2 GB)
```

**Ventajas:**
- Simple de gestionar
- Restore rápido (solo necesitas 1 backup + archive logs)
- Adecuado para databases pequeñas (< 10 GB)

**Desventajas:**
- Espacio: 7 × tamaño de database
- I/O: Backup full diario puede impactar performance

### Estrategia Alternativa: Incremental Semanal

**Para databases más grandes (> 50 GB):**

```
Domingo:   Level 0 (full incremental)     10 GB    2 horas
Lunes:     Level 1 (diferencial)          1 GB     15 min
Martes:    Level 1 (diferencial)          1 GB     15 min
Miércoles: Level 1 (diferencial)          1 GB     15 min
Jueves:    Level 1 (diferencial)          1 GB     15 min
Viernes:   Level 1 (diferencial)          1 GB     15 min
Sábado:    Level 1 (diferencial)          1 GB     15 min

Retención: 4 semanas
Espacio total: ~64 GB (4 Level 0 + 24 Level 1)
```

**Ventajas:**
- Backups diarios rápidos (15 min vs 2 horas)
- Menor espacio relativo (64 GB vs 280 GB con full diario)

**Desventajas:**
- Restore más complejo (Level 0 + 6 Level 1 + archive logs)

### Backup Offsite (Redundancia Geográfica)

Nuestro proyecto usa **rsync** para copiar backups al standby:

```bash
# Parte del script 71-rman-daily-backup.sh
rsync -avz --delete \
  /u01/app/oracle/fast_recovery_area/CDB1/backupset/ \
  oracle@ol8-21-dg2:/u02/backups/primary/

# Opciones:
# -a: archive mode (preserva permisos, timestamps)
# -v: verbose
# -z: compresión durante transferencia
# --delete: elimina archivos en destino que no existen en origen
```

**Ventajas:**
- Si primary y su disco de backups fallan, backups siguen en standby
- Transferencia incremental (solo archivos nuevos)

---

## 🔧 Troubleshooting

### Problema 1: Backup Falla con ORA-19809 (FRA Full)

**Error:**

```
RMAN-03009: failure of backup command on ORA_DISK_1 channel at 11/04/2025 01:15:23
ORA-19809: limit exceeded for recovery files
ORA-19804: cannot reclaim 2147483648 bytes disk space from 10737418240 byte limit
```

**Causa:** Fast Recovery Area (FRA) 100% llena

**Diagnóstico:**

```sql
SELECT * FROM v$recovery_file_dest;

-- SPACE_USED = SPACE_LIMIT (10 GB de 10 GB)
```

**Soluciones:**

1. **Limpiar backups obsoletos:**
```rman
DELETE NOPROMPT OBSOLETE;
DELETE NOPROMPT ARCHIVELOG ALL COMPLETED BEFORE 'SYSDATE-3';
CROSSCHECK BACKUP;
DELETE NOPROMPT EXPIRED BACKUP;
```

2. **Expandir FRA (temporal):**
```sql
ALTER SYSTEM SET db_recovery_file_dest_size=20G SCOPE=BOTH;
```

3. **Mover backups antiguos fuera de FRA:**
```bash
mkdir /u02/old_backups
mv /u01/app/oracle/fast_recovery_area/CDB1/backupset/2025_10_* /u02/old_backups/

# Actualizar catálogo RMAN
rman target /
CROSSCHECK BACKUP;
DELETE NOPROMPT EXPIRED BACKUP;
```

### Problema 2: RMAN DUPLICATE Falla con ORA-17629 (Connection Error)

**Error:**

```
RMAN-00571: ===========================================================
RMAN-00569: =============== ERROR MESSAGE STACK FOLLOWS ===============
RMAN-00571: ===========================================================
RMAN-03002: failure of Duplicate Db command at 11/04/2025 10:30:15
RMAN-05501: aborting duplication of target database
RMAN-03015: error occurred in stored script Memory Script
ORA-17629: Cannot connect to the remote database server
```

**Causa:** No hay conectividad de red entre standby y primary

**Diagnóstico:**

```bash
# En STANDBY, verificar conectividad
tnsping cdb1

# Intentar conexión SQL
sqlplus sys/password@cdb1 as sysdba <<EOF
SELECT instance_name FROM v\$instance;
EXIT;
EOF
```

**Solución:**

- Verificar tnsnames.ora tiene entrada para primary
- Verificar listener en primary: `lsnrctl status`
- Verificar firewall permite puerto 1521

### Problema 3: Backup Muy Lento

**Síntomas:**

```
Backup tarda 2 horas (debería tomar 20 minutos)
```

**Causas posibles:**

1. **Disco lento (I/O bottleneck)**

```bash
# Verificar I/O wait
iostat -x 5

# Si %iowait > 30%, disco es bottleneck
```

2. **Un solo canal (no paralelizado)**

```rman
-- Ver configuración actual
SHOW DEVICE TYPE DISK;

-- Si PARALLELISM = 1, aumentar:
CONFIGURE DEVICE TYPE DISK PARALLELISM 2;
```

3. **Sin compresión (transfiriendo demasiados datos)**

```rman
-- Habilitar compresión
BACKUP AS COMPRESSED BACKUPSET DATABASE;
```

---

## 📝 Conclusiones

### Puntos Clave sobre RMAN

1. **Estándar de Facto:** RMAN es la herramienta estándar de Oracle para backups (no usar cp/tar).

2. **Incremental Awareness:** RMAN conoce la estructura interna de Oracle, puede hacer backups incrementales eficientes.

3. **RMAN DUPLICATE:** Método estándar para crear standby físico en Data Guard (sin backup manual).

4. **Compresión Integrada:** Ahorra 40-60% de espacio sin software adicional.

5. **Catálogo en Control File:** No necesitas database separada para catálogo (a menos que gestiones 100+ databases).

### Configuración en Nuestro Proyecto

| Aspecto | Configuración |
|---------|---------------|
| **Tipo de backup** | Full backup diario comprimido |
| **Frecuencia** | 1 AM diario (cron) |
| **Retención** | 7 días |
| **Destino** | Fast Recovery Area (/u01/app/oracle/fast_recovery_area) |
| **Compresión** | BASIC (40-60% ratio) |
| **Paralelismo** | 1 canal (PARALLELISM 1) |
| **Archive logs** | Incluidos (PLUS ARCHIVELOG) |
| **Offsite** | Sí (rsync a standby /u02/backups/) |
| **RMAN DUPLICATE** | Usado para crear standby (FROM ACTIVE DATABASE) |

### Relación con Otros Componentes

- **Archive Logs** (83-archive-logs.md): RMAN respalda archive logs para recovery completo
- **Flashback Database** (84-flashback-database.md): Flashback es más rápido que RMAN restore para recovery reciente
- **Data Guard** (81-data-guard-conceptos.md): RMAN DUPLICATE crea standby físico

### Comandos Rápidos de Referencia

```bash
# Conectarse a RMAN
rman target /

# Backups
BACKUP DATABASE;
BACKUP AS COMPRESSED BACKUPSET DATABASE PLUS ARCHIVELOG;
BACKUP INCREMENTAL LEVEL 0 DATABASE;
BACKUP TABLESPACE users;
BACKUP ARCHIVELOG ALL;

# Restore/Recover
RESTORE DATABASE;
RECOVER DATABASE;
ALTER DATABASE OPEN RESETLOGS;

RESTORE TABLESPACE users;
RECOVER TABLESPACE users;

# Gestión de backups
LIST BACKUP SUMMARY;
DELETE NOPROMPT OBSOLETE;
DELETE NOPROMPT ARCHIVELOG ALL COMPLETED BEFORE 'SYSDATE-7';
CROSSCHECK BACKUP;
DELETE NOPROMPT EXPIRED BACKUP;

# RMAN DUPLICATE
DUPLICATE TARGET DATABASE FOR STANDBY FROM ACTIVE DATABASE DORECOVER;

# Configuración
SHOW ALL;
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 7 DAYS;
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE COMPRESSION ALGORITHM 'BASIC';
```

---

**Anterior:** [86-networking-tns.md](86-networking-tns.md) - Networking y TNS
**Inicio:** [00-tabla-contenidos.md](../00-tabla-contenidos.md)
**Tabla de Contenidos Completa:** [00-tabla-contenidos.md](../00-tabla-contenidos.md)
