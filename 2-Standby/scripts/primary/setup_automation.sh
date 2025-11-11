#!/bin/bash
# Configurar scripts de automatización en el primario

. /vagrant_config/install.env
. /home/oracle/scripts/setEnv.sh

echo "******************************************************************************"
echo "Configurar scripts de automatización en PRIMARY." `date`
echo "******************************************************************************"

# Copiar scripts de automatización al directorio del usuario oracle
mkdir -p /home/oracle/automation

cp /vagrant_automation/*.sh /home/oracle/automation/
chmod +x /home/oracle/automation/*.sh
chown -R oracle:oinstall /home/oracle/automation

# Crear directorio de registros para automatización
mkdir -p /home/oracle/logs/automation
chown -R oracle:oinstall /home/oracle/logs

echo "******************************************************************************"
echo "Configuración de scripts de automatización completada." `date`
echo "******************************************************************************"
echo "Scripts disponibles en /home/oracle/automation/:"
ls -l /home/oracle/automation/
