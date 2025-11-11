#!/bin/bash
# Respaldo Manual Bajo Demanda
# Se ejecuta en la base de datos PRINCIPAL cuando se necesita un respaldo manual

. /home/oracle/scripts/setEnv.sh
. /vagrant_config/install.env

BACKUP_TAG="MANUAL_BACKUP_$(date +%Y%m%d_%H%M%S)"

echo "===================================================================="
echo "Respaldo Manual RMAN"
echo "===================================================================="
echo "Etiqueta del respaldo: $BACKUP_TAG"
echo "Directorio de respaldo: $BACKUP_DIR"
echo ""

read -p "Proceder con el respaldo? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
  echo "Respaldo cancelado"
  exit 0
fi

echo ""
echo "Iniciando respaldo..."

rman target / <<REOF
RUN {
  # Asignar canal para respaldo
  ALLOCATE CHANNEL ch1 DEVICE TYPE DISK FORMAT '${BACKUP_DIR}/${BACKUP_TAG}_%U';

  # Forzar archivado del log actual antes del respaldo
  SQL 'ALTER SYSTEM ARCHIVE LOG CURRENT';

  # Respaldo completo comprimido de base de datos con archivos de log
  BACKUP AS COMPRESSED BACKUPSET
    DATABASE
    PLUS ARCHIVELOG
    TAG ${BACKUP_TAG};

  # Respaldar archivo de control actual
  BACKUP CURRENT CONTROLFILE;

  # Liberar canal de respaldo
  RELEASE CHANNEL ch1;
}
# Mostrar resumen de respaldos existentes
LIST BACKUP SUMMARY;
EXIT;
REOF

echo ""
echo "===================================================================="
echo "Respaldo Manual Completado"
echo "===================================================================="

read -p "Transferir a standby? (yes/no): " transfer

if [ "$transfer" = "yes" ]; then
  echo "Transfiriendo respaldos..."
  rsync -avz --progress ${BACKUP_DIR}/${BACKUP_TAG}* oracle@${NODE2_FQ_HOSTNAME}:/u02/backup_from_primary/
  echo "Transferencia completada"
fi
