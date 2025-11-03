#!/bin/bash
# Create PRIMARY database with Data Guard configuration

. /vagrant_config/install.env
. /home/oracle/scripts/setEnv.sh

echo "******************************************************************************"
echo "Configure network scripts." `date`
echo "******************************************************************************"

# Create tnsnames.ora
cat > ${ORACLE_HOME}/network/admin/tnsnames.ora <<EOF
LISTENER${DB_DOMAIN_STR} = (ADDRESS = (PROTOCOL = TCP)(HOST = ${NODE1_FQ_HOSTNAME})(PORT = 1521))

${NODE1_DB_UNIQUE_NAME}${DB_DOMAIN_STR} =
  (DESCRIPTION =
    (ADDRESS_LIST =
      (ADDRESS = (PROTOCOL = TCP)(HOST = ${NODE1_FQ_HOSTNAME})(PORT = 1521))
    )
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SID = ${ORACLE_SID})
      (UR=A)
    )
  )

${NODE2_DB_UNIQUE_NAME}${DB_DOMAIN_STR} =
  (DESCRIPTION =
    (ADDRESS_LIST =
      (ADDRESS = (PROTOCOL = TCP)(HOST = ${NODE2_FQ_HOSTNAME})(PORT = 1521))
    )
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SID = ${ORACLE_SID})
      (UR=A)
    )
  )
EOF

# Create listener.ora
cat > ${ORACLE_HOME}/network/admin/listener.ora <<EOF
LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = ${NODE1_FQ_HOSTNAME})(PORT = 1521))
      (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1521))
    )
  )

SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = ${NODE1_DB_UNIQUE_NAME})
      (SID_NAME = ${ORACLE_SID})
      (ORACLE_HOME = ${ORACLE_HOME})
    )
    (SID_DESC =
      (GLOBAL_DBNAME = ${NODE1_DB_UNIQUE_NAME}${DB_DOMAIN_STR})
      (SID_NAME = ${ORACLE_SID})
      (ORACLE_HOME = ${ORACLE_HOME})
    )
    (SID_DESC =
      (SID_NAME = ${ORACLE_SID})
      (GLOBAL_DBNAME = ${NODE1_DB_UNIQUE_NAME}_DGMGRL${DB_DOMAIN_STR})
      (ORACLE_HOME = ${ORACLE_HOME})
      (ENVS="TNS_ADMIN=${ORACLE_HOME}/network/admin")
    )
  )

ADR_BASE_LISTENER = ${ORACLE_BASE}
INBOUND_CONNECT_TIMEOUT_LISTENER=400
EOF

# Create sqlnet.ora
cat > ${ORACLE_HOME}/network/admin/sqlnet.ora <<EOF
SQLNET.INBOUND_CONNECT_TIMEOUT=400
EOF

# Add Native Network Encryption if enabled
if [ "${NATIVE_NETWORK_ENCRYPTION}" = "true" ]; then
  cat >> ${ORACLE_HOME}/network/admin/sqlnet.ora <<EOF
SQLNET.ENCRYPTION_SERVER=REQUIRED
SQLNET.ENCRYPTION_TYPES_SERVER=(AES256)

SQLNET.ENCRYPTION_CLIENT=REQUIRED
SQLNET.ENCRYPTION_TYPES_CLIENT=(AES256)

SQLNET.CRYPTO_CHECKSUM_SERVER=REQUIRED
SQLNET.CRYPTO_CHECKSUM_TYPES_SERVER = (SHA256)

SQLNET.CRYPTO_CHECKSUM_CLIENT=REQUIRED
SQLNET.CRYPTO_CHECKSUM_TYPES_CLIENT = (SHA256)
EOF
fi

if [ "${DB_DOMAIN}" != "" ]; then
  cat >> ${ORACLE_HOME}/network/admin/sqlnet.ora <<EOF
NAMES.DEFAULT_DOMAIN=${DB_DOMAIN}
EOF
fi

echo "******************************************************************************"
echo "Start listener." `date`
echo "******************************************************************************"
lsnrctl stop 2>/dev/null || true
lsnrctl start
lsnrctl status

echo "******************************************************************************"
echo "Create database." `date`
echo "******************************************************************************"
dbca -silent -createDatabase \
  -templateName General_Purpose.dbc \
  -sid ${ORACLE_SID} \
  -responseFile NO_VALUE \
  -gdbname ${DB_NAME}${DB_DOMAIN_STR} \
  -characterSet AL32UTF8 \
  -sysPassword ${SYS_PASSWORD} \
  -systemPassword ${SYS_PASSWORD} \
  -createAsContainerDatabase true \
  -numberOfPDBs 1 \
  -pdbName ${PDB_NAME} \
  -pdbAdminPassword ${PDB_PASSWORD} \
  -databaseType MULTIPURPOSE \
  -automaticMemoryManagement false \
  -totalMemory 2048 \
  -storageType FS \
  -datafileDestination "${DATA_DIR}" \
  -redoLogFileSize ${REDO_LOG_SIZE} \
  -emConfiguration NONE \
  -initparams db_name=${DB_NAME},db_unique_name=${NODE1_DB_UNIQUE_NAME} \
  -ignorePreReqs

echo "******************************************************************************"
echo "Set the PDB to auto-start." `date`
echo "******************************************************************************"
sqlplus / as sysdba <<EOF
alter system set db_create_file_dest='${DATA_DIR}';
alter system set db_create_online_log_dest_1='${DATA_DIR}';
alter pluggable database ${PDB_NAME} save state;
alter system reset local_listener;
exit;
EOF

echo "******************************************************************************"
echo "Configure for Data Guard using PREPARE DATABASE command." `date`
echo "******************************************************************************"
mkdir -p ${FRA_LOCATION}
mkdir -p ${DATA_DIR}/${ORACLE_SID}/arch

# Use modern PREPARE DATABASE FOR DATA GUARD command
dgmgrl / <<EOF
prepare database for data guard
  with db_unique_name is ${NODE1_DB_UNIQUE_NAME}
  db_recovery_file_dest is "${FRA_LOCATION}"
  db_recovery_file_dest_size is ${FRA_SIZE};
exit;
EOF

echo "******************************************************************************"
echo "Configure additional Data Guard parameters per guide." `date`
echo "******************************************************************************"
sqlplus / as sysdba <<EOF
-- Archive lag target (5 minutes as per guide)
ALTER SYSTEM SET archive_lag_target=${ARCHIVE_LAG_TARGET} SCOPE=BOTH;

-- Log archive configuration
ALTER SYSTEM SET log_archive_config='DG_CONFIG=(${NODE1_DB_UNIQUE_NAME},${NODE2_DB_UNIQUE_NAME})' SCOPE=BOTH;

-- Archive destinations
ALTER SYSTEM SET log_archive_dest_1=
  'LOCATION=${DATA_DIR}/${ORACLE_SID}/arch VALID_FOR=(ALL_LOGFILES,ALL_ROLES) DB_UNIQUE_NAME=${NODE1_DB_UNIQUE_NAME}'
  SCOPE=BOTH;

-- LOG_ARCHIVE_DEST_2 is managed by Data Guard Broker (not configured manually)

ALTER SYSTEM SET log_archive_dest_state_1='ENABLE' SCOPE=BOTH;
ALTER SYSTEM SET log_archive_format='%t_%s_%r.arc' SCOPE=SPFILE;

-- Archive process configuration
ALTER SYSTEM SET log_archive_max_processes=8 SCOPE=BOTH;

-- FAL configuration is managed by Data Guard Broker (not configured manually)

-- Standby file management
ALTER SYSTEM SET standby_file_management='AUTO' SCOPE=BOTH;

-- Protection and checking
ALTER SYSTEM SET db_lost_write_protect='TYPICAL' SCOPE=BOTH;
ALTER SYSTEM SET db_block_checking='MEDIUM' SCOPE=BOTH;
ALTER SYSTEM SET db_block_checksum='TYPICAL' SCOPE=BOTH;

-- File name conversion
ALTER SYSTEM SET db_file_name_convert='/u01/oradata/${NODE2_DB_UNIQUE_NAME}/','/u01/oradata/${NODE1_DB_UNIQUE_NAME}/' SCOPE=SPFILE;
ALTER SYSTEM SET log_file_name_convert='/u01/oradata/${NODE2_DB_UNIQUE_NAME}/','/u01/oradata/${NODE1_DB_UNIQUE_NAME}/' SCOPE=SPFILE;

-- Create password file
!orapwd file=${ORACLE_HOME}/dbs/orapw${ORACLE_SID} password=${SYS_PASSWORD} entries=10 format=12

EXIT;
EOF

echo "******************************************************************************"
echo "Verify FLASHBACK DATABASE status (enabled by PREPARE DATABASE)." `date`
echo "******************************************************************************"
sqlplus / as sysdba <<EOF
-- Check if flashback is already enabled (PREPARE DATABASE FOR DATA GUARD enables it automatically)
SET SERVEROUTPUT ON
DECLARE
    v_flashback_on VARCHAR2(3);
BEGIN
    SELECT flashback_on INTO v_flashback_on FROM v\$database;

    IF v_flashback_on = 'NO' THEN
        DBMS_OUTPUT.PUT_LINE('Flashback is OFF, enabling now...');
        EXECUTE IMMEDIATE 'ALTER DATABASE FLASHBACK ON';
        DBMS_OUTPUT.PUT_LINE('Flashback enabled successfully.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Flashback is already ON (enabled by PREPARE DATABASE FOR DATA GUARD).');
    END IF;
END;
/

-- Verify flashback is enabled
SELECT name, db_unique_name, flashback_on, log_mode
FROM v\$database;

-- Show FRA configuration
SHOW PARAMETER db_recovery_file_dest;

EXIT;
EOF

echo "******************************************************************************"
echo "PRIMARY database creation complete." `date`
echo "******************************************************************************"
