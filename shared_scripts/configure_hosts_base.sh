#!/bin/bash
# Configure /etc/hosts for Data Guard environment

. /vagrant_config/install.env

echo "******************************************************************************"
echo "Configure /etc/hosts." `date`
echo "******************************************************************************"

cat >> /etc/hosts << EOF

# Oracle Data Guard Hosts
${NODE1_PUBLIC_IP}  ${NODE1_FQ_HOSTNAME} ${NODE1_HOSTNAME}
${NODE2_PUBLIC_IP}  ${NODE2_FQ_HOSTNAME} ${NODE2_HOSTNAME}
EOF

echo "******************************************************************************"
echo "Hosts configuration complete." `date`
echo "******************************************************************************"
