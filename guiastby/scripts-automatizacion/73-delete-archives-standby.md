# 73 - Delete Archives Standby

## Limpieza Automática de Archive Logs en el Nodo Standby

Este script elimina archive logs del nodo standby después de confirmar que han sido aplicados al standby database, manteniendo solo archives de los últimos 3 días y liberando espacio en el Fast Recovery Area.

## Ubicación

`2-Standby/automation/delete_archives_standby.sh`

## Propósito

Gestionar el espacio en disco del Fast Recovery Area (FRA) en el standby eliminando archive logs que:
1. Ya fueron aplicados al standby database (integrados en datafiles)
2. Tienen más de 3 días de antigüedad (fuera de ventana de retención)
3. No son necesarios para recuperación del standby

Cumple con el requisito: "Eliminar archivos aplicados con retención de 3 días"

## Cuándo se Ejecuta

- **Frecuencia:** Diario a las 11:00 PM
- **Nodo:** Standby solamente
- **Usuario:** oracle
- **Installed by:** install_cron_jobs.sh

## Cron Schedule

```cron
0 23 * * * /home/oracle/automation/delete_archives_standby.sh
```

**En español:** "A las 11:00 PM (23:00 horas) todos los días"

**Razón del horario:**
- 11:00 PM = final del día, después de toda la actividad
- No interfiere con transferencias de backup desde primary
- Permite que archives del día se apliquen antes de borrar

## Variables de Entorno

Desde `config/install.env`:

```bash
# Configuración de retención
ARCHIVE_RETENTION_DAYS=3              # Retención de 3 días

# Oracle
ORACLE_SID=cdb1                       # Mismo SID que primary
ORACLE_HOME=/u01/app/oracle/product/21.0.0/dbhome_1
```

## Qué Hace el Script (Paso a Paso)

### Paso 1: Inicialización del Entorno

```bash
. /home/oracle/scripts/setEnv.sh
. /vagrant_config/install.env

LOGFILE="/home/oracle/logs/automation/delete_archives_standby.log"
```

**Explicación:**
- Carga variables de entorno de Oracle
- Define archivo de log (se sobrescribe con cada ejecución)
- En standby, ORACLE_SID es igual al primary pero DB_UNIQUE_NAME es cdb1_stby

### Paso 2: Consultar Última Secuencia Aplicada Antigua

```bash
MAX_OLD_SEQ=$(sqlplus -s / as sysdba << EOF
SET PAGESIZE 0 FEEDBACK OFF HEADING OFF
SELECT MAX(sequence#)
FROM v\$archived_log
WHERE applied = 'YES'
  AND completion_time < SYSDATE - ${ARCHIVE_RETENTION_DAYS}
  AND dest_id = 1;
EXIT;
EOF
)

echo "Max applied sequence older than ${ARCHIVE_RETENTION_DAYS} days: $MAX_OLD_SEQ"
```

**Explicación detallada:**

Este query es diferente al del primary. Busca archives que cumplan TRES condiciones:

#### 1. applied = 'YES'
- Archive fue aplicado al standby database
- Contenido ya está integrado en los datafiles del standby
- **SEGURO de borrar:** Ya no se necesita para recuperación

#### 2. completion_time < SYSDATE - 3
- Archive completó hace más de 3 días
- Ejemplo: Hoy es 4-NOV, borra archives de 31-OCT o anteriores
- Mantiene archives de 1-NOV, 2-NOV, 3-NOV, 4-NOV

#### 3. dest_id = 1
- Solo archives locales del standby
- No archives de destinos remotos

**¿Qué secuencia se obtiene?**

Ejemplo:
```
Max applied sequence older than 3 days: 180
```

Esto significa:
- Hasta secuencia 180 fue aplicada hace más de 3 días
- Secuencias 1-180 son candidatas para borrado
- Secuencias 181+ son más recientes (se preservan)

**Diferencia clave con primary:**
- **Primary:** Borra hasta secuencia aplicada en standby (sin límite de fecha)
- **Standby:** Borra solo archives aplicados Y con más de 3 días

### Paso 3: Validar Resultado

```bash
if [ -n "$MAX_OLD_SEQ" ] && [ "$MAX_OLD_SEQ" != "" ]; then
  # Continuar con borrado
else
  echo "No archives older than ${ARCHIVE_RETENTION_DAYS} days to delete."
fi
```

**Explicación:**
- Si query no retorna nada, `$MAX_OLD_SEQ` está vacío
- Esto es normal y válido: significa no hay archives > 3 días
- No es error, simplemente no hay nada que borrar

**Escenarios:**
1. **Standby nuevo (< 3 días):** No hay archives antiguos, MAX_OLD_SEQ = null
2. **Standby operando normalmente:** MAX_OLD_SEQ tiene valor, se borra
3. **MRP detenido por 3+ días:** Muchos archives sin aplicar, MAX_OLD_SEQ puede ser null (no aplicados)

### Paso 4: Eliminación via RMAN

```bash
rman target / << REOF
RUN {
  DELETE NOPROMPT ARCHIVELOG UNTIL SEQUENCE ${MAX_OLD_SEQ} THREAD 1;
  CROSSCHECK ARCHIVELOG ALL;
}
EXIT;
REOF
```

**Explicación:**

#### DELETE NOPROMPT ARCHIVELOG UNTIL SEQUENCE
```sql
DELETE NOPROMPT ARCHIVELOG UNTIL SEQUENCE ${MAX_OLD_SEQ} THREAD 1;
```

Similar al primary, pero:
- Solo borra archives aplicados (verificado por el query previo)
- Solo borra archives > 3 días (también verificado por el query)
- No necesita consultar otro nodo (trabaja local)

#### CROSSCHECK ARCHIVELOG ALL
```sql
CROSSCHECK ARCHIVELOG ALL;
```

- Sincroniza catálogo RMAN con filesystem
- Marca como EXPIRED archives que faltan
- Actualiza status de archives existentes

**¿Por qué no hay ALLOCATE CHANNEL?**

En el standby, el bloque RUN solo tiene DELETE y CROSSCHECK:
- DELETE no requiere canal explícito (usa canal default)
- Para operaciones simples, RMAN asigna canal automáticamente
- ALLOCATE solo es necesario para backups o paralelismo

### Paso 5: Registro y Limpieza

```bash
echo "===================================================================="
echo "Archive Deletion Complete: $(date)"
echo "===================================================================="
```

```bash
find /home/oracle/logs/automation -name "delete_archives_standby.log" -mtime +30 -delete 2>/dev/null
```

## Comandos Importantes

### Consultas de Archives en Standby

```sql
-- Ver archives aplicados y no aplicados
SELECT applied, COUNT(*) AS count,
       ROUND(SUM(blocks * block_size)/1024/1024/1024, 2) AS gb
FROM v$archived_log
WHERE deleted = 'NO'
  AND dest_id = 1
GROUP BY applied;

-- Ver archives aplicados por día
SELECT TO_CHAR(completion_time, 'YYYY-MM-DD') AS day,
       COUNT(*) AS archives_applied,
       ROUND(SUM(blocks * block_size)/1024/1024/1024, 2) AS gb
FROM v$archived_log
WHERE applied = 'YES'
  AND deleted = 'NO'
  AND dest_id = 1
GROUP BY TO_CHAR(completion_time, 'YYYY-MM-DD')
ORDER BY day DESC;

-- Ver archives pendientes de aplicar
SELECT sequence#, name,
       TO_CHAR(completion_time, 'YYYY-MM-DD HH24:MI:SS') AS received
FROM v$archived_log
WHERE applied = 'NO'
  AND deleted = 'NO'
  AND dest_id = 1
ORDER BY sequence#;

-- Ver archives que se borrarían
SELECT sequence#, name,
       TO_CHAR(completion_time, 'YYYY-MM-DD HH24:MI:SS') AS completed,
       ROUND((SYSDATE - completion_time), 2) AS days_old
FROM v$archived_log
WHERE applied = 'YES'
  AND completion_time < SYSDATE - 3
  AND deleted = 'NO'
  AND dest_id = 1
ORDER BY sequence#;
```

### Verificar Estado MRP

```sql
-- Ver si MRP (Managed Recovery Process) está corriendo
SELECT process, status, thread#, sequence#, block#, blocks
FROM v$managed_standby
WHERE process LIKE 'MRP%';

-- Ver procesos RFS (Remote File Server - recibe archives)
SELECT process, status, thread#, sequence#
FROM v$managed_standby
WHERE process LIKE 'RFS%';

-- Ver progreso de recuperación
SELECT PROCESS, STATUS, THREAD#, SEQUENCE#,
       ROUND(SOFAR/1024/1024, 2) AS mb_applied,
       TO_CHAR(TIMESTAMP, 'YYYY-MM-DD HH24:MI:SS') AS last_update
FROM v$managed_standby
WHERE PROCESS LIKE 'MRP%';
```

### Controlar MRP

```sql
-- Iniciar MRP (aplicar archives automáticamente)
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;

-- Detener MRP
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE CANCEL;

-- Aplicar archives manualmente hasta secuencia específica
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE UNTIL SEQUENCE 250 THREAD 1;

-- Reiniciar MRP con parámetros
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE
  USING CURRENT LOGFILE DISCONNECT FROM SESSION;
```

## Salida Esperada

### Ejecución Normal (Con Archives para Borrar)

```
====================================================================
Archive Deletion STANDBY: Tue Nov  4 23:00:01 UTC 2025
====================================================================
Max applied sequence older than 3 days: 180

Recovery Manager: Release 21.0.0.0.0 - Production on Tue Nov 4 23:00:01 2025
Version 21.3.0.0.0

connected to target database: CDB1 (DBID=1234567890, not open)

RMAN> RUN {
2>   DELETE NOPROMPT ARCHIVELOG UNTIL SEQUENCE 180 THREAD 1;
3>   CROSSCHECK ARCHIVELOG ALL;
4> }

List of Archived Log Copies for database with db_unique_name CDB1_STBY
=======================================================================

Key     Thrd Seq     S Low Time            Name
------- ---- ------- - ------------------ ----
320     1    165     A 31-OCT-25          /u01/app/oracle/fast_recovery_area/CDB1_STBY/archivelog/2025_10_31/o1_mf_1_165_xyz.arc
321     1    166     A 31-OCT-25          /u01/app/oracle/fast_recovery_area/CDB1_STBY/archivelog/2025_10_31/o1_mf_1_166_xyz.arc
...
335     1    180     A 01-NOV-25          /u01/app/oracle/fast_recovery_area/CDB1_STBY/archivelog/2025_11_01/o1_mf_1_180_xyz.arc

deleted archived log
archived log file name=/u01/app/oracle/fast_recovery_area/CDB1_STBY/archivelog/2025_10_31/o1_mf_1_165_xyz.arc RECID=320 STAMP=1234560000
...
deleted archived log
archived log file name=/u01/app/oracle/fast_recovery_area/CDB1_STBY/archivelog/2025_11_01/o1_mf_1_180_xyz.arc RECID=335 STAMP=1234560150

Deleted 16 objects

crosschecked backup piece: found to be 'AVAILABLE'
...
Crosschecked 25 objects

RMAN>
Recovery Manager complete.

====================================================================
Archive Deletion Complete: Tue Nov  4 23:00:18 UTC 2025
====================================================================
```

### Ejecución Sin Archives para Borrar

```
====================================================================
Archive Deletion STANDBY: Tue Nov  4 23:00:01 UTC 2025
====================================================================
Max applied sequence older than 3 days:
No archives older than 3 days to delete.
====================================================================
Archive Deletion Complete: Tue Nov  4 23:00:05 UTC 2025
====================================================================
```

**Interpretación:**
- Query no retornó valor (standby nuevo o ya se limpiaron archives)
- No se ejecutó DELETE (comportamiento normal)
- No es error, simplemente no hay trabajo que hacer

## Logs Generados

- **Ubicación:** `/home/oracle/logs/automation/delete_archives_standby.log`
- **Tipo:** Sobrescritura (cada ejecución reemplaza el anterior)
- **Contenido:**
  - Timestamp de ejecución
  - Máxima secuencia aplicada > 3 días
  - Output de RMAN (archives eliminados)
  - Resultado de CROSSCHECK
- **Retención:** Solo último log

### Ver Log

```bash
# En standby
cat /home/oracle/logs/automation/delete_archives_standby.log

# Desde primary (via SSH)
ssh oracle@ol8-21-dg2 "cat /home/oracle/logs/automation/delete_archives_standby.log"
```

## Diferencias Entre Primary y Standby

| Aspecto | Primary (72-delete-archives-primary.md) | Standby (Este Script) |
|---------|----------------------------------------|----------------------|
| **Criterio principal** | Archives aplicados en standby | Archives aplicados localmente Y > 3 días |
| **Consulta remota** | Sí (consulta standby) | No (solo local) |
| **Horario** | 2:00 AM | 11:00 PM |
| **Dependencias** | Backup diario (1 AM) | Ninguna |
| **Política RMAN** | APPLIED ON ALL STANDBY | Ninguna especial |
| **Fallo si standby caído** | No borra nada (safe) | N/A (trabaja local) |
| **Propósito** | Liberar FRA tras confirmar replicación | Liberar FRA tras aplicar changes |

### ¿Por Qué Diferentes Criterios?

**Primary:**
- Debe asegurar que standby no necesita los archives
- Consulta remota para confirmar
- Protege la replicación Data Guard

**Standby:**
- Solo necesita confirmar que aplicó los archives localmente
- Una vez aplicados, están en datafiles (no se necesita el archive)
- No hay otro nodo que dependa de estos archives

## Ejecución Manual

### Ejecutar Limpieza Manual

```bash
# En standby, como usuario oracle
/home/oracle/automation/delete_archives_standby.sh

# Ver log
cat /home/oracle/logs/automation/delete_archives_standby.log
```

**Casos de uso:**
- FRA del standby se está llenando
- Testing del script
- Limpieza fuera de horario programado

### Forzar Limpieza Agresiva

Si FRA está crítico y necesita borrar MÁS archives:

```bash
rman target /

# Borrar archives aplicados sin límite de fecha
# (PRECAUCIÓN: reduce capacidad de flashback)
DELETE NOPROMPT ARCHIVELOG UNTIL TIME 'SYSDATE-1';

# O borrar todos los aplicados
# (MAYOR PRECAUCIÓN: solo si tiene backups recientes)
RUN {
  DELETE NOPROMPT ARCHIVELOG ALL COMPLETED BEFORE 'SYSDATE-1';
}
```

## Verificación

### Verificar Cron Instalado

```bash
# En standby
crontab -l | grep delete_archives_standby

# Salida esperada:
# 0 23 * * * /home/oracle/automation/delete_archives_standby.sh
```

### Verificar Última Ejecución

```bash
# Ver timestamp del log
ls -l /home/oracle/logs/automation/delete_archives_standby.log

# Ver contenido
cat /home/oracle/logs/automation/delete_archives_standby.log
```

### Verificar Espacio FRA

```bash
# Uso de FRA
df -h /u01

# Dentro de SQL
sqlplus / as sysdba <<EOF
SELECT * FROM v\$recovery_file_dest;
SELECT * FROM v\$recovery_area_usage;
EXIT;
EOF
```

### Verificar MRP Aplicando Archives

```sql
-- En standby
SELECT process, status, sequence#
FROM v$managed_standby
WHERE process LIKE 'MRP%';

-- Salida esperada:
-- PROCESS   STATUS      SEQUENCE#
-- --------- ----------- ---------
-- MRP0      APPLYING    261

-- Si STATUS = APPLYING, MRP está trabajando correctamente
```

## Puntos de Fallo Comunes

### 1. MRP No Está Aplicando Archives

**Síntoma:** Archives se acumulan, ninguno marca como applied='YES'

**Diagnóstico:**
```sql
SELECT process, status FROM v$managed_standby WHERE process LIKE 'MRP%';

-- Si no hay filas o STATUS != APPLYING
```

**Solución:**
```sql
-- Iniciar MRP
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;

-- Verificar que inició
SELECT process, status FROM v$managed_standby WHERE process LIKE 'MRP%';
```

### 2. FRA Se Llena en Standby

**Síntoma:**
```
ORA-19809: limit exceeded for recovery files
ORA-19804: cannot reclaim 52428800 bytes disk space
```

**Causa:** Archives no se están borrando suficientemente rápido

**Solución inmediata:**
```bash
# Borrar archives aplicados manualmente
rman target / << EOF
DELETE NOPROMPT ARCHIVELOG UNTIL TIME 'SYSDATE-7';
EXIT;
EOF

# O aumentar FRA
sqlplus / as sysdba << EOF
ALTER SYSTEM SET db_recovery_file_dest_size=150G SCOPE=BOTH;
EXIT;
EOF
```

### 3. Archives No Se Borran (Deleted Objects = 0)

**Causa Posible 1:** No hay archives > 3 días (normal en standby nuevo)

**Verificar:**
```sql
SELECT MIN(completion_time) AS oldest_archive
FROM v$archived_log
WHERE deleted = 'NO' AND dest_id = 1;

-- Si oldest_archive es reciente (< 3 días), es normal
```

**Causa Posible 2:** Archives no están marcados como aplicados

**Verificar:**
```sql
SELECT applied, COUNT(*) FROM v$archived_log
WHERE deleted = 'NO' AND dest_id = 1
GROUP BY applied;

-- Si muchos archives con applied='NO', MRP está atrasado
```

**Solución:**
```sql
-- Esperar a que MRP aplique archives
-- Verificar progreso cada 5 minutos
SELECT MAX(sequence#) AS last_applied
FROM v$archived_log
WHERE applied = 'YES' AND dest_id = 1;
```

### 4. Script Falla con ORA-00257

**Error completo:**
```
ORA-00257: archiver error. Connect internal only, until freed.
```

**Causa:** FRA está 100% llena, no se pueden crear nuevos archives

**Solución de emergencia:**
```bash
# Como root, dar más espacio temporal
df -h /u01

# Si /u01 tiene espacio, aumentar FRA
sqlplus / as sysdba << EOF
ALTER SYSTEM SET db_recovery_file_dest_size=120G SCOPE=BOTH;
EXIT;
EOF

# Forzar borrado inmediato
rman target / << EOF
DELETE NOPROMPT ARCHIVELOG ALL COMPLETED BEFORE 'SYSDATE-2';
CROSSCHECK ARCHIVELOG ALL;
EXIT;
EOF
```

### 5. Standby No Recibe Archives de Primary

**Síntoma:** No hay archives nuevos en v$archived_log del standby

**Diagnóstico:**
```sql
-- En standby
SELECT MAX(sequence#), MAX(completion_time)
FROM v$archived_log
WHERE dest_id = 1;

-- Si completion_time es antigua (> 1 hora), hay problema
```

**Verificar:**
```bash
# Listener en standby
lsnrctl status

# Conectividad desde primary
ping ol8-21-dg2.localdomain
tnsping cdb1_stby.world

# En primary, verificar destino log_archive_dest_2
sqlplus / as sysdba << EOF
SHOW PARAMETER log_archive_dest_2;
SELECT dest_name, status, error FROM v\$archive_dest WHERE dest_id=2;
EXIT;
EOF
```

## Importancia para el Sistema

Este script es **IMPORTANTE** para la operación del standby:

### 1. Previene Llenado de FRA en Standby

Standby recibe todos los archives del primary:
- Mismo volumen de archives que primary
- Sin limpieza, FRA se llenaría en ~7 días
- FRA llena impide recibir más archives (standby desincronizado)

### 2. Mantiene Capacidad de Recuperación

Retención de 3 días en standby:
- Suficiente para flashback database
- Permite investigar incidentes recientes
- Balance entre protección y espacio

### 3. Complementa Limpieza en Primary

Arquitectura de limpieza distribuida:
- **Primary:** Borra después de aplicar en standby
- **Standby:** Borra después de aplicar localmente
- Ambos nodos mantienen FRA saludable

### 4. Operación Autónoma del Standby

Sin este script:
- DBA tendría que limpiar standby manualmente
- Standby es nodo secundario, a menudo "olvidado"
- Riesgo mayor de problemas no detectados

### 5. Preparación para Switchover/Failover

Standby con FRA limpia:
- Listo para convertirse en primary en cualquier momento
- No tendrá problemas de espacio tras switchover
- Operación de alta disponibilidad sin obstáculos

## Referencias Cruzadas

### Documentos Relacionados

- **[72-delete-archives-primary.md](72-delete-archives-primary.md)** - Limpieza en primary
- **[60-install-cron.md](../ejecucion/standby/60-install-cron.md)** - Instalación de cron job
- **[57-rman-duplicate.md](../ejecucion/standby/57-rman-duplicate.md)** - Creación del standby
- **[83-archive-logs.md](../conceptos-avanzados/83-archive-logs.md)** - Conceptos de archive logs
- **[92-switchover.md](../operaciones/92-switchover.md)** - Procedimiento switchover

### Scripts Relacionados

```bash
/home/oracle/automation/delete_archives_standby.sh    # Este script
/home/oracle/automation/delete_archives_primary.sh    # Equivalente en primary
```

### Parámetros Oracle en Standby

```sql
-- Fast Recovery Area (standby)
SHOW PARAMETER db_recovery_file_dest;
SHOW PARAMETER db_recovery_file_dest_size;

-- Standby-specific
SHOW PARAMETER standby_file_management;  -- AUTO
SHOW PARAMETER fal_server;               -- Primary server
SHOW PARAMETER fal_client;               -- This standby
```

### Vistas Importantes en Standby

```sql
-- Estado del standby database
SELECT name, db_unique_name, database_role, open_mode
FROM v$database;

-- Procesos de recuperación activos
SELECT * FROM v$managed_standby;

-- Archive logs disponibles
SELECT * FROM v$archived_log WHERE deleted = 'NO';

-- Uso de FRA
SELECT * FROM v$recovery_file_dest;
SELECT * FROM v$recovery_area_usage;
```

---

**Última Actualización:** 2025-11-04
**Autor:** Claude (Subagente 4)
**Versión:** 1.0
