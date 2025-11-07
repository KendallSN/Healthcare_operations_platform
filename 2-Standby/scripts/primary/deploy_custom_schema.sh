#!/bin/bash
# Deploy custom database schema from ScriptProyectoBD.SQL to PDB

. /vagrant_config/install.env
. /home/oracle/scripts/setEnv.sh

echo "******************************************************************************"
echo "Deploy custom schema to ${PDB_NAME}." `date`
echo "******************************************************************************"

# Check if script exists
if [ ! -f "/vagrant/1-BD/ScriptProyectoBD.SQL" ]; then
  echo "ERROR: ScriptProyectoBD.SQL not found!"
  exit 1
fi

# Open PDB if not already open
sqlplus / as sysdba <<EOF
ALTER PLUGGABLE DATABASE ${PDB_NAME} OPEN;
EXIT;
EOF

# Create application schema user and tablespace in PDB using SQL script
echo "******************************************************************************"
echo "Create application schema user ${APP_SCHEMA} in ${PDB_NAME} using ${APP_SCHEMA_SQL}..." `date`
echo "******************************************************************************"

# Check if schema creation SQL script exists
if [ ! -f "/vagrant/1-BD/${APP_SCHEMA_SQL}" ]; then
  echo "ERROR: ${APP_SCHEMA_SQL} not found in /vagrant/1-BD/!"
  exit 1
fi

# Preprocess the SQL script to fix paths and passwords
echo "Preprocessing ${APP_SCHEMA_SQL} to fix datafile paths and password substitution..."

TEMP_SQL="/tmp/${APP_SCHEMA_SQL}.processed"

# Read the SQL file and make substitutions:
# 1. Replace hardcoded 'password' with actual password from config
# 2. Fix datafile paths: /opt/oracle/oradata/ -> /u01/oradata/CDB1/pdb1/
# 3. Comment out Administrator role grant (role doesn't exist in Oracle 21c)
sed -e "s/identified by password/identified by ${APP_SCHEMA_PASSWORD}/g" \
    -e "s|/opt/oracle/oradata/|${DATA_DIR}/${ORACLE_SID^^}/${PDB_NAME}/|g" \
    -e "s/^GRANT Administrator/-- GRANT Administrator (role does not exist) --/" \
    "/vagrant/1-BD/${APP_SCHEMA_SQL}" > "${TEMP_SQL}"

echo "Preprocessed SQL saved to ${TEMP_SQL}"
echo "Changes applied:"
echo "  - Password: 'password' -> '${APP_SCHEMA_PASSWORD}'"
echo "  - Datafile path: /opt/oracle/oradata/ -> ${DATA_DIR}/${ORACLE_SID^^}/${PDB_NAME}/"
echo "  - Administrator role grant: commented out (role does not exist in Oracle 21c)"

# Execute the preprocessed SQL with error handling
sqlplus -S / as sysdba <<EOF
WHENEVER SQLERROR EXIT SQL.SQLCODE
-- Connect to the PDB
ALTER SESSION SET CONTAINER=${PDB_NAME};

-- Execute the preprocessed schema creation script
@${TEMP_SQL}

EXIT;
EOF

SQL_EXIT_CODE=$?
if [ ${SQL_EXIT_CODE} -ne 0 ]; then
  echo "ERROR: Schema creation failed with exit code ${SQL_EXIT_CODE}"
  echo "Check the SQL output above for errors"
  exit ${SQL_EXIT_CODE}
fi

echo "Schema user ${APP_SCHEMA} and tablespace HC_TS created successfully"

# Verify HC_TS tablespace was created
echo "Verifying HC_TS tablespace creation..."
sqlplus -S / as sysdba <<EOF
SET HEADING OFF
SET FEEDBACK OFF
ALTER SESSION SET CONTAINER=${PDB_NAME};
SELECT 'HC_TS tablespace: ' || tablespace_name || ' at ' || file_name
FROM dba_data_files
WHERE tablespace_name = 'HC_TS';
EXIT;
EOF

# Clean up temporary file
rm -f "${TEMP_SQL}"

# Deploy the schema to the PDB
echo "******************************************************************************"
echo "Executing ScriptProyectoBD.SQL as ${APP_SCHEMA}..." `date`
echo "******************************************************************************"

sqlplus -S / as sysdba <<EOF
WHENEVER SQLERROR EXIT SQL.SQLCODE
-- Connect to the PDB and set current schema
ALTER SESSION SET CONTAINER=${PDB_NAME};
ALTER SESSION SET CURRENT_SCHEMA=${APP_SCHEMA};

-- Execute the custom schema script
@/vagrant/1-BD/ScriptProyectoBD.SQL

-- Verify tables were created
SET LINESIZE 150
SET PAGESIZE 100
COL table_name FORMAT A30
COL num_rows FORMAT 999,999,999

SELECT table_name, num_rows
FROM user_tables
ORDER BY table_name;

EXIT;
EOF

SQL_EXIT_CODE=$?
if [ ${SQL_EXIT_CODE} -ne 0 ]; then
  echo "ERROR: ScriptProyectoBD.SQL execution failed with exit code ${SQL_EXIT_CODE}"
  echo "Check the SQL output above for errors"
  exit ${SQL_EXIT_CODE}
fi

echo "ScriptProyectoBD.SQL executed successfully"

echo "******************************************************************************"
echo "Verify sequences were created..." `date`
echo "******************************************************************************"

sqlplus / as sysdba <<EOF
-- Connect to the PDB and set current schema
ALTER SESSION SET CONTAINER=${PDB_NAME};
ALTER SESSION SET CURRENT_SCHEMA=${APP_SCHEMA};

SET LINESIZE 150
SET PAGESIZE 100
COL sequence_name FORMAT A30

SELECT sequence_name, min_value, max_value, increment_by, last_number
FROM user_sequences
ORDER BY sequence_name;

EXIT;
EOF

# Force log switch to ensure replication to standby
echo "******************************************************************************"
echo "Force log archive to ensure replication." `date`
echo "******************************************************************************"

sqlplus / as sysdba <<EOF
ALTER SYSTEM ARCHIVE LOG CURRENT;
EXIT;
EOF

echo "******************************************************************************"
echo "Custom schema deployment complete." `date`
echo "******************************************************************************"
echo ""
echo "Schema has been deployed to ${PDB_NAME} and will be automatically"
echo "replicated to the standby database when it is created."
