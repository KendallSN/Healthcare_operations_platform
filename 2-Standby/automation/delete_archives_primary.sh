#!/bin/bash
# Delete Archives on Primary After Transfer to Standby
# Run on PRIMARY database
# Scheduled via cron: 0 2 * * * (2 AM daily, after backup)

. /home/oracle/scripts/setEnv.sh
. /vagrant_config/install.env

LOGFILE="/home/oracle/logs/automation/delete_archives_primary.log"

{
  echo "===================================================================="
  echo "Archive Deletion PRIMARY: $(date)"
  echo "===================================================================="

  # Get last applied sequence on standby
  STANDBY_APPLIED=$(sqlplus -s sys/${SYS_PASSWORD}@${NODE2_DB_UNIQUE_NAME}${DB_DOMAIN_STR} as sysdba << EOF
SET PAGESIZE 0 FEEDBACK OFF HEADING OFF
SELECT MAX(sequence#) FROM v\$archived_log WHERE applied='YES' AND dest_id=1;
EXIT;
EOF
)

  echo "Standby last applied sequence: $STANDBY_APPLIED"

  if [ -n "$STANDBY_APPLIED" ] && [ "$STANDBY_APPLIED" != "" ]; then
    # Delete archives on primary that have been applied on standby
    rman target / << REOF
RUN {
  ALLOCATE CHANNEL FOR MAINTENANCE DEVICE TYPE DISK;
  DELETE NOPROMPT ARCHIVELOG UNTIL SEQUENCE ${STANDBY_APPLIED} THREAD 1;
  CROSSCHECK ARCHIVELOG ALL;
}
EXIT;
REOF
  else
    echo "WARNING: Could not determine standby applied sequence. Skipping deletion."
  fi

  echo "===================================================================="
  echo "Archive Deletion Complete: $(date)"
  echo "===================================================================="

} >> $LOGFILE 2>&1

# Keep logs for 30 days
find /home/oracle/logs/automation -name "delete_archives_primary.log" -mtime +30 -delete 2>/dev/null
