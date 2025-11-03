#!/bin/bash
# Daily RMAN Backup with Transfer to Standby
# Run on PRIMARY database
# Scheduled via cron: 0 1 * * * (1 AM daily)

. /home/oracle/scripts/setEnv.sh
. /vagrant_config/install.env

BACKUP_TAG="DAILY_BACKUP_$(date +%Y%m%d)"
LOGFILE="/home/oracle/logs/automation/rman_backup_$(date +%Y%m%d).log"

{
  echo "===================================================================="
  echo "RMAN Daily Backup Started: $(date)"
  echo "===================================================================="

  # Configure RMAN retention and policies
  rman target / << REOF
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF ${BACKUP_RETENTION_DAYS} DAYS;
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '${BACKUP_DIR}/cf_%F';
CONFIGURE DEVICE TYPE DISK PARALLELISM 2;
CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;

RUN {
  ALLOCATE CHANNEL ch1 DEVICE TYPE DISK FORMAT '${BACKUP_DIR}/${BACKUP_TAG}_%U';
  ALLOCATE CHANNEL ch2 DEVICE TYPE DISK FORMAT '${BACKUP_DIR}/${BACKUP_TAG}_%U';

  # Force log archive before backup
  SQL 'ALTER SYSTEM ARCHIVE LOG CURRENT';

  # Full database backup with compressed backupsets
  BACKUP AS COMPRESSED BACKUPSET
    DATABASE
    PLUS ARCHIVELOG
    TAG ${BACKUP_TAG};

  # Backup current controlfile
  BACKUP CURRENT CONTROLFILE
    FORMAT '${BACKUP_DIR}/control_${BACKUP_TAG}_%U';

  # Backup SPFILE
  BACKUP SPFILE
    FORMAT '${BACKUP_DIR}/spfile_${BACKUP_TAG}_%U';

  # Delete obsolete backups
  DELETE NOPROMPT OBSOLETE;

  RELEASE CHANNEL ch1;
  RELEASE CHANNEL ch2;
}

EXIT;
REOF

  echo ""
  echo "===================================================================="
  echo "RMAN Backup Completed: $(date)"
  echo "===================================================================="

  # Transfer backup files to standby
  echo ""
  echo "===================================================================="
  echo "Transferring backups to standby server..."
  echo "===================================================================="

  rsync -avz --progress ${BACKUP_DIR}/ oracle@${NODE2_FQ_HOSTNAME}:/u02/backup_from_primary/

  if [ $? -eq 0 ]; then
    echo "===================================================================="
    echo "Backup transfer completed successfully: $(date)"
    echo "===================================================================="
  else
    echo "===================================================================="
    echo "ERROR: Backup transfer failed!"
    echo "===================================================================="
    # Could send email alert here if mail is configured
  fi

} >> $LOGFILE 2>&1

# Keep backup logs for 30 days
find /home/oracle/logs/automation/rman_backup_*.log -mtime +30 -delete 2>/dev/null

echo "Backup log: $LOGFILE"
