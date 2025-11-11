#!/bin/bash
# setup_ssh_keys_auto.sh - Generación automatizada de claves SSH para nodo primario
# Propósito: Generar claves SSH de forma no interactiva para transferencias de respaldo rsync
# Llamado por: root_setup.sh durante el aprovisionamiento de VM primaria

set -e

echo "========================================="
echo "Configuración automatizada de claves SSH - Nodo primario"
echo "========================================="

# Cargar variables de entorno
if [ -f /vagrant_config/install.env ]; then
    source /vagrant_config/install.env
else
    echo "ERROR: install.env no encontrado!"
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

# Generar par de claves SSH si no existe
SSH_KEY="${SSH_DIR}/id_rsa"
if [ ! -f "${SSH_KEY}" ]; then
    echo "Generando par de claves SSH para el usuario oracle..."
    sudo -u oracle ssh-keygen -t rsa -b 4096 -f "${SSH_KEY}" -N "" -C "oracle@${NODE1_FQ_HOSTNAME}"
    echo "Par de claves SSH generado exitosamente"
else
    echo "El par de claves SSH ya existe, omitiendo generación"
fi

# Crear directorio compartido para intercambio de claves (ejecutar como root)
SHARED_SSH_DIR="/vagrant/ssh_keys"
mkdir -p "${SHARED_SSH_DIR}"
chmod 777 "${SHARED_SSH_DIR}"

# Exportar clave pública a carpeta compartida para que el standby la importe
PUBLIC_KEY="${SSH_KEY}.pub"
if [ -f "${PUBLIC_KEY}" ]; then
    cp "${PUBLIC_KEY}" "${SHARED_SSH_DIR}/primary_id_rsa.pub"
    chmod 644 "${SHARED_SSH_DIR}/primary_id_rsa.pub"
    echo "Clave pública exportada a: ${SHARED_SSH_DIR}/primary_id_rsa.pub"

    # Mostrar huella dactilar de clave pública para verificación
    ssh-keygen -lf "${PUBLIC_KEY}"
else
    echo "ERROR: Clave pública no encontrada en ${PUBLIC_KEY}"
    exit 1
fi

# Pre-configurar ajustes de cliente SSH para modo por lotes
SSH_CONFIG="${SSH_DIR}/config"
if [ ! -f "${SSH_CONFIG}" ]; then
    cat > "${SSH_CONFIG}" << 'EOF'
# Configuración del cliente SSH para transferencia de respaldo de Data Guard
Host ol8-21-dg2 ol8-21-dg2.localdomain 192.168.56.102
    StrictHostKeyChecking accept-new
    BatchMode yes
    ConnectTimeout 10
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF
    chown oracle:oinstall "${SSH_CONFIG}"
    chmod 600 "${SSH_CONFIG}"
    echo "Configuración del cliente SSH creada"
fi

# Crear marcador de posición para clave de host del standby (será poblado por PowerShell)
KNOWN_HOSTS="${SSH_DIR}/known_hosts"
touch "${KNOWN_HOSTS}"
chown oracle:oinstall "${KNOWN_HOSTS}"
chmod 644 "${KNOWN_HOSTS}"

echo "========================================="
echo "Configuración de claves SSH del primario completada"
echo "========================================="
echo "Próximos pasos:"
echo "1. El standby importará esta clave pública durante su configuración"
echo "2. PowerShell deploy.ps1 probará la conectividad SSH"
echo "3. Después de pasar la prueba SSH, se instalarán trabajos cron"
echo "========================================="
