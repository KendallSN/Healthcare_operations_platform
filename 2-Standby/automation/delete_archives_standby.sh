#!/bin/bash
# Delete Applied Archives on Standby Older Than 3 Days
# Run on STANDBY database
# Scheduled via cron: 0 23 * * * (11 PM daily)

. /home/oracle/scripts/setEnv.sh
. /vagrant_config/install.env

LOGFILE="/home/oracle/logs/automation/delete_archives_standby.log"

{
  echo "===================================================================="
  echo "Archive Deletion STANDBY: $(date)"
  echo "===================================================================="

  # Get max applied sequence older than configured retention days
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

  echo "Max applied sequence older than ${ARCHIVE_RETENTION_DAYS} days: $MAX_OLD_SEQ"

  if [ -n "$MAX_OLD_SEQ" ] && [ "$MAX_OLD_SEQ" != "" ]; then
    rman target / << REOF
RUN {
  DELETE NOPROMPT ARCHIVELOG UNTIL SEQUENCE ${MAX_OLD_SEQ} THREAD 1;
  CROSSCHECK ARCHIVELOG ALL;
}
EXIT;
REOF
  else
    echo "No archives older than ${ARCHIVE_RETENTION_DAYS} days to delete."
  fi

  echo "===================================================================="
  echo "Archive Deletion Complete: $(date)"
  echo "===================================================================="

} >> $LOGFILE 2>&1

# Keep logs for 30 days
find /home/oracle/logs/automation -name "delete_archives_standby.log" -mtime +30 -delete 2>/dev/null
