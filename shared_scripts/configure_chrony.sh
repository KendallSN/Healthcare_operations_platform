#!/bin/bash
# Configure time synchronization with chrony

. /vagrant_config/install.env

echo "******************************************************************************"
echo "Configure chrony for time synchronization." `date`
echo "******************************************************************************"

# Enable and start chrony
systemctl enable chronyd
systemctl start chronyd

# Verify time sync
chronyc tracking

echo "******************************************************************************"
echo "Chrony configuration complete." `date`
echo "******************************************************************************"
