#!/bin/bash
# Instalar tareas programadas para automatización
# Ejecutar como usuario oracle

. /home/oracle/scripts/setEnv.sh
. /vagrant_config/install.env

# Determinar si esto es primario o en espera basándose en el nombre de host
CURRENT_HOST=$(hostname -f)

echo "===================================================================="
echo "Instalando tareas programadas para automatización"
echo "Host actual: $CURRENT_HOST"
echo "===================================================================="

# Crear archivo cron temporal
CRON_FILE="/tmp/oracle_cron_$$"

# Obtener crontab existente
crontab -l > $CRON_FILE 2>/dev/null || touch $CRON_FILE

# Eliminar entradas de automatización antiguas
sed -i '/# Oracle Data Guard Automation/d' $CRON_FILE
sed -i '/check_log_transport.sh/d' $CRON_FILE
sed -i '/rman_daily_backup.sh/d' $CRON_FILE
sed -i '/delete_archives/d' $CRON_FILE

echo ""
echo "Agregando tareas programadas de automatización..."

# Agregar encabezado
echo "" >> $CRON_FILE
echo "# Oracle Data Guard Automation" >> $CRON_FILE

if [ "$CURRENT_HOST" == "$NODE1_FQ_HOSTNAME" ]; then
  echo "Configurando tareas programadas del PRIMARIO..."

  # Verificación de transporte de registro cada 10 minutos
  echo "${LOG_TRANSPORT_CHECK_INTERVAL} /home/oracle/automation/check_log_transport.sh" >> $CRON_FILE

  # Respaldo diario a la hora configurada (default: 1 AM)
  echo "${BACKUP_TIME} /home/oracle/automation/rman_daily_backup.sh" >> $CRON_FILE

  # Limpieza de archivos en primario (2 AM, después del respaldo)
  echo "0 2 * * * /home/oracle/automation/delete_archives_primary.sh" >> $CRON_FILE

elif [ "$CURRENT_HOST" == "$NODE2_FQ_HOSTNAME" ]; then
  echo "Configurando tareas programadas del SERVIDOR EN ESPERA..."

  # Limpieza de archivos en standby (default: 11 PM)
  echo "${ARCHIVE_CLEANUP_TIME} /home/oracle/automation/delete_archives_standby.sh" >> $CRON_FILE

else
  echo "ERROR: ¡No se puede determinar si esto es primario o en espera!"
  echo "Nombre de host actual: $CURRENT_HOST"
  echo "Esperado: $NODE1_FQ_HOSTNAME o $NODE2_FQ_HOSTNAME"
  rm -f $CRON_FILE
  exit 1
fi

# Instalar crontab
crontab $CRON_FILE

# Limpiar
rm -f $CRON_FILE

echo ""
echo "===================================================================="
echo "Tareas programadas instaladas:"
echo "===================================================================="
crontab -l | grep -A 10 "Oracle Data Guard Automation"

echo ""
echo "===================================================================="
echo "¡Instalación de tareas programadas completada!"
echo "===================================================================="
