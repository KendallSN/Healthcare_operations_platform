#!/bin/bash
# Crear base de datos STANDBY usando RMAN DUPLICATE y configurar Data Guard Broker

. /vagrant_config/install.env
. /home/oracle/scripts/setEnv.sh

echo "******************************************************************************"
echo "Configurar scripts de red." `date`
echo "******************************************************************************"

# Crear tnsnames.ora (igual que en el primario)
cat > ${ORACLE_HOME}/network/admin/tnsnames.ora <<EOF
LISTENER${DB_DOMAIN_STR} = (ADDRESS = (PROTOCOL = TCP)(HOST = ${NODE2_FQ_HOSTNAME})(PORT = 1521))

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
      (ADDRESS = (PROTOCOL = TCP)(HOST = ${NODE2_FQ_HOSTNAME})(PORT = 1521))
      (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1521))
    )
  )

SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = ${NODE2_DB_UNIQUE_NAME})
      (SID_NAME = ${ORACLE_SID})
      (ORACLE_HOME = ${ORACLE_HOME})
    )
    (SID_DESC =
      (GLOBAL_DBNAME = ${NODE2_DB_UNIQUE_NAME}${DB_DOMAIN_STR})
      (SID_NAME = ${ORACLE_SID})
      (ORACLE_HOME = ${ORACLE_HOME})
    )
    (SID_DESC =
      (SID_NAME = ${ORACLE_SID})
      (GLOBAL_DBNAME = ${NODE2_DB_UNIQUE_NAME}_DGMGRL${DB_DOMAIN_STR})
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

# Agregar cifrado de red nativo si está habilitado
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
echo "Crear directorios y archivo de contraseñas." `date`
echo "******************************************************************************"

mkdir -p /u01/oradata/${ORACLE_SID^^}
mkdir -p /u01/oradata/${ORACLE_SID^^}/pdbseed
mkdir -p /u01/oradata/${ORACLE_SID^^}/${PDB_NAME}
mkdir -p ${FRA_LOCATION}/${ORACLE_SID}
mkdir -p ${ORACLE_BASE}/admin/${ORACLE_SID}/adump
mkdir -p ${DATA_DIR}/${ORACLE_SID}/arch
mkdir -p /u02/backup_from_primary

orapwd file=$ORACLE_HOME/dbs/orapw${ORACLE_SID} password=${SYS_PASSWORD} entries=10 format=12

echo "******************************************************************************"
echo "Crear archivo init.ora temporal para la instancia auxiliar." `date`
echo "******************************************************************************"

cat > /tmp/init${ORACLE_SID}_stby.ora <<EOF
*.db_name='${ORACLE_SID}'
EOF

echo "******************************************************************************"
echo "Crear instancia auxiliar." `date`
echo "******************************************************************************"

sqlplus / as sysdba <<EOF
startup nomount pfile='/tmp/init${ORACLE_SID}_stby.ora';
exit;
EOF

echo "******************************************************************************"
echo "Probar conectividad a la base de datos primaria." `date`
echo "******************************************************************************"

tnsping ${NODE1_DB_UNIQUE_NAME}${DB_DOMAIN_STR}

echo "******************************************************************************"
echo "Crear base de datos standby usando RMAN duplicate." `date`
echo "Esto puede tardar 10-20 minutos dependiendo del tamaño de la base de datos..."
echo "******************************************************************************"

# RMAN DUPLICATE FROM ACTIVE DATABASE:
# Este comando crea una copia física exacta de la base de datos primaria para usarla como standby.
# - TARGET: Se conecta a la base de datos primaria (origen de los datos)
# - AUXILIARY: Se conecta a la instancia auxiliar standby (destino de la copia)
# - DUPLICATE TARGET DATABASE: Comando principal que inicia la duplicación
# - FOR STANDBY: Indica que se creará una base de datos standby (no una copia independiente)
# - FROM ACTIVE DATABASE: Copia los datos directamente desde la base de datos primaria en ejecución
#   sin necesidad de backups previos. Usa conexiones de red para transferir los archivos.
# - DORECOVER: Aplica automáticamente los redo logs archivados disponibles después de copiar
#   los archivos de datos, sincronizando el standby con el primario lo máximo posible
# - SPFILE: Copia y configura el archivo de parámetros del servidor (SPFile) desde el primario
# - SET DB_UNIQUE_NAME: Establece el nombre único de la base de datos standby (debe ser diferente al primario)
# - NOFILENAMECHECK: Omite la validación de nombres de archivos, permitiendo usar el mismo
#   nombre de archivo en ambos servidores (necesario cuando ambos están en máquinas diferentes)
rman target sys/${SYS_PASSWORD}@${NODE1_DB_UNIQUE_NAME}${DB_DOMAIN_STR} auxiliary sys/${SYS_PASSWORD}@${NODE2_DB_UNIQUE_NAME}${DB_DOMAIN_STR} <<EOF

duplicate target database
  for standby
  from active database
  dorecover
  spfile
    set db_unique_name='${NODE2_DB_UNIQUE_NAME}' comment 'Is standby'
  nofilenamecheck;

exit;
EOF

echo "******************************************************************************"
echo "Habilitar FLASHBACK DATABASE en standby." `date`
echo "******************************************************************************"

sqlplus / as sysdba <<EOF
-- Verificar si flashback ya está habilitado
SET SERVEROUTPUT ON
DECLARE
    v_flashback_on VARCHAR2(3);
BEGIN
    SELECT flashback_on INTO v_flashback_on FROM v\$database;

    IF v_flashback_on = 'NO' THEN
        DBMS_OUTPUT.PUT_LINE('Flashback está DESACTIVADO en standby, habilitando ahora...');
        EXECUTE IMMEDIATE 'ALTER DATABASE FLASHBACK ON';
        DBMS_OUTPUT.PUT_LINE('Flashback habilitado exitosamente en standby.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Flashback ya está ACTIVADO en standby.');
    END IF;
END;
/

-- Verificar que flashback está habilitado
SELECT name, db_unique_name, flashback_on, log_mode
FROM v\$database;

EXIT;
EOF

echo "******************************************************************************"
echo "Habilitar Data Guard Broker en standby." `date`
echo "******************************************************************************"

# ALTER SYSTEM SET DG_BROKER_START=TRUE:
# Inicia el proceso Data Guard Broker (DMON) en la base de datos standby.
# El Broker es una herramienta de gestión centralizada que simplifica la administración
# de configuraciones Data Guard, incluyendo switchover, failover y monitoreo.
sqlplus / as sysdba <<EOF
alter system set dg_broker_start=true;
EXIT;
EOF

echo "******************************************************************************"
echo "Habilitar Data Guard Broker en primario y crear configuración." `date`
echo "******************************************************************************"

# Habilitar broker en primario
# ALTER SYSTEM SET DG_BROKER_START=TRUE:
# Inicia el proceso Data Guard Broker (DMON) en la base de datos primaria.
# Debe habilitarse en ambas bases de datos (primaria y standby) para que puedan
# comunicarse y coordinarse a través del Broker.
sqlplus sys/${SYS_PASSWORD}@${NODE1_DB_UNIQUE_NAME}${DB_DOMAIN_STR} as sysdba <<EOF
alter system set dg_broker_start=true;
EXIT;
EOF

# Esperar a que el broker se inicialice
sleep 10

# Configurar broker
# COMANDOS DATA GUARD BROKER (DGMGRL):
# DGMGRL es la herramienta de línea de comandos para gestionar Data Guard Broker.
# Se conecta a la base de datos primaria para administrar toda la configuración.
#
# REMOVE CONFIGURATION:
# Elimina cualquier configuración de Broker existente (útil en reinstalaciones).
# Es seguro ejecutar aunque no exista configuración previa (genera advertencia pero continúa).
#
# CREATE CONFIGURATION DG_CONFIG AS PRIMARY DATABASE:
# Crea una nueva configuración de Data Guard Broker con nombre 'dg_config'.
# - AS PRIMARY DATABASE IS: Define cuál base de datos es la primaria en la configuración
# - CONNECT IDENTIFIER IS: Especifica el nombre de servicio TNS para conectarse al primario
#
# ADD DATABASE AS CONNECT IDENTIFIER:
# Agrega la base de datos standby a la configuración de Broker.
# - Registra el standby como miembro de la configuración Data Guard
# - CONNECT IDENTIFIER: Nombre de servicio TNS para conectarse al standby
# - El Broker usará esta conexión para administrar y monitorear el standby
#
# ENABLE CONFIGURATION:
# Activa la configuración de Data Guard Broker.
# - Inicia el monitoreo automático y la gestión de ambas bases de datos
# - El Broker comienza a rastrear el estado de sincronización
# - Habilita comandos avanzados como SWITCHOVER y FAILOVER
#
# SHOW CONFIGURATION:
# Muestra el estado actual de la configuración Data Guard:
# - Estado de cada base de datos (SUCCESS, WARNING, ERROR)
# - Modo de protección actual (MAXPERFORMANCE, MAXAVAILABILITY, MAXPROTECTION)
# - Roles de cada base de datos (PRIMARY, PHYSICAL STANDBY)
dgmgrl sys/${SYS_PASSWORD}@${NODE1_DB_UNIQUE_NAME}${DB_DOMAIN_STR} <<EOF
remove configuration;
create configuration dg_config as primary database is ${NODE1_DB_UNIQUE_NAME} connect identifier is ${NODE1_DB_UNIQUE_NAME}${DB_DOMAIN_STR};
add database ${NODE2_DB_UNIQUE_NAME} as connect identifier is ${NODE2_DB_UNIQUE_NAME}${DB_DOMAIN_STR};
enable configuration;
show configuration;
exit;
EOF

# Esperar a que la configuración se estabilice
sleep 15

echo "******************************************************************************"
echo "Configurar modo de protección MAXAVAILABILITY y transporte FASTSYNC." `date`
echo "******************************************************************************"

# Función para verificar que LogXptMode está configurado correctamente en una base de datos
verify_logxptmode() {
    local db_name=$1
    local expected_mode=$2
    local max_attempts=12  # 60 segundos totales (12 * 5 segundos)
    local attempt=1

    echo "Verificando LogXptMode=${expected_mode} en ${db_name}..."

    while [ $attempt -le $max_attempts ]; do
        # Consultar la propiedad LogXptMode desde Data Guard Broker
        local actual_mode=$(dgmgrl -silent sys/${SYS_PASSWORD}@${NODE1_DB_UNIQUE_NAME}${DB_DOMAIN_STR} <<EOF | grep "LogXptMode" | awk '{print $3}' | tr -d "'"
SHOW DATABASE VERBOSE ${db_name};
exit;
EOF
)

        if echo "$actual_mode" | grep -qi "$expected_mode"; then
            echo "[OK] LogXptMode verificado como ${expected_mode} en ${db_name}"
            return 0
        fi

        echo "  Intento ${attempt}/${max_attempts}: LogXptMode es '${actual_mode}', esperando '${expected_mode}'..."
        sleep 5
        attempt=$((attempt + 1))
    done

    echo "[ERROR] Falló la verificación de LogXptMode=${expected_mode} en ${db_name} después de ${max_attempts} intentos"
    return 1
}

# Función para verificar que el nivel de protección es MAXIMUM AVAILABILITY (no RESYNCHRONIZATION)
verify_protection_level() {
    local max_attempts=12  # 60 segundos totales
    local attempt=1

    echo "Verificando que el nivel de protección es MAXIMUM AVAILABILITY..."

    while [ $attempt -le $max_attempts ]; do
        # Consultar el nivel de protección desde la base de datos primaria
        local protection_level=$(sqlplus -s / as sysdba <<EOF
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF
SELECT protection_level FROM v\$database;
EXIT;
EOF
)

        # Eliminar espacios en blanco
        protection_level=$(echo "$protection_level" | tr -d ' \t\r\n')

        if [ "$protection_level" = "MAXIMUMAVAILABILITY" ]; then
            echo "[OK] Nivel de protección verificado como MAXIMUM AVAILABILITY"
            return 0
        fi

        echo "  Intento ${attempt}/${max_attempts}: Nivel de protección es '${protection_level}', esperando 'MAXIMUM AVAILABILITY'..."
        sleep 5
        attempt=$((attempt + 1))
    done

    echo "[ERROR] Falló la verificación del nivel de protección MAXIMUM AVAILABILITY después de ${max_attempts} intentos"
    echo "  Nivel de protección actual: ${protection_level}"
    return 1
}

# Paso 1: Establecer modo de transporte FASTSYNC en PRIMARIO
# EDIT DATABASE SET PROPERTY LogXptMode='FASTSYNC':
# Configura el modo de transporte de redo logs desde el primario al standby.
# - LogXptMode (Log Transport Mode): Define cómo se envían los redo logs al standby
# - FASTSYNC: Modo de transporte SÍNCRONO que garantiza cero pérdida de datos
#   * El primario espera confirmación de que el redo se escribió en el disco del standby
#   * Más lento que ASYNC pero garantiza que no se pierden transacciones confirmadas
#   * Requiere que el standby esté disponible, o las transacciones se bloquean
#   * Necesario para el modo de protección MAXAVAILABILITY
# - Otras opciones: SYNC (más estricto), ASYNC (sin espera), ARCH (por archivos)
echo "Estableciendo LogXptMode=FASTSYNC en base de datos primaria..."
dgmgrl sys/${SYS_PASSWORD}@${NODE1_DB_UNIQUE_NAME}${DB_DOMAIN_STR} <<EOF
EDIT DATABASE ${NODE1_DB_UNIQUE_NAME} SET PROPERTY LogXptMode='FASTSYNC';
exit;
EOF

# EDIT DATABASE SET PROPERTY LogXptMode='FASTSYNC' (en standby):
# Configura el modo de transporte de redo logs en el standby.
# Aunque el standby no envía logs en operación normal, esta propiedad se usa
# durante un switchover cuando el standby se convierte en primario.
echo "Estableciendo LogXptMode=FASTSYNC en base de datos standby..."
dgmgrl sys/${SYS_PASSWORD}@${NODE2_DB_UNIQUE_NAME}${DB_DOMAIN_STR} <<EOF
EDIT DATABASE ${NODE2_DB_UNIQUE_NAME} SET PROPERTY LogXptMode='FASTSYNC';
exit;
EOF

# Verificar que LogXptMode del primario se aplicó correctamente
if ! verify_logxptmode "${NODE1_DB_UNIQUE_NAME}" "FASTSYNC"; then
    echo "ADVERTENCIA: No se pudo verificar LogXptMode en primario, pero continuando..."
fi

# Paso 2: Habilitar aplicación de logs en standby para iniciar transporte de logs
# EDIT DATABASE SET STATE='APPLY-ON':
# Inicia el proceso Managed Recovery (MRP) en la base de datos standby.
# - APPLY-ON: Activa la aplicación automática de redo logs en el standby
# - El proceso MRP lee los redo logs recibidos y los aplica al standby
# - Mantiene el standby sincronizado con el primario en tiempo real
# - Necesario para que el transporte de logs funcione correctamente
# - Otras opciones: APPLY-OFF (desactiva aplicación), ONLINE (abre para lectura)
echo "Habilitando aplicación de logs en base de datos standby..."
dgmgrl sys/${SYS_PASSWORD}@${NODE1_DB_UNIQUE_NAME}${DB_DOMAIN_STR} <<EOF
EDIT DATABASE ${NODE2_DB_UNIQUE_NAME} SET STATE='APPLY-ON';
exit;
EOF

# Dar tiempo al standby para comenzar a aplicar logs
sleep 5

# Paso 3: Establecer modo de protección MAXAVAILABILITY DESPUÉS de configurar el transporte
# EDIT CONFIGURATION SET PROTECTION MODE AS MAXAVAILABILITY:
# Configura el modo de protección Data Guard a MAXIMUM AVAILABILITY.
#
# MODOS DE PROTECCIÓN DISPONIBLES:
# 1. MAXPROTECTION (Máxima Protección):
#    - Cero pérdida de datos GARANTIZADA
#    - Transacciones esperan confirmación SYNC del standby
#    - Si el standby no está disponible, el primario se APAGA
#    - El más seguro pero el más restrictivo
#
# 2. MAXAVAILABILITY (Máxima Disponibilidad) [CONFIGURADO AQUÍ]:
#    - Cero pérdida de datos EN CONDICIONES NORMALES
#    - Transacciones esperan confirmación FASTSYNC del standby
#    - Si el standby no está disponible, el primario continúa en modo MAXPERFORMANCE
#    - Mejor balance entre protección de datos y disponibilidad del primario
#    - Requiere LogXptMode=FASTSYNC o SYNC
#
# 3. MAXPERFORMANCE (Máximo Rendimiento):
#    - Pérdida de datos POSIBLE (según el retraso del transporte)
#    - No espera confirmación del standby (modo ASYNC)
#    - Máxima performance del primario, sin impacto por el standby
#    - El primario siempre continúa aunque el standby esté inactivo
#
# MAXAVAILABILITY proporciona:
# - Protección de datos (cero pérdida si el standby está activo)
# - Alta disponibilidad del primario (continúa si el standby falla)
# - Ideal para entornos de producción críticos
echo "Estableciendo modo de protección MAXAVAILABILITY..."
dgmgrl sys/${SYS_PASSWORD}@${NODE1_DB_UNIQUE_NAME}${DB_DOMAIN_STR} <<EOF
EDIT CONFIGURATION SET PROTECTION MODE AS MAXAVAILABILITY;
exit;
EOF

# Paso 4: Verificar que el nivel de protección es realmente MAXIMUM AVAILABILITY
if ! verify_protection_level; then
    echo "ADVERTENCIA: ¡Falló la verificación del nivel de protección!"
    echo "La configuración puede estar en modo RESYNCHRONIZATION o MAXIMUM PERFORMANCE."
    echo "Verifique el estado de Data Guard Broker para errores ORA-16627."
fi

# Mostrar configuración final después de aplicar todos los ajustes
echo ""
echo "Configuración final de Data Guard Broker:"
dgmgrl sys/${SYS_PASSWORD}@${NODE1_DB_UNIQUE_NAME}${DB_DOMAIN_STR} <<EOF
SHOW CONFIGURATION;
SHOW DATABASE ${NODE1_DB_UNIQUE_NAME};
SHOW DATABASE ${NODE2_DB_UNIQUE_NAME};
exit;
EOF

echo "******************************************************************************"
echo "Validar configuración de Data Guard." `date`
echo "******************************************************************************"

sleep 30

# VALIDATE DATABASE:
# Verifica que la base de datos esté configurada correctamente para Data Guard.
# - Valida configuración de redo logs, archive logs, parámetros de inicialización
# - VALIDATE DATABASE: Verifica la base de datos en general
# - VALIDATE DATABASE SPFILE: Verifica específicamente el archivo de parámetros
# - VALIDATE STATIC CONNECT IDENTIFIER: Verifica la configuración TNS para conexiones estáticas
#   (necesarias para que el Broker pueda conectarse cuando la BD está en modo MOUNT)
dgmgrl sys/${SYS_PASSWORD}@${NODE1_DB_UNIQUE_NAME}${DB_DOMAIN_STR} <<EOF
validate database ${NODE1_DB_UNIQUE_NAME};
validate database ${NODE2_DB_UNIQUE_NAME};
validate database ${NODE2_DB_UNIQUE_NAME} spfile;
validate static connect identifier for ${NODE1_DB_UNIQUE_NAME};
validate static connect identifier for ${NODE2_DB_UNIQUE_NAME};
exit;
EOF

echo "******************************************************************************"
echo "Verificar que FLASHBACK DATABASE está habilitado en ambas bases de datos." `date`
echo "******************************************************************************"

echo "Verificando estado de flashback en PRIMARIO..."
sqlplus -s sys/${SYS_PASSWORD}@${NODE1_DB_UNIQUE_NAME}${DB_DOMAIN_STR} as sysdba <<EOF
SET LINESIZE 180
COLUMN name FORMAT A15
COLUMN db_unique_name FORMAT A20
COLUMN flashback_on FORMAT A12
COLUMN log_mode FORMAT A12
SELECT name, db_unique_name, flashback_on, log_mode
FROM v\$database;
EXIT;
EOF

echo ""
echo "Verificando estado de flashback en STANDBY..."
sqlplus -s / as sysdba <<EOF
SET LINESIZE 180
COLUMN name FORMAT A15
COLUMN db_unique_name FORMAT A20
COLUMN flashback_on FORMAT A12
COLUMN log_mode FORMAT A12
SELECT name, db_unique_name, flashback_on, log_mode
FROM v\$database;
EXIT;
EOF

echo ""
echo "NOTA: FLASHBACK DATABASE permite reinstauración rápida después de un failover."
echo "      Sin flashback, el antiguo primario debe reconstruirse desde cero."
echo ""

echo "******************************************************************************"
echo "Verificar sincronización de Data Guard y replicación del esquema." `date`
echo "******************************************************************************"

# Mostrar estado final de la configuración después del cambio de modo de protección
dgmgrl sys/${SYS_PASSWORD}@${NODE1_DB_UNIQUE_NAME}${DB_DOMAIN_STR} <<EOF
SHOW CONFIGURATION;
SHOW DATABASE ${NODE1_DB_UNIQUE_NAME};
SHOW DATABASE ${NODE2_DB_UNIQUE_NAME};
exit;
EOF

echo ""
echo "Estado de Sincronización de Data Guard:"
echo "- Base de datos standby está gestionada por Data Guard Broker"
echo "- Esquema personalizado (${APP_SCHEMA}) fue creado en primario antes de la creación del standby"
echo "- RMAN DUPLICATE copió todos los datos incluyendo el esquema personalizado al standby"
echo "- Los cambios continuos se replican mediante transporte y aplicación de logs de Data Guard"
echo "- Use '/home/oracle/automation/verify_dataguard.sh' para verificación detallada"
echo ""

echo "******************************************************************************"
echo "¡Creación y configuración de base de datos STANDBY completa!" `date`
echo "******************************************************************************"
echo ""
echo "Resumen de Configuración de Data Guard:"
echo "- Primario: ${NODE1_DB_UNIQUE_NAME} en ${NODE1_FQ_HOSTNAME}"
echo "- Standby: ${NODE2_DB_UNIQUE_NAME} en ${NODE2_FQ_HOSTNAME}"
echo "- Modo de Protección: MAXAVAILABILITY"
echo "- Modo de Transporte: FASTSYNC (síncrono)"
echo "- Objetivo de Retraso de Archivado: ${ARCHIVE_LAG_TARGET} segundos (5 minutos)"
echo "- Tamaño de Redo Log: ${REDO_LOG_SIZE} MB"
echo "- Flashback Database: HABILITADO (permite reinstauración rápida después de failover)"
echo "- El esquema personalizado ha sido replicado al standby"
echo ""
echo "Use 'dgmgrl sys/${SYS_PASSWORD}@${NODE1_DB_UNIQUE_NAME}${DB_DOMAIN_STR}' para administrar Data Guard"
echo ""
