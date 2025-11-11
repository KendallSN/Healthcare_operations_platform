#!/bin/bash
# Desplegar esquema de prueba simple para pruebas de replicación de Data Guard
# Este script crea un esquema mínimo para verificar la funcionalidad de Data Guard
# sin dependencias de esquemas de aplicación complejos

. /vagrant_config/install.env
. /home/oracle/scripts/setEnv.sh

echo "******************************************************************************"
echo "Desplegar esquema de prueba simple a ${PDB_NAME}." `date`
echo "******************************************************************************"

# Definir directorio de esquema y archivos (todos dentro de 2-Standby)
SCHEMA_DIR="/vagrant/2-Standby/schema"
SCHEMA_SQL="${SCHEMA_DIR}/simple_schema.sql"

# Verificar que el archivo de esquema existe
if [ ! -f "${SCHEMA_SQL}" ]; then
  echo "ERROR: Script de esquema no encontrado: ${SCHEMA_SQL}"
  exit 1
fi

echo "Archivo de esquema verificado: ${SCHEMA_SQL}"

# Abrir PDB si no está ya abierto
sqlplus / as sysdba <<EOF
ALTER PLUGGABLE DATABASE ${PDB_NAME} OPEN;
EXIT;
EOF

# ============================================================================
# Paso 1: Crear usuario de prueba
# ============================================================================
echo "******************************************************************************"
echo "Crear usuario de prueba ${APP_SCHEMA} en ${PDB_NAME}..." `date`
echo "******************************************************************************"

echo "Creando usuario con tablespace USERS predeterminado..."

# Ejecutar creación de usuario directamente con contraseña del entorno
# Usar heredoc para evitar problemas de expansión de shell con caracteres especiales como !
sqlplus -S / as sysdba <<EOF
WHENEVER SQLERROR EXIT SQL.SQLCODE
-- Conectar a la PDB
ALTER SESSION SET CONTAINER=${PDB_NAME};

-- Descartar usuario si existe (para redeployment)
BEGIN
  EXECUTE IMMEDIATE 'DROP USER ${APP_SCHEMA} CASCADE';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -1918 THEN  -- ORA-01918: user does not exist
      RAISE;
    END IF;
END;
/

-- Crear usuario con contraseña del config
CREATE USER ${APP_SCHEMA} IDENTIFIED BY "${APP_SCHEMA_PASSWORD}"
  DEFAULT TABLESPACE users
  TEMPORARY TABLESPACE temp
  QUOTA UNLIMITED ON users;

-- Otorgar privilegios necesarios
GRANT CONNECT, RESOURCE TO ${APP_SCHEMA};
GRANT CREATE SESSION TO ${APP_SCHEMA};
GRANT CREATE TABLE TO ${APP_SCHEMA};
GRANT CREATE SEQUENCE TO ${APP_SCHEMA};
GRANT CREATE VIEW TO ${APP_SCHEMA};
GRANT CREATE PROCEDURE TO ${APP_SCHEMA};

-- Mostrar confirmación
SELECT 'User ${APP_SCHEMA} created successfully' AS status FROM dual;

EXIT;
EOF

SQL_EXIT_CODE=$?
if [ ${SQL_EXIT_CODE} -ne 0 ]; then
  echo "ERROR: Creación de usuario falló con código de salida ${SQL_EXIT_CODE}"
  exit ${SQL_EXIT_CODE}
fi

echo "Usuario ${APP_SCHEMA} creado exitosamente con tablespace predeterminado"

# Verificar que el usuario fue creado
echo "Verificando creación de usuario..."
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
# Paso 2: Desplegar esquema simple
# ============================================================================
echo "******************************************************************************"
echo "Desplegando esquema simple como ${APP_SCHEMA}..." `date`
echo "******************************************************************************"

sqlplus -S / as sysdba <<EOF
WHENEVER SQLERROR EXIT SQL.SQLCODE
-- Conectar a la PDB y establecer esquema actual
ALTER SESSION SET CONTAINER=${PDB_NAME};
ALTER SESSION SET CURRENT_SCHEMA=${APP_SCHEMA};

-- Ejecutar el script de esquema simple
@${SCHEMA_SQL}

EXIT;
EOF

SQL_EXIT_CODE=$?
if [ ${SQL_EXIT_CODE} -ne 0 ]; then
  echo "ERROR: Despliegue de esquema falló con código de salida ${SQL_EXIT_CODE}"
  exit ${SQL_EXIT_CODE}
fi

echo "Esquema simple desplegado exitosamente"

# ============================================================================
# Paso 3: Verificar despliegue
# ============================================================================
echo "******************************************************************************"
echo "Verificar objetos del esquema..." `date`
echo "******************************************************************************"

sqlplus / as sysdba <<EOF
ALTER SESSION SET CONTAINER=${PDB_NAME};
ALTER SESSION SET CURRENT_SCHEMA=${APP_SCHEMA};

SET LINESIZE 150
SET PAGESIZE 100

-- Mostrar tablas
PROMPT
PROMPT Tablas:
COL table_name FORMAT A30
SELECT table_name, num_rows
FROM user_tables
ORDER BY table_name;

-- Mostrar secuencias
PROMPT
PROMPT Secuencias:
COL sequence_name FORMAT A30
SELECT sequence_name, last_number
FROM user_sequences
ORDER BY sequence_name;

-- Mostrar procedimientos
PROMPT
PROMPT Procedimientos:
COL object_name FORMAT A30
SELECT object_name, object_type, status
FROM user_objects
WHERE object_type IN ('PROCEDURE', 'TRIGGER')
ORDER BY object_type, object_name;

EXIT;
EOF

# ============================================================================
# Paso 4: Forzar cambio de registro para replicación
# ============================================================================
echo "******************************************************************************"
echo "Forzar archivo de registro para asegurar replicación." `date`
echo "******************************************************************************"

sqlplus / as sysdba <<EOF
ALTER SYSTEM ARCHIVE LOG CURRENT;
EXIT;
EOF

echo "******************************************************************************"
echo "Despliegue del esquema simple completado." `date`
echo "******************************************************************************"
echo ""
echo "Esquema desplegado: ${APP_SCHEMA}"
echo "Tablas creadas: replication_test, replication_details, audit_log"
echo "Secuencias: seq_replication_test, seq_replication_details, seq_audit_log"
echo "Procedimientos: insert_test_data, check_replication_status"
echo ""
echo "Este esquema será replicado automáticamente a la base de datos standby"
echo "cuando Data Guard sea configurado."
echo ""
echo "Para verificar la replicación después de la configuración del standby:"
echo "  En primario:  SELECT * FROM ${APP_SCHEMA}.replication_test;"
echo "  En standby:  SELECT * FROM ${APP_SCHEMA}.replication_test;"
echo "  (las marcas de tiempo y created_on_db deben mostrar la replicación)"
echo ""
