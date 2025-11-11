#!/bin/bash
# Crear base de datos PRIMARIA con configuración de Data Guard

. /vagrant_config/install.env
. /home/oracle/scripts/setEnv.sh

echo "******************************************************************************"
echo "Configurar scripts de red." `date`
echo "******************************************************************************"

# Crear tnsnames.ora
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

# Crear listener.ora
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

# Crear sqlnet.ora
cat > ${ORACLE_HOME}/network/admin/sqlnet.ora <<EOF
SQLNET.INBOUND_CONNECT_TIMEOUT=400
EOF

# Agregar Cifrado de Red Nativo si está habilitado
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
echo "Iniciar listener." `date`
echo "******************************************************************************"
lsnrctl stop 2>/dev/null || true
lsnrctl start
lsnrctl status

echo "******************************************************************************"
echo "Crear base de datos." `date`
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
echo "Configurar el PDB para inicio automático." `date`
echo "******************************************************************************"
sqlplus / as sysdba <<EOF
alter system set db_create_file_dest='${DATA_DIR}';
alter system set db_create_online_log_dest_1='${DATA_DIR}';
alter pluggable database ${PDB_NAME} save state;
alter system reset local_listener;
exit;
EOF

echo "******************************************************************************"
echo "Configurar para Data Guard usando el comando PREPARE DATABASE." `date`
echo "******************************************************************************"
mkdir -p ${FRA_LOCATION}
mkdir -p ${DATA_DIR}/${ORACLE_SID}/arch

# Usar el comando moderno PREPARE DATABASE FOR DATA GUARD
# Este comando automatiza la configuración de Data Guard habilitando:
# - ARCHIVELOG mode (modo de archivo de logs)
# - FORCE LOGGING (registro forzado de todas las transacciones)
# - Configuración del Fast Recovery Area (FRA)
# - Parámetros esenciales de Data Guard
dgmgrl / <<EOF
prepare database for data guard
  with db_unique_name is ${NODE1_DB_UNIQUE_NAME}
  db_recovery_file_dest is "${FRA_LOCATION}"
  db_recovery_file_dest_size is ${FRA_SIZE};
exit;
EOF

echo "******************************************************************************"
echo "Configurar parámetros adicionales de Data Guard según la guía." `date`
echo "******************************************************************************"
sqlplus / as sysdba <<EOF
-- Archive lag target (objetivo de retraso de archivo) - fuerza cambio de log después de 5 minutos
-- Garantiza que los cambios se envíen al standby incluso con poca actividad transaccional
ALTER SYSTEM SET archive_lag_target=${ARCHIVE_LAG_TARGET} SCOPE=BOTH;

-- Log archive configuration (configuración de archivo de logs) - lista todas las bases de datos en la configuración de Data Guard
-- DG_CONFIG identifica todas las bases de datos que participan en la configuración de Data Guard
ALTER SYSTEM SET log_archive_config='DG_CONFIG=(${NODE1_DB_UNIQUE_NAME},${NODE2_DB_UNIQUE_NAME})' SCOPE=BOTH;

-- Archive destinations (destinos de archivo) - destino local para archive logs
-- LOCATION: directorio local donde se guardan los archive logs
-- VALID_FOR: aplica a todos los archivos de log y todos los roles (primary/standby)
-- DB_UNIQUE_NAME: identifica esta base de datos en la configuración de Data Guard
ALTER SYSTEM SET log_archive_dest_1=
  'LOCATION=${DATA_DIR}/${ORACLE_SID}/arch VALID_FOR=(ALL_LOGFILES,ALL_ROLES) DB_UNIQUE_NAME=${NODE1_DB_UNIQUE_NAME}'
  SCOPE=BOTH;

-- LOG_ARCHIVE_DEST_2 es gestionado por Data Guard Broker (no se configura manualmente)
-- El Broker configura automáticamente el destino remoto al standby

-- Habilitar el destino de archivo primario
ALTER SYSTEM SET log_archive_dest_state_1='ENABLE' SCOPE=BOTH;

-- Formato de nombre de archivo para archive logs: thread_sequence_resetlogs.arc
-- %t=thread number, %s=log sequence number, %r=resetlogs ID
ALTER SYSTEM SET log_archive_format='%t_%s_%r.arc' SCOPE=SPFILE;

-- Archive process configuration (configuración de procesos archivadores)
-- Número de procesos ARCn que pueden archivar logs en paralelo (mejora rendimiento)
ALTER SYSTEM SET log_archive_max_processes=8 SCOPE=BOTH;

-- FAL (Fetch Archive Log) configuration es gestionada por Data Guard Broker (no se configura manualmente)
-- El Broker configura automáticamente FAL_SERVER y FAL_CLIENT para recuperación automática de gaps

-- Standby file management (gestión automática de archivos en standby)
-- AUTO: Oracle gestiona automáticamente la creación/eliminación de archivos en standby
ALTER SYSTEM SET standby_file_management='AUTO' SCOPE=BOTH;

-- Protection and checking (protección y verificación)
-- db_lost_write_protect: detecta escrituras perdidas que pueden causar corrupción de datos
ALTER SYSTEM SET db_lost_write_protect='TYPICAL' SCOPE=BOTH;

-- db_block_checking: verifica la integridad de bloques de datos al leer/escribir
ALTER SYSTEM SET db_block_checking='MEDIUM' SCOPE=BOTH;

-- db_block_checksum: calcula checksums para detectar corrupción de bloques
ALTER SYSTEM SET db_block_checksum='TYPICAL' SCOPE=BOTH;

-- File name conversion (conversión de nombres de archivo)
-- db_file_name_convert: convierte rutas de archivos de datos del standby al primary
-- Mapea /u01/oradata/${NODE2_DB_UNIQUE_NAME}/ a /u01/oradata/${NODE1_DB_UNIQUE_NAME}/
ALTER SYSTEM SET db_file_name_convert='/u01/oradata/${NODE2_DB_UNIQUE_NAME}/','/u01/oradata/${NODE1_DB_UNIQUE_NAME}/' SCOPE=SPFILE;

-- log_file_name_convert: convierte rutas de redo logs del standby al primary
ALTER SYSTEM SET log_file_name_convert='/u01/oradata/${NODE2_DB_UNIQUE_NAME}/','/u01/oradata/${NODE1_DB_UNIQUE_NAME}/' SCOPE=SPFILE;

-- Crear archivo de contraseñas para autenticación remota (requerido para Data Guard)
-- Permite que el standby se autentique con el primary usando SYS password
!orapwd file=${ORACLE_HOME}/dbs/orapw${ORACLE_SID} password=${SYS_PASSWORD} entries=10 format=12

EXIT;
EOF

echo "******************************************************************************"
echo "Verificar estado de FLASHBACK DATABASE (habilitado por PREPARE DATABASE)." `date`
echo "******************************************************************************"
sqlplus / as sysdba <<EOF
-- Verificar si flashback está habilitado (PREPARE DATABASE FOR DATA GUARD lo habilita automáticamente)
-- Flashback Database permite retroceder la base de datos a un punto anterior en el tiempo
-- Es crítico para operaciones de failover y recuperación en Data Guard
SET SERVEROUTPUT ON
DECLARE
    v_flashback_on VARCHAR2(3);
BEGIN
    SELECT flashback_on INTO v_flashback_on FROM v\$database;

    IF v_flashback_on = 'NO' THEN
        DBMS_OUTPUT.PUT_LINE('Flashback está desactivado, habilitando ahora...');
        EXECUTE IMMEDIATE 'ALTER DATABASE FLASHBACK ON';
        DBMS_OUTPUT.PUT_LINE('Flashback habilitado exitosamente.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Flashback ya está activado (habilitado por PREPARE DATABASE FOR DATA GUARD).');
    END IF;
END;
/

-- Verificar que flashback está habilitado y la base de datos está en modo ARCHIVELOG
SELECT name, db_unique_name, flashback_on, log_mode
FROM v\$database;

-- Mostrar configuración del Fast Recovery Area (FRA)
-- El FRA almacena flashback logs, archive logs, y backups
SHOW PARAMETER db_recovery_file_dest;

EXIT;
EOF

echo "******************************************************************************"
echo "Creación de base de datos PRIMARIA completa." `date`
echo "******************************************************************************"
