#!/bin/bash
# Verificación Completa de la Configuración de Data Guard
# Ejecutar en la base de datos PRIMARY

. /home/oracle/scripts/setEnv.sh
. /vagrant_config/install.env

echo "========================================================================"
echo "VERIFICACIÓN DE LA CONFIGURACIÓN DE DATA GUARD"
echo "========================================================================"

# 1. Estado de la Base de Datos Primary
echo ""
echo "=== ESTADO DE LA BASE DE DATOS PRIMARY ==="
sqlplus -s / as sysdba <<EOF
SET LINESIZE 150
COL name FORMAT A10
COL db_unique_name FORMAT A15
COL database_role FORMAT A16
COL open_mode FORMAT A12
COL protection_mode FORMAT A20
COL protection_level FORMAT A20

-- Muestra el rol, modo de apertura, y nivel de protección de la base de datos
SELECT name, db_unique_name, database_role, open_mode, log_mode,
       force_logging, flashback_on, protection_mode, protection_level
FROM v\$database;
EOF

# 2. Estado de los Destinos de Archivo
echo ""
echo "=== DESTINOS DE ARCHIVO ==="
sqlplus -s / as sysdba <<EOF
SET LINESIZE 200
COL dest_name FORMAT A15
COL status FORMAT A10
COL destination FORMAT A40
COL error FORMAT A30

-- Consulta v\$archive_dest para verificar el estado de los destinos de archivo de logs
-- Solo muestra destinos activos (no INACTIVE)
SELECT dest_name, status, destination, error
FROM v\$archive_dest
WHERE status != 'INACTIVE'
ORDER BY dest_id;
EOF

# 3. Logs de Redo Standby
echo ""
echo "=== LOGS DE REDO STANDBY ==="
sqlplus -s / as sysdba <<EOF
COL member FORMAT A50

-- Consulta v\$standby_log para verificar la configuración de standby redo logs
-- Estos logs son necesarios para recibir cambios en el standby
SELECT l.group#, l.thread#, l.sequence#, l.bytes/1024/1024 AS size_mb,
       l.archived, l.status, f.member
FROM v\$standby_log l, v\$logfile f
WHERE l.group# = f.group#
ORDER BY l.group#;
EOF

# 4. Configuración del Retraso de Archivo
echo ""
echo "=== OBJETIVO DE RETRASO DE ARCHIVO ==="
sqlplus -s / as sysdba <<EOF
-- ARCHIVE_LAG_TARGET especifica el tiempo máximo (en segundos) antes de forzar un switch de log
SHOW PARAMETER ARCHIVE_LAG_TARGET;
EOF

# 5. Historial de Cambios de Log
echo ""
echo "=== CAMBIOS DE LOG RECIENTES ==="
sqlplus -s / as sysdba <<EOF
-- Consulta v\$log_history para ver los últimos 10 switches de log en las últimas 24 horas
SELECT sequence#, thread#, first_time, first_change#
FROM v\$log_history
WHERE first_time > SYSDATE - 1
ORDER BY sequence# DESC
FETCH FIRST 10 ROWS ONLY;
EOF

# 6. Estado de la Base de Datos Standby
echo ""
echo "=== ESTADO DE LA BASE DE DATOS STANDBY ==="
sqlplus -s sys/${SYS_PASSWORD}@${NODE2_DB_UNIQUE_NAME}${DB_DOMAIN_STR} as sysdba <<EOF
SET LINESIZE 150

-- Verifica el rol y modo de apertura de la base de datos standby
SELECT name, db_unique_name, database_role, open_mode, log_mode
FROM v\$database;
EOF

# 7. Estado de Aplicación en Standby
echo ""
echo "=== ESTADO DE APLICACIÓN EN STANDBY ==="
sqlplus -s sys/${SYS_PASSWORD}@${NODE2_DB_UNIQUE_NAME}${DB_DOMAIN_STR} as sysdba <<EOF
-- Consulta v\$managed_standby para ver los procesos de Data Guard activos
-- MRP: Managed Recovery Process (aplica logs)
-- RFS: Remote File Server (recibe logs)
-- LNS: Log Network Server (envía logs desde primary)
SELECT process, status, thread#, sequence#, block#, blocks
FROM v\$managed_standby
WHERE process LIKE 'MRP%' OR process LIKE 'RFS%' OR process LIKE 'LNS%';
EOF

# 8. Retraso de Transporte y Aplicación
echo ""
echo "=== RETRASO DE TRANSPORTE Y APLICACIÓN ==="
sqlplus -s sys/${SYS_PASSWORD}@${NODE2_DB_UNIQUE_NAME}${DB_DOMAIN_STR} as sysdba <<EOF
COL name FORMAT A20
COL value FORMAT A20
COL unit FORMAT A15
COL time_computed FORMAT A20

-- Consulta v\$dataguard_stats para medir el retraso entre primary y standby
-- transport lag: tiempo desde que el log fue generado hasta que fue recibido
-- apply lag: tiempo desde que el log fue generado hasta que fue aplicado
SELECT name, value, unit, time_computed
FROM v\$dataguard_stats
WHERE name IN ('transport lag', 'apply lag');
EOF

# 9. Verificación de Brechas de Archivo
echo ""
echo "=== VERIFICACIÓN DE BRECHAS DE ARCHIVO ==="
sqlplus -s sys/${SYS_PASSWORD}@${NODE2_DB_UNIQUE_NAME}${DB_DOMAIN_STR} as sysdba <<EOF
-- Consulta v\$archive_gap para identificar secuencias de log faltantes en el standby
SELECT * FROM v\$archive_gap;
EOF

echo ""
echo "Si no se devuelven filas, NO HAY BRECHAS (esto es bueno)"

# 10. Estado del Broker de Data Guard
echo ""
echo "=== CONFIGURACIÓN DEL BROKER DE DATA GUARD ==="
dgmgrl -silent sys/${SYS_PASSWORD}@${NODE1_DB_UNIQUE_NAME}${DB_DOMAIN_STR} <<EOF
-- Muestra la configuración completa del Data Guard Broker
-- y el estado de cada base de datos (primary y standby)
SHOW CONFIGURATION;
SHOW DATABASE ${NODE1_DB_UNIQUE_NAME};
SHOW DATABASE ${NODE2_DB_UNIQUE_NAME};
EXIT;
EOF

# 11. Verificación del Esquema Personalizado
echo ""
echo "=== VERIFICACIÓN DEL ESQUEMA PERSONALIZADO (en PDB) ==="
sqlplus -s / as sysdba <<EOF
ALTER SESSION SET CONTAINER=${PDB_NAME};
SET LINESIZE 150
COL owner FORMAT A15
COL table_name FORMAT A30

-- Lista todas las tablas de usuarios no-sistema en el PDB
-- Útil para verificar que el esquema personalizado se replicó correctamente
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
echo "VERIFICACIÓN COMPLETA"
echo "========================================================================"
