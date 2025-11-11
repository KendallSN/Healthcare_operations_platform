#!/bin/bash
# Sincronización Manual de Logs
# Ejecutar en la base de datos PRIMARY cuando se necesite sincronización manual

. /home/oracle/scripts/setEnv.sh
. /vagrant_config/install.env

echo "===================================================================="
echo "Archivo Manual de Logs y Sincronización"
echo "===================================================================="

# Forzar cambio de log y archivo en primary
sqlplus / as sysdba <<EOF
-- Comando síncrono - espera a que se complete el archivado
-- Fuerza el switch del log actual y su archivado inmediato
ALTER SYSTEM ARCHIVE LOG CURRENT;

-- Verificar última secuencia archivada al destino remoto (dest_id=2)
SELECT MAX(sequence#) AS latest_seq FROM v\$archived_log WHERE dest_id=2;
EXIT;
EOF

echo ""
echo "===================================================================="
echo "Verificar estado de sincronización en standby"
echo "===================================================================="

sqlplus sys/${SYS_PASSWORD}@${NODE2_DB_UNIQUE_NAME}${DB_DOMAIN_STR} as sysdba <<EOF
SET LINESIZE 150
COL name FORMAT A30
COL value FORMAT A30

-- Consulta v\$dataguard_stats para verificar los retrasos de transporte y aplicación
-- transport lag: retraso en la recepción de logs
-- apply lag: retraso en la aplicación de logs
SELECT name, value, unit FROM v\$dataguard_stats WHERE name IN ('transport lag','apply lag');
EXIT;
EOF

echo ""
echo "===================================================================="
echo "Sincronización Completa"
echo "===================================================================="
