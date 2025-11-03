#!/bin/bash
# Setup SSH Key-Based Authentication for Automated Backups
# Run on PRIMARY database as oracle user

. /home/oracle/scripts/setEnv.sh
. /vagrant_config/install.env

echo "===================================================================="
echo "Setup SSH Key-Based Authentication"
echo "===================================================================="

# Check if SSH key already exists
if [ -f /home/oracle/.ssh/id_rsa ]; then
  echo "SSH key already exists"
  read -p "Regenerate SSH key? (yes/no): " regenerate
  if [ "$regenerate" != "yes" ]; then
    echo "Using existing SSH key"
  else
    rm -f /home/oracle/.ssh/id_rsa /home/oracle/.ssh/id_rsa.pub
    ssh-keygen -t rsa -b 4096 -f /home/oracle/.ssh/id_rsa -N ""
  fi
else
  # Generate SSH key
  echo "Generating SSH key..."
  mkdir -p /home/oracle/.ssh
  chmod 700 /home/oracle/.ssh
  ssh-keygen -t rsa -b 4096 -f /home/oracle/.ssh/id_rsa -N ""
fi

echo ""
echo "===================================================================="
echo "Copy SSH key to standby server"
echo "===================================================================="
echo "You will be prompted for the oracle user password on standby"
echo ""

# Copy public key to standby
ssh-copy-id -i /home/oracle/.ssh/id_rsa.pub oracle@${NODE2_FQ_HOSTNAME}

echo ""
echo "===================================================================="
echo "Test SSH connection to standby"
echo "===================================================================="

ssh oracle@${NODE2_FQ_HOSTNAME} "echo 'SSH connection successful from primary to standby'"

if [ $? -eq 0 ]; then
  echo ""
  echo "===================================================================="
  echo "SSH Key Setup Complete!"
  echo "===================================================================="
  echo "You can now use passwordless rsync for backup transfers"
else
  echo ""
  echo "===================================================================="
  echo "ERROR: SSH connection test failed!"
  echo "===================================================================="
  exit 1
fi
