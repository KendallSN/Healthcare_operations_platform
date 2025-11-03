#!/bin/bash
# Log Transport Status Checker
# Run on PRIMARY database
# Scheduled via cron: */10 * * * * (every 10 minutes)

. /home/oracle/scripts/setEnv.sh
. /vagrant_config/install.env

LOGFILE="/home/oracle/logs/automation/log_transport.log"

{
  echo "===================================================================="
  echo "Log Transport Check: $(date)"
  echo "===================================================================="

  # Check on primary - last archived sequence
  PRIMARY_SEQ=$(sqlplus -s / as sysdba << EOF
SET PAGESIZE 0 FEEDBACK OFF HEADING OFF
SELECT MAX(sequence#) FROM v\$archived_log WHERE dest_id=1 AND archived='YES';
EXIT;
EOF
)

  # Check on standby - last applied sequence
  STANDBY_SEQ=$(sqlplus -s sys/${SYS_PASSWORD}@${NODE2_DB_UNIQUE_NAME}${DB_DOMAIN_STR} as sysdba << EOF
SET PAGESIZE 0 FEEDBACK OFF HEADING OFF
SELECT MAX(sequence#) FROM v\$archived_log WHERE dest_id=1 AND applied='YES';
EXIT;
EOF
)

  # Calculate gap
  GAP=$((PRIMARY_SEQ - STANDBY_SEQ))

  echo "Primary last archived: $PRIMARY_SEQ"
  echo "Standby last applied: $STANDBY_SEQ"
  echo "Current gap: $GAP sequences"

  # Check apply lag
  APPLY_LAG=$(sqlplus -s sys/${SYS_PASSWORD}@${NODE2_DB_UNIQUE_NAME}${DB_DOMAIN_STR} as sysdba << EOF
SET PAGESIZE 0 FEEDBACK OFF HEADING OFF
SELECT value FROM v\$dataguard_stats WHERE name='apply lag';
EXIT;
EOF
)

  echo "Apply lag: $APPLY_LAG"

  # Alert if gap exceeds threshold
  if [ $GAP -gt ${LOG_GAP_ALERT_THRESHOLD} ]; then
    echo "WARNING: Gap exceeds ${LOG_GAP_ALERT_THRESHOLD} sequences!"
    # Could send email alert here
  fi

  echo "===================================================================="

} >> $LOGFILE 2>&1

# Keep only last 1000 lines of log
tail -1000 $LOGFILE > ${LOGFILE}.tmp && mv ${LOGFILE}.tmp $LOGFILE
