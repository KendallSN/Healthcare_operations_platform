#!/bin/bash
# Configurar sincronización de hora con chrony

. /vagrant_config/install.env

echo "******************************************************************************"
echo "Configure chrony for time synchronization." `date`
echo "******************************************************************************"

# Habilitar e iniciar chrony
systemctl enable chronyd
systemctl start chronyd

# Verificar sincronización de hora
chronyc tracking

echo "******************************************************************************"
echo "Chrony configuration complete." `date`
echo "******************************************************************************"
