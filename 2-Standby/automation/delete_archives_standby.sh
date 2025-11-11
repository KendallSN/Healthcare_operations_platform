#!/bin/bash
# Eliminar Archivos de Registro Aplicados en Standby con Mas de 3 Dias
# Se ejecuta en la base de datos STANDBY
# Programado via cron: 0 23 * * * (11 PM diariamente)

. /home/oracle/scripts/setEnv.sh
. /vagrant_config/install.env

LOGFILE="/home/oracle/logs/automation/delete_archives_standby.log"

{
  echo "===================================================================="
  echo "Eliminacion de Archivos STANDBY: $(date)"
  echo "===================================================================="

  # Obtener maxima secuencia aplicada mas antigua que los dias de retencion configurados
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

  echo "Maxima secuencia aplicada con mas de ${ARCHIVE_RETENTION_DAYS} dias: $MAX_OLD_SEQ"

  if [ -n "$MAX_OLD_SEQ" ] && [ "$MAX_OLD_SEQ" != "" ]; then
    rman target / << REOF
RUN {
  # Eliminar archivos de log hasta la secuencia antigua determinada
  DELETE NOPROMPT ARCHIVELOG UNTIL SEQUENCE ${MAX_OLD_SEQ} THREAD 1;
  # Verificar estado de todos los archivos de log en catalogo
  CROSSCHECK ARCHIVELOG ALL;
}
EXIT;
REOF
  else
    echo "No hay archivos con mas de ${ARCHIVE_RETENTION_DAYS} dias para eliminar."
  fi

  echo "===================================================================="
  echo "Eliminacion de Archivos Completada: $(date)"
  echo "===================================================================="

} >> $LOGFILE 2>&1

# Mantener registros por 30 dias
find /home/oracle/logs/automation -name "delete_archives_standby.log" -mtime +30 -delete 2>/dev/null
