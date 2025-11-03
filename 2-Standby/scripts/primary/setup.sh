#!/bin/bash
# Primary node setup entry point

echo "******************************************************************************"
echo "Starting PRIMARY node setup." `date`
echo "******************************************************************************"

# Run root setup script
sudo bash -c 'sh /vagrant/2-Standby/scripts/primary/root_setup.sh'

echo "******************************************************************************"
echo "PRIMARY node setup complete." `date`
echo "******************************************************************************"
