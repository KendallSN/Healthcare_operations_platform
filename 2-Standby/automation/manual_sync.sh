#!/bin/bash
# Manual Log Synchronization
# Run on PRIMARY database when manual sync is needed

. /home/oracle/scripts/setEnv.sh
. /vagrant_config/install.env

echo "===================================================================="
echo "Manual Log Archive and Sync"
echo "===================================================================="

# Force log switch and archive on primary
sqlplus / as sysdba <<EOF
-- Synchronous command - waits for archiving to complete
ALTER SYSTEM ARCHIVE LOG CURRENT;

-- Verify latest sequence
SELECT MAX(sequence#) AS latest_seq FROM v\$archived_log WHERE dest_id=2;
EXIT;
EOF

echo ""
echo "===================================================================="
echo "Check standby for sync status"
echo "===================================================================="

sqlplus sys/${SYS_PASSWORD}@${NODE2_DB_UNIQUE_NAME}${DB_DOMAIN_STR} as sysdba <<EOF
SET LINESIZE 150
COL name FORMAT A30
COL value FORMAT A30
SELECT name, value, unit FROM v\$dataguard_stats WHERE name IN ('transport lag','apply lag');
EXIT;
EOF

echo ""
echo "===================================================================="
echo "Sync Complete"
echo "===================================================================="
