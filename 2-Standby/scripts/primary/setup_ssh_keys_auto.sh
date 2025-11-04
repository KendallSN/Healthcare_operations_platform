#!/bin/bash
# setup_ssh_keys_auto.sh - Automated SSH key generation for primary node
# Purpose: Generate SSH keys non-interactively for rsync backup transfers
# Called by: root_setup.sh during primary VM provisioning

set -e

echo "========================================="
echo "Automated SSH Key Setup - Primary Node"
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

# Generate SSH key pair if it doesn't exist
SSH_KEY="${SSH_DIR}/id_rsa"
if [ ! -f "${SSH_KEY}" ]; then
    echo "Generating SSH key pair for oracle user..."
    sudo -u oracle ssh-keygen -t rsa -b 4096 -f "${SSH_KEY}" -N "" -C "oracle@${NODE1_FQ_HOSTNAME}"
    echo "SSH key pair generated successfully"
else
    echo "SSH key pair already exists, skipping generation"
fi

# Create shared directory for key exchange (running as root)
SHARED_SSH_DIR="/vagrant/ssh_keys"
mkdir -p "${SHARED_SSH_DIR}"
chmod 777 "${SHARED_SSH_DIR}"

# Export public key to shared folder for standby to import
PUBLIC_KEY="${SSH_KEY}.pub"
if [ -f "${PUBLIC_KEY}" ]; then
    cp "${PUBLIC_KEY}" "${SHARED_SSH_DIR}/primary_id_rsa.pub"
    chmod 644 "${SHARED_SSH_DIR}/primary_id_rsa.pub"
    echo "Public key exported to: ${SHARED_SSH_DIR}/primary_id_rsa.pub"

    # Display public key fingerprint for verification
    ssh-keygen -lf "${PUBLIC_KEY}"
else
    echo "ERROR: Public key not found at ${PUBLIC_KEY}"
    exit 1
fi

# Pre-configure SSH client settings for batch mode
SSH_CONFIG="${SSH_DIR}/config"
if [ ! -f "${SSH_CONFIG}" ]; then
    cat > "${SSH_CONFIG}" << 'EOF'
# SSH Client Configuration for Data Guard Backup Transfer
Host ol8-21-dg2 ol8-21-dg2.localdomain 192.168.56.102
    StrictHostKeyChecking accept-new
    BatchMode yes
    ConnectTimeout 10
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF
    chown oracle:oinstall "${SSH_CONFIG}"
    chmod 600 "${SSH_CONFIG}"
    echo "SSH client configuration created"
fi

# Create placeholder for standby's host key (will be populated by PowerShell)
KNOWN_HOSTS="${SSH_DIR}/known_hosts"
touch "${KNOWN_HOSTS}"
chown oracle:oinstall "${KNOWN_HOSTS}"
chmod 644 "${KNOWN_HOSTS}"

echo "========================================="
echo "Primary SSH Key Setup Complete"
echo "========================================="
echo "Next steps:"
echo "1. Standby will import this public key during its setup"
echo "2. PowerShell deploy.ps1 will test SSH connectivity"
echo "3. After SSH test passes, cron jobs will be installed"
echo "========================================="
