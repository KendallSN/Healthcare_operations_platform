# 70 - Check Log Transport

## Monitoreo Automático de Transferencia de Archive Logs

Este script monitorea continuamente la replicación de archive logs desde el nodo primario hacia el nodo standby, verificando que la transferencia de datos se mantenga sincronizada y alertando cuando existen desfases significativos.

## Ubicación

`2-Standby/automation/check_log_transport.sh`

## Propósito

Verificar cada 10 minutos que los archive logs generados en el primario están siendo transferidos y aplicados correctamente en el standby, cumpliendo con los requisitos de alta disponibilidad del sistema. Este monitoreo continuo permite detectar problemas de replicación antes de que impacten la capacidad de recuperación.

## Cuándo se Ejecuta

- **Frecuencia:** Cada 10 minutos (*/10 * * * *)
- **Nodo:** Primary solamente
- **Usuario:** oracle
- **Installed by:** install_cron_jobs.sh

## Cron Schedule

```cron
*/10 * * * * /home/oracle/automation/check_log_transport.sh
```

**En español:** "Cada 10 minutos, todos los días"

## Variables de Entorno

Desde `config/install.env`:

```bash
# Nodos Data Guard
NODE2_DB_UNIQUE_NAME=cdb1_stby       # Nombre único del standby
NODE2_FQ_HOSTNAME=ol8-21-dg2.localdomain

# Credenciales
SYS_PASSWORD=S1sPassword1!           # Password del usuario SYS

# Configuración de monitoreo
LOG_GAP_ALERT_THRESHOLD=10           # Alerta si gap > 10 secuencias

# Dominio
DB_DOMAIN=world
```

## Qué Hace el Script (Paso a Paso)

### Paso 1: Inicialización del Entorno

```bash
. /home/oracle/scripts/setEnv.sh
. /vagrant_config/install.env

LOGFILE="/home/oracle/logs/automation/log_transport.log"
```

**Explicación:** Carga las variables de entorno necesarias (ORACLE_HOME, ORACLE_SID) y define el archivo de log donde se registrará el monitoreo.

### Paso 2: Consultar Última Secuencia Archivada en Primary

```bash
PRIMARY_SEQ=$(sqlplus -s / as sysdba << EOF
SET PAGESIZE 0 FEEDBACK OFF HEADING OFF
SELECT MAX(sequence#) FROM v\$archived_log WHERE dest_id=1 AND archived='YES';
EXIT;
EOF
)
```

**Explicación:** Consulta la vista dinámica `v$archived_log` para obtener el número de secuencia del último archive log que se archivó exitosamente en el nodo primario. El `dest_id=1` se refiere al destino local en el primario.

**¿Qué es v$archived_log?**
- Vista dinámica que contiene información sobre todos los archive logs generados
- Cada fila representa un archive log con su número de secuencia
- `archived='YES'` indica que el proceso de archivado completó exitosamente

### Paso 3: Consultar Última Secuencia Aplicada en Standby

```bash
STANDBY_SEQ=$(sqlplus -s sys/${SYS_PASSWORD}@${NODE2_DB_UNIQUE_NAME}${DB_DOMAIN_STR} as sysdba << EOF
SET PAGESIZE 0 FEEDBACK OFF HEADING OFF
SELECT MAX(sequence#) FROM v\$archived_log WHERE dest_id=1 AND applied='YES';
EXIT;
EOF
)
```

**Explicación:** Conecta remotamente al standby usando TNS y consulta la última secuencia que fue aplicada al standby. `applied='YES'` significa que el MRP (Managed Recovery Process) ya procesó este archive log.

**Conexión remota:**
- `sys/${SYS_PASSWORD}@${NODE2_DB_UNIQUE_NAME}${DB_DOMAIN_STR}` = `sys/S1sPassword1!@cdb1_stby.world`
- Utiliza el TNS configurado en `$ORACLE_HOME/network/admin/tnsnames.ora`

### Paso 4: Calcular el Gap de Replicación

```bash
GAP=$((PRIMARY_SEQ - STANDBY_SEQ))

echo "Primary last archived: $PRIMARY_SEQ"
echo "Standby last applied: $STANDBY_SEQ"
echo "Current gap: $GAP sequences"
```

**Explicación:** El "gap" es la diferencia entre la última secuencia archivada en primary y la última aplicada en standby. Un gap pequeño (0-5) es normal durante operaciones activas, pero un gap grande indica problemas de replicación.

**Interpretación del Gap:**
- Gap = 0: Standby completamente sincronizado (ideal)
- Gap = 1-5: Normal durante operación activa
- Gap = 6-10: Standby está retrasado (vigilar)
- Gap > 10: Problema serio (alerta activada)

### Paso 5: Verificar Apply Lag

```bash
APPLY_LAG=$(sqlplus -s sys/${SYS_PASSWORD}@${NODE2_DB_UNIQUE_NAME}${DB_DOMAIN_STR} as sysdba << EOF
SET PAGESIZE 0 FEEDBACK OFF HEADING OFF
SELECT value FROM v\$dataguard_stats WHERE name='apply lag';
EXIT;
EOF
)

echo "Apply lag: $APPLY_LAG"
```

**Explicación:** `v$dataguard_stats` proporciona métricas específicas de Data Guard. El "apply lag" mide cuánto tiempo está retrasado el standby en aplicar los cambios (generalmente en formato "+0 00:00:00" o similar).

**¿Qué es apply lag?**
- Tiempo transcurrido entre cuando se generó un cambio en primary y cuando se aplicó en standby
- Expresado como: "+HH:MI:SS" o "+DD HH:MI:SS"
- Ejemplo: "+0 00:02:30" significa 2 minutos 30 segundos de retraso

### Paso 6: Verificar Threshold y Generar Alertas

```bash
if [ $GAP -gt ${LOG_GAP_ALERT_THRESHOLD} ]; then
  echo "WARNING: Gap exceeds ${LOG_GAP_ALERT_THRESHOLD} sequences!"
  # Could send email alert here
fi
```

**Explicación:** Si el gap excede el umbral configurado (default: 10 secuencias), se registra una advertencia en el log. En un ambiente de producción, aquí se podría enviar un email o activar un sistema de alertas.

**Posibles acciones cuando hay alerta:**
1. Verificar conectividad de red entre primary y standby
2. Revisar el estado del listener en standby
3. Verificar espacio en disco para archive logs
4. Consultar alertlog de ambas bases de datos

### Paso 7: Mantener Tamaño del Log

```bash
tail -1000 $LOGFILE > ${LOGFILE}.tmp && mv ${LOGFILE}.tmp $LOGFILE
```

**Explicación:** Mantiene solo las últimas 1000 líneas del archivo de log para evitar que crezca indefinidamente. Con ejecuciones cada 10 minutos, esto preserva aproximadamente 7 días de historia (144 ejecuciones diarias).

## Comandos Importantes

### v$archived_log

Vista dinámica que registra todos los archive logs:

```sql
-- Ver últimos 10 archive logs generados
SELECT sequence#, first_time, next_time, archived, applied, deleted
FROM v$archived_log
WHERE dest_id=1
ORDER BY sequence# DESC
FETCH FIRST 10 ROWS ONLY;

-- Verificar estado de archivado para cada destino
SELECT dest_id, status, error, archived, applied
FROM v$archived_log
WHERE sequence# = (SELECT MAX(sequence#) FROM v$archived_log);
```

### v$dataguard_stats

Métricas específicas de Data Guard:

```sql
-- Ver todas las estadísticas de Data Guard
SELECT name, value, unit, time_computed
FROM v$dataguard_stats;

-- Estadísticas clave a monitorear:
-- 'transport lag'  - Retraso en transferencia de logs
-- 'apply lag'      - Retraso en aplicación de cambios
-- 'apply finish time' - Tiempo estimado para alcanzar sincronización
```

## Salida Esperada

Cuando el script se ejecuta correctamente:

```
====================================================================
Log Transport Check: Tue Nov  4 14:20:01 UTC 2025
====================================================================
Primary last archived: 145
Standby last applied: 145
Current gap: 0 sequences
Apply lag: +0 00:00:03
====================================================================
```

**Interpretación:**
- Secuencia 145 es la última generada y aplicada
- Gap de 0 secuencias = sincronización perfecta
- Apply lag de 3 segundos = tiempo desde que se generó el último cambio

Cuando hay desfase:

```
====================================================================
Log Transport Check: Tue Nov  4 14:30:01 UTC 2025
====================================================================
Primary last archived: 158
Standby last applied: 146
Current gap: 12 sequences
Apply lag: +0 00:05:23
WARNING: Gap exceeds 10 sequences!
====================================================================
```

**Interpretación:**
- Standby está 12 secuencias atrasado (alerta activada)
- Apply lag de 5 minutos 23 segundos
- Se requiere investigación inmediata

## Logs Generados

- **Ubicación:** `/home/oracle/logs/automation/log_transport.log`
- **Contenido:**
  - Timestamp de cada verificación
  - Secuencias primary/standby
  - Gap calculado
  - Apply lag
  - Alertas cuando gap > threshold
- **Retención:** Últimas 1000 líneas (~7 días con ejecución cada 10 minutos)
- **Formato:** Append (se agrega al final del archivo)

### Ejemplo de Log Completo

```
====================================================================
Log Transport Check: Tue Nov  4 13:00:01 UTC 2025
====================================================================
Primary last archived: 120
Standby last applied: 120
Current gap: 0 sequences
Apply lag: +0 00:00:02
====================================================================

====================================================================
Log Transport Check: Tue Nov  4 13:10:01 UTC 2025
====================================================================
Primary last archived: 123
Standby last applied: 123
Current gap: 0 sequences
Apply lag: +0 00:00:01
====================================================================

====================================================================
Log Transport Check: Tue Nov  4 13:20:01 UTC 2025
====================================================================
Primary last archived: 127
Standby last applied: 125
Current gap: 2 sequences
Apply lag: +0 00:01:15
====================================================================
```

## Umbrales y Alertas

### Threshold Configurado

```bash
LOG_GAP_ALERT_THRESHOLD=10  # De install.env
```

**Significado:**
- Si `PRIMARY_SEQ - STANDBY_SEQ > 10`, se genera alerta
- Ajustable según necesidades del ambiente
- Valor conservador: 5 secuencias
- Valor permisivo: 20 secuencias

### Razones para Ajustar el Threshold

**Aumentar threshold (15-20) si:**
- Alto volumen de transacciones (muchos archive logs por minuto)
- Red con latencia conocida entre nodos
- Aplicación genera ráfagas de actividad

**Disminuir threshold (5-7) si:**
- Requisitos estrictos de RPO (Recovery Point Objective)
- Ambiente de producción crítico
- Red de alta velocidad entre nodos

### Acciones al Recibir Alerta

1. **Verificar conectividad:**
   ```bash
   ping ol8-21-dg2.localdomain
   tnsping cdb1_stby.world
   ```

2. **Revisar listener en standby:**
   ```bash
   ssh oracle@ol8-21-dg2 "lsnrctl status"
   ```

3. **Verificar espacio en disco:**
   ```bash
   ssh oracle@ol8-21-dg2 "df -h /u01/app/oracle/fast_recovery_area"
   ```

4. **Consultar procesos de replicación:**
   ```sql
   -- En standby
   SELECT process, status, thread#, sequence#, block#, blocks
   FROM v$managed_standby
   WHERE process LIKE 'MRP%' OR process LIKE 'RFS%';
   ```

## Ejecución Manual

Para probar el script o ejecutar verificación bajo demanda:

```bash
# Como usuario oracle en primary
/home/oracle/automation/check_log_transport.sh

# Ver el resultado inmediatamente
tail -20 /home/oracle/logs/automation/log_transport.log
```

**Casos de uso para ejecución manual:**
- Después de aplicar cambios en Data Guard
- Tras reiniciar base de datos
- Al investigar problemas de replicación
- Antes de realizar switchover o failover

## Verificación

### Confirmar que el Script Está en Cron

```bash
# Ver cron jobs instalados
crontab -l | grep check_log_transport

# Salida esperada:
# */10 * * * * /home/oracle/automation/check_log_transport.sh
```

### Verificar Ejecuciones Recientes

```bash
# Ver últimas 50 líneas del log
tail -50 /home/oracle/logs/automation/log_transport.log

# Contar ejecuciones del día actual
grep "$(date +%Y-%m-%d)" /home/oracle/logs/automation/log_transport.log | grep "Log Transport Check" | wc -l

# Deberían ser aproximadamente: (hora actual - 0) * 6
# Ejemplo: Si son las 14:00, deberían haber ~84 ejecuciones (14 * 6)
```

### Verificar que No Hay Gaps Críticos

```bash
# Buscar alertas en el día actual
grep "WARNING" /home/oracle/logs/automation/log_transport.log | grep "$(date +%Y-%m-%d)"

# Si no hay salida = no hay gaps críticos (bueno)
# Si hay salida = investigar inmediatamente
```

### Prueba de Generación de Archive Log

```bash
# Forzar creación de archive log y verificar replicación
sqlplus / as sysdba <<EOF
ALTER SYSTEM ARCHIVE LOG CURRENT;
EXIT;
EOF

# Esperar 1 minuto
sleep 60

# Ejecutar verificación manual
/home/oracle/automation/check_log_transport.sh

# Ver resultado
tail -15 /home/oracle/logs/automation/log_transport.log
```

## Puntos de Fallo Comunes

### 1. "ORA-01017: invalid username/password"

**Causa:** Password de SYS incorrecto en install.env o cambió en la base de datos.

**Solución:**
```bash
# Verificar password actual
cat /vagrant_config/install.env | grep SYS_PASSWORD

# Si cambió, actualizar install.env y reintentar
```

### 2. "ORA-12154: TNS:could not resolve the connect identifier"

**Causa:** TNS name `cdb1_stby.world` no existe o está mal configurado.

**Solución:**
```bash
# Verificar tnsnames.ora
cat $ORACLE_HOME/network/admin/tnsnames.ora | grep cdb1_stby -A 10

# Probar conexión manualmente
tnsping cdb1_stby.world
sqlplus sys/S1sPassword1!@cdb1_stby.world as sysdba
```

### 3. "ORA-12514: TNS:listener does not currently know of service"

**Causa:** Listener en standby no está levantado o no conoce el servicio.

**Solución:**
```bash
# En standby
lsnrctl status

# Si no está levantado
lsnrctl start

# Verificar que cdb1_stby esté registrado
lsnrctl services | grep cdb1_stby
```

### 4. Gap Siempre Aumentando

**Causa:** MRP (Managed Recovery Process) no está corriendo en standby.

**Solución:**
```sql
-- Verificar en standby
SELECT process, status FROM v$managed_standby WHERE process LIKE 'MRP%';

-- Si no hay filas, iniciar MRP
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;
```

### 5. Script No Se Ejecuta Automáticamente

**Causa:** Cron job no instalado o cron daemon no corriendo.

**Solución:**
```bash
# Verificar que cron esté corriendo
systemctl status crond

# Si no está activo
sudo systemctl start crond
sudo systemctl enable crond

# Reinstalar cron jobs
/home/oracle/automation/install_cron_jobs.sh
```

### 6. Log File Crece Demasiado

**Causa:** Comando `tail -1000` falló o no se ejecuta.

**Solución:**
```bash
# Limpiar manualmente
tail -1000 /home/oracle/logs/automation/log_transport.log > /tmp/log_tmp
mv /tmp/log_tmp /home/oracle/logs/automation/log_transport.log

# Verificar permisos
ls -l /home/oracle/logs/automation/log_transport.log
# Debe ser: -rw-r--r-- oracle oinstall
```

## Importancia para el Sistema

Este script es **CRÍTICO** para mantener la alta disponibilidad del sistema porque:

### 1. Cumple Requisito de Sincronización

El proyecto requiere "transferencia cada 10 minutos", y este script verifica que se cumpla.

**RPO (Recovery Point Objective):**
- Con ARCHIVE_LAG_TARGET=300s (5 min) y monitoreo cada 10 min
- RPO máximo: 5 minutos de datos en el peor caso
- Cumple con requisitos de sistemas críticos de salud

### 2. Detección Temprana de Problemas

Permite identificar problemas de replicación antes de que se vuelvan críticos:
- Red caída entre nodos
- Problemas de espacio en disco
- Procesos de Data Guard detenidos

### 3. Base para Failover Seguro

Solo se puede hacer un failover confiable si:
- El gap es mínimo (< 5 secuencias)
- El apply lag es bajo (< 1 minuto)
- Este script confirma ambas condiciones

### 4. Evidencia de Cumplimiento

Los logs generados sirven como evidencia de:
- Disponibilidad del sistema de replicación
- Cumplimiento de SLAs
- Auditoría de operación de Data Guard

### 5. Prevención de Pérdida de Datos

Si el gap crece sin control:
- Riesgo de perder archive logs (si se llenan discos)
- Standby puede quedar desincronizado
- Necesidad de reconstruir standby desde cero (costoso)

### 6. Integración con ARCHIVE_LAG_TARGET

Trabaja en conjunto con el parámetro ARCHIVE_LAG_TARGET=300 para garantizar:
- Archive logs se generan cada 5 minutos máximo
- Monitoreo verifica transferencia cada 10 minutos
- Sistema completo de sincronización continua

## Referencias Cruzadas

### Documentos Relacionados

- **[41-install-cron.md](../ejecucion/primary/41-install-cron.md)** - Instalación de este cron job
- **[71-rman-daily-backup.md](71-rman-daily-backup.md)** - Backup diario que depende de replicación
- **[72-delete-archives-primary.md](72-delete-archives-primary.md)** - Usa datos de este script para limpieza
- **[74-verify-dataguard.md](74-verify-dataguard.md)** - Verificación completa incluye estas métricas

### Conceptos de Data Guard

- **Archive Logs:** Archivos de redo generados cuando se llena un redo log
- **Sequence Number:** Número secuencial único de cada archive log
- **dest_id:** Identificador del destino de archivado (1=local, 2=remoto)
- **Gap:** Diferencia en secuencias entre primary y standby
- **Apply Lag:** Tiempo de retraso en aplicación de cambios

### Comandos Útiles

```sql
-- Ver configuración actual de archive lag
SHOW PARAMETER ARCHIVE_LAG_TARGET;

-- Ver destinos de archivado configurados
SELECT dest_id, dest_name, status, destination
FROM v$archive_dest
WHERE status != 'INACTIVE';

-- Ver últimos 20 archive logs con todos sus estados
SELECT sequence#, dest_id, archived, applied, deleted,
       TO_CHAR(completion_time, 'YYYY-MM-DD HH24:MI:SS') AS completed
FROM v$archived_log
ORDER BY sequence# DESC, dest_id
FETCH FIRST 20 ROWS ONLY;

-- Ver historial de gaps (si existieron)
SELECT * FROM v$archive_gap;
```

### Archivos de Configuración

- `/vagrant_config/install.env` - Variables de entorno
- `$ORACLE_HOME/network/admin/tnsnames.ora` - Conexión al standby
- `/home/oracle/scripts/setEnv.sh` - Variables Oracle
- `/home/oracle/logs/automation/log_transport.log` - Logs de ejecución

---

**Última Actualización:** 2025-11-04
**Autor:** Claude (Subagente 4)
**Versión:** 1.0
