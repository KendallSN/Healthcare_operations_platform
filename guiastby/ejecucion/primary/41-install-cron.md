# 41 - Install Cron - Instalación de Cron Jobs Automatizados

## Instalación de Trabajos Cron para Automatización de Data Guard

Este es el **último paso** del despliegue primario. Instala 3 cron jobs que ejecutan automáticamente: monitoreo de log transport cada 10 minutos, backup diario RMAN a la 1 AM, y limpieza de archive logs a las 2 AM. Después de este script, el nodo primario está **completamente operacional y automatizado**.

## Ubicación

`2-Standby/automation/install_cron_jobs.sh`

**Nota:** Este script detecta automáticamente si es primary o standby y configura los cron jobs apropiados.

## Propósito

- **Función principal:** Instalar cron jobs para automatización de Data Guard
- **Responsabilidad:** Configurar monitoreo continuo, backups automáticos, mantenimiento
- **Resultado:** Sistema completamente automatizado sin intervención manual

## Cuándo se Ejecuta

- **Llamado por:** `root_setup.sh`
- **Orden:** Paso 16 de 12 (ÚLTIMO PASO del despliegue primario)
- **Usuario:** `oracle` (cron jobs se ejecutan como oracle)
- **Duración:** < 5 segundos

## Variables de Entorno Utilizadas

```bash
# De setEnv.sh
ORACLE_HOME=/u01/app/oracle/product/21.0.0/dbhome_1

# De install.env
NODE1_FQ_HOSTNAME=ol8-21-dg1.localdomain
NODE2_FQ_HOSTNAME=ol8-21-dg2.localdomain
LOG_TRANSPORT_CHECK_INTERVAL="*/10 * * * *"    # Cada 10 minutos
BACKUP_TIME="0 1 * * *"                        # 1 AM diariamente
ARCHIVE_CLEANUP_TIME="0 23 * * *"              # 11 PM diariamente (standby)
```

## Flujo de Ejecución Paso a Paso

### Paso 1: Cargar Variables de Entorno

```bash
. /home/oracle/scripts/setEnv.sh
. /vagrant_config/install.env
```

### Paso 2: Detectar Si Es Primary o Standby

```bash
CURRENT_HOST=$(hostname -f)

echo "===================================================================="
echo "Installing Cron Jobs for Automation"
echo "Current host: $CURRENT_HOST"
echo "===================================================================="
```

### Paso 3: Crear Archivo Temporal para Crontab

```bash
CRON_FILE="/tmp/oracle_cron_$$"

# Get existing cron jobs (if any)
crontab -l > $CRON_FILE 2>/dev/null || touch $CRON_FILE
```

**Explicación:**
- `$$`: PID del proceso actual (hace filename único)
- `crontab -l`: Lista cron jobs existentes
- `2>/dev/null || touch`: Si no hay crontab, crea archivo vacío

### Paso 4: Limpiar Entradas Antiguas de Automatización

```bash
# Remove old automation entries
sed -i '/# Oracle Data Guard Automation/d' $CRON_FILE
sed -i '/check_log_transport.sh/d' $CRON_FILE
sed -i '/rman_daily_backup.sh/d' $CRON_FILE
sed -i '/delete_archives/d' $CRON_FILE
```

**Explicación:**
- Previene duplicados si script se ejecuta múltiples veces
- Permite re-ejecutar script para actualizar cron jobs

### Paso 5: Agregar Header

```bash
echo "" >> $CRON_FILE
echo "# Oracle Data Guard Automation" >> $CRON_FILE
```

### Paso 6: Agregar Cron Jobs para PRIMARY

```bash
if [ "$CURRENT_HOST" == "$NODE1_FQ_HOSTNAME" ]; then
  echo "Configuring PRIMARY cron jobs..."

  # Log transport check every 10 minutes
  echo "${LOG_TRANSPORT_CHECK_INTERVAL} /home/oracle/automation/check_log_transport.sh" >> $CRON_FILE

  # Daily backup at configured time (default 1 AM)
  echo "${BACKUP_TIME} /home/oracle/automation/rman_daily_backup.sh" >> $CRON_FILE

  # Archive cleanup on primary at 2 AM (after backup)
  echo "0 2 * * * /home/oracle/automation/delete_archives_primary.sh" >> $CRON_FILE

elif [ "$CURRENT_HOST" == "$NODE2_FQ_HOSTNAME" ]; then
  # ... (Standby cron jobs - no aplica en este nodo)
else
  echo "ERROR: Cannot determine if this is primary or standby!"
  exit 1
fi
```

**Cron jobs instalados en PRIMARY:**

**1. Monitoreo de Log Transport (cada 10 minutos):**
```cron
*/10 * * * * /home/oracle/automation/check_log_transport.sh
```
- Ejecuta: Cada 10 minutos
- Función: Verifica que archive logs se están replicando a standby
- Alerta: Si gap > 10 sequences
- Log: `/home/oracle/logs/automation/check_log_transport_YYYYMMDD.log`

**2. Backup Diario RMAN (1 AM):**
```cron
0 1 * * * /home/oracle/automation/rman_daily_backup.sh
```
- Ejecuta: Diariamente a la 1:00 AM
- Función: RMAN incremental level 1 backup + archive logs
- Destino: `/u02/backup/`
- Opcional: rsync a standby después del backup
- Log: `/home/oracle/logs/automation/rman_backup_YYYYMMDD.log`

**3. Limpieza de Archive Logs (2 AM):**
```cron
0 2 * * * /home/oracle/automation/delete_archives_primary.sh
```
- Ejecuta: Diariamente a las 2:00 AM (después del backup)
- Función: Elimina archive logs > 3 días (ya aplicados en standby)
- Previene: `/u01` lleno de archive logs
- Log: `/home/oracle/logs/automation/delete_archives_YYYYMMDD.log`

### Paso 7: Instalar Crontab

```bash
crontab $CRON_FILE
```

**Explicación:**
- Reemplaza crontab del usuario oracle con el nuevo archivo
- Cambios son efectivos inmediatamente (no necesita reboot)

### Paso 8: Limpiar Archivo Temporal

```bash
rm -f $CRON_FILE
```

### Paso 9: Mostrar Cron Jobs Instalados

```bash
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

**Salida esperada:**
```
====================================================================
Installed Cron Jobs:
====================================================================
# Oracle Data Guard Automation
*/10 * * * * /home/oracle/automation/check_log_transport.sh
0 1 * * * /home/oracle/automation/rman_daily_backup.sh
0 2 * * * /home/oracle/automation/delete_archives_primary.sh

====================================================================
Cron Jobs Installation Complete!
====================================================================
```

## Formato de Crontab

**Sintaxis cron:**
```
┌───────────── minuto (0 - 59)
│ ┌───────────── hora (0 - 23)
│ │ ┌───────────── día del mes (1 - 31)
│ │ │ ┌───────────── mes (1 - 12)
│ │ │ │ ┌───────────── día de la semana (0 - 6) (Domingo=0 o 7)
│ │ │ │ │
│ │ │ │ │
* * * * * comando a ejecutar
```

**Ejemplos:**

```cron
*/10 * * * *   # Cada 10 minutos
0 1 * * *      # Cada día a la 1:00 AM
0 2 * * *      # Cada día a las 2:00 AM
0 */4 * * *    # Cada 4 horas
0 0 * * 0      # Cada domingo a medianoche
30 2 1 * *     # Primer día del mes a las 2:30 AM
```

## Archivos Creados/Modificados

| Archivo | Descripción |
|---------|-------------|
| `/var/spool/cron/oracle` | Crontab del usuario oracle (modificado) |

**Contenido de /var/spool/cron/oracle después de instalación:**
```
# Oracle Data Guard Automation
*/10 * * * * /home/oracle/automation/check_log_transport.sh
0 1 * * * /home/oracle/automation/rman_daily_backup.sh
0 2 * * * /home/oracle/automation/delete_archives_primary.sh
```

## Dependencias

### Prerequisitos Absolutos

1. Scripts de automatización deben estar en `/home/oracle/automation/`
2. Permisos de ejecución en scripts (`chmod +x`)
3. Variables de entorno en `setEnv.sh`
4. Servicio `crond` debe estar corriendo

### Verificar Servicio Crond

```bash
# Verificar que crond está activo
systemctl status crond

# Si no está corriendo
sudo systemctl start crond
sudo systemctl enable crond
```

## Verificación

### Verificar Cron Jobs Instalados

```bash
# Como usuario oracle
crontab -l

# Debe mostrar:
# # Oracle Data Guard Automation
# */10 * * * * /home/oracle/automation/check_log_transport.sh
# 0 1 * * * /home/oracle/automation/rman_daily_backup.sh
# 0 2 * * * /home/oracle/automation/delete_archives_primary.sh
```

### Verificar Próximas Ejecuciones

```bash
# Desde host Windows (PowerShell)
vagrant ssh primary -c "sudo su - oracle -c 'crontab -l'"
```

### Probar Ejecución Manual

```bash
# Como oracle
/home/oracle/automation/check_log_transport.sh

# Ver log generado
ls -l /home/oracle/logs/automation/
tail -f /home/oracle/logs/automation/check_log_transport_*.log
```

### Verificar Que Cron Ejecutó Jobs

```bash
# Ver log de cron (como root)
sudo tail -f /var/log/cron

# Debe mostrar:
# Nov  4 14:40:01 ol8-21-dg1 CROND[12345]: (oracle) CMD (/home/oracle/automation/check_log_transport.sh)
```

### Forzar Ejecución de Backup Ahora (Para Testing)

```bash
# Ejecutar manualmente (no esperar a 1 AM)
sudo su - oracle
/home/oracle/automation/rman_daily_backup.sh

# Ver progreso
tail -f /home/oracle/logs/automation/rman_backup_$(date +%Y%m%d).log
```

## Logs de Cron Jobs

### Ubicación de Logs

```
/home/oracle/logs/automation/
├── check_log_transport_20251104.log
├── check_log_transport_20251105.log
├── rman_backup_20251104.log
├── rman_backup_20251105.log
├── delete_archives_20251104.log
└── delete_archives_20251105.log
```

### Log de Sistema (Cron Daemon)

```bash
# Ver todas las ejecuciones de cron
sudo grep CRON /var/log/cron | grep oracle

# Ejemplo de salida:
# Nov  4 14:40:01 ol8-21-dg1 CROND[12345]: (oracle) CMD (/home/oracle/automation/check_log_transport.sh)
# Nov  4 01:00:01 ol8-21-dg1 CROND[23456]: (oracle) CMD (/home/oracle/automation/rman_daily_backup.sh)
```

## Puntos de Fallo Comunes

### 1. Cron Jobs No Se Ejecutan

**Síntoma:** Logs no se generan, no hay entradas en /var/log/cron

**Causa:** Servicio crond no corriendo

**Solución:**
```bash
sudo systemctl start crond
sudo systemctl enable crond
```

### 2. Scripts Fallan con "Command Not Found"

**Error en logs:**
```
sqlplus: command not found
lsnrctl: command not found
```

**Causa:** Cron no carga setEnv.sh automáticamente

**Solución:** Scripts deben incluir:
```bash
#!/bin/bash
. /home/oracle/scripts/setEnv.sh
# ... resto del script
```

### 3. Permisos Denegados

**Error:**
```
-bash: /home/oracle/automation/check_log_transport.sh: Permission denied
```

**Solución:**
```bash
chmod +x /home/oracle/automation/*.sh
chown oracle:oinstall /home/oracle/automation/*.sh
```

### 4. Múltiples Entradas Duplicadas

**Síntoma:** Cron jobs se ejecutan múltiple veces simultáneamente

**Causa:** Script ejecutado múltiples veces sin limpiar entradas antiguas

**Solución:**
```bash
# Editar crontab manualmente
crontab -e

# Eliminar líneas duplicadas de "Oracle Data Guard Automation"
```

### 5. PATH No Incluye ORACLE_HOME/bin

**Error:**
```
rman: command not found
```

**Solución:** Cada script debe cargar setEnv.sh que exporta PATH:
```bash
. /home/oracle/scripts/setEnv.sh
export PATH=$ORACLE_HOME/bin:$PATH
```

## Importancia para Data Guard

### Monitoreo Continuo (check_log_transport.sh)

**Sin monitoreo:**
- Problemas de replicación pasan desapercibidos
- Standby se atrasa días o semanas
- RPO (Recovery Point Objective) se degrada

**Con monitoreo cada 10 minutos:**
- Detección temprana de log gaps
- Alertas automáticas (logs pueden ser parseados para enviar emails)
- RPO garantizado < 5 minutos (archive_lag_target)

### Backups Automáticos (rman_daily_backup.sh)

**Protección en capas:**
1. **Capa 1:** Data Guard (replicación sincrónica)
2. **Capa 2:** Backups diarios (recovery point-in-time)
3. **Capa 3:** Backups en standby (offsite redundancy)

**Permite:**
- Recovery después de corrupción lógica (DROP TABLE)
- Recovery punto-en-tiempo específico
- Restore completo si ambos nodos fallan

### Mantenimiento Automático (delete_archives_primary.sh)

**Sin limpieza:**
- `/u01/oradata/cdb1/arch/` crece sin límite
- Disco se llena en ~7-10 días
- Database para de funcionar (ORA-00257: archiver error)

**Con limpieza automática:**
- Archive logs se eliminan después de 3 días (ya aplicados en standby)
- Espacio en disco se mantiene estable
- Sistema funciona indefinidamente sin intervención

### Operación Desatendida 24/7

**Con estos 3 cron jobs, el sistema Data Guard es completamente autónomo:**
- ✅ Monitoreo continuo
- ✅ Backups diarios
- ✅ Mantenimiento automático
- ✅ No requiere DBA dedicado
- ✅ Funciona 24/7/365 sin intervención

**Único mantenimiento manual requerido:**
- Verificar logs semanalmente
- Probar switchover mensualmente (práctica)
- Actualizar patches trimestralmente

## Este es el ÚLTIMO PASO

**Después de este script:**
- ✅ Primary está 100% operacional
- ✅ Base de datos creada con Data Guard habilitado
- ✅ Schema healthcare desplegado
- ✅ Monitoreo automatizado configurado
- ✅ Backups automatizados configurados
- ✅ Mantenimiento automatizado configurado
- ✅ SSH configurado para transferencia de backups

**Próximo paso:** Desplegar nodo standby (vagrant up standby)

## Referencias Cruzadas

### Scripts de Automatización

- **[70 - Check Log Transport](../../scripts-automatizacion/70-check-log-transport.md)** - Monitoreo de replicación
- **[71 - RMAN Daily Backup](../../scripts-automatizacion/71-rman-daily-backup.md)** - Backups automáticos
- **[72 - Delete Archives Primary](../../scripts-automatizacion/72-delete-archives-primary.md)** - Limpieza de logs

### Scripts de Despliegue

- **[31 - Primary Root Setup](31-primary-root-setup.md)** - Orquestador que ejecuta este script
- **[39 - Setup Automation](39-setup-automation.md)** - Despliega scripts que son ejecutados por cron

### Documentación de Operaciones

- **[90 - Monitoreo Diario](../../operaciones/90-monitoreo-diario.md)** - Operaciones de monitoreo
- **[91 - Respaldos Manuales](../../operaciones/91-respaldos-manuales.md)** - Ejecución manual de backups

## Código Fuente Completo

Ver archivo: `2-Standby/automation/install_cron_jobs.sh` (77 líneas)

---

## 🎉 DESPLIEGUE PRIMARIO COMPLETADO

**El nodo primario está completamente configurado y operacional.**

**Estadísticas:**
- **Scripts ejecutados:** 16 (setup.sh → root_setup.sh → 14 scripts)
- **Tiempo total:** 35-45 minutos
- **Base de datos:** CDB + PDB con healthcare schema
- **Data Guard:** Habilitado y preparado
- **Automatización:** 3 cron jobs instalados

**Siguiente:** [50 - Standby Setup](../standby/50-standby-setup.md) - Comenzar despliegue del nodo standby para completar Data Guard.
