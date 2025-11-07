#!/bin/bash
# Complete Data Guard Configuration Verification
# Run on PRIMARY database

. /home/oracle/scripts/setEnv.sh
. /vagrant_config/install.env

echo "========================================================================"
echo "DATA GUARD CONFIGURATION VERIFICATION"
echo "========================================================================"

# 1. Primary Database Status
echo ""
echo "=== PRIMARY DATABASE STATUS ==="
sqlplus -s / as sysdba <<EOF
SET LINESIZE 150
COL name FORMAT A10
COL db_unique_name FORMAT A15
COL database_role FORMAT A16
COL open_mode FORMAT A12
COL protection_mode FORMAT A20
COL protection_level FORMAT A20

SELECT name, db_unique_name, database_role, open_mode, log_mode,
       force_logging, flashback_on, protection_mode, protection_level
FROM v\$database;
EOF

# 2. Archive Destinations Status
echo ""
echo "=== ARCHIVE DESTINATIONS ==="
sqlplus -s / as sysdba <<EOF
SET LINESIZE 200
COL dest_name FORMAT A15
COL status FORMAT A10
COL destination FORMAT A40
COL error FORMAT A30

SELECT dest_name, status, destination, error
FROM v\$archive_dest
WHERE status != 'INACTIVE'
ORDER BY dest_id;
EOF

# 3. Standby Redo Logs
echo ""
echo "=== STANDBY REDO LOGS ==="
sqlplus -s / as sysdba <<EOF
COL member FORMAT A50
SELECT l.group#, l.thread#, l.sequence#, l.bytes/1024/1024 AS size_mb,
       l.archived, l.status, f.member
FROM v\$standby_log l, v\$logfile f
WHERE l.group# = f.group#
ORDER BY l.group#;
EOF

# 4. Archive Lag Configuration
echo ""
echo "=== ARCHIVE LAG TARGET ==="
sqlplus -s / as sysdba <<EOF
SHOW PARAMETER ARCHIVE_LAG_TARGET;
EOF

# 5. Log Switch History
echo ""
echo "=== RECENT LOG SWITCHES ==="
sqlplus -s / as sysdba <<EOF
SELECT sequence#, thread#, first_time, first_change#
FROM v\$log_history
WHERE first_time > SYSDATE - 1
ORDER BY sequence# DESC
FETCH FIRST 10 ROWS ONLY;
EOF

# 6. Standby Database Status
echo ""
echo "=== STANDBY DATABASE STATUS ==="
sqlplus -s sys/${SYS_PASSWORD}@${NODE2_DB_UNIQUE_NAME}${DB_DOMAIN_STR} as sysdba <<EOF
SET LINESIZE 150
SELECT name, db_unique_name, database_role, open_mode, log_mode
FROM v\$database;
EOF

# 7. Standby Apply Status
echo ""
echo "=== STANDBY APPLY STATUS ==="
sqlplus -s sys/${SYS_PASSWORD}@${NODE2_DB_UNIQUE_NAME}${DB_DOMAIN_STR} as sysdba <<EOF
SELECT process, status, thread#, sequence#, block#, blocks
FROM v\$managed_standby
WHERE process LIKE 'MRP%' OR process LIKE 'RFS%' OR process LIKE 'LNS%';
EOF

# 8. Transport and Apply Lag
echo ""
echo "=== TRANSPORT AND APPLY LAG ==="
sqlplus -s sys/${SYS_PASSWORD}@${NODE2_DB_UNIQUE_NAME}${DB_DOMAIN_STR} as sysdba <<EOF
COL name FORMAT A20
COL value FORMAT A20
COL unit FORMAT A15
COL time_computed FORMAT A20

SELECT name, value, unit, TO_CHAR(time_computed, 'YYYY-MM-DD HH24:MI:SS') AS time_computed
FROM v\$dataguard_stats
WHERE name IN ('transport lag', 'apply lag');
EOF

# 9. Archive Gap Check
echo ""
echo "=== ARCHIVE GAP CHECK ==="
sqlplus -s sys/${SYS_PASSWORD}@${NODE2_DB_UNIQUE_NAME}${DB_DOMAIN_STR} as sysdba <<EOF
SELECT * FROM v\$archive_gap;
EOF

echo ""
echo "If no rows returned, there are NO GAPS (this is good)"

# 10. Data Guard Broker Status
echo ""
echo "=== DATA GUARD BROKER CONFIGURATION ==="
dgmgrl -silent sys/${SYS_PASSWORD}@${NODE1_DB_UNIQUE_NAME}${DB_DOMAIN_STR} <<EOF
SHOW CONFIGURATION;
SHOW DATABASE ${NODE1_DB_UNIQUE_NAME};
SHOW DATABASE ${NODE2_DB_UNIQUE_NAME};
EXIT;
EOF

# 11. Custom Schema Verification
echo ""
echo "=== CUSTOM SCHEMA VERIFICATION (in PDB) ==="
sqlplus -s / as sysdba <<EOF
ALTER SESSION SET CONTAINER=${PDB_NAME};
SET LINESIZE 150
COL owner FORMAT A15
COL table_name FORMAT A30
SELECT owner, table_name, num_rows
FROM dba_tables
WHERE owner NOT IN ('SYS','SYSTEM','OUTLN','DBSNMP','APPQOSSYS',
                     'DBSFWUSER','GGSYS','ANONYMOUS','CTXSYS','DVSYS',
                     'DVF','GSMADMIN_INTERNAL','LBACSYS','MDSYS',
                     'OJVMSYS','OLAPSYS','ORDDATA','ORDSYS','WMSYS',
                     'XDB','AUDSYS','ORDPLUGINS','SI_INFORMTN_SCHEMA')
ORDER BY owner, table_name;
EOF

echo ""
echo "========================================================================"
echo "VERIFICATION COMPLETE"
echo "========================================================================"
