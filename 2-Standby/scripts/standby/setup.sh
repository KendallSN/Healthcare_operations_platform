#!/bin/bash
# Standby node setup entry point

echo "******************************************************************************"
echo "Starting STANDBY node setup." `date`
echo "******************************************************************************"

# Run root setup script
sudo bash -c 'sh /vagrant/2-Standby/scripts/standby/root_setup.sh'

echo "******************************************************************************"
echo "STANDBY node setup complete." `date`
echo "******************************************************************************"
