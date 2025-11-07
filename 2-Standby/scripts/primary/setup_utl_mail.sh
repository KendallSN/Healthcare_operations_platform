#!/bin/bash
# Setup UTL_MAIL and UTL_SMTP packages in PDB
# This script configures email functionality for the application schema

. /vagrant_config/install.env
. /home/oracle/scripts/setEnv.sh

echo "******************************************************************************"
echo "Setup UTL_MAIL and UTL_SMTP in ${PDB_NAME}." `date`
echo "******************************************************************************"

# Check if UTL_MAIL installation is enabled
if [ "${INSTALL_UTL_MAIL}" != "true" ]; then
  echo "UTL_MAIL installation is disabled (INSTALL_UTL_MAIL=${INSTALL_UTL_MAIL})"
  echo "Skipping UTL_MAIL setup."
  exit 0
fi

echo "Installing UTL_MAIL and UTL_SMTP packages..."

# Install UTL_MAIL in the PDB
sqlplus / as sysdba <<EOF
-- Connect to PDB
ALTER SESSION SET CONTAINER=${PDB_NAME};

-- Run the UTL_MAIL installation scripts
-- These scripts are part of Oracle and create the UTL_MAIL package
@?/rdbms/admin/utlmail.sql
@?/rdbms/admin/prvtmail.plb

EXIT;
EOF

# Configure SMTP server for UTL_MAIL
echo "Configuring SMTP server: ${SMTP_SERVER}"

sqlplus / as sysdba <<EOF
ALTER SESSION SET CONTAINER=${PDB_NAME};

-- Set SMTP server parameter
BEGIN
  -- Configure SMTP_OUT_SERVER parameter
  EXECUTE IMMEDIATE 'ALTER SYSTEM SET SMTP_OUT_SERVER = ''${SMTP_SERVER}'' SCOPE=BOTH';
EXCEPTION
  WHEN OTHERS THEN
    -- If parameter doesn't exist or can't be set at PDB level, set at CDB level
    NULL;
END;
/

EXIT;
EOF

# Try setting at CDB level if PDB level fails
sqlplus / as sysdba <<EOF
-- Set SMTP server at CDB level (fallback)
ALTER SYSTEM SET SMTP_OUT_SERVER = '${SMTP_SERVER}' SCOPE=BOTH;

EXIT;
EOF

# Verify UTL_MAIL package exists
echo "Verifying UTL_MAIL installation..."
sqlplus / as sysdba <<EOF
ALTER SESSION SET CONTAINER=${PDB_NAME};

SET HEADING OFF
SET FEEDBACK OFF

SELECT 'UTL_MAIL package: ' || object_name || ' (' || status || ')'
FROM dba_objects
WHERE object_name = 'UTL_MAIL' AND owner = 'SYS' AND object_type = 'PACKAGE';

SELECT 'UTL_SMTP package: ' || object_name || ' (' || status || ')'
FROM dba_objects
WHERE object_name = 'UTL_SMTP' AND owner = 'SYS' AND object_type = 'PACKAGE';

EXIT;
EOF

echo "******************************************************************************"
echo "UTL_MAIL and UTL_SMTP setup complete." `date`
echo "******************************************************************************"
