#!/bin/bash
# Setup automation scripts on primary

. /vagrant_config/install.env
. /home/oracle/scripts/setEnv.sh

echo "******************************************************************************"
echo "Setup automation scripts on PRIMARY." `date`
echo "******************************************************************************"

# Copy automation scripts to oracle user home
mkdir -p /home/oracle/automation

cp /vagrant_automation/*.sh /home/oracle/automation/
chmod +x /home/oracle/automation/*.sh
chown -R oracle:oinstall /home/oracle/automation

# Create logs directory for automation
mkdir -p /home/oracle/logs/automation
chown -R oracle:oinstall /home/oracle/logs

echo "******************************************************************************"
echo "Automation scripts setup complete." `date`
echo "******************************************************************************"
echo "Available scripts in /home/oracle/automation/:"
ls -l /home/oracle/automation/
