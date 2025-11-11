#!/bin/bash
# Verificar configuración de automatización de respaldos
# Ejecutar después del despliegue para confirmar que todos los componentes funcionan
# Uso: /home/oracle/automation/verify_backup_automation.sh

. /home/oracle/scripts/setEnv.sh
. /vagrant_config/install.env

echo "========================================================================"
echo "VERIFICACIÓN DE AUTOMATIZACIÓN DE RESPALDOS"
echo "Host: $(hostname)"
echo "Fecha: $(date)"
echo "========================================================================"

ERRORS=0

# 1. Verificar claves SSH
echo ""
echo "=== Configuración de claves SSH ==="
if [ -f ~/.ssh/id_rsa ]; then
    echo "  [OK] La clave privada existe"
    KEY_PERMS=$(stat -c "%a" ~/.ssh/id_rsa)
    if [ "$KEY_PERMS" = "600" ]; then
        echo "  [OK] Permisos de clave privada correctos (600)"
    else
        echo "  [ERROR] Permisos de clave privada incorrectos: $KEY_PERMS (debe ser 600)"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "  [ERROR] Clave privada faltante"
    ERRORS=$((ERRORS + 1))
fi

if [ -f ~/.ssh/id_rsa.pub ]; then
    echo "  [OK] La clave pública existe"
    PUB_KEY_PERMS=$(stat -c "%a" ~/.ssh/id_rsa.pub)
    if [ "$PUB_KEY_PERMS" = "644" ]; then
        echo "  [OK] Permisos de clave pública correctos (644)"
    else
        echo "  [ERROR] Permisos de clave pública incorrectos: $PUB_KEY_PERMS (debe ser 644)"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "  [ERROR] Clave pública faltante"
    ERRORS=$((ERRORS + 1))
fi

# 2. Probar conectividad SSH (si está en primario)
if [ "$ORACLE_SID" = "cdb1" ]; then
    echo ""
    echo "=== Prueba de conectividad SSH ==="
    if ssh -o BatchMode=yes -o ConnectTimeout=10 oracle@${NODE2_FQ_HOSTNAME} "echo 'SSH OK'" 2>/dev/null | grep -q "SSH OK"; then
        echo "  [OK] SSH sin contraseña al servidor en espera funcionando"
    else
        echo "  [ERROR] SSH sin contraseña al servidor en espera falló"
        ERRORS=$((ERRORS + 1))
    fi
fi

# 3. Verificar claves autorizadas (si está en espera)
if [ "$ORACLE_SID" != "cdb1" ]; then
    echo ""
    echo "=== Claves autorizadas ==="
    if [ -f ~/.ssh/authorized_keys ]; then
        echo "  [OK] El archivo de claves autorizadas existe"
        AUTH_KEY_PERMS=$(stat -c "%a" ~/.ssh/authorized_keys)
        if [ "$AUTH_KEY_PERMS" = "600" ]; then
            echo "  [OK] Permisos de claves autorizadas correctos (600)"
        else
            echo "  [ERROR] Permisos de claves autorizadas incorrectos: $AUTH_KEY_PERMS (debe ser 600)"
            ERRORS=$((ERRORS + 1))
        fi

        KEY_COUNT=$(grep -c "^ssh-rsa" ~/.ssh/authorized_keys)
        echo "  [OK] Número de claves autorizadas: $KEY_COUNT"
    else
        echo "  [ERROR] Archivo de claves autorizadas faltante"
        ERRORS=$((ERRORS + 1))
    fi
fi

# 4. Verificar directorios de respaldos
echo ""
echo "=== Directorios de respaldos ==="
if [ "$ORACLE_SID" = "cdb1" ]; then
    if [ -d /u02/backup ]; then
        echo "  [OK] El directorio de respaldos primario existe: /u02/backup"
        BACKUP_COUNT=$(ls -1 /u02/backup/*.bkp 2>/dev/null | wc -l)
        BACKUP_SIZE=$(du -sh /u02/backup 2>/dev/null | awk '{print $1}')
        echo "    Archivos de respaldo: $BACKUP_COUNT"
        echo "    Tamaño total: $BACKUP_SIZE"
    else
        echo "  [ERROR] Directorio de respaldos primario faltante: /u02/backup"
        ERRORS=$((ERRORS + 1))
    fi
else
    if [ -d /u02/backup_from_primary ]; then
        echo "  [OK] El directorio de respaldos en espera existe: /u02/backup_from_primary"
        BACKUP_COUNT=$(ls -1 /u02/backup_from_primary/*.bkp 2>/dev/null | wc -l)
        BACKUP_SIZE=$(du -sh /u02/backup_from_primary 2>/dev/null | awk '{print $1}')
        echo "    Archivos de respaldo: $BACKUP_COUNT"
        echo "    Tamaño total: $BACKUP_SIZE"
    else
        echo "  [ERROR] Directorio de respaldos en espera faltante: /u02/backup_from_primary"
        ERRORS=$((ERRORS + 1))
    fi
fi

# 5. Verificar scripts de automatización
echo ""
echo "=== Scripts de automatización ==="
REQUIRED_SCRIPTS=(
    "check_log_transport.sh"
    "delete_archives_primary.sh"
    "delete_archives_standby.sh"
    "install_cron_jobs.sh"
    "manual_backup.sh"
    "rman_daily_backup.sh"
    "setup_ssh_keys.sh"
    "verify_dataguard.sh"
    "verify_backup_automation.sh"
)

SCRIPT_ERRORS=0
for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [ -x "/home/oracle/automation/$script" ]; then
        echo "  [OK] $script"
    else
        echo "  [ERROR] $script (faltante o no ejecutable)"
        ERRORS=$((ERRORS + 1))
        SCRIPT_ERRORS=$((SCRIPT_ERRORS + 1))
    fi
done

if [ $SCRIPT_ERRORS -eq 0 ]; then
    echo "  Todos los scripts de automatización están presentes y son ejecutables"
fi

# 6. Verificar tareas programadas
echo ""
echo "=== Tareas programadas ==="
CRON_COUNT=$(crontab -l 2>/dev/null | grep -v "^#" | grep -v "^$" | wc -l)
if [ "$ORACLE_SID" = "cdb1" ]; then
    # El primario debe tener 3 tareas programadas
    if [ "$CRON_COUNT" -ge 3 ]; then
        echo "  [OK] Tareas programadas del primario instaladas ($CRON_COUNT trabajos)"
        echo ""
        crontab -l 2>/dev/null | grep -v "^#" | grep -v "^$" | sed 's/^/    /'
    else
        echo "  [ERROR] Tareas programadas del primario faltantes (encontradas $CRON_COUNT, se esperaban 3)"
        echo "  Ejecutar: /home/oracle/automation/install_cron_jobs.sh"
        ERRORS=$((ERRORS + 1))
    fi
else
    # El servidor en espera debe tener 1 tarea programada
    if [ "$CRON_COUNT" -ge 1 ]; then
        echo "  [OK] Tareas programadas en espera instaladas ($CRON_COUNT trabajos)"
        echo ""
        crontab -l 2>/dev/null | grep -v "^#" | grep -v "^$" | sed 's/^/    /'
    else
        echo "  [ERROR] Tareas programadas en espera faltantes (encontradas $CRON_COUNT, se esperaba 1)"
        echo "  Ejecutar: /home/oracle/automation/install_cron_jobs.sh"
        ERRORS=$((ERRORS + 1))
    fi
fi

# 7. Verificar directorio de registros
echo ""
echo "=== Directorio de registros ==="
if [ -d /home/oracle/logs/automation ]; then
    echo "  [OK] El directorio de registros existe: /home/oracle/logs/automation"
    LOG_COUNT=$(ls -1 /home/oracle/logs/automation/*.log 2>/dev/null | wc -l)
    echo "    Archivos de registro: $LOG_COUNT"

    if [ $LOG_COUNT -gt 0 ]; then
        echo "    Registros recientes:"
        ls -lth /home/oracle/logs/automation/*.log 2>/dev/null | head -5 | awk '{print "      " $9 " (" $5 ")"}'
    fi
else
    echo "  [ERROR] Directorio de registros faltante: /home/oracle/logs/automation"
    ERRORS=$((ERRORS + 1))
fi

# 8. Verificar entorno Oracle
echo ""
echo "=== Entorno de Oracle ==="
if [ -n "$ORACLE_HOME" ]; then
    echo "  [OK] ORACLE_HOME configurado: $ORACLE_HOME"
else
    echo "  [ERROR] ORACLE_HOME no está configurado"
    ERRORS=$((ERRORS + 1))
fi

if [ -n "$ORACLE_SID" ]; then
    echo "  [OK] ORACLE_SID configurado: $ORACLE_SID"
else
    echo "  [ERROR] ORACLE_SID no está configurado"
    ERRORS=$((ERRORS + 1))
fi

# 9. Verificar conectividad de base de datos
echo ""
echo "=== Conectividad de base de datos ==="
DB_STATUS=$(sqlplus -s / as sysdba << EOF
SET PAGESIZE 0 FEEDBACK OFF HEADING OFF
SELECT status FROM v\$instance;
EXIT;
EOF
)

DB_STATUS=$(echo "$DB_STATUS" | tr -d '[:space:]')

if [ "$DB_STATUS" = "OPEN" ] || [ "$DB_STATUS" = "MOUNTED" ]; then
    echo "  [OK] Estado de la base de datos: $DB_STATUS"
else
    echo "  [ADVERTENCIA] Estado de la base de datos: $DB_STATUS (inesperado)"
    ERRORS=$((ERRORS + 1))
fi

# 10. Verificar configuración de Data Guard (si es primario)
if [ "$ORACLE_SID" = "cdb1" ]; then
    echo ""
    echo "=== Configuración de Data Guard ==="

    DG_STATUS=$(dgmgrl / "show configuration" 2>/dev/null | grep "Configuration Status" | awk -F: '{print $2}' | tr -d '[:space:]')

    if [ "$DG_STATUS" = "SUCCESS" ]; then
        echo "  [OK] Estado de configuración de Data Guard: ÉXITO"
    else
        echo "  [ADVERTENCIA] Estado de configuración de Data Guard: $DG_STATUS"
        ERRORS=$((ERRORS + 1))
    fi
fi

# Resumen
echo ""
echo "========================================================================"
if [ $ERRORS -eq 0 ]; then
    echo "RESULTADO DE VERIFICACIÓN: [OK] TODAS LAS VERIFICACIONES PASARON"
    echo ""
    echo "La automatización de respaldos está completamente configurada y lista."
    echo ""
    echo "Tareas automatizadas:"
    if [ "$ORACLE_SID" = "cdb1" ]; then
        echo "  - Respaldos diarios a las 1:00 AM (con transferencia automática al servidor en espera)"
        echo "  - Limpieza de archivos a las 2:00 AM (después de la confirmación del servidor en espera)"
        echo "  - Monitoreo de transporte de registros cada 10 minutos"
    else
        echo "  - Limpieza de archivos a las 11:00 PM (retención de 3 días)"
    fi
else
    echo "RESULTADO DE VERIFICACIÓN: [FALLO] SE ENCONTRARON $ERRORS ERROR(ES)"
    echo ""
    echo "Por favor, revise los errores anteriores y corríjalos antes del uso en producción."
    echo ""
    echo "Soluciones comunes:"
    echo "  - Tareas programadas faltantes: /home/oracle/automation/install_cron_jobs.sh"
    echo "  - Claves SSH faltantes: /home/oracle/automation/setup_ssh_keys.sh"
fi
echo "========================================================================"

exit $ERRORS
