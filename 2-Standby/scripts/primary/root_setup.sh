#!/bin/bash
# Primary node root setup script

. /vagrant_config/install.env

echo "******************************************************************************"
echo "PRIMARY Root Setup Started." `date`
echo "******************************************************************************"

# Prepare disks
sh /vagrant_scripts/prepare_u01_u02_disks.sh

# Install OS packages
sh /vagrant_scripts/install_os_packages.sh

# Set passwords
echo "******************************************************************************"
echo "Set root and oracle password and change ownership." `date`
echo "******************************************************************************"
echo -e "${ROOT_PASSWORD}\n${ROOT_PASSWORD}" | passwd
echo -e "${ORACLE_PASSWORD}\n${ORACLE_PASSWORD}" | passwd oracle
chown -R oracle:oinstall /u01 /u02
chmod -R 775 /u01 /u02

# Configure hosts file
sh /vagrant_scripts/configure_hosts_base.sh

# Configure hostname
sh /vagrant_scripts/configure_hostname.sh

# Configure time sync
sh /vagrant_scripts/configure_chrony.sh

# Setup oracle user environment
su - oracle -c 'sh /vagrant/2-Standby/scripts/primary/oracle_user_environment_setup.sh'
. /home/oracle/scripts/setEnv.sh

# Install Oracle software
su - oracle -c 'sh /vagrant_scripts/oracle_db_software_installation.sh'

# Run Oracle root scripts
echo "******************************************************************************"
echo "Run DB root scripts." `date`
echo "******************************************************************************"
sh ${ORA_INVENTORY}/orainstRoot.sh
sh ${ORACLE_HOME}/root.sh

# Create primary database
su - oracle -c 'sh /vagrant/2-Standby/scripts/primary/oracle_create_database.sh'

# Deploy custom schema
su - oracle -c 'sh /vagrant/2-Standby/scripts/primary/deploy_custom_schema.sh'

# Setup automation scripts
su - oracle -c 'sh /vagrant/2-Standby/scripts/primary/setup_automation.sh'

# Setup SSH keys for automated backup transfers (run as root for /vagrant access)
echo "******************************************************************************"
echo "Setting up SSH keys for backup transfers." `date`
echo "******************************************************************************"
sh /vagrant/2-Standby/scripts/primary/setup_ssh_keys_auto.sh

# Install cron jobs for automation
echo "******************************************************************************"
echo "Installing cron jobs for automation." `date`
echo "******************************************************************************"
su - oracle -c 'sh /home/oracle/automation/install_cron_jobs.sh'

echo "******************************************************************************"
echo "PRIMARY Root Setup Complete." `date`
echo "******************************************************************************"
