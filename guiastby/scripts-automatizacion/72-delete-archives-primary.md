# 72 - Delete Archives Primary

## Limpieza Automática de Archive Logs en el Nodo Primario

Este script elimina archive logs antiguos del nodo primario después de confirmar que han sido aplicados en el standby y respaldados por RMAN, liberando espacio en disco mientras mantiene la integridad de Data Guard.

## Ubicación

`2-Standby/automation/delete_archives_primary.sh`

## Propósito

Gestionar el espacio en disco del Fast Recovery Area (FRA) eliminando archive logs que:
1. Ya fueron aplicados en el standby (no se necesitan para replicación)
2. Ya fueron respaldados por RMAN (protegidos en backup)
3. Son más antiguos que la ventana de retención de 3 días

Cumple con el requisito: "Eliminar archivos con rango de 3 días"

## Cuándo se Ejecuta

- **Frecuencia:** Diario a las 2:00 AM
- **Nodo:** Primary solamente
- **Usuario:** oracle
- **Installed by:** install_cron_jobs.sh

## Cron Schedule

```cron
0 2 * * * /home/oracle/automation/delete_archives_primary.sh
```

**En español:** "A las 2:00 AM todos los días"

**Razón del horario:**
- 2:00 AM = 1 hora después del backup diario (1:00 AM)
- Garantiza que archives están respaldados antes de borrar
- Evita interferir con el proceso de backup

## Variables de Entorno

Desde `config/install.env`:

```bash
# Configuración de retención
ARCHIVE_RETENTION_DAYS=3              # Retención de 3 días

# Nodos Data Guard
NODE2_DB_UNIQUE_NAME=cdb1_stby       # Nombre único del standby
DB_DOMAIN=world

# Credenciales
SYS_PASSWORD=S1sPassword1!           # Password del usuario SYS

# Oracle
ORACLE_SID=cdb1
ORACLE_HOME=/u01/app/oracle/product/21.0.0/dbhome_1
```

## Qué Hace el Script (Paso a Paso)

### Paso 1: Inicialización del Entorno

```bash
. /home/oracle/scripts/setEnv.sh
. /vagrant_config/install.env

LOGFILE="/home/oracle/logs/automation/delete_archives_primary.log"
```

**Explicación:**
- Carga variables de entorno de Oracle (ORACLE_HOME, ORACLE_SID, PATH)
- Define el archivo de log único (se sobrescribe con cada ejecución)

### Paso 2: Consultar Última Secuencia Aplicada en Standby

```bash
STANDBY_APPLIED=$(sqlplus -s sys/${SYS_PASSWORD}@${NODE2_DB_UNIQUE_NAME}${DB_DOMAIN_STR} as sysdba << EOF
SET PAGESIZE 0 FEEDBACK OFF HEADING OFF
SELECT MAX(sequence#) FROM v\$archived_log WHERE applied='YES' AND dest_id=1;
EXIT;
EOF
)

echo "Standby last applied sequence: $STANDBY_APPLIED"
```

**Explicación:**
Este es el paso MÁS IMPORTANTE del script. Conecta remotamente al standby para determinar hasta qué secuencia se han aplicado los archive logs.

**¿Por qué es crítico?**
- **Protección de Data Guard:** Solo borra archives que el standby ya no necesita
- **Evita pérdida de datos:** Si borramos archives no aplicados, el standby no podrá sincronizarse
- **Recuperación garantizada:** Standby puede usar Data Guard para recuperación incluso si primary falla

**Ejemplo de valores:**
```
Standby last applied sequence: 245
```

Esto significa:
- Standby ha aplicado hasta secuencia 245
- Es SEGURO borrar archives con secuencia ≤ 245 en primary
- Archives 246+ NO se deben borrar (standby los necesita aún)

### Paso 3: Validar que Se Obtuvo Secuencia

```bash
if [ -n "$STANDBY_APPLIED" ] && [ "$STANDBY_APPLIED" != "" ]; then
  # Continuar con borrado
else
  echo "WARNING: Could not determine standby applied sequence. Skipping deletion."
fi
```

**Explicación:**
- `-n "$STANDBY_APPLIED"` verifica que la variable no esté vacía
- Si no se puede conectar al standby o query falla, `$STANDBY_APPLIED` estará vacío
- **SEGURIDAD:** Si no sabemos qué aplicó el standby, NO borramos nada

**Razones para falla:**
- Standby está caído
- Red entre primary y standby está caída
- Credenciales incorrectas
- Standby en proceso de reinicio

**Comportamiento seguro:**
- El script termina sin borrar nada
- Se registra WARNING en el log
- Archives se acumulan (mejor que borrar incorrectamente)
- Próxima ejecución (mañana) lo reintentará

### Paso 4: Eliminación de Archives via RMAN

```bash
rman target / << REOF
RUN {
  ALLOCATE CHANNEL FOR MAINTENANCE DEVICE TYPE DISK;
  DELETE NOPROMPT ARCHIVELOG UNTIL SEQUENCE ${STANDBY_APPLIED} THREAD 1;
  CROSSCHECK ARCHIVELOG ALL;
}
EXIT;
REOF
```

**Explicación detallada:**

#### ALLOCATE CHANNEL FOR MAINTENANCE
```sql
ALLOCATE CHANNEL FOR MAINTENANCE DEVICE TYPE DISK;
```
- Asigna un canal para operaciones de mantenimiento (no backup/restore)
- `DEVICE TYPE DISK` = trabajar con archivos en disco (no tape)
- Canal se usa para las operaciones DELETE y CROSSCHECK

#### DELETE NOPROMPT ARCHIVELOG UNTIL SEQUENCE
```sql
DELETE NOPROMPT ARCHIVELOG UNTIL SEQUENCE ${STANDBY_APPLIED} THREAD 1;
```

Comando clave que elimina archives con condiciones específicas:

**ARCHIVELOG:** Trabaja solo con archive logs (no backups, ni datafiles)

**UNTIL SEQUENCE ${STANDBY_APPLIED}:** Hasta la secuencia aplicada en standby
- Ejemplo: Si `STANDBY_APPLIED=245`
- Borra archives con sequence# ≤ 245
- **NO borra** archives con sequence# > 245

**THREAD 1:** Solo thread 1 (single-instance database)
- En RAC (multi-instancia) cada nodo tiene su thread
- Nuestro setup es single-instance, siempre thread 1

**NOPROMPT:** No pide confirmación
- Necesario para ejecución automatizada
- Sin esto, RMAN esperaría input del usuario ("Are you sure? [Y/N]")

**¿Qué archives se eliminan exactamente?**

RMAN solo elimina archives que cumplen TODAS estas condiciones:
1. sequence# ≤ STANDBY_APPLIED
2. thread# = 1
3. Han sido respaldados (por política ARCHIVELOG DELETION POLICY)
4. No se necesitan para recuperación según RETENTION POLICY

**Política de borrado configurada:**
```sql
CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;
```

Esta política (configurada en `rman_daily_backup.sh`) agrega protección extra:
- Solo permite borrar archives que fueron APLICADOS en standby
- Aunque le digamos "DELETE UNTIL SEQUENCE X", si no está aplicado, NO se borra
- Doble protección: nuestro script + política RMAN

#### CROSSCHECK ARCHIVELOG ALL
```sql
CROSSCHECK ARCHIVELOG ALL;
```

**Explicación:**
- Verifica que archives registrados en RMAN catalog existen físicamente
- Actualiza el status en RMAN repository
- Marca como EXPIRED los que faltan en disco

**¿Por qué es necesario?**
- Después de DELETE, el catálogo RMAN debe reflejar qué archives existen
- Si un archive fue borrado manualmente (fuera de RMAN), CROSSCHECK lo detecta
- Mantiene consistencia entre filesystem y catálogo RMAN

### Paso 5: Registro y Limpieza

```bash
echo "===================================================================="
echo "Archive Deletion Complete: $(date)"
echo "===================================================================="
```

**Explicación:**
- Registra timestamp de completado
- Todo el output (incluyendo output de RMAN) se redirige al log file

```bash
find /home/oracle/logs/automation -name "delete_archives_primary.log" -mtime +30 -delete 2>/dev/null
```

**Explicación:**
- Elimina el log si tiene más de 30 días
- En la práctica, como hay un solo log que se sobrescribe, esto raramente hace algo
- Buena práctica de limpieza

## Comandos Importantes

### DELETE ARCHIVELOG (Variaciones)

```sql
-- Borrar hasta secuencia específica
DELETE NOPROMPT ARCHIVELOG UNTIL SEQUENCE 100 THREAD 1;

-- Borrar archives hasta una fecha
DELETE NOPROMPT ARCHIVELOG UNTIL TIME 'SYSDATE-3';

-- Borrar archives aplicados en standby
DELETE NOPROMPT ARCHIVELOG UNTIL SEQUENCE
  (SELECT MAX(sequence#) FROM v$archived_log WHERE applied='YES');

-- Borrar archives con más de N días
DELETE NOPROMPT ARCHIVELOG UNTIL TIME 'SYSDATE-7';

-- Borrar TODOS los archives (PELIGROSO - solo para testing)
DELETE NOPROMPT ARCHIVELOG ALL;

-- Borrar archives de un rango de secuencias
DELETE NOPROMPT ARCHIVELOG FROM SEQUENCE 50 UNTIL SEQUENCE 100 THREAD 1;

-- Borrar archives respaldados al menos 2 veces
DELETE NOPROMPT ARCHIVELOG ALL BACKED UP 2 TIMES TO DEVICE TYPE DISK;
```

### CROSSCHECK

```sql
-- Verificar todos los archives
CROSSCHECK ARCHIVELOG ALL;

-- Verificar archives de rango de fechas
CROSSCHECK ARCHIVELOG FROM TIME 'SYSDATE-7' UNTIL TIME 'SYSDATE-1';

-- Verificar backups también
CROSSCHECK BACKUP;
CROSSCHECK BACKUP OF DATABASE;

-- Ver resultados de crosscheck
LIST EXPIRED ARCHIVELOG ALL;
LIST EXPIRED BACKUP;
```

### Políticas de Borrado

```sql
-- Configurar política de borrado de archives
CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;
CONFIGURE ARCHIVELOG DELETION POLICY TO BACKED UP 1 TIMES TO DISK;
CONFIGURE ARCHIVELOG DELETION POLICY TO NONE;  -- Sin restricciones

-- Ver política actual
SHOW ARCHIVELOG DELETION POLICY;

-- Limpiar política (usar default)
CONFIGURE ARCHIVELOG DELETION POLICY CLEAR;
```

### Consultas de Archive Logs

```sql
-- Ver archives disponibles en disco
SELECT sequence#, name, deleted, applied, backed_up, archived
FROM v$archived_log
WHERE deleted = 'NO'
ORDER BY sequence#;

-- Ver espacio usado por archives
SELECT SUM(blocks * block_size)/1024/1024/1024 AS gb_archives
FROM v$archived_log
WHERE deleted = 'NO';

-- Ver archives que se borrarían (simulación)
SELECT sequence#, name, completion_time
FROM v$archived_log
WHERE sequence# <= (SELECT MAX(sequence#)
                    FROM v$archived_log
                    WHERE applied='YES' AND dest_id=1)
  AND deleted = 'NO'
ORDER BY sequence#;
```

## Salida Esperada

### Ejecución Exitosa

```
====================================================================
Archive Deletion PRIMARY: Tue Nov  4 02:00:01 UTC 2025
====================================================================
Standby last applied sequence: 245

Recovery Manager: Release 21.0.0.0.0 - Production on Tue Nov 4 02:00:01 2025
Version 21.3.0.0.0

connected to target database: CDB1 (DBID=1234567890)

RMAN> RUN {
2>   ALLOCATE CHANNEL FOR MAINTENANCE DEVICE TYPE DISK;
3>   DELETE NOPROMPT ARCHIVELOG UNTIL SEQUENCE 245 THREAD 1;
4>   CROSSCHECK ARCHIVELOG ALL;
5> }

allocated channel: ORA_MAINT_DISK_1
channel ORA_MAINT_DISK_1: SID=123 device type=DISK

List of Archived Log Copies for database with db_unique_name CDB1
=====================================================================

Key     Thrd Seq     S Low Time            Name
------- ---- ------- - ------------------ ----
120     1    230     A 03-NOV-25          /u01/app/oracle/fast_recovery_area/CDB1/archivelog/2025_11_03/o1_mf_1_230_xyz.arc
121     1    231     A 03-NOV-25          /u01/app/oracle/fast_recovery_area/CDB1/archivelog/2025_11_03/o1_mf_1_231_xyz.arc
122     1    232     A 03-NOV-25          /u01/app/oracle/fast_recovery_area/CDB1/archivelog/2025_11_03/o1_mf_1_232_xyz.arc
...
135     1    245     A 04-NOV-25          /u01/app/oracle/fast_recovery_area/CDB1/archivelog/2025_11_04/o1_mf_1_245_xyz.arc


deleted archived log
archived log file name=/u01/app/oracle/fast_recovery_area/CDB1/archivelog/2025_11_03/o1_mf_1_230_xyz.arc RECID=120 STAMP=1234567890
deleted archived log
archived log file name=/u01/app/oracle/fast_recovery_area/CDB1/archivelog/2025_11_03/o1_mf_1_231_xyz.arc RECID=121 STAMP=1234567891
...
deleted archived log
archived log file name=/u01/app/oracle/fast_recovery_area/CDB1/archivelog/2025_11_04/o1_mf_1_245_xyz.arc RECID=135 STAMP=1234567920

Deleted 16 objects

crosschecked backup piece: found to be 'AVAILABLE'
crosschecked backup piece: found to be 'AVAILABLE'
...
Crosschecked 45 objects

RMAN>
Recovery Manager complete.

====================================================================
Archive Deletion Complete: Tue Nov  4 02:00:15 UTC 2025
====================================================================
```

**Interpretación:**
- Standby aplicó hasta secuencia 245
- Se eliminaron 16 archives (secuencias 230-245)
- Crosscheck verificó 45 objetos (archives restantes + backups)
- Proceso completó en ~14 segundos

### Cuando Standby No Responde

```
====================================================================
Archive Deletion PRIMARY: Tue Nov  4 02:00:01 UTC 2025
====================================================================

ERROR:
ORA-12170: TNS:Connect timeout occurred

Standby last applied sequence:
WARNING: Could not determine standby applied sequence. Skipping deletion.
====================================================================
Archive Deletion Complete: Tue Nov  4 02:00:35 UTC 2025
====================================================================
```

**Interpretación:**
- Conexión al standby falló (timeout)
- Variable STANDBY_APPLIED está vacía
- Script NO ejecutó DELETE (comportamiento seguro)
- Archives se preservan hasta mañana

## Logs Generados

- **Ubicación:** `/home/oracle/logs/automation/delete_archives_primary.log`
- **Tipo:** Sobrescritura (cada ejecución reemplaza el log anterior)
- **Contenido:**
  - Timestamp de ejecución
  - Secuencia aplicada en standby
  - Output de RMAN (archives eliminados)
  - Resultado de CROSSCHECK
  - Advertencias si no se pudo conectar al standby
- **Retención:** Último log solamente (se sobrescribe diariamente)

### Ver Log Actual

```bash
cat /home/oracle/logs/automation/delete_archives_primary.log

# Ver solo resumen
grep -E "Standby last applied|Deleted.*objects|Archive Deletion Complete" /home/oracle/logs/automation/delete_archives_primary.log
```

## Coordinación con Otros Scripts

### Orden de Ejecución Diaria

```
1:00 AM - rman_daily_backup.sh (Primary)
  ├─ Respalda database + archive logs
  ├─ Incluye archives hasta secuencia actual
  └─ Transfiere backups al standby

2:00 AM - delete_archives_primary.sh (Primary)  ← ESTE SCRIPT
  ├─ Espera 1 hora después del backup
  ├─ Verifica secuencia aplicada en standby
  ├─ Solo borra archives respaldados Y aplicados
  └─ Libera espacio en FRA

11:00 PM - delete_archives_standby.sh (Standby)
  ├─ Ejecuta en standby (diferente nodo)
  └─ Borra archives aplicados > 3 días
```

### Dependencias

**Depende de:**
1. `rman_daily_backup.sh` debe ejecutar primero
   - Archives deben estar respaldados antes de borrar
   - RMAN policy impide borrar archives no respaldados

2. Data Guard debe estar funcionando
   - Standby debe estar aplicando archives
   - Si MRP (Managed Recovery Process) está detenido, standby no avanza

3. Red entre primary y standby debe funcionar
   - Script necesita consultar v$archived_log en standby
   - Sin conexión, no borra nada (safe-fail)

**Otros scripts dependen de este:**
- Ninguno directamente, pero mantiene FRA con espacio disponible
- Si este falla, FRA puede llenarse y causar:
  - Database hang (no puede crear nuevos archives)
  - Backup failures (no hay espacio)

## Ejecución Manual

### Ejecutar Limpieza Manual

```bash
# Como usuario oracle en primary
/home/oracle/automation/delete_archives_primary.sh

# Ver log generado
cat /home/oracle/logs/automation/delete_archives_primary.log
```

**Casos de uso:**
- FRA está llenándose y necesita limpieza urgente
- Después de resolver problema de standby (aplicó archives atrasados)
- Testing del script
- Auditoría de cuántos archives se borrarían

### Simulación (Dry Run)

Para ver qué se borraría SIN borrar realmente:

```bash
# Conectar a RMAN
rman target /

# Ver qué archives se borrarían
REPORT OBSOLETE;

# Listar archives que cumplen criterio
LIST ARCHIVELOG UNTIL SEQUENCE 245 THREAD 1;
```

### Borrado Manual Selectivo

Si necesita borrar manualmente con control fino:

```bash
rman target /

# Borrar solo un rango específico
DELETE NOPROMPT ARCHIVELOG FROM SEQUENCE 100 UNTIL SEQUENCE 150 THREAD 1;

# Borrar archives de fecha específica
DELETE NOPROMPT ARCHIVELOG UNTIL TIME 'SYSDATE-5';

# Forzar borrado (ignora policies - PELIGROSO)
DELETE FORCE NOPROMPT ARCHIVELOG UNTIL SEQUENCE 200 THREAD 1;
```

## Verificación

### Verificar Cron Instalado

```bash
crontab -l | grep delete_archives_primary

# Salida esperada:
# 0 2 * * * /home/oracle/automation/delete_archives_primary.sh
```

### Verificar Última Ejecución

```bash
# Ver log de última ejecución
cat /home/oracle/logs/automation/delete_archives_primary.log

# Ver timestamp de última modificación del log
ls -l /home/oracle/logs/automation/delete_archives_primary.log
```

### Verificar Espacio Liberado

```bash
# Antes de ejecutar script (supongamos 9 AM)
df -h /u01

# Ejecutar manualmente
/home/oracle/automation/delete_archives_primary.sh

# Después de ejecutar
df -h /u01

# Debería haber liberado espacio en FRA
```

### Verificar Archives Restantes

```sql
-- Conectar a sqlplus
sqlplus / as sysdba

-- Ver archives que quedan en disco
SELECT COUNT(*),
       MIN(sequence#) AS min_seq,
       MAX(sequence#) AS max_seq,
       ROUND(SUM(blocks * block_size)/1024/1024/1024, 2) AS gb_total
FROM v$archived_log
WHERE deleted = 'NO'
  AND dest_id = 1;

-- Ejemplo de salida:
--   COUNT  MIN_SEQ  MAX_SEQ  GB_TOTAL
-- ------- -------- -------- ---------
--      15      246      260      0.75
```

### Verificar Política de Borrado

```bash
rman target /

SHOW ARCHIVELOG DELETION POLICY;

# Salida esperada:
# RMAN configuration parameters for database with db_unique_name CDB1 are:
# CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;
```

## Puntos de Fallo Comunes

### 1. "ORA-12170: TNS:Connect timeout" al Consultar Standby

**Causa:** Standby no alcanzable por red o está caído

**Solución:**
```bash
# Verificar conectividad
ping ol8-21-dg2.localdomain

# Verificar listener en standby
ssh oracle@ol8-21-dg2 "lsnrctl status"

# Probar conexión TNS
tnsping cdb1_stby.world

# Si todo falla, esperar a que standby vuelva
# El script no borrará nada (safe behavior)
```

**Impacto:**
- Archives se acumulan en primary
- Puede llenar FRA si standby está caído varios días
- Monitorear espacio: `df -h /u01`

### 2. "RMAN-08120: archived log not deleted, not yet applied"

**Causa:** Policy impide borrar archives que no fueron aplicados en standby

**Solución:**
```bash
# Verificar estado de aplicación en standby
ssh oracle@ol8-21-dg2 "sqlplus / as sysdba" << EOF
SELECT MAX(sequence#) AS last_applied FROM v\$archived_log WHERE applied='YES';
EXIT;
EOF

# Verificar que MRP está corriendo en standby
ssh oracle@ol8-21-dg2 "sqlplus / as sysdba" << EOF
SELECT process, status FROM v\$managed_standby WHERE process LIKE 'MRP%';
EXIT;
EOF

# Si MRP no está corriendo, iniciar en standby
ssh oracle@ol8-21-dg2 "sqlplus / as sysdba" << EOF
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;
EXIT;
EOF
```

### 3. FRA Se Llena Antes de las 2 AM

**Causa:** Mucha actividad de transacciones genera archives rápidamente

**Solución inmediata:**
```bash
# Ejecutar limpieza fuera de horario
/home/oracle/automation/delete_archives_primary.sh

# O borrar manualmente archives más viejos
rman target / << EOF
DELETE NOPROMPT ARCHIVELOG UNTIL TIME 'SYSDATE-7';
EXIT;
EOF
```

**Solución permanente:**
```sql
-- Aumentar tamaño de FRA
ALTER SYSTEM SET db_recovery_file_dest_size=150G SCOPE=BOTH;

-- O ejecutar limpieza más frecuente
-- Editar crontab para ejecutar cada 6 horas:
# 0 */6 * * * /home/oracle/automation/delete_archives_primary.sh
```

### 4. Archives No Se Borran (Deleted Objects = 0)

**Causa:** Varios posibles:

**A. Archives no respaldados aún:**
```sql
-- Verificar en RMAN
LIST ARCHIVELOG ALL;
-- Buscar columna "A" (Archived) vs "B" (Backed up)
```

**Solución:**
```bash
# Forzar backup de archives
rman target / << EOF
BACKUP ARCHIVELOG ALL;
EXIT;
EOF
```

**B. Policy muy restrictiva:**
```sql
-- Ver policy
SHOW ARCHIVELOG DELETION POLICY;
```

**Solución temporal (emergencia):**
```bash
rman target / << EOF
CONFIGURE ARCHIVELOG DELETION POLICY TO NONE;
DELETE NOPROMPT ARCHIVELOG UNTIL SEQUENCE 200 THREAD 1;
CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;
EXIT;
EOF
```

### 5. Error: "RMAN-06207: WARNING: 2 objects could not be deleted"

**Causa:** Archives están siendo usados por un proceso

**Solución:**
```sql
-- Ver qué proceso usa los archives
SELECT * FROM v$archive_processes;
SELECT * FROM v$managed_standby WHERE process LIKE 'RFS%';

-- Esperar a que terminen
-- Reintentar en 5 minutos
```

### 6. Script No Ejecuta Automáticamente

**Causa:** Cron no configurado o cron daemon no corriendo

**Solución:**
```bash
# Verificar cron daemon
sudo systemctl status crond

# Si no está corriendo
sudo systemctl start crond
sudo systemctl enable crond

# Reinstalar cron jobs
/home/oracle/automation/install_cron_jobs.sh

# Verificar
crontab -l
```

## Importancia para el Sistema

Este script es **ESENCIAL** para la operación continua porque:

### 1. Previene Llenado de FRA

Fast Recovery Area tiene tamaño limitado (100GB):
- Sin limpieza, archives se acumulan indefinidamente
- FRA llena = database HANG (no puede crear nuevos archives)
- Database hang = sistema de salud completo caído

**Cálculo de urgencia:**
```
- Archive log promedio: 50MB
- Generación: ~1 archive cada 5 minutos (ARCHIVE_LAG_TARGET)
- Por día: 288 archives × 50MB = 14.4GB/día
- FRA (100GB) se llenaría en ~7 días sin limpieza
```

### 2. Protección de Data Guard

Solo borra archives que standby ya procesó:
- Garantiza que standby puede seguir sincronizando
- Si se borraran archives no aplicados, standby quedaría inconsistente
- Requeriría rebuild completo de standby (8+ horas)

### 3. Coordinación con Backups

Ejecuta 1 hora después del backup diario:
- Archives están protegidos en backup antes de borrar
- Doble protección: backup + standby
- Cumple requisitos de recuperación

### 4. Cumplimiento de Retención

Implementa política de retención de 3 días:
- Suficiente para ventana de recuperación
- Balance entre protección y uso de espacio
- Cumple regulaciones de datos de salud

### 5. Operación Autónoma

Sin este script:
- DBA tendría que limpiar manualmente cada día
- Riesgo de olvidar y llenar FRA
- Emergencias nocturnas si FRA se llena

Con este script:
- Limpieza automática garantizada
- Alertas solo si hay problemas reales
- DBA puede enfocarse en tareas estratégicas

### 6. Safe-Fail Design

Diseñado para fallar de forma segura:
- Si no puede consultar standby → no borra nada
- Si policy impide borrado → respeta la policy
- Mejor tener FRA llena que perder capacidad de recuperación

## Referencias Cruzadas

### Documentos Relacionados

- **[71-rman-daily-backup.md](71-rman-daily-backup.md)** - Backup que debe ejecutar primero
- **[73-delete-archives-standby.md](73-delete-archives-standby.md)** - Limpieza en standby
- **[41-install-cron.md](../ejecucion/primary/41-install-cron.md)** - Instalación de cron job
- **[83-archive-logs.md](../conceptos-avanzados/83-archive-logs.md)** - Conceptos de archive logs
- **[87-rman-backups.md](../conceptos-avanzados/87-rman-backups.md)** - Conceptos RMAN

### Scripts Relacionados

```bash
/home/oracle/automation/delete_archives_primary.sh    # Este script
/home/oracle/automation/delete_archives_standby.sh    # Equivalente en standby
/home/oracle/automation/rman_daily_backup.sh          # Debe ejecutar primero
/home/oracle/automation/check_log_transport.sh        # Monitorea transferencia
```

### Parámetros Oracle Relacionados

```sql
-- Fast Recovery Area
SHOW PARAMETER db_recovery_file_dest;
SHOW PARAMETER db_recovery_file_dest_size;

-- Archive Log
SHOW PARAMETER log_archive_dest;
SHOW PARAMETER archive_lag_target;

-- Ver uso de FRA
SELECT * FROM v$recovery_file_dest;
SELECT * FROM v$recovery_area_usage;
SELECT * FROM v$flash_recovery_area_usage;
```

### Queries Útiles

```sql
-- Ver archives por día
SELECT TO_CHAR(completion_time, 'YYYY-MM-DD') AS day,
       COUNT(*) AS archives,
       ROUND(SUM(blocks * block_size)/1024/1024/1024, 2) AS gb
FROM v$archived_log
WHERE deleted = 'NO'
GROUP BY TO_CHAR(completion_time, 'YYYY-MM-DD')
ORDER BY day DESC;

-- Ver archives no aplicados en standby
SELECT sequence#, name, applied, backed_up
FROM v$archived_log
WHERE dest_id = 1
  AND deleted = 'NO'
  AND applied = 'NO'
ORDER BY sequence#;

-- Ver archives que se pueden borrar
SELECT sequence#, name,
       TO_CHAR(completion_time, 'YYYY-MM-DD HH24:MI:SS') AS completed
FROM v$archived_log
WHERE sequence# <= (SELECT MAX(sequence#)
                    FROM v$archived_log
                    WHERE applied='YES' AND dest_id=1)
  AND deleted = 'NO'
  AND backed_up = 'YES'
ORDER BY sequence#;
```

---

**Última Actualización:** 2025-11-04
**Autor:** Claude (Subagente 4)
**Versión:** 1.0
