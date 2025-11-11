#!/bin/bash
# Configurar nombre de host

. /vagrant_config/install.env

# Determinar cuál nodo es éste basado en IP
IP_ADDR=$(hostname -I | awk '{print $2}')

if [ "${IP_ADDR}" == "${NODE1_PUBLIC_IP}" ]; then
  HOSTNAME_TO_SET=${NODE1_FQ_HOSTNAME}
elif [ "${IP_ADDR}" == "${NODE2_PUBLIC_IP}" ]; then
  HOSTNAME_TO_SET=${NODE2_FQ_HOSTNAME}
else
  echo "ERROR: No se puede determinar nodo de IP: ${IP_ADDR}"
  exit 1
fi

echo "******************************************************************************"
echo "Set hostname to ${HOSTNAME_TO_SET}." `date`
echo "******************************************************************************"

hostnamectl set-hostname ${HOSTNAME_TO_SET} --static

echo "******************************************************************************"
echo "Hostname configuration complete." `date`
echo "******************************************************************************"
