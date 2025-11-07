# 71 - RMAN Daily Backup

## Respaldo Diario Automático con Transferencia al Standby

Este script ejecuta un respaldo completo de la base de datos primaria cada día usando RMAN (Recovery Manager), comprime los backupsets para ahorrar espacio, y transfiere automáticamente los archivos de respaldo al servidor standby para doble protección.

## Ubicación

`2-Standby/automation/rman_daily_backup.sh`

## Propósito

Proteger los datos del sistema de salud mediante respaldos diarios completos que incluyen:
- Todos los datafiles de la base de datos (CDB + PDB)
- Archive logs generados
- Controlfile y SPFILE
- Transferencia automática al standby para redundancia geográfica

Cumple con el requisito: "Respaldo diario automático a la 1 AM"

## Cuándo se Ejecuta

- **Frecuencia:** Diario a la 1:00 AM
- **Nodo:** Primary solamente
- **Usuario:** oracle
- **Installed by:** install_cron_jobs.sh

## Cron Schedule

```cron
0 1 * * * /home/oracle/automation/rman_daily_backup.sh
```

**En español:** "A la 1:00 AM todos los días"

**Razón del horario:**
- 1:00 AM = ventana de menor actividad del sistema de salud
- Evita impacto en operaciones diurnas
- Permite 1 hora antes de limpieza de archives (2:00 AM)

## Variables de Entorno

Desde `config/install.env`:

```bash
# Configuración de Backup
BACKUP_DIR=/u02/backup                    # Directorio de respaldos
BACKUP_RETENTION_DAYS=7                   # Retención de 7 días
BACKUP_TIME="0 1 * * *"                   # 1 AM diario

# Nodos
NODE2_FQ_HOSTNAME=ol8-21-dg2.localdomain  # Servidor standby

# Oracle
ORACLE_SID=cdb1
ORACLE_HOME=/u01/app/oracle/product/21.0.0/dbhome_1
```

## Qué Hace el Script (Paso a Paso)

### Paso 1: Preparación del Entorno

```bash
. /home/oracle/scripts/setEnv.sh
. /vagrant_config/install.env

BACKUP_TAG="DAILY_BACKUP_$(date +%Y%m%d)"
LOGFILE="/home/oracle/logs/automation/rman_backup_$(date +%Y%m%d).log"
```

**Explicación:**
- Carga variables de entorno de Oracle (ORACLE_HOME, ORACLE_SID, PATH)
- Define un tag único para el backup: `DAILY_BACKUP_20251104`
- Crea un log file específico para este backup: `rman_backup_20251104.log`

**¿Por qué un log por día?**
- Facilita auditoría de cada backup individual
- Permite investigar problemas de días específicos
- Logs antiguos se limpian automáticamente (30 días)

### Paso 2: Configuración de Políticas RMAN

```bash
rman target / << REOF
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF ${BACKUP_RETENTION_DAYS} DAYS;
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '${BACKUP_DIR}/cf_%F';
CONFIGURE DEVICE TYPE DISK PARALLELISM 2;
CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;
```

**Explicación detallada:**

#### RETENTION POLICY (7 días)
```sql
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 7 DAYS;
```
- Define cuánto tiempo se conservan los backups
- "7 DAYS" = se puede restaurar la DB a cualquier punto en los últimos 7 días
- RMAN marcará como OBSOLETE backups más antiguos
- Los obsoletos se eliminarán con DELETE OBSOLETE

#### CONTROLFILE AUTOBACKUP
```sql
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '/u02/backup/cf_%F';
```
- Respalda automáticamente controlfile después de cambios estructurales
- `%F` = formato único: `c-<DBID>-<TIMESTAMP>-<SEQUENCE>`
- Esencial para recuperación completa de la base de datos

#### DISK PARALLELISM 2
```sql
CONFIGURE DEVICE TYPE DISK PARALLELISM 2;
```
- Usa 2 canales paralelos para el backup
- Acelera el proceso al escribir en 2 archivos simultáneamente
- Valor óptimo para VM con 2 CPUs

#### ARCHIVELOG DELETION POLICY
```sql
CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;
```
- **MUY IMPORTANTE:** Solo permite eliminar archives que ya fueron aplicados en el standby
- Protege contra pérdida de datos si standby no está sincronizado
- Trabaja en conjunto con `delete_archives_primary.sh`

### Paso 3: Ejecución del Backup

```bash
RUN {
  ALLOCATE CHANNEL ch1 DEVICE TYPE DISK FORMAT '${BACKUP_DIR}/${BACKUP_TAG}_%U';
  ALLOCATE CHANNEL ch2 DEVICE TYPE DISK FORMAT '${BACKUP_DIR}/${BACKUP_TAG}_%U';
```

**Explicación:**
- Asigna 2 canales (ch1, ch2) para backup paralelo
- `FORMAT` especifica el patrón de nombre de archivos:
  - `DAILY_BACKUP_20251104_%U`
  - `%U` = identificador único generado por RMAN

**Ejemplo de archivos generados:**
```
/u02/backup/DAILY_BACKUP_20251104_01v3pq9t_1_1.bkp
/u02/backup/DAILY_BACKUP_20251104_02v3pq9t_1_1.bkp
/u02/backup/DAILY_BACKUP_20251104_03v3pq9t_1_1.bkp
```

### Paso 4: Forzar Archive Log Current

```bash
  SQL 'ALTER SYSTEM ARCHIVE LOG CURRENT';
```

**Explicación:**
- Fuerza el archivado del redo log activo actual
- Garantiza que todos los cambios hasta este momento están en archive logs
- Permite incluir estos archives en el backup

**¿Por qué es importante?**
- Sin esto, cambios recientes (en current online redo) no estarían respaldados
- Después del archivado, el backup incluirá TODO hasta el momento de inicio

### Paso 5: Backup Comprimido de Base de Datos

```bash
  BACKUP AS COMPRESSED BACKUPSET
    DATABASE
    PLUS ARCHIVELOG
    TAG ${BACKUP_TAG};
```

**Explicación detallada:**

#### AS COMPRESSED BACKUPSET
- Comprime los backupsets durante la creación
- Ahorro típico: 60-80% del espacio
- Base de datos de 10GB → backup de ~2-4GB

#### DATABASE
- Respalda TODOS los datafiles de:
  - CDB (Container Database): SYSTEM, SYSAUX, USERS, UNDO
  - PDB1 (Pluggable Database): Esquema HEALTHCENTER con datos de salud

#### PLUS ARCHIVELOG
- Además de datafiles, respalda TODOS los archive logs disponibles
- Permite recuperación point-in-time completa
- Incluye archives generados durante el backup

#### TAG
- Etiqueta el backup para fácil identificación
- Útil para restaurar backup específico:
  ```sql
  RESTORE DATABASE FROM TAG 'DAILY_BACKUP_20251104';
  ```

### Paso 6: Backup de Controlfile

```bash
  BACKUP CURRENT CONTROLFILE
    FORMAT '${BACKUP_DIR}/control_${BACKUP_TAG}_%U';
```

**Explicación:**
- Copia del controlfile (archivo de control de la base de datos)
- Contiene metadatos críticos: ubicación de datafiles, redo logs, checkpoint info
- Necesario para montar la DB durante recuperación

**Nombre generado:**
```
/u02/backup/control_DAILY_BACKUP_20251104_04v3pq9t_1_1.ctl
```

### Paso 7: Backup de SPFILE

```bash
  BACKUP SPFILE
    FORMAT '${BACKUP_DIR}/spfile_${BACKUP_TAG}_%U';
```

**Explicación:**
- SPFILE = Server Parameter File (parámetros de configuración de la DB)
- Contiene: memory settings, archive log config, Data Guard params, etc.
- Permite recrear exactamente la misma configuración tras recuperación

**Nombre generado:**
```
/u02/backup/spfile_DAILY_BACKUP_20251104_05v3pq9t_1_1.ora
```

### Paso 8: Limpieza de Backups Obsoletos

```bash
  DELETE NOPROMPT OBSOLETE;
```

**Explicación:**
- Elimina backups marcados como OBSOLETE según la retention policy (7 días)
- `NOPROMPT` = no pide confirmación (necesario para ejecución automatizada)
- Libera espacio automáticamente manteniendo solo backups necesarios

**¿Qué se elimina?**
- Backups con más de 7 días
- Backups no necesarios para cumplir recovery window
- NO elimina backups que se necesiten para restore point-in-time

### Paso 9: Liberación de Canales

```bash
  RELEASE CHANNEL ch1;
  RELEASE CHANNEL ch2;
}
EXIT;
```

**Explicación:**
- Libera los canales paralelos asignados
- Buena práctica de limpieza de recursos
- Sale de RMAN

### Paso 10: Transferencia al Standby

```bash
rsync -avz --progress ${BACKUP_DIR}/ oracle@${NODE2_FQ_HOSTNAME}:/u02/backup_from_primary/
```

**Explicación detallada:**

#### Opciones de rsync:
- `-a` (archive): Preserva permisos, timestamps, ownership
- `-v` (verbose): Muestra archivos transferidos
- `-z` (compress): Comprime durante transferencia (aunque backups ya están comprimidos)
- `--progress`: Muestra progreso de cada archivo

#### Directorios:
- Origen: `/u02/backup/` (primary)
- Destino: `oracle@ol8-21-dg2.localdomain:/u02/backup_from_primary/` (standby)

#### Autenticación:
- Usa claves SSH configuradas por `setup_ssh_keys.sh`
- Sin password (automatizado)

**¿Por qué transferir backups al standby?**
1. **Protección geográfica:** Si falla disco en primary, backup existe en standby
2. **Recuperación distribuida:** Standby puede usarse para restore sin impactar primary
3. **Disaster recovery:** Si primary se pierde completamente, backups están en standby

### Paso 11: Verificación de Transferencia

```bash
if [ $? -eq 0 ]; then
  echo "===================================================================="
  echo "Backup transfer completed successfully: $(date)"
  echo "===================================================================="
else
  echo "===================================================================="
  echo "ERROR: Backup transfer failed!"
  echo "===================================================================="
  # Could send email alert here if mail is configured
fi
```

**Explicación:**
- `$?` = código de salida del último comando (rsync)
- `0` = éxito, cualquier otro = error
- Registra resultado en el log
- En producción, error activaría alerta por email

### Paso 12: Limpieza de Logs Antiguos

```bash
find /home/oracle/logs/automation/rman_backup_*.log -mtime +30 -delete 2>/dev/null
```

**Explicación:**
- Busca logs de backup con más de 30 días
- Los elimina automáticamente
- `2>/dev/null` = suprime errores si no hay archivos

**Retención:**
- Backups: 7 días (dentro de RMAN)
- Logs de backup: 30 días (en filesystem)
- Permite auditar backups más allá de la ventana de retención

## Comandos Importantes

### RMAN BACKUP

```sql
-- Backup básico de base de datos
BACKUP DATABASE;

-- Backup comprimido
BACKUP AS COMPRESSED BACKUPSET DATABASE;

-- Backup incremental nivel 0 (full) y nivel 1 (incremental)
BACKUP INCREMENTAL LEVEL 0 DATABASE;
BACKUP INCREMENTAL LEVEL 1 DATABASE;

-- Backup de tablespace específico
BACKUP TABLESPACE USERS;

-- Backup de archive logs solo
BACKUP ARCHIVELOG ALL;

-- Backup con múltiples copias
BACKUP COPIES 2 DATABASE;
```

### RMAN RESTORE/RECOVER

```sql
-- Restaurar base de datos completa
RESTORE DATABASE;
RECOVER DATABASE;

-- Restaurar a punto en el tiempo
RUN {
  SET UNTIL TIME "TO_DATE('2025-11-04 12:00:00', 'YYYY-MM-DD HH24:MI:SS')";
  RESTORE DATABASE;
  RECOVER DATABASE;
}

-- Restaurar desde tag específico
RESTORE DATABASE FROM TAG 'DAILY_BACKUP_20251104';

-- Restaurar solo controlfile
RESTORE CONTROLFILE FROM AUTOBACKUP;
```

### RMAN LIST/REPORT

```sql
-- Listar todos los backups
LIST BACKUP;

-- Listar backups de hoy
LIST BACKUP COMPLETED AFTER 'SYSDATE-1';

-- Listar backups por tag
LIST BACKUP OF DATABASE TAG 'DAILY_BACKUP_20251104';

-- Reportar backups obsoletos
REPORT OBSOLETE;

-- Reportar archivos que necesitan backup
REPORT NEED BACKUP;

-- Ver resumen de backups
LIST BACKUP SUMMARY;
```

### RMAN CONFIGURE

```sql
-- Ver todas las configuraciones
SHOW ALL;

-- Ver configuración específica
SHOW RETENTION POLICY;
SHOW CONTROLFILE AUTOBACKUP;

-- Restaurar configuración a default
CONFIGURE RETENTION POLICY CLEAR;

-- Configurar compresión por defecto
CONFIGURE COMPRESSION ALGORITHM 'MEDIUM';
```

## Salida Esperada

### Inicio del Backup

```
====================================================================
RMAN Daily Backup Started: Tue Nov  4 01:00:02 UTC 2025
====================================================================

Recovery Manager: Release 21.0.0.0.0 - Production on Tue Nov 4 01:00:02 2025
Version 21.3.0.0.0

connected to target database: CDB1 (DBID=1234567890)

RMAN configuration parameters for database with db_unique_name CDB1 are:
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 7 DAYS;
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '/u02/backup/cf_%F';
CONFIGURE DEVICE TYPE DISK PARALLELISM 2 BACKUP TYPE TO BACKUPSET;
CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;
```

### Durante el Backup

```
Starting backup at 04-NOV-25
current log archived
allocated channel: ch1
channel ch1: SID=123 device type=DISK
allocated channel: ch2
channel ch2: SID=124 device type=DISK

channel ch1: starting compressed archived log backup set
channel ch1: specifying archived log(s) in backup set
input archived log thread=1 sequence=120 RECID=1 STAMP=1234567890
input archived log thread=1 sequence=121 RECID=2 STAMP=1234567891
channel ch1: starting piece 1 at 04-NOV-25
channel ch2: starting compressed full datafile backup set
channel ch2: specifying datafile(s) in backup set
input datafile file number=00001 name=/u01/oradata/cdb1/system01.dbf
input datafile file number=00003 name=/u01/oradata/cdb1/sysaux01.dbf
input datafile file number=00004 name=/u01/oradata/cdb1/undotbs01.dbf
input datafile file number=00007 name=/u01/oradata/cdb1/users01.dbf
channel ch2: starting piece 1 at 04-NOV-25

channel ch1: finished piece 1 at 04-NOV-25
piece handle=/u02/backup/DAILY_BACKUP_20251104_01v3pq9t_1_1.bkp tag=DAILY_BACKUP_20251104 comment=NONE
channel ch1: backup set complete, elapsed time: 00:01:15
channel ch1: starting compressed full datafile backup set
channel ch1: specifying datafile(s) in backup set
input datafile file number=00010 name=/u01/oradata/cdb1/pdb1/system01.dbf
input datafile file number=00011 name=/u01/oradata/cdb1/pdb1/sysaux01.dbf
input datafile file number=00012 name=/u01/oradata/cdb1/pdb1/undotbs01.dbf
channel ch1: starting piece 1 at 04-NOV-25

channel ch2: finished piece 1 at 04-NOV-25
piece handle=/u02/backup/DAILY_BACKUP_20251104_02v3pq9t_1_1.bkp tag=DAILY_BACKUP_20251104 comment=NONE
channel ch2: backup set complete, elapsed time: 00:02:35

channel ch1: finished piece 1 at 04-NOV-25
piece handle=/u02/backup/DAILY_BACKUP_20251104_03v3pq9t_1_1.bkp tag=DAILY_BACKUP_20251104 comment=NONE
channel ch1: backup set complete, elapsed time: 00:01:45
Finished backup at 04-NOV-25
```

### Backup de Controlfile y SPFILE

```
Starting backup at 04-NOV-25
using channel ch1
using channel ch2
channel ch1: starting full datafile backup set
channel ch1: specifying datafile(s) in backup set
including current control file in backup set
channel ch1: starting piece 1 at 04-NOV-25
channel ch1: finished piece 1 at 04-NOV-25
piece handle=/u02/backup/control_DAILY_BACKUP_20251104_04v3pq9t_1_1.ctl tag=TAG20251104T010000 comment=NONE
channel ch1: backup set complete, elapsed time: 00:00:01
Finished backup at 04-NOV-25

Starting backup at 04-NOV-25
using channel ch1
using channel ch2
channel ch1: starting full datafile backup set
channel ch1: specifying datafile(s) in backup set
including current SPFILE in backup set
channel ch1: starting piece 1 at 04-NOV-25
channel ch1: finished piece 1 at 04-NOV-25
piece handle=/u02/backup/spfile_DAILY_BACKUP_20251104_05v3pq9t_1_1.ora tag=TAG20251104T010001 comment=NONE
channel ch1: backup set complete, elapsed time: 00:00:01
Finished backup at 04-NOV-25
```

### Limpieza de Obsoletos

```
RMAN> DELETE NOPROMPT OBSOLETE;

RMAN retention policy will be applied to the command
RMAN retention policy is set to recovery window of 7 days
allocated channel: ORA_DISK_1
channel ORA_DISK_1: SID=125 device type=DISK

Deleting the following obsolete backups and copies:
Type                 Key    Completion Time    Filename/Handle
-------------------- ------ ------------------ --------------------
Backup Set           15     28-OCT-25          /u02/backup/DAILY_BACKUP_20251028_01u3pq9t_1_1.bkp
Backup Set           16     28-OCT-25          /u02/backup/DAILY_BACKUP_20251028_02u3pq9t_1_1.bkp

deleted backup piece
backup piece handle=/u02/backup/DAILY_BACKUP_20251028_01u3pq9t_1_1.bkp RECID=15 STAMP=1234567000
deleted backup piece
backup piece handle=/u02/backup/DAILY_BACKUP_20251028_02u3pq9t_1_1.bkp RECID=16 STAMP=1234567001
Deleted 2 objects
```

### Transferencia al Standby

```
====================================================================
RMAN Backup Completed: Tue Nov  4 01:06:45 UTC 2025
====================================================================

====================================================================
Transferring backups to standby server...
====================================================================

sending incremental file list
DAILY_BACKUP_20251104_01v3pq9t_1_1.bkp
         1,234,567 100%   12.34MB/s    0:00:00 (xfr#1, to-chk=4/5)
DAILY_BACKUP_20251104_02v3pq9t_1_1.bkp
         2,345,678 100%   15.67MB/s    0:00:00 (xfr#2, to-chk=3/5)
DAILY_BACKUP_20251104_03v3pq9t_1_1.bkp
         1,456,789 100%   13.45MB/s    0:00:00 (xfr#3, to-chk=2/5)
control_DAILY_BACKUP_20251104_04v3pq9t_1_1.ctl
           123,456 100%    5.67MB/s    0:00:00 (xfr#4, to-chk=1/5)
spfile_DAILY_BACKUP_20251104_05v3pq9t_1_1.ora
            12,345 100%    2.34MB/s    0:00:00 (xfr#5, to-chk=0/5)

sent 5,172,835 bytes  received 115 bytes  10,345,900.00 bytes/sec
total size is 5,172,835  speedup is 1.00

====================================================================
Backup transfer completed successfully: Tue Nov  4 01:07:12 UTC 2025
====================================================================
```

### Log File Final

Todo esto se guarda en:
```
/home/oracle/logs/automation/rman_backup_20251104.log
```

## Logs Generados

### Log de Backup Diario

- **Ubicación:** `/home/oracle/logs/automation/rman_backup_YYYYMMDD.log`
- **Uno por día:** Cada ejecución crea su propio log
- **Retención:** 30 días (se eliminan automáticamente logs antiguos)

**Contenido del log:**
1. Configuraciones RMAN aplicadas
2. Lista de archivos respaldados
3. Progreso de cada canal paralelo
4. Tamaño de backupsets generados
5. Resultados de DELETE OBSOLETE
6. Output de rsync (transferencia)
7. Confirmación de éxito o errores

### Verificar Logs Recientes

```bash
# Ver log de hoy
tail -100 /home/oracle/logs/automation/rman_backup_$(date +%Y%m%d).log

# Ver log de ayer
tail -100 /home/oracle/logs/automation/rman_backup_$(date -d yesterday +%Y%m%d).log

# Listar todos los logs de backup
ls -lh /home/oracle/logs/automation/rman_backup_*.log

# Buscar errores en log de hoy
grep -i error /home/oracle/logs/automation/rman_backup_$(date +%Y%m%d).log
```

### Tamaño de Logs

Típicamente:
- Backup exitoso: 50-200 KB por log
- Backup con errores: 100-500 KB (más output de debug)

## Archivos Generados

### En Primary (/u02/backup/)

Después de un backup exitoso:

```bash
$ ls -lh /u02/backup/
total 4.5G
-rw-r----- 1 oracle oinstall 1.2G Nov  4 01:03 DAILY_BACKUP_20251104_01v3pq9t_1_1.bkp
-rw-r----- 1 oracle oinstall 2.3G Nov  4 01:05 DAILY_BACKUP_20251104_02v3pq9t_1_1.bkp
-rw-r----- 1 oracle oinstall 1.5G Nov  4 01:06 DAILY_BACKUP_20251104_03v3pq9t_1_1.bkp
-rw-r----- 1 oracle oinstall 120K Nov  4 01:06 control_DAILY_BACKUP_20251104_04v3pq9t_1_1.ctl
-rw-r----- 1 oracle oinstall  12K Nov  4 01:06 spfile_DAILY_BACKUP_20251104_05v3pq9t_1_1.ora
-rw-r----- 1 oracle oinstall 256K Nov  4 01:00 cf_c-1234567890-20251104-00.ctl
```

### En Standby (/u02/backup_from_primary/)

Después de la transferencia, mismos archivos:

```bash
$ ssh oracle@ol8-21-dg2 "ls -lh /u02/backup_from_primary/"
total 4.5G
-rw-r----- 1 oracle oinstall 1.2G Nov  4 01:07 DAILY_BACKUP_20251104_01v3pq9t_1_1.bkp
-rw-r----- 1 oracle oinstall 2.3G Nov  4 01:08 DAILY_BACKUP_20251104_02v3pq9t_1_1.bkp
-rw-r----- 1 oracle oinstall 1.5G Nov  4 01:09 DAILY_BACKUP_20251104_03v3pq9t_1_1.bkp
-rw-r----- 1 oracle oinstall 120K Nov  4 01:09 control_DAILY_BACKUP_20251104_04v3pq9t_1_1.ctl
-rw-r----- 1 oracle oinstall  12K Nov  4 01:09 spfile_DAILY_BACKUP_20251104_05v3pq9t_1_1.ora
-rw-r----- 1 oracle oinstall 256K Nov  4 01:07 cf_c-1234567890-20251104-00.ctl
```

## Ejecución Manual

### Ejecutar Backup Manual

```bash
# Como usuario oracle en primary
/home/oracle/automation/rman_daily_backup.sh

# Ver progreso en tiempo real
tail -f /home/oracle/logs/automation/rman_backup_$(date +%Y%m%d).log
```

**Casos de uso:**
- Backup antes de cambios importantes
- Backup adicional fuera de horario programado
- Pruebas de proceso de backup

### Backup Manual Interactivo

Para más control, use el script `manual_backup.sh`:

```bash
/home/oracle/automation/manual_backup.sh
```

Este script:
- Pide confirmación antes de iniciar
- Pregunta si desea transferir al standby
- Usa tag único con timestamp exacto

## Verificación

### Verificar que Cron Está Configurado

```bash
# Ver cron jobs instalados
crontab -l | grep rman_daily_backup

# Salida esperada:
# 0 1 * * * /home/oracle/automation/rman_daily_backup.sh
```

### Verificar Backups en RMAN

```bash
rman target /

# Dentro de RMAN:
LIST BACKUP SUMMARY;

# Ver backups de los últimos 7 días
LIST BACKUP COMPLETED AFTER 'SYSDATE-7';

# Ver backup de tag específico
LIST BACKUP OF DATABASE TAG 'DAILY_BACKUP_20251104';
```

### Verificar Transferencia al Standby

```bash
# Comparar tamaños entre primary y standby
du -sh /u02/backup/DAILY_BACKUP_$(date +%Y%m%d)*
ssh oracle@ol8-21-dg2 "du -sh /u02/backup_from_primary/DAILY_BACKUP_$(date +%Y%m%d)*"

# Deben ser idénticos
```

### Verificar Espacio en Disco

```bash
# En primary
df -h /u02

# En standby
ssh oracle@ol8-21-dg2 "df -h /u02"

# Asegurar que hay suficiente espacio libre (al menos 50% disponible)
```

### Probar Restauración (Dry Run)

```bash
rman target /

# Validar que se puede restaurar sin hacerlo realmente
RESTORE DATABASE VALIDATE;

# Validar backup específico
RESTORE DATABASE FROM TAG 'DAILY_BACKUP_20251104' VALIDATE;
```

## Puntos de Fallo Comunes

### 1. "RMAN-03009: failure of backup command"

**Causa:** Espacio insuficiente en /u02/backup

**Solución:**
```bash
# Verificar espacio
df -h /u02

# Si está lleno, limpiar backups obsoletos manualmente
rman target /
DELETE NOPROMPT OBSOLETE;
EXIT;

# O eliminar backups muy antiguos
find /u02/backup -name "DAILY_BACKUP_*" -mtime +10 -delete
```

### 2. "rsync: failed to connect to ol8-21-dg2"

**Causa:** SSH keys no configuradas o standby no alcanzable

**Solución:**
```bash
# Verificar conectividad
ping ol8-21-dg2.localdomain

# Probar SSH
ssh oracle@ol8-21-dg2 "hostname"

# Si falla, reconfigurar SSH keys
/home/oracle/automation/setup_ssh_keys.sh
```

### 3. "RMAN-08120: warning: archived log not deleted, not yet applied"

**Causa:** Policy `APPLIED ON ALL STANDBY` impide borrar archives no aplicados

**Solución:**
```bash
# Verificar estado de standby
/home/oracle/automation/check_log_transport.sh
tail -20 /home/oracle/logs/automation/log_transport.log

# Si standby está atrasado, esperar a que se sincronice
# O temporalmente cambiar policy:
rman target /
CONFIGURE ARCHIVELOG DELETION POLICY TO NONE;
DELETE NOPROMPT OBSOLETE;
CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;
```

### 4. "ORA-19809: limit exceeded for recovery files"

**Causa:** Fast Recovery Area (FRA) llena

**Solución:**
```sql
-- Ver uso de FRA
SELECT * FROM v$recovery_area_usage;
SELECT * FROM v$recovery_file_dest;

-- Aumentar tamaño de FRA
ALTER SYSTEM SET db_recovery_file_dest_size=150G SCOPE=BOTH;

-- O limpiar FRA
RMAN> DELETE NOPROMPT OBSOLETE RECOVERY FILES;
```

### 5. Backup Toma Demasiado Tiempo

**Causa:** Paralelismo insuficiente o compresión lenta

**Solución:**
```bash
# Aumentar paralelismo (si hay más CPUs/discos)
rman target /
CONFIGURE DEVICE TYPE DISK PARALLELISM 4;

# Cambiar algoritmo de compresión (más rápido pero menos compresión)
CONFIGURE COMPRESSION ALGORITHM 'LOW';

# O deshabilitar compresión completamente
# (solo si espacio no es problema)
BACKUP DATABASE PLUS ARCHIVELOG;  # Sin AS COMPRESSED
```

### 6. Transferencia rsync Falla por Timeout

**Causa:** Backups muy grandes, red lenta

**Solución:**
```bash
# Agregar timeout más largo a rsync
# Editar script y cambiar línea de rsync a:
rsync -avz --progress --timeout=3600 ${BACKUP_DIR}/ oracle@${NODE2_FQ_HOSTNAME}:/u02/backup_from_primary/

# O usar compresión adicional durante transferencia
rsync -avz --compress-level=9 --progress ${BACKUP_DIR}/ oracle@${NODE2_FQ_HOSTNAME}:/u02/backup_from_primary/
```

### 7. Cron No Ejecuta el Backup

**Causa:** Variable de entorno no disponible en cron, script no ejecutable

**Solución:**
```bash
# Verificar permisos
ls -l /home/oracle/automation/rman_daily_backup.sh
chmod +x /home/oracle/automation/rman_daily_backup.sh

# Verificar que cron está corriendo
systemctl status crond

# Ver errores de cron
grep -i rman /var/log/cron

# Probar ejecución manual
/home/oracle/automation/rman_daily_backup.sh
```

## Importancia para el Sistema

Este script es **CRÍTICO** para la protección de datos porque:

### 1. Cumplimiento de Requisitos

Implementa el requisito explícito: "Respaldo diario automático"
- Ejecuta a la 1 AM sin intervención humana
- Incluye TODOS los componentes (DB + archives + control + spfile)
- Retención de 7 días cumple estándares de industria de salud

### 2. Protección Multinivel

Ofrece 3 niveles de protección:
1. **Standby Database** (sincronización en tiempo real)
2. **Backups en Primary** (recuperación local)
3. **Backups en Standby** (recuperación remota)

### 3. Recovery Point Objective (RPO)

- RPO máximo: 5 minutos (ARCHIVE_LAG_TARGET)
- Con backups diarios + archive logs + Data Guard
- Se puede recuperar a CUALQUIER punto en los últimos 7 días

### 4. Recovery Time Objective (RTO)

Backups RMAN permiten:
- Restauración completa de DB: 30-60 minutos
- Restauración de tablespace: 5-15 minutos
- Recuperación point-in-time: agregar 10-30 minutos

### 5. Protección de Datos de Salud

Sistema maneja datos críticos:
- Registros médicos (HC_Procedure)
- Información de usuarios/médicos (HC_User)
- Nóminas (HC_Payroll, HC_PayrollXUser)
- Turnos y escalas mensuales (HC_MonthScale)

**Pérdida de estos datos sería catastrófica:**
- Incumplimiento legal (privacidad de datos médicos)
- Pérdida financiera (nóminas, facturación)
- Riesgo para pacientes (historial médico perdido)

### 6. Doble Protección con Transferencia

La transferencia al standby protege contra:
- **Falla de disco en primary:** Backups en standby están intactos
- **Desastre en sitio primary:** Standby tiene copia de backups
- **Corrupción de FRA:** Backups transferidos no se afectan

### 7. Automatización = Confiabilidad

Sin intervención manual:
- No depende de recordar hacer backup
- Siempre a la misma hora (ventana de menor carga)
- Logs auditan cada ejecución

## Referencias Cruzadas

### Documentos Relacionados

- **[41-install-cron.md](../ejecucion/primary/41-install-cron.md)** - Instalación de este cron job
- **[72-delete-archives-primary.md](72-delete-archives-primary.md)** - Limpieza de archives tras backup
- **[75-manual-scripts.md](75-manual-scripts.md)** - Script de backup manual
- **[87-rman-backups.md](../conceptos-avanzados/87-rman-backups.md)** - Conceptos RMAN profundos
- **[91-respaldos-manuales.md](../operaciones/91-respaldos-manuales.md)** - Procedimientos de restore

### Scripts Relacionados

```bash
/home/oracle/automation/rman_daily_backup.sh        # Este script (automatizado)
/home/oracle/automation/manual_backup.sh            # Versión interactiva
/home/oracle/automation/delete_archives_primary.sh  # Limpieza post-backup
/home/oracle/automation/setup_ssh_keys.sh           # Requerido para rsync
/home/oracle/automation/verify_backup_automation.sh # Verificar configuración
```

### Configuraciones RMAN Relacionadas

```sql
-- Ver configuración actual
SHOW ALL;

-- Configuraciones críticas para este script:
SHOW RETENTION POLICY;                    -- 7 DAYS
SHOW CONTROLFILE AUTOBACKUP;              -- ON
SHOW DEVICE TYPE DISK PARALLELISM;        -- 2
SHOW ARCHIVELOG DELETION POLICY;          -- APPLIED ON ALL STANDBY
SHOW COMPRESSION ALGORITHM;               -- MEDIUM (default)
```

### Parámetros de Base de Datos Relacionados

```sql
-- Fast Recovery Area (donde se guardan backups antes de mover a /u02/backup)
SHOW PARAMETER db_recovery_file_dest;
SHOW PARAMETER db_recovery_file_dest_size;

-- Archive logs (incluidos en PLUS ARCHIVELOG)
SHOW PARAMETER log_archive_dest;
SHOW PARAMETER archive_lag_target;
```

---

**Última Actualización:** 2025-11-04
**Autor:** Claude (Subagente 4)
**Versión:** 1.0
