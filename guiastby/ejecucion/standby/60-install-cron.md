# 60 - Instalación de Cron Jobs (Standby)

## Descripción General

**Archivo:** `2-Standby/automation/install_cron_jobs.sh`

**Propósito:** Instalar trabajos programados (cron jobs) para automatización de tareas de mantenimiento del standby database.

**Diferencia con Primary:** Standby tiene SOLO 1 cron job (limpieza de archives), mientras que primary tiene 3.

**Tiempo de ejecución:** ~5 segundos

---

## Comparación Primary vs Standby

### Primary Cron Jobs (3 jobs)

```cron
# Oracle Data Guard Automation
*/10 * * * * /home/oracle/automation/check_log_transport.sh
0 1 * * * /home/oracle/automation/rman_daily_backup.sh
0 2 * * * /home/oracle/automation/delete_archives_primary.sh
```

**Tareas:**
1. Monitorear transporte de logs cada 10 minutos
2. Backup RMAN diario a la 1 AM
3. Limpieza de archives a las 2 AM (después del backup)

---

### Standby Cron Jobs (1 job) ⭐

```cron
# Oracle Data Guard Automation
0 23 * * * /home/oracle/automation/delete_archives_standby.sh
```

**Tarea:**
1. Limpieza de archives aplicados a las 11 PM

**Por qué solo 1 job:**
- Standby NO monitorea (es el receptor)
- Standby NO hace backups (recibe de primary)
- Standby SOLO limpia archives aplicados

---

## Código del Script

```bash
#!/bin/bash
# Install Cron Jobs for Automation
# Run as oracle user

. /home/oracle/scripts/setEnv.sh
. /vagrant_config/install.env

# Determine if this is primary or standby based on hostname
CURRENT_HOST=$(hostname -f)

echo "===================================================================="
echo "Installing Cron Jobs for Automation"
echo "Current host: $CURRENT_HOST"
echo "===================================================================="

# Create temporary cron file
CRON_FILE="/tmp/oracle_cron_$$"

# Get existing cron jobs (if any)
crontab -l > $CRON_FILE 2>/dev/null || touch $CRON_FILE

# Remove old automation entries
sed -i '/# Oracle Data Guard Automation/d' $CRON_FILE
sed -i '/check_log_transport.sh/d' $CRON_FILE
sed -i '/rman_daily_backup.sh/d' $CRON_FILE
sed -i '/delete_archives/d' $CRON_FILE

echo ""
echo "Adding automation cron jobs..."

# Add header
echo "" >> $CRON_FILE
echo "# Oracle Data Guard Automation" >> $CRON_FILE

if [ "$CURRENT_HOST" == "$NODE1_FQ_HOSTNAME" ]; then
  echo "Configuring PRIMARY cron jobs..."

  # Log transport check every 10 minutes
  echo "${LOG_TRANSPORT_CHECK_INTERVAL} /home/oracle/automation/check_log_transport.sh" >> $CRON_FILE

  # Daily backup at configured time (default 1 AM)
  echo "${BACKUP_TIME} /home/oracle/automation/rman_daily_backup.sh" >> $CRON_FILE

  # Archive cleanup on primary at 2 AM (after backup)
  echo "0 2 * * * /home/oracle/automation/delete_archives_primary.sh" >> $CRON_FILE

elif [ "$CURRENT_HOST" == "$NODE2_FQ_HOSTNAME" ]; then
  echo "Configuring STANDBY cron jobs..."

  # Archive cleanup on standby at configured time (default 11 PM)
  echo "${ARCHIVE_CLEANUP_TIME} /home/oracle/automation/delete_archives_standby.sh" >> $CRON_FILE

else
  echo "ERROR: Cannot determine if this is primary or standby!"
  echo "Current hostname: $CURRENT_HOST"
  echo "Expected: $NODE1_FQ_HOSTNAME or $NODE2_FQ_HOSTNAME"
  rm -f $CRON_FILE
  exit 1
fi

# Install crontab
crontab $CRON_FILE

# Cleanup
rm -f $CRON_FILE

echo ""
echo "===================================================================="
echo "Installed Cron Jobs:"
echo "===================================================================="
crontab -l | grep -A 10 "Oracle Data Guard Automation"

echo ""
echo "===================================================================="
echo "Cron Jobs Installation Complete!"
echo "===================================================================="
```

---

## Desglose del Script

### 1. Determinar Tipo de Nodo

```bash
CURRENT_HOST=$(hostname -f)
# En standby: ol8-21-dg2.localdomain
```

**Comparación:**
```bash
if [ "$CURRENT_HOST" == "$NODE1_FQ_HOSTNAME" ]; then
  # Primary
elif [ "$CURRENT_HOST" == "$NODE2_FQ_HOSTNAME" ]; then
  # Standby ⭐
else
  # Error
fi
```

**Por qué:**
- Mismo script se usa en primary y standby
- Instala diferentes jobs según el nodo
- Variables de install.env:
  - `NODE1_FQ_HOSTNAME=ol8-21-dg1.localdomain`
  - `NODE2_FQ_HOSTNAME=ol8-21-dg2.localdomain`

---

### 2. Backup de Crontab Existente

```bash
CRON_FILE="/tmp/oracle_cron_$$"
crontab -l > $CRON_FILE 2>/dev/null || touch $CRON_FILE
```

**`$$`:**
- PID del proceso actual
- Genera nombre único: `/tmp/oracle_cron_12345`
- Previene conflictos si script se ejecuta múltiples veces

**`2>/dev/null || touch`:**
- Si no hay crontab previo, `crontab -l` falla
- `|| touch` crea archivo vacío
- No interrumpe el script

---

### 3. Limpiar Entradas Antiguas

```bash
sed -i '/# Oracle Data Guard Automation/d' $CRON_FILE
sed -i '/check_log_transport.sh/d' $CRON_FILE
sed -i '/rman_daily_backup.sh/d' $CRON_FILE
sed -i '/delete_archives/d' $CRON_FILE
```

**Por qué:**
- Permite re-ejecutar script sin duplicar entries
- Elimina configuración antigua
- Asegura limpieza antes de agregar nuevas

---

### 4. Agregar Cron Jobs (Standby)

```bash
elif [ "$CURRENT_HOST" == "$NODE2_FQ_HOSTNAME" ]; then
  echo "Configuring STANDBY cron jobs..."

  # Archive cleanup on standby at configured time (default 11 PM)
  echo "${ARCHIVE_CLEANUP_TIME} /home/oracle/automation/delete_archives_standby.sh" >> $CRON_FILE
```

**Variable `ARCHIVE_CLEANUP_TIME`:**
```bash
# De install.env:
ARCHIVE_CLEANUP_TIME="0 23 * * *"  # 11 PM daily
```

**Formato cron:**
```
0 23 * * *
│ │  │ │ └─ Día de semana (0-7, 0=Domingo)
│ │  │ └─── Mes (1-12)
│ │  └───── Día del mes (1-31)
│ └──────── Hora (0-23)
└────────── Minuto (0-59)

0 23 * * * = Todos los días a las 11:00 PM
```

---

### 5. Instalar Crontab

```bash
crontab $CRON_FILE
rm -f $CRON_FILE
```

**`crontab $CRON_FILE`:**
- Instala el crontab para el usuario actual (oracle)
- Reemplaza crontab anterior completamente

**Cleanup:**
- Elimina archivo temporal

---

## Cron Job Instalado en Standby

### delete_archives_standby.sh

**Horario:** Diario 11 PM (23:00)

**Propósito:** Eliminar archive logs que ya fueron aplicados al standby.

**Lógica:**
```sql
-- Query archive logs aplicados
SELECT name FROM v$archived_log
WHERE applied='YES'
  AND deleted='NO'
  AND first_time < SYSDATE - ${ARCHIVE_RETENTION_DAYS};

-- Eliminar cada archivo
DELETE NOPROMPT ARCHIVELOG 'path/to/archive.arc';
```

**Retención:** 3 días (configurable en `install.env`)

**Por qué 11 PM:**
- Después de que primary hizo backup (1 AM primary)
- Primary limpió sus archives (2 AM primary)
- Standby recibió y aplicó logs del día
- Seguro eliminar archives antiguos

---

## Verificación

### Ver Cron Jobs Instalados

```bash
vagrant ssh standby
sudo su - oracle

# Listar crontab
crontab -l

# Salida esperada:
# Oracle Data Guard Automation
0 23 * * * /home/oracle/automation/delete_archives_standby.sh
```

---

### Ver Logs de Ejecución

**Log del cron job:**
```bash
# Ver log de limpieza
cat /home/oracle/logs/automation/delete_archives_standby.log

# Ejemplo de contenido:
[2025-11-04 23:00:01] Starting archive log cleanup on standby...
[2025-11-04 23:00:02] Found 24 archive logs older than 3 days
[2025-11-04 23:00:03] Deleting: /u01/oradata/CDB1/arch/1_100_1234567890.arc
[2025-11-04 23:00:03] Deleting: /u01/oradata/CDB1/arch/1_101_1234567890.arc
...
[2025-11-04 23:00:15] Deleted 24 archive logs successfully
[2025-11-04 23:00:15] Archive log cleanup complete.
```

**Cron log del sistema:**
```bash
# Ver que cron ejecutó el job
sudo grep delete_archives /var/log/cron

# Ejemplo:
Nov  4 23:00:01 ol8-21-dg2 CROND[12345]: (oracle) CMD (/home/oracle/automation/delete_archives_standby.sh)
```

---

### Ejecutar Manualmente (Testing)

```bash
vagrant ssh standby
sudo su - oracle

# Ejecutar script directamente
/home/oracle/automation/delete_archives_standby.sh

# Ver salida en tiempo real
```

**Útil para:**
- Verificar que script funciona antes del cron
- Debugging
- Limpieza on-demand

---

## Diferencias con Primary

| Aspecto | Primary | Standby |
|---------|---------|---------|
| **Número de jobs** | 3 | 1 ⭐ |
| **Monitoreo lag** | ✅ Cada 10 min | ❌ No |
| **Backup RMAN** | ✅ Diario 1 AM | ❌ No |
| **Limpieza archives** | ✅ Diario 2 AM | ✅ Diario 11 PM ⭐ |
| **Script limpieza** | delete_archives_primary.sh | delete_archives_standby.sh ⭐ |

### ¿Por qué Standby No Hace Backups?

**Estrategia de backup:**
1. Primary hace backup RMAN diario
2. Primary transfiere backups a standby vía rsync
3. Standby almacena en `/u02/backup_from_primary/`

**Resultado:**
- Backups están en ambos nodos
- Si primary falla, standby tiene backups
- No necesita hacer sus propios backups

**Excepción:**
- En producción real, podría configurar backups en standby
- Para reducir carga en primary
- Este proyecto usa estrategia simple: primary hace backups

---

## Troubleshooting

### Problema: Cron job no ejecuta

**Síntoma:**
```bash
# No hay logs
ls /home/oracle/logs/automation/delete_archives_standby.log
ls: cannot access: No such file or directory
```

**Diagnóstico:**
```bash
# Ver crontab
crontab -l

# Ver cron log del sistema
sudo grep oracle /var/log/cron

# Ver si crond está corriendo
systemctl status crond
```

**Solución:**
```bash
# Re-instalar cron jobs
sh /home/oracle/automation/install_cron_jobs.sh

# Verificar
crontab -l
```

---

### Problema: Script falla al ejecutar

**Síntoma:**
```bash
# Log muestra errores
cat /home/oracle/logs/automation/delete_archives_standby.log
ORA-00001: unique constraint violated
```

**Causa:**
- Variables de entorno no cargadas
- Script no tiene permisos correctos

**Solución:**
```bash
# Verificar permisos
chmod +x /home/oracle/automation/delete_archives_standby.sh

# Ejecutar manualmente con debug
bash -x /home/oracle/automation/delete_archives_standby.sh
```

---

### Problema: Archives no se eliminan

**Síntoma:**
```bash
# Disco /u01 se llena
df -h /u01
Filesystem      Size  Used Avail Use% Mounted on
/dev/sdb1        99G   98G  1.0G  99% /u01  # ❌ Casi lleno
```

**Causa:**
- Cron job no configurado
- Retención muy larga
- Archives no aplicados (no se pueden eliminar)

**Diagnóstico:**
```sql
-- Ver archives pendientes de aplicar
SELECT COUNT(*) FROM v$archived_log WHERE applied='NO';

-- Ver espacio usado por archives
SELECT SUM(blocks*block_size)/1024/1024/1024 AS size_gb
FROM v$archived_log
WHERE deleted='NO';
```

**Solución:**
```bash
# Ejecutar limpieza manual
/home/oracle/automation/delete_archives_standby.sh

# O RMAN cleanup
rman target / <<EOF
DELETE NOPROMPT ARCHIVELOG ALL COMPLETED BEFORE 'SYSDATE-1';
EOF
```

---

## Resumen

### Cron Job en Standby

**Un único job:**
```cron
0 23 * * * /home/oracle/automation/delete_archives_standby.sh
```

**Función:** Limpieza diaria de archive logs aplicados

**Horario:** 11 PM (23:00)

**Por qué este horario:**
- Después de actividad del primary (backups a 1-2 AM)
- Antes de medianoche (inicio de nuevo día)
- Fuera de horas laborales

---

### Comparación con Primary

Primary es activo (monitorea, hace backups, limpia).
Standby es pasivo (solo limpia archives aplicados).

---

### Archivos Relacionados

- **Script cron:** [73-delete-archives-standby.md](../../scripts-automatizacion/73-delete-archives-standby.md)
- **Primary cron:** [41-install-cron-primary.md](../primary/41-install-cron.md)
- **Monitoreo:** [90-monitoreo-diario.md](../../operaciones/90-monitoreo-diario.md)

---

## Conclusión del Despliegue Standby

**Con este paso, el despliegue standby está COMPLETO:**

✅ 50: Entry point wrapper
✅ 51: Orquestador principal
✅ 52: Discos preparados
✅ 53: Paquetes instalados
✅ 54: Red configurada
✅ 55: Entorno Oracle
✅ 56: Oracle software instalado
✅ 57: 🔥 RMAN DUPLICATE + Data Guard 🔥
✅ 58: Scripts de automatización copiados
✅ 59: SSH keys configuradas
✅ 60: Cron jobs instalados ◄─── ESTÁS AQUÍ

**Sistema completamente funcional:**
- Standby database replicando desde primary
- Data Guard en modo MAXAVAILABILITY
- Automatización configurada
- Listo para producción

---

**FIN DE LA DOCUMENTACIÓN DE DESPLIEGUE STANDBY**

Para operaciones diarias, ver:
- [Monitoreo Diario](../../operaciones/90-monitoreo-diario.md)
- [Switchover](../../operaciones/92-switchover.md)
- [Failover](../../operaciones/93-failover.md)
