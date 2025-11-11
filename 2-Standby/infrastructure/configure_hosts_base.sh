#!/bin/bash
# Configurar /etc/hosts para ambiente Data Guard

. /vagrant_config/install.env

echo "******************************************************************************"
echo "Configure /etc/hosts." `date`
echo "******************************************************************************"

cat >> /etc/hosts << EOF

# Servidores Oracle Data Guard
${NODE1_PUBLIC_IP}  ${NODE1_FQ_HOSTNAME} ${NODE1_HOSTNAME}
${NODE2_PUBLIC_IP}  ${NODE2_FQ_HOSTNAME} ${NODE2_HOSTNAME}
EOF

echo "******************************************************************************"
echo "Hosts configuration complete." `date`
echo "******************************************************************************"
