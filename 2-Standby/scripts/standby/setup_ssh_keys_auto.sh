#!/bin/bash
# setup_ssh_keys_auto.sh - Importación automática de claves SSH para nodo standby
# Propósito: Importar clave pública del primario para transferencias de copia de seguridad rsync sin contraseña
# Llamado por: root_setup.sh durante el aprovisionamiento de VM standby

set -e

echo "========================================="
echo "Configuración Automática de Claves SSH - Nodo Standby"
echo "========================================="

# Cargar variables de entorno
if [ -f /vagrant_config/install.env ]; then
    source /vagrant_config/install.env
else
    echo "ERROR: ¡install.env no encontrado!"
    exit 1
fi

# Asegurar que el directorio SSH existe con permisos correctos
SSH_DIR="/home/oracle/.ssh"
if [ ! -d "${SSH_DIR}" ]; then
    mkdir -p "${SSH_DIR}"
    chmod 700 "${SSH_DIR}"
    chown oracle:oinstall "${SSH_DIR}"
    echo "Directorio SSH creado: ${SSH_DIR}"
fi

# Esperar a que la clave pública del primario esté disponible (con tiempo de espera)
SHARED_SSH_DIR="/vagrant/ssh_keys"
PRIMARY_PUBKEY="${SHARED_SSH_DIR}/primary_id_rsa.pub"
TIMEOUT=300  # 5 minutos
ELAPSED=0

echo "Esperando clave pública del primario..."
while [ ! -f "${PRIMARY_PUBKEY}" ] && [ ${ELAPSED} -lt ${TIMEOUT} ]; do
    sleep 5
    ELAPSED=$((ELAPSED + 5))
    echo "  Esperando... (${ELAPSED}s/${TIMEOUT}s)"
done

if [ ! -f "${PRIMARY_PUBKEY}" ]; then
    echo "ERROR: ¡Clave pública del primario no encontrada después de ${TIMEOUT} segundos!"
    echo "Esperado: ${PRIMARY_PUBKEY}"
    exit 1
fi

echo "¡Clave pública del primario encontrada!"

# Importar clave pública del primario en authorized_keys
AUTHORIZED_KEYS="${SSH_DIR}/authorized_keys"
if [ ! -f "${AUTHORIZED_KEYS}" ]; then
    touch "${AUTHORIZED_KEYS}"
    chmod 600 "${AUTHORIZED_KEYS}"
    chown oracle:oinstall "${AUTHORIZED_KEYS}"
fi

# Agregar clave del primario si no está presente
PRIMARY_KEY_CONTENT=$(cat "${PRIMARY_PUBKEY}")
if grep -q "${PRIMARY_KEY_CONTENT}" "${AUTHORIZED_KEYS}" 2>/dev/null; then
    echo "Clave pública del primario ya está en authorized_keys"
else
    cat "${PRIMARY_PUBKEY}" >> "${AUTHORIZED_KEYS}"
    echo "Clave pública del primario agregada a authorized_keys"
fi

# Mostrar huella digital de clave para verificación
echo "Huella digital de clave importada:"
ssh-keygen -lf "${PRIMARY_PUBKEY}"

# Crear directorio de almacenamiento de copia de seguridad para copias de seguridad entrantes del primario
BACKUP_FROM_PRIMARY="/u02/backup_from_primary"
if [ ! -d "${BACKUP_FROM_PRIMARY}" ]; then
    mkdir -p "${BACKUP_FROM_PRIMARY}"
    chown oracle:oinstall "${BACKUP_FROM_PRIMARY}"
    chmod 755 "${BACKUP_FROM_PRIMARY}"
    echo "Directorio de almacenamiento de copia de seguridad creado: ${BACKUP_FROM_PRIMARY}"
fi

# Generar claves SSH propias del standby para uso futuro (opcional pero recomendado)
SSH_KEY="${SSH_DIR}/id_rsa"
if [ ! -f "${SSH_KEY}" ]; then
    echo "Generando par de claves SSH propio del standby..."
    sudo -u oracle ssh-keygen -t rsa -b 4096 -f "${SSH_KEY}" -N "" -C "oracle@${NODE2_FQ_HOSTNAME}"
    echo "Par de claves SSH del standby generado con éxito"
fi

# Exportar claves de host del standby a carpeta compartida para que el primario las agregue a known_hosts (ejecutando como root)
STANDBY_HOST_KEYS="${SHARED_SSH_DIR}/standby_host_keys.txt"
ssh-keyscan -H "${NODE2_PUBLIC_IP}" 2>/dev/null > "${STANDBY_HOST_KEYS}"
ssh-keyscan -H "${NODE2_FQ_HOSTNAME}" 2>/dev/null >> "${STANDBY_HOST_KEYS}"
chmod 644 "${STANDBY_HOST_KEYS}"
echo "Claves de host del standby exportadas a: ${STANDBY_HOST_KEYS}"

echo "========================================="
echo "Configuración de Claves SSH del Standby Completada"
echo "========================================="
echo "Resumen de configuración:"
echo "  - Clave pública del primario importada"
echo "  - Directorio de copia de seguridad creado: ${BACKUP_FROM_PRIMARY}"
echo "  - Claves SSH del standby generadas"
echo "  - Claves de host exportadas para el primario"
echo ""
echo "Próximos pasos:"
echo "1. El primario importará claves de host del standby"
echo "2. PowerShell deploy.ps1 probará conectividad SSH"
echo "3. Después de que pase la prueba SSH, se instalarán trabajos cron"
echo "========================================="
