#!/bin/bash
# setup_ssh_keys_auto.sh - Automated SSH key import for standby node
# Purpose: Import primary's public key for passwordless rsync backup transfers
# Called by: root_setup.sh during standby VM provisioning

set -e

echo "========================================="
echo "Automated SSH Key Setup - Standby Node"
echo "========================================="

# Source environment variables
if [ -f /vagrant_config/install.env ]; then
    source /vagrant_config/install.env
else
    echo "ERROR: install.env not found!"
    exit 1
fi

# Ensure SSH directory exists with correct permissions
SSH_DIR="/home/oracle/.ssh"
if [ ! -d "${SSH_DIR}" ]; then
    mkdir -p "${SSH_DIR}"
    chmod 700 "${SSH_DIR}"
    chown oracle:oinstall "${SSH_DIR}"
    echo "Created SSH directory: ${SSH_DIR}"
fi

# Wait for primary's public key to be available (with timeout)
SHARED_SSH_DIR="/vagrant/ssh_keys"
PRIMARY_PUBKEY="${SHARED_SSH_DIR}/primary_id_rsa.pub"
TIMEOUT=300  # 5 minutes
ELAPSED=0

echo "Waiting for primary's public key..."
while [ ! -f "${PRIMARY_PUBKEY}" ] && [ ${ELAPSED} -lt ${TIMEOUT} ]; do
    sleep 5
    ELAPSED=$((ELAPSED + 5))
    echo "  Waiting... (${ELAPSED}s/${TIMEOUT}s)"
done

if [ ! -f "${PRIMARY_PUBKEY}" ]; then
    echo "ERROR: Primary's public key not found after ${TIMEOUT} seconds!"
    echo "Expected: ${PRIMARY_PUBKEY}"
    exit 1
fi

echo "Primary's public key found!"

# Import primary's public key into authorized_keys
AUTHORIZED_KEYS="${SSH_DIR}/authorized_keys"
if [ ! -f "${AUTHORIZED_KEYS}" ]; then
    touch "${AUTHORIZED_KEYS}"
    chmod 600 "${AUTHORIZED_KEYS}"
    chown oracle:oinstall "${AUTHORIZED_KEYS}"
fi

# Add primary's key if not already present
PRIMARY_KEY_CONTENT=$(cat "${PRIMARY_PUBKEY}")
if grep -q "${PRIMARY_KEY_CONTENT}" "${AUTHORIZED_KEYS}" 2>/dev/null; then
    echo "Primary's public key already in authorized_keys"
else
    cat "${PRIMARY_PUBKEY}" >> "${AUTHORIZED_KEYS}"
    echo "Primary's public key added to authorized_keys"
fi

# Display key fingerprint for verification
echo "Imported key fingerprint:"
ssh-keygen -lf "${PRIMARY_PUBKEY}"

# Create backup storage directory for incoming backups from primary
BACKUP_FROM_PRIMARY="/u02/backup_from_primary"
if [ ! -d "${BACKUP_FROM_PRIMARY}" ]; then
    mkdir -p "${BACKUP_FROM_PRIMARY}"
    chown oracle:oinstall "${BACKUP_FROM_PRIMARY}"
    chmod 755 "${BACKUP_FROM_PRIMARY}"
    echo "Created backup storage directory: ${BACKUP_FROM_PRIMARY}"
fi

# Generate standby's own SSH keys for future use (optional but recommended)
SSH_KEY="${SSH_DIR}/id_rsa"
if [ ! -f "${SSH_KEY}" ]; then
    echo "Generating standby's own SSH key pair..."
    sudo -u oracle ssh-keygen -t rsa -b 4096 -f "${SSH_KEY}" -N "" -C "oracle@${NODE2_FQ_HOSTNAME}"
    echo "Standby SSH key pair generated successfully"
fi

# Export standby's host keys to shared folder for primary to add to known_hosts (running as root)
STANDBY_HOST_KEYS="${SHARED_SSH_DIR}/standby_host_keys.txt"
ssh-keyscan -H "${NODE2_PUBLIC_IP}" 2>/dev/null > "${STANDBY_HOST_KEYS}"
ssh-keyscan -H "${NODE2_FQ_HOSTNAME}" 2>/dev/null >> "${STANDBY_HOST_KEYS}"
chmod 644 "${STANDBY_HOST_KEYS}"
echo "Standby host keys exported to: ${STANDBY_HOST_KEYS}"

echo "========================================="
echo "Standby SSH Key Setup Complete"
echo "========================================="
echo "Configuration summary:"
echo "  - Primary's public key imported"
echo "  - Backup directory created: ${BACKUP_FROM_PRIMARY}"
echo "  - Standby's SSH keys generated"
echo "  - Host keys exported for primary"
echo ""
echo "Next steps:"
echo "1. Primary will import standby's host keys"
echo "2. PowerShell deploy.ps1 will test SSH connectivity"
echo "3. After SSH test passes, cron jobs will be installed"
echo "========================================="
