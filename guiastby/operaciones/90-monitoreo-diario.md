# 90 - Monitoreo Diario de Oracle Data Guard

## Procedimientos de Monitoreo y Mantenimiento Diario

Este documento describe los procedimientos de monitoreo diario que debe realizar un DBA para asegurar el correcto funcionamiento del sistema Oracle Data Guard.

---

## Tabla de Contenidos

1. [Introducción](#introducción)
2. [Monitoreo Automatizado](#monitoreo-automatizado)
3. [Checks Manuales Diarios](#checks-manuales-diarios)
4. [Métricas Clave](#métricas-clave)
5. [Umbrales de Alerta](#umbrales-de-alerta)
6. [Queries de Diagnóstico](#queries-de-diagnóstico)
7. [Monitoreo de Recursos](#monitoreo-de-recursos)
8. [Reportes Diarios](#reportes-diarios)
9. [Checklist Diario](#checklist-diario)

---

## Introducción

El monitoreo diario de Oracle Data Guard es esencial para:

- **Detectar problemas antes de que sean críticos**
- **Asegurar que la replicación está funcionando correctamente**
- **Verificar que los backups se ejecutan exitosamente**
- **Mantener el espacio en disco bajo control**
- **Garantizar alta disponibilidad 24/7**

**Tiempo estimado:** 15-20 minutos por día para checks manuales.

---

## Monitoreo Automatizado

El sistema incluye scripts automatizados que corren vía cron. Estos scripts son la primera línea de defensa.

### Script: check_log_transport.sh (Primary)

**Ubicación:** `/home/oracle/automation/check_log_transport.sh`

**Frecuencia:** Cada 10 minutos

**Qué hace:**
- Verifica la última secuencia archivada en primary
- Verifica la última secuencia aplicada en standby
- Calcula el gap (diferencia entre ambas)
- Verifica el apply lag desde v$dataguard_stats
- Alerta si el gap excede el umbral configurado

**Ver última ejecución:**

```bash
vagrant ssh primary -c "tail -20 /home/oracle/logs/automation/log_transport.log"
```

**Salida normal:**

```
====================================================================
Log Transport Check: Mon Nov  4 15:30:00 UTC 2025
====================================================================
Primary last archived: 145
Standby last applied: 145
Current gap: 0 sequences
Apply lag: +00 00:00:02
====================================================================
```

**Salida con problema:**

```
====================================================================
Log Transport Check: Mon Nov  4 15:40:00 UTC 2025
====================================================================
Primary last archived: 152
Standby last applied: 145
Current gap: 7 sequences
Apply lag: +00 00:05:32
WARNING: Gap exceeds 5 sequences!
====================================================================
```

**Acción si hay WARNING:**
1. Investigar inmediatamente usando queries de diagnóstico (ver sección más adelante)
2. Verificar que MRP0 está corriendo en standby
3. Verificar conectividad de red entre primary y standby
4. Revisar alert logs en ambos nodos

---

### Script: rman_daily_backup.sh (Primary)

**Ubicación:** `/home/oracle/automation/rman_daily_backup.sh`

**Frecuencia:** Diario a la 1:00 AM

**Qué hace:**
- Ejecuta backup RMAN completo de la base de datos
- Incluye archivelog backup
- Incluye controlfile y SPFILE
- Elimina backups obsoletos (>7 días por defecto)
- Transfiere backup al servidor standby vía rsync

**Ver último backup:**

```bash
vagrant ssh primary -c "ls -lt /home/oracle/logs/automation/rman_backup_*.log | head -1 | xargs tail -50"
```

**Verificar que backup se ejecutó exitosamente:**

```bash
vagrant ssh primary

sudo su - oracle

# Ver último backup en RMAN
rman target / <<EOF
LIST BACKUP SUMMARY;
EXIT;
EOF
```

**Salida esperada:**

```
List of Backups
===============
Key     TY LV S Device Type Completion Time #Pieces #Copies Compressed Tag
------- -- -- - ----------- --------------- ------- ------- ---------- ---
145     B  F  A DISK        04-NOV-25       2       1       YES        DAILY_BACKUP_20251104
146     B  A  A DISK        04-NOV-25       1       1       YES        DAILY_BACKUP_20251104
147     B  F  A DISK        04-NOV-25       1       1       NO         DAILY_BACKUP_20251104
```

**Verificar transferencia a standby:**

```bash
vagrant ssh standby -c "ls -lh /u02/backup_from_primary/"
```

Debe haber archivos recientes con tag DAILY_BACKUP_YYYYMMDD.

---

### Script: delete_archives_primary.sh (Primary)

**Ubicación:** `/home/oracle/automation/delete_archives_primary.sh`

**Frecuencia:** Diario a las 2:00 AM (después de backup)

**Qué hace:**
- Elimina archive logs que ya fueron aplicados en standby
- Usa RMAN para eliminar de forma segura
- Respeta política: APPLIED ON ALL STANDBY
- Mantiene archives de últimos 3 días como mínimo

**Ver última ejecución:**

```bash
vagrant ssh primary -c "tail -50 /home/oracle/logs/automation/delete_archives_primary.log"
```

---

### Script: delete_archives_standby.sh (Standby)

**Ubicación:** `/home/oracle/automation/delete_archives_standby.sh`

**Frecuencia:** Diario a las 11:00 PM

**Qué hace:**
- Elimina archive logs que ya fueron aplicados
- Mantiene archives de últimos 3 días como mínimo
- Libera espacio en /u01/oradata/cdb1/arch

**Ver última ejecución:**

```bash
vagrant ssh standby -c "tail -50 /home/oracle/logs/automation/delete_archives_standby.log"
```

---

### Verificar Estado de Cron Jobs

**En Primary:**

```bash
vagrant ssh primary -c "sudo su - oracle -c 'crontab -l'"
```

**Salida esperada:**

```
# Data Guard monitoring (every 10 minutes)
*/10 * * * * /home/oracle/automation/check_log_transport.sh >> /home/oracle/logs/automation/check_log_transport.log 2>&1

# Daily backup at 1 AM
0 1 * * * /home/oracle/automation/rman_daily_backup.sh

# Archive cleanup at 2 AM (after backup)
0 2 * * * /home/oracle/automation/delete_archives_primary.sh
```

**En Standby:**

```bash
vagrant ssh standby -c "sudo su - oracle -c 'crontab -l'"
```

**Salida esperada:**

```
# Archive cleanup at 11 PM
0 23 * * * /home/oracle/automation/delete_archives_standby.sh
```

---

## Checks Manuales Diarios

Además del monitoreo automatizado, el DBA debe realizar checks manuales diarios.

### 1. Verificación Completa de Data Guard

**Comando:**

```bash
vagrant ssh primary -c "/home/oracle/automation/verify_dataguard.sh"
```

**Tiempo:** 10-15 segundos

**Qué verifica:**
- Roles de base de datos (PRIMARY/PHYSICAL STANDBY)
- Modos de apertura (READ WRITE/MOUNTED/READ ONLY WITH APPLY)
- Protection mode (MAXIMUM AVAILABILITY)
- Estado de archive destinations
- Standby redo logs
- Log switch history
- Apply status en standby
- Transport lag y apply lag
- Archive gaps
- Data Guard Broker configuration
- Schema customizado (HEALTHCENTER)

**Puntos a verificar en la salida:**

1. **Primary Database Status:**
   - Database Role: PRIMARY ✓
   - Open Mode: READ WRITE ✓
   - Protection Mode: MAXIMUM AVAILABILITY ✓
   - Flashback: ON ✓
   - Force Logging: YES ✓

2. **Archive Destinations:**
   - Destination 1 (Local): VALID ✓
   - Destination 2 (Standby): VALID ✓
   - Status: VALID (no INACTIVE, no ERROR) ✓

3. **Standby Database Status:**
   - Database Role: PHYSICAL STANDBY ✓
   - Open Mode: READ ONLY WITH APPLY o MOUNTED ✓
   - MRP Status: APPLYING_LOG ✓

4. **Apply Lag:**
   - Apply Lag: 0 seconds (ideal) ✓
   - Apply Lag: <5 seconds (aceptable) ⚠️
   - Apply Lag: >30 seconds (investigar) 🔴

5. **Archive Gaps:**
   - No rows returned (ideal) ✓
   - Si hay rows, hay un gap 🔴 → Ver sección troubleshooting

6. **Broker Status:**
   - Configuration Status: SUCCESS ✓
   - Database cdb1: SUCCESS ✓
   - Database cdb1_stby: SUCCESS ✓

**Si algo muestra ERROR o WARNING:** Ver sección [Troubleshooting](94-troubleshooting.md).

---

### 2. Verificación de Conectividad

**Verificar conectividad a primary desde Windows:**

```bash
sqlplus sys/S1sPassword1!@localhost:1521/cdb1 as sysdba <<EOF
SELECT name, database_role, open_mode FROM v\$database;
EXIT;
EOF
```

**Salida esperada:**

```
NAME      DATABASE_ROLE    OPEN_MODE
--------- ---------------- --------------------
CDB1      PRIMARY          READ WRITE
```

**Verificar conectividad a standby desde Windows:**

```bash
sqlplus sys/S1sPassword1!@localhost:1522/cdb1_stby as sysdba <<EOF
SELECT name, database_role, open_mode FROM v\$database;
EXIT;
EOF
```

**Salida esperada:**

```
NAME      DATABASE_ROLE       OPEN_MODE
--------- ------------------- --------------------
CDB1      PHYSICAL STANDBY    MOUNTED
```

**Si falla la conexión:** Verificar que listeners están corriendo (ver sección troubleshooting).

---

### 3. Verificación de Listeners

**Primary:**

```bash
vagrant ssh primary -c "sudo su - oracle -c 'lsnrctl status'"
```

**Verificar en la salida:**

```
Services Summary...
Service "cdb1" has 1 instance(s).
  Instance "cdb1", status READY, has 1 handler(s) for this service...
Service "cdb1.world" has 1 instance(s).
  Instance "cdb1", status READY, has 1 handler(s) for this service...
Service "pdb1" has 1 instance(s).
  Instance "cdb1", status READY, has 1 handler(s) for this service...
```

**Standby:**

```bash
vagrant ssh standby -c "sudo su - oracle -c 'lsnrctl status'"
```

**Verificar en la salida:**

```
Services Summary...
Service "cdb1_stby" has 1 instance(s).
  Instance "cdb1", status READY, has 1 handler(s) for this service...
Service "cdb1_stby.world" has 1 instance(s).
  Instance "cdb1", status READY, has 1 handler(s) for this service...
```

**Si listener no está corriendo:**

```bash
vagrant ssh primary
sudo su - oracle
lsnrctl start
```

---

### 4. Verificación de Espacio en Disco

**Critical check:** Quedarse sin espacio en disco puede causar fallas catastróficas.

**Primary:**

```bash
vagrant ssh primary -c "df -h"
```

**Verificar:**

- `/u01` (Oracle software + datafiles): <80% uso ✓
- `/u02` (backups): <85% uso ✓
- `/` (root): <85% uso ✓

**Salida esperada:**

```
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1        39G   12G   27G  31% /
/dev/sdb1        99G   45G   49G  48% /u01
/dev/sdc1        99G   25G   70G  27% /u02
```

**Si `/u01` está >80%:**

Probablemente hay acumulación de archive logs.

```bash
vagrant ssh primary

sudo su - oracle
cd /u01/oradata/cdb1/arch
ls -lh | wc -l  # Contar archivos
du -sh .         # Ver tamaño total
```

**Solución:** Ejecutar delete_archives_primary.sh manualmente (ver [91-respaldos-manuales.md](91-respaldos-manuales.md)).

**Si `/u02` está >85%:**

Backups acumulados.

```bash
vagrant ssh primary

sudo su - oracle
rman target / <<EOF
DELETE NOPROMPT OBSOLETE;
LIST BACKUP SUMMARY;
EXIT;
EOF
```

---

**Standby:**

```bash
vagrant ssh standby -c "df -h"
```

Mismas verificaciones que primary.

---

### 5. Revisión de Alert Logs

**Primary alert log (últimas 50 líneas):**

```bash
vagrant ssh primary -c "tail -50 /u01/app/oracle/diag/rdbms/cdb1/cdb1/trace/alert_cdb1.log"
```

**Qué buscar:**

✓ **Mensajes normales:**
- `Thread 1 advanced to log sequence X`
- `LNS: Standby redo logfile selected...`
- `Media Recovery Log /u01/oradata/cdb1/arch/...`

🔴 **Mensajes de error:**
- `ORA-XXXXX` (cualquier error)
- `Error writing to archive destination`
- `FAL[server, ARC]: Error`
- `Errors in file ...`

**Standby alert log:**

```bash
vagrant ssh standby -c "tail -50 /u01/app/oracle/diag/rdbms/cdb1_stby/cdb1/trace/alert_cdb1.log"
```

**Qué buscar:**

✓ **Mensajes normales:**
- `Media Recovery Log /u01/oradata/cdb1/arch/...`
- `Recovery of Online Redo Log: Thread 1 Group X Seq X`
- `Media Recovery Complete`

🔴 **Mensajes de error:**
- `ORA-XXXXX`
- `MRP0: Background Media Recovery terminated with error`
- `Errors in file ...`

**Si encuentras errores:** Documenta el error completo y consulta [94-troubleshooting.md](94-troubleshooting.md).

---

### 6. Verificación de Procesos Oracle

**Primary:**

```bash
vagrant ssh primary -c "ps aux | grep -E '(pmon|smon|lgwr|arch|lns)' | grep -v grep"
```

**Procesos esperados:**

- `ora_pmon_cdb1` - Process Monitor
- `ora_smon_cdb1` - System Monitor
- `ora_lgwr_cdb1` - Log Writer
- `ora_arch_cdb1` - Archiver (puede haber múltiples)
- `ora_lns_cdb1` - Log Network Server (Data Guard redo transport)

**Standby:**

```bash
vagrant ssh standby -c "ps aux | grep -E '(pmon|smon|rfs|mrp)' | grep -v grep"
```

**Procesos esperados:**

- `ora_pmon_cdb1`
- `ora_smon_cdb1`
- `ora_rfs_cdb1` - Remote File Server (recibe redo de primary)
- `ora_mrp0_cdb1` - Managed Recovery Process (aplica redo)

**Si falta MRP0 en standby:**

El standby no está aplicando logs. Iniciarlo:

```bash
vagrant ssh standby

sudo su - oracle
sqlplus / as sysdba <<EOF
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;
EXIT;
EOF
```

---

## Métricas Clave

Estas son las métricas más importantes a monitorear diariamente.

### 1. Apply Lag

**Qué es:** Tiempo de retraso entre cuando un cambio se hace en primary y cuando se aplica en standby.

**Objetivo:** 0 segundos (ideal), <5 segundos (aceptable)

**Query:**

```sql
-- En standby
SELECT name, value, unit, time_computed
FROM v$dataguard_stats
WHERE name = 'apply lag';
```

**Salida normal:**

```
NAME        VALUE          UNIT         TIME_COMPUTED
----------- -------------- ------------ ---------------------
apply lag   +00 00:00:02   seconds      2025-11-04 15:30:15
```

**Interpretación:**
- `+00 00:00:00` = 0 segundos → Perfecto ✓
- `+00 00:00:05` = 5 segundos → Aceptable ✓
- `+00 00:05:00` = 5 minutos → Problema 🔴

---

### 2. Transport Lag

**Qué es:** Tiempo de retraso en el transporte de redo logs del primary al standby.

**Objetivo:** 0-1 segundos

**Query:**

```sql
-- En standby
SELECT name, value, unit, time_computed
FROM v$dataguard_stats
WHERE name = 'transport lag';
```

**Salida normal:**

```
NAME           VALUE          UNIT         TIME_COMPUTED
-------------- -------------- ------------ ---------------------
transport lag  +00 00:00:01   seconds      2025-11-04 15:30:15
```

---

### 3. Archive Gap

**Qué es:** Secuencias de archive log que faltan en el standby.

**Objetivo:** 0 gaps

**Query:**

```sql
-- En standby
SELECT * FROM v$archive_gap;
```

**Salida ideal:**

```
no rows selected
```

**Si hay rows:**

```
THREAD# LOW_SEQUENCE# HIGH_SEQUENCE#
------- ------------- --------------
      1           145            147
```

Esto significa que las secuencias 145, 146, 147 faltan en standby. **Acción inmediata requerida.**

**Solución:** Ver [94-troubleshooting.md](94-troubleshooting.md) sección "Archive Gap Recovery".

---

### 4. Sequence# Gap

**Qué es:** Diferencia numérica entre última secuencia archivada en primary y última aplicada en standby.

**Objetivo:** 0-2 sequences (normal), 3-5 (aceptable bajo carga), >10 (problema)

**Query manual:**

```sql
-- En primary
SELECT MAX(sequence#) AS primary_seq
FROM v$archived_log
WHERE dest_id = 1 AND archived = 'YES';

-- En standby
SELECT MAX(sequence#) AS standby_seq
FROM v$archived_log
WHERE dest_id = 1 AND applied = 'YES';
```

Calcular gap = primary_seq - standby_seq.

---

### 5. Redo Generation Rate

**Qué es:** Velocidad a la que primary está generando redo logs.

**Útil para:** Predecir cuándo se necesitará más espacio en disco.

**Query:**

```sql
-- En primary
SELECT sequence#, first_time, next_time,
       ROUND((next_time - first_time) * 24 * 60, 2) AS minutes_to_fill,
       blocks * block_size / 1024 / 1024 AS size_mb
FROM v$log_history
WHERE first_time > SYSDATE - 1
ORDER BY sequence# DESC
FETCH FIRST 10 ROWS ONLY;
```

**Salida:**

```
SEQUENCE# FIRST_TIME          NEXT_TIME           MINUTES_TO_FILL SIZE_MB
--------- ------------------- ------------------- --------------- -------
      145 04-NOV-25 14:50:00  04-NOV-25 15:00:00            10.00      50
      144 04-NOV-25 14:40:00  04-NOV-25 14:50:00            10.00      50
      143 04-NOV-25 14:30:00  04-NOV-25 14:40:00            10.00      50
```

**Interpretación:**
- Redo log lleno cada 10 minutos = actividad normal
- Redo log lleno cada 1-2 minutos = actividad muy alta (esperar más apply lag)

---

### 6. Standby Redo Log Status

**Qué es:** Estado de los standby redo logs (usados para recibir redo de primary).

**Objetivo:** Al menos un grupo en estado ACTIVE (standby recibiendo redo)

**Query:**

```sql
-- En standby
SELECT group#, thread#, sequence#, bytes/1024/1024 AS size_mb,
       archived, status
FROM v$standby_log
ORDER BY group#;
```

**Salida esperada:**

```
GROUP# THREAD# SEQUENCE# SIZE_MB ARCHIVED STATUS
------ ------- --------- ------- -------- ----------
     4       0         0      50 YES      UNASSIGNED
     5       0         0      50 YES      UNASSIGNED
     6       1       145      50 NO       ACTIVE
     7       0         0      50 YES      UNASSIGNED
```

Un grupo debe estar en ACTIVE (recibiendo redo actualmente).

---

## Umbrales de Alerta

Definir umbrales claros ayuda a tomar decisiones rápidas.

| Métrica | Verde (OK) | Amarillo (Warning) | Rojo (Critical) |
|---------|------------|-------------------|-----------------|
| **Apply Lag** | 0-5 seg | 5-30 seg | >30 seg |
| **Transport Lag** | 0-2 seg | 2-10 seg | >10 seg |
| **Sequence Gap** | 0-2 seq | 3-5 seq | >5 seq |
| **Archive Gap** | 0 gaps | - | >0 gaps |
| **Disk /u01** | <70% | 70-85% | >85% |
| **Disk /u02** | <75% | 75-90% | >90% |
| **Backup Age** | <24 hrs | 24-36 hrs | >36 hrs |
| **Listener Status** | Running | - | Down |
| **MRP0 Status** | APPLYING_LOG | - | Not running |

**Acciones por nivel:**

- **Verde:** Monitoreo normal
- **Amarillo:** Investigar causa, monitorear más frecuentemente
- **Rojo:** Acción inmediata, escalar si es necesario

---

## Queries de Diagnóstico

Estas queries son útiles para diagnosticar problemas.

### Query 1: Estado General de Data Guard

```sql
-- En primary
SELECT database_role, open_mode, protection_mode, protection_level,
       switchover_status, force_logging, flashback_on
FROM v$database;
```

---

### Query 2: Estado de Archive Destinations

```sql
-- En primary
SET LINESIZE 200
COL dest_name FORMAT A15
COL status FORMAT A10
COL destination FORMAT A40
COL error FORMAT A50

SELECT dest_name, status, destination, error
FROM v$archive_dest
WHERE status != 'INACTIVE'
ORDER BY dest_id;
```

**Verificar:**
- DEST_1 (LOCAL): STATUS = VALID
- DEST_2 (STANDBY): STATUS = VALID
- ERROR: debe estar vacío

---

### Query 3: Estado de MRP (Managed Recovery Process)

```sql
-- En standby
SELECT process, status, thread#, sequence#, block#, blocks
FROM v$managed_standby
WHERE process LIKE 'MRP%' OR process LIKE 'RFS%';
```

**Salida esperada:**

```
PROCESS STATUS     THREAD# SEQUENCE#  BLOCK#     BLOCKS
------- ---------- ------- --------- -------- ----------
RFS     IDLE             0         0        0          0
RFS     IDLE             0         0        0          0
MRP0    APPLYING_LOG     1       145     1024      51200
```

MRP0 debe estar en APPLYING_LOG.

---

### Query 4: Historial de Log Switches (Primary)

```sql
SELECT TO_CHAR(first_time, 'YYYY-MM-DD HH24') AS hour,
       COUNT(*) AS log_switches
FROM v$log_history
WHERE first_time > SYSDATE - 1
GROUP BY TO_CHAR(first_time, 'YYYY-MM-DD HH24')
ORDER BY hour DESC;
```

**Útil para:** Identificar horas pico de actividad.

---

### Query 5: Archive Logs Pendientes de Aplicar (Standby)

```sql
SELECT sequence#, applied, completion_time
FROM v$archived_log
WHERE applied = 'NO' AND sequence# > 0
ORDER BY sequence#;
```

Idealmente no debe haber rows (todo aplicado).

---

### Query 6: Sesiones Activas

```sql
SELECT sid, serial#, username, program, status, sql_id
FROM v$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
ORDER BY logon_time DESC;
```

---

## Monitoreo de Recursos

### CPU Usage

```bash
vagrant ssh primary -c "top -bn1 | head -20"
```

**Verificar:**
- `%Cpu(s)`: <80% normal, >90% alta carga
- Procesos Oracle (pmon, lgwr, arch) no deben estar al 100% constantemente

---

### Memory Usage

```bash
vagrant ssh primary -c "free -h"
```

**Salida esperada:**

```
              total        used        free      shared  buff/cache   available
Mem:          3.8Gi       2.5Gi       400Mi        50Mi       900Mi       1.0Gi
Swap:         2.0Gi       100Mi       1.9Gi
```

**Verificar:**
- Used memory: <90% total
- Available: >500MB
- Swap used: <50% (ideal <20%)

---

### Network Connectivity (Primary → Standby)

```bash
vagrant ssh primary -c "ping -c 3 192.168.56.102"
```

Debe haber respuesta con latencia <1ms (red local).

```bash
vagrant ssh primary -c "sudo su - oracle -c 'ssh oracle@ol8-21-dg2.localdomain hostname'"
```

Debe devolver: `ol8-21-dg2.localdomain`

---

## Reportes Diarios

Generar un reporte diario ayuda a mantener un registro histórico.

### Template de Reporte Diario

```
========================================
ORACLE DATA GUARD - REPORTE DIARIO
========================================
Fecha: 04-NOV-2025
Generado por: [Nombre DBA]

1. ESTADO GENERAL
   Primary:  ✓ ONLINE - READ WRITE
   Standby:  ✓ ONLINE - MOUNTED/READ ONLY WITH APPLY

2. REPLICACIÓN
   Apply Lag:     0 seconds ✓
   Transport Lag: 1 second ✓
   Sequence Gap:  0 sequences ✓
   Archive Gaps:  None ✓

3. BACKUPS
   Último backup: 04-NOV-2025 01:00 AM ✓
   Backup size:   12.5 GB
   Transfer:      Successful ✓
   RMAN status:   No errors ✓

4. ESPACIO EN DISCO
   Primary /u01:  48% ✓
   Primary /u02:  27% ✓
   Standby /u01:  46% ✓
   Standby /u02:  35% ✓

5. ALERTAS
   [Ninguna / Detalles de alertas]

6. ACCIONES REALIZADAS
   [Ninguna / Descripción de acciones]

7. OBSERVACIONES
   [Notas adicionales]

========================================
```

---

## Checklist Diario

Imprimir o guardar esta checklist para uso diario.

### Checklist de Monitoreo Diario

**Fecha:** _______________  **DBA:** _______________

#### Checks Automatizados (Revisar Logs)

- [ ] check_log_transport.sh - Sin warnings
- [ ] rman_daily_backup.sh - Completado exitosamente
- [ ] delete_archives_*.sh - Ejecutados correctamente
- [ ] Cron jobs activos en ambos nodos

#### Checks Manuales

- [ ] verify_dataguard.sh ejecutado - Todo SUCCESS
- [ ] Conectividad a primary desde Windows - OK
- [ ] Conectividad a standby desde Windows - OK
- [ ] Listener en primary - Running
- [ ] Listener en standby - Running
- [ ] Apply lag < 5 segundos
- [ ] Transport lag < 2 segundos
- [ ] Sequence gap = 0 o <3
- [ ] Archive gap = 0
- [ ] Protection mode = MAXIMUM AVAILABILITY
- [ ] MRP0 en standby = APPLYING_LOG

#### Espacio en Disco

- [ ] Primary /u01 < 80%
- [ ] Primary /u02 < 85%
- [ ] Standby /u01 < 80%
- [ ] Standby /u02 < 85%

#### Alert Logs (últimas 50 líneas)

- [ ] Primary alert log - Sin errores ORA-
- [ ] Standby alert log - Sin errores ORA-

#### Backups

- [ ] Último backup < 24 horas
- [ ] Backup transferido a standby
- [ ] Backup size razonable (10-15 GB típico)

#### Procesos Oracle

- [ ] Primary: pmon, smon, lgwr, arch, lns - Running
- [ ] Standby: pmon, smon, rfs, mrp0 - Running

#### Monitoreo de Recursos

- [ ] CPU usage < 80%
- [ ] Memory available > 500MB
- [ ] Network connectivity OK

#### Data Guard Broker

- [ ] Configuration status = SUCCESS
- [ ] Database cdb1 status = SUCCESS
- [ ] Database cdb1_stby status = SUCCESS

#### Schema Replication

- [ ] HEALTHCENTER schema presente en standby
- [ ] Table count coincide con primary

#### Observaciones/Acciones

```
__________________________________________
__________________________________________
__________________________________________
```

#### Firma DBA

```
__________________________________________
```

---

## Referencias

- [94 - Troubleshooting](94-troubleshooting.md) - Resolución de problemas comunes
- [91 - Respaldos Manuales](91-respaldos-manuales.md) - Procedimientos de backup
- [Oracle Data Guard Monitoring](https://docs.oracle.com/en/database/oracle/oracle-database/21/sbydb/monitoring-oracle-data-guard.html)
- [v$dataguard_stats Reference](https://docs.oracle.com/en/database/oracle/oracle-database/21/refrn/V-DATAGUARD_STATS.html)

---

**Nota Final:** El monitoreo diario es la clave para prevenir problemas antes de que se conviertan en desastres. Dedica 15-20 minutos cada día para asegurar que tu sistema Data Guard está saludable.
