#!/bin/bash
# Deploy simple test schema for Data Guard replication testing
# This script creates a minimal schema to verify Data Guard functionality
# without dependencies on complex application schemas

. /vagrant_config/install.env
. /home/oracle/scripts/setEnv.sh

echo "******************************************************************************"
echo "Deploy simple test schema to ${PDB_NAME}." `date`
echo "******************************************************************************"

# Define schema directory and files (all within 2-Standby)
SCHEMA_DIR="/vagrant/2-Standby/schema"
USER_SQL="${SCHEMA_DIR}/create_user.sql"
SCHEMA_SQL="${SCHEMA_DIR}/simple_schema.sql"

# Verify schema files exist
if [ ! -f "${USER_SQL}" ]; then
  echo "ERROR: User creation script not found: ${USER_SQL}"
  exit 1
fi

if [ ! -f "${SCHEMA_SQL}" ]; then
  echo "ERROR: Schema script not found: ${SCHEMA_SQL}"
  exit 1
fi

echo "Schema files verified:"
echo "  User script:   ${USER_SQL}"
echo "  Schema script: ${SCHEMA_SQL}"

# Open PDB if not already open
sqlplus / as sysdba <<EOF
ALTER PLUGGABLE DATABASE ${PDB_NAME} OPEN;
EXIT;
EOF

# ============================================================================
# Step 1: Create test user
# ============================================================================
echo "******************************************************************************"
echo "Create test user ${APP_SCHEMA} in ${PDB_NAME}..." `date`
echo "******************************************************************************"

# Preprocess user creation script to substitute password
TEMP_USER_SQL="/tmp/create_user_$$.sql"

# Replace 'password' placeholder with actual password from config
sed "s/identified by password/identified by ${APP_SCHEMA_PASSWORD}/g" \
    "${USER_SQL}" > "${TEMP_USER_SQL}"

echo "Creating user with default USERS tablespace..."

# Execute user creation script
sqlplus -S / as sysdba <<EOF
WHENEVER SQLERROR EXIT SQL.SQLCODE
-- Connect to the PDB
ALTER SESSION SET CONTAINER=${PDB_NAME};

-- Execute user creation
@${TEMP_USER_SQL}

EXIT;
EOF

SQL_EXIT_CODE=$?
if [ ${SQL_EXIT_CODE} -ne 0 ]; then
  echo "ERROR: User creation failed with exit code ${SQL_EXIT_CODE}"
  rm -f "${TEMP_USER_SQL}"
  exit ${SQL_EXIT_CODE}
fi

echo "User ${APP_SCHEMA} created successfully with default tablespace"

# Clean up temporary file
rm -f "${TEMP_USER_SQL}"

# Verify user was created
echo "Verifying user creation..."
sqlplus -S / as sysdba <<EOF
SET HEADING OFF
SET FEEDBACK OFF
ALTER SESSION SET CONTAINER=${PDB_NAME};

SELECT 'User: ' || username || ' (Default Tablespace: ' || default_tablespace || ')'
FROM dba_users
WHERE username = UPPER('${APP_SCHEMA}');

EXIT;
EOF

# ============================================================================
# Step 2: Deploy simple schema
# ============================================================================
echo "******************************************************************************"
echo "Deploying simple schema as ${APP_SCHEMA}..." `date`
echo "******************************************************************************"

sqlplus -S / as sysdba <<EOF
WHENEVER SQLERROR EXIT SQL.SQLCODE
-- Connect to the PDB and set current schema
ALTER SESSION SET CONTAINER=${PDB_NAME};
ALTER SESSION SET CURRENT_SCHEMA=${APP_SCHEMA};

-- Execute the simple schema script
@${SCHEMA_SQL}

EXIT;
EOF

SQL_EXIT_CODE=$?
if [ ${SQL_EXIT_CODE} -ne 0 ]; then
  echo "ERROR: Schema deployment failed with exit code ${SQL_EXIT_CODE}"
  exit ${SQL_EXIT_CODE}
fi

echo "Simple schema deployed successfully"

# ============================================================================
# Step 3: Verify deployment
# ============================================================================
echo "******************************************************************************"
echo "Verify schema objects..." `date`
echo "******************************************************************************"

sqlplus / as sysdba <<EOF
ALTER SESSION SET CONTAINER=${PDB_NAME};
ALTER SESSION SET CURRENT_SCHEMA=${APP_SCHEMA};

SET LINESIZE 150
SET PAGESIZE 100

-- Display tables
PROMPT
PROMPT Tables:
COL table_name FORMAT A30
SELECT table_name, num_rows
FROM user_tables
ORDER BY table_name;

-- Display sequences
PROMPT
PROMPT Sequences:
COL sequence_name FORMAT A30
SELECT sequence_name, last_number
FROM user_sequences
ORDER BY sequence_name;

-- Display procedures
PROMPT
PROMPT Procedures:
COL object_name FORMAT A30
SELECT object_name, object_type, status
FROM user_objects
WHERE object_type IN ('PROCEDURE', 'TRIGGER')
ORDER BY object_type, object_name;

EXIT;
EOF

# ============================================================================
# Step 4: Force log switch for replication
# ============================================================================
echo "******************************************************************************"
echo "Force log archive to ensure replication." `date`
echo "******************************************************************************"

sqlplus / as sysdba <<EOF
ALTER SYSTEM ARCHIVE LOG CURRENT;
EXIT;
EOF

echo "******************************************************************************"
echo "Simple schema deployment complete." `date`
echo "******************************************************************************"
echo ""
echo "Schema deployed: ${APP_SCHEMA}"
echo "Tables created: replication_test, replication_details, audit_log"
echo "Sequences: seq_replication_test, seq_replication_details, seq_audit_log"
echo "Procedures: insert_test_data, check_replication_status"
echo ""
echo "This schema will be automatically replicated to the standby database"
echo "when Data Guard is configured."
echo ""
echo "To verify replication after standby setup:"
echo "  On primary:  SELECT * FROM ${APP_SCHEMA}.replication_test;"
echo "  On standby:  SELECT * FROM ${APP_SCHEMA}.replication_test;"
echo "  (timestamps and created_on_db should show replication)"
echo ""
