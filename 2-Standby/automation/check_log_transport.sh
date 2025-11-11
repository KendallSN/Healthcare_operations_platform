#!/bin/bash
# Verificador del Estado de Transporte de Logs
# Ejecutar en la base de datos PRIMARY
# Programado vía cron: */10 * * * * (cada 10 minutos)

. /home/oracle/scripts/setEnv.sh
. /vagrant_config/install.env

LOGFILE="/home/oracle/logs/automation/log_transport.log"

{
  echo "===================================================================="
  echo "Verificación de Transporte de Logs: $(date)"
  echo "===================================================================="

  # Verificar en primary - última secuencia archivada
  # Consulta v$archived_log con dest_id=1 (destino local) para obtener el último log archivado
  PRIMARY_SEQ=$(sqlplus -s / as sysdba << EOF
SET PAGESIZE 0 FEEDBACK OFF HEADING OFF
SELECT MAX(sequence#) FROM v\$archived_log WHERE dest_id=1 AND archived='YES';
EXIT;
EOF
)

  # Verificar en standby - última secuencia aplicada
  # Consulta v$archived_log en el standby para obtener el último log aplicado
  STANDBY_SEQ=$(sqlplus -s sys/${SYS_PASSWORD}@${NODE2_DB_UNIQUE_NAME}${DB_DOMAIN_STR} as sysdba << EOF
SET PAGESIZE 0 FEEDBACK OFF HEADING OFF
SELECT MAX(sequence#) FROM v\$archived_log WHERE dest_id=1 AND applied='YES';
EXIT;
EOF
)

  # Calcular brecha entre primary y standby
  GAP=$((PRIMARY_SEQ - STANDBY_SEQ))

  echo "Último archivado en primary: $PRIMARY_SEQ"
  echo "Último aplicado en standby: $STANDBY_SEQ"
  echo "Brecha actual: $GAP secuencias"

  # Verificar retraso de aplicación
  # Consulta v$dataguard_stats para obtener el tiempo de retraso en la aplicación de logs
  APPLY_LAG=$(sqlplus -s sys/${SYS_PASSWORD}@${NODE2_DB_UNIQUE_NAME}${DB_DOMAIN_STR} as sysdba << EOF
SET PAGESIZE 0 FEEDBACK OFF HEADING OFF
SELECT value FROM v\$dataguard_stats WHERE name='apply lag';
EXIT;
EOF
)

  echo "Retraso de aplicación: $APPLY_LAG"

  # Alertar si la brecha excede el umbral
  if [ $GAP -gt ${LOG_GAP_ALERT_THRESHOLD} ]; then
    echo "ADVERTENCIA: ¡La brecha excede ${LOG_GAP_ALERT_THRESHOLD} secuencias!"
    # Aquí se podría enviar una alerta por correo
  fi

  echo "===================================================================="

} >> $LOGFILE 2>&1

# Mantener solo las últimas 1000 líneas del log para evitar crecimiento excesivo
tail -1000 $LOGFILE > ${LOGFILE}.tmp && mv ${LOGFILE}.tmp $LOGFILE
