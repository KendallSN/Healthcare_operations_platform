#!/bin/bash
# Manual On-Demand Backup
# Run on PRIMARY database when manual backup is needed

. /home/oracle/scripts/setEnv.sh
. /vagrant_config/install.env

BACKUP_TAG="MANUAL_BACKUP_$(date +%Y%m%d_%H%M%S)"

echo "===================================================================="
echo "Manual RMAN Backup"
echo "===================================================================="
echo "Backup tag: $BACKUP_TAG"
echo "Backup directory: $BACKUP_DIR"
echo ""

read -p "Proceed with backup? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
  echo "Backup cancelled"
  exit 0
fi

echo ""
echo "Starting backup..."

rman target / <<REOF
RUN {
  ALLOCATE CHANNEL ch1 DEVICE TYPE DISK FORMAT '${BACKUP_DIR}/${BACKUP_TAG}_%U';

  SQL 'ALTER SYSTEM ARCHIVE LOG CURRENT';

  BACKUP AS COMPRESSED BACKUPSET
    DATABASE
    PLUS ARCHIVELOG
    TAG ${BACKUP_TAG};

  BACKUP CURRENT CONTROLFILE;

  RELEASE CHANNEL ch1;
}
LIST BACKUP SUMMARY;
EXIT;
REOF

echo ""
echo "===================================================================="
echo "Manual Backup Complete"
echo "===================================================================="

read -p "Transfer to standby? (yes/no): " transfer

if [ "$transfer" = "yes" ]; then
  echo "Transferring backups..."
  rsync -avz --progress ${BACKUP_DIR}/${BACKUP_TAG}* oracle@${NODE2_FQ_HOSTNAME}:/u02/backup_from_primary/
  echo "Transfer complete"
fi
