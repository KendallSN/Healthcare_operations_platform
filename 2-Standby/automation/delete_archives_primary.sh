#!/bin/bash
# Eliminar Archivos de Registro en Primaria Despues de Transferencia a Standby
# Se ejecuta en la base de datos PRINCIPAL
# Programado via cron: 0 2 * * * (2 AM diariamente, despues del respaldo)

. /home/oracle/scripts/setEnv.sh
. /vagrant_config/install.env

LOGFILE="/home/oracle/logs/automation/delete_archives_primary.log"

{
  echo "===================================================================="
  echo "Eliminacion de Archivos PRINCIPAL: $(date)"
  echo "===================================================================="

  # Obtener ultima secuencia aplicada en standby
  STANDBY_APPLIED=$(sqlplus -s sys/${SYS_PASSWORD}@${NODE2_DB_UNIQUE_NAME}${DB_DOMAIN_STR} as sysdba << EOF
SET PAGESIZE 0 FEEDBACK OFF HEADING OFF
SELECT MAX(sequence#) FROM v\$archived_log WHERE applied='YES' AND dest_id=1;
EXIT;
EOF
)

  echo "Ultima secuencia aplicada en standby: $STANDBY_APPLIED"

  if [ -n "$STANDBY_APPLIED" ] && [ "$STANDBY_APPLIED" != "" ]; then
    # Eliminar archivos en primaria que ya fueron aplicados en standby
    rman target / << REOF
RUN {
  # Asignar canal de mantenimiento para operaciones de eliminacion
  ALLOCATE CHANNEL FOR MAINTENANCE DEVICE TYPE DISK;
  # Eliminar archivos de log hasta la secuencia aplicada en standby
  DELETE NOPROMPT ARCHIVELOG UNTIL SEQUENCE ${STANDBY_APPLIED} THREAD 1;
  # Verificar estado de todos los archivos de log en catalogo
  CROSSCHECK ARCHIVELOG ALL;
}
EXIT;
REOF
  else
    echo "ADVERTENCIA: No se pudo determinar secuencia aplicada en standby. Omitiendo eliminacion."
  fi

  echo "===================================================================="
  echo "Eliminacion de Archivos Completada: $(date)"
  echo "===================================================================="

} >> $LOGFILE 2>&1

# Mantener registros por 30 dias
find /home/oracle/logs/automation -name "delete_archives_primary.log" -mtime +30 -delete 2>/dev/null
