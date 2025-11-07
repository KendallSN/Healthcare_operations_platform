# 91 - Respaldos Manuales

## Ejecución Manual de Respaldos RMAN

Este documento describe los procedimientos para ejecutar respaldos manuales usando RMAN (Recovery Manager) en el sistema Oracle Data Guard.

---

## Tabla de Contenidos

1. [Introducción](#introducción)
2. [Cuándo Realizar Respaldos Manuales](#cuándo-realizar-respaldos-manuales)
3. [Usando el Script manual_backup.sh](#usando-el-script-manual_backupsh)
4. [Comandos RMAN Directos](#comandos-rman-directos)
5. [Transferencia a Standby](#transferencia-a-standby)
6. [Verificación de Respaldos](#verificación-de-respaldos)
7. [Catálogo de Respaldos](#catálogo-de-respaldos)
8. [Pruebas de Restore](#pruebas-de-restore)
9. [Checklist de Respaldos](#checklist-de-respaldos)

---

## Introducción

Aunque el sistema incluye respaldos automáticos diarios (ejecutados a la 1:00 AM), hay situaciones que requieren respaldos manuales on-demand.

**Tipos de respaldo soportados:**
- **Full backup:** Base de datos completa + archive logs
- **Incremental backup:** Solo bloques modificados
- **Archive log backup:** Solo archive logs
- **Controlfile backup:** Archivo de control
- **SPFILE backup:** Archivo de parámetros

**Políticas de retención:** 7 días por defecto (configurable en install.env)

---

## Cuándo Realizar Respaldos Manuales

### Situaciones que Requieren Respaldo Manual

1. **Antes de Cambios Mayores al Schema**
   - Agregar nuevas tablas
   - Modificar estructuras existentes
   - Ejecutar scripts de migración
   - Cargar datos importantes

2. **Antes de Actualizaciones de Oracle**
   - Aplicar patches
   - Actualizar versión minor
   - Cambios de configuración críticos

3. **Antes de Pruebas Destructivas**
   - Testing de failover
   - Pruebas de recovery
   - Simulaciones de desastre

4. **A Petición del Profesor (Requisito del Proyecto)**
   - Durante revisiones
   - Para demostrar funcionalidad
   - Verificación de replicación

5. **Después de Cargas de Datos Importantes**
   - Import de datos de producción
   - Cargas masivas
   - Migración de datos legacy

6. **Antes de Mantenimiento Programado**
   - Reinicio de servidores
   - Cambios de red
   - Mantenimiento de hardware virtual

---

## Usando el Script manual_backup.sh

El método más simple es usar el script incluido.

### Ubicación

```
/home/oracle/automation/manual_backup.sh
```

### Ejecución desde Windows

```bash
vagrant ssh primary -c "/home/oracle/automation/manual_backup.sh"
```

### Ejecución desde dentro del Primary

```bash
vagrant ssh primary

sudo su - oracle
cd /home/oracle/automation
./manual_backup.sh
```

### Flujo Interactivo

El script te preguntará:

```
====================================================================
Manual RMAN Backup
====================================================================
Backup tag: MANUAL_BACKUP_20251104_153022
Backup directory: /u02/backup

Proceed with backup? (yes/no):
```

**Escribe:** `yes` y presiona Enter.

El backup comenzará:

```
Starting backup...

Recovery Manager: Release 21.0.0.0.0 - Production on Mon Nov 4 15:30:25 2025

connected to target database: CDB1 (DBID=1234567890)

RMAN> RUN {
2>   ALLOCATE CHANNEL ch1 DEVICE TYPE DISK FORMAT '/u02/backup/MANUAL_BACKUP_20251104_153022_%U';
3>   SQL 'ALTER SYSTEM ARCHIVE LOG CURRENT';
4>   BACKUP AS COMPRESSED BACKUPSET
5>     DATABASE
6>     PLUS ARCHIVELOG
7>     TAG MANUAL_BACKUP_20251104_153022;
8>   BACKUP CURRENT CONTROLFILE;
9>   RELEASE CHANNEL ch1;
10> }

allocated channel: ch1
channel ch1: SID=245 device type=DISK

sql statement: ALTER SYSTEM ARCHIVE LOG CURRENT

Starting backup at 04-NOV-25
current log archived
channel ch1: starting compressed archived log backup set
channel ch1: specifying archived log(s) in backup set
input archived log thread=1 sequence=140 RECID=120 STAMP=1234567890
input archived log thread=1 sequence=141 RECID=121 STAMP=1234567891
[... más logs ...]
channel ch1: starting piece 1 at 04-NOV-25
channel ch1: finished piece 1 at 04-NOV-25
piece handle=/u02/backup/MANUAL_BACKUP_20251104_153022_01 tag=MANUAL_BACKUP_20251104_153022
channel ch1: backup set complete, elapsed time: 00:00:15

channel ch1: starting compressed full datafile backup set
channel ch1: specifying datafile(s) in backup set
input datafile file number=00001 name=/u01/oradata/CDB1/system01.dbf
input datafile file number=00003 name=/u01/oradata/CDB1/sysaux01.dbf
input datafile file number=00004 name=/u01/oradata/CDB1/undotbs01.dbf
[... más datafiles ...]
channel ch1: starting piece 1 at 04-NOV-25
channel ch1: finished piece 1 at 04-NOV-25
piece handle=/u02/backup/MANUAL_BACKUP_20251104_153022_02 tag=MANUAL_BACKUP_20251104_153022
channel ch1: backup set complete, elapsed time: 00:02:35

Starting Control File backup at 04-NOV-25
piece handle=/u02/backup/MANUAL_BACKUP_20251104_153022_03
Finished Control File backup at 04-NOV-25

released channel: ch1

RMAN> LIST BACKUP SUMMARY;

List of Backups
===============
Key     TY LV S Device Type Completion Time #Pieces #Copies Compressed Tag
------- -- -- - ----------- --------------- ------- ------- ---------- ---
1234    B  F  A DISK        04-NOV-25       1       1       YES        MANUAL_BACKUP_20251104_153022
1235    B  A  A DISK        04-NOV-25       1       1       YES        MANUAL_BACKUP_20251104_153022
1236    B  F  A DISK        04-NOV-25       1       1       NO         MANUAL_BACKUP_20251104_153022
```

**Tiempo esperado:** 3-7 minutos dependiendo del tamaño de la base de datos.

Al terminar:

```
====================================================================
Manual Backup Complete
====================================================================

Transfer to standby? (yes/no):
```

**Escribe:** `yes` para transferir el backup al servidor standby (recomendado).

```
Transferring backups...
sending incremental file list
MANUAL_BACKUP_20251104_153022_01
      1,234,567 100%   15.23MB/s    0:00:00 (xfr#1, to-chk=2/4)
MANUAL_BACKUP_20251104_153022_02
     12,345,678 100%   25.45MB/s    0:00:00 (xfr#2, to-chk=1/4)
MANUAL_BACKUP_20251104_153022_03
        567,890 100%    8.90MB/s    0:00:00 (xfr#3, to-chk=0/4)

Transfer complete
```

---

## Comandos RMAN Directos

Para mayor control, puedes ejecutar comandos RMAN directamente.

### Conectar a RMAN

```bash
vagrant ssh primary

sudo su - oracle
rman target /
```

**Salida:**

```
Recovery Manager: Release 21.0.0.0.0 - Production on Mon Nov 4 15:40:00 2025
Copyright (c) 1982, 2021, Oracle and/or its affiliates.  All rights reserved.

connected to target database: CDB1 (DBID=1234567890)

RMAN>
```

---

### Backup Completo (Full)

```rman
BACKUP AS COMPRESSED BACKUPSET
  DATABASE
  PLUS ARCHIVELOG
  TAG FULL_BACKUP_20251104;
```

**Qué hace:**
- Archiva todos los archive logs actuales
- Respalda todos los datafiles de todos los PDBs
- Respalda el CDB
- Respalda archive logs generados durante el backup
- Elimina archive logs del disco después de respaldarlos

**Tiempo:** 3-7 minutos

---

### Backup Incremental Level 0 (Base para Incrementales)

```rman
BACKUP AS COMPRESSED BACKUPSET
  INCREMENTAL LEVEL 0
  DATABASE
  TAG INCR0_20251104;
```

**Qué hace:**
- Crea un backup base (equivalente a full backup)
- Permite backups incrementales posteriores (Level 1)
- Más eficiente para estrategias de backup frecuentes

---

### Backup Incremental Level 1 (Solo Cambios)

```rman
BACKUP AS COMPRESSED BACKUPSET
  INCREMENTAL LEVEL 1
  DATABASE
  TAG INCR1_20251104;
```

**Qué hace:**
- Respalda solo bloques modificados desde el último Level 0 o Level 1
- Mucho más rápido que full backup
- Requiere tener un Level 0 previo

**Tiempo:** 30 segundos - 2 minutos (dependiendo de cambios)

---

### Backup Solo de Archive Logs

```rman
BACKUP AS COMPRESSED BACKUPSET
  ARCHIVELOG ALL
  DELETE INPUT;
```

**Qué hace:**
- Respalda todos los archive logs
- DELETE INPUT elimina los archives del disco después de respaldar
- Útil cuando /u01 está llenándose

**Tiempo:** 10-30 segundos

---

### Backup de Controlfile

```rman
BACKUP CURRENT CONTROLFILE
  FORMAT '/u02/backup/controlfile_%U';
```

**Cuándo usar:**
- Después de cambios estructurales (agregar datafiles, tablespaces)
- Antes de modificar configuración de Data Guard

---

### Backup de SPFILE

```rman
BACKUP SPFILE
  FORMAT '/u02/backup/spfile_%U';
```

**Cuándo usar:**
- Después de cambiar parámetros de inicialización
- Antes de pruebas que modifiquen configuración

---

### Backup con Validación

```rman
BACKUP AS COMPRESSED BACKUPSET
  DATABASE
  PLUS ARCHIVELOG
  TAG VALIDATED_BACKUP_20251104
  VALIDATE;
```

**Qué hace:**
- Realiza el backup
- Valida que el backup es utilizable para restore
- Detecta bloques corruptos

**Tiempo:** +20% sobre backup normal (vale la pena)

---

### Configuración de Políticas de Backup

```rman
-- Ver configuración actual
SHOW ALL;

-- Configurar retención de 7 días
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 7 DAYS;

-- Configurar autobackup de controlfile
CONFIGURE CONTROLFILE AUTOBACKUP ON;

-- Configurar formato de autobackup
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '/u02/backup/cf_%F';

-- Configurar paralelismo (2 canales)
CONFIGURE DEVICE TYPE DISK PARALLELISM 2;

-- Política de eliminación de archives
CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;
```

---

## Transferencia a Standby

Los backups deben transferirse al servidor standby para tener copias offsite.

### Método 1: rsync (Recomendado)

```bash
vagrant ssh primary

sudo su - oracle

# Transferir todos los backups del día
rsync -avz --progress /u02/backup/ oracle@ol8-21-dg2.localdomain:/u02/backup_from_primary/
```

**Salida:**

```
sending incremental file list
./
DAILY_BACKUP_20251104_01
     12,345,678 100%   25.45MB/s    0:00:00 (xfr#1, to-chk=5/7)
DAILY_BACKUP_20251104_02
      1,234,567 100%   15.23MB/s    0:00:00 (xfr#2, to-chk=4/7)
[... más archivos ...]

sent 13,580,245 bytes  received 135 bytes  27,160,760.00 bytes/sec
total size is 13,579,000  speedup is 1.00
```

**Ventajas de rsync:**
- Solo transfiere archivos nuevos o modificados
- Compresión durante transferencia
- Verificación de integridad
- Recuperable si se interrumpe

---

### Método 2: scp (Alternativo)

```bash
scp /u02/backup/MANUAL_BACKUP_* oracle@ol8-21-dg2.localdomain:/u02/backup_from_primary/
```

Más simple pero menos eficiente que rsync.

---

### Verificar Transferencia

**En standby:**

```bash
vagrant ssh standby

sudo su - oracle
ls -lh /u02/backup_from_primary/
```

**Debe mostrar:**

```
total 13M
-rw-r----- 1 oracle oinstall 12M Nov  4 15:35 MANUAL_BACKUP_20251104_153022_01
-rw-r----- 1 oracle oinstall 1.2M Nov  4 15:35 MANUAL_BACKUP_20251104_153022_02
-rw-r----- 1 oracle oinstall 555K Nov  4 15:35 MANUAL_BACKUP_20251104_153022_03
```

---

## Verificación de Respaldos

Verificar que los backups son válidos es crítico. Un backup corrupto es inútil en una emergencia.

### Método 1: RMAN LIST

```bash
vagrant ssh primary

sudo su - oracle
rman target / <<EOF
LIST BACKUP SUMMARY;
EXIT;
EOF
```

**Salida:**

```
List of Backups
===============
Key     TY LV S Device Type Completion Time #Pieces #Copies Compressed Tag
------- -- -- - ----------- --------------- ------- ------- ---------- ---
1230    B  F  A DISK        03-NOV-25       2       1       YES        DAILY_BACKUP_20251103
1231    B  A  A DISK        03-NOV-25       1       1       YES        DAILY_BACKUP_20251103
1232    B  F  A DISK        03-NOV-25       1       1       NO         DAILY_BACKUP_20251103
1234    B  F  A DISK        04-NOV-25       2       1       YES        MANUAL_BACKUP_20251104_153022
1235    B  A  A DISK        04-NOV-25       1       1       YES        MANUAL_BACKUP_20251104_153022
1236    B  F  A DISK        04-NOV-25       1       1       NO         MANUAL_BACKUP_20251104_153022
```

**Leyenda:**
- TY: Type (B=Backup, F=Full, A=Archivelog)
- LV: Level (F=Full, 0=Incremental Level 0, 1=Incremental Level 1)
- S: Status (A=Available, X=Expired)
- Compressed: YES (comprimido), NO (sin comprimir)

---

### Método 2: LIST BACKUP DETAIL

Para ver detalles completos de un backup específico:

```rman
LIST BACKUP OF DATABASE TAG 'MANUAL_BACKUP_20251104_153022';
```

**Salida:**

```
BS Key  Type LV Size       Device Type Elapsed Time Completion Time
------- ---- -- ---------- ----------- ------------ ---------------
1234    Full    3.50G      DISK        00:02:35     04-NOV-25
  BP Key: 1234   Status: AVAILABLE  Compressed: YES  Tag: MANUAL_BACKUP_20251104_153022
  Piece Name: /u02/backup/MANUAL_BACKUP_20251104_153022_02
  List of Datafiles in backup set 1234
  File LV Type Ckp SCN    Ckp Time  Abs Fuz SCN Sparse Name
  ---- -- ---- ---------- --------- ----------- ------ ----
  1       Full 2345678    04-NOV-25              NO    /u01/oradata/CDB1/system01.dbf
  3       Full 2345678    04-NOV-25              NO    /u01/oradata/CDB1/sysaux01.dbf
  4       Full 2345678    04-NOV-25              NO    /u01/oradata/CDB1/undotbs01.dbf
  [... más datafiles ...]
```

---

### Método 3: VALIDATE BACKUPSET

Valida físicamente que el backup es recuperable:

```rman
VALIDATE BACKUPSET 1234;
```

**Salida exitosa:**

```
allocated channel: ORA_DISK_1
channel ORA_DISK_1: SID=245 device type=DISK
channel ORA_DISK_1: starting validation of datafile backup set
channel ORA_DISK_1: reading from backup piece /u02/backup/MANUAL_BACKUP_20251104_153022_02
channel ORA_DISK_1: piece handle=/u02/backup/MANUAL_BACKUP_20251104_153022_02 tag=MANUAL_BACKUP_20251104_153022
channel ORA_DISK_1: restored backup piece 1
channel ORA_DISK_1: validation complete, elapsed time: 00:00:15
Finished validate at 04-NOV-25
```

Si hay errores, mostrará: `RMAN-06169: could not read file header` o similar.

---

### Método 4: RESTORE VALIDATE

Simula un restore completo sin escribir datos (el más completo):

```rman
RESTORE DATABASE VALIDATE;
```

**Qué hace:**
- Verifica que todos los datafiles pueden restaurarse
- Verifica que los backups están completos
- Verifica que no hay bloques corruptos
- NO modifica la base de datos actual

**Tiempo:** 2-5 minutos

**Salida exitosa:**

```
Starting restore at 04-NOV-25
allocated channel: ORA_DISK_1
channel ORA_DISK_1: SID=245 device type=DISK

channel ORA_DISK_1: starting validation of datafile backup set
channel ORA_DISK_1: reading from backup piece /u02/backup/MANUAL_BACKUP_20251104_153022_02
channel ORA_DISK_1: piece handle=/u02/backup/MANUAL_BACKUP_20251104_153022_02 tag=MANUAL_BACKUP_20251104_153022
channel ORA_DISK_1: restored backup piece 1
channel ORA_DISK_1: validation complete, elapsed time: 00:02:15
Finished restore at 04-NOV-25
```

---

## Catálogo de Respaldos

RMAN mantiene un catálogo interno de backups en el controlfile.

### Ver Todos los Backups

```rman
LIST BACKUP;
```

Muestra TODOS los backups (puede ser muy largo).

---

### Ver Backups por Fecha

```rman
LIST BACKUP COMPLETED AFTER 'SYSDATE-7';
```

Muestra backups de últimos 7 días.

---

### Ver Backups por Tag

```rman
LIST BACKUP TAG 'DAILY_BACKUP_20251104';
```

---

### Ver Backups Obsoletos

```rman
REPORT OBSOLETE;
```

Muestra backups que exceden la política de retención (7 días).

---

### Eliminar Backups Obsoletos

```rman
DELETE NOPROMPT OBSOLETE;
```

**Precaución:** Esto elimina permanentemente backups antiguos.

---

### Ver Espacio Usado por Backups

```bash
du -sh /u02/backup/
```

**Salida ejemplo:**

```
25G     /u02/backup/
```

---

### Eliminar Backup Específico

```rman
DELETE BACKUPSET 1234;
```

Donde 1234 es el BS Key del backup.

---

## Pruebas de Restore

Es crítico probar que los backups son restaurables. **Un backup no probado es un backup no confiable.**

### Recomendación: Probar en Standby

**Por qué:** El standby puede usarse para pruebas destructivas sin afectar el primary.

---

### Prueba 1: RESTORE DATABASE PREVIEW

```bash
vagrant ssh standby

sudo su - oracle
rman target / <<EOF
RESTORE DATABASE PREVIEW;
EXIT;
EOF
```

**Qué hace:**
- Muestra qué archivos de backup se usarían para restaurar
- NO restaura realmente
- Útil para planificar un restore

**Salida:**

```
List of Backup Sets
===================

BS Key  Type LV Size       Device Type Elapsed Time Completion Time
------- ---- -- ---------- ----------- ------------ ---------------
1234    Full    3.50G      DISK        00:02:35     04-NOV-25
        BP Key: 1234   Status: AVAILABLE  Compressed: YES
        Piece Name: /u02/backup/MANUAL_BACKUP_20251104_153022_02
  List of Datafiles in backup set 1234
  File LV Type Ckp SCN    Ckp Time  Name
  ---- -- ---- ---------- --------- ----
  1       Full 2345678    04-NOV-25 /u01/oradata/CDB1/system01.dbf
  [... más datafiles ...]
```

---

### Prueba 2: RESTORE VALIDATE (Ya Explicada)

Ver sección anterior "Método 4: RESTORE VALIDATE".

---

### Prueba 3: Restore a Localización Diferente (Avanzado)

Restaurar backup a un directorio diferente para inspección:

```rman
RUN {
  SET NEWNAME FOR DATABASE TO '/u02/restore_test/%b';
  RESTORE DATABASE;
}
```

**Precaución:** Requiere espacio adicional y es avanzado. No recomendado para principiantes.

---

### Prueba 4: Restore de Un Solo Datafile

```rman
RESTORE DATAFILE 1 VALIDATE;
```

Valida que el datafile 1 (SYSTEM) puede restaurarse.

---

## Checklist de Respaldos

### Checklist Pre-Backup

- [ ] Verificar espacio en disco disponible en /u02 (>10GB libre)
- [ ] Confirmar que no hay otros backups corriendo
- [ ] Revisar alert log por errores recientes
- [ ] Documentar razón del backup (para logs)

### Checklist Durante Backup

- [ ] Monitorear progreso (si es desde sesión interactiva)
- [ ] Verificar que no hay errores en la salida
- [ ] Anotar tiempo de inicio y fin
- [ ] Anotar tamaño del backup

### Checklist Post-Backup

- [ ] Verificar que backup completó exitosamente
- [ ] Ejecutar LIST BACKUP SUMMARY
- [ ] Ejecutar VALIDATE BACKUPSET
- [ ] Transferir a standby
- [ ] Verificar transferencia en standby
- [ ] Ejecutar RESTORE VALIDATE (opcional pero recomendado)
- [ ] Documentar backup en log de operaciones
- [ ] Verificar espacio en disco restante

### Checklist Semanal (Backups en General)

- [ ] Ejecutar RESTORE VALIDATE en al menos un backup de la semana
- [ ] Verificar que backups automáticos están corriendo
- [ ] Revisar logs de RMAN por warnings
- [ ] Limpiar backups obsoletos (DELETE OBSOLETE)
- [ ] Verificar espacio en /u02 en primary y standby
- [ ] Documentar estado en reporte semanal

---

## Comandos de Referencia Rápida

### Backup Completo Rápido

```bash
vagrant ssh primary -c "sudo su - oracle -c 'rman target / << EOF
BACKUP AS COMPRESSED BACKUPSET DATABASE PLUS ARCHIVELOG TAG QUICK_BACKUP;
EXIT;
EOF'"
```

---

### Ver Último Backup

```bash
vagrant ssh primary -c "sudo su - oracle -c 'rman target / << EOF
LIST BACKUP SUMMARY;
EXIT;
EOF' | tail -20"
```

---

### Validar Último Backup

```bash
vagrant ssh primary -c "sudo su - oracle -c 'rman target / << EOF
RESTORE DATABASE VALIDATE;
EXIT;
EOF'"
```

---

### Transferir Backups a Standby

```bash
vagrant ssh primary -c "sudo su - oracle -c 'rsync -avz /u02/backup/ oracle@ol8-21-dg2.localdomain:/u02/backup_from_primary/'"
```

---

### Eliminar Backups Obsoletos

```bash
vagrant ssh primary -c "sudo su - oracle -c 'rman target / << EOF
DELETE NOPROMPT OBSOLETE;
EXIT;
EOF'"
```

---

## Escenarios Comunes

### Escenario 1: Backup Antes de Cambio de Schema

```bash
# 1. Ejecutar backup
vagrant ssh primary -c "/home/oracle/automation/manual_backup.sh"

# 2. Responder 'yes' dos veces (backup y transfer)

# 3. Verificar
vagrant ssh primary -c "sudo su - oracle -c 'rman target / << EOF
LIST BACKUP SUMMARY;
EXIT;
EOF'"

# 4. Ahora es seguro hacer cambios al schema
sqlplus HEALTHCENTER/HCApp2025!@localhost:1521/pdb1 <<EOF
-- Tus cambios aquí
EOF
```

---

### Escenario 2: Backup a Petición del Profesor

Durante revisión del proyecto:

```bash
# Ejecutar backup inmediato
vagrant ssh primary -c "/home/oracle/automation/manual_backup.sh"

# Mostrar que backup está en standby
vagrant ssh standby -c "ls -lh /u02/backup_from_primary/ | tail -10"

# Validar backup
vagrant ssh primary -c "sudo su - oracle -c 'rman target / << EOF
RESTORE DATABASE VALIDATE;
EXIT;
EOF'"
```

---

### Escenario 3: Backup Después de Carga de Datos

```bash
# 1. Cargar datos
sqlplus HEALTHCENTER/HCApp2025!@localhost:1521/pdb1 <<EOF
@load_data_script.sql
COMMIT;
EOF

# 2. Backup inmediato
vagrant ssh primary -c "/home/oracle/automation/manual_backup.sh"

# 3. Forzar sincronización con standby
vagrant ssh primary -c "sudo su - oracle -c 'sqlplus / as sysdba << EOF
ALTER SYSTEM ARCHIVE LOG CURRENT;
EXIT;
EOF'"
```

---

## Referencias

- [90 - Monitoreo Diario](90-monitoreo-diario.md) - Verificación de backups automáticos
- [94 - Troubleshooting](94-troubleshooting.md) - Solución de problemas de backup
- [Oracle RMAN Documentation](https://docs.oracle.com/en/database/oracle/oracle-database/21/bradv/)
- [RMAN Best Practices](https://docs.oracle.com/en/database/oracle/oracle-database/21/bradv/rman-backup-concepts.html)

---

**Nota Final:** Los respaldos son la última línea de defensa contra pérdida de datos. Asegúrate de que siempre hay backups válidos y probados disponibles.
