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

# Create application schema user in PDB
echo "******************************************************************************"
echo "Create application schema user ${APP_SCHEMA} in ${PDB_NAME}..." `date`
echo "******************************************************************************"

sqlplus / as sysdba <<EOF
-- Connect to the PDB
ALTER SESSION SET CONTAINER=${PDB_NAME};

-- Drop user if exists (for re-deployments)
BEGIN
  EXECUTE IMMEDIATE 'DROP USER ${APP_SCHEMA} CASCADE';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -1918 THEN
      RAISE;
    END IF;
END;
/

-- Create application schema user
CREATE USER ${APP_SCHEMA} IDENTIFIED BY "${APP_SCHEMA_PASSWORD}"
  DEFAULT TABLESPACE USERS
  TEMPORARY TABLESPACE TEMP
  QUOTA UNLIMITED ON USERS;

-- Grant necessary privileges
GRANT CONNECT, RESOURCE TO ${APP_SCHEMA};
GRANT CREATE TABLE TO ${APP_SCHEMA};
GRANT CREATE SEQUENCE TO ${APP_SCHEMA};
GRANT CREATE TRIGGER TO ${APP_SCHEMA};
GRANT CREATE VIEW TO ${APP_SCHEMA};
GRANT CREATE PROCEDURE TO ${APP_SCHEMA};

EXIT;
EOF

# Deploy the schema to the PDB
echo "******************************************************************************"
echo "Executing ScriptProyectoBD.SQL as ${APP_SCHEMA}..." `date`
echo "******************************************************************************"

sqlplus / as sysdba <<EOF
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
