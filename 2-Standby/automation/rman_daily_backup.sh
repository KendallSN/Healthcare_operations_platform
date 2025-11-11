#!/bin/bash
# Respaldo Diario con RMAN y Transferencia a Standby
# Se ejecuta en la base de datos PRINCIPAL
# Programado via cron: 0 1 * * * (1 AM diariamente)

. /home/oracle/scripts/setEnv.sh
. /vagrant_config/install.env

BACKUP_TAG="DAILY_BACKUP_$(date +%Y%m%d)"
LOGFILE="/home/oracle/logs/automation/rman_backup_$(date +%Y%m%d).log"

{
  echo "===================================================================="
  echo "Respaldo Diario RMAN Iniciado: $(date)"
  echo "===================================================================="

  # Configurar politicas de retencion y respaldo de RMAN
  rman target / << REOF
# Configurar ventana de recuperacion (cuantos dias de respaldos mantener)
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF ${BACKUP_RETENTION_DAYS} DAYS;
# Habilitar respaldo automatico del archivo de control
CONFIGURE CONTROLFILE AUTOBACKUP ON;
# Formato del respaldo automatico del archivo de control
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '${BACKUP_DIR}/cf_%F';
# Configurar paralelismo de respaldo (2 canales para mayor velocidad)
CONFIGURE DEVICE TYPE DISK PARALLELISM 2;
# Politica de eliminacion de archivos: solo eliminar cuando se apliquen en standby
CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;

RUN {
  # Asignar dos canales para respaldo paralelo
  ALLOCATE CHANNEL ch1 DEVICE TYPE DISK FORMAT '${BACKUP_DIR}/${BACKUP_TAG}_%U';
  ALLOCATE CHANNEL ch2 DEVICE TYPE DISK FORMAT '${BACKUP_DIR}/${BACKUP_TAG}_%U';

  # Forzar archivado del log actual antes del respaldo
  SQL 'ALTER SYSTEM ARCHIVE LOG CURRENT';

  # Respaldo completo de base de datos con compresion incluyendo archivos de log
  BACKUP AS COMPRESSED BACKUPSET
    DATABASE
    PLUS ARCHIVELOG
    TAG ${BACKUP_TAG};

  # Respaldar archivo de control actual
  BACKUP CURRENT CONTROLFILE
    FORMAT '${BACKUP_DIR}/control_${BACKUP_TAG}_%U';

  # Respaldar archivo de parametros del servidor (SPFILE)
  BACKUP SPFILE
    FORMAT '${BACKUP_DIR}/spfile_${BACKUP_TAG}_%U';

  # Eliminar respaldos obsoletos segun politica de retencion
  DELETE NOPROMPT OBSOLETE;

  # Liberar canales de respaldo
  RELEASE CHANNEL ch1;
  RELEASE CHANNEL ch2;
}

EXIT;
REOF

  echo ""
  echo "===================================================================="
  echo "Respaldo RMAN Completado: $(date)"
  echo "===================================================================="

  # Transferir archivos de respaldo a servidor standby
  echo ""
  echo "===================================================================="
  echo "Transfiriendo respaldos a servidor standby..."
  echo "===================================================================="

  rsync -avz --progress ${BACKUP_DIR}/ oracle@${NODE2_FQ_HOSTNAME}:/u02/backup_from_primary/

  if [ $? -eq 0 ]; then
    echo "===================================================================="
    echo "Transferencia de respaldo completada exitosamente: $(date)"
    echo "===================================================================="
  else
    echo "===================================================================="
    echo "ERROR: Fallo en la transferencia del respaldo!"
    echo "===================================================================="
    # Se podria enviar alerta por correo aqui si esta configurado
  fi

} >> $LOGFILE 2>&1

# Mantener registros de respaldo por 30 dias
find /home/oracle/logs/automation/rman_backup_*.log -mtime +30 -delete 2>/dev/null

echo "Registro del respaldo: $LOGFILE"
